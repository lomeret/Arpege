import 'dart:io';

import 'package:arpege/models/score.dart';
import 'package:arpege/models/setlist.dart';
import 'package:arpege/services/json_file.dart';
import 'package:arpege/services/library_repository.dart';
import 'package:arpege/services/paths.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;
  late FileLibraryRepository repo;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('arpege_library_');
    repo = FileLibraryRepository(locations: AppPaths.at(tmp.path));
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  File libraryFile() => File(p.join(tmp.path, 'config', 'library.json'));

  group('FileLibraryRepository', () {
    test('a fresh install loads an empty library', () async {
      final data = await repo.load();
      expect(data.scores, isEmpty);
      expect(data.setlists, isEmpty);
    });

    test('round-trips scores and setlists', () async {
      await repo.save(LibraryData(
        scores: [
          Score(
            id: 'a',
            path: '/scores/bolero.pdf',
            added: '2026-01-01T00:00:00.000',
            lastOpened: '2026-01-02T00:00:00.000',
            title: 'Boléro',
            composer: 'Ravel',
            tempo: '72',
          ),
        ],
        setlists: [Setlist(id: 's1', name: 'Concert', scoreIds: ['a'])],
      ));

      final data = await repo.load();
      expect(data.scores.single.id, 'a');
      expect(data.scores.single.title, 'Boléro');
      expect(data.scores.single.composer, 'Ravel');
      expect(data.scores.single.tempo, '72');
      expect(data.setlists.single.name, 'Concert');
      expect(data.setlists.single.scoreIds, ['a']);
    });

    test('writes atomically and leaves no temporary file', () async {
      await repo.save(LibraryData.empty());
      final dir = Directory(p.join(tmp.path, 'config'));
      final names = await dir.list().map((e) => p.basename(e.path)).toList();
      expect(names, ['library.json']);
    });

    test('a corrupt library is reported and quarantined, never silently lost',
        () async {
      final file = libraryFile();
      await file.parent.create(recursive: true);
      await file.writeAsString('{"scores": [ truncated');

      await expectLater(repo.load(), throwsA(isA<StorageException>()));

      expect(await file.exists(), isFalse);
      final dir = Directory(p.join(tmp.path, 'config'));
      final names = await dir.list().map((e) => p.basename(e.path)).toList();
      expect(names.single, startsWith('library.json.corrupt-'));

      // And the quarantined copy still holds the original bytes.
      final quarantined = File(p.join(dir.path, names.single));
      expect(await quarantined.readAsString(), '{"scores": [ truncated');
    });

    test('a JSON file whose root is not an object is treated as corrupt',
        () async {
      final file = libraryFile();
      await file.parent.create(recursive: true);
      await file.writeAsString('[1, 2, 3]');
      await expectLater(repo.load(), throwsA(isA<StorageException>()));
    });
  });
}
