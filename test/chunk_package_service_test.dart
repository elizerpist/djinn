import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/knowledge/data/chunk_package_service.dart';
import 'package:djinn/src/knowledge/data/objectbox_knowledge_repository.dart';
import 'package:djinn/src/knowledge/models/chunk_package.dart';
import 'package:djinn/src/local_store/entities.dart';
import 'package:djinn/src/local_store/objectbox_store.dart';

void main() {
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
