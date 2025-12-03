import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final supabase = Supabase.instance.client;
  List<dynamic> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final uid = supabase.auth.currentUser!.id;

    final res = await supabase
        .from("notifications")
        .select("type, created_at, drawings(image_url), users!actor_id(name)")
        .eq("receiver_id", uid)
        .order("created_at", ascending: false);

    setState(() {
      _items = res;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0C20),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E0C20),
        title: const Text("Activity"),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(
                  child: Text("No activity yet 👀", style: TextStyle(color: Colors.white54)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _items.length,
                  itemBuilder: (_, i) {
                    final n = _items[i];
                    final actor = n["users"]["name"] ?? "Someone";
                    final type = n["type"];
                    final img = n["drawings"]["image_url"];

                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(img, width: 44, height: 44, fit: BoxFit.cover),
                      ),
                      title: Text(
                        type == "like"
                            ? "$actor liked your drawing ❤️"
                            : "$actor commented on your drawing 💬",
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  },
                ),
    );
  }
}
