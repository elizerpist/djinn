import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/knowledge/data/training_queue.dart';

void main() {
  test('training queue processes documents sequentially', () async {
    final processed = <String>[];
    final queue = TrainingQueue(
      processDocument: (documentId) async {
        processed.add(documentId);
      },
    );

    await queue.process(['doc-1', 'doc-2', 'doc-3']);

    expect(processed, ['doc-1', 'doc-2', 'doc-3']);
    expect(queue.running, isFalse);
  });

  test('training queue cancel stops before the next document', () async {
    final processed = <String>[];
    late TrainingQueue queue;
    queue = TrainingQueue(
      processDocument: (documentId) async {
        processed.add(documentId);
        queue.cancel();
      },
    );

    await queue.process(['doc-1', 'doc-2']);

    expect(processed, ['doc-1']);
    expect(queue.cancelRequested, isFalse);
  });
}
