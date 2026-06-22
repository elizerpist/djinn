import 'package:objectbox/objectbox.dart';
import 'package:uuid/uuid.dart';

import '../../../objectbox.g.dart';
import '../../local_store/entities.dart';
import '../models/note_document.dart';
import '../models/note_tag_registry.dart';
import 'tag_repository.dart';

class ObjectBoxTagRepository implements TagRepository {
  ObjectBoxTagRepository({
    required Store store,
    Uuid? uuid,
    DateTime Function()? clock,
  }) : _tagBox = store.box<NoteTagEntity>(),
       _folderBox = store.box<NoteTagFolderEntity>(),
       _uuid = uuid ?? const Uuid(),
       _clock = clock ?? DateTime.now;

  final Box<NoteTagEntity> _tagBox;
  final Box<NoteTagFolderEntity> _folderBox;
  final Uuid _uuid;
  final DateTime Function() _clock;

  @override
  Future<List<NoteTagDefinition>> listTags() async {
    final rows = _tagBox.getAll();
    rows.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return rows.map(_definitionFromEntity).toList(growable: false);
  }

  @override
  Future<List<NoteTagFolder>> listFolders() async {
    final rows = _folderBox.getAll();
    rows.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return rows.map(_folderFromEntity).toList(growable: false);
  }

  @override
  Future<NoteTagDefinition?> findTagByLabel(String label) async {
    final normalized = normalizeNoteTagLabel(label);
    if (normalized.isEmpty) {
      return null;
    }
    final query = _tagBox
        .query(NoteTagEntity_.normalizedLabel.equals(normalized))
        .build();
    try {
      final entity = query.findFirst();
      return entity == null ? null : _definitionFromEntity(entity);
    } finally {
      query.close();
    }
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
    final nowMillis = now.millisecondsSinceEpoch;
    final entity = _findEntityByLabel(cleanLabel) ?? _findByPublicId(id);
    final normalizedColorSlotId = normalizeNoteTagColorSlotId(colorSlotId);
    if (entity != null) {
      entity.label = cleanLabel;
      entity.normalizedLabel = normalizedLabel;
      entity.colorSlotId = normalizedColorSlotId;
      if (folderId != null) {
        entity.folderPublicId = folderId;
      }
      entity.type = NoteKnowledgeTagTypes.custom;
      entity.updatedAtMillis = nowMillis;
      _tagBox.put(entity);
      return _definitionFromEntity(entity);
    }
    final next = NoteTagEntity(
      publicId: id?.trim().isNotEmpty == true ? id!.trim() : _uuid.v4(),
      label: cleanLabel,
      normalizedLabel: normalizedLabel,
      colorSlotId: normalizedColorSlotId,
      folderPublicId: folderId,
      type: NoteKnowledgeTagTypes.custom,
      createdAtMillis: nowMillis,
      updatedAtMillis: nowMillis,
    );
    _tagBox.put(next);
    return _definitionFromEntity(next);
  }

  @override
  Future<void> deleteTag(String id) async {
    final entity = _findByPublicId(id);
    if (entity != null) {
      _tagBox.remove(entity.id);
    }
  }

  @override
  Future<NoteTagFolder> createFolder(String label) async {
    final cleanLabel = cleanNoteTagLabel(label);
    if (cleanLabel.isEmpty) {
      throw ArgumentError.value(label, 'label', 'Folder label cannot be empty');
    }
    final normalizedLabel = normalizeNoteTagLabel(cleanLabel);
    final query = _folderBox
        .query(NoteTagFolderEntity_.normalizedLabel.equals(normalizedLabel))
        .build();
    try {
      final existing = query.findFirst();
      if (existing != null) {
        return _folderFromEntity(existing);
      }
    } finally {
      query.close();
    }
    final nowMillis = _clock().millisecondsSinceEpoch;
    final entity = NoteTagFolderEntity(
      publicId: _uuid.v4(),
      label: cleanLabel,
      normalizedLabel: normalizedLabel,
      createdAtMillis: nowMillis,
      updatedAtMillis: nowMillis,
    );
    _folderBox.put(entity);
    return _folderFromEntity(entity);
  }

  @override
  Future<NoteTagDefinition> setTagFolder(String tagId, String? folderId) async {
    final entity = _findByPublicId(tagId);
    if (entity == null) {
      throw StateError('Unknown tag: $tagId');
    }
    entity.folderPublicId = folderId;
    entity.updatedAtMillis = _clock().millisecondsSinceEpoch;
    _tagBox.put(entity);
    return _definitionFromEntity(entity);
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
      final fallbackSlotId = (await listTags()).length % noteTagColorSlots.length;
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

  NoteTagEntity? _findByPublicId(String? publicId) {
    final normalized = publicId?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    final query = _tagBox.query(NoteTagEntity_.publicId.equals(normalized)).build();
    try {
      return query.findFirst();
    } finally {
      query.close();
    }
  }

  NoteTagEntity? _findEntityByLabel(String label) {
    final normalized = normalizeNoteTagLabel(label);
    if (normalized.isEmpty) {
      return null;
    }
    final query = _tagBox
        .query(NoteTagEntity_.normalizedLabel.equals(normalized))
        .build();
    try {
      return query.findFirst();
    } finally {
      query.close();
    }
  }

  NoteTagDefinition _definitionFromEntity(NoteTagEntity entity) {
    return NoteTagDefinition(
      id: entity.publicId,
      label: entity.label,
      normalizedLabel: entity.normalizedLabel,
      colorSlotId: normalizeNoteTagColorSlotId(entity.colorSlotId),
      folderId: entity.folderPublicId,
      type: NoteKnowledgeTagTypes.normalize(entity.type),
      createdAt: DateTime.fromMillisecondsSinceEpoch(entity.createdAtMillis),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(entity.updatedAtMillis),
    );
  }

  NoteTagFolder _folderFromEntity(NoteTagFolderEntity entity) {
    return NoteTagFolder(
      id: entity.publicId,
      label: entity.label,
      normalizedLabel: entity.normalizedLabel,
      createdAt: DateTime.fromMillisecondsSinceEpoch(entity.createdAtMillis),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(entity.updatedAtMillis),
    );
  }
}
