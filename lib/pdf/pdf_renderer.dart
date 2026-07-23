import 'dart:ui' as ui;

import 'package:pdfrx/pdfrx.dart';

/// Enveloppe pdfrx : ouvre un PDF et rend chaque page en image bitmap (cache).
/// Remplace le rendu PyMuPDF de `features/pdf_viewer.py`.
class PdfRenderer {
  static const double renderDpi = 200;

  PdfDocument? _doc;
  final Map<int, ui.Image> _cache = {};

  bool get isOpen => _doc != null;
  int get pageCount => _doc?.pages.length ?? 0;

  Future<void> open(String path) async {
    await close();
    _doc = await PdfDocument.openFile(path);
  }

  Future<void> close() async {
    for (final img in _cache.values) {
      img.dispose();
    }
    _cache.clear();
    await _doc?.dispose();
    _doc = null;
  }

  /// Dimensions de la page en points PDF (72 dpi).
  ui.Size pageSize(int index) {
    final page = _doc!.pages[index];
    return ui.Size(page.width, page.height);
  }

  /// Rend une page en `ui.Image` à [renderDpi] (résultat mis en cache).
  Future<ui.Image> renderPage(int index) async {
    final cached = _cache[index];
    if (cached != null) return cached;

    final page = _doc!.pages[index];
    const scale = renderDpi / 72.0;

    // On doit fournir fullWidth/fullHeight : sinon pdfrx dessine la page à sa
    // taille en points (72 dpi) dans le coin haut-gauche d'un bitmap plus grand,
    // laissant le reste en blanc. En les passant, la page remplit tout le bitmap.
    final fullW = page.width * scale;
    final fullH = page.height * scale;

    final rendered = await page.render(fullWidth: fullW, fullHeight: fullH);
    if (rendered == null) {
      throw StateError('Échec du rendu de la page ${index + 1}');
    }
    final image = await rendered.createImage();
    rendered.dispose();
    _cache[index] = image;
    return image;
  }
}
