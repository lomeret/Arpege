import 'package:flutter_test/flutter_test.dart';

import 'package:arpege/models/score.dart';

void main() {
  group('Score', () {
    test('fromJson(toJson(x)) round-trips every field', () {
      final score = Score(
        id: 'abc123',
        path: '/scores/song.pdf',
        added: '2026-01-01T00:00:00.000',
        lastOpened: '2026-01-02T00:00:00.000',
        title: 'Clair de lune',
        composer: 'Debussy',
        arranger: 'Louis',
        key: 'Db',
        tempo: 'Andante',
        genre: 'Classique',
        notes: 'Jouer piano',
      );

      final restored = Score.fromJson(score.toJson());

      expect(restored.id, score.id);
      expect(restored.path, score.path);
      expect(restored.added, score.added);
      expect(restored.lastOpened, score.lastOpened);
      for (final field in Score.metadataFields) {
        expect(restored.get(field), score.get(field), reason: field);
      }
    });

    test('fromJson fills missing metadata fields with empty strings', () {
      final restored = Score.fromJson({
        'id': 'abc123',
        'path': '/scores/song.pdf',
      });

      expect(restored.added, '');
      expect(restored.lastOpened, '');
      for (final field in Score.metadataFields) {
        expect(restored.get(field), '');
      }
    });

    test('get/set only accept known metadata fields', () {
      final score = Score(id: 'x', path: 'p', added: 'a', lastOpened: 'l');
      score.set('composer', 'Bach');
      expect(score.get('composer'), 'Bach');

      // Champ inconnu : ignoré silencieusement plutôt que de planter.
      score.set('unknown_field', 'value');
      expect(score.get('unknown_field'), '');
    });
  });
}
