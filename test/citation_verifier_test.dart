import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/local_store/entities.dart';
import 'package:djinn/src/rag/models/source_evidence.dart';
import 'package:djinn/src/rag/verification/citation_verifier.dart';

void main() {
  test('blocks citations that were not retrieved', () {
    final verifier = CitationVerifier();
    final result = verifier.verify(
      citedSourceIds: ['missing'],
      retrieved: const [
        SourceEvidence(
          id: 'chunk-1',
          sourceType: EvidenceSourceType.textChunk,
          text: 'ABCDE',
          label: 'Szöveges PDF-részlet',
          validationState: ValidationState.validated,
        ),
      ],
    );

    expect(result.accepted, isFalse);
    expect(result.refusalReason, 'citation_verification_failed');
  });

  test('warns when unreviewed flowchart evidence is cited', () {
    final verifier = CitationVerifier();
    final result = verifier.verify(
      citedSourceIds: ['node-1'],
      retrieved: const [
        SourceEvidence(
          id: 'node-1',
          sourceType: EvidenceSourceType.flowchartNode,
          text: 'Döntési pont',
          label: 'Nem validált flowchart',
          validationState: ValidationState.unreviewed,
        ),
      ],
    );

    expect(result.accepted, isTrue);
    expect(result.hasValidationWarning, isTrue);
    expect(result.warningText, contains('nem validált'));
  });
}
