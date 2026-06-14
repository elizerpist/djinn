import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/ai/ai_client.dart';
import 'package:djinn/src/knowledge/data/knowledge_document_repository.dart';
import 'package:djinn/src/knowledge/models/local_extraction.dart';
import 'package:djinn/src/local_store/entities.dart';

void main() {
  test('AI and local chunks coexist and can be compared for one document', () async {
    final repository = KnowledgeDocumentRepository();
    final document = await repository.addDocument(
      filename: 'copd.pdf',
      localPath: '/memory/copd.pdf',
      sizeBytes: 10,
      importedAt: DateTime.utc(2026, 6, 14),
      sha256: 'hash-copd',
    );

    await repository.saveExtractedEvidence(
      documentPublicId: document.id,
      evidence: const AiExtractedEvidence(
        id: 'ai-copd-causes',
        text: 'A COPDAE kiváltó oka leggyakrabban infekció.',
        pageNumber: 1,
        sectionTitle: 'COPDAE',
        sourceType: AiEvidenceSourceType.textChunk,
      ),
      embedding: List<double>.filled(3072, 0.1),
      embeddingModel: 'gemini-embedding-001',
    );

    await repository.saveLocalChunks(
      document.id,
      const [
        LocalChunk(
          id: 'local-copd-causes',
          documentId: 'document-1',
          text: 'A COPDAE kiváltó oka leggyakrabban: infekció; pneumothorax.',
          pageNumber: 1,
          sectionTitle: 'COPDAE',
          pipeline: LocalExtractionPipeline.localOcr,
          kind: LocalChunkKind.list,
          auditState: LocalAuditState.accepted,
        ),
      ],
    );

    final aiItems = await repository.listExtractedKnowledgeItems(
      document.id,
      pipeline: LocalExtractionPipeline.ai,
    );
    final localItems = await repository.listExtractedKnowledgeItems(
      document.id,
      pipeline: LocalExtractionPipeline.localOcr,
    );
    final comparison = await repository.compareExtractedChunks(document.id);

    expect(aiItems, hasLength(1));
    expect(localItems, hasLength(1));
    expect(aiItems.single.pipeline, LocalExtractionPipeline.ai);
    expect(localItems.single.pipeline, LocalExtractionPipeline.localOcr);
    expect(localItems.single.auditState, LocalAuditState.accepted);
    expect(comparison.rows, hasLength(1));
    expect(comparison.rows.single.aiChunk?.id, 'ai-copd-causes');
    expect(comparison.rows.single.localChunk?.id, 'local-copd-causes');
    expect(comparison.rows.single.status, ChunkComparisonStatus.matched);

    await repository.updateExtractedKnowledgeAuditState(
      document.id,
      'local-copd-causes',
      LocalAuditState.rejected,
    );
    final rejectedLocalItems = await repository.listExtractedKnowledgeItems(
      document.id,
      pipeline: LocalExtractionPipeline.localOcr,
    );
    expect(rejectedLocalItems.single.auditState, LocalAuditState.rejected);
  });

  test('document chunk entity defaults old AI chunks to accepted AI text chunks', () {
    final entity = DocumentChunkEntity(
      publicId: 'doc-1:chunk-1',
      documentPublicId: 'doc-1',
      text: 'Régi AI chunk',
      pageNumber: 1,
    );

    expect(entity.pipeline, LocalExtractionPipeline.ai.wireName);
    expect(entity.chunkKind, LocalChunkKind.text.wireName);
    expect(entity.auditState, LocalAuditState.accepted.wireName);
  });
}
