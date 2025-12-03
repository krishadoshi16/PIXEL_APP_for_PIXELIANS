// lib/draw_screen.dart
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import 'login_screen.dart';

enum _Tool { brush, eraser, eyedropper, fill }

class DrawScreen extends StatefulWidget {
  const DrawScreen({super.key});

  @override
  State<DrawScreen> createState() => _DrawScreenState();
}

class _DrawScreenState extends State<DrawScreen> {
  int _gridCount = 32;
  bool _showGrid = true;
  bool _mirrorMode = false;

  late List<List<Color>> _gridColors;
  Uint8List? _pixelBytes;
  bool _isBuilding = false;

  Color _currentColor = const Color(0xFFFF5C8D);
  List<Color> _palette = [
    const Color(0xFFFF5C8D),
    const Color(0xFF5CFFCB),
    const Color(0xFFFFE66D),
    const Color(0xFF9D7CFF),
    Colors.white,
    Colors.black,
    Colors.red,
    Colors.green,
    Colors.blue,
  ];

  _Tool _tool = _Tool.brush;
  int _brushSize = 1;

  List<List<List<Color>>> _history = [];
  int _historyIndex = -1;
  static const int _maxHistory = 50;

  final ImagePicker _picker = ImagePicker();
  File? _referenceFile;

  @override
  void initState() {
    super.initState();
    _initGrid();
  }

  void _initGrid() {
    _gridColors = List.generate(
      _gridCount,
      (_) => List<Color>.filled(_gridCount, Colors.white, growable: false),
      growable: false,
    );
    _history.clear();
    _historyIndex = -1;
    _pushHistory();
    _buildImageFromGrid();
  }

  List<List<Color>> _cloneGrid(List<List<Color>> src) {
    return [for (final r in src) [...r]];
  }

  void _pushHistory() {
    final snap = _cloneGrid(_gridColors);
    if (_historyIndex < _history.length - 1) {
      _history = _history.sublist(0, _historyIndex + 1);
    }
    _history.add(snap);
    if (_history.length > _maxHistory) _history.removeAt(0);
    _historyIndex = _history.length - 1;
  }

  bool get _canUndo => _historyIndex > 0;
  bool get _canRedo => _historyIndex < _history.length - 1;

  void _undo() {
    if (!_canUndo) return;
    setState(() {
      _historyIndex--;
      _gridColors = _cloneGrid(_history[_historyIndex]);
    });
    _buildImageFromGrid();
  }

  void _redo() {
    if (!_canRedo) return;
    setState(() {
      _historyIndex++;
      _gridColors = _cloneGrid(_history[_historyIndex]);
    });
    _buildImageFromGrid();
  }

  Future<void> _buildImageFromGrid() async {
    setState(() => _isBuilding = true);
    try {
      final n = _gridCount;
      final img.Image small = img.Image(width: n, height: n);

      for (int r = 0; r < n; r++) {
        for (int c = 0; c < n; c++) {
          final col = _gridColors[r][c];
          small.setPixelRgba(c, r, col.red, col.green, col.blue, col.alpha);
        }
      }

      final img.Image big = img.copyResize(
        small,
        width: 900,
        height: 900,
        interpolation: img.Interpolation.nearest,
      );

      _pixelBytes = Uint8List.fromList(img.encodePng(big));
    } catch (_) {}
    if (mounted) setState(() => _isBuilding = false);
  }

  // ================== LOCAL SAVE (DEVICE) ==================
  Future<void> _savePixelArtLocal() async {
    if (_pixelBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to save yet.')),
      );
      return;
    }
    try {
      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory("${dir.path}/pixel_art");
      if (!await folder.exists()) await folder.create();
      final file = File(
        '${folder.path}/draw_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(_pixelBytes!, flush: true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved locally:\n${file.path}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  // ================== CLOUD SAVE (SUPABASE) ==================
  Future<void> _savePixelArtOnline({required bool isPublic}) async {
    if (_pixelBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to upload yet.')),
      );
      return;
    }

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to save online.')),
      );
      return;
    }

    try {
      final bucket = supabase.storage.from('pixel-art'); // 👈 make sure this bucket exists
      final path =
          'drawings/${user.id}/${DateTime.now().millisecondsSinceEpoch}.png';

      // Upload bytes to Supabase Storage
      await bucket.uploadBinary(path, _pixelBytes!);

      // Get public URL
      final publicUrl = bucket.getPublicUrl(path);

      // Insert into drawings table
      await supabase.from('drawings').insert({
        'user_id': user.id,
        'image_url': publicUrl,
        'is_public': isPublic,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isPublic
                ? 'Saved online & published publicly 🌍'
                : 'Saved online (private) ✅',
          ),
        ),
      );
    } on PostgrestException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Database error: ${e.message}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    }
  }

  // ================== SAVE OPTIONS SHEET ==================
  Future<void> _showSaveOptions() async {
    if (_pixelBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('First draw something to save.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16142B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              const Text(
                'Save drawing',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              const Divider(color: Colors.white24, height: 16),
              ListTile(
                leading: const Icon(Icons.save_alt, color: Colors.white70),
                title: const Text(
                  'Save locally on device',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _savePixelArtLocal();
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.cloud_upload_outlined, color: Colors.white70),
                title: const Text(
                  'Save online (private)',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Only you can see it in your online gallery.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _savePixelArtOnline(isPublic: false);
                },
              ),
              ListTile(
                leading: const Icon(Icons.public, color: Colors.greenAccent),
                title: const Text(
                  'Save online & publish publicly 🌍',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Will appear in the public feed (future feature).',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _savePixelArtOnline(isPublic: true);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  // ================== SHARE AS PDF ==================
  Future<void> _sharePixelArt() async {
    if (_pixelBytes == null) return;
    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (ctx) => pw.Center(
            child: pw.Image(
              pw.MemoryImage(_pixelBytes!),
              width: 400,
              height: 400,
            ),
          ),
        ),
      );
      Printing.sharePdf(bytes: await pdf.save(), filename: 'pixel_drawing.pdf');
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Share failed: $e')));
    }
  }

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

  Future<void> _pickReferenceImage() async {
    try {
      final x = await _picker.pickImage(source: ImageSource.gallery);
      if (x == null) return;
      setState(() => _referenceFile = File(x.path));
    } catch (_) {}
  }

  Widget _buildReferenceBar() {
    if (_referenceFile == null) {
      return Container(
        height: 90,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24, width: 0.8),
        ),
        child: const Center(
          child: Text(
            "Tap the photo icon to add a reference image",
            style: TextStyle(color: Colors.white54, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Container(
      height: 90,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24, width: 0.8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.file(_referenceFile!, fit: BoxFit.cover),
      ),
    );
  }

  void _onTapCell(Offset p, Size size) {
    final double cellW = size.width / _gridCount;
    final double cellH = size.height / _gridCount;
    final col = (p.dx ~/ cellW);
    final row = (p.dy ~/ cellH);
    if (row < 0 || col < 0 || row >= _gridCount || col >= _gridCount) return;

    if (_tool == _Tool.eyedropper) {
      setState(() => _currentColor = _gridColors[row][col]);
      return;
    }
    if (_tool == _Tool.fill) {
      _applyFill(row, col);
      return;
    }
    _applyBrush(row, col, erase: _tool == _Tool.eraser);
  }

  void _applyBrush(int row, int col, {bool erase = false}) {
    final paintColor = erase ? Colors.white : _currentColor;
    final half = (_brushSize - 1) ~/ 2;

    setState(() {
      for (int r = row - half; r <= row + half; r++) {
        for (int c = col - half; c <= col + half; c++) {
          if (r < 0 || c < 0 || r >= _gridCount || c >= _gridCount) continue;
          _gridColors[r][c] = paintColor;

          if (_mirrorMode) {
            final mirrorC = (_gridCount - 1) - c;
            if (mirrorC >= 0 && mirrorC < _gridCount) {
              _gridColors[r][mirrorC] = paintColor;
            }
          }
        }
      }
    });

    _pushHistory();
    _buildImageFromGrid();
  }

  void _applyFill(int row, int col) {
    final target = _gridColors[row][col];
    if (target == _currentColor) return;
    final n = _gridCount;

    final visited =
        List.generate(n, (_) => List<bool>.filled(n, false), growable: false);

    final stack = <List<int>>[
      [row, col]
    ];

    setState(() {
      while (stack.isNotEmpty) {
        final p = stack.removeLast();
        final r = p[0];
        final c = p[1];
        if (r < 0 || c < 0 || r >= n || c >= n) continue;
        if (visited[r][c]) continue;
        if (_gridColors[r][c] != target) continue;
        visited[r][c] = true;
        _gridColors[r][c] = _currentColor;

        if (_mirrorMode) {
          final mirrorC = (_gridCount - 1) - c;
          if (mirrorC >= 0 && mirrorC < _gridCount) {
            _gridColors[r][mirrorC] = _currentColor;
          }
        }

        stack.add([r + 1, c]);
        stack.add([r - 1, c]);
        stack.add([r, c + 1]);
        stack.add([r, c - 1]);
      }
    });

    _pushHistory();
    _buildImageFromGrid();
  }

  void _clearGrid() {
    setState(() {
      for (int i = 0; i < _gridCount; i++) {
        for (int j = 0; j < _gridCount; j++) {
          _gridColors[i][j] = Colors.white;
        }
      }
    });
    _pushHistory();
    _buildImageFromGrid();
  }

  void _changeGridSize(double v) {
    final newSize = v.round();
    if (newSize == _gridCount) return;
    setState(() => _gridCount = newSize);
    _initGrid();
  }

  // Color Picker
  void _openColorPicker() {
    Color temp = _currentColor;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF16142B),
        title: const Text("Select a color", style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: temp,
            onColorChanged: (c) => temp = c,
            pickerAreaBorderRadius: BorderRadius.circular(12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _currentColor = temp;
                _palette.add(temp);
              });
              Navigator.pop(context);
            },
            child: const Text("Add Color",
                style: TextStyle(color: Color(0xFF5CFFCB))),
          ),
        ],
      ),
    );
  }

  Widget _toolButton(_Tool tool, IconData icon, String text) {
    final bool active = (_tool == tool);
    return TextButton.icon(
      onPressed: () => setState(() => _tool = tool),
      icon: Icon(icon, color: active ? Colors.white : Colors.white54, size: 18),
      label: Text(
        text,
        style: TextStyle(
          color: active ? Colors.white : Colors.white54,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _brushChip(int size) {
    final bool selected = _brushSize == size;
    return GestureDetector(
      onTap: () => setState(() => _brushSize = size),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white24 : Colors.white10,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.white : Colors.white24,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          "${size}x$size",
          style: TextStyle(color: selected ? Colors.white : Colors.white70),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFF070812),
      appBar: AppBar(
        title:
            const Text("Draw Pixel Art", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF070812),
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
              icon: const Icon(Icons.image_outlined, color: Colors.white),
              onPressed: _pickReferenceImage),
          IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: _logout),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: _buildReferenceBar(),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (_, c) {
                    final double size = c.biggest.shortestSide;
                    final drawSize = Size(size, size);
                    return GestureDetector(
                      onTapDown: (d) => _onTapCell(d.localPosition, drawSize),
                      child: SizedBox(
                        width: size,
                        height: size,
                        child: CustomPaint(
                          painter: _DrawGridPainter(
                            gridColors: _gridColors,
                            showGrid: _showGrid,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              decoration: const BoxDecoration(
                color: Color(0xFF111320),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text("Grid:", style: TextStyle(color: Colors.white70)),
                      Expanded(
                        child: Slider(
                          value: _gridCount.toDouble(),
                          min: 8,
                          max: 64,
                          divisions: 7,
                          label: "$_gridCount",
                          onChanged: _changeGridSize,
                        ),
                      ),
                      Text("$_gridCount",
                          style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                  Row(
                    children: [
                      Switch(
                          value: _showGrid,
                          activeColor: colors.secondary,
                          onChanged: (v) => setState(() => _showGrid = v)),
                      const Text("Show grid",
                          style: TextStyle(color: Colors.white70)),
                      const SizedBox(width: 12),
                      Switch(
                          value: _mirrorMode,
                          activeColor: colors.secondary,
                          onChanged: (v) => setState(() => _mirrorMode = v)),
                      const Text("Mirror mode",
                          style: TextStyle(color: Colors.white70)),
                      const Spacer(),
                      TextButton(
                        onPressed: _clearGrid,
                        child: const Text("Clear",
                            style: TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.undo, color: Colors.white70),
                        onPressed: _canUndo ? _undo : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.redo, color: Colors.white70),
                        onPressed: _canRedo ? _redo : null,
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _toolButton(_Tool.brush, Icons.brush, "Brush"),
                              _toolButton(_Tool.eraser, Icons.square_foot, "Eraser"),
                              _toolButton(
                                  _Tool.eyedropper, Icons.colorize, "Pick"),
                              _toolButton(
                                  _Tool.fill, Icons.format_color_fill, "Fill"),
                            ],
                          ),
                        ),
                      )
                    ],
                  ),

                  Row(
                    children: [
                      const Text("Brush:",
                          style: TextStyle(color: Colors.white70)),
                      const SizedBox(width: 8),
                      _brushChip(1),
                      _brushChip(2),
                      _brushChip(3),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _openColorPicker,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white38),
                          ),
                          child: const Text(
                            "+ Color",
                            style: TextStyle(
                                color: Colors.white, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _palette.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: 10),
                      itemBuilder: (_, index) {
                        final col = _palette[index];
                        final bool selected = col == _currentColor;
                        return GestureDetector(
                          onTap: () => setState(() => _currentColor = col),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: col,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? Colors.white
                                    : Colors.white24,
                                width: selected ? 3 : 1,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isBuilding ? null : _showSaveOptions,
                      icon: const Icon(Icons.download),
                      label: const Text("Save drawing"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.secondary,
                        foregroundColor: Colors.black,
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          _pixelBytes == null || _isBuilding
                              ? null
                              : _sharePixelArt,
                      icon: const Icon(Icons.share),
                      label: const Text("Share drawing (PDF)"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white12,
                        foregroundColor: Colors.white70,
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawGridPainter extends CustomPainter {
  final List<List<Color>> gridColors;
  final bool showGrid;

  _DrawGridPainter({
    required this.gridColors,
    required this.showGrid,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rows = gridColors.length;
    final cols = gridColors[0].length;
    final cellW = size.width / cols;
    final cellH = size.height / rows;

    final paint = Paint()..style = PaintingStyle.fill;
    final gridPaint = Paint()
      ..color = Colors.black.withOpacity(0.55)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        paint.color = gridColors[r][c];
        final rect = Rect.fromLTWH(c * cellW, r * cellH, cellW, cellH);
        canvas.drawRect(rect, paint);
        if (showGrid) canvas.drawRect(rect, gridPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DrawGridPainter old) {
    return old.gridColors != gridColors || old.showGrid != showGrid;
  }
}
