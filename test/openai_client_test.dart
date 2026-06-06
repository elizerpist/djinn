import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/openai/openai_client.dart';

void main() {
  test('fake OpenAI client returns deterministic embedding', () async {
    final client = FakeOpenAiClient(embedding: List<double>.filled(3072, 0.1));

    final vector = await client.createEmbedding(
      input: 'mellkasi fajdalom',
      model: 'text-embedding-3-large',
    );

    expect(vector, hasLength(3072));
    expect(vector.first, 0.1);
  });

  test('fake answer cites supplied evidence ids', () async {
    final client = FakeOpenAiClient(answerText: 'ABCDE szerint jarj el.');

    final answer = await client.generateAnswer(
      model: 'gpt-5.5',
      question: 'Mi a teendo?',
      evidence: const [
        OpenAiEvidence(
          id: 'chunk-1',
          label: 'Szöveges PDF-részlet',
          text: 'ABCDE',
        ),
      ],
    );

    expect(answer.answer, 'ABCDE szerint jarj el.');
    expect(answer.citedSourceIds, ['chunk-1']);
  });
}
