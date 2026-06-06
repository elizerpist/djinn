class ChatCitation {
  const ChatCitation({
    required this.documentId,
    required this.title,
    required this.excerpt,
    this.page,
    this.section,
    this.sourceId,
    this.sourceLabel,
    this.validationState,
  });

  final String documentId;
  final String title;
  final int? page;
  final String? section;
  final String excerpt;
  final String? sourceId;
  final String? sourceLabel;
  final String? validationState;

  Map<String, Object?> toJson() {
    return {
      'documentId': documentId,
      'title': title,
      'page': page,
      'section': section,
      'excerpt': excerpt,
      'sourceId': sourceId,
      'sourceLabel': sourceLabel,
      'validationState': validationState,
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
      sourceLabel:
          json['sourceLabel'] as String? ?? json['source_label'] as String?,
      validationState:
          json['validationState'] as String? ??
          json['validation_state'] as String?,
    );
  }
}
