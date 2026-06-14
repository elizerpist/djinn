import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/knowledge/data/local_chunk_builder.dart';
import 'package:djinn/src/knowledge/models/local_extraction.dart';

void main() {
  test('keeps bullet list together when it continues on the next page', () {
    final chunks = const LocalChunkBuilder().build(
      documentId: 'doc-copd',
      pages: const [
        LocalDocumentPage(
          documentId: 'doc-copd',
          pageNumber: 1,
          pdfText: 'A COPDAE kiváltó oka leggyakrabban:\n'
              '- infekció\n'
              '- szívelégtelenség',
          ocrText: '',
        ),
        LocalDocumentPage(
          documentId: 'doc-copd',
          pageNumber: 2,
          pdfText: '- pulmonalis embolia\n- pneumothorax',
          ocrText: '',
        ),
      ],
    );

    final listChunk = chunks.singleWhere(
      (chunk) => chunk.kind == LocalChunkKind.list,
    );

    expect(listChunk.pageNumber, 1);
    expect(listChunk.endPageNumber, 2);
    expect(listChunk.sectionTitle, 'A COPDAE kiváltó oka leggyakrabban');
    expect(listChunk.text, contains('infekció'));
    expect(listChunk.text, contains('szívelégtelenség'));
    expect(listChunk.text, contains('pulmonalis embolia'));
    expect(listChunk.text, contains('pneumothorax'));
    expect(listChunk.auditState, LocalAuditState.unreviewed);
    expect(listChunk.pipeline, LocalExtractionPipeline.localPdfText);
  });

  test('uses OCR text when the PDF text layer is empty', () {
    final chunks = const LocalChunkBuilder().build(
      documentId: 'doc-image-table',
      pages: const [
        LocalDocumentPage(
          documentId: 'doc-image-table',
          pageNumber: 1,
          pdfText: '',
          ocrText: 'RAVE score\nArc paresis | 1 pont\nBeszédzavar | 1 pont',
        ),
      ],
    );

    expect(chunks, isNotEmpty);
    expect(chunks.any((chunk) => chunk.kind == LocalChunkKind.table), isTrue);
    expect(chunks.map((chunk) => chunk.text).join('\n'), contains('RAVE score'));
  });
}
