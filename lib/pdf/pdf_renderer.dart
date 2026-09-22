import 'dart:ui' as ui;

import 'package:pdfrx/pdfrx.dart';

/// Wraps pdfrx: opens a PDF and renders each page to a cached bitmap image.
/// Replaces the PyMuPDF rendering from `features/pdf_viewer.py`.
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

  /// Page dimensions in PDF points (72 dpi).
  ui.Size pageSize(int index) {
    final page = _doc!.pages[index];
    return ui.Size(page.width, page.height);
  }

  /// Renders a page to a `ui.Image` at [renderDpi] (result is cached).
  Future<ui.Image> renderPage(int index) async {
    final cached = _cache[index];
    if (cached != null) return cached;

    final page = _doc!.pages[index];
    const scale = renderDpi / 72.0;

    // fullWidth/fullHeight must be supplied: otherwise pdfrx draws the page
    // at its point size (72 dpi) in the top-left corner of a larger bitmap,
    // leaving the rest blank. Passing them makes the page fill the bitmap.
    final fullW = page.width * scale;
    final fullH = page.height * scale;

    final rendered = await page.render(fullWidth: fullW, fullHeight: fullH);
    if (rendered == null) {
      throw StateError('Failed to render page ${index + 1}');
    }
    final image = await rendered.createImage();
    rendered.dispose();
    _cache[index] = image;
    return image;
  }
}
