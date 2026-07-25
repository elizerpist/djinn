import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

import '../../../objectbox.g.dart';
import '../../chunks/data/objectbox_chunk_derived_data.dart';
import '../../chunks/data/chunk_entity_codec.dart';
import '../../chunks/models/chunk.dart';
import '../../debug/debug_console.dart';
import '../../flowchart/data/objectbox_flowchart_projection.dart';
import '../../knowledge/models/chunk_package.dart';
import '../../knowledge/models/local_extraction.dart';
import '../../local_store/entities.dart';
import '../models/note_document.dart';
import '../models/note_folder.dart';
import '../models/note_item.dart';
import 'note_repository.dart';

/// ObjectBox-backed collector repository over the one global chunk table.
///
/// The legacy JSON file is read once and deliberately retained as a recovery
/// source. A durable marker is written only after the idempotent import has
/// completed in one transaction.
class ObjectBoxNoteRepository implements NoteRepository {
  ObjectBoxNoteRepository({
    required Store store,
    required File legacyFile,
    Uuid? uuid,
    DateTime Function()? clock,
    ChunkEntityCodec codec = const ChunkEntityCodec(),
  }) : _store = store,
       _legacyFile = legacyFile,
       _uuid = uuid ?? const Uuid(),
       _clock = clock ?? DateTime.now,
       _codec = codec,
       _flowchartProjection = ObjectBoxFlowchartProjection(
         store: store,
         codec: codec,
       ),
       _chunkDerivedData = ObjectBoxChunkDerivedData(store: store),
       _noteBox = store.box<NoteEntity>(),
       _folderBox = store.box<NoteFolderEntity>(),
       _chunkBox = store.box<DocumentChunkEntity>(),
       _embeddingBox = store.box<ChunkEmbeddingEntity>(),
       _linkBox = store.box<ChunkNoteLinkEntity>(),
       _migrationBox = store.box<DataMigrationEntity>();

  static const legacyMigrationKey = 'notes-json-to-unified-chunks-v1';

  final Store _store;
  final File _legacyFile;
  final Uuid _uuid;
  final DateTime Function() _clock;
  final ChunkEntityCodec _codec;
  final ObjectBoxFlowchartProjection _flowchartProjection;
  final ObjectBoxChunkDerivedData _chunkDerivedData;
  final Box<NoteEntity> _noteBox;
  final Box<NoteFolderEntity> _folderBox;
  final Box<DocumentChunkEntity> _chunkBox;
  final Box<ChunkEmbeddingEntity> _embeddingBox;
  final Box<ChunkNoteLinkEntity> _linkBox;
  final Box<DataMigrationEntity> _migrationBox;

  @override
  Future<void> load() async {
    _canonicalizeStoredChunks();
    await _migrateLegacyJson();
  }

  void _canonicalizeStoredChunks() {
    final now = _clock();
    _store.runInTransaction(TxMode.write, () {
      final changed = <DocumentChunkEntity>[];
      for (final entity in _chunkBox.getAll()) {
        if (_codec.canonicalize(entity, now: now)) {
          changed.add(entity);
        }
      }
      if (changed.isNotEmpty) {
        _chunkBox.putMany(changed);
        DebugConsole.log(
          '[ChunkMigration] canonicalized rows=${changed.length}',
        );
      }
    });
  }

  Future<void> _migrateLegacyJson() async {
    if (_findMigration(legacyMigrationKey) != null ||
        !_legacyFile.existsSync()) {
      return;
    }
    final decoded = jsonDecode(await _legacyFile.readAsString());
    if (decoded is! Map) {
      throw const FormatException('Legacy notes file must be a JSON object.');
    }
    final folders = (decoded['folders'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => NoteFolder.fromJson(Map<String, Object?>.from(item)))
        .toList(growable: false);
    final notes = (decoded['notes'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => NoteItem.fromJson(Map<String, Object?>.from(item)))
        .toList(growable: false);
    final now = _clock();
    final timestamp = now.millisecondsSinceEpoch;

    _store.runInTransaction(TxMode.write, () {
      for (final folder in folders) {
        final existing = _findFolder(folder.id);
        _folderBox.put(
          NoteFolderEntity(
            id: existing?.id ?? 0,
            publicId: folder.id,
            title: folder.title,
            createdAtMillis: folder.createdAt.millisecondsSinceEpoch,
            updatedAtMillis: folder.updatedAt.millisecondsSinceEpoch,
            sortOrder: folder.sortOrder,
          ),
        );
      }
      for (final note in notes) {
        final existing = _findNote(note.id);
        _noteBox.put(
          NoteEntity(
            id: existing?.id ?? 0,
            publicId: note.id,
            folderPublicId: note.folderId,
            title: note.title,
            auditState: note.auditState.wireName,
            reason: note.reason,
            tagsJson: _tagsToJson(note.document.tags),
            createdAtMillis: note.createdAt.millisecondsSinceEpoch,
            updatedAtMillis: note.updatedAt.millisecondsSinceEpoch,
          ),
        );
        _upsertLegacyDocument(note, now: now);
      }

      final verifiedNotes = notes.every((note) {
        if (_findNote(note.id) == null) {
          return false;
        }
        final links = _linksForNote(note.id);
        return links.length == note.document.blocks.length &&
            links.every((link) => _findChunk(link.chunkPublicId) != null);
      });
      final verifiedFolders = folders.every(
        (folder) => _findFolder(folder.id) != null,
      );
      if (!verifiedNotes || !verifiedFolders) {
        throw StateError('Legacy note migration verification failed.');
      }
      final existingMarker = _findMigration(legacyMigrationKey);
      _migrationBox.put(
        DataMigrationEntity(
          id: existingMarker?.id ?? 0,
          publicId: legacyMigrationKey,
          completedAtMillis: timestamp,
          details: jsonEncode({
            'notes': notes.length,
            'folders': folders.length,
            'legacy_file_retained': true,
          }),
        ),
      );
    });
    DebugConsole.log(
      '[ChunkMigration] legacy notes imported notes=${notes.length} '
      'folders=${folders.length} file=${_legacyFile.path}',
    );
  }

  void _upsertLegacyDocument(NoteItem note, {required DateTime now}) {
    final existingLinks = _linksForNote(note.id);
    final linkedChunkIds = {
      for (final link in existingLinks) link.chunkPublicId,
    };
    for (var index = 0; index < note.document.blocks.length; index += 1) {
      final block = note.document.blocks[index];
      final chunkId = 'legacy-note:${note.id}:${block.id}:$index';
      final existingChunk = _findChunk(chunkId);
      final chunk = _chunkFromBlock(
        block.copyWith(id: chunkId),
        creationMethod: ChunkCreationMethod.manualSelection,
        validationState: note.auditState,
        source: ChunkSource(
          sourceType: ChunkSourceType.note,
          sourceId: note.id,
          originalText: block.plainText,
        ),
        createdAt: note.createdAt,
        updatedAt: note.updatedAt,
      );
      final entity =
          existingChunk ??
          DocumentChunkEntity(
            publicId: chunkId,
            documentPublicId: '',
            text: chunk.plainText,
            pageNumber: 0,
            pipeline: LocalExtractionPipeline.manual.wireName,
            chunkKind: chunk.kind.wireName,
            auditState: chunk.validationState.wireName,
          );
      _codec.write(entity, chunk, now: now);
      _chunkBox.put(entity);
      if (!linkedChunkIds.contains(chunkId)) {
        _linkBox.put(
          ChunkNoteLinkEntity(
            publicId: _linkId(note.id, chunkId),
            notePublicId: note.id,
            chunkPublicId: chunkId,
            sortOrder: index,
            addedAtMillis: note.createdAt.millisecondsSinceEpoch,
          ),
        );
      }
      _flowchartProjection.projectCanonicalChunk(entity);
    }
  }

  @override
  Future<List<NoteFolder>> listFolders() async {
    final entities = _folderBox.getAll()
      ..sort((a, b) {
        final order = a.sortOrder.compareTo(b.sortOrder);
        return order != 0
            ? order
            : a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
    return List.unmodifiable(entities.map(_folderFromEntity));
  }

  @override
  Future<NoteFolder> createFolder(String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('folder title must not be blank');
    }
    final now = _clock();
    final entity = NoteFolderEntity(
      publicId: _uuid.v4(),
      title: trimmed,
      createdAtMillis: now.millisecondsSinceEpoch,
      updatedAtMillis: now.millisecondsSinceEpoch,
      sortOrder: _folderBox.count(),
    );
    _folderBox.put(entity);
    return _folderFromEntity(entity);
  }

  @override
  Future<void> deleteFolder(String folderId) async {
    _store.runInTransaction(TxMode.write, () {
      final folder = _findFolder(folderId);
      if (folder != null) {
        _folderBox.remove(folder.id);
      }
      final now = _clock().millisecondsSinceEpoch;
      for (final note in _noteBox.getAll()) {
        if (note.folderPublicId == folderId) {
          note.folderPublicId = null;
          note.updatedAtMillis = now;
          _noteBox.put(note);
        }
      }
    });
  }

  @override
  Future<List<NoteItem>> listNotes({
    String? folderId,
    NoteItemType? type,
  }) async {
    if (type != null && type != NoteItemType.document) {
      return const [];
    }
    final entities =
        _noteBox
            .getAll()
            .where(
              (note) => folderId == null || note.folderPublicId == folderId,
            )
            .toList(growable: false)
          ..sort((a, b) => b.updatedAtMillis.compareTo(a.updatedAtMillis));
    return List.unmodifiable(entities.map(_noteFromEntity));
  }

  @override
  Future<NoteItem> createDocumentNote({
    required String title,
    required NoteDocument document,
    String? folderId,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('note title must not be blank');
    }
    final now = _clock();
    final noteId = _uuid.v4();
    final entity = NoteEntity(
      publicId: noteId,
      folderPublicId: folderId,
      title: trimmed,
      auditState: LocalAuditState.unreviewed.wireName,
      tagsJson: _tagsToJson(document.tags),
      createdAtMillis: now.millisecondsSinceEpoch,
      updatedAtMillis: now.millisecondsSinceEpoch,
    );
    _store.runInTransaction(TxMode.write, () {
      _noteBox.put(entity);
      _writeDocumentMemberships(entity, _canonicalDocument(document), now: now);
    });
    return _noteFromEntity(entity);
  }

  @override
  Future<NoteItem> createNote({
    required NoteItemType type,
    required String title,
    required String plainText,
    required String payloadJson,
    String? folderId,
  }) {
    return createDocumentNote(
      title: title,
      document: NoteDocument.fromPayload(
        payloadJson.trim().isEmpty ? '{}' : payloadJson,
        legacyType: type.wireName,
        legacyText: plainText,
        title: title,
      ),
      folderId: folderId,
    );
  }

  @override
  Future<List<NoteItem>> importNotes(
    List<NoteItem> notes, {
    String? folderId,
  }) async {
    final imported = <NoteItem>[];
    for (final note in notes) {
      final created = await createDocumentNote(
        title: note.title.trim().isEmpty ? 'Importált jegyzet' : note.title,
        document: note.document,
        folderId: folderId,
      );
      final updated = await updateNoteDocument(
        created.id,
        title: created.title,
        document: created.document,
        auditState: note.auditState,
        reason: note.reason,
      );
      _markNoteChunksImported(created.id, importedSourceId: note.id);
      imported.add(updated);
    }
    return List.unmodifiable(imported);
  }

  void _markNoteChunksImported(
    String noteId, {
    required String importedSourceId,
  }) {
    final now = _clock();
    _store.runInTransaction(TxMode.write, () {
      for (final link in _linksForNote(noteId)) {
        final entity = _findChunk(link.chunkPublicId);
        if (entity == null) {
          continue;
        }
        final stored = _codec.decode(entity);
        final source = ChunkSource(
          sourceType: ChunkSourceType.importedFile,
          sourceId: importedSourceId,
          originalText: stored.source.originalText ?? stored.plainText,
        );
        final imported = switch (stored) {
          NoteChunk() => NoteChunk(
            id: stored.id,
            creationMethod: ChunkCreationMethod.imported,
            validationState: stored.validationState,
            source: source,
            createdAt: stored.createdAt,
            updatedAt: now,
            content: stored.content,
          ),
          FlowchartChunk() => FlowchartChunk(
            id: stored.id,
            creationMethod: ChunkCreationMethod.imported,
            validationState: stored.validationState,
            source: source,
            createdAt: stored.createdAt,
            updatedAt: now,
            content: stored.content,
          ),
        };
        _codec.write(entity, imported, now: now);
        _chunkBox.put(entity);
      }
    });
  }

  @override
  Future<NoteItem> updateNoteDocument(
    String noteId, {
    required String title,
    required NoteDocument document,
    LocalAuditState? auditState,
    String? reason,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('note title must not be blank');
    }
    final now = _clock();
    final entity = _findNote(noteId);
    if (entity == null) {
      throw StateError('note not found: $noteId');
    }
    _store.runInTransaction(TxMode.write, () {
      entity.title = trimmed;
      entity.tagsJson = _tagsToJson(document.tags);
      entity.auditState =
          (auditState ?? LocalAuditState.fromWireName(entity.auditState))
              .wireName;
      final trimmedReason = reason?.trim();
      entity.reason = trimmedReason == null || trimmedReason.isEmpty
          ? null
          : trimmedReason;
      entity.updatedAtMillis = now.millisecondsSinceEpoch;
      _noteBox.put(entity);
      _writeDocumentMemberships(entity, _canonicalDocument(document), now: now);
    });
    return _noteFromEntity(entity);
  }

  @override
  Future<NoteItem> updateNoteValidation(
    String noteId, {
    required LocalAuditState auditState,
    String? plainText,
    String? payloadJson,
    String? reason,
  }) async {
    final existing = _noteById(noteId);
    final document = payloadJson == null && plainText != null
        ? NoteDocument(
            blocks: [
              NoteBlock(
                id: existing.document.blocks.firstOrNull?.id ?? 'block-1',
                type: NoteBlockType.paragraph,
                text: plainText,
              ),
            ],
          )
        : NoteDocument.fromPayload(
            payloadJson ?? existing.payloadJson,
            legacyType: existing.type.wireName,
            legacyText: plainText ?? existing.plainText,
            title: existing.title,
          );
    return updateNoteDocument(
      noteId,
      title: existing.title,
      document: document,
      auditState: auditState,
      reason: reason,
    );
  }

  @override
  Future<NoteItem> markNoteBlocksIndexed(
    String noteId,
    List<String> blockIds,
  ) async {
    final existing = _noteById(noteId);
    final ids = blockIds.toSet();
    final now = _clock();
    final document = existing.document.copyWith(
      blocks: [
        for (final block in existing.document.blocks)
          if (ids.contains(block.id))
            block.copyWith(
              indexedContentHash: block.contentHash,
              indexedAt: now,
            )
          else
            block,
      ],
    );
    return updateNoteDocument(
      noteId,
      title: existing.title,
      document: document,
      auditState: existing.auditState,
      reason: existing.reason,
    );
  }

  @override
  Future<NoteItem> moveNoteToFolder(String noteId, String? folderId) async {
    final entity = _findNote(noteId);
    if (entity == null) {
      throw StateError('note not found: $noteId');
    }
    entity.folderPublicId = folderId;
    entity.updatedAtMillis = _clock().millisecondsSinceEpoch;
    _noteBox.put(entity);
    return _noteFromEntity(entity);
  }

  @override
  Future<ChunkLinkResult> linkChunksToNote(
    String noteId,
    Iterable<String> chunkIds,
  ) async {
    final note = _findNote(noteId);
    if (note == null) {
      throw StateError('note not found: $noteId');
    }
    final normalizedIds = [
      for (final id in chunkIds)
        if (id.trim().isNotEmpty) id.trim(),
    ];
    var addedCount = 0;
    var alreadyLinkedCount = 0;
    _store.runInTransaction(TxMode.write, () {
      final existingLinks = _linksForNote(noteId);
      final linkedIds = {for (final link in existingLinks) link.chunkPublicId};
      var sortOrder = existingLinks.isEmpty
          ? 0
          : existingLinks
                    .map((link) => link.sortOrder)
                    .reduce((a, b) => a > b ? a : b) +
                1;
      for (final chunkId in normalizedIds) {
        if (_findChunk(chunkId) == null) {
          throw StateError('chunk not found: $chunkId');
        }
        if (!linkedIds.add(chunkId)) {
          alreadyLinkedCount += 1;
          continue;
        }
        _linkBox.put(
          ChunkNoteLinkEntity(
            publicId: _linkId(noteId, chunkId),
            notePublicId: noteId,
            chunkPublicId: chunkId,
            sortOrder: sortOrder,
            addedAtMillis: _clock().millisecondsSinceEpoch,
          ),
        );
        sortOrder += 1;
        addedCount += 1;
      }
      if (addedCount > 0) {
        note.updatedAtMillis = _clock().millisecondsSinceEpoch;
        _noteBox.put(note);
      }
    });
    return ChunkLinkResult(
      addedCount: addedCount,
      alreadyLinkedCount: alreadyLinkedCount,
    );
  }

  @override
  Future<Set<String>> listLinkedChunkIds(String noteId) async {
    if (_findNote(noteId) == null) {
      throw StateError('note not found: $noteId');
    }
    return Set.unmodifiable(
      _linksForNote(noteId).map((link) => link.chunkPublicId),
    );
  }

  @override
  Future<List<Chunk>> listChunksForNote(String noteId) async {
    if (_findNote(noteId) == null) {
      throw StateError('note not found: $noteId');
    }
    return List.unmodifiable([
      for (final link in _linksForNote(noteId))
        if (_findChunk(link.chunkPublicId) case final entity?)
          _codec.decode(entity),
    ]);
  }

  @override
  Future<ChunkPackage> exportChunkPackageForNote(
    String noteId, {
    bool includeSourceMetadata = true,
  }) async {
    final note = _findNote(noteId);
    if (note == null) {
      throw StateError('note not found: $noteId');
    }
    final embeddings = _embeddingBox.getAll();
    final items = <ChunkPackageItem>[];
    final models = <String>{};
    final dimensions = <int>{};
    for (final link in _linksForNote(noteId)) {
      final entity = _findChunk(link.chunkPublicId);
      if (entity == null) {
        continue;
      }
      final chunk = _codec.decode(entity);
      final relatedEmbeddings = embeddings
          .where(
            (embedding) =>
                embedding.sourceId == chunk.id ||
                embedding.sourceId.startsWith('${chunk.id}:'),
          )
          .where((embedding) => embedding.vector?.isNotEmpty == true)
          .toList(growable: false);
      models.addAll(relatedEmbeddings.map((embedding) => embedding.model));
      dimensions.addAll(
        relatedEmbeddings.map((embedding) => embedding.vector!.length),
      );
      final parentEmbedding = relatedEmbeddings
          .where((embedding) => embedding.sourceId == chunk.id)
          .firstOrNull;
      items.add(
        ChunkPackageItem(
          id: chunk.id,
          text: chunk.plainText,
          pageNumber: includeSourceMetadata
              ? chunk.source.pageStart ?? entity.pageNumber
              : 0,
          sectionTitle: chunk.content.title,
          embedding: parentEmbedding?.vector ?? const [],
          kind: chunk.kind,
          creationMethod: chunk.creationMethod,
          validationState: chunk.validationState,
          source: includeSourceMetadata ? chunk.source : const ChunkSource(),
          content: chunk.content,
          embeddingRecords: [
            for (final embedding in relatedEmbeddings)
              ChunkPackageEmbedding(
                sourceId: embedding.sourceId,
                sourceType: embedding.sourceType,
                vector: embedding.vector!,
                model: embedding.model,
              ),
          ],
        ),
      );
    }
    return ChunkPackage(
      schemaVersion: 2,
      documentHash: '',
      filename: note.title,
      provider: '',
      extractionModel: '',
      embeddingModel: models.length == 1 ? models.single : '',
      embeddingDimension: dimensions.length == 1 ? dimensions.single : 0,
      chunks: items,
    );
  }

  @override
  Future<void> deleteNotes(List<String> noteIds) async {
    final ids = noteIds.toSet();
    _store.runInTransaction(TxMode.write, () {
      for (final noteId in ids) {
        final note = _findNote(noteId);
        if (note == null) {
          continue;
        }
        final links = _linksForNote(noteId);
        _linkBox.removeMany(links.map((link) => link.id).toList());
        _noteBox.remove(note.id);
        for (final link in links) {
          _deleteOrphanUserChunk(link.chunkPublicId);
        }
      }
    });
  }

  void _writeDocumentMemberships(
    NoteEntity note,
    NoteDocument document, {
    required DateTime now,
  }) {
    final existingLinks = _linksForNote(note.publicId);
    final existingByChunkId = {
      for (final link in existingLinks) link.chunkPublicId: link,
    };
    final retainedIds = <String>{};
    for (var index = 0; index < document.blocks.length; index += 1) {
      final incomingBlock = document.blocks[index];
      final linkedEntity = existingByChunkId[incomingBlock.id] == null
          ? null
          : _findChunk(incomingBlock.id);
      final chunkId =
          linkedEntity?.publicId ??
          _newChunkId(note.publicId, incomingBlock.id);
      final existingChunk = linkedEntity ?? _findChunk(chunkId);
      final oldChunk = existingChunk == null
          ? null
          : _codec.decode(existingChunk);
      final normalizedBlock = incomingBlock.copyWith(id: chunkId);
      final chunk = _chunkFromBlock(
        normalizedBlock,
        creationMethod:
            oldChunk?.creationMethod ?? ChunkCreationMethod.manualSelection,
        validationState:
            oldChunk?.validationState ??
            LocalAuditState.fromWireName(note.auditState),
        source:
            oldChunk?.source ??
            ChunkSource(
              sourceType: ChunkSourceType.note,
              sourceId: note.publicId,
              originalText: normalizedBlock.plainText,
            ),
        createdAt: oldChunk?.createdAt ?? now,
        updatedAt: now,
      );
      final entity =
          existingChunk ??
          DocumentChunkEntity(
            publicId: chunkId,
            documentPublicId: '',
            text: chunk.plainText,
            pageNumber: 0,
            pipeline: LocalExtractionPipeline.manual.wireName,
            chunkKind: chunk.kind.wireName,
            auditState: chunk.validationState.wireName,
          );
      _codec.write(entity, chunk, now: now);
      _chunkBox.put(entity);
      if (oldChunk != null) {
        _chunkDerivedData.synchronizeMutation(
          before: oldChunk,
          after: chunk,
          entity: entity,
        );
      }

      final link = existingByChunkId[chunkId];
      _linkBox.put(
        ChunkNoteLinkEntity(
          id: link?.id ?? 0,
          publicId: _linkId(note.publicId, chunkId),
          notePublicId: note.publicId,
          chunkPublicId: chunkId,
          sortOrder: index,
          addedAtMillis: link?.addedAtMillis ?? now.millisecondsSinceEpoch,
        ),
      );
      _flowchartProjection.projectCanonicalChunk(entity);
      retainedIds.add(chunkId);
    }
    for (final link in existingLinks) {
      if (retainedIds.contains(link.chunkPublicId)) {
        continue;
      }
      _linkBox.remove(link.id);
      _deleteOrphanUserChunk(link.chunkPublicId);
    }
  }

  void _deleteOrphanUserChunk(String chunkId) {
    if (_linkBox.getAll().any((link) => link.chunkPublicId == chunkId)) {
      return;
    }
    final chunk = _findChunk(chunkId);
    if (chunk != null && chunk.documentPublicId.trim().isEmpty) {
      final embeddingIds = _embeddingBox
          .getAll()
          .where(
            (embedding) =>
                embedding.sourceId == chunkId ||
                embedding.sourceId.startsWith('$chunkId:'),
          )
          .map((embedding) => embedding.id)
          .toList(growable: false);
      if (embeddingIds.isNotEmpty) {
        _embeddingBox.removeMany(embeddingIds);
      }
      _flowchartProjection.removeProjection(chunkId);
      _chunkBox.remove(chunk.id);
    }
  }

  NoteDocument _canonicalDocument(NoteDocument document) {
    final blocks = document.blocks.isEmpty
        ? NoteDocument.empty().blocks
        : document.blocks;
    return NoteDocument(
      schemaVersion: document.schemaVersion,
      tags: document.tags,
      blocks: [
        for (final block in blocks)
          if (block.type == NoteBlockType.flowchart)
            block
          else
            normalizeLegacyNoteBlock(block),
      ],
    );
  }

  Chunk _chunkFromBlock(
    NoteBlock block, {
    required ChunkCreationMethod creationMethod,
    required LocalAuditState validationState,
    ChunkSource source = const ChunkSource(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    if (block.type == NoteBlockType.flowchart) {
      return FlowchartChunk(
        id: block.id,
        creationMethod: creationMethod,
        validationState: validationState,
        source: source,
        createdAt: createdAt,
        updatedAt: updatedAt,
        content: block,
      );
    }
    return NoteChunk.fromLegacyBlock(
      block: block,
      creationMethod: creationMethod,
      validationState: validationState,
      source: source,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  NoteItem _noteFromEntity(NoteEntity entity) {
    final blocks = <NoteBlock>[];
    for (final link in _linksForNote(entity.publicId)) {
      final chunkEntity = _findChunk(link.chunkPublicId);
      if (chunkEntity == null) {
        continue;
      }
      blocks.add(
        _codec.decode(chunkEntity).content.copyWith(id: link.chunkPublicId),
      );
    }
    final document = NoteDocument(
      tags: _tagsFromJson(entity.tagsJson),
      blocks: blocks,
    );
    return NoteItem(
      id: entity.publicId,
      folderId: entity.folderPublicId,
      type: NoteItemType.document,
      title: entity.title,
      plainText: document.plainText,
      payloadJson: document.toPayloadJson(),
      auditState: LocalAuditState.fromWireName(entity.auditState),
      reason: entity.reason,
      createdAt: DateTime.fromMillisecondsSinceEpoch(entity.createdAtMillis),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(entity.updatedAtMillis),
    );
  }

  NoteItem _noteById(String noteId) {
    final entity = _findNote(noteId);
    if (entity == null) {
      throw StateError('note not found: $noteId');
    }
    return _noteFromEntity(entity);
  }

  NoteEntity? _findNote(String publicId) {
    return _noteBox
        .getAll()
        .where((entity) => entity.publicId == publicId)
        .firstOrNull;
  }

  NoteFolderEntity? _findFolder(String publicId) {
    return _folderBox
        .getAll()
        .where((entity) => entity.publicId == publicId)
        .firstOrNull;
  }

  DocumentChunkEntity? _findChunk(String publicId) {
    return _chunkBox
        .getAll()
        .where((entity) => entity.publicId == publicId)
        .firstOrNull;
  }

  DataMigrationEntity? _findMigration(String publicId) {
    return _migrationBox
        .getAll()
        .where((entity) => entity.publicId == publicId)
        .firstOrNull;
  }

  List<ChunkNoteLinkEntity> _linksForNote(String noteId) {
    final links =
        _linkBox
            .getAll()
            .where((link) => link.notePublicId == noteId)
            .toList(growable: false)
          ..sort((a, b) {
            final order = a.sortOrder.compareTo(b.sortOrder);
            return order != 0 ? order : a.publicId.compareTo(b.publicId);
          });
    return links;
  }

  NoteFolder _folderFromEntity(NoteFolderEntity entity) {
    return NoteFolder(
      id: entity.publicId,
      title: entity.title,
      createdAt: DateTime.fromMillisecondsSinceEpoch(entity.createdAtMillis),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(entity.updatedAtMillis),
      sortOrder: entity.sortOrder,
    );
  }

  String _newChunkId(String noteId, String requestedBlockId) {
    final trimmed = requestedBlockId.trim();
    final canonicalPrefix = '$noteId:chunk:';
    if (trimmed.startsWith(canonicalPrefix)) {
      return trimmed;
    }
    final base = trimmed.isEmpty ? _uuid.v4() : trimmed;
    var candidate = '$canonicalPrefix$base';
    while (_findChunk(candidate) != null) {
      candidate = '$noteId:chunk:${_uuid.v4()}';
    }
    return candidate;
  }

  String _linkId(String noteId, String chunkId) {
    return 'note-chunk-link:$noteId:$chunkId';
  }

  String? _tagsToJson(List<NoteKnowledgeTag> tags) {
    if (tags.isEmpty) {
      return null;
    }
    return jsonEncode([for (final tag in tags) tag.toJson()]);
  }

  List<NoteKnowledgeTag> _tagsFromJson(String? value) {
    if (value == null || value.trim().isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(value);
      if (decoded is! List) {
        return const [];
      }
      return decoded
          .map(NoteKnowledgeTag.fromJson)
          .where((tag) => tag.label.trim().isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
