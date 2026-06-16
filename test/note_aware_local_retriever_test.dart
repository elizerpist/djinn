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

  test('skips note keyword evidence on vector path unless explicitly selected', () async {
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
      isNot(contains('térfogattartó')),
    );
    expect(
      DebugConsole.allText,
      contains('[VectorGraph] note keyword expansion skipped reason=not_selected'),
    );

    DebugConsole.clear();
    final keywordResults = await retriever.retrieve(
      queryVector: const [0, 1, 2],
      limit: 8,
      minimumSimilarity: 0.7,
      query: 'folyadék jellemző',
      allowKeywordExpansion: true,
    );

    expect(
      keywordResults.map((item) => item.text).join('\n'),
      contains('térfogattartó'),
    );
    expect(DebugConsole.allText, contains('[LocalEmbedding] note chunk'));
  });

  test('links binary decision branches to explicit negated values without domain terms', () {
    final expander = LocalKnowledgeGraphExpander();
    const flowchart = SourceEvidence(
      id: 'flow:bags',
      sourceType: EvidenceSourceType.flowchartNode,
      text: '''
Táska színe zöld?
Táska színe zöld? -> Kiválasztás [Igen]
Táska színe zöld? -> Kiválasztás [Nem]
''',
      label: 'Flowchart · felszerelés',
      validationState: ValidationState.validated,
    );
    const table = SourceEvidence(
      id: 'table:bags',
      sourceType: EvidenceSourceType.tableChunk,
      text: '''
Felszerelés
Eszköz | Szín | Megjegyzés
Válltáska | színe zöld | oldalsó zsebben
Hátitáska | színe nem zöld | piros fedlap
''',
      label: 'Táblázat · táskák',
      validationState: ValidationState.validated,
    );

    final results = expander.expand(
      query: 'milyen a hátitáska színe?',
      seeds: const [flowchart],
      candidates: const [table],
      existing: const [flowchart],
      limit: 4,
    );

    expect(results, contains(table));
    expect(DebugConsole.allText, contains('[LocalGraph] branch signal'));
    expect(DebugConsole.allText, contains('type=branch_value'));
    expect(DebugConsole.allText, contains('polarity:negative'));
  });


  test('links binary decision branches to rules hidden in long text chunks', () {
    final expander = LocalKnowledgeGraphExpander();
    const flowchart = SourceEvidence(
      id: 'flow:state',
      sourceType: EvidenceSourceType.flowchartNode,
      text: '''
Aktív?
Aktív? -> Feldolgozás [Igen]
Aktív? -> Archiválás [Nem]
''',
      label: 'Flowchart · állapot',
      validationState: ValidationState.validated,
    );
    const ruleText = SourceEvidence(
      id: 'text:state-rule',
      sourceType: EvidenceSourceType.textChunk,
      text: 'Egy hosszú működési definíció szerint ha nem aktív, akkor archiválás következik; ha aktív, akkor azonnali feldolgozás indul.',
      label: 'Szöveg · állapotszabály',
      validationState: ValidationState.validated,
    );

    final results = expander.expand(
      query: 'mi történik ha nem aktív?',
      seeds: const [flowchart],
      candidates: const [ruleText],
      existing: const [flowchart],
      limit: 4,
    );

    expect(results, contains(ruleText));
    expect(DebugConsole.allText, contains('type=branch_value'));
    expect(DebugConsole.allText, contains('polarity:negative'));
  });

  test('links multi-branch range decisions to matching table or text rules', () {
    final expander = LocalKnowledgeGraphExpander();
    const flowchart = SourceEvidence(
      id: 'flow:spo2',
      sourceType: EvidenceSourceType.flowchartNode,
      text: '''
SpO2?
SpO2? -> Oxigén [95-100]
SpO2? -> Megfigyelés [90-95]
SpO2? -> Oxigén [80-90]
SpO2? -> Oxigén [80 alatt]
''',
      label: 'Flowchart · szaturáció',
      validationState: ValidationState.validated,
    );
    const table = SourceEvidence(
      id: 'table:spo2',
      sourceType: EvidenceSourceType.tableChunk,
      text: '''
SpO2 áramlási értékek
Tartomány | Teendő | Áramlás
95-100 | kontroll | szobalevegő
90-95 | megfigyelés | alacsony áramlás
80-90 | oxigén | közepes áramlás
80 alatt | oxigén | magas áramlás
''',
      label: 'Táblázat · SpO2',
      validationState: ValidationState.validated,
    );

    final results = expander.expand(
      query: 'spo2 90-95 áramlás',
      seeds: const [flowchart],
      candidates: const [table],
      existing: const [flowchart],
      limit: 4,
    );

    expect(results, contains(table));
    expect(DebugConsole.allText, contains('type=branch_value'));
    expect(DebugConsole.allText, contains('key=spo2'));
    expect(DebugConsole.allText, contains('value=90 95'));
  });

}
