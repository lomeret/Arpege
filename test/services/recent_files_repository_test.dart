import 'dart:io';

import 'package:arpege/services/paths.dart';
import 'package:arpege/services/recent_files_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;
  late FileRecentFilesRepository repo;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('arpege_recent_');
    repo = FileRecentFilesRepository(locations: AppPaths.at(tmp.path));
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  /// The repository only returns paths that still exist, so tests need real
  /// files to stand in for scores.
  Future<String> makeScore(String name) async {
    final file = File(p.join(tmp.path, name));
    await file.writeAsString('%PDF-1.4');
    return file.path;
  }

  group('FileRecentFilesRepository', () {
    test('starts empty', () async {
      expect(await repo.load(), isEmpty);
    });

    test('adds the most recent score first', () async {
      final a = await makeScore('a.pdf');
      final b = await makeScore('b.pdf');
      await repo.add(a);
      await repo.add(b);
      expect(await repo.load(), [b, a]);
    });

    test('re-adding an existing score moves it to the front', () async {
      final a = await makeScore('a.pdf');
      final b = await makeScore('b.pdf');
      await repo.add(a);
      await repo.add(b);
      await repo.add(a);
      expect(await repo.load(), [a, b]);
    });

    test('caps the list at maxRecent entries', () async {
      for (var i = 0; i < FileRecentFilesRepository.maxRecent + 4; i++) {
        await repo.add(await makeScore('score_$i.pdf'));
      }
      expect((await repo.load()).length, FileRecentFilesRepository.maxRecent);
    });

    test('remove drops a score for good', () async {
      final a = await makeScore('a.pdf');
      await repo.add(a);
      await repo.remove(a);
      expect(await repo.load(), isEmpty);
    });

    test('scores whose file is gone are filtered out', () async {
      final a = await makeScore('a.pdf');
      final b = await makeScore('b.pdf');
      await repo.add(a);
      await repo.add(b);
      await File(a).delete();
      expect(await repo.load(), [b]);
    });

    test('an unreadable list degrades to empty rather than throwing',
        () async {
      final file = File(p.join(tmp.path, 'config', 'recent_files.json'));
      await file.parent.create(recursive: true);
      await file.writeAsString('not json at all');
      expect(await repo.load(), isEmpty);
    });
  });
}
