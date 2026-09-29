import 'notation.dart';
import 'bookmark.dart';

/// All annotations for a score (one entry per PDF).
///
/// Serialization strictly compatible with the old `main.py` format
/// (`save_annotations` / `_restore_annotations`), so existing
/// `~/Documents/Arpège/annotations/<name>_annotations.json` files still load.
class AnnotationDocument {
  List<Notation> notations;
  Map<int, List<DrawingPath>> drawings;
  List<dynamic> generalAnnotations; // legacy leftover: kept for round-trip fidelity
  List<Bookmark> bookmarks;
  List<int>? pageSequence;

  AnnotationDocument({
    List<Notation>? notations,
    Map<int, List<DrawingPath>>? drawings,
    List<dynamic>? generalAnnotations,
    List<Bookmark>? bookmarks,
    this.pageSequence,
  })  : notations = notations ?? [],
        drawings = drawings ?? {},
        generalAnnotations = generalAnnotations ?? [],
        bookmarks = bookmarks ?? [];

  List<Notation> notationsForPage(int page) =>
      notations.where((n) => n.page == page).toList();

  List<DrawingPath> drawingsForPage(int page) => drawings[page] ?? const [];

  factory AnnotationDocument.fromJson(Map<String, dynamic> data) {
    final annotations =
        Map<String, dynamic>.from((data['annotations'] as Map?) ?? {});

    final notations = ((annotations['music_notations'] as List?) ?? const [])
        .map((n) => Notation.fromJson(Map<String, dynamic>.from(n as Map)))
        .toList();

    final drawings = <int, List<DrawingPath>>{};
    final rawDrawings =
        Map<String, dynamic>.from((annotations['drawings'] as Map?) ?? {});
    rawDrawings.forEach((pageStr, value) {
      final page = int.parse(pageStr);
      if (value is List) {
        // Can be a list of paths (dicts) or the old format (a list of points).
        if (value.isNotEmpty &&
            value.first is Map &&
            (value.first as Map).containsKey('relative_x')) {
          // Legacy format: a plain list of points -> a single path.
          drawings[page] = [DrawingPath.fromJson(value)];
        } else {
          drawings[page] = value.map((d) => DrawingPath.fromJson(d)).toList();
        }
      } else {
        drawings[page] = [];
      }
    });

    final bookmarks = ((data['bookmarks'] as List?) ?? const [])
        .map((b) => Bookmark.fromJson(Map<String, dynamic>.from(b as Map)))
        .toList();

    final seq = data['page_sequence'];
    final pageSequence =
        seq is List ? seq.map((e) => (e as num).toInt()).toList() : null;

    return AnnotationDocument(
      notations: notations,
      drawings: drawings,
      generalAnnotations:
          List<dynamic>.from((annotations['general_annotations'] as List?) ?? []),
      bookmarks: bookmarks,
      pageSequence: pageSequence,
    );
  }

  /// Builds the full file structure (identical to `save_annotations`).
  Map<String, dynamic> toFileJson({
    required String pdfPath,
    required String pdfName,
    required int totalPages,
    required String nowIso,
    String? createdIso,
  }) {
    final drawingsJson = <String, dynamic>{};
    drawings.forEach((page, paths) {
      drawingsJson['$page'] = paths.map((p) => p.toJson()).toList();
    });

    return {
      'pdf_file': pdfPath,
      'pdf_name': pdfName,
      'created_date': createdIso ?? nowIso,
      'last_modified': nowIso,
      'total_pages': totalPages,
      'bookmarks': bookmarks.map((b) => b.toJson()).toList(),
      'page_sequence': pageSequence,
      'annotations': {
        'music_notations': notations.map((n) => n.toJson()).toList(),
        'drawings': drawingsJson,
        'general_annotations': generalAnnotations,
      },
    };
  }

  /// Deep snapshot for undo/redo history.
  AnnotationSnapshot snapshot() => AnnotationSnapshot(
        notations: notations.map((n) => n.copy()).toList(),
        drawings: {
          for (final entry in drawings.entries)
            entry.key: entry.value.map((p) => p.copy()).toList(),
        },
      );

  void restore(AnnotationSnapshot snap) {
    notations = snap.notations.map((n) => n.copy()).toList();
    drawings = {
      for (final entry in snap.drawings.entries)
        entry.key: entry.value.map((p) => p.copy()).toList(),
    };
  }
}

/// Snapshot of the annotatable data only (notations + strokes), for history.
class AnnotationSnapshot {
  final List<Notation> notations;
  final Map<int, List<DrawingPath>> drawings;

  AnnotationSnapshot({required this.notations, required this.drawings});

  AnnotationSnapshot copy() => AnnotationSnapshot(
        notations: notations.map((n) => n.copy()).toList(),
        drawings: {
          for (final entry in drawings.entries)
            entry.key: entry.value.map((p) => p.copy()).toList(),
        },
      );
}
