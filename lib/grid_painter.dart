// lib/grid_painter.dart
import 'dart:ui';
import 'package:flutter/material.dart';

class GridPainter extends CustomPainter {
  final int rows;
  final int cols;
  final Color lineColor;

  GridPainter({
    required this.rows,
    required this.cols,
    this.lineColor = const Color.fromARGB(120, 255, 255, 255),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 0.7;

    double cellW = size.width / cols;
    double cellH = size.height / rows;

    for (int c = 0; c <= cols; c++) {
      canvas.drawLine(
        Offset(c * cellW, 0),
        Offset(c * cellW, size.height),
        paint,
      );
    }

    for (int r = 0; r <= rows; r++) {
      canvas.drawLine(
        Offset(0, r * cellH),
        Offset(size.width, r * cellH),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
