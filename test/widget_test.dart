import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/main.dart';

void main() {
  testWidgets('Djinn opens a new chat and sends a text message', (tester) async {
    await tester.pumpWidget(const DjinnApp());

    expect(find.text('Djinn'), findsOneWidget);
    expect(find.text('Nincs meg chat'), findsOneWidget);

    await tester.tap(find.byTooltip('Uj chat'));
    await tester.pumpAndSettle();

    expect(find.text('Uj chat'), findsOneWidget);
    expect(find.byKey(const ValueKey('message-input')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('message-input')),
      'Mi az ellatasi algoritmus?',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('send-message')));
    await tester.pumpAndSettle();

    expect(find.text('Mi az ellatasi algoritmus?'), findsOneWidget);
    expect(find.textContaining('tudasbazis'), findsOneWidget);
  });
}
