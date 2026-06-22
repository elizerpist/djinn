class ChatCitation {
  const ChatCitation({
    required this.documentId,
    required this.title,
    required this.excerpt,
    this.page,
    this.section,
    this.sourceId,
    this.sourceType,
    this.sourceLabel,
    this.validationState,
    this.atomType,
    this.reasons = const [],
    this.fullChunkText,
  });

  final String documentId;
  final String title;
  final int? page;
  final String? section;
  final String excerpt;
  final String? sourceId;
  final String? sourceType;
  final String? sourceLabel;
  final String? validationState;
  final String? atomType;
  final List<String> reasons;
  final String? fullChunkText;

  Map<String, Object?> toJson() {
    return {
      'documentId': documentId,
      'title': title,
      'page': page,
      'section': section,
      'excerpt': excerpt,
      'sourceId': sourceId,
      'sourceType': sourceType,
      'sourceLabel': sourceLabel,
      'validationState': validationState,
      'atomType': atomType,
      if (reasons.isNotEmpty) 'reasons': reasons,
      'fullChunkText': fullChunkText,
    };
  }

  factory ChatCitation.fromJson(Map<String, Object?> json) {
    return ChatCitation(
      documentId:
          json['documentId'] as String? ?? json['document_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      page: json['page'] as int?,
      section: json['section'] as String?,
      excerpt: json['excerpt'] as String? ?? '',
      sourceId: json['sourceId'] as String? ?? json['source_id'] as String?,
      sourceType:
          json['sourceType'] as String? ?? json['source_type'] as String?,
      sourceLabel:
          json['sourceLabel'] as String? ?? json['source_label'] as String?,
      validationState:
          json['validationState'] as String? ??
          json['validation_state'] as String?,
      atomType: json['atomType'] as String? ?? json['atom_type'] as String?,
      reasons: _stringsFromJson(json['reasons']),
      fullChunkText:
          json['fullChunkText'] as String? ??
          json['full_chunk_text'] as String?,
    );
  }

  static List<String> _stringsFromJson(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
}
