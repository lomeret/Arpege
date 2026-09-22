import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show TransformationController, VoidCallback;

import '../models/annotation_document.dart';
import '../models/bookmark.dart';
import '../models/notation.dart';
import '../pdf/pdf_renderer.dart';
import '../services/annotation_store.dart';
import '../services/pdf_export.dart';
import '../services/recent_files.dart';
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

/// Editing state for a score + orchestration (port of `ArpegeWindow`).
class EditorController extends ChangeNotifier {
  EditorController(this.library);

  final LibraryController library;
  final PdfRenderer renderer = PdfRenderer();
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

  Color get crayonColor => _hexToColor(_crayonColorHex);
  String get crayonColorHex => _crayonColorHex;

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
    history.clear();
    doc = AnnotationDocument();
    seqPos = 0;
    currentPdfPath = path;

    await renderer.open(path);
    final loaded = await AnnotationStore.load(path);
    if (loaded != null) doc = loaded;
    if (doc.notations.isNotEmpty) notationSize = doc.notations.last.size;
    _createdIso = await AnnotationStore.existingCreatedDate(path);

    await RecentFiles.add(path);
    final score = await library.addOrTouch(path);
    currentScoreId = score.id;

    activeTool = null;
    _statusHint = '${_basename(path)}  •  ${renderer.pageCount} pages';
    notifyListeners();
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

  void _pushHistory() => history.push(doc.snapshot());

  void undo() {
    if (!history.canUndo) return;
    final state = history.undo(doc.snapshot());
    if (state != null) {
      doc.restore(state);
      notifyListeners();
    }
  }

  void redo() {
    if (!history.canRedo) return;
    final state = history.redo(doc.snapshot());
    if (state != null) {
      doc.restore(state);
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
    notifyListeners();
  }

  // ---- Bookmarks -------------------------------------------------------

  void addBookmark(String label) {
    if (currentPdfPath == null) return;
    final page = currentSourcePage;
    doc.bookmarks.add(Bookmark(
        label: label.trim().isEmpty ? 'Page ${page + 1}' : label.trim(),
        page: page));
    saveAnnotations(silent: true);
    notifyListeners();
  }

  void removeBookmark(String id) {
    doc.bookmarks.removeWhere((b) => b.id == id);
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

  Future<String?> saveAnnotations({bool silent = false}) async {
    if (currentPdfPath == null) return null;
    final path = await AnnotationStore.save(
      pdfPath: currentPdfPath!,
      doc: doc,
      totalPages: renderer.pageCount,
      createdIso: _createdIso,
    );
    _createdIso ??= DateTime.now().toIso8601String();
    if (!silent) {
      _statusHint = 'Annotations saved  •  $path';
      notifyListeners();
    }
    return path;
  }

  Future<void> loadAnnotationsFromPath(String jsonPath) async {
    _pushHistory();
    final loaded = await AnnotationStore.loadFromPath(jsonPath);
    doc = loaded;
    seqPos = 0;
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
