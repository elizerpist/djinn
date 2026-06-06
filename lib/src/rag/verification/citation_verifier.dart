import '../../local_store/entities.dart';
import '../models/source_evidence.dart';

class CitationVerifier {
  CitationVerificationResult verify({
    required List<String> citedSourceIds,
    required List<SourceEvidence> retrieved,
  }) {
    if (citedSourceIds.isEmpty) {
      return const CitationVerificationResult(
        accepted: false,
        citations: [],
        refusalReason: 'citation_verification_failed',
      );
    }

    final byId = {for (final item in retrieved) item.id: item};
    final citations = <SourceEvidence>[];
    for (final id in citedSourceIds) {
      final evidence = byId[id];
      if (evidence == null) {
        return const CitationVerificationResult(
          accepted: false,
          citations: [],
          refusalReason: 'citation_verification_failed',
        );
      }
      citations.add(evidence);
    }

    final hasWarning = citations.any(
      (item) =>
          item.sourceType != EvidenceSourceType.textChunk &&
          item.validationState != ValidationState.validated,
    );
    return CitationVerificationResult(
      accepted: true,
      citations: List.unmodifiable(citations),
      hasValidationWarning: hasWarning,
      warningText: hasWarning
          ? 'A válasz nem validált vagy csak részben validált flowchart elemet használ.'
          : null,
    );
  }
}
