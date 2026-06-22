import '../../local_store/entities.dart';

enum NoteEvidenceAtomType {
  textSentence('text_sentence'),
  listItem('list_item'),
  tableCell('table_cell'),
  tableRow('table_row'),
  flowchartNode('flowchart_node'),
  flowchartEdge('flowchart_edge');

  const NoteEvidenceAtomType(this.wireName);

  final String wireName;

  static NoteEvidenceAtomType? fromWireName(String? value) {
    if (value == null) {
      return null;
    }
    for (final type in values) {
      if (type.wireName == value) {
        return type;
      }
    }
    return null;
  }
}

enum NoteEvidenceReason {
  directQuery('direct_query'),
  noteScope('note_scope'),
  chunkTitle('chunk_title'),
  listItemMatch('list_item_match'),
  tableColumn('table_column'),
  tableCell('table_cell'),
  flowchartBranch('flowchart_branch'),
  processLink('process_link'),
  externalDirect('external_direct');

  const NoteEvidenceReason(this.wireName);

  final String wireName;

  static NoteEvidenceReason? fromWireName(String? value) {
    if (value == null) {
      return null;
    }
    for (final reason in values) {
      if (reason.wireName == value) {
        return reason;
      }
    }
    return null;
  }
}

class SourceEvidence {
  const SourceEvidence({
    required this.id,
    required this.sourceType,
    required this.text,
    required this.label,
    required this.validationState,
    this.documentId,
    this.pageNumber,
    this.score,
    this.searchText,
    this.atomType,
    this.reasons = const [],
    this.noteTitle,
    this.chunkId,
    this.chunkTitle,
    this.sourceStart,
    this.sourceEnd,
    this.fullChunkText,
  });

  final String id;
  final EvidenceSourceType sourceType;
  final String text;
  final String label;
  final ValidationState validationState;
  final String? documentId;
  final int? pageNumber;
  final double? score;
  final String? searchText;
  final NoteEvidenceAtomType? atomType;
  final List<NoteEvidenceReason> reasons;
  final String? noteTitle;
  final String? chunkId;
  final String? chunkTitle;
  final int? sourceStart;
  final int? sourceEnd;
  final String? fullChunkText;

  String get searchableText {
    final metadata = searchText?.trim();
    if (metadata == null || metadata.isEmpty) {
      return text;
    }
    return '$metadata\n$text';
  }

  SourceEvidence copyWith({
    String? id,
    EvidenceSourceType? sourceType,
    String? text,
    String? label,
    ValidationState? validationState,
    String? documentId,
    bool clearDocumentId = false,
    int? pageNumber,
    bool clearPageNumber = false,
    double? score,
    bool clearScore = false,
    String? searchText,
    bool clearSearchText = false,
    NoteEvidenceAtomType? atomType,
    bool clearAtomType = false,
    List<NoteEvidenceReason>? reasons,
    String? noteTitle,
    bool clearNoteTitle = false,
    String? chunkId,
    bool clearChunkId = false,
    String? chunkTitle,
    bool clearChunkTitle = false,
    int? sourceStart,
    bool clearSourceStart = false,
    int? sourceEnd,
    bool clearSourceEnd = false,
    String? fullChunkText,
    bool clearFullChunkText = false,
  }) {
    return SourceEvidence(
      id: id ?? this.id,
      sourceType: sourceType ?? this.sourceType,
      text: text ?? this.text,
      label: label ?? this.label,
      validationState: validationState ?? this.validationState,
      documentId: clearDocumentId ? null : documentId ?? this.documentId,
      pageNumber: clearPageNumber ? null : pageNumber ?? this.pageNumber,
      score: clearScore ? null : score ?? this.score,
      searchText: clearSearchText ? null : searchText ?? this.searchText,
      atomType: clearAtomType ? null : atomType ?? this.atomType,
      reasons: reasons ?? this.reasons,
      noteTitle: clearNoteTitle ? null : noteTitle ?? this.noteTitle,
      chunkId: clearChunkId ? null : chunkId ?? this.chunkId,
      chunkTitle: clearChunkTitle ? null : chunkTitle ?? this.chunkTitle,
      sourceStart: clearSourceStart ? null : sourceStart ?? this.sourceStart,
      sourceEnd: clearSourceEnd ? null : sourceEnd ?? this.sourceEnd,
      fullChunkText: clearFullChunkText
          ? null
          : fullChunkText ?? this.fullChunkText,
    );
  }
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
