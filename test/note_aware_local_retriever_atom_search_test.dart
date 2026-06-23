import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/debug/debug_console.dart';
import 'package:djinn/src/notes/data/note_repository.dart';
import 'package:djinn/src/notes/models/note_document.dart';
import 'package:djinn/src/rag/models/source_evidence.dart';
import 'package:djinn/src/rag/retrieval/local_retriever.dart';
import 'package:djinn/src/rag/retrieval/note_aware_local_retriever.dart';

void main() {
  setUp(DebugConsole.clear);

  test(
    'bolognai query returns only direct bolognai atoms from mixed chunks',
    () async {
      final notes = MemoryNoteRepository();
      await notes.createDocumentNote(
        title: 'Kevert jegyzet',
        document: const NoteDocument(
          blocks: [
            NoteBlock(
              id: 'mixed',
              type: NoteBlockType.paragraph,
              text:
                  'Bolognai ragu lassan fő. Légzési elégtelenség akkor áll fenn, amikor DO2 < VO2.',
            ),
          ],
        ),
      );
      final retriever = NoteAwareLocalRetriever(
        base: MemoryLocalRetriever(const []),
        noteRepository: notes,
      );

      final results = await retriever.retrieveOffline(
        query: 'bolognai',
        limit: 8,
      );
      final noteAtoms = results
          .where((item) => item.id.startsWith('note:'))
          .toList();

      expect(noteAtoms, isNotEmpty);
      expect(
        noteAtoms.every(
          (item) => item.atomType == NoteEvidenceAtomType.textSentence,
        ),
        isTrue,
      );
      expect(
        noteAtoms.every(
          (item) => item.reasons.contains(NoteEvidenceReason.directQuery),
        ),
        isTrue,
      );
      expect(
        noteAtoms.map((item) => item.text).join('\n'),
        contains('Bolognai ragu'),
      );
      expect(
        noteAtoms.map((item) => item.text).join('\n'),
        isNot(contains('Légzési elégtelenség')),
      );
      expect(
        DebugConsole.allText,
        contains(
          '[NoteAtomSearch] start mode=offline query="bolognai" limit=8',
        ),
      );
      expect(
        DebugConsole.allText,
        contains('[NoteAtomSearch] evidence notes=1 atoms=2 text_sentence=2'),
      );
      expect(
        DebugConsole.allText,
        contains('[NoteAtomSearch] direct matches count=1'),
      );
      expect(
        DebugConsole.allText,
        contains('[NoteAtomSearch] primary scope=note:'),
      );
      expect(
        DebugConsole.allText,
        contains('[NoteAtomSearch] cascade skipped reason=single_term'),
      );
      expect(
        DebugConsole.allText,
        contains('[NoteAtomSearch] final count=1 note=1 external=0'),
      );
    },
  );

  test(
    'sulyos legzesi elegtelenseg retrieves O2 by table column without external oxygen cascade',
    () async {
      final notes = MemoryNoteRepository();
      await _createRespiratoryNote(notes);
      await notes.createDocumentNote(
        title: 'Oxigén háttér',
        document: const NoteDocument(
          blocks: [
            NoteBlock(
              id: 'oxygen-background',
              type: NoteBlockType.paragraph,
              text: 'Oxigén protokoll általános monitorozási megjegyzésekkel.',
            ),
          ],
        ),
      );
      await notes.createDocumentNote(
        title: 'Berodual',
        document: const NoteDocument(
          blocks: [
            NoteBlock(
              id: 'berodual',
              type: NoteBlockType.table,
              title: 'Gyógyszerek',
              rows: [
                ['Gyógyszer', 'Indikáció'],
                ['Berodual', 'súlyos légzési elégtelenség esetén mérlegelhető'],
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
        query: 'súlyos légzési elégtelenség',
        limit: 12,
      );
      final joined = results.map((item) => item.text).join('\n');
      final o2 = results.singleWhere(
        (item) =>
            item.atomType == NoteEvidenceAtomType.tableCell &&
            item.text.contains('O2'),
      );

      expect(o2.reasons, contains(NoteEvidenceReason.tableColumn));
      expect(o2.reasons, contains(NoteEvidenceReason.tableCell));
      expect(joined, contains('Berodual'));
      expect(joined, isNot(contains('Oxigén protokoll általános')));
      expect(
        results
            .where(
              (item) =>
                  item.documentId != o2.documentId &&
                  item.id.startsWith('note:'),
            )
            .every(
              (item) =>
                  item.reasons.contains(NoteEvidenceReason.externalDirect),
            ),
        isTrue,
      );
    },
  );

  test(
    'legzesi elegtelenseg definicio treats definicio as literal token while cascading DO2 VO2 inside primary note',
    () async {
      final notes = MemoryNoteRepository();
      await _createRespiratoryNote(notes);
      await notes.createDocumentNote(
        title: 'Távoli gyógyszer',
        document: const NoteDocument(
          blocks: [
            NoteBlock(
              id: 'berodual',
              type: NoteBlockType.paragraph,
              text: 'Berodual inhaláció hörgőtágító példaként.',
            ),
          ],
        ),
      );
      final retriever = NoteAwareLocalRetriever(
        base: MemoryLocalRetriever(const []),
        noteRepository: notes,
      );

      final results = await retriever.retrieveOffline(
        query: 'légzési elégtelenség definíció',
        limit: 12,
      );
      final joined = results.map((item) => item.text).join('\n');
      final do2 = results.singleWhere((item) => item.text.contains('DO2 ='));
      final vo2 = results.singleWhere((item) => item.text.contains('VO2 ='));

      expect(joined, contains('DO2 < VO2'));
      expect(joined, contains('DO2 = oxigénkínálat'));
      expect(joined, contains('VO2 = oxigénigény'));
      expect(joined, isNot(contains('Berodual inhaláció')));
      expect(do2.reasons, contains(NoteEvidenceReason.processLink));
      expect(vo2.reasons, contains(NoteEvidenceReason.processLink));
      expect(
        results
            .where((item) => item.id.startsWith('note:'))
            .every((item) => item.reasons.isNotEmpty),
        isTrue,
      );
    },
  );

  test(
    'single-word sulyos query does not start deep process cascade',
    () async {
      final notes = MemoryNoteRepository();
      await _createRespiratoryNote(notes);
      final retriever = NoteAwareLocalRetriever(
        base: MemoryLocalRetriever(const []),
        noteRepository: notes,
      );

      final results = await retriever.retrieveOffline(
        query: 'súlyos',
        limit: 12,
      );
      final joined = results.map((item) => item.text).join('\n');

      expect(joined, contains('Súlyos?'));
      expect(joined, isNot(contains('célzott oxigénterápia')));
      expect(
        results.every(
          (item) => item.reasons.isNotEmpty || !item.id.startsWith('note:'),
        ),
        isTrue,
      );
    },
  );
}

Future<void> _createRespiratoryNote(MemoryNoteRepository notes) async {
  await notes.createDocumentNote(
    title: 'Légzési elégtelenség',
    document: const NoteDocument(
      blocks: [
        NoteBlock(
          id: 'definition',
          type: NoteBlockType.paragraph,
          text: 'Légzési elégtelenség akkor áll fenn, amikor DO2 < VO2.',
        ),
        NoteBlock(
          id: 'symbols',
          type: NoteBlockType.listItem,
          title: 'Magyarázat',
          listItems: [
            NoteListItem(id: 'do2', text: 'DO2 = oxigénkínálat'),
            NoteListItem(id: 'vo2', text: 'VO2 = oxigénigény'),
          ],
        ),
        NoteBlock(
          id: 'flow',
          type: NoteBlockType.flowchart,
          title: 'Triage',
          nodes: [
            NoteFlowchartNode(id: 'severe', label: 'Súlyos?'),
            NoteFlowchartNode(id: 'oxygen', label: 'Oxigén'),
          ],
          edges: [
            NoteFlowchartEdge(
              id: 'edge-severe-oxygen',
              fromNodeId: 'severe',
              toNodeId: 'oxygen',
              label: 'Igen',
            ),
          ],
        ),
        NoteBlock(
          id: 'therapy',
          type: NoteBlockType.table,
          title: 'Terápia',
          rows: [
            [
              'Beavatkozás',
              'enyhe légzési elégtelenség',
              'súlyos légzési elégtelenség',
            ],
            ['Oxigén', 'célzott oxigénterápia', 'O2'],
          ],
        ),
      ],
    ),
  );
}
