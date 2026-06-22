import 'package:uuid/uuid.dart';

import '../models/note_document.dart';
import '../models/note_tag_registry.dart';

abstract class TagRepository {
  Future<List<NoteTagDefinition>> listTags();

  Future<List<NoteTagFolder>> listFolders();

  Future<NoteTagDefinition> upsertTag({
    String? id,
    required String label,
    required int colorSlotId,
    String? folderId,
  });

  Future<void> deleteTag(String id);

  Future<NoteTagDefinition?> findTagByLabel(String label);

  Future<NoteTagFolder> createFolder(String label);

  Future<NoteTagDefinition> setTagFolder(String tagId, String? folderId);

  Future<List<NoteKnowledgeTag>> rememberEmbeddedTags(
    List<NoteKnowledgeTag> tags,
  );
}

class MemoryTagRepository implements TagRepository {
  MemoryTagRepository({
    Uuid? uuid,
    DateTime Function()? clock,
  }) : _uuid = uuid ?? const Uuid(),
       _clock = clock ?? DateTime.now;

  final Uuid _uuid;
  final DateTime Function() _clock;
  final Map<String, NoteTagDefinition> _tagsById = <String, NoteTagDefinition>{};
  final Map<String, NoteTagFolder> _foldersById = <String, NoteTagFolder>{};

  @override
  Future<List<NoteTagDefinition>> listTags() async {
    final tags = _tagsById.values.toList(growable: false);
    tags.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return tags;
  }

  @override
  Future<List<NoteTagFolder>> listFolders() async {
    final folders = _foldersById.values.toList(growable: false);
    folders.sort(
      (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
    );
    return folders;
  }

  @override
  Future<NoteTagDefinition?> findTagByLabel(String label) async {
    final normalized = normalizeNoteTagLabel(label);
    if (normalized.isEmpty) {
      return null;
    }
    for (final tag in _tagsById.values) {
      if (tag.normalizedLabel == normalized) {
        return tag;
      }
    }
    return null;
  }

  @override
  Future<NoteTagDefinition> upsertTag({
    String? id,
    required String label,
    required int colorSlotId,
    String? folderId,
  }) async {
    final cleanLabel = cleanNoteTagLabel(label);
    if (cleanLabel.isEmpty) {
      throw ArgumentError.value(label, 'label', 'Tag label cannot be empty');
    }
    final normalizedLabel = normalizeNoteTagLabel(cleanLabel);
    final now = _clock();
    final existingById = id == null ? null : _tagsById[id];
    final existingByLabel = await findTagByLabel(cleanLabel);
    final existing = existingByLabel ?? existingById;
    final normalizedColorSlotId = normalizeNoteTagColorSlotId(colorSlotId);
    if (existing != null) {
      final updated = existing.copyWith(
        label: cleanLabel,
        normalizedLabel: normalizedLabel,
        colorSlotId: normalizedColorSlotId,
        folderId: folderId,
        type: NoteKnowledgeTagTypes.custom,
        updatedAt: now,
      );
      _tagsById[updated.id] = updated;
      return updated;
    }
    final tag = NoteTagDefinition(
      id: id?.trim().isNotEmpty == true ? id!.trim() : _uuid.v4(),
      label: cleanLabel,
      normalizedLabel: normalizedLabel,
      colorSlotId: normalizedColorSlotId,
      folderId: folderId,
      type: NoteKnowledgeTagTypes.custom,
      createdAt: now,
      updatedAt: now,
    );
    _tagsById[tag.id] = tag;
    return tag;
  }

  @override
  Future<void> deleteTag(String id) async {
    _tagsById.remove(id);
  }

  @override
  Future<NoteTagFolder> createFolder(String label) async {
    final cleanLabel = cleanNoteTagLabel(label);
    if (cleanLabel.isEmpty) {
      throw ArgumentError.value(label, 'label', 'Folder label cannot be empty');
    }
    final normalizedLabel = normalizeNoteTagLabel(cleanLabel);
    for (final folder in _foldersById.values) {
      if (folder.normalizedLabel == normalizedLabel) {
        return folder;
      }
    }
    final now = _clock();
    final folder = NoteTagFolder(
      id: _uuid.v4(),
      label: cleanLabel,
      normalizedLabel: normalizedLabel,
      createdAt: now,
      updatedAt: now,
    );
    _foldersById[folder.id] = folder;
    return folder;
  }

  @override
  Future<NoteTagDefinition> setTagFolder(String tagId, String? folderId) async {
    final tag = _tagsById[tagId];
    if (tag == null) {
      throw StateError('Unknown tag: $tagId');
    }
    final updated = tag.copyWith(
      folderId: folderId,
      clearFolderId: folderId == null,
      updatedAt: _clock(),
    );
    _tagsById[updated.id] = updated;
    return updated;
  }

  @override
  Future<List<NoteKnowledgeTag>> rememberEmbeddedTags(
    List<NoteKnowledgeTag> tags,
  ) async {
    final remembered = <NoteKnowledgeTag>[];
    for (final tag in tags) {
      final cleanLabel = cleanNoteTagLabel(tag.label);
      if (cleanLabel.isEmpty) {
        continue;
      }
      final fallbackSlotId = _tagsById.length % noteTagColorSlots.length;
      final slotId = tag.colorSlotId ??
          noteTagColorSlotIdForValue(
            tag.colorValue,
            fallback: fallbackSlotId,
          );
      final definition = await upsertTag(
        id: tag.id,
        label: cleanLabel,
        colorSlotId: slotId,
        folderId: tag.folderId,
      );
      remembered.add(definition.toKnowledgeTag());
    }
    return remembered;
  }
}
