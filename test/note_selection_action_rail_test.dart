import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/notes/ui/note_tag_pills.dart';

void main() {
  testWidgets('rail alternate background uses table surface grey', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NoteSelectionActionRail(
            tags: [],
            actions: [],
            transparentBackground: true,
          ),
        ),
      ),
    );

    final material = tester.widget<Material>(
      find.byKey(const ValueKey('note-selection-action-rail')),
    );

    expect(material.color, const Color(0xFFF8FAFC));
    expect(
      find.byKey(const ValueKey('note-selection-action-rail-grey')),
      findsOneWidget,
    );
  });
}
