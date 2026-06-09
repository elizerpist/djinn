import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/ai/ai_client.dart';
import 'package:djinn/src/ai/ai_provider.dart';

void main() {
  test('AI extraction contract includes chunks and flowcharts', () {
    const result = AiExtractionResult(
      chunks: [
        AiExtractedChunk(id: 'p1-main', text: 'Protocol text', pageNumber: 1),
      ],
      flowcharts: [
        AiExtractedFlowchart(
          id: 'flow-1',
          title: 'ABCDE',
          pageNumber: 2,
          confidence: 0.84,
          nodes: [
            AiExtractedFlowchartNode(id: 'a', label: 'Airway'),
            AiExtractedFlowchartNode(id: 'b', label: 'Breathing'),
          ],
          edges: [
            AiExtractedFlowchartEdge(
              id: 'a-b',
              fromNodeId: 'a',
              toNodeId: 'b',
              label: 'then',
            ),
          ],
        ),
      ],
    );

    expect(result.chunks.single.id, 'p1-main');
    expect(result.flowcharts.single.nodes, hasLength(2));
    expect(result.flowcharts.single.edges.single.toNodeId, 'b');
  });

  test('provider defaults keep OpenAI and Gemini model names separate', () {
    expect(AiProvider.openai.defaultAnswerModel, 'gpt-5.5');
    expect(AiProvider.openai.defaultEmbeddingModel, 'text-embedding-3-large');
    expect(AiProvider.google.defaultAnswerModel, 'gemini-2.5-flash');
    expect(AiProvider.google.defaultExtractionModel, 'gemini-2.5-flash');
    expect(AiProvider.google.defaultEmbeddingModel, 'gemini-embedding-001');
  });
}
