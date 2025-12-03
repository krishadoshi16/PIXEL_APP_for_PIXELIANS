import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommentsScreen extends StatefulWidget {
  final String postId;
  final String ownerId; // ⭐ drawing owner's id added
  const CommentsScreen({super.key, required this.postId, required this.ownerId});

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final supabase = Supabase.instance.client;
  List<dynamic> comments = [];
  bool _loading = true;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  late final String uid;

  @override
  void initState() {
    super.initState();
    uid = supabase.auth.currentUser!.id;
    _loadComments();
  }

  Future<void> _loadComments() async {
    setState(() => _loading = true);

    final res = await supabase
        .from("comments")
        .select("id, comment, user_id, created_at, users(name)")
        .eq("drawing_id", widget.postId)
        .order("created_at", ascending: true);

    setState(() {
      comments = res;
      _loading = false;
    });

    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    await supabase.from("comments").insert({
      "drawing_id": widget.postId,
      "user_id": uid,
      "comment": text,
    });

    // ⭐ send notification to owner if someone else comments
    if (uid != widget.ownerId) {
      await supabase.from("notifications").insert({
        "receiver_id": widget.ownerId,
        "actor_id": uid,
        "drawing_id": widget.postId,
        "type": "comment",
      });
    }

    _controller.clear();
    _loadComments();
  }

  Future<void> _deleteComment(String commentId) async {
    await supabase.from("comments").delete().eq("id", commentId);
    _loadComments();
  }

  Future<void> _editComment(String commentId, String oldText) async {
    final controller = TextEditingController(text: oldText);

    final newText = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0E0C20),
        title: const Text("Edit Comment"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "Comment"),
          autofocus: true,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text("Save")),
        ],
      ),
    );

    if (newText == null || newText.isEmpty) return;

    await supabase
        .from("comments")
        .update({"comment": newText}).eq("id", commentId);

    _loadComments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0C20),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E0C20),
        title: const Text("Comments", style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : comments.isEmpty
                    ? const Center(
                        child: Text(
                          "No comments yet. Be first ✨",
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.all(12),
                        itemCount: comments.length,
                        itemBuilder: (_, i) {
                          final c = comments[i];
                          final isMine = c["user_id"] == uid;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.white12,
                                  child: Icon(Icons.person,
                                      color: Colors.white70, size: 18),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0x22222222),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              c["users"]["name"] ?? "User",
                                              style: const TextStyle(
                                                color: Color(0xFF5CFFCB),
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (isMine)
                                              Row(
                                                children: [
                                                  GestureDetector(
                                                    onTap: () => _editComment(
                                                        c["id"], c["comment"]),
                                                    child: const Icon(
                                                      Icons.edit,
                                                      color: Colors.lightBlueAccent,
                                                      size: 18,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  GestureDetector(
                                                    onTap: () =>
                                                        _deleteComment(c["id"]),
                                                    child: const Icon(
                                                      Icons.delete,
                                                      color: Colors.redAccent,
                                                      size: 18,
                                                    ),
                                                  ),
                                                ],
                                              )
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          c["comment"],
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),

          /// ✨ Input bar - unchanged
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(color: Color(0xFF151525)),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Write a comment...",
                      hintStyle:
                          const TextStyle(color: Colors.white54, fontSize: 14),
                      filled: true,
                      fillColor: const Color(0xFF1E1C31),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _send,
                  icon: const Icon(Icons.send, color: Color(0xFF5CFFCB)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
