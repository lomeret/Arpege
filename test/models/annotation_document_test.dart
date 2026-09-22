import 'package:flutter_test/flutter_test.dart';

import 'package:arpege/models/annotation_document.dart';
import 'package:arpege/models/bookmark.dart';
import 'package:arpege/models/notation.dart';

void main() {
  group('AnnotationDocument.toFileJson / fromJson round-trip', () {
    test('preserves notations, drawings, bookmarks and page sequence', () {
      final doc = AnnotationDocument(
        notations: [
          Notation(type: 'sharp', page: 0, relativeX: 0.1, relativeY: 0.2, size: 1.5),
          Notation(
              type: 'indication',
              page: 1,
              relativeX: 0.3,
              relativeY: 0.4,
              text: 'rit.'),
        ],
        drawings: {
          0: [
            DrawingPath(
              points: [StrokePoint(0.0, 0.0), StrokePoint(1.0, 1.0)],
              color: '#ff0000',
              size: 5,
            ),
          ],
        },
        bookmarks: [Bookmark(id: 'bm-1', label: 'Refrain', page: 2)],
        pageSequence: [2, 0, 1],
      );

      final json = doc.toFileJson(
        pdfPath: '/scores/song.pdf',
        pdfName: 'song.pdf',
        totalPages: 3,
        nowIso: '2026-01-01T00:00:00.000',
        createdIso: '2025-01-01T00:00:00.000',
      );
      final restored = AnnotationDocument.fromJson(json);

      expect(restored.notations.length, 2);
      expect(restored.notations[0].type, 'sharp');
      expect(restored.notations[0].size, 1.5);
      expect(restored.notations[1].text, 'rit.');

      expect(restored.drawings[0]!.single.color, '#ff0000');
      expect(restored.drawings[0]!.single.points.map((p) => p.relativeX), [0.0, 1.0]);

      expect(restored.bookmarks.single.label, 'Refrain');
      expect(restored.bookmarks.single.page, 2);

      expect(restored.pageSequence, [2, 0, 1]);
    });

    test('round-trips a null page sequence (no custom page order)', () {
      final doc = AnnotationDocument();
      final json = doc.toFileJson(
        pdfPath: '/scores/song.pdf',
        pdfName: 'song.pdf',
        totalPages: 3,
        nowIso: '2026-01-01T00:00:00.000',
      );
      expect(AnnotationDocument.fromJson(json).pageSequence, isNull);
    });
  });

  group('Legacy (main.py) format compatibility', () {
    test('reads the old drawings format: a page mapping to a raw list of points', () {
      final legacy = {
        'pdf_file': '/scores/song.pdf',
        'bookmarks': <dynamic>[],
        'annotations': {
          'music_notations': <dynamic>[],
          'drawings': {
            '0': [
              {'relative_x': 0.1, 'relative_y': 0.2},
              {'relative_x': 0.3, 'relative_y': 0.4},
            ],
          },
        },
      };

      final doc = AnnotationDocument.fromJson(legacy);

      expect(doc.drawings[0], hasLength(1),
          reason: 'the old flat point list becomes a single DrawingPath');
      final path = doc.drawings[0]!.single;
      expect(path.points.map((p) => p.relativeX), [0.1, 0.3]);
      // Format legacy sans couleur/épaisseur : valeurs de repli attendues.
      expect(path.color, '#000000');
      expect(path.size, 3);
    });

    test('reads the current drawings format: a page mapping to a list of path dicts', () {
      final current = {
        'annotations': {
          'music_notations': <dynamic>[],
          'drawings': {
            '0': [
              {
                'points': [
                  {'relative_x': 0.5, 'relative_y': 0.5},
                ],
                'color': '#00ff00',
                'size': 7,
              },
            ],
          },
        },
        'bookmarks': <dynamic>[],
      };

      final doc = AnnotationDocument.fromJson(current);

      final path = doc.drawings[0]!.single;
      expect(path.color, '#00ff00');
      expect(path.size, 7);
    });

    test('reads a bookmark saved without an id and generates one on load', () {
      final legacy = {
        'annotations': {'music_notations': <dynamic>[], 'drawings': <String, dynamic>{}},
        'bookmarks': [
          {'label': 'Intro', 'page': 0},
        ],
      };

      final doc = AnnotationDocument.fromJson(legacy);

      expect(doc.bookmarks.single.label, 'Intro');
      expect(doc.bookmarks.single.id, isNotEmpty);
    });

    test('tolerates a completely empty file', () {
      final doc = AnnotationDocument.fromJson(const {});
      expect(doc.notations, isEmpty);
      expect(doc.drawings, isEmpty);
      expect(doc.bookmarks, isEmpty);
      expect(doc.pageSequence, isNull);
    });
  });

  group('snapshot / restore (undo-redo support)', () {
    test('restore replaces notations and drawings without aliasing the snapshot', () {
      final doc = AnnotationDocument(
        notations: [Notation(type: 'sharp', page: 0, relativeX: 0, relativeY: 0)],
      );
      final snap = doc.snapshot();

      doc.notations.add(Notation(type: 'flat', page: 0, relativeX: 1, relativeY: 1));
      expect(doc.notations.length, 2);

      doc.restore(snap);
      expect(doc.notations.length, 1);
      expect(doc.notations.single.type, 'sharp');

      // Mutating the document after restore must not leak back into the snapshot.
      doc.notations.single.type = 'mutated';
      expect(snap.notations.single.type, 'sharp');
    });
  });
}
