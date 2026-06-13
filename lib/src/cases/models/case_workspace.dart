class CaseWorkspace {
  const CaseWorkspace({
    required this.id,
    required this.title,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.archived,
    required this.linkedChatCount,
    required this.linkedDocumentCount,
  });

  final String id;
  final String title;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool archived;
  final int linkedChatCount;
  final int linkedDocumentCount;

  String get notesPreview {
    final trimmed = notes.trim();
    if (trimmed.isEmpty) {
      return 'Nincs jegyzet';
    }
    return trimmed.length <= 80 ? trimmed : '${trimmed.substring(0, 77)}...';
  }
}
