import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/ai/ai_client.dart';
import 'package:djinn/src/chunks/models/chunk.dart';
import 'package:djinn/src/knowledge/data/chunk_package_service.dart';
import 'package:djinn/src/knowledge/data/objectbox_knowledge_repository.dart';
import 'package:djinn/src/knowledge/models/chunk_package.dart';
import 'package:djinn/src/knowledge/models/local_extraction.dart';
import 'package:djinn/src/local_store/entities.dart';
import 'package:djinn/src/local_store/objectbox_store.dart';
import 'package:djinn/src/notes/models/note_document.dart';

void main() {
  test(
    'schema 2 exports only canonical kinds with editable content and provenance',
    () {
      final noteContent = normalizeLegacyNoteBlock(
        const NoteBlock(
          id: 'note-1',
          type: NoteBlockType.paragraph,
          text: 'Kiemelt tudáselem',
          tags: [
            NoteKnowledgeTag(type: NoteKnowledgeTagTypes.topic, label: 'COPD'),
          ],
          textFills: [
            NoteTextFill(
              id: 'fill-1',
              start: 0,
              end: 7,
              colorValue: 0xFFFFE082,
            ),
          ],
        ),
      );
      const flowchartContent = NoteBlock(
        id: 'flow-1',
        type: NoteBlockType.flowchart,
        nodes: [
          NoteFlowchartNode(
            id: 'node-1',
            label: 'Kezdés',
            shape: AiFlowchartNodeShape.startEnd,
            order: 0,
          ),
        ],
      );
      final package = ChunkPackage(
        schemaVersion: 2,
        documentHash: 'hash',
        filename: 'source.pdf',
        provider: 'openai',
        extractionModel: 'gpt-5.5',
        embeddingModel: 'text-embedding-3-large',
        embeddingDimension: 2,
        chunks: [
          ChunkPackageItem(
            id: 'note-1',
            text: noteContent.plainText,
            pageNumber: 3,
            sectionTitle: 'Tétel',
            embedding: const [0.1, 0.2],
            kind: ChunkKind.noteChunk,
            creationMethod: ChunkCreationMethod.assistedSelection,
            validationState: LocalAuditState.edited,
            source: const ChunkSource(
              sourceType: ChunkSourceType.pdf,
              sourceId: 'document-1',
              pageStart: 3,
              pageEnd: 4,
              originalText: 'Eredeti szöveg',
            ),
            content: noteContent,
          ),
          const ChunkPackageItem(
            id: 'flow-1',
            text: 'Kezdés',
            pageNumber: 5,
            sectionTitle: 'Folyamat',
            embedding: [],
            kind: ChunkKind.flowchartChunk,
            creationMethod: ChunkCreationMethod.aiGenerated,
            validationState: LocalAuditState.unreviewed,
            source: ChunkSource(
              sourceType: ChunkSourceType.pdf,
              sourceId: 'document-1',
              pageStart: 5,
            ),
            content: flowchartContent,
          ),
        ],
      );

      final json = package.toJson();
      final encodedKinds = (json['chunks']! as List)
          .cast<Map<String, Object?>>()
          .map((item) => item['kind'])
          .toSet();
      final parsed = ChunkPackage.fromJson(json);

      expect(encodedKinds, {'note_chunk', 'flowchart_chunk'});
      expect(
        (json['chunks']! as List).first,
        containsPair('creation_method', 'assisted_selection'),
      );
      expect(
        ((json['chunks']! as List).first as Map)['content'].toString(),
        contains('textFills'),
      );
      expect(parsed.chunks.first.content?.knownTags.single.label, 'COPD');
      expect(
        parsed.chunks.first.content?.mixedSections.single.textFills.single.id,
        'fill-1',
      );
      expect(parsed.chunks.last.kind, ChunkKind.flowchartChunk);
      expect(parsed.chunks.last.content?.nodes.single.label, 'Kezdés');
      expect(parsed.chunks.last.embedding, isEmpty);
    },
  );

  test('schema 2 preserves heterogeneous parent and flowchart embeddings', () {
    const package = ChunkPackage(
      schemaVersion: 2,
      documentHash: 'hash',
      filename: 'flow.pdf',
      provider: '',
      extractionModel: '',
      embeddingModel: '',
      embeddingDimension: 0,
      chunks: [
        ChunkPackageItem(
          id: 'flow-1',
          text: 'Kezdés',
          pageNumber: 1,
          sectionTitle: null,
          embedding: [],
          kind: ChunkKind.flowchartChunk,
          content: NoteBlock(
            id: 'flow-1',
            type: NoteBlockType.flowchart,
            nodes: [NoteFlowchartNode(id: 'node-1', label: 'Kezdés')],
          ),
          embeddingRecords: [
            ChunkPackageEmbedding(
              sourceId: 'flow-1',
              sourceType: 'flowchart',
              vector: [0.1, 0.2],
              model: 'parent-model',
            ),
            ChunkPackageEmbedding(
              sourceId: 'node-1',
              sourceType: 'flowchart_node',
              vector: [0.3, 0.4, 0.5],
              model: 'node-model',
            ),
          ],
        ),
      ],
    );

    final parsed = ChunkPackage.fromJson(
      jsonDecode(jsonEncode(package.toJson())) as Map<String, Object?>,
    );

    expect(parsed.embeddingDimension, 0);
    expect(parsed.chunks.single.embeddingRecords, hasLength(2));
    expect(parsed.chunks.single.embeddingRecords.map((item) => item.model), [
      'parent-model',
      'node-model',
    ]);
    expect(parsed.chunks.single.embeddingRecords.last.vector, hasLength(3));
    expect(
      () => const ChunkPackageService().validateForImport(
        parsed,
        documentHash: 'hash',
        expectedDimension: 0,
      ),
      returnsNormally,
    );
  });

  test('schema 1 import migrates legacy rows into a canonical note chunk', () {
    final package = ChunkPackage.fromJson(
      jsonDecode('''
      {
        "schema_version": 1,
        "document_hash": "hash",
        "filename": "legacy.pdf",
        "provider": "openai",
        "extraction_model": "gpt-4",
        "embedding_model": "legacy-embedding",
        "embedding_dimension": 2,
        "chunks": [
          {
            "id": "legacy-table",
            "text": "A | B",
            "page_number": 2,
            "section_title": "Régi táblázat",
            "embedding": [0.1, 0.2],
            "kind": "table"
          }
        ]
      }
      ''')
          as Map<String, Object?>,
    );

    final chunk = package.chunks.single;
    expect(chunk.kind, ChunkKind.noteChunk);
    expect(chunk.creationMethod, ChunkCreationMethod.imported);
    expect(chunk.content?.type, NoteBlockType.mixed);
    expect(chunk.sectionTitle, 'Régi táblázat');
    expect(
      chunk.content?.plainText,
      'A | B',
      reason:
          'A legacy section title is metadata and must not be duplicated into '
          'the editable chunk body.',
    );
  });

  test('schema 2 rejects non-canonical chunk kind names', () {
    expect(
      () => ChunkPackage.fromJson({
        'schema_version': 2,
        'document_hash': 'hash',
        'filename': 'invalid.pdf',
        'provider': '',
        'extraction_model': '',
        'embedding_model': '',
        'embedding_dimension': 0,
        'chunks': [
          {
            'id': 'legacy-text',
            'text': 'Régi',
            'page_number': 1,
            'section_title': null,
            'embedding': <double>[],
            'kind': 'text',
            'creation_method': 'imported',
            'validation_state': 'accepted',
            'content': {
              'id': 'legacy-text',
              'type': 'mixed',
              'mixedSections': [
                {'id': 'paragraph-1', 'type': 'paragraph', 'text': 'Régi'},
              ],
            },
          },
        ],
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('schema 2 validation accepts unembedded manual chunks', () {
    const service = ChunkPackageService();
    final package = ChunkPackage(
      schemaVersion: 2,
      documentHash: 'hash',
      filename: 'source.pdf',
      provider: '',
      extractionModel: '',
      embeddingModel: 'text-embedding-3-large',
      embeddingDimension: 2,
      chunks: const [
        ChunkPackageItem(
          id: 'manual-1',
          text: 'Saját chunk',
          pageNumber: 1,
          sectionTitle: null,
          embedding: [],
          kind: ChunkKind.noteChunk,
          creationMethod: ChunkCreationMethod.manualSelection,
          validationState: LocalAuditState.accepted,
          content: NoteBlock(
            id: 'manual-1',
            type: NoteBlockType.mixed,
            mixedSections: [
              NoteMixedSection(
                id: 'paragraph-1',
                type: NoteMixedSectionType.paragraph,
                text: 'Saját chunk',
              ),
            ],
          ),
        ),
      ],
    );

    expect(
      () => service.validateForImport(
        package,
        documentHash: 'hash',
        expectedDimension: 2,
      ),
      returnsNormally,
    );
  });

  test('exports chunk package with hash model and dimension metadata', () {
    final package = ChunkPackage(
      schemaVersion: 1,
      documentHash: 'hash',
      filename: 'stroke.pdf',
      provider: 'openai',
      extractionModel: 'gpt-5.5',
      embeddingModel: 'text-embedding-3-large',
      embeddingDimension: 3072,
      chunks: const [
        ChunkPackageItem(
          id: 'p1-main',
          text: 'ABCDE',
          pageNumber: 1,
          sectionTitle: null,
          embedding: [0.1, 0.2],
        ),
      ],
    );

    final json = package.toJson();

    expect(json['document_hash'], 'hash');
    expect(json['embedding_dimension'], 3072);
    expect(ChunkPackage.fromJson(json).chunks.single.id, 'p1-main');
  });

  test('rejects import when document hash differs', () {
    final service = ChunkPackageService();
    final package = ChunkPackage.fromJson(
      jsonDecode('''
      {
        "schema_version": 1,
        "document_hash": "hash-a",
        "filename": "a.pdf",
        "provider": "openai",
        "extraction_model": "gpt-5.5",
        "embedding_model": "text-embedding-3-large",
        "embedding_dimension": 3072,
        "chunks": []
      }
      ''')
          as Map<String, Object?>,
    );

    expect(
      () => service.validateForImport(
        package,
        documentHash: 'hash-b',
        expectedDimension: 3072,
      ),
      throwsA(isA<ChunkPackageException>()),
    );
  });

  test('rejects import when embedding dimension differs from store', () {
    const service = ChunkPackageService();
    final package = ChunkPackage(
      schemaVersion: 1,
      documentHash: 'hash',
      filename: 'stroke.pdf',
      provider: 'openai',
      extractionModel: 'gpt-5.5',
      embeddingModel: 'text-embedding-3-large',
      embeddingDimension: 1536,
      chunks: const [
        ChunkPackageItem(
          id: 'p1-main',
          text: 'ABCDE',
          pageNumber: 1,
          sectionTitle: null,
          embedding: [0.1, 0.2, 0.3],
        ),
      ],
    );

    expect(
      () => service.validateForImport(
        package,
        documentHash: 'hash',
        expectedDimension: 3072,
      ),
      throwsA(isA<ChunkPackageException>()),
    );
  });

  test('rejects import when package contains duplicate chunk ids', () {
    const service = ChunkPackageService();
    final package = ChunkPackage(
      schemaVersion: 1,
      documentHash: 'hash',
      filename: 'stroke.pdf',
      provider: 'openai',
      extractionModel: 'gpt-5.5',
      embeddingModel: 'text-embedding-3-large',
      embeddingDimension: 2,
      chunks: const [
        ChunkPackageItem(
          id: 'p1-main',
          text: 'ABCDE',
          pageNumber: 1,
          sectionTitle: null,
          embedding: [0.1, 0.2],
        ),
        ChunkPackageItem(
          id: 'p1-main',
          text: 'FGHIJ',
          pageNumber: 2,
          sectionTitle: null,
          embedding: [0.3, 0.4],
        ),
      ],
    );

    expect(
      () => service.validateForImport(
        package,
        documentHash: 'hash',
        expectedDimension: 2,
      ),
      throwsA(isA<ChunkPackageException>()),
    );
  });

  test('rejects malformed package JSON instead of dropping chunks', () {
    expect(
      () => ChunkPackage.fromJson({
        'schema_version': 1,
        'document_hash': 'hash',
        'filename': 'stroke.pdf',
        'provider': 'openai',
        'extraction_model': 'gpt-5.5',
        'embedding_model': 'text-embedding-3-large',
        'embedding_dimension': 3072,
        'chunks': ['not-a-chunk'],
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects malformed package embeddings instead of dropping values', () {
    expect(
      () => ChunkPackage.fromJson({
        'schema_version': 1,
        'document_hash': 'hash',
        'filename': 'stroke.pdf',
        'provider': 'openai',
        'extraction_model': 'gpt-5.5',
        'embedding_model': 'text-embedding-3-large',
        'embedding_dimension': 3072,
        'chunks': [
          {
            'id': 'p1-main',
            'text': 'ABCDE',
            'page_number': 1,
            'section_title': null,
            'embedding': [0.1, 'bad'],
          },
        ],
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'ObjectBox repository saves local chunks with repeated section titles',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'djinn-local-graph-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final ObjectBoxStore objectBox;
      try {
        objectBox = await ObjectBoxStore.open(directory: directory);
      } on ArgumentError catch (error) {
        markTestSkipped('Host ObjectBox library unavailable: $error');
        return;
      }
      addTearDown(objectBox.close);
      final repository = ObjectBoxKnowledgeRepository(store: objectBox.store);
      final document = await repository.addImportedDocument(
        filename: 'copd.pdf',
        localPath: '/memory/copd.pdf',
        sizeBytes: 4,
        sha256: 'hash-copd-local',
      );

      await repository.saveLocalChunks(document.publicId, const [
        LocalChunk(
          id: 'local-text-p1-1',
          documentId: 'document-1',
          text: 'Első lokális OCR sor.',
          pageNumber: 1,
          sectionTitle: 'COPDAE kiváltó okai',
          pipeline: LocalExtractionPipeline.localOcr,
        ),
        LocalChunk(
          id: 'local-text-p1-2',
          documentId: 'document-1',
          text: 'Második lokális OCR sor.',
          pageNumber: 1,
          sectionTitle: 'COPDAE kiváltó okai',
          pipeline: LocalExtractionPipeline.localOcr,
        ),
      ]);

      final items = await repository.listExtractedKnowledgeItems(
        document.publicId,
        pipeline: LocalExtractionPipeline.localOcr,
      );

      expect(items, hasLength(2));
    },
  );

  test(
    'ObjectBox repository exports and imports text chunk packages',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'djinn-chunk-package-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final ObjectBoxStore objectBox;
      try {
        objectBox = await ObjectBoxStore.open(directory: directory);
      } on ArgumentError catch (error) {
        markTestSkipped('Host ObjectBox library unavailable: $error');
        return;
      }
      addTearDown(objectBox.close);
      final repository = ObjectBoxKnowledgeRepository(store: objectBox.store);
      final source = await repository.addImportedDocument(
        filename: 'stroke.pdf',
        localPath: '/memory/stroke.pdf',
        sizeBytes: 4,
        sha256: 'hash-stroke',
      );
      await repository.updateProcessingState(
        source.publicId,
        ProcessingState.ready,
        activeProvider: 'openai',
        activeModel: 'gpt-5.5',
      );
      final embedding = List<double>.filled(3072, 0.25);
      await repository.saveChunk(
        DocumentChunkEntity(
          publicId: '${source.publicId}:p1-main',
          documentPublicId: source.publicId,
          text: 'ABCDE protokoll',
          pageNumber: 1,
        ),
        ChunkEmbeddingEntity(
          sourceId: '${source.publicId}:p1-main',
          sourceType: EvidenceSourceType.textChunk.wireName,
          vector: embedding,
          model: 'text-embedding-3-large',
          createdAtMillis: 1760000000000,
        ),
      );

      final exported = await repository.exportChunkPackage(source.publicId);

      expect(exported.documentHash, 'hash-stroke');
      expect(exported.provider, 'openai');
      expect(exported.extractionModel, 'gpt-5.5');
      expect(exported.embeddingModel, 'text-embedding-3-large');
      expect(exported.embeddingDimension, 3072);
      expect(exported.chunks.single.id, 'p1-main');

      final target = await repository.addImportedDocument(
        filename: 'stroke-copy.pdf',
        localPath: '/memory/stroke-copy.pdf',
        sizeBytes: 4,
        sha256: 'hash-stroke',
      );
      await repository.importChunkPackage(target.publicId, exported);
      final reexported = await repository.exportChunkPackage(target.publicId);
      final importedDocument = (await repository.listDocuments()).singleWhere(
        (document) => document.publicId == target.publicId,
      );

      expect(reexported.chunks.single.text, 'ABCDE protokoll');
      expect(reexported.chunks.single.embedding, hasLength(3072));
      expect(reexported.embeddingModel, 'text-embedding-3-large');
      expect(importedDocument.processingState, ProcessingState.ready.wireName);
      expect(importedDocument.activeProvider, 'openai');
      expect(importedDocument.activeModel, 'gpt-5.5');

      final replacement = ChunkPackage(
        schemaVersion: 1,
        documentHash: 'hash-stroke',
        filename: 'stroke.pdf',
        provider: 'openai',
        extractionModel: 'gpt-5.5',
        embeddingModel: 'text-embedding-3-large',
        embeddingDimension: 3072,
        chunks: [
          ChunkPackageItem(
            id: 'p2-main',
            text: 'Csere chunk',
            pageNumber: 2,
            sectionTitle: null,
            embedding: List<double>.filled(3072, 0.5),
          ),
        ],
      );

      await repository.importChunkPackage(target.publicId, replacement);
      final replaced = await repository.exportChunkPackage(target.publicId);

      expect(replaced.chunks.single.id, 'p2-main');
      expect(replaced.chunks.single.text, 'Csere chunk');
    },
  );
}
