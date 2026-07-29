import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/main_web.dart';

void main() {
  testWidgets(
    'web preview shows the current Djinn home UI without the engine',
    (tester) async {
      await tester.pumpWidget(const DjinnWebPreviewApp());

      expect(find.text('Djinn'), findsOneWidget);
      expect(find.text('Nincs még beszélgetés'), findsOneWidget);
      expect(find.byTooltip('Tudastar'), findsOneWidget);
      expect(find.byTooltip('Új chat'), findsOneWidget);
    },
  );

  testWidgets('web preview opens the current knowledge-base UI', (
    tester,
  ) async {
    await tester.pumpWidget(const DjinnWebPreviewApp());

    await tester.tap(find.byTooltip('Tudastar'));
    await tester.pumpAndSettle();

    expect(find.text('Tudastar'), findsOneWidget);
    expect(find.text('Nincs importált PDF'), findsOneWidget);
    expect(find.byTooltip('PDF hozzáadása'), findsOneWidget);
  });
}
