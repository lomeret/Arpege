import 'package:flutter_test/flutter_test.dart';

import 'package:arpege/models/bookmark.dart';

void main() {
  group('Bookmark', () {
    test('fromJson(toJson(x)) round-trips id, label and page', () {
      final bookmark = Bookmark(id: 'bm-1', label: 'Refrain', page: 4);
      final restored = Bookmark.fromJson(bookmark.toJson());

      expect(restored.id, 'bm-1');
      expect(restored.label, 'Refrain');
      expect(restored.page, 4);
    });

    test('generates a fresh id when none was provided (legacy files)', () {
      final restored = Bookmark.fromJson({'label': 'Intro', 'page': 0});
      expect(restored.id, isNotEmpty);
    });

    test('two auto-generated ids are distinct', () {
      final a = Bookmark(label: 'A', page: 0);
      final b = Bookmark(label: 'B', page: 0);
      expect(a.id, isNot(equals(b.id)));
    });
  });
}
