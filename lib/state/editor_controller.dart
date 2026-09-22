import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show AppExitResponse, Color;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'
    show AppLifecycleListener, TransformationController, VoidCallback;

import '../models/annotation_document.dart';
import '../models/bookmark.dart';
import '../models/notation.dart';
import '../pdf/pdf_renderer.dart';
import '../services/annotation_repository.dart';
import '../services/json_file.dart';
import '../services/logger.dart';
import '../services/pdf_export.dart';
import '../services/recent_files_repository.dart';
import '../theme.dart';
import 'history.dart';
import 'library_controller.dart';

enum Tool { crayon, sharp, flat, indication, eraser }

/// Eraser click tolerance, in relative coordinates.
const double kEraserTolerance = 0.03;

String _colorToHex(Color c) =>
    '#${(c.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

Color _hexToColor(String hex) {
  final h = hex.replaceFirst('#', '');
  if (h.length != 6) return AppColors.defaultCrayon;
  return Color(0xFF000000 | int.parse(h, radix: 16));
}

/// Editing state for a score + orchestration.
///
/// Owns the annotation document *and its lifecycle*: every mutation bumps a
/// revision counter, and the document is never replaced or abandoned without
/// pending changes being flushed to disk first (see [flushPendingChanges]).
class EditorController extends ChangeNotifier {
  EditorController(
    this.library, {
    AnnotationRepository? annotations,
    RecentFilesRepository? recentFiles,
    PdfRenderer? renderer,
    bool observeLifecycle = true,
  })  : _annotations = annotations ?? FileAnnotationRepository(),
        recentFiles = recentFiles ?? FileRecentFilesRepository(),
        renderer = renderer ?? PdfRenderer() {
    if (observeLifecycle) {
      // The app can be killed in the background (Android) or closed by the
      // window manager (desktop) at any moment: persist before that happens.
      _lifecycle = AppLifecycleListener(
        onHide: _flushQuietly,
        onPause: _flushQuietly,
        onDetach: _flushQuietly,
        onExitRequested: _onExitRequested,
      );
    }
  }

  final LibraryController library;
  final AnnotationRepository _annotations;

  /// Exposed so the "recent files" dialog reads the same source as the
  /// controller writes, rather than reaching for a global.
  final RecentFilesRepository recentFiles;
  AppLifecycleListener? _lifecycle;

  final PdfRenderer renderer;
  final HistoryManager history = HistoryManager();

  /// Shared with the view for zoom/pan (read by the "zoom chip").
  final TransformationController viewTransform = TransformationController();

  /// Repaints on every point added to the current stroke (avoids a full rebuild).
  final ValueNotifier<int> strokeTick = ValueNotifier<int>(0);

  // Callbacks registered by the view (need the viewport size).
  VoidCallback? fitViewCallback;
  void Function(double factor)? zoomByCallback;

  String? currentPdfPath;
  String? currentScoreId;
  String? _createdIso;

  AnnotationDocument doc = AnnotationDocument();

  int seqPos = 0;
  String? activeSetlistId;

  Tool? activeTool;
  String _crayonColorHex = _colorToHex(AppColors.defaultCrayon);

  /// Pencil stroke width, in PDF points.
  double crayonSize = 4;

  /// Scale applied to the next sharps/flats/indications placed.
  double notationSize = 1.0;

  bool spreadView = false;

  // Pencil stroke in progress (rendered by the view, committed at the end).
  List<StrokePoint>? activeStrokePoints;
  int? activeStrokePage;

  String get statusHint => _statusHint;
  String _statusHint = 'Open a score to get started  •  Ctrl+O';

  /// Last storage failure, for the UI to show. Cleared by [clearError].
  String? get lastError => _lastError;
  String? _lastError;

  void clearError() {
    if (_lastError == null) return;
    _lastError = null;
    notifyListeners();
  }

  void _reportError(String message, Object error) {
    logError(message, error);
    _lastError =
        error is StorageException ? '$message: ${error.message}' : message;
  }

  Color get crayonColor => _hexToColor(_crayonColorHex);
  String get crayonColorHex => _crayonColorHex;

  // ---- Unsaved-changes tracking -----------------------------------------

  /// Incremented by every change to [doc]; compared with the revision that
  /// was last written to disk. A counter rather than a boolean so a mutation
  /// happening *during* a save is not mistaken for saved content.
  int _revision = 0;
  int _savedRevision = 0;

  bool get hasUnsavedChanges =>
      currentPdfPath != null && _revision != _savedRevision;

  void _markDirty() => _revision++;

  void _markClean() => _savedRevision = _revision;

  /// Writes pending annotations, if any. Never throws: it runs on paths
  /// (app going to background, score switch) where there is nobody to tell.
  Future<void> flushPendingChanges() async {
    if (!hasUnsavedChanges) return;
    try {
      await saveAnnotations(silent: true);
    } catch (e, st) {
      // Callers are shutdown paths and score switches: there is nobody to
      // hand an exception to, and swallowing it here is the only place where
      // that is the right answer — the document stays marked dirty.
      logError('Could not flush pending annotations', e, st);
    }
  }

  void _flushQuietly() {
    // Fire and forget: the lifecycle callbacks are synchronous, and the
    // platform gives no guarantee about how long it will wait anyway.
    flushPendingChanges();
  }

  Future<AppExitResponse> _onExitRequested() async {
    await flushPendingChanges();
    return AppExitResponse.exit;
  }

  // ---- Page sequence ---------------------------------------------------

  List<int> get effectiveSequence {
    if (doc.pageSequence != null) return doc.pageSequence!;
    if (renderer.isOpen) return List.generate(renderer.pageCount, (i) => i);
    return const [];
  }

  int get currentSourcePage {
    final seq = effectiveSequence;
    if (seq.isEmpty) return 0;
    final pos = seqPos.clamp(0, seq.length - 1);
    return seq[pos];
  }

  bool get spreadActiveNow =>
      spreadView && seqPos + 1 < effectiveSequence.length;

  String get pageChipText {
    final seq = effectiveSequence;
    if (seq.isEmpty) return '— / —';
    final total = seq.length;
    if (spreadActiveNow) return '${seqPos + 1}-${seqPos + 2} / $total';
    return '${seqPos + 1} / $total';
  }

  // ---- Opening / loading -------------------------------------------------

  Future<void> openPdf(String path) async {
    // Never drop the current score's annotations on the floor.
    await flushPendingChanges();

    // Announce the empty state *before* the renderer disposes its cached
    // bitmaps: the view holds ui.Image handles, and painting a disposed
    // image throws. Listeners run synchronously, so the view has dropped
    // them by the time the next frame is drawn.
    _resetDocument();
    currentPdfPath = null;
    currentScoreId = null;
    notifyListeners();

    try {
      await renderer.open(path);
    } catch (e, st) {
      // The previous document is already closed at this point: leave the
      // editor empty rather than pointing at a score it can no longer render.
      logError('Could not open $path', e, st);
      _statusHint = 'Open a score to get started  •  Ctrl+O';
      notifyListeners();
      rethrow;
    }

    currentPdfPath = path;

    try {
      final stored = await _annotations.load(path);
      if (stored != null) {
        doc = stored.doc;
        _createdIso = stored.createdIso;
      }
    } catch (e, st) {
      // A copy of an unreadable file was kept aside by the repository; start
      // from a blank document rather than refusing to open the score.
      logError('Could not load annotations for $path', e, st);
      _reportError('Annotations could not be loaded, a copy was kept aside', e);
    }
    if (doc.notations.isNotEmpty) notationSize = doc.notations.last.size;
    _markClean();

    try {
      await recentFiles.add(path);
    } catch (e, st) {
      logError('Could not update the recent files list', e, st);
    }
    final score = await library.addOrTouch(path);
    currentScoreId = score.id;

    activeTool = null;
    _statusHint = '${_basename(path)}  •  ${renderer.pageCount} pages';
    notifyListeners();
  }

  void _resetDocument() {
    history.clear();
    doc = AnnotationDocument();
    _createdIso = null;
    seqPos = 0;
    _revision = 0;
    _savedRevision = 0;
  }

  /// Opens a score from the library; returns `false` if the file is missing.
  Future<bool> openScoreId(String scoreId) async {
    final score = library.getScore(scoreId);
    if (score == null) return true;
    if (!await File(score.path).exists()) return false;
    await openPdf(score.path);
    return true;
  }

  // ---- Tools --------------------------------------------------------

  void setTool(Tool? tool) {
    activeTool = tool;
    _statusHint = switch (tool) {
      null => 'No tool selected  •  drag to pan the view',
      Tool.crayon => 'Pencil  •  draw directly on the score',
      Tool.sharp => 'Sharp  •  tap where you want to place it',
      Tool.flat => 'Flat  •  tap where you want to place it',
      Tool.indication => 'Indication  •  tap then type the text',
      Tool.eraser => 'Eraser  •  tap an element to remove it',
    };
    notifyListeners();
  }

  void setCrayonColor(Color color) {
    _crayonColorHex = _colorToHex(color);
    notifyListeners();
  }

  void setCrayonSize(double size) {
    crayonSize = size;
    notifyListeners();
  }

  void setNotationSize(double size) {
    notationSize = size;
    notifyListeners();
  }

  // ---- History ----------------------------------------------------

  void _pushHistory() {
    history.push(doc.snapshot());
    _markDirty();
  }

  void undo() {
    if (!history.canUndo) return;
    final state = history.undo(doc.snapshot());
    if (state != null) {
      doc.restore(state);
      _markDirty();
      notifyListeners();
    }
  }

  void redo() {
    if (!history.canRedo) return;
    final state = history.redo(doc.snapshot());
    if (state != null) {
      doc.restore(state);
      _markDirty();
      notifyListeners();
    }
  }

  // ---- Annotations: placement --------------------------------------------

  void placeSharp(int page, double relX, double relY) {
    _pushHistory();
    doc.notations.add(Notation(
        type: 'sharp',
        page: page,
        relativeX: relX,
        relativeY: relY,
        size: notationSize));
    notifyListeners();
  }

  void placeFlat(int page, double relX, double relY) {
    _pushHistory();
    doc.notations.add(Notation(
        type: 'flat',
        page: page,
        relativeX: relX,
        relativeY: relY,
        size: notationSize));
    notifyListeners();
  }

  void placeIndication(int page, double relX, double relY, String text) {
    if (text.trim().isEmpty) return;
    _pushHistory();
    doc.notations.add(Notation(
        type: 'indication',
        page: page,
        relativeX: relX,
        relativeY: relY,
        size: notationSize,
        text: text.trim()));
    notifyListeners();
  }

  // Pencil stroke
  void beginStroke(int page, double relX, double relY) {
    activeStrokePage = page;
    activeStrokePoints = [StrokePoint(relX, relY)];
    strokeTick.value++;
  }

  void extendStroke(double relX, double relY) {
    if (activeStrokePoints == null) return;
    activeStrokePoints!.add(StrokePoint(relX, relY));
    strokeTick.value++;
  }

  void endStroke() {
    final points = activeStrokePoints;
    final page = activeStrokePage;
    activeStrokePoints = null;
    activeStrokePage = null;
    if (points != null && page != null && points.length > 1) {
      _pushHistory();
      doc.drawings
          .putIfAbsent(page, () => [])
          .add(DrawingPath(points: points, color: _crayonColorHex, size: crayonSize));
      notifyListeners();
    } else {
      strokeTick.value++;
    }
  }

  void eraseAt(int page, double relX, double relY) {
    double best = kEraserTolerance;
    Notation? bestNotation;
    int? bestPathIndex;

    for (final n in doc.notationsForPage(page)) {
      final dx = n.relativeX - relX;
      final dy = n.relativeY - relY;
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist < best) {
        best = dist;
        bestNotation = n;
        bestPathIndex = null;
      }
    }

    final drawings = doc.drawings[page] ?? const [];
    for (var i = 0; i < drawings.length; i++) {
      for (final pt in drawings[i].points) {
        final dx = pt.relativeX - relX;
        final dy = pt.relativeY - relY;
        final d = math.sqrt(dx * dx + dy * dy);
        if (d < best) {
          best = d;
          bestPathIndex = i;
          bestNotation = null;
        }
      }
    }

    if (bestNotation == null && bestPathIndex == null) return;
    _pushHistory();
    if (bestNotation != null) {
      doc.notations.remove(bestNotation);
    } else if (bestPathIndex != null) {
      doc.drawings[page]!.removeAt(bestPathIndex);
    }
    notifyListeners();
  }

  void clearCurrentPage() {
    if (currentPdfPath == null) return;
    _pushHistory();
    final page = currentSourcePage;
    doc.notations.removeWhere((n) => n.page == page);
    doc.drawings.remove(page);
    notifyListeners();
  }

  // ---- Navigation ----------------------------------------------------

  void goToSeqPos(int pos) {
    final seq = effectiveSequence;
    if (seq.isEmpty) return;
    seqPos = pos.clamp(0, seq.length - 1);
    notifyListeners();
  }

  void prevPage() => goToSeqPos(seqPos - 1);
  void nextPage() => goToSeqPos(seqPos + 1);
  void goFirst() => goToSeqPos(0);
  void goLast() => goToSeqPos(effectiveSequence.length - 1);

  void goToSourcePage(int page) {
    final seq = effectiveSequence;
    final pos = seq.indexOf(page);
    goToSeqPos(pos < 0 ? 0 : pos);
  }

  void toggleSpread(bool enabled) {
    spreadView = enabled;
    notifyListeners();
  }

  void fitView() => fitViewCallback?.call();
  void zoomIn() => zoomByCallback?.call(1.15);
  void zoomOut() => zoomByCallback?.call(1 / 1.15);

  // ---- Page management ---------------------------------------------

  List<int> get defaultSequence =>
      renderer.isOpen ? List.generate(renderer.pageCount, (i) => i) : [];

  void applyPageSequence(List<int> newSequence) {
    final current = currentSourcePage;
    final normalized =
        _listEquals(newSequence, defaultSequence) ? null : newSequence;
    doc.pageSequence = normalized;
    if (newSequence.isNotEmpty) {
      final idx = newSequence.indexOf(current);
      seqPos = idx >= 0 ? idx : seqPos.clamp(0, newSequence.length - 1);
    } else {
      seqPos = 0;
    }
    _markDirty();
    notifyListeners();
  }

  // ---- Bookmarks -------------------------------------------------------

  void addBookmark(String label) {
    if (currentPdfPath == null) return;
    final page = currentSourcePage;
    doc.bookmarks.add(Bookmark(
        label: label.trim().isEmpty ? 'Page ${page + 1}' : label.trim(),
        page: page));
    _markDirty();
    saveAnnotations(silent: true);
    notifyListeners();
  }

  void removeBookmark(String id) {
    doc.bookmarks.removeWhere((b) => b.id == id);
    _markDirty();
    saveAnnotations(silent: true);
    notifyListeners();
  }

  // ---- Setlists ------------------------------------------------------

  Future<void> stepSong(int delta) async {
    if (activeSetlistId == null) return;
    final scores = library.setlistScores(activeSetlistId!);
    final ids = scores.map((s) => s.id).toList();
    final idx = ids.indexOf(currentScoreId ?? '');
    if (idx < 0) return;
    final target = idx + delta;
    if (target >= 0 && target < ids.length) {
      await openScoreId(ids[target]);
    }
  }

  void selectSetlist(String? id) {
    activeSetlistId = id;
    notifyListeners();
  }

  // ---- Save / export -------------------------------------------

  /// Serializes saves: bookmarks, the save button and the lifecycle hooks can
  /// all fire at once, and two concurrent writes to the same file would race.
  Future<void> _saveQueue = Future<void>.value();

  Future<String?> saveAnnotations({bool silent = false}) {
    final result = _saveQueue.then((_) => _writeAnnotations(silent: silent));
    _saveQueue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<String?> _writeAnnotations({required bool silent}) async {
    final path = currentPdfPath;
    if (path == null) return null;
    // Captured before the write: a change made while it runs must keep the
    // document marked as dirty.
    final revision = _revision;
    try {
      final saved = await _annotations.save(
        pdfPath: path,
        doc: doc,
        totalPages: renderer.pageCount,
        createdIso: _createdIso,
      );
      _createdIso ??= DateTime.now().toIso8601String();
      _savedRevision = revision;
      if (!silent) _statusHint = 'Annotations saved  •  $saved';
      notifyListeners();
      return saved;
    } catch (e, st) {
      // Including failures from outside the repository (resolving the
      // storage directory, for instance): the save button must report them,
      // never throw out of a fire-and-forget call.
      logError('Annotations could not be saved', e, st);
      _reportError('Annotations could not be saved', e);
      notifyListeners();
      return null;
    }
  }

  Future<void> loadAnnotationsFromPath(String jsonPath) async {
    // Importing replaces the whole document: save what is there first.
    await flushPendingChanges();
    final loaded = await _annotations.import(jsonPath);
    _pushHistory();
    doc = loaded;
    seqPos = 0;
    _markDirty();
    notifyListeners();
  }

  Future<void> exportPdf(String destPath) async {
    if (currentPdfPath == null) return;
    await PdfExporter.export(
      sourcePdfPath: currentPdfPath!,
      destPath: destPath,
      doc: doc,
    );
    _statusHint = 'Annotated PDF exported  •  $destPath';
    notifyListeners();
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    renderer.close();
    viewTransform.dispose();
    strokeTick.dispose();
    super.dispose();
  }
}

String _basename(String path) => path.split(RegExp(r'[\\/]')).last;

bool _listEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
