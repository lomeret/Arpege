import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/notation.dart';
import '../theme.dart';

/// A page band shown in the scene (single view, or half in spread view).
/// Reuses the "slot" notion from the old `rebuild_scene`.
class PageSlot {
  final int page;
  final double y0; // vertical portion of the page covered (0-1)
  final double y1;
  final Rect rect; // rectangle in canvas coordinates
  final ui.Image image;

  PageSlot({
    required this.page,
    required this.y0,
    required this.y1,
    required this.rect,
    required this.image,
  });

  double get band => y1 - y0;

  /// Relative page coordinates (0-1) -> canvas coordinates within the band.
  Offset relToCanvas(double relX, double relY) => Offset(
        rect.left + relX * rect.width,
        rect.top + (relY - y0) / band * rect.height,
      );

  /// Canvas coordinates -> relative page coordinates (0-1).
  Offset canvasToRel(Offset p) => Offset(
        (p.dx - rect.left) / rect.width,
        y0 + (p.dy - rect.top) / rect.height * band,
      );

  bool contains(Offset p) => rect.contains(p);
}

/// Paints the PDF pages then the annotations (symbols + strokes) on top.
class AnnotationPainter extends CustomPainter {
  final List<PageSlot> slots;
  final List<Notation> notations;
  final Map<int, List<DrawingPath>> drawings;
  final List<StrokePoint>? activeStrokePoints;
  final int? activeStrokePage;
  final Color crayonColor;
  final double crayonSize;
  final bool showLabels;

  AnnotationPainter({
    required this.slots,
    required this.notations,
    required this.drawings,
    required this.activeStrokePoints,
    required this.activeStrokePage,
    required this.crayonColor,
    required this.crayonSize,
    required this.showLabels,
    required Listenable repaint,
  }) : super(repaint: repaint);

  static Color _hexToColor(String hex) {
    final h = hex.replaceFirst('#', '');
    if (h.length != 6) return Colors.black;
    return Color(0xFF000000 | int.parse(h, radix: 16));
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final slot in slots) {
      // Drop shadow under the page.
      canvas.drawShadow(
        Path()..addRect(slot.rect),
        Colors.black.withValues(alpha: 0.8),
        14,
        false,
      );

      // Page image (vertical sub-rectangle in spread view).
      final H = slot.image.height.toDouble();
      final W = slot.image.width.toDouble();
      final src = Rect.fromLTWH(0, slot.y0 * H, W, slot.band * H);
      canvas.drawImageRect(
        slot.image,
        src,
        slot.rect,
        Paint()..filterQuality = FilterQuality.high,
      );

      // Page label (spread view only).
      if (showLabels) {
        _paintLabel(canvas, slot);
      }

      // Annotations clipped to the band.
      canvas.save();
      canvas.clipRect(slot.rect);
      _paintNotations(canvas, slot);
      _paintDrawings(canvas, slot);
      canvas.restore();
    }
  }

  double _pageHeight(PageSlot slot) => slot.rect.height / slot.band;

  void _paintLabel(Canvas canvas, PageSlot slot) {
    final pageHeight = _pageHeight(slot);
    final tp = TextPainter(
      text: TextSpan(
        text: 'page ${slot.page + 1}',
        style: TextStyle(
          color: AppColors.subtext,
          fontSize: pageHeight * 0.016,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(slot.rect.left, slot.rect.top - pageHeight * 0.024));
  }

  void _paintNotations(Canvas canvas, PageSlot slot) {
    final pageHeight = _pageHeight(slot);

    for (final n in notations) {
      if (n.page != slot.page) continue;
      final pos = slot.relToCanvas(n.relativeX, n.relativeY);
      final TextPainter tp;
      if (n.type == 'sharp' || n.type == 'flat') {
        tp = TextPainter(
          text: TextSpan(
            text: n.type == 'sharp' ? '♯' : '♭',
            style: TextStyle(
              color: AppColors.symbol,
              fontSize: pageHeight * 0.034 * n.size,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
      } else if (n.type == 'indication') {
        tp = TextPainter(
          text: TextSpan(
            text: n.text ?? '',
            style: TextStyle(
              color: AppColors.indication,
              fontSize: pageHeight * 0.022 * n.size,
              fontStyle: FontStyle.italic,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
      } else {
        continue;
      }
      tp.layout();
      tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
    }
  }

  void _paintDrawings(Canvas canvas, PageSlot slot) {
    final pagePaths = drawings[slot.page] ?? const [];
    for (final path in pagePaths) {
      _paintStroke(canvas, slot, path.points, _hexToColor(path.color), path.size);
    }
    // Stroke in progress.
    if (activeStrokePage == slot.page && activeStrokePoints != null) {
      _paintStroke(canvas, slot, activeStrokePoints!, crayonColor, crayonSize);
    }
  }

  void _paintStroke(Canvas canvas, PageSlot slot, List<StrokePoint> points,
      Color color, double size) {
    if (points.length < 2) return;
    // Width in PDF points, converted to the scale of the rendered page.
    final width = size * slot.rect.width / 595.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final path = Path();
    final first = slot.relToCanvas(points.first.relativeX, points.first.relativeY);
    path.moveTo(first.dx, first.dy);
    for (var i = 1; i < points.length; i++) {
      final p = slot.relToCanvas(points[i].relativeX, points[i].relativeY);
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant AnnotationPainter oldDelegate) => true;
}
