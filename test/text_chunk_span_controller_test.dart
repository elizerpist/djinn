import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/notes/models/note_document.dart';
import 'package:djinn/src/notes/ui/text_chunk/text_chunk_span_controller.dart';

void main() {
  testWidgets('controller builds spans without changing text', (tester) async {
    final controller = TextChunkSpanController(text: 'Alpha Beta Gamma')
      ..configureTextChunkSpans(
        rangeTags: const [
          NoteTextRangeTag(
            id: 'r-1',
            start: 6,
            end: 10,
            tag: NoteKnowledgeTag(
              type: NoteKnowledgeTagTypes.topic,
              label: 'Topic',
              colorValue: 0xFF2563EB,
            ),
          ),
        ],
      );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (context) {
            final span = controller.buildTextSpan(
              context: context,
              style: const TextStyle(fontSize: 16),
              withComposing: false,
            );
            return Text.rich(span);
          },
        ),
      ),
    );

    expect(controller.text, 'Alpha Beta Gamma');
    expect(find.textContaining('Alpha Beta Gamma'), findsOneWidget);
  });

  testWidgets('secondary tag lanes increase only tagged span height', (
    tester,
  ) async {
    final controller = TextChunkSpanController(text: 'Alpha\nBeta\nGamma')
      ..configureTextChunkSpans(
        rangeTags: const [
          NoteTextRangeTag(
            id: 'r-1',
            start: 6,
            end: 10,
            tag: NoteKnowledgeTag(
              type: NoteKnowledgeTagTypes.topic,
              label: 'Topic',
              colorValue: 0xFF2563EB,
            ),
            tags: [
              NoteKnowledgeTag(
                type: NoteKnowledgeTagTypes.topic,
                label: 'Topic',
                colorValue: 0xFF2563EB,
              ),
              NoteKnowledgeTag(
                type: NoteKnowledgeTagTypes.state,
                label: 'State',
                colorValue: 0xFFDC2626,
              ),
              NoteKnowledgeTag(
                type: NoteKnowledgeTagTypes.custom,
                label: 'Custom',
                colorValue: 0xFF059669,
              ),
            ],
          ),
        ],
      );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (context) {
            final span = controller.buildTextSpan(
              context: context,
              style: const TextStyle(fontSize: 16),
              withComposing: false,
            );
            return Text.rich(span);
          },
        ),
      ),
    );

    final root = tester.widget<Text>(find.byType(Text));
    final spans = (root.textSpan! as TextSpan).children!.whereType<TextSpan>();
    final alphaSpan = spans.firstWhere((span) => span.text == 'Alpha\n');
    final betaSpan = spans.firstWhere((span) => span.text == 'Beta');
    expect(alphaSpan.style?.height, isNull);
    expect(betaSpan.style?.height, greaterThan(1));
    expect(controller.text, 'Alpha\nBeta\nGamma');
  });
}
