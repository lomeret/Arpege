import 'package:flutter_test/flutter_test.dart';

import 'package:arpege/models/annotation_document.dart';
import 'package:arpege/models/notation.dart';
import 'package:arpege/state/history.dart';

AnnotationSnapshot _snapshotWith(String type) => AnnotationSnapshot(
      notations: [
        Notation(type: type, page: 0, relativeX: 0.1, relativeY: 0.2),
      ],
      drawings: const {},
    );

void main() {
  group('HistoryManager', () {
    test('canUndo/canRedo are false on a fresh stack', () {
      final history = HistoryManager();
      expect(history.canUndo, isFalse);
      expect(history.canRedo, isFalse);
    });

    test('push makes undo available and clears redo', () {
      final history = HistoryManager();
      history.push(_snapshotWith('sharp'));
      expect(history.canUndo, isTrue);
      expect(history.canRedo, isFalse);
    });

    test('undo returns the pushed snapshot and enables redo', () {
      final history = HistoryManager();
      final pushed = _snapshotWith('sharp');
      history.push(pushed);

      final current = _snapshotWith('flat');
      final restored = history.undo(current);

      expect(restored, isNotNull);
      expect(restored!.notations.single.type, 'sharp');
      expect(history.canUndo, isFalse);
      expect(history.canRedo, isTrue);
    });

    test('undo on an empty stack returns null and changes nothing', () {
      final history = HistoryManager();
      expect(history.undo(_snapshotWith('flat')), isNull);
      expect(history.canRedo, isFalse);
    });

    test('redo restores the state that was undone', () {
      final history = HistoryManager();
      history.push(_snapshotWith('sharp'));
      final afterEdit = _snapshotWith('flat');
      history.undo(afterEdit);

      final redone = history.redo(_snapshotWith('sharp'));

      expect(redone, isNotNull);
      expect(redone!.notations.single.type, 'flat');
      expect(history.canRedo, isFalse);
      expect(history.canUndo, isTrue);
    });

    test('a new push after undo drops the old redo branch', () {
      final history = HistoryManager();
      history.push(_snapshotWith('sharp'));
      history.undo(_snapshotWith('flat'));
      expect(history.canRedo, isTrue);

      history.push(_snapshotWith('indication'));
      expect(history.canRedo, isFalse);
    });

    test('clear empties both stacks', () {
      final history = HistoryManager();
      history.push(_snapshotWith('sharp'));
      history.undo(_snapshotWith('flat'));
      history.clear();
      expect(history.canUndo, isFalse);
      expect(history.canRedo, isFalse);
    });

    test('popUndo removes the last pushed entry without touching redo', () {
      final history = HistoryManager();
      history.push(_snapshotWith('sharp'));
      history.popUndo();
      expect(history.canUndo, isFalse);
    });

    test('respects maxDepth by dropping the oldest undo entry', () {
      final history = HistoryManager(maxDepth: 2);
      history.push(_snapshotWith('a'));
      history.push(_snapshotWith('b'));
      history.push(_snapshotWith('c'));

      // 3 pushes with maxDepth=2 → only 'b' then 'c' survive, oldest ('a') dropped.
      final first = history.undo(_snapshotWith('current'))!;
      expect(first.notations.single.type, 'c');
      final second = history.undo(_snapshotWith('current'))!;
      expect(second.notations.single.type, 'b');
      expect(history.canUndo, isFalse);
    });

    test('push stores a deep copy, later mutation of the source is not reflected', () {
      final history = HistoryManager();
      final snap = _snapshotWith('sharp');
      history.push(snap);

      snap.notations.single.type = 'mutated-after-push';

      final restored = history.undo(_snapshotWith('flat'))!;
      expect(restored.notations.single.type, 'sharp');
    });
  });
}
