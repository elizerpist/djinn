import 'package:objectbox/objectbox.dart';

enum ProcessingState {
  imported('imported'),
  blockedMissingApiKey('blocked_missing_api_key'),
  blockedOffline('blocked_offline'),
  uploading('uploading'),
  processing('processing'),
  embedded('embedded'),
  ready('ready'),
  needsReview('needs_review'),
  failed('failed');

  const ProcessingState(this.wireName);

  final String wireName;
}

enum ValidationState {
  unreviewed('unreviewed'),
  partiallyValidated('partially_validated'),
  validated('validated'),
  rejected('rejected');

  const ValidationState(this.wireName);

  final String wireName;
}

enum EvidenceSourceType {
  textChunk('text_chunk'),
  tableChunk('table_chunk'),
  scoreChunk('score_chunk'),
  flowchartNode('flowchart_node'),
  flowchartEdge('flowchart_edge');

  const EvidenceSourceType(this.wireName);

  final String wireName;
}

@Entity()
class ChatThreadEntity {
  ChatThreadEntity({
    this.id = 0,
    required this.publicId,
    required this.title,
    required this.createdAtMillis,
    required this.updatedAtMillis,
  });

  @Id()
  int id;

  @Unique()
  String publicId;

  String title;
  int createdAtMillis;
  int updatedAtMillis;
}

@Entity()
class ChatMessageEntity {
  ChatMessageEntity({
    this.id = 0,
    required this.publicId,
    required this.threadPublicId,
    required this.sender,
    required this.text,
    required this.createdAtMillis,
    this.status,
    this.refusalReason,
    this.hasValidationWarning = false,
    this.warningText,
  });

  @Id()
  int id;

  @Unique()
  String publicId;

  @Index()
  String threadPublicId;

  String sender;
  String text;
  int createdAtMillis;
  String? status;
  String? refusalReason;
  bool hasValidationWarning;
  String? warningText;
}

@Entity()
class KnowledgeFolderEntity {
  KnowledgeFolderEntity({
    this.id = 0,
    required this.publicId,
    required this.name,
    required this.createdAtMillis,
    required this.updatedAtMillis,
    this.sortOrder = 0,
  });

  @Id()
  int id;

  @Unique()
  String publicId;

  @Index()
  String name;

  int createdAtMillis;
  int updatedAtMillis;
  int sortOrder;
}

@Entity()
class KnowledgeDocumentEntity {
  KnowledgeDocumentEntity({
    this.id = 0,
    required this.publicId,
    required this.filename,
    required this.localPath,
    required this.sizeBytes,
    required this.importedAtMillis,
    required this.processingState,
    this.errorMessage,
    this.openAiFileId,
    this.folderPublicId,
    this.sha256,
    this.activeProvider,
    this.activeModel,
    this.lastErrorCode,
    this.retryable = false,
  });

  @Id()
  int id;

  @Unique()
  String publicId;

  String filename;
  String localPath;
  int sizeBytes;
  int importedAtMillis;

  @Index()
  String processingState;

  String? errorMessage;
  String? openAiFileId;

  @Index()
  String? folderPublicId;

  String? sha256;
  String? activeProvider;
  String? activeModel;
  String? lastErrorCode;
  bool retryable;
}

@Entity()
class DocumentChunkEntity {
  DocumentChunkEntity({
    this.id = 0,
    required this.publicId,
    required this.documentPublicId,
    required this.text,
    required this.pageNumber,
    this.sectionTitle,
    this.sourceRectJson,
    this.pipeline = 'ai',
    this.chunkKind = 'text',
    this.auditState = 'accepted',
    this.endPageNumber,
    this.confidence,
    this.sourcePageImagePath,
    this.tagsJson,
  });

  @Id()
  int id;

  @Unique()
  String publicId;

  @Index()
  String documentPublicId;

  String text;
  int pageNumber;
  String? sectionTitle;
  String? sourceRectJson;
  String pipeline;
  String chunkKind;
  String auditState;
  int? endPageNumber;
  double? confidence;
  String? sourcePageImagePath;
  String? tagsJson;
}

@Entity()
class DocumentPageEntity {
  DocumentPageEntity({
    this.id = 0,
    required this.publicId,
    required this.documentPublicId,
    required this.pageNumber,
    this.pdfText,
    this.ocrText,
    this.sourceImagePath,
    this.ocrBlocksJson,
    this.confidence,
  });

  @Id()
  int id;

  @Unique()
  String publicId;

  @Index()
  String documentPublicId;

  int pageNumber;
  String? pdfText;
  String? ocrText;
  String? sourceImagePath;
  String? ocrBlocksJson;
  double? confidence;
}

@Entity()
class ExtractionAuditItemEntity {
  ExtractionAuditItemEntity({
    this.id = 0,
    required this.publicId,
    required this.documentPublicId,
    required this.sourceId,
    required this.itemKind,
    required this.auditState,
    required this.createdAtMillis,
    this.pageNumber,
    this.title,
    this.previewText,
    this.reason,
    this.updatedAtMillis,
  });

  @Id()
  int id;

  @Unique()
  String publicId;

  @Index()
  String documentPublicId;

  @Index()
  String sourceId;

  String itemKind;

  @Index()
  String auditState;

  int createdAtMillis;
  int? updatedAtMillis;
  int? pageNumber;
  String? title;
  String? previewText;
  String? reason;
}

@Entity()
class KnowledgeNodeEntity {
  KnowledgeNodeEntity({
    this.id = 0,
    required this.publicId,
    required this.documentPublicId,
    required this.label,
    required this.nodeType,
    this.pageNumber,
    this.sourceId,
  });

  @Id()
  int id;

  @Unique()
  String publicId;

  @Index()
  String documentPublicId;

  String label;
  String nodeType;
  int? pageNumber;
  String? sourceId;
}

@Entity()
class KnowledgeEdgeEntity {
  KnowledgeEdgeEntity({
    this.id = 0,
    required this.publicId,
    required this.documentPublicId,
    required this.fromNodePublicId,
    required this.toNodePublicId,
    required this.relationType,
    this.sourceId,
    this.weight,
  });

  @Id()
  int id;

  @Unique()
  String publicId;

  @Index()
  String documentPublicId;

  @Index()
  String fromNodePublicId;

  @Index()
  String toNodePublicId;

  String relationType;
  String? sourceId;
  double? weight;
}

@Entity()
class KnowledgeEvidenceEntity {
  KnowledgeEvidenceEntity({
    this.id = 0,
    required this.publicId,
    required this.documentPublicId,
    required this.nodePublicId,
    required this.sourceId,
    required this.pipeline,
    this.pageNumber,
    this.quote,
  });

  @Id()
  int id;

  @Unique()
  String publicId;

  @Index()
  String documentPublicId;

  @Index()
  String nodePublicId;

  @Index()
  String sourceId;

  String pipeline;
  int? pageNumber;
  String? quote;
}

@Entity()
class VisualObjectEntity {
  VisualObjectEntity({
    this.id = 0,
    required this.publicId,
    required this.documentPublicId,
    required this.label,
    required this.objectType,
    this.pageNumber,
    this.sourceRectJson,
    this.confidence,
  });

  @Id()
  int id;

  @Unique()
  String publicId;

  @Index()
  String documentPublicId;

  String label;
  String objectType;
  int? pageNumber;
  String? sourceRectJson;
  double? confidence;
}

@Entity()
class VisualAttributeEntity {
  VisualAttributeEntity({
    this.id = 0,
    required this.publicId,
    required this.visualObjectPublicId,
    required this.name,
    required this.value,
    this.confidence,
  });

  @Id()
  int id;

  @Unique()
  String publicId;

  @Index()
  String visualObjectPublicId;

  String name;
  String value;
  double? confidence;
}

@Entity()
class ChunkEmbeddingEntity {
  ChunkEmbeddingEntity({
    this.id = 0,
    required this.sourceId,
    required this.sourceType,
    required this.vector,
    required this.model,
    required this.createdAtMillis,
  });

  @Id()
  int id;

  @Index()
  String sourceId;

  String sourceType;

  @HnswIndex(dimensions: 3072, distanceType: VectorDistanceType.cosine)
  @Property(type: PropertyType.floatVector)
  List<double>? vector;

  String model;
  int createdAtMillis;
}

@Entity()
class FlowchartEntity {
  FlowchartEntity({
    this.id = 0,
    required this.publicId,
    required this.documentPublicId,
    required this.pageNumber,
    required this.validationState,
    this.sourceRectJson,
    this.extractionConfidence,
  });

  @Id()
  int id;

  @Unique()
  String publicId;

  @Index()
  String documentPublicId;

  int pageNumber;

  @Index()
  String validationState;

  String? sourceRectJson;
  double? extractionConfidence;
}

@Entity()
class FlowchartNodeEntity {
  FlowchartNodeEntity({
    this.id = 0,
    required this.publicId,
    required this.flowchartPublicId,
    required this.label,
    required this.validationState,
    this.rejectionReason,
    this.positionX = 0,
    this.positionY = 0,
    this.shape = 'process',
    this.sortOrder = 0,
    this.sourceRectJson,
    this.colorSlot,
  });

  @Id()
  int id;

  @Unique()
  String publicId;

  @Index()
  String flowchartPublicId;

  String label;

  @Index()
  String validationState;

  String? rejectionReason;
  double positionX;
  double positionY;
  String shape;
  int sortOrder;
  String? sourceRectJson;
  int? colorSlot;
}

@Entity()
class FlowchartEdgeEntity {
  FlowchartEdgeEntity({
    this.id = 0,
    required this.publicId,
    required this.flowchartPublicId,
    required this.fromNodePublicId,
    required this.toNodePublicId,
    required this.label,
    required this.validationState,
    this.rejectionReason,
    this.sortOrder = 0,
    this.sourceRectJson,
  });

  @Id()
  int id;

  @Unique()
  String publicId;

  @Index()
  String flowchartPublicId;

  @Index()
  String fromNodePublicId;

  @Index()
  String toNodePublicId;

  String label;

  @Index()
  String validationState;

  String? rejectionReason;
  int sortOrder;
  String? sourceRectJson;
}

@Entity()
class CitationEntity {
  CitationEntity({
    this.id = 0,
    required this.publicId,
    required this.messagePublicId,
    required this.sourceId,
    required this.sourceType,
    required this.sourceLabel,
    this.documentPublicId,
    this.pageNumber,
    this.excerpt,
    this.atomType,
    this.reasonsJson,
    this.fullChunkText,
  });

  @Id()
  int id;

  @Unique()
  String publicId;

  @Index()
  String messagePublicId;

  @Index()
  String sourceId;

  String sourceType;
  String sourceLabel;
  String? documentPublicId;
  int? pageNumber;
  String? excerpt;
  String? atomType;
  String? reasonsJson;
  String? fullChunkText;
}

@Entity()
class ProcessingJobEntity {
  ProcessingJobEntity({
    this.id = 0,
    required this.publicId,
    required this.documentPublicId,
    required this.state,
    required this.createdAtMillis,
    required this.updatedAtMillis,
    this.errorMessage,
  });

  @Id()
  int id;

  @Unique()
  String publicId;

  @Index()
  String documentPublicId;

  @Index()
  String state;

  int createdAtMillis;
  int updatedAtMillis;
  String? errorMessage;
}

@Entity()
class CaseEntity {
  CaseEntity({
    this.id = 0,
    required this.publicId,
    required this.title,
    required this.notes,
    required this.createdAtMillis,
    required this.updatedAtMillis,
    this.archived = false,
  });

  @Id()
  int id;

  @Unique()
  String publicId;

  @Index()
  String title;

  String notes;
  int createdAtMillis;
  int updatedAtMillis;
  bool archived;
}

@Entity()
class CaseChatLinkEntity {
  CaseChatLinkEntity({
    this.id = 0,
    required this.publicId,
    required this.casePublicId,
    required this.chatThreadPublicId,
  });

  @Id()
  int id;

  @Unique()
  String publicId;

  @Index()
  String casePublicId;

  @Index()
  String chatThreadPublicId;
}

@Entity()
class CaseDocumentLinkEntity {
  CaseDocumentLinkEntity({
    this.id = 0,
    required this.publicId,
    required this.casePublicId,
    required this.documentPublicId,
  });

  @Id()
  int id;

  @Unique()
  String publicId;

  @Index()
  String casePublicId;

  @Index()
  String documentPublicId;
}

@Entity()
class NoteTagEntity {
  NoteTagEntity({
    this.id = 0,
    required this.publicId,
    required this.label,
    required this.normalizedLabel,
    required this.colorSlotId,
    this.folderPublicId,
    required this.type,
    required this.createdAtMillis,
    required this.updatedAtMillis,
  });

  @Id()
  int id;

  @Unique()
  String publicId;

  String label;

  @Index()
  String normalizedLabel;

  int colorSlotId;

  @Index()
  String? folderPublicId;

  String type;
  int createdAtMillis;
  int updatedAtMillis;
}

@Entity()
class NoteTagFolderEntity {
  NoteTagFolderEntity({
    this.id = 0,
    required this.publicId,
    required this.label,
    required this.normalizedLabel,
    required this.createdAtMillis,
    required this.updatedAtMillis,
  });

  @Id()
  int id;

  @Unique()
  String publicId;

  String label;

  @Index()
  String normalizedLabel;

  int createdAtMillis;
  int updatedAtMillis;
}

@Entity()
class AppSettingsEntity {
  AppSettingsEntity({
    this.id = 0,
    required this.runtimeMode,
    required this.activeProvider,
    required this.openAiAnswerModel,
    required this.openAiExtractionModel,
    required this.openAiGroundednessModel,
    required this.openAiEmbeddingModel,
    required this.geminiAnswerModel,
    required this.geminiExtractionModel,
    required this.geminiGroundednessModel,
    required this.geminiEmbeddingModel,
    required this.answerModel,
    required this.extractionModel,
    required this.groundednessModel,
    required this.embeddingModel,
    required this.deleteOpenAiFilesAfterProcessing,
    required this.groundednessCheckEnabled,
    required this.offlineFallbackEnabled,
    required this.retrievalLimit,
    required this.minimumSimilarity,
    required this.voiceMode,
    required this.voiceLocale,
    required this.chunkingMode,
    required this.localIndexingMode,
    required this.navigationMode,
  });

  @Id()
  int id;

  String runtimeMode;
  String activeProvider;
  String openAiAnswerModel;
  String openAiExtractionModel;
  String openAiGroundednessModel;
  String openAiEmbeddingModel;
  String geminiAnswerModel;
  String geminiExtractionModel;
  String geminiGroundednessModel;
  String geminiEmbeddingModel;
  String answerModel;
  String extractionModel;
  String groundednessModel;
  String embeddingModel;
  bool deleteOpenAiFilesAfterProcessing;
  bool groundednessCheckEnabled;
  bool offlineFallbackEnabled;
  int retrievalLimit;
  double minimumSimilarity;
  String voiceMode;
  String voiceLocale;
  String chunkingMode;
  String localIndexingMode;
  String navigationMode;
}
