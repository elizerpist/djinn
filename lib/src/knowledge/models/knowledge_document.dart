enum KnowledgeDocumentStatus {
  imported,
  pendingIngest,
  uploading,
  processed,
  failed;

  String get wireName {
    return switch (this) {
      KnowledgeDocumentStatus.imported => 'imported',
      KnowledgeDocumentStatus.pendingIngest => 'pending_ingest',
      KnowledgeDocumentStatus.uploading => 'uploading',
      KnowledgeDocumentStatus.processed => 'processed',
      KnowledgeDocumentStatus.failed => 'failed',
    };
  }

  static KnowledgeDocumentStatus fromWireName(String? value) {
    return switch (value) {
      'imported' => KnowledgeDocumentStatus.imported,
      'uploading' => KnowledgeDocumentStatus.uploading,
      'processed' => KnowledgeDocumentStatus.processed,
      'failed' => KnowledgeDocumentStatus.failed,
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
      errorMessage: errorMessage ?? this.errorMessage,
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

  int get pendingCount => documents
      .where(
        (document) =>
            document.status == KnowledgeDocumentStatus.imported ||
            document.status == KnowledgeDocumentStatus.pendingIngest ||
            document.status == KnowledgeDocumentStatus.uploading,
      )
      .length;

  int get processedCount => documents
      .where((document) => document.status == KnowledgeDocumentStatus.processed)
      .length;

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
    if (documents.any(
      (document) => document.status == KnowledgeDocumentStatus.processed,
    )) {
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
