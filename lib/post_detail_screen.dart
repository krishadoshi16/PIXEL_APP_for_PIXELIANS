import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'comments_screen.dart';

class PostDetailScreen extends StatefulWidget {
  final Map post;
  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final supabase = Supabase.instance.client;

  bool _isFavorite = false;
  bool _loadingFav = true;
  int commentCount = 0;

  @override
  void initState() {
    super.initState();
    _checkFav();
    _loadCommentCount();
  }

  Future<void> _checkFav() async {
    final uid = supabase.auth.currentUser!.id;

    final res = await supabase
        .from("favorites")
        .select()
        .eq("user_id", uid)
        .eq("drawing_id", widget.post["id"]);

    setState(() {
      _isFavorite = res.isNotEmpty;
      _loadingFav = false;
    });
  }

  Future<void> _toggleFav() async {
    final uid = supabase.auth.currentUser!.id;

    if (_isFavorite) {
      await supabase
          .from("favorites")
          .delete()
          .eq("user_id", uid)
          .eq("drawing_id", widget.post["id"]);
    } else {
      await supabase.from("favorites").insert({
        "user_id": uid,
        "drawing_id": widget.post["id"],
      });
    }

    _checkFav();
  }

  Future<void> _loadCommentCount() async {
    final res = await supabase
        .from("comments")
        .select("id")
        .eq("drawing_id", widget.post["id"]);

    setState(() => commentCount = res.length);
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.post["image_url"];
    final title = widget.post["title"] ?? "Untitled";
    final username = widget.post["users"]["name"] ?? "Artist";

    return Scaffold(
      backgroundColor: const Color(0xFF0E0C20),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E0C20),
        title: Text(
          username,
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              /// ❤️ LIKE / FAVORITE
              IconButton(
                onPressed: _loadingFav ? null : _toggleFav,
                icon: Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: Colors.pinkAccent,
                  size: 32,
                ),
              ),

              /// 🔗 SHARE
              IconButton(
                onPressed: () => Share.share(imageUrl),
                icon: const Icon(
                  Icons.share,
                  color: Colors.white,
                  size: 32,
                ),
              ),

              /// 💬 COMMENTS (Tap to open)
              Stack(
                children: [
                  IconButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CommentsScreen(
                             postId: widget.post["id"],
                              ownerId: widget.post["user_id"],
                          ),
                        ),
                      );
                      _loadCommentCount();
                    },
                    icon: const Icon(
                      Icons.comment,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  if (commentCount > 0)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: CircleAvatar(
                        radius: 9,
                        backgroundColor: Colors.pinkAccent,
                        child: Text(
                          "$commentCount",
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
