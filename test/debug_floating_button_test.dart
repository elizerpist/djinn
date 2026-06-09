import 'package:djinn/src/debug/debug_console.dart';
import 'package:djinn/src/debug/debug_floating_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(DebugConsole.clear);

  testWidgets('floating button opens debug console dialog', (tester) async {
    DebugConsole.log('[VectorGraph] retrieval complete matches=2');

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Stack(children: [DebugFloatingButton()])),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('debug-floating-button')));
    await tester.pumpAndSettle();

    expect(find.text('Debug Console'), findsOneWidget);
    expect(
      find.textContaining('[VectorGraph] retrieval complete'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('debug-console-copy')), findsOneWidget);
    expect(find.byKey(const ValueKey('debug-console-clear')), findsOneWidget);
  });
}
