typedef ProcessKnowledgeDocument = Future<void> Function(String documentId);

class TrainingQueue {
  TrainingQueue({required ProcessKnowledgeDocument processDocument})
    : _processDocument = processDocument;

  final ProcessKnowledgeDocument _processDocument;

  bool running = false;
  bool cancelRequested = false;

  Future<void> process(List<String> documentIds) async {
    if (running) {
      return;
    }
    running = true;
    cancelRequested = false;
    try {
      for (final documentId in documentIds) {
        if (cancelRequested) {
          break;
        }
        await _processDocument(documentId);
      }
    } finally {
      running = false;
      cancelRequested = false;
    }
  }

  void cancel() {
    if (running) {
      cancelRequested = true;
    }
  }
}
