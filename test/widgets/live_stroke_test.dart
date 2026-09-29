import 'package:arpege/state/editor_controller.dart';
import 'package:arpege/theme.dart';
import 'package:arpege/widgets/annotation_painter.dart';
import 'package:arpege/widgets/sheet_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

final _annotationCanvas = find.byWidgetPredicate(
    (w) => w is CustomPaint && w.painter is AnnotationPainter);

void main() {
  for (final (tool, color) in [
    (Tool.crayon, AppColors.defaultCrayon),
    (Tool.highlighter, AppColors.defaultHighlighter),
  ]) {
    testWidgets('$tool paints the stroke while the finger is still moving',
        (tester) async {
      final editor = await pumpArpegeWithScore(tester);
      editor.setTool(tool);
      await tester.pump();

      final center = tester.getCenter(find.byType(SheetView));
      final gesture = await tester.startGesture(center);
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(20, 8));
        await tester.pump();
      }

      // Finger still down: nothing committed yet, but the stroke is painted.
      expect(editor.doc.drawings, isEmpty);
      final painted = color.withValues(
          alpha: tool == Tool.highlighter ? 0.4 : 1.0);
      expect(tester.renderObject(_annotationCanvas),
          paints..path(color: painted, style: PaintingStyle.stroke));

      await gesture.up();
      await tester.pump();
      expect(editor.doc.drawings[0], hasLength(1));
    });
  }
}
