import 'dart:convert';
import 'dart:io';

import 'package:arpege/models/annotation_document.dart';
import 'package:arpege/models/notation.dart';
import 'package:arpege/services/annotation_repository.dart';
import 'package:arpege/services/json_file.dart';
import 'package:arpege/services/paths.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;
  late FileAnnotationRepository repo;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('arpege_annotations_');
    repo = FileAnnotationRepository(locations: AppPaths.at(tmp.path));
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  File annotationFile(String name) =>
      File(p.join(tmp.path, 'annotations', '${name}_annotations.json'));

  group('FileAnnotationRepository', () {
    test('returns null when nothing was ever saved', () async {
      expect(await repo.load('/scores/Prelude.pdf'), isNull);
    });

    test('round-trips a document through disk', () async {
      final doc = AnnotationDocument(
        notations: [
          Notation(type: 'sharp', page: 0, relativeX: 0.25, relativeY: 0.5),
          Notation(
              type: 'indication',
              page: 1,
              relativeX: 0.1,
              relativeY: 0.2,
              text: 'rall.',
              size: 1.5),
        ],
        drawings: {
          2: [
            DrawingPath(
              points: [StrokePoint(0.1, 0.1), StrokePoint(0.9, 0.8)],
              color: '#ff0000',
              size: 4,
            )
          ]
        },
        pageSequence: [0, 2, 1],
      );

      await repo.save(
          pdfPath: '/scores/Prelude.pdf', doc: doc, totalPages: 3);
      final stored = await repo.load('/scores/Prelude.pdf');

      expect(stored, isNotNull);
      final reloaded = stored!.doc;
      expect(reloaded.notations.length, 2);
      expect(reloaded.notations[0].type, 'sharp');
      expect(reloaded.notations[0].relativeX, 0.25);
      expect(reloaded.notations[1].text, 'rall.');
      expect(reloaded.notations[1].size, 1.5);
      expect(reloaded.drawings[2]!.single.color, '#ff0000');
      expect(reloaded.drawings[2]!.single.points.length, 2);
      expect(reloaded.pageSequence, [0, 2, 1]);
    });

    test('preserves the original creation date across saves', () async {
      final doc = AnnotationDocument();
      await repo.save(pdfPath: '/s/A.pdf', doc: doc, totalPages: 1);
      final first = (await repo.load('/s/A.pdf'))!.createdIso;
      expect(first, isNotNull);

      await repo.save(
          pdfPath: '/s/A.pdf', doc: doc, totalPages: 1, createdIso: first);
      expect((await repo.load('/s/A.pdf'))!.createdIso, first);
    });

    test('still reads the legacy drawing format (a bare point list)', () async {
      final file = annotationFile('Legacy');
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode({
        'annotations': {
          'drawings': {
            '0': [
              {'relative_x': 0.1, 'relative_y': 0.2},
              {'relative_x': 0.3, 'relative_y': 0.4},
            ]
          }
        }
      }));

      final stored = await repo.load('/x/Legacy.pdf');
      final path = stored!.doc.drawings[0]!.single;
      expect(path.points.length, 2);
      expect(path.points.first.relativeX, 0.1);
    });

    test('leaves no temporary file behind after a save', () async {
      await repo.save(
          pdfPath: '/s/Clean.pdf', doc: AnnotationDocument(), totalPages: 1);
      final dir = Directory(p.join(tmp.path, 'annotations'));
      final names = await dir.list().map((e) => p.basename(e.path)).toList();
      expect(names, ['Clean_annotations.json']);
    });

    test('reports a corrupt file and moves it aside instead of losing it',
        () async {
      final file = annotationFile('Broken');
      await file.parent.create(recursive: true);
      await file.writeAsString('{ this is not json');

      await expectLater(
          repo.load('/x/Broken.pdf'), throwsA(isA<StorageException>()));

      // The original bytes are still on disk under a quarantine name, so the
      // next save cannot destroy them.
      expect(await file.exists(), isFalse);
      final dir = Directory(p.join(tmp.path, 'annotations'));
      final quarantined =
          await dir.list().map((e) => p.basename(e.path)).toList();
      expect(quarantined.single, startsWith('Broken_annotations.json.corrupt-'));
    });

    test('import reads an annotations file from an arbitrary path', () async {
      final external = File(p.join(tmp.path, 'exported.json'));
      await external.writeAsString(jsonEncode({
        'annotations': {
          'music_notations': [
            {'type': 'flat', 'page': 0, 'relative_x': 0.5, 'relative_y': 0.5}
          ]
        }
      }));

      final doc = await repo.import(external.path);
      expect(doc.notations.single.type, 'flat');
    });

    test('import fails loudly on a missing file', () async {
      await expectLater(repo.import(p.join(tmp.path, 'nope.json')),
          throwsA(isA<StorageException>()));
    });
  });
}
