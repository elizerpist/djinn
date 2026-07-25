import 'dart:convert';

import '../../../objectbox.g.dart';
import '../../local_store/entities.dart';
import '../models/chunk.dart';

/// Keeps disposable search/graph projections consistent with the canonical
/// chunk row after an edit, regardless of which collector UI performed it.
///
/// Callers must invoke this inside the same ObjectBox write transaction as the
/// canonical chunk mutation. Embeddings are deliberately removed rather than
/// relabelled because their vector can only be rebuilt by the indexing layer.
class ObjectBoxChunkDerivedData {
  ObjectBoxChunkDerivedData({required Store store})
    : _embeddingBox = store.box<ChunkEmbeddingEntity>(),
      _auditItemBox = store.box<ExtractionAuditItemEntity>(),
      _knowledgeNodeBox = store.box<KnowledgeNodeEntity>(),
      _knowledgeEdgeBox = store.box<KnowledgeEdgeEntity>(),
      _knowledgeEvidenceBox = store.box<KnowledgeEvidenceEntity>();

  final Box<ChunkEmbeddingEntity> _embeddingBox;
  final Box<ExtractionAuditItemEntity> _auditItemBox;
  final Box<KnowledgeNodeEntity> _knowledgeNodeBox;
  final Box<KnowledgeEdgeEntity> _knowledgeEdgeBox;
  final Box<KnowledgeEvidenceEntity> _knowledgeEvidenceBox;

  void synchronizeMutation({
    required Chunk before,
    required Chunk after,
    required DocumentChunkEntity entity,
  }) {
    if (before.id != after.id) {
      throw ArgumentError('A canonical chunk mutation must keep its id.');
    }
    final contentChanged =
        jsonEncode(before.content.toJson()) !=
        jsonEncode(after.content.toJson());
    final kindChanged = before.kind != after.kind;
    final sourceChanged =
        jsonEncode(before.source.toJson()) != jsonEncode(after.source.toJson());
    if (contentChanged || kindChanged || sourceChanged) {
      _removeChunkEmbeddings(after.id);
    }

    final label = _chunkLabel(after);
    for (final node in _knowledgeNodeBox.getAll()) {
      if (node.sourceId != after.id) {
        continue;
      }
      node
        ..documentPublicId = entity.documentPublicId
        ..label = label
        ..nodeType = after.kind.wireName
        ..pageNumber = after.source.pageStart;
      _knowledgeNodeBox.put(node);
    }
    for (final evidence in _knowledgeEvidenceBox.getAll()) {
      if (evidence.sourceId != after.id) {
        continue;
      }
      evidence
        ..documentPublicId = entity.documentPublicId
        ..pageNumber = after.source.pageStart
        ..quote = after.plainText;
      _knowledgeEvidenceBox.put(evidence);
    }
    for (final auditItem in _auditItemBox.getAll()) {
      if (auditItem.sourceId != after.id) {
        continue;
      }
      auditItem
        ..documentPublicId = entity.documentPublicId
        ..itemKind = after.kind.wireName
        ..auditState = after.validationState.wireName
        ..pageNumber = after.source.pageStart
        ..title = after.content.title
        ..previewText = after.plainText
        ..updatedAtMillis =
            after.updatedAt?.millisecondsSinceEpoch ??
            entity.updatedAtMillis ??
            DateTime.now().millisecondsSinceEpoch;
      _auditItemBox.put(auditItem);
    }
    if (before.content.title != after.content.title || sourceChanged) {
      _rewireSectionEdge(after, entity);
    }
  }

  void _removeChunkEmbeddings(String chunkId) {
    final ids = _embeddingBox
        .getAll()
        .where(
          (embedding) =>
              embedding.sourceId == chunkId ||
              embedding.sourceId.startsWith('$chunkId:'),
        )
        .map((embedding) => embedding.id)
        .toList(growable: false);
    if (ids.isNotEmpty) {
      _embeddingBox.removeMany(ids);
    }
  }

  void _rewireSectionEdge(Chunk chunk, DocumentChunkEntity entity) {
    final nodeId = '${chunk.id}:node';
    final staleIds = _knowledgeEdgeBox
        .getAll()
        .where(
          (edge) =>
              edge.sourceId == chunk.id &&
              edge.relationType == 'part_of' &&
              edge.fromNodePublicId == nodeId,
        )
        .map((edge) => edge.id)
        .toList(growable: false);
    if (staleIds.isNotEmpty) {
      _knowledgeEdgeBox.removeMany(staleIds);
    }
    final title = chunk.content.title?.trim();
    if (entity.documentPublicId.trim().isEmpty ||
        title == null ||
        title.isEmpty) {
      return;
    }
    final sectionNodeId =
        '${entity.documentPublicId}:section:${_graphKey(title)}';
    final existingSection = _knowledgeNodeBox
        .getAll()
        .where((node) => node.publicId == sectionNodeId)
        .firstOrNull;
    _knowledgeNodeBox.put(
      KnowledgeNodeEntity(
        id: existingSection?.id ?? 0,
        publicId: sectionNodeId,
        documentPublicId: entity.documentPublicId,
        label: title,
        nodeType: 'section',
        pageNumber: chunk.source.pageStart,
      ),
    );
    final edgeId = '$nodeId:part_of:$sectionNodeId';
    final existingEdge = _knowledgeEdgeBox
        .getAll()
        .where((edge) => edge.publicId == edgeId)
        .firstOrNull;
    _knowledgeEdgeBox.put(
      KnowledgeEdgeEntity(
        id: existingEdge?.id ?? 0,
        publicId: edgeId,
        documentPublicId: entity.documentPublicId,
        fromNodePublicId: nodeId,
        toNodePublicId: sectionNodeId,
        relationType: 'part_of',
        sourceId: chunk.id,
        weight: 1,
      ),
    );
  }

  String _chunkLabel(Chunk chunk) {
    final title = chunk.content.title?.trim();
    if (title != null && title.isNotEmpty) {
      return title;
    }
    final singleLine = chunk.plainText.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (singleLine.length <= 72) {
      return singleLine;
    }
    return '${singleLine.substring(0, 69)}...';
  }

  String _graphKey(String value) {
    final normalized = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9áéíóöőúüű]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return normalized.isEmpty ? 'section' : normalized;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
