import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/debug/debug_console.dart';
import 'package:djinn/src/local_store/entities.dart';
import 'package:djinn/src/notes/data/note_repository.dart';
import 'package:djinn/src/notes/models/note_document.dart';
import 'package:djinn/src/rag/models/source_evidence.dart';
import 'package:djinn/src/rag/retrieval/local_retriever.dart';
import 'package:djinn/src/rag/retrieval/note_aware_local_retriever.dart';
import 'package:djinn/src/settings/models/app_settings.dart';

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
              NoteListItem(
                id: 'force',
                text: 'erő: testek kölcsönhatásának mértéke',
              ),
              NoteListItem(id: 'mass', text: 'tömeg: tehetetlenség mértéke'),
              NoteListItem(
                id: 'accel',
                text: 'gyorsulás: sebességváltozás időegység alatt',
              ),
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

  test(
    'retrieves note vector evidence on vector path without keyword fallback',
    () async {
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
        contains('Állapot: Folyadék | Jellemző: térfogattartó'),
      );
      expect(
        DebugConsole.allText,
        contains('[VectorGraph] note local vector expansion mode=note_vector'),
      );
      expect(DebugConsole.allText, isNot(contains('[Offline] search start')));

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
    },
  );

  test(
    'links binary decision branches to explicit negated values without domain terms',
    () {
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
    },
  );

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
      text:
          'Egy hosszú működési definíció szerint ha nem aktív, akkor archiválás következik; ha aktív, akkor azonnali feldolgozás indul.',
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

  test(
    'links multi-branch range decisions to matching table or text rules',
    () {
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
    },
  );

  test(
    'links flowchart branch process to only the relevant table row unit',
    () async {
      final notes = MemoryNoteRepository();
      await notes.createDocumentNote(
        title: 'Légzési elégtelenség',
        document: const NoteDocument(
          blocks: [
            NoteBlock(
              id: 'flow',
              type: NoteBlockType.flowchart,
              nodes: [
                NoteFlowchartNode(
                  id: 'severity',
                  label: 'Súlyos légzési elégtelenség?',
                  kind: NoteFlowchartNodeKind.binaryDecision,
                  ports: [
                    NoteFlowchartPort(
                      id: 'yes',
                      side: NoteFlowchartPortSide.bottom,
                      label: 'Igen',
                      semantic: NoteFlowchartPortSemantic.yes,
                    ),
                    NoteFlowchartPort(
                      id: 'no',
                      side: NoteFlowchartPortSide.bottom,
                      label: 'Nem',
                      semantic: NoteFlowchartPortSemantic.no,
                    ),
                  ],
                ),
                NoteFlowchartNode(id: 'oxygen', label: 'Oxigén'),
              ],
              edges: [
                NoteFlowchartEdge(
                  id: 'yes-edge',
                  fromNodeId: 'severity',
                  fromPortId: 'yes',
                  toNodeId: 'oxygen',
                  label: 'Igen',
                ),
                NoteFlowchartEdge(
                  id: 'no-edge',
                  fromNodeId: 'severity',
                  fromPortId: 'no',
                  toNodeId: 'oxygen',
                  label: 'Nem',
                ),
              ],
            ),
            NoteBlock(
              id: 'oxygen-table',
              type: NoteBlockType.table,
              rows: [
                ['Állapot', 'Teendő'],
                ['Súlyos légzési elégtelenség', 'magas áramlású oxigén'],
                ['Enyhe légzési elégtelenség', 'célzott oxigénterápia'],
              ],
            ),
          ],
        ),
      );

      final retriever = NoteAwareLocalRetriever(
        base: MemoryLocalRetriever(const []),
        noteRepository: notes,
      );

      final results = await retriever.retrieveLocalVector(
        query: 'súlyos légzési elégtelenség esetén oxigén',
        limit: 8,
        mode: 'embedding_gemma',
      );
      final joined = results.map((item) => item.text).join('\n');

      expect(
        joined,
        contains(
          'Állapot: Súlyos légzési elégtelenség | Teendő: magas áramlású oxigén',
        ),
      );
      expect(
        joined,
        isNot(
          contains(
            'Állapot: Enyhe légzési elégtelenség | Teendő: célzott oxigénterápia',
          ),
        ),
      );
      expect(DebugConsole.allText, contains('type=branch_value'));
    },
  );

  test(
    'local vector note retrieval returns relevant long text rule units only',
    () async {
      final notes = MemoryNoteRepository();
      await notes.createDocumentNote(
        title: 'Állapot szabályok',
        document: const NoteDocument(
          blocks: [
            NoteBlock(
              id: 'flow',
              type: NoteBlockType.flowchart,
              nodes: [
                NoteFlowchartNode(
                  id: 'state',
                  label: 'Aktív?',
                  kind: NoteFlowchartNodeKind.binaryDecision,
                  ports: [
                    NoteFlowchartPort(
                      id: 'yes',
                      side: NoteFlowchartPortSide.bottom,
                      label: 'Igen',
                      semantic: NoteFlowchartPortSemantic.yes,
                    ),
                    NoteFlowchartPort(
                      id: 'no',
                      side: NoteFlowchartPortSide.bottom,
                      label: 'Nem',
                      semantic: NoteFlowchartPortSemantic.no,
                    ),
                  ],
                ),
                NoteFlowchartNode(id: 'archive', label: 'Archiválás'),
              ],
              edges: [
                NoteFlowchartEdge(
                  id: 'no-edge',
                  fromNodeId: 'state',
                  fromPortId: 'no',
                  toNodeId: 'archive',
                  label: 'Nem',
                ),
              ],
            ),
            NoteBlock(
              id: 'long-rule',
              type: NoteBlockType.paragraph,
              text:
                  'Egy hosszú definíció szerint ha nem aktív, akkor archiválás következik; ha aktív, akkor azonnali feldolgozás indul.',
            ),
          ],
        ),
      );

      final retriever = NoteAwareLocalRetriever(
        base: MemoryLocalRetriever(const []),
        noteRepository: notes,
      );

      final results = await retriever.retrieveLocalVector(
        query: 'mi történik ha nem aktív?',
        limit: 8,
        mode: 'mediapipe_text_embedder',
      );
      final joined = results.map((item) => item.text).join('\n');

      expect(joined, contains('ha nem aktív, akkor archiválás következik'));
      expect(
        joined,
        isNot(contains('ha aktív, akkor azonnali feldolgozás indul')),
      );
      expect(DebugConsole.allText, contains('type=branch_value'));
    },
  );

  test(
    'local vector note retrieval connects shared symbols without keyword fallback',
    () async {
      final notes = MemoryNoteRepository();
      await notes.createDocumentNote(
        title: 'Definíciók',
        document: const NoteDocument(
          blocks: [
            NoteBlock(
              id: 'definition',
              type: NoteBlockType.paragraph,
              text: 'Légzési elégtelenség, amikor DO2 < VO2.',
            ),
            NoteBlock(
              id: 'symbols',
              type: NoteBlockType.listItem,
              listItems: [
                NoteListItem(id: 'do2', text: 'DO2 = oxigénkínálat'),
                NoteListItem(id: 'vo2', text: 'VO2 = oxigénigény'),
              ],
            ),
          ],
        ),
      );

      final retriever = NoteAwareLocalRetriever(
        base: MemoryLocalRetriever(const []),
        noteRepository: notes,
      );

      final results = await retriever.retrieveLocalVector(
        query: 'mi a légzési elégtelenség?',
        limit: 8,
        mode: 'onnx_multilingual_e5',
      );
      final joined = results.map((item) => item.text).join('\n');

      expect(joined, contains('DO2 < VO2'));
      expect(joined, contains('DO2 = oxigénkínálat'));
      expect(joined, contains('VO2 = oxigénigény'));
      expect(DebugConsole.allText, isNot(contains('[Offline] search start')));
      expect(DebugConsole.allText, contains('[LocalVector] note search'));
    },
  );

  test('hybrid note retrieval combines vector keyword symbol and metadata signals', () async {
    final notes = MemoryNoteRepository();
    await notes.createDocumentNote(
      title: 'Oxigén jegyzet',
      document: const NoteDocument(
        blocks: [
          NoteBlock(
            id: 'definition',
            type: NoteBlockType.paragraph,
            searchContext: 'légzési elégtelenség',
            searchRole: NoteSearchRoles.definition,
            searchAliases: ['DO2', 'VO2'],
            text: 'Légzési elégtelenség akkor áll fenn, amikor DO2 < VO2.',
          ),
          NoteBlock(
            id: 'symbols',
            type: NoteBlockType.listItem,
            title: 'Magyarázat',
            searchContext: 'légzési elégtelenség',
            searchRole: NoteSearchRoles.definition,
            listItems: [
              NoteListItem(id: 'do2', text: 'DO2 = oxygénkínálat'),
              NoteListItem(id: 'vo2', text: 'VO2 = oxygénigény'),
            ],
          ),
        ],
      ),
    );

    final retriever = NoteAwareLocalRetriever(
      base: MemoryLocalRetriever(const []),
      noteRepository: notes,
    );

    final results = await retriever.retrieveHybrid(
      query: 'mit jelent a légzési elégtelenség?',
      limit: 8,
      vectorMode: LocalIndexingModes.mediapipeTextEmbedder,
    );
    final joined = results.map((item) => item.text).join('\n');

    expect(joined, contains('DO2 < VO2'));
    expect(joined, contains('DO2 = oxygénkínálat'));
    expect(joined, contains('VO2 = oxygénigény'));
    expect(DebugConsole.allText, contains('[HybridSearch] note search'));
    expect(DebugConsole.allText, contains('symbol='));
    expect(DebugConsole.allText, contains('keyword='));
    expect(DebugConsole.allText, contains('vector='));
  });

  test(
    'local vector graph keeps linked symbol definitions ahead of noisy flowchart edges',
    () async {
      final notes = MemoryNoteRepository();
      await notes.createDocumentNote(
        title: 'Légzési elégtelenség',
        document: const NoteDocument(
          blocks: [
            NoteBlock(
              id: 'definition',
              type: NoteBlockType.paragraph,
              text:
                  'Bolognai spaghetti készítésekor a ragu akkor lesz kiegyensúlyozott, ha a paradicsomos alap és a hús aránya megfelelő. Rejtett jegyzet: légzési elégtelenség akkor áll fenn, amikor DO2 < VO2. A receptben ez olyan, mintha kevesebb szósz jutna a tésztára, mint amennyit az étel igényel.',
            ),
            NoteBlock(
              id: 'symbols',
              type: NoteBlockType.listItem,
              title: 'Magyarázat',
              listItems: [
                NoteListItem(
                  id: 'recipe',
                  text:
                      'Bolognai spaghettihez először hagymát és fokhagymát pirítunk',
                ),
                NoteListItem(id: 'do2', text: 'DO2= oxygénkínálat'),
                NoteListItem(id: 'vo2', text: 'VO2= oxygénigény'),
                NoteListItem(
                  id: 'finish',
                  text:
                      'Ezután darált húst, paradicsomot, sót, borsot és oregánót adunk hozzá.',
                ),
              ],
            ),
            NoteBlock(
              id: 'flow',
              type: NoteBlockType.flowchart,
              nodes: [
                NoteFlowchartNode(id: 'start', label: 'Kezdés'),
                NoteFlowchartNode(
                  id: 'resp',
                  label: 'Légzési elégtelen?',
                  kind: NoteFlowchartNodeKind.binaryDecision,
                  ports: [
                    NoteFlowchartPort(
                      id: 'yes',
                      side: NoteFlowchartPortSide.bottom,
                      label: 'Igen',
                      semantic: NoteFlowchartPortSemantic.yes,
                    ),
                    NoteFlowchartPort(
                      id: 'no',
                      side: NoteFlowchartPortSide.bottom,
                      label: 'Nem',
                      semantic: NoteFlowchartPortSemantic.no,
                    ),
                  ],
                ),
                NoteFlowchartNode(
                  id: 'severe',
                  label: 'Súlyos?',
                  kind: NoteFlowchartNodeKind.binaryDecision,
                  ports: [
                    NoteFlowchartPort(
                      id: 'yes',
                      side: NoteFlowchartPortSide.bottom,
                      label: 'Igen',
                      semantic: NoteFlowchartPortSemantic.yes,
                    ),
                    NoteFlowchartPort(
                      id: 'no',
                      side: NoteFlowchartPortSide.bottom,
                      label: 'Nem',
                      semantic: NoteFlowchartPortSemantic.no,
                    ),
                  ],
                ),
                NoteFlowchartNode(id: 'observe', label: 'Megfigyelés'),
                NoteFlowchartNode(id: 'oxygen', label: 'Oxygén'),
              ],
              edges: [
                NoteFlowchartEdge(
                  id: 'edge-1',
                  fromNodeId: 'start',
                  toNodeId: 'resp',
                  label: 'Kimenet',
                ),
                NoteFlowchartEdge(
                  id: 'edge-2',
                  fromNodeId: 'resp',
                  fromPortId: 'no',
                  toNodeId: 'observe',
                  label: 'Nem',
                ),
                NoteFlowchartEdge(
                  id: 'edge-3',
                  fromNodeId: 'resp',
                  fromPortId: 'yes',
                  toNodeId: 'severe',
                  label: 'Igen',
                ),
                NoteFlowchartEdge(
                  id: 'edge-4',
                  fromNodeId: 'severe',
                  fromPortId: 'no',
                  toNodeId: 'oxygen',
                  label: 'Nem',
                ),
                NoteFlowchartEdge(
                  id: 'edge-5',
                  fromNodeId: 'severe',
                  fromPortId: 'yes',
                  toNodeId: 'oxygen',
                  label: 'Igen',
                ),
              ],
            ),
            NoteBlock(
              id: 'oxygen-table',
              type: NoteBlockType.table,
              rows: [
                [
                  'súlyos légzési elégtelenség: magas áramlású oxygén',
                  'enyhe légzési elégtelenség: célzott oxygénterápia',
                ],
              ],
            ),
          ],
        ),
      );

      final retriever = NoteAwareLocalRetriever(
        base: MemoryLocalRetriever(const []),
        noteRepository: notes,
      );

      final results = await retriever.retrieveLocalVector(
        query: 'mi a légzési elégtelenség?',
        limit: 8,
        mode: 'embedding_gemma',
      );
      final joined = results.map((item) => item.text).join('\n');

      expect(joined, contains('DO2 < VO2'));
      expect(joined, contains('DO2= oxygénkínálat'));
      expect(joined, contains('VO2= oxygénigény'));
      expect(
        results.where(
          (item) => item.sourceType == EvidenceSourceType.flowchartEdge,
        ),
        hasLength(lessThanOrEqualTo(3)),
      );
      expect(DebugConsole.allText, contains('type=definition'));
      expect(DebugConsole.allText, isNot(contains('keys:jegyzet')));
    },
  );

  test(
    'local vector note retrieval keeps mixed-topic bolognai seed away from respiratory symbols',
    () async {
      final notes = MemoryNoteRepository();
      await notes.createDocumentNote(
        title: 'Légzési elégtelenség',
        document: const NoteDocument(
          blocks: [
            NoteBlock(
              id: 'definition',
              type: NoteBlockType.paragraph,
              text:
                  'Bolognai spagetti készítésekor a ragu akkor lesz kiegyensúlyozott, ha a paradicsomos alap és a hús aránya megfelelő Rejtett jegyzet: légzési elégtelenség akkor áll fenn, amikor DO2 < VO2. A receptben ez olyan, mintha kevesebb szósz jutna a tésztára.',
            ),
            NoteBlock(
              id: 'symbols',
              type: NoteBlockType.listItem,
              title: 'Magyarázat',
              searchContext: 'légzési elégtelenség',
              searchRole: NoteSearchRoles.definition,
              listItems: [
                NoteListItem(
                  id: 'recipe',
                  text:
                      'Bolognai spagettihez először hagymát és fokhagymát pirítunk',
                ),
                NoteListItem(id: 'do2', text: 'DO2= oxygénkínálat'),
                NoteListItem(id: 'vo2', text: 'VO2= oxygénigény'),
              ],
            ),
          ],
        ),
      );

      final retriever = NoteAwareLocalRetriever(
        base: MemoryLocalRetriever(const []),
        noteRepository: notes,
      );

      final results = await retriever.retrieveLocalVector(
        query: 'bolognai',
        limit: 8,
        mode: 'mediapipe_text_embedder',
      );
      final joined = results.map((item) => item.text).join('\n');

      expect(joined, contains('Bolognai spagetti'));
      expect(joined, isNot(contains('DO2')));
      expect(joined, isNot(contains('VO2')));
      expect(joined, isNot(contains('légzési elégtelenség akkor áll fenn')));
    },
  );

  test('graph expansion follows symbols discovered through linked definitions', () {
    final expander = LocalKnowledgeGraphExpander();
    const table = SourceEvidence(
      id: 'table:oxygen:row-1',
      sourceType: EvidenceSourceType.tableChunk,
      text:
          'súlyos légzési elégtelenség: magas áramlású oxygén | enyhe légzési elégtelenség: célzott oxygénterápia',
      label: 'Jegyzet · Táblázat · sor 2',
      validationState: ValidationState.validated,
    );
    const node = SourceEvidence(
      id: 'flow:resp:node',
      sourceType: EvidenceSourceType.flowchartNode,
      text: 'Légzési elégtelen?',
      label: 'Jegyzet · Flowchart · node',
      validationState: ValidationState.validated,
    );
    const hiddenDefinition = SourceEvidence(
      id: 'text:hidden:part-1',
      sourceType: EvidenceSourceType.textChunk,
      text:
          'Rejtett jegyzet: légzési elégtelenség akkor áll fenn, amikor DO2 < VO2',
      label: 'Jegyzet · Szöveg · részlet 2',
      validationState: ValidationState.validated,
    );
    const do2 = SourceEvidence(
      id: 'list:symbols:item-do2',
      sourceType: EvidenceSourceType.textChunk,
      text: 'DO2= oxygénkínálat',
      label: 'Jegyzet · Lista · elem',
      validationState: ValidationState.validated,
    );
    const vo2 = SourceEvidence(
      id: 'list:symbols:item-vo2',
      sourceType: EvidenceSourceType.textChunk,
      text: 'VO2= oxygénigény',
      label: 'Jegyzet · Lista · elem',
      validationState: ValidationState.validated,
    );
    const edge = SourceEvidence(
      id: 'flow:resp:edge-1',
      sourceType: EvidenceSourceType.flowchartEdge,
      text: 'Légzési elégtelen? -> Súlyos? [Igen]',
      label: 'Jegyzet · Flowchart · kapcsolat',
      validationState: ValidationState.validated,
    );

    final results = expander.expand(
      query: 'mi a légzési elégtelenség?',
      seeds: const [table, node],
      candidates: const [table, node, hiddenDefinition, do2, vo2, edge],
      existing: const [table, node],
      limit: 8,
    );
    final joined = results.map((item) => item.text).join('\n');

    expect(joined, contains('DO2 < VO2'));
    expect(joined, contains('DO2= oxygénkínálat'));
    expect(joined, contains('VO2= oxygénigény'));
    expect(DebugConsole.allText, contains('source=text:hidden:part-1'));
    expect(DebugConsole.allText, contains('symbol:DO2'));
    expect(DebugConsole.allText, contains('symbol:VO2'));
    expect(DebugConsole.allText, isNot(contains('keys:jegyzet')));
  });

  test('granular table evidence splits independent definition cells', () async {
    final notes = MemoryNoteRepository();
    await notes.createDocumentNote(
      title: 'Oxigén szabályok',
      document: const NoteDocument(
        blocks: [
          NoteBlock(
            id: 'oxygen-table',
            type: NoteBlockType.table,
            rows: [
              [
                'súlyos légzési elégtelenség: magas áramlású oxygén',
                'enyhe légzési elégtelenség: célzott oxygénterápia',
              ],
            ],
          ),
        ],
      ),
    );

    final retriever = NoteAwareLocalRetriever(
      base: MemoryLocalRetriever(const []),
      noteRepository: notes,
    );

    final results = await retriever.retrieveLocalVector(
      query: 'enyhe légzési elégtelenség oxigén',
      limit: 4,
      mode: 'onnx_multilingual_e5',
    );
    final joined = results.map((item) => item.text).join('\n');

    expect(
      joined,
      contains('enyhe légzési elégtelenség: célzott oxygénterápia'),
    );
    expect(
      joined,
      isNot(contains('súlyos légzési elégtelenség: magas áramlású oxygén')),
    );
    expect(results.single.id, endsWith(':row-0-cell-1'));
  });

  test('granular table evidence splits pipe-packed definition cells', () async {
    final notes = MemoryNoteRepository();
    await notes.createDocumentNote(
      title: 'Oxigén szabályok',
      document: const NoteDocument(
        blocks: [
          NoteBlock(
            id: 'oxygen-table',
            type: NoteBlockType.table,
            rows: [
              ['Szabály'],
              [
                'súlyos légzési elégtelenség: magas áramlású oxygén | enyhe légzési elégtelenség: célzott oxygénterápia',
              ],
            ],
          ),
        ],
      ),
    );

    final retriever = NoteAwareLocalRetriever(
      base: MemoryLocalRetriever(const []),
      noteRepository: notes,
    );

    final results = await retriever.retrieveLocalVector(
      query: 'enyhe légzési elégtelenség oxigén',
      limit: 4,
      mode: 'mediapipe_text_embedder',
    );
    final joined = results.map((item) => item.text).join('\n');

    expect(
      joined,
      contains('enyhe légzési elégtelenség: célzott oxygénterápia'),
    );
    expect(
      joined,
      isNot(contains('súlyos légzési elégtelenség: magas áramlású oxygén')),
    );
    expect(results.single.id, endsWith(':row-1-cell-1'));
  });
}
