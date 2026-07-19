import 'notation.dart';
import 'bookmark.dart';

/// Ensemble des annotations d'une partition (une entrée par PDF).
///
/// Sérialisation strictement compatible avec l'ancien format de `main.py`
/// (`save_annotations` / `_restore_annotations`), pour reprendre les fichiers
/// `~/Documents/Arpège/annotations/<nom>_annotations.json` existants.
class AnnotationDocument {
  List<Notation> notations;
  Map<int, List<DrawingPath>> drawings;
  List<dynamic> generalAnnotations; // vestige : conservé pour fidélité de round-trip
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
        // Peut être une liste de tracés (dicts) ou l'ancien format (liste de points).
        if (value.isNotEmpty &&
            value.first is Map &&
            (value.first as Map).containsKey('relative_x')) {
          // Ancien format : une liste simple de points → un seul tracé.
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

  /// Construit la structure de fichier complète (identique à `save_annotations`).
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

  /// Instantané profond pour l'historique undo/redo.
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

/// Instantané des seules données annotables (notations + tracés), pour l'historique.
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
