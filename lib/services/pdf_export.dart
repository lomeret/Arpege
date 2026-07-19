import 'dart:io';
import 'dart:ui' show Offset, Rect;

import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/annotation_document.dart';

/// Fusionne les annotations dans une copie vectorielle du PDF source.
/// Port de `features/pdf_export.py` (dièses/bémols/indications/tracés).
class PdfExporter {
  static const String _defaultColor = '#e74c3c';
  static const String _indicationColor = '#27ae60';

  static PdfColor _hexToColor(String hex) {
    final h = hex.replaceFirst('#', '');
    if (h.length != 6) return PdfColor(0, 0, 0);
    return PdfColor(
      int.parse(h.substring(0, 2), radix: 16),
      int.parse(h.substring(2, 4), radix: 16),
      int.parse(h.substring(4, 6), radix: 16),
    );
  }

  static void _drawSharp(
      PdfGraphics g, double x, double y, double size, PdfColor color) {
    final half = size / 2;
    final slant = size * 0.12;
    final pen = PdfPen(color, width: 1.4);
    g.drawLine(pen, Offset(x - half * 0.5 - slant, y - half),
        Offset(x - half * 0.5 + slant, y + half));
    g.drawLine(pen, Offset(x + half * 0.5 - slant, y - half),
        Offset(x + half * 0.5 + slant, y + half));
    g.drawLine(pen, Offset(x - half, y - half * 0.35),
        Offset(x + half, y - half * 0.55));
    g.drawLine(pen, Offset(x - half, y + half * 0.55),
        Offset(x + half, y + half * 0.35));
  }

  static void _drawFlat(
      PdfGraphics g, double x, double y, double size, PdfColor color) {
    final half = size / 2;
    final pen = PdfPen(color, width: 1.4);
    // Hampe verticale.
    g.drawLine(pen, Offset(x - half * 0.4, y - half),
        Offset(x - half * 0.4, y + half * 0.7));
    // Panse arrondie pleine.
    g.drawEllipse(
      Rect.fromLTWH(x - half * 0.4, y, half * 1.0, half * 0.9),
      pen: pen,
      brush: PdfSolidBrush(color),
    );
  }

  /// Écrit le PDF annoté dans [destPath].
  static Future<void> export({
    required String sourcePdfPath,
    required String destPath,
    required AnnotationDocument doc,
  }) async {
    final bytes = await File(sourcePdfPath).readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    try {
      final defaultRgb = _hexToColor(_defaultColor);
      final indicationRgb = _hexToColor(_indicationColor);

      for (var i = 0; i < document.pages.count; i++) {
        final page = document.pages[i];
        final g = page.graphics;
        final size = page.getClientSize();
        final pageWidth = size.width;
        final pageHeight = size.height;

        // Notations musicales.
        for (final n in doc.notationsForPage(i)) {
          final absX = n.relativeX * pageWidth;
          final absY = n.relativeY * pageHeight;
          final symbolSize =
              (pageWidth > pageHeight ? pageWidth : pageHeight) * 0.02;

          if (n.type == 'sharp') {
            _drawSharp(g, absX, absY, symbolSize, defaultRgb);
          } else if (n.type == 'flat') {
            _drawFlat(g, absX, absY, symbolSize, defaultRgb);
          } else if (n.type == 'indication') {
            final text = n.text ?? '';
            if (text.isNotEmpty) {
              final fontSize = (symbolSize * 1.2) < 10 ? 10.0 : symbolSize * 1.2;
              g.drawString(
                text,
                PdfStandardFont(PdfFontFamily.helvetica, fontSize),
                brush: PdfSolidBrush(indicationRgb),
                bounds: Rect.fromLTWH(absX, absY, pageWidth, fontSize * 2),
              );
            }
          }
        }

        // Tracés au crayon.
        for (final path in doc.drawingsForPage(i)) {
          final rgb = _hexToColor(path.color);
          final pen = PdfPen(rgb, width: path.size);
          for (var k = 0; k < path.points.length - 1; k++) {
            final p1 = path.points[k];
            final p2 = path.points[k + 1];
            g.drawLine(
              pen,
              Offset(p1.relativeX * pageWidth, p1.relativeY * pageHeight),
              Offset(p2.relativeX * pageWidth, p2.relativeY * pageHeight),
            );
          }
        }
      }

      final out = await document.save();
      await File(destPath).writeAsBytes(out);
    } finally {
      document.dispose();
    }
  }
}
