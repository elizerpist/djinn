import 'dart:convert';

abstract class TrainingPackRepository {
  Future<List<TrainingPackDocument>> listDocumentPacks();
  Future<void> upsertDocumentPack(TrainingPackDocument document);
}

class TrainingPackService {
  const TrainingPackService({
    required TrainingPackRepository repository,
    DateTime Function()? clock,
  }) : _repository = repository,
       _clock = clock;

  final TrainingPackRepository _repository;
  final DateTime Function()? _clock;

  Future<String> exportPack() async {
    final documents = await _repository.listDocumentPacks();
    return const JsonEncoder.withIndent('  ').convert({
      'schema_version': 1,
      'app': 'djinn',
      'exported_at': (_clock ?? DateTime.now)().toUtc().toIso8601String(),
      'documents': documents.map((document) => document.toJson()).toList(),
    });
  }

  Future<void> importPack(String jsonText) async {
    final decoded = jsonDecode(jsonText);
    if (decoded is! Map<String, Object?> || decoded['schema_version'] != 1) {
      throw const FormatException('unsupported djinnpack schema');
    }
    final documents = decoded['documents'];
    if (documents is! List) {
      throw const FormatException('invalid djinnpack documents');
    }
    for (final item in documents) {
      if (item is! Map) {
        throw const FormatException('invalid djinnpack document');
      }
      await _repository.upsertDocumentPack(
        TrainingPackDocument.fromJson(item.cast<String, Object?>()),
      );
    }
  }
}

class TrainingPackDocument {
  const TrainingPackDocument({
    required this.id,
    required this.filename,
    required this.localPath,
    required this.sizeBytes,
    required this.importedAtMillis,
    required this.processingState,
    required this.contentHash,
    required this.ragEnabled,
    required this.collectionName,
    required this.ocrStatus,
    required this.chunks,
    required this.embeddings,
    required this.flowcharts,
    this.trainedAtMillis,
    this.packVersion,
  });

  final String id;
  final String filename;
  final String localPath;
  final int sizeBytes;
  final int importedAtMillis;
  final String processingState;
  final String contentHash;
  final bool ragEnabled;
  final String collectionName;
  final String ocrStatus;
  final int? trainedAtMillis;
  final int? packVersion;
  final List<TrainingPackChunk> chunks;
  final List<TrainingPackEmbedding> embeddings;
  final List<TrainingPackFlowchart> flowcharts;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'filename': filename,
      'local_path': localPath,
      'size_bytes': sizeBytes,
      'imported_at_millis': importedAtMillis,
      'processing_state': processingState,
      'content_hash': contentHash,
      'rag_enabled': ragEnabled,
      'collection_name': collectionName,
      'ocr_status': ocrStatus,
      'trained_at_millis': trainedAtMillis,
      'pack_version': packVersion,
      'chunks': chunks.map((item) => item.toJson()).toList(),
      'embeddings': embeddings.map((item) => item.toJson()).toList(),
      'flowcharts': flowcharts.map((item) => item.toJson()).toList(),
    };
  }

  factory TrainingPackDocument.fromJson(Map<String, Object?> json) {
    return TrainingPackDocument(
      id: json['id'] as String? ?? '',
      filename: json['filename'] as String? ?? '',
      localPath: json['local_path'] as String? ?? '',
      sizeBytes: json['size_bytes'] as int? ?? 0,
      importedAtMillis: json['imported_at_millis'] as int? ?? 0,
      processingState: json['processing_state'] as String? ?? 'ready',
      contentHash: json['content_hash'] as String? ?? '',
      ragEnabled: json['rag_enabled'] as bool? ?? true,
      collectionName: json['collection_name'] as String? ?? 'Alap',
      ocrStatus: json['ocr_status'] as String? ?? 'unknown',
      trainedAtMillis: json['trained_at_millis'] as int?,
      packVersion: json['pack_version'] as int?,
      chunks: _list(
        json['chunks'],
      ).map((item) => TrainingPackChunk.fromJson(item)).toList(growable: false),
      embeddings: _list(json['embeddings'])
          .map((item) => TrainingPackEmbedding.fromJson(item))
          .toList(growable: false),
      flowcharts: _list(json['flowcharts'])
          .map((item) => TrainingPackFlowchart.fromJson(item))
          .toList(growable: false),
    );
  }
}

class TrainingPackChunk {
  const TrainingPackChunk({
    required this.id,
    required this.text,
    required this.pageNumber,
    this.sectionTitle,
  });

  final String id;
  final String text;
  final int pageNumber;
  final String? sectionTitle;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'text': text,
      'page_number': pageNumber,
      'section_title': sectionTitle,
    };
  }

  factory TrainingPackChunk.fromJson(Map<String, Object?> json) {
    return TrainingPackChunk(
      id: json['id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      pageNumber: json['page_number'] as int? ?? 0,
      sectionTitle: json['section_title'] as String?,
    );
  }
}

class TrainingPackEmbedding {
  TrainingPackEmbedding({
    required this.sourceId,
    required this.sourceType,
    required this.vector,
    required this.model,
    required this.createdAtMillis,
  });

  final String sourceId;
  final String sourceType;
  final List<double> vector;
  final String model;
  final int createdAtMillis;

  Map<String, Object?> toJson() {
    return {
      'source_id': sourceId,
      'source_type': sourceType,
      'vector': vector,
      'model': model,
      'created_at_millis': createdAtMillis,
    };
  }

  factory TrainingPackEmbedding.fromJson(Map<String, Object?> json) {
    final vector = json['vector'];
    return TrainingPackEmbedding(
      sourceId: json['source_id'] as String? ?? '',
      sourceType: json['source_type'] as String? ?? '',
      vector: vector is List
          ? vector.map((value) => (value as num).toDouble()).toList()
          : const [],
      model: json['model'] as String? ?? '',
      createdAtMillis: json['created_at_millis'] as int? ?? 0,
    );
  }
}

class TrainingPackFlowchart {
  const TrainingPackFlowchart({
    required this.id,
    required this.pageNumber,
    required this.validationState,
    required this.nodes,
    required this.edges,
    this.extractionConfidence,
  });

  final String id;
  final int pageNumber;
  final String validationState;
  final double? extractionConfidence;
  final List<TrainingPackFlowchartNode> nodes;
  final List<TrainingPackFlowchartEdge> edges;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'page_number': pageNumber,
      'validation_state': validationState,
      'extraction_confidence': extractionConfidence,
      'nodes': nodes.map((item) => item.toJson()).toList(),
      'edges': edges.map((item) => item.toJson()).toList(),
    };
  }

  factory TrainingPackFlowchart.fromJson(Map<String, Object?> json) {
    return TrainingPackFlowchart(
      id: json['id'] as String? ?? '',
      pageNumber: json['page_number'] as int? ?? 0,
      validationState: json['validation_state'] as String? ?? 'unreviewed',
      extractionConfidence: (json['extraction_confidence'] as num?)?.toDouble(),
      nodes: _list(json['nodes'])
          .map((item) => TrainingPackFlowchartNode.fromJson(item))
          .toList(growable: false),
      edges: _list(json['edges'])
          .map((item) => TrainingPackFlowchartEdge.fromJson(item))
          .toList(growable: false),
    );
  }
}

class TrainingPackFlowchartNode {
  const TrainingPackFlowchartNode({
    required this.id,
    required this.label,
    required this.validationState,
    this.rejectionReason,
    this.positionX = 0,
    this.positionY = 0,
  });

  final String id;
  final String label;
  final String validationState;
  final String? rejectionReason;
  final double positionX;
  final double positionY;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'label': label,
      'validation_state': validationState,
      'rejection_reason': rejectionReason,
      'position_x': positionX,
      'position_y': positionY,
    };
  }

  factory TrainingPackFlowchartNode.fromJson(Map<String, Object?> json) {
    return TrainingPackFlowchartNode(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      validationState: json['validation_state'] as String? ?? 'unreviewed',
      rejectionReason: json['rejection_reason'] as String?,
      positionX: (json['position_x'] as num?)?.toDouble() ?? 0,
      positionY: (json['position_y'] as num?)?.toDouble() ?? 0,
    );
  }
}

class TrainingPackFlowchartEdge {
  const TrainingPackFlowchartEdge({
    required this.id,
    required this.fromNodeId,
    required this.toNodeId,
    required this.label,
    required this.validationState,
    this.rejectionReason,
  });

  final String id;
  final String fromNodeId;
  final String toNodeId;
  final String label;
  final String validationState;
  final String? rejectionReason;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'from_node_id': fromNodeId,
      'to_node_id': toNodeId,
      'label': label,
      'validation_state': validationState,
      'rejection_reason': rejectionReason,
    };
  }

  factory TrainingPackFlowchartEdge.fromJson(Map<String, Object?> json) {
    return TrainingPackFlowchartEdge(
      id: json['id'] as String? ?? '',
      fromNodeId: json['from_node_id'] as String? ?? '',
      toNodeId: json['to_node_id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      validationState: json['validation_state'] as String? ?? 'unreviewed',
      rejectionReason: json['rejection_reason'] as String?,
    );
  }
}

List<Map<String, Object?>> _list(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value
      .whereType<Map>()
      .map((item) => item.cast<String, Object?>())
      .toList(growable: false);
}
