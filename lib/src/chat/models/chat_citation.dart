class ChatCitation {
  const ChatCitation({
    required this.documentId,
    required this.title,
    required this.excerpt,
    this.page,
    this.section,
  });

  final String documentId;
  final String title;
  final int? page;
  final String? section;
  final String excerpt;

  Map<String, Object?> toJson() {
    return {
      'documentId': documentId,
      'title': title,
      'page': page,
      'section': section,
      'excerpt': excerpt,
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
    );
  }
}
