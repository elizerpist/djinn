import '../../shared/chunks/shared_chunk.dart';
import '../models/extracted_knowledge_item.dart';
import '../models/local_extraction.dart';

SharedChunkViewModel sharedChunkFromExtractedItem(
  ExtractedKnowledgeItem item, {
  required String filename,
  required bool isImage,
}) {
  return SharedChunkViewModel(
    id: item.id,
    origin: isImage ? SharedChunkOrigin.image : SharedChunkOrigin.pdf,
    mode: item.pipeline == LocalExtractionPipeline.ai
        ? SharedChunkMode.ai
        : SharedChunkMode.manual,
    kind: sharedKindFromLocalChunkKind(item.chunkKind),
    title: item.sectionTitle?.trim().isNotEmpty == true
        ? item.sectionTitle!.trim()
        : item.pageLabel,
    preview: item.text.trim(),
    content: item.text,
    pageLabel: item.pageLabel,
    sourceRectJson: item.sourceRectJson,
    auditState: item.auditState,
    tags: const [],
  );
}
