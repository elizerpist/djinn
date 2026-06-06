enum KnowledgeDocumentStatus {
  imported('imported'),
  pendingIngest('pending_ingest'),
  blockedMissingApiKey('blocked_missing_api_key'),
  blockedOffline('blocked_offline'),
  uploading('uploading'),
  processing('processing'),
  embedded('embedded'),
  ready('ready'),
  needsReview('needs_review'),
  processed('processed'),
  failed('failed');

  const KnowledgeDocumentStatus(this.wireName);

  final String wireName;

  static KnowledgeDocumentStatus fromWireName(String? value) {
    for (final status in KnowledgeDocumentStatus.values) {
      if (status.wireName == value) {
        return status;
      }
    }
    return switch (value) {
      'processing' => KnowledgeDocumentStatus.processing,
      _ => KnowledgeDocumentStatus.pendingIngest,
    };
  }
}

enum KnowledgeBaseReadiness { empty, pendingIngest, ready, failed }

class KnowledgeDocument {
  const KnowledgeDocument({
    required this.id,
    required this.filename,
    required this.localPath,
    required this.sizeBytes,
    required this.importedAt,
    required this.status,
    this.backendDocumentId,
    this.errorMessage,
  });

  final String id;
  final String filename;
  final String localPath;
  final int sizeBytes;
  final DateTime importedAt;
  final KnowledgeDocumentStatus status;
  final String? backendDocumentId;
  final String? errorMessage;

  KnowledgeDocument copyWith({
    String? id,
    String? filename,
    String? localPath,
    int? sizeBytes,
    DateTime? importedAt,
    KnowledgeDocumentStatus? status,
    String? backendDocumentId,
    String? errorMessage,
  }) {
    return KnowledgeDocument(
      id: id ?? this.id,
      filename: filename ?? this.filename,
      localPath: localPath ?? this.localPath,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      importedAt: importedAt ?? this.importedAt,
      status: status ?? this.status,
      backendDocumentId: backendDocumentId ?? this.backendDocumentId,
      errorMessage: errorMessage,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'filename': filename,
      'localPath': localPath,
      'sizeBytes': sizeBytes,
      'importedAt': importedAt.toIso8601String(),
      'status': status.wireName,
      'backendDocumentId': backendDocumentId,
      'errorMessage': errorMessage,
    };
  }

  factory KnowledgeDocument.fromJson(Map<String, Object?> json) {
    return KnowledgeDocument(
      id: json['id'] as String? ?? '',
      filename: json['filename'] as String? ?? '',
      localPath: json['localPath'] as String? ?? '',
      sizeBytes: json['sizeBytes'] as int? ?? 0,
      importedAt:
          DateTime.tryParse(json['importedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      status: KnowledgeDocumentStatus.fromWireName(json['status'] as String?),
      backendDocumentId: json['backendDocumentId'] as String?,
      errorMessage: json['errorMessage'] as String?,
    );
  }
}

class KnowledgeBaseState {
  const KnowledgeBaseState({required this.documents, required this.readiness});

  final List<KnowledgeDocument> documents;
  final KnowledgeBaseReadiness readiness;

  int get pendingCount =>
      documents.where((document) => document.status.isPending).length;

  int get processedCount =>
      documents.where((document) => document.status.isReady).length;

  static KnowledgeBaseState fromDocuments(List<KnowledgeDocument> documents) {
    final immutableDocuments = List<KnowledgeDocument>.unmodifiable(documents);
    final readiness = _deriveReadiness(immutableDocuments);
    return KnowledgeBaseState(
      documents: immutableDocuments,
      readiness: readiness,
    );
  }

  static KnowledgeBaseReadiness _deriveReadiness(
    List<KnowledgeDocument> documents,
  ) {
    if (documents.isEmpty) {
      return KnowledgeBaseReadiness.empty;
    }
    if (documents.any((document) => document.status.isReady)) {
      return KnowledgeBaseReadiness.ready;
    }
    if (documents.every(
      (document) => document.status == KnowledgeDocumentStatus.failed,
    )) {
      return KnowledgeBaseReadiness.failed;
    }
    return KnowledgeBaseReadiness.pendingIngest;
  }
}

extension KnowledgeDocumentStatusFlags on KnowledgeDocumentStatus {
  bool get isReady {
    return this == KnowledgeDocumentStatus.ready ||
        this == KnowledgeDocumentStatus.processed;
  }

  bool get isPending {
    return switch (this) {
      KnowledgeDocumentStatus.imported ||
      KnowledgeDocumentStatus.pendingIngest ||
      KnowledgeDocumentStatus.blockedMissingApiKey ||
      KnowledgeDocumentStatus.blockedOffline ||
      KnowledgeDocumentStatus.uploading ||
      KnowledgeDocumentStatus.processing ||
      KnowledgeDocumentStatus.embedded ||
      KnowledgeDocumentStatus.needsReview => true,
      KnowledgeDocumentStatus.ready ||
      KnowledgeDocumentStatus.processed ||
      KnowledgeDocumentStatus.failed => false,
    };
  }

  bool get canRetry {
    return this == KnowledgeDocumentStatus.failed ||
        this == KnowledgeDocumentStatus.blockedMissingApiKey ||
        this == KnowledgeDocumentStatus.blockedOffline;
  }
}
