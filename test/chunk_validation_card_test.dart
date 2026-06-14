import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/knowledge/models/local_extraction.dart';
import 'package:djinn/src/shared/chunks/chunk_validation_card.dart';
import 'package:djinn/src/shared/chunks/chunk_validation_controller.dart';
import 'package:djinn/src/shared/ui/draggable_bottom_card.dart';

void main() {
  testWidgets('chunk validation card saves edited accepted text and reason', (
    tester,
  ) async {
    ChunkValidationResult? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChunkValidationCard(
            title: 'COPD chunk',
            initialText: 'eredeti szöveg',
            initialAuditState: LocalAuditState.unreviewed,
            onCancel: () {},
            onSave: (result) => saved = result,
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('chunk-validation-text-field')),
      'javított szöveg',
    );
    await tester.tap(find.text('Elfogad'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('chunk-validation-reason-field')),
      'kézi ellenőrzés',
    );
    await tester.tap(find.byKey(const ValueKey('chunk-validation-save')));

    expect(saved, isNotNull);
    expect(saved!.auditState, LocalAuditState.accepted);
    expect(saved!.text, 'javított szöveg');
    expect(saved!.reason, 'kézi ellenőrzés');
  });

  testWidgets('draggable bottom card cancels only after downward threshold', (
    tester,
  ) async {
    var dismissed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Align(
                alignment: Alignment.bottomCenter,
                child: DraggableBottomCard(
                  onDismiss: () => dismissed += 1,
                  dismissThreshold: 80,
                  child: const SizedBox(
                    key: ValueKey('drag-card-content'),
                    height: 220,
                    child: Text('Card'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.drag(find.byKey(const ValueKey('draggable-bottom-card')), const Offset(0, 40));
    await tester.pumpAndSettle();
    expect(dismissed, 0);

    await tester.drag(find.byKey(const ValueKey('draggable-bottom-card')), const Offset(0, 120));
    await tester.pumpAndSettle();
    expect(dismissed, 1);
  });
}
