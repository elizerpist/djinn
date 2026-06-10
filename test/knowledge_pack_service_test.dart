import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/knowledge/data/knowledge_pack_service.dart';
import 'package:djinn/src/knowledge/models/chunk_package.dart';
import 'package:djinn/src/knowledge/models/knowledge_pack.dart';

void main() {
  test('encodes and decodes PDF bytes with chunk package metadata', () {
    const service = KnowledgePackService();
    final pack = KnowledgePack(
      schemaVersion: 1,
      documents: [
        KnowledgePackDocument(
          filename: 'protocol.pdf',
          documentHash: 'hash-protocol',
          pdfBytes: [37, 80, 68, 70],
          chunkPackage: ChunkPackage(
            schemaVersion: 1,
            documentHash: 'hash-protocol',
            filename: 'protocol.pdf',
            provider: 'gemini',
            extractionModel: 'gemini-2.5-flash-lite',
            embeddingModel: 'gemini-embedding-001',
            embeddingDimension: 3072,
            chunks: [
              ChunkPackageItem(
                id: 'p1-main',
                text: 'ABCDE protokoll',
                pageNumber: 1,
                sectionTitle: 'ABCDE',
                embedding: List<double>.filled(3072, 0.25),
              ),
            ],
          ),
        ),
      ],
    );

    final encoded = service.encode(pack);
    final decoded = service.decode(encoded);

    expect(decoded.schemaVersion, 1);
    expect(decoded.documents, hasLength(1));
    expect(decoded.documents.single.filename, 'protocol.pdf');
    expect(decoded.documents.single.documentHash, 'hash-protocol');
    expect(decoded.documents.single.pdfBytes, [37, 80, 68, 70]);
    expect(
      decoded.documents.single.chunkPackage.chunks.single.text,
      'ABCDE protokoll',
    );
  });
}
