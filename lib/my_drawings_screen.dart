// lib/my_drawings_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class MyDrawingsScreen extends StatefulWidget {
  const MyDrawingsScreen({super.key});

  @override
  State<MyDrawingsScreen> createState() => _MyDrawingsScreenState();
}

class _MyDrawingsScreenState extends State<MyDrawingsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _drawings = [];

  @override
  void initState() {
    super.initState();
    _loadDrawings();
  }

  Future<void> _loadDrawings() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() {
        _loading = false;
        _drawings = [];
      });
      return;
    }

    try {
      final res = await supabase
          .from("drawings")
          .select("id, image_url, title, is_public, created_at")
          .eq("user_id", user.id)
          .order("created_at", ascending: false);

      setState(() {
        _drawings = List<Map<String, dynamic>>.from(res);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _drawings = [];
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load drawings: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFF070812),
      appBar: AppBar(
        title: const Text(
          "My drawings",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF070812),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadDrawings,
          )
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : _drawings.isEmpty
              ? const Center(
                  child: Text(
                    "You haven't saved any drawings yet.\nTry saving from the Pixel / Draw screen.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(12),
                  child: GridView.builder(
                    itemCount: _drawings.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.9,
                    ),
                    itemBuilder: (context, index) {
                      final d = _drawings[index];
                      final url = d["image_url"] as String;
                      final title = (d["title"] as String?) ?? "Untitled";
                      final isPublic = (d["is_public"] as bool?) ?? false;

                      return ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF16142B),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white10,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Expanded(
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: Image.network(
                                        url,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return const Center(
                                            child: Icon(Icons.broken_image,
                                                color: Colors.white38),
                                          );
                                        },
                                      ),
                                    ),
                                    if (isPublic)
                                      Positioned(
                                        top: 6,
                                        left: 6,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: colors.secondary
                                                .withOpacity(0.9),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: const Text(
                                            "Public",
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 8),
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
