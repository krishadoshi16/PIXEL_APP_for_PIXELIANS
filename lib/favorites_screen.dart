import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final supabase = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> favDrawings = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _loading = true);
    final uid = supabase.auth.currentUser!.id;

    final res = await supabase
        .from('favorites')
        .select('drawing_id, drawings(*)')
        .eq('user_id', uid)
        .order('id', ascending: false);

    // Extract drawing object from nested response
    favDrawings = res.map<Map<String, dynamic>>(
      (f) => f['drawings'] as Map<String, dynamic>,
    ).toList();

    setState(() => _loading = false);
  }

  Future<void> _removeFavorite(String drawingId) async {
    final uid = supabase.auth.currentUser!.id;
    await supabase.from('favorites').delete().match({
      'user_id': uid,
      'drawing_id': drawingId,
    });
    _loadFavorites();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070812),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070812),
        title: const Text("My Favorites ❤️", style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : favDrawings.isEmpty
              ? const Center(
                  child: Text(
                    "No favorite drawings yet 🥹",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadFavorites,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.90,
                    ),
                    itemCount: favDrawings.length,
                    itemBuilder: (_, i) {
                      final d = favDrawings[i];
                      return GestureDetector(
                        onTap: () => _openPreview(d['image_url']),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    d['image_url'],
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  d['title'] ?? 'Untitled',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 13),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.favorite, color: Colors.redAccent),
                                onPressed: () => _removeFavorite(d['id']),
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

  void _openPreview(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        child: InteractiveViewer(
          child: Image.network(url),
        ),
      ),
    );
  }
}
