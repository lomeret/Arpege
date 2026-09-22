import 'package:flutter_test/flutter_test.dart';

import 'package:arpege/models/setlist.dart';

void main() {
  group('Setlist', () {
    test('fromJson(toJson(x)) round-trips id, name and ordered score ids', () {
      final setlist = Setlist(
        id: 'sl-1',
        name: 'Concert du 12',
        scoreIds: ['s1', 's2', 's3'],
      );

      final restored = Setlist.fromJson(setlist.toJson());

      expect(restored.id, 'sl-1');
      expect(restored.name, 'Concert du 12');
      expect(restored.scoreIds, ['s1', 's2', 's3']);
    });

    test('fromJson defaults a missing score_ids list to empty', () {
      final restored = Setlist.fromJson({'id': 'sl-2', 'name': 'Vide'});
      expect(restored.scoreIds, isEmpty);
    });
  });
}
