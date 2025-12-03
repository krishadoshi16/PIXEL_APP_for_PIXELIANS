// lib/main.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_screen.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';
import 'pixel_screen.dart';
import 'gallery_screen.dart';
import 'draw_screen.dart';
import 'profile_screen.dart';               // ⭐ NEW
import 'favorites_screen.dart';
import 'explore_screen.dart';
import 'activity_screen.dart';




const supabaseUrl = 'https://ifbnvchgwxgdaoswpsir.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlmYm52Y2hnd3hnZGFvc3dwc2lyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ2NjQ2MTYsImV4cCI6MjA4MDI0MDYxNn0.gLvfxIRywIULoVqQcOm6rhEJsbVPciPysBPc2U5OdnA';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  runApp(const PixelArtApp());
}

class PixelArtApp extends StatelessWidget {
  const PixelArtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pixel Art Maker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF5C8D),
          secondary: Color(0xFF5CFFCB),
          surface: Color(0xFF16142B),
          background: Color(0xFF0E0C20),
        ),
        scaffoldBackgroundColor: const Color(0xFF0E0C20),
      ),
      initialRoute: '/login',
      routes: {
        '/login': (_) => const LoginScreen(),
        '/signup': (_) => const SignupScreen(),
        '/forgot': (_) => const ForgotPasswordScreen(),
        '/home': (_) => const PixelHomeScreen(),
        '/gallery': (_) => const GalleryScreen(),
        '/draw': (_) => const DrawScreen(),
        '/profile': (_) => const ProfileScreen(),          // ⭐ NEW
        '/favorites': (_) => const FavoritesScreen(),      // ⭐ NEW
        '/explore': (_) => const ExploreScreen(),   // ⭐ NEW
        '/activity': (_) => const ActivityScreen(),

      },
    );
  }
}

/// ======================= HOME SCREEN =======================

class PixelHomeScreen extends StatefulWidget {
  const PixelHomeScreen({super.key});

  @override
  State<PixelHomeScreen> createState() => _PixelHomeScreenState();
}

class _PixelHomeScreenState extends State<PixelHomeScreen> {
  ImageProvider? _selectedImage;
  File? _selectedFile;
  final ImagePicker _picker = ImagePicker();

  Future<void> _logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E0C20),
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
              tooltip: "Explore",
              icon: const Icon(Icons.public, color: Colors.white),
              onPressed: () {
                Navigator.pushNamed(context, "/explore");
              },
            ),
          IconButton(
            tooltip: "Profile",
            icon: const Icon(Icons.person_outline, color: Colors.white),
            onPressed: () {
              Navigator.pushNamed(context, "/profile");
            },
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
          ),
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () => Navigator.pushNamed(context, "/activity"),
          ),

        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),

              SizedBox(
                height: 130,
                child: Image.asset('assets/logo.png', fit: BoxFit.contain),
              ),
              const SizedBox(height: 12),

              const Text(
                'PIXEL ART MAKER',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Turn any photo into a cute pixel grid.',
                style: TextStyle(fontSize: 14, color: Colors.white70),
                textAlign: TextAlign.center,
              ),

              if (user != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Logged in as ${user.email}',
                  style: const TextStyle(fontSize: 11, color: Colors.white54),
                ),
              ],

              const SizedBox(height: 24),

              Expanded(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: colors.surface.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: colors.secondary.withOpacity(0.8),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.primary.withOpacity(0.45),
                          blurRadius: 20,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF241B4D),
                                Color(0xFF16142B),
                              ],
                            ),
                          ),
                          child: _buildPreviewContent(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: _pickImageFromGallery,
                    child: const Text(
                      'SELECT IMAGE',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedFile == null
                          ? Colors.white.withOpacity(0.08)
                          : colors.secondary,
                      foregroundColor:
                          _selectedFile == null ? Colors.white54 : Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: _selectedFile == null
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    PixelScreen(imageFile: _selectedFile!),
                              ),
                            );
                          },
                    child: Text(
                      _selectedFile == null
                          ? 'CHOOSE IMAGE FIRST'
                          : 'CONVERT TO PIXEL ART',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.3,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.08),
                      foregroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pushNamed(context, '/draw');
                    },
                    child: const Text(
                      'DRAW MODE (EMPTY GRID)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.3,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  TextButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/gallery');
                    },
                    icon: const Icon(
                      Icons.photo_library_outlined,
                      size: 18,
                      color: Colors.white70,
                    ),
                    label: const Text(
                      'Open PIXEL gallery',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewContent() {
    if (_selectedImage != null) {
      return Image(image: _selectedImage!, fit: BoxFit.cover);
    }

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Wrap(
            spacing: 3,
            runSpacing: 3,
            children: List.generate(10 * 10, (index) {
              const colors = [
                Color(0xFFFF5C8D),
                Color(0xFF5CFFCB),
                Color(0xFFFFE66D),
                Color(0xFF9D7CFF),
              ];
              return Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: colors[index % colors.length]
                      .withOpacity(index.isEven ? 0.9 : 0.45),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
          const SizedBox(height: 18),
          const Text(
            'Your pixel preview will appear here\nafter you select an image.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? picked =
          await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      setState(() {
        final file = File(picked.path);
        _selectedFile = file;
        _selectedImage = FileImage(file);
      });
    } catch (e) {
      _showSnack('Could not pick image: $e');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: const Color(0xFF16142B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'How to use Pixel Art Maker',
            style: TextStyle(color: Colors.white),
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '1. Log in or create an account.\n'
                '2. Tap "SELECT IMAGE" and pick any photo.\n'
                '3. Tap "CONVERT TO PIXEL ART" to see the grid.\n'
                '4. Use "View drawing instructions" to see colors and rows.\n'
                '5. Save PNG or share the pixel art as PDF.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(_).pop(),
              child: const Text(
                'Got it',
                style: TextStyle(color: Color(0xFF5CFFCB)),
              ),
            ),
          ],
        );
      },
    );
  }
}
