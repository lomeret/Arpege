import 'package:arpege/main.dart';
import 'package:arpege/widgets/toolbar.dart';
import 'package:arpege/widgets/tool_sidebar.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  testWidgets('F5 hides the chrome and turns taps into page turns, Esc exits',
      (tester) async {
    final editor = await pumpArpegeWithScore(tester);
    expect(find.byType(ArpegeToolbar), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pumpAndSettle();
    expect(editor.performanceMode, isTrue);
    expect(find.byType(ArpegeToolbar), findsNothing);
    expect(find.byType(ToolSidebar), findsNothing);
    expect(find.byType(PanelsView), findsNothing);

    // Right half of the screen: next page. Pedals still reach the shortcuts.
    await tester.tapAt(const Offset(1200, 450));
    await tester.pumpAndSettle();
    expect(editor.seqPos, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pumpAndSettle();
    expect(editor.seqPos, 2);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(editor.performanceMode, isFalse);
    expect(find.byType(ArpegeToolbar), findsOneWidget);
  });
}
