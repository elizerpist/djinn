import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/debug/debug_console.dart';
import 'package:djinn/src/local_store/entities.dart';
import 'package:djinn/src/rag/models/source_evidence.dart';
import 'package:djinn/src/rag/retrieval/local_retriever.dart';

void main() {
  setUp(DebugConsole.clear);

  test('retriever excludes rejected flowchart evidence', () async {
    final retriever = MemoryLocalRetriever(const [
      SourceEvidence(
        id: 'node-rejected',
        sourceType: EvidenceSourceType.flowchartNode,
        text: 'Rejected',
        label: 'Nem validált flowchart',
        validationState: ValidationState.rejected,
        score: 0.99,
      ),
      SourceEvidence(
        id: 'chunk-accepted',
        sourceType: EvidenceSourceType.textChunk,
        text: 'Accepted',
        label: 'Szöveges PDF-részlet',
        validationState: ValidationState.validated,
        score: 0.91,
      ),
    ]);

    final result = await retriever.retrieve(
      queryVector: List<double>.filled(3072, 0.1),
      limit: 5,
      minimumSimilarity: 0.7,
    );

    expect(result.map((item) => item.id), ['chunk-accepted']);
    expect(
      DebugConsole.allText,
      contains('[VectorGraph] memory retrieval start dim=3072 limit=5 min=0.7'),
    );
    expect(
      DebugConsole.allText,
      contains('[VectorGraph] memory skipped rejected source=node-rejected'),
    );
    expect(
      DebugConsole.allText,
      contains('[VectorGraph] memory retrieval matches=1'),
    );
  });
}
