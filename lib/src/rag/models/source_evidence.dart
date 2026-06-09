import '../../local_store/entities.dart';

class SourceEvidence {
  const SourceEvidence({
    required this.id,
    required this.sourceType,
    required this.text,
    required this.label,
    required this.validationState,
    this.documentId,
    this.pageNumber,
    this.ragEnabled = true,
    this.collectionName = 'Alap',
    this.score,
  });

  final String id;
  final EvidenceSourceType sourceType;
  final String text;
  final String label;
  final ValidationState validationState;
  final String? documentId;
  final int? pageNumber;
  final bool ragEnabled;
  final String collectionName;
  final double? score;
}

class CitationVerificationResult {
  const CitationVerificationResult({
    required this.accepted,
    required this.citations,
    this.refusalReason,
    this.hasValidationWarning = false,
    this.warningText,
  });

  final bool accepted;
  final List<SourceEvidence> citations;
  final String? refusalReason;
  final bool hasValidationWarning;
  final String? warningText;
}
