import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final supabase = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> drawings = [];

  @override
  void initState() {
    super.initState();
    _fetchDrawings();
  }

  Future<void> _fetchDrawings() async {
    setState(() => _loading = true);
    final uid = supabase.auth.currentUser!.id;

    final res = await supabase
        .from('drawings')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false);

    setState(() {
      drawings = List<Map<String, dynamic>>.from(res);
      _loading = false;
    });
  }

  Future<void> _toggleFavorite(String drawingId, bool isFav) async {
    final uid = supabase.auth.currentUser!.id;

    if (isFav) {
      await supabase.from('favorites').delete().match({
        'user_id': uid,
        'drawing_id': drawingId,
      });
    } else {
      await supabase.from('favorites').insert({
        'user_id': uid,
        'drawing_id': drawingId,
      });
    }
    _fetchDrawings();
  }

  Future<bool> _isFavorite(String drawingId) async {
    final uid = supabase.auth.currentUser!.id;
    final res = await supabase
        .from('favorites')
        .select()
        .eq('user_id', uid)
        .eq('drawing_id', drawingId);

    return res.isNotEmpty;
  }

  Future<void> _togglePublic(String id, bool current) async {
    await supabase
        .from('drawings')
        .update({'is_public': !current})
        .eq('id', id);
    _fetchDrawings();
  }

  Future<void> _deleteDrawing(String drawingId) async {
    await supabase.from('drawings').delete().eq('id', drawingId);
    _fetchDrawings();
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF070812),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070812),
        elevation: 0,
        title: const Text("My Pixel Gallery", style: TextStyle(color: Colors.white)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.person, color: Colors.white),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : drawings.isEmpty
              ? const Center(
                  child: Text(
                    "No drawings yet.\nSave artworks from Draw Mode!",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchDrawings,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.90,
                    ),
                    itemCount: drawings.length,
                    itemBuilder: (_, i) {
                      final d = drawings[i];
                      final image = d['image_url'];
                      final title = d['title'] ?? 'Untitled';

                      return FutureBuilder(
                        future: _isFavorite(d['id']),
                        builder: (c, snapshot) {
                          final fav = snapshot.data ?? false;
                          return GestureDetector(
                            onTap: () => _openPreview(image),
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
                                      child: Image.network(image, fit: BoxFit.cover),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          fav ? Icons.favorite : Icons.favorite_border,
                                          color: fav ? Colors.red : Colors.white70,
                                        ),
                                        onPressed: () {
                                          _toggleFavorite(d['id'], fav);
                                        },
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          d['is_public']
                                              ? Icons.public
                                              : Icons.public_off_outlined,
                                          color: d['is_public']
                                              ? Colors.greenAccent
                                              : Colors.white38,
                                        ),
                                        onPressed: () =>
                                            _togglePublic(d['id'], d['is_public']),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                                        onPressed: () => _deleteDrawing(d['id']),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
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
        child: InteractiveViewer(child: Image.network(url)),
      ),
    );
  }
}
