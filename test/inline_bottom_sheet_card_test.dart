import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/shared/ui/inline_bottom_sheet_card.dart';

void main() {
  testWidgets(
    'inline bottom sheet dismisses by drag without retaining surface',
    (tester) async {
      var dismissed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                const ColoredBox(
                  key: ValueKey('pdf-background'),
                  color: Colors.blue,
                  child: SizedBox.expand(),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: InlineBottomSheetCard(
                    onDismiss: () => dismissed = true,
                    child: const SizedBox(
                      key: ValueKey('sheet-content'),
                      height: 180,
                      child: Text('Sheet'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('sheet-content')), findsOneWidget);
      await tester.drag(
        find.byKey(const ValueKey('inline-bottom-sheet-card')),
        const Offset(0, 180),
      );
      await tester.pumpAndSettle();
      expect(dismissed, isTrue);
    },
  );
}
