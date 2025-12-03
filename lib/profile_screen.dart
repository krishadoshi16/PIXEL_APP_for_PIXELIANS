// lib/profile_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'favorites_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final supabase = Supabase.instance.client;
  bool _loading = true;

  String username = "";
  String? avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final res = await supabase
        .from('users')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    setState(() {
      username = res?['name'] ?? "Pixelians";
      avatarUrl = res?['avatar_url'];
      _loading = false;
    });
  }

  Future<void> _updateName() async {
    final controller = TextEditingController(text: username);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Name"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "Name"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text("Save")),
        ],
      ),
    );

    if (newName == null || newName.trim().isEmpty) return;

    final uid = supabase.auth.currentUser!.id;
    await supabase.from('users').update({'name': newName.trim()}).eq('id', uid);

    setState(() => username = newName.trim());
  }

  Future<void> _changeAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    final uid = supabase.auth.currentUser!.id;
    final bytes = await File(file.path).readAsBytes();
    final path = "avatars/$uid.png";

    await supabase.storage.from("avatars").uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(upsert: true),
    );

    final publicUrl = supabase.storage.from("avatars").getPublicUrl(path);

    await supabase.from("users").update({
      'avatar_url': publicUrl,
    }).eq('id', uid);

    setState(() => avatarUrl = publicUrl);
  }

  void _logout() async {
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, "/login", (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0E0C20),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E0C20),
        elevation: 0,
        title: const Text("Profile", style: TextStyle(color: Colors.white)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _changeAvatar,
                    child: CircleAvatar(
                      radius: 55,
                      backgroundColor: Colors.white12,
                      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                      child: avatarUrl == null
                          ? const Icon(Icons.person, size: 55, color: Colors.white54)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    username,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? "",
                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _updateName,
                    icon: const Icon(Icons.edit),
                    label: const Text("Edit Profile"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white12,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                  ),
                  const SizedBox(height: 28),
                  ListTile(
                    leading: const Icon(Icons.brush, color: Colors.white),
                    title: const Text("My Drawings", style: TextStyle(color: Colors.white)),
                    trailing: const Icon(Icons.chevron_right, color: Colors.white70),
                    onTap: () => Navigator.pushNamed(context, "/gallery"),
                  ),
                  const Divider(color: Colors.white12),
                  ListTile(
                    leading: const Icon(Icons.favorite, color: Colors.pinkAccent),
                    title: const Text("Favorites", style: TextStyle(color: Colors.white)),
                    trailing: const Icon(Icons.chevron_right, color: Colors.white70),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesScreen()));
                    },
                  ),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 24),
                  const Text("More profile features coming soon 🎨",
                      style: TextStyle(color: Colors.white38, fontSize: 13)),
                ],
              ),
            ),
    );
  }
}
