import 'package:objectbox/objectbox.dart';

enum ProcessingState {
  imported('imported'),
  blockedMissingApiKey('blocked_missing_api_key'),
  blockedPaidAi('blocked_paid_ai'),
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
    this.contentHash,
    this.ragEnabled = true,
    this.collectionName = 'Alap',
    this.ocrStatus = 'unknown',
    this.trainedAtMillis,
    this.packVersion,
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
  String? contentHash;

  bool ragEnabled;

  @Index()
  String collectionName;

  String ocrStatus;
  int? trainedAtMillis;
  int? packVersion;
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
class AppSettingsEntity {
  AppSettingsEntity({
    this.id = 0,
    required this.runtimeMode,
    required this.aiProvider,
    required this.answerModel,
    required this.extractionModel,
    required this.groundednessModel,
    required this.embeddingModel,
    required this.googleAnswerModel,
    required this.googleExtractionModel,
    required this.googleGroundednessModel,
    required this.googleEmbeddingModel,
    required this.deleteOpenAiFilesAfterProcessing,
    required this.groundednessCheckEnabled,
    required this.retrievalLimit,
    required this.minimumSimilarity,
    required this.allowPaidAi,
    required this.confirmBeforeAiProcessing,
    required this.voiceLocale,
    required this.ttsSpeechRate,
    required this.ttsPitch,
  });

  @Id()
  int id;

  String runtimeMode;
  String aiProvider;
  String answerModel;
  String extractionModel;
  String groundednessModel;
  String embeddingModel;
  String googleAnswerModel;
  String googleExtractionModel;
  String googleGroundednessModel;
  String googleEmbeddingModel;
  bool deleteOpenAiFilesAfterProcessing;
  bool groundednessCheckEnabled;
  int retrievalLimit;
  double minimumSimilarity;
  bool allowPaidAi;
  bool confirmBeforeAiProcessing;
  String voiceLocale;
  double ttsSpeechRate;
  double ttsPitch;
}
