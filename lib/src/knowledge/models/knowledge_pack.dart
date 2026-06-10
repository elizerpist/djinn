import 'chunk_package.dart';

class KnowledgePack {
  const KnowledgePack({required this.schemaVersion, required this.documents});

  final int schemaVersion;
  final List<KnowledgePackDocument> documents;
}

class KnowledgePackDocument {
  const KnowledgePackDocument({
    required this.filename,
    required this.documentHash,
    required this.pdfBytes,
    required this.chunkPackage,
  });

  final String filename;
  final String documentHash;
  final List<int> pdfBytes;
  final ChunkPackage chunkPackage;
}
