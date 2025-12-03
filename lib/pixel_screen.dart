// pixel_screen.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// 🔹 Supabase + LoginScreen for logout
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';

class PixelScreen extends StatefulWidget {
  final File imageFile;
  const PixelScreen({super.key, required this.imageFile});

  @override
  State<PixelScreen> createState() => _PixelScreenState();
}

class _PixelScreenState extends State<PixelScreen> {
  Uint8List? _pixelBytes;
  bool _isProcessing = false;

  int _gridCount = 32;
  bool _useSymmetry = false;
  bool _showGrid = true;
  bool _showNumbers = false; // if later you want numbers again

  List<List<Color>>? _gridColors;
  Map<int, int> _paletteCounts = {};
  int? _highlightColor; // now we’ll actually use this 🎯

  @override
  void initState() {
    super.initState();
    _generatePixelArt();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Future<void> _generatePixelArt() async {
    setState(() => _isProcessing = true);

    try {
      final bytes = await widget.imageFile.readAsBytes();
      final img.Image? original = img.decodeImage(bytes);
      if (original == null) {
        _showSnack('Could not decode image');
        setState(() => _isProcessing = false);
        return;
      }

      // 1) crop to center square
      final int side =
          original.width < original.height ? original.width : original.height;
      final int offsetX = (original.width - side) ~/ 2;
      final int offsetY = (original.height - side) ~/ 2;

      final img.Image square = img.copyCrop(
        original,
        x: offsetX,
        y: offsetY,
        width: side,
        height: side,
      );

      // 2) resize to grid resolution
      final img.Image small = img.copyResize(
        square,
        width: _gridCount,
        height: _gridCount,
        interpolation: img.Interpolation.average,
      );

      // 3) optional mirror symmetry
      if (_useSymmetry) {
        final int half = small.width ~/ 2;
        for (int y = 0; y < small.height; y++) {
          for (int x = 0; x < half; x++) {
            final px = small.getPixel(x, y);
            final int mx = small.width - 1 - x;
            small.setPixelRgba(
              mx,
              y,
              px.r.toInt(),
              px.g.toInt(),
              px.b.toInt(),
              px.a.toInt(),
            );
          }
        }
      }

      // 4) build grid + palette
      final List<List<Color>> grid = List.generate(
        _gridCount,
        (_) => List<Color>.filled(_gridCount, Colors.transparent),
      );
      final Map<int, int> paletteCounts = {};

      for (int y = 0; y < small.height; y++) {
        for (int x = 0; x < small.width; x++) {
          final px = small.getPixel(x, y);
          final int argb = (px.a.toInt() << 24) |
              (px.r.toInt() << 16) |
              (px.g.toInt() << 8) |
              px.b.toInt();
          grid[y][x] = Color(argb);
          paletteCounts[argb] = (paletteCounts[argb] ?? 0) + 1;
        }
      }

      // 5) enlarge back to big square for preview / saving
      final img.Image big = img.copyResize(
        small,
        width: 900,
        height: 900,
        interpolation: img.Interpolation.nearest,
      );
      final png = Uint8List.fromList(img.encodePng(big));

      setState(() {
        _pixelBytes = png;
        _isProcessing = false;
        _gridColors = grid;
        _paletteCounts = paletteCounts;
      });
    } catch (e) {
      _showSnack('Error: $e');
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _savePixelArt() async {
    if (_pixelBytes == null) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory('${dir.path}/pixel_art');
      if (!await folder.exists()) await folder.create();
      final file = File(
        '${folder.path}/pixel_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(_pixelBytes!, flush: true);
      _showSnack('Saved:\n${file.path}');
    } catch (e) {
      _showSnack('Save failed: $e');
    }
  }

  // ⭐ Share pixel art as a simple one-page PDF
  Future<void> _sharePixelArt() async {
    if (_pixelBytes == null) return;
    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Image(
                pw.MemoryImage(_pixelBytes!),
                width: 400,
                height: 400,
                fit: pw.BoxFit.contain,
              ),
            );
          },
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'pixel_art.pdf',
      );
    } catch (e) {
      _showSnack('Share failed: $e');
    }
  }

  Future<void> _logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {
      // ignore error, still go back to login
    }
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _onSettingsChanged() => _generatePixelArt();

  void _openInstructions() async {
    if (_gridColors == null || _pixelBytes == null) return;

    final selectedColor = await Navigator.push<int?>(
      context,
      MaterialPageRoute(
        builder: (_) => InstructionsScreen(
          gridColors: _gridColors!,
          paletteCounts: _paletteCounts,
          pixelImage: _pixelBytes!,
        ),
      ),
    );

    if (selectedColor != null) {
      setState(() => _highlightColor = selectedColor);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFF070812),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070812),
        elevation: 0,
        title: const Text(
          'Pixel Grid',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildPreview()),
            _buildControls(colors),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (_isProcessing) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_pixelBytes == null) {
      return const Center(
        child: Text('Processing...', style: TextStyle(color: Colors.white)),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (_, c) {
          final size = c.biggest.shortestSide;
          return SizedBox(
            width: size,
            height: size,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _pixelBytes!,
                    fit: BoxFit.contain,
                  ),
                ),
                if (_showGrid)
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _GridPainter(
                        squares: _gridCount,
                        lineColor: Colors.white24,
                      ),
                    ),
                  ),

                // ⭐ NEW: highlight selected color from instructions
                if (_highlightColor != null && _gridColors != null)
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _HighlightPainter(
                        gridColors: _gridColors!,
                        squares: _gridCount,
                        highlightValue: _highlightColor!,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildControls(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      decoration: const BoxDecoration(
        color: Color(0xFF111320),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            const Text('Grid:', style: TextStyle(color: Colors.white70)),
            Expanded(
              child: Slider(
                value: _gridCount.toDouble(),
                min: 8,
                max: 64,
                divisions: 7,
                label: '$_gridCount',
                onChanged: (v) => setState(() => _gridCount = v.round()),
                onChangeEnd: (_) => _onSettingsChanged(),
              ),
            ),
            Text('$_gridCount', style: const TextStyle(color: Colors.white70)),
          ]),
          Row(children: [
            Switch(
              value: _useSymmetry,
              onChanged: (v) {
                setState(() => _useSymmetry = v);
                _onSettingsChanged();
              },
              activeColor: colors.secondary,
            ),
            const Text('Mirror', style: TextStyle(color: Colors.white70)),
            const Spacer(),
            Checkbox(
              value: _showGrid,
              onChanged: (v) => setState(() => _showGrid = v ?? true),
              activeColor: colors.secondary,
            ),
            const Text('Grid', style: TextStyle(color: Colors.white70)),
          ]),
          const SizedBox(height: 8),
          _btn(
            "View drawing instructions",
            Icons.list_alt,
            _gridColors != null && _pixelBytes != null,
            _openInstructions,
          ),
          const SizedBox(height: 8),
          _btn(
            "Save pixel art (PNG)",
            Icons.download,
            _pixelBytes != null,
            _savePixelArt,
          ),
          const SizedBox(height: 8),
          _btn(
            "Share pixel art (PDF)",
            Icons.share,
            _pixelBytes != null,
            _sharePixelArt,
          ),
        ],
      ),
    );
  }

  Widget _btn(String txt, IconData icon, bool active, VoidCallback f) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: active ? f : null,
        icon: Icon(icon),
        label: Text(txt),
        style: ElevatedButton.styleFrom(
          backgroundColor: active ? colors.secondary : Colors.white12,
          foregroundColor: active ? Colors.black : Colors.white38,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final int squares;
  final Color lineColor;
  _GridPainter({required this.squares, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = lineColor
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;
    final w = size.width / squares;
    final h = size.height / squares;
    for (int i = 0; i <= squares; i++) {
      canvas.drawLine(Offset(i * w, 0), Offset(i * w, size.height), p);
      canvas.drawLine(Offset(0, i * h), Offset(size.width, i * h), p);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ⭐ NEW: painter to highlight the selected color cells
class _HighlightPainter extends CustomPainter {
  final List<List<Color>> gridColors;
  final int squares;
  final int highlightValue;

  _HighlightPainter({
    required this.gridColors,
    required this.squares,
    required this.highlightValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (gridColors.isEmpty) return;

    final double cellW = size.width / squares;
    final double cellH = size.height / squares;

    final Paint outline = Paint()
      ..color = Colors.yellowAccent.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final Paint fill = Paint()
      ..color = Colors.yellowAccent.withOpacity(0.18)
      ..style = PaintingStyle.fill;

    for (int r = 0; r < gridColors.length; r++) {
      for (int c = 0; c < gridColors[r].length; c++) {
        if (gridColors[r][c].value == highlightValue) {
          final rect = Rect.fromLTWH(
            c * cellW,
            r * cellH,
            cellW,
            cellH,
          );
          canvas.drawRect(rect, fill);
          canvas.drawRect(rect, outline);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HighlightPainter oldDelegate) {
    return oldDelegate.highlightValue != highlightValue ||
        oldDelegate.gridColors != gridColors ||
        oldDelegate.squares != squares;
  }
}

// ===================== INSTRUCTIONS SCREEN =====================

class InstructionsScreen extends StatefulWidget {
  final List<List<Color>> gridColors;
  final Map<int, int> paletteCounts;
  final Uint8List pixelImage;

  const InstructionsScreen({
    super.key,
    required this.gridColors,
    required this.paletteCounts,
    required this.pixelImage,
  });

  @override
  State<InstructionsScreen> createState() => _InstructionsScreenState();
}

class _InstructionsScreenState extends State<InstructionsScreen> {
  int? _selectedColor;
  List<_CellInfo> _cells = [];

  void _select(int argb) {
    _selectedColor = argb;
    _cells = [];
    for (int r = 0; r < widget.gridColors.length; r++) {
      for (int c = 0; c < widget.gridColors[r].length; c++) {
        if (widget.gridColors[r][c].value == argb) {
          _cells.add(_CellInfo(r + 1, c + 1));
        }
      }
    }
    setState(() {});
    // send selected color back to main screen when popping
    Navigator.pop(context, argb);
  }

  Map<int, List<int>> _groupByRow(List<_CellInfo> list) {
    final map = <int, List<int>>{};
    for (var e in list) {
      map[e.row] = (map[e.row] ?? [])..add(e.col);
    }
    return map;
  }

  /// PDF: only the pixel image
  Future<void> _downloadPDF() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Image(
              pw.MemoryImage(widget.pixelImage),
              width: 400,
              height: 400,
              fit: pw.BoxFit.contain,
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  // ---------- Color naming + saturation ----------

  double _saturation(Color c) {
    final r = c.red / 255.0;
    final g = c.green / 255.0;
    final b = c.blue / 255.0;

    final maxC = math.max(r, math.max(g, b));
    final minC = math.min(r, math.min(g, b));
    final l = (maxC + minC) / 2.0;

    if (maxC == minC) return 0.0;

    final s = l < 0.5
        ? (maxC - minC) / (maxC + minC)
        : (maxC - minC) / (2.0 - maxC - minC);
    return s;
  }

  String _getNearestName(Color c) {
    int r = c.red;
    int g = c.green;
    int b = c.blue;
    final sat = _saturation(c);

    // Black / White / Gray
    if (r < 40 && g < 40 && b < 40) return "Black";
    if (r > 220 && g > 220 && b > 220) return "White";
    if (sat < 0.15) {
      return r < 130 ? "Dark Gray" : "Light Gray";
    }

    // Blue / Purple family
    if (b > r && b > g) {
      if (r > 180) return "Purple";
      if (g > 160) return "Sky Blue";
      return b > 180 ? "Blue" : "Dark Blue";
    }

    // Red / Pink / Orange family
    if (r > g && r > b) {
      if (b > 140) return "Pink";
      if (g > 160) return "Orange";
      return r > 170 ? "Red" : "Dark Red";
    }

    // Green family
    if (g > r && g > b) {
      if (r > 140) return "Lime";
      return g > 170 ? "Green" : "Dark Green";
    }

    return "Color";
  }

  @override
  Widget build(BuildContext context) {
    // sort by saturation (vivid colors first), then by count
    final palette = widget.paletteCounts.entries.toList()
      ..sort((a, b) {
        final ca = Color(a.key);
        final cb = Color(b.key);
        final sa = _saturation(ca);
        final sb = _saturation(cb);
        if (sa != sb) return sb.compareTo(sa); // vivid first
        return b.value.compareTo(a.value); // then more blocks
      });

    return Scaffold(
      backgroundColor: const Color(0xFF070812),
      appBar: AppBar(
        title: const Text(
          "Drawing Instructions",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF070812),
        elevation: 0,
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _downloadPDF,
        label: const Text("Download PDF"),
        icon: const Icon(Icons.picture_as_pdf),
        backgroundColor: Colors.pinkAccent,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              const Text(
                "Tap any color box",
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 10),

              // Color boxes row
              SizedBox(
                height: 120,
                child: GridView.count(
                  scrollDirection: Axis.horizontal,
                  crossAxisCount: 2,
                  children: palette.map((e) {
                    final argb = e.key;
                    final selected = _selectedColor == argb;
                    return GestureDetector(
                      onTap: () => _select(argb),
                      child: Container(
                        margin: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Color(argb),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selected ? Colors.white : Colors.black,
                            width: selected ? 2.4 : 1,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Palette list with names
              Expanded(
                child: ListView(
                  children: palette.asMap().entries.map((e) {
                    final idx = e.key;
                    final argb = e.value.key;
                    final count = e.value.value;
                    final selected = _selectedColor == argb;
                    final name = _getNearestName(Color(argb));

                    return ListTile(
                      onTap: () => _select(argb),
                      leading: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Color(argb),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: selected ? Colors.white : Colors.white24,
                            width: selected ? 2 : 1,
                          ),
                        ),
                      ),
                      title: Text(
                        "Color ${idx + 1}: $name — $count blocks",
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Row/column instructions
              Expanded(
                child: _selectedColor == null
                    ? const Center(
                        child: Text(
                          "Tap a color to see block positions",
                          style: TextStyle(color: Colors.white54, fontSize: 14),
                        ),
                      )
                    : ListView(
                        children: _groupByRow(_cells).entries.map((e) {
                          final row = e.key;
                          final cols = e.value;
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "Row $row → Col ${cols.join(", ")}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CellInfo {
  final int row;
  final int col;
  _CellInfo(this.row, this.col);
}
