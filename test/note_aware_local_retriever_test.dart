import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/debug/debug_console.dart';
import 'package:djinn/src/local_store/entities.dart';
import 'package:djinn/src/notes/data/note_repository.dart';
import 'package:djinn/src/notes/models/note_document.dart';
import 'package:djinn/src/rag/models/source_evidence.dart';
import 'package:djinn/src/rag/retrieval/local_retriever.dart';
import 'package:djinn/src/rag/retrieval/note_aware_local_retriever.dart';

void main() {
  setUp(DebugConsole.clear);

  test('retrieves note chunks and graph-linked definitions offline', () async {
    final notes = MemoryNoteRepository();
    await notes.createDocumentNote(
      title: 'Mechanika jegyzet',
      document: const NoteDocument(
        blocks: [
          NoteBlock(
            id: 'law',
            type: NoteBlockType.paragraph,
            text: 'A dinamika alapegyenlete szerint az erő F = m * a.',
          ),
          NoteBlock(
            id: 'terms',
            type: NoteBlockType.listItem,
            title: 'Jelölések',
            listItems: [
              NoteListItem(id: 'force', text: 'erő: testek kölcsönhatásának mértéke'),
              NoteListItem(id: 'mass', text: 'tömeg: tehetetlenség mértéke'),
              NoteListItem(id: 'accel', text: 'gyorsulás: sebességváltozás időegység alatt'),
            ],
          ),
        ],
      ),
    );

    final retriever = NoteAwareLocalRetriever(
      base: MemoryLocalRetriever(const []),
      noteRepository: notes,
    );

    final results = await retriever.retrieveOffline(
      query: 'hogyan működik a dinamika alapegyenlete?',
      limit: 8,
    );

    expect(results.any((item) => item.id.endsWith(':law')), isTrue);
    expect(results.any((item) => item.id.endsWith(':terms')), isTrue);
    expect(
      results.map((item) => item.text).join('\n'),
      contains('gyorsulás: sebességváltozás'),
    );
    expect(DebugConsole.allText, contains('[LocalIndex] note chunk'));
    expect(DebugConsole.allText, contains('[LocalGraph] link type=definition'));
  });

  test('adds note keyword evidence to vector retrieval path', () async {
    final notes = MemoryNoteRepository();
    await notes.createDocumentNote(
      title: 'Anyagismeret jegyzet',
      document: const NoteDocument(
        blocks: [
          NoteBlock(
            id: 'table',
            type: NoteBlockType.table,
            title: 'Halmazállapotok',
            rows: [
              ['Állapot', 'Jellemző'],
              ['Szilárd', 'alaktartó'],
              ['Folyadék', 'térfogattartó'],
            ],
          ),
        ],
      ),
    );

    final retriever = NoteAwareLocalRetriever(
      base: MemoryLocalRetriever(const [
        SourceEvidence(
          id: 'pdf-1',
          sourceType: EvidenceSourceType.textChunk,
          text: 'PDF találat',
          label: 'PDF',
          validationState: ValidationState.validated,
          score: 0.91,
        ),
      ]),
      noteRepository: notes,
    );

    final results = await retriever.retrieve(
      queryVector: const [0, 1, 2],
      limit: 8,
      minimumSimilarity: 0.7,
      query: 'folyadék jellemző',
    );

    expect(results.map((item) => item.id), contains('pdf-1'));
    expect(
      results.map((item) => item.text).join('\n'),
      contains('térfogattartó'),
    );
    expect(DebugConsole.allText, contains('[LocalEmbedding] note chunk'));
  });
}
