import 'package:flutter_test/flutter_test.dart';

import 'package:arpege/models/score.dart';
import 'package:arpege/state/library_controller.dart';

// Ces tests manipulent directement `scores` (une List<Score> publique) et
// n'appellent jamais load()/save() : pas d'accès disque, donc pas besoin de
// mocker path_provider pour tester la recherche.
Score _score({
  required String id,
  String title = '',
  String composer = '',
  String path = '',
}) =>
    Score(id: id, path: path, added: '', lastOpened: '', title: title, composer: composer);

void main() {
  group('LibraryController.search', () {
    late LibraryController library;

    setUp(() {
      library = LibraryController()
        ..scores.addAll([
          _score(id: '1', title: 'Clair de lune', composer: 'Debussy', path: '/a/clair.pdf'),
          _score(id: '2', title: 'Boléro', composer: 'Ravel', path: '/b/bolero.pdf'),
          _score(id: '3', title: 'Ave Maria', composer: 'Schubert', path: '/c/ave.pdf'),
        ]);
    });

    test('an empty query returns every score sorted by title', () {
      final results = library.search('');
      expect(results.map((s) => s.title), ['Ave Maria', 'Boléro', 'Clair de lune']);
    });

    test('matches on title', () {
      final results = library.search('lune');
      expect(results.map((s) => s.id), ['1']);
    });

    test('matches on composer', () {
      final results = library.search('ravel');
      expect(results.map((s) => s.id), ['2']);
    });

    test('matches on the file path as a fallback', () {
      final results = library.search('ave.pdf');
      expect(results.map((s) => s.id), ['3']);
    });

    test('is case-insensitive', () {
      expect(library.search('DEBUSSY').map((s) => s.id), ['1']);
    });

    test('trims surrounding whitespace', () {
      expect(library.search('  ravel  ').map((s) => s.id), ['2']);
    });

    test('returns nothing when no score matches', () {
      expect(library.search('nonexistent'), isEmpty);
    });
  });
}
