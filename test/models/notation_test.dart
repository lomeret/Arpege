import 'package:flutter_test/flutter_test.dart';

import 'package:arpege/models/notation.dart';

void main() {
  group('StrokePoint', () {
    test('fromJson(toJson(x)) round-trips', () {
      final point = StrokePoint(0.25, 0.75);
      final restored = StrokePoint.fromJson(point.toJson());
      expect(restored.relativeX, 0.25);
      expect(restored.relativeY, 0.75);
    });
  });

  group('Notation', () {
    test('sharp/flat round-trip position and size (no text field)', () {
      final sharp = Notation(
          type: 'sharp', page: 2, relativeX: 0.1, relativeY: 0.9, size: 1.2);
      final restored = Notation.fromJson(sharp.toJson());

      expect(restored.type, 'sharp');
      expect(restored.page, 2);
      expect(restored.relativeX, 0.1);
      expect(restored.relativeY, 0.9);
      expect(restored.size, 1.2);
      expect(restored.text, isNull);
    });

    test('indication round-trips its text', () {
      final indication = Notation(
        type: 'indication',
        page: 0,
        relativeX: 0.5,
        relativeY: 0.5,
        text: 'rall.',
      );
      final restored = Notation.fromJson(indication.toJson());
      expect(restored.text, 'rall.');
    });

    test('fromJson defaults size to 1.0 when absent (older files)', () {
      final restored = Notation.fromJson({
        'type': 'sharp',
        'page': 0,
        'relative_x': 0.0,
        'relative_y': 0.0,
      });
      expect(restored.size, 1.0);
    });

    test('copy() is independent from the original', () {
      final original = Notation(type: 'sharp', page: 0, relativeX: 0, relativeY: 0);
      final copy = original.copy();
      copy.type = 'flat';
      expect(original.type, 'sharp');
    });
  });

  group('DrawingPath', () {
    test('fromJson(toJson(x)) round-trips points, color and size', () {
      final path = DrawingPath(
        points: [StrokePoint(0, 0), StrokePoint(1, 1)],
        color: '#00ff00',
        size: 6,
      );
      final restored = DrawingPath.fromJson(path.toJson());

      expect(restored.color, '#00ff00');
      expect(restored.size, 6);
      expect(restored.points.map((p) => p.relativeX), [0, 1]);
    });

    test('fromJson accepts a raw point list (legacy format)', () {
      final restored = DrawingPath.fromJson([
        {'relative_x': 0.2, 'relative_y': 0.4},
      ]);
      expect(restored.points.single.relativeX, 0.2);
      expect(restored.color, '#000000');
      expect(restored.size, 3);
    });

    test('copy() deep-copies the points list', () {
      final original = DrawingPath(points: [StrokePoint(0, 0)]);
      final copy = original.copy();
      copy.points.add(StrokePoint(1, 1));
      expect(original.points, hasLength(1));
    });
  });
}
