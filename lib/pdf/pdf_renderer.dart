import 'dart:collection';
import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:pdfrx/pdfrx.dart';

import '../services/logger.dart';

/// Wraps pdfrx: opens a PDF and renders pages to bitmaps, behind two bounded
/// LRU caches — one for full-resolution pages, one for thumbnails.
///
/// A full page at [renderDpi] costs ~15 MB (A4), so an unbounded cache runs
/// a device out of memory on any sizeable score. Eviction disposes the
/// image, which is only safe because the caches keep far more entries than
/// can be displayed at once: the pages being painted are always the most
/// recently requested ones, so they are never the eviction candidates.
class PdfRenderer {
  PdfRenderer({int? maxPageCacheBytes})
      : maxPageCacheBytes = maxPageCacheBytes ?? _defaultPageCacheBytes;

  /// Resolution used for the page being read.
  static const double renderDpi = 200;

  /// Resolution used for the page-manager thumbnails (~40x56 px on screen).
  static const double thumbnailDpi = 24;

  /// Mobile devices get a much smaller per-process memory budget than a
  /// desktop, and are the ones that actually get killed for exceeding it.
  static int get _defaultPageCacheBytes =>
      Platform.isAndroid || Platform.isIOS ? 96 << 20 : 256 << 20;

  /// Never evicted below this many pages, whatever the byte budget: the view
  /// holds at most two at a time (spread mode), plus a margin for prefetch.
  static const int minCachedPages = 4;

  /// Thumbnails are small (~220 KB each at [thumbnailDpi]); bounding them by
  /// count is enough, and stays well above the number visible in the dialog.
  static const int maxCachedThumbnails = 64;

  final int maxPageCacheBytes;

  PdfDocument? _doc;

  // LinkedHashMap preserves insertion order: the first key is the least
  // recently used, because a hit re-inserts its entry at the end.
  final LinkedHashMap<int, ui.Image> _pages = LinkedHashMap<int, ui.Image>();
  final LinkedHashMap<int, ui.Image> _thumbnails = LinkedHashMap<int, ui.Image>();
  int _pageCacheBytes = 0;

  bool get isOpen => _doc != null;
  int get pageCount => _doc?.pages.length ?? 0;

  /// Current size of the full-resolution cache, in bytes (for diagnostics).
  int get cachedPageBytes => _pageCacheBytes;
  int get cachedPageCount => _pages.length;

  Future<void> open(String path) async {
    await close();
    _doc = await PdfDocument.openFile(path);
  }

  Future<void> close() async {
    _clearCaches();
    await _doc?.dispose();
    _doc = null;
  }

  void _clearCaches() {
    for (final img in _pages.values) {
      img.dispose();
    }
    _pages.clear();
    _pageCacheBytes = 0;
    for (final img in _thumbnails.values) {
      img.dispose();
    }
    _thumbnails.clear();
  }

  /// Page dimensions in PDF points (72 dpi).
  ui.Size pageSize(int index) {
    final doc = _doc;
    if (doc == null) return ui.Size.zero;
    final page = doc.pages[index];
    return ui.Size(page.width, page.height);
  }

  /// Renders a page at [renderDpi]. Cached, with the cache bounded by
  /// [maxPageCacheBytes].
  Future<ui.Image> renderPage(int index) async {
    final cached = _pages.remove(index);
    if (cached != null) {
      _pages[index] = cached; // touch: move to most-recently-used
      return cached;
    }

    final image = await _render(index, renderDpi);
    _pages[index] = image;
    _pageCacheBytes += _bytesOf(image);
    _evictPages();
    return image;
  }

  /// Renders a small preview of a page, for lists of thumbnails.
  ///
  /// Kept apart from [renderPage] so scrolling a 200-page document in the
  /// page manager cannot flush the full-resolution page being read.
  Future<ui.Image> renderThumbnail(int index) async {
    final cached = _thumbnails.remove(index);
    if (cached != null) {
      _thumbnails[index] = cached;
      return cached;
    }

    final image = await _render(index, thumbnailDpi);
    _thumbnails[index] = image;
    while (_thumbnails.length > maxCachedThumbnails) {
      _thumbnails.remove(_thumbnails.keys.first)?.dispose();
    }
    return image;
  }

  void _evictPages() {
    while (_pageCacheBytes > maxPageCacheBytes && _pages.length > minCachedPages) {
      final oldest = _pages.keys.first;
      final image = _pages.remove(oldest);
      if (image == null) break;
      _pageCacheBytes -= _bytesOf(image);
      image.dispose();
      logInfo('Evicted page ${oldest + 1} from the render cache');
    }
  }

  static int _bytesOf(ui.Image image) => image.width * image.height * 4;

  Future<ui.Image> _render(int index, double dpi) async {
    final doc = _doc;
    if (doc == null) {
      throw StateError('No PDF is open');
    }
    final page = doc.pages[index];
    final scale = dpi / 72.0;

    // fullWidth/fullHeight must be supplied: otherwise pdfrx draws the page
    // at its point size (72 dpi) in the top-left corner of a larger bitmap,
    // leaving the rest blank. Passing them makes the page fill the bitmap.
    final rendered = await page.render(
      fullWidth: page.width * scale,
      fullHeight: page.height * scale,
    );
    if (rendered == null) {
      throw StateError('Failed to render page ${index + 1}');
    }
    try {
      return await rendered.createImage();
    } finally {
      rendered.dispose();
    }
  }
}
