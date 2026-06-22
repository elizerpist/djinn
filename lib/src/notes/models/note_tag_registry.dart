import 'note_document.dart';

class NoteTagDefinition {
  const NoteTagDefinition({
    required this.id,
    required this.label,
    required this.normalizedLabel,
    required this.colorSlotId,
    this.folderId,
    this.type = NoteKnowledgeTagTypes.custom,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String label;
  final String normalizedLabel;
  final int colorSlotId;
  final String? folderId;
  final String type;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get colorValue => noteTagColorSlots[colorSlotId];

  NoteKnowledgeTag toKnowledgeTag() {
    return NoteKnowledgeTag(
      id: id,
      type: NoteKnowledgeTagTypes.normalize(type),
      label: label,
      colorSlotId: colorSlotId,
      folderId: folderId,
      colorValue: colorValue,
    );
  }

  NoteTagDefinition copyWith({
    String? id,
    String? label,
    String? normalizedLabel,
    int? colorSlotId,
    String? folderId,
    bool clearFolderId = false,
    String? type,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NoteTagDefinition(
      id: id ?? this.id,
      label: label ?? this.label,
      normalizedLabel: normalizedLabel ?? this.normalizedLabel,
      colorSlotId: colorSlotId ?? this.colorSlotId,
      folderId: clearFolderId ? null : folderId ?? this.folderId,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class NoteTagFolder {
  const NoteTagFolder({
    required this.id,
    required this.label,
    required this.normalizedLabel,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String label;
  final String normalizedLabel;
  final DateTime createdAt;
  final DateTime updatedAt;

  NoteTagFolder copyWith({
    String? id,
    String? label,
    String? normalizedLabel,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NoteTagFolder(
      id: id ?? this.id,
      label: label ?? this.label,
      normalizedLabel: normalizedLabel ?? this.normalizedLabel,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

String normalizeNoteTagLabel(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

String cleanNoteTagLabel(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ');
}

int noteTagColorSlotIdForValue(int? colorValue, {int fallback = 0}) {
  if (colorValue == null) {
    return fallback.clamp(0, noteTagColorSlots.length - 1).toInt();
  }
  final index = noteTagColorSlots.indexOf(colorValue);
  if (index != -1) {
    return index;
  }
  return fallback.clamp(0, noteTagColorSlots.length - 1).toInt();
}

int normalizeNoteTagColorSlotId(int value) {
  return value.clamp(0, noteTagColorSlots.length - 1).toInt();
}
