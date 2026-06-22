import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/notes/models/note_document.dart';
import 'package:djinn/src/rag/models/source_evidence.dart';
import 'package:djinn/src/rag/retrieval/note_atom_indexer.dart';

void main() {
  test(
    'atomizes note blocks into spec atom types without hidden-note atom type',
    () {
      final atoms = const NoteAtomIndexer().buildEvidence(
        noteId: 'note-1',
        noteTitle: 'Teszt jegyzet',
        document: _documentWithEveryAtomType(),
      );

      expect(
        atoms.map((atom) => atom.atomType).whereType<NoteEvidenceAtomType>(),
        containsAll([
          NoteEvidenceAtomType.textSentence,
          NoteEvidenceAtomType.listItem,
          NoteEvidenceAtomType.tableCell,
          NoteEvidenceAtomType.flowchartNode,
          NoteEvidenceAtomType.flowchartEdge,
        ]),
      );
      expect(
        atoms.map((atom) => atom.atomType?.wireName),
        isNot(contains('hidden_note_sentence')),
      );

      final hiddenNoteText = atoms.singleWhere(
        (atom) => atom.text.contains('Rejtett jegyzet'),
      );
      expect(hiddenNoteText.atomType, NoteEvidenceAtomType.textSentence);
      expect(hiddenNoteText.chunkId, 'mixed-text');
      expect(hiddenNoteText.fullChunkText, contains('Bolognai ragu'));
      expect(hiddenNoteText.sourceStart, isNonNegative);
      final sourceStart = hiddenNoteText.sourceStart;
      final sourceEnd = hiddenNoteText.sourceEnd;
      expect(sourceStart, isNotNull);
      expect(sourceEnd, isNotNull);
      expect(sourceEnd!, greaterThan(sourceStart!));
    },
  );

  test(
    'table cell search text includes chunk title, row header, column header, and value',
    () {
      final atoms = const NoteAtomIndexer().buildEvidence(
        noteId: 'note-1',
        noteTitle: 'Légzési elégtelenség',
        document: const NoteDocument(
          blocks: [
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

      final o2 = atoms.singleWhere(
        (atom) =>
            atom.atomType == NoteEvidenceAtomType.tableCell &&
            atom.text.contains('O2'),
      );

      expect(o2.text, contains('O2'));
      expect(o2.searchableText, contains('Terápia'));
      expect(o2.searchableText, contains('Oxigén'));
      expect(o2.searchableText, contains('súlyos légzési elégtelenség'));
      expect(o2.searchableText, contains('O2'));
    },
  );
}

NoteDocument _documentWithEveryAtomType() {
  return const NoteDocument(
    blocks: [
      NoteBlock(
        id: 'mixed-text',
        type: NoteBlockType.paragraph,
        title: 'Kevert szöveg',
        text:
            'Bolognai ragu lassan fő. Rejtett jegyzet: légzési elégtelenség akkor áll fenn, amikor DO2 < VO2.',
      ),
      NoteBlock(
        id: 'list',
        type: NoteBlockType.listItem,
        title: 'Lista',
        listItems: [
          NoteListItem(id: 'bolognai', text: 'bolognai hozzávalók'),
          NoteListItem(id: 'do2', text: 'DO2 = oxigénkínálat'),
        ],
      ),
      NoteBlock(
        id: 'table',
        type: NoteBlockType.table,
        title: 'Terápia',
        rows: [
          ['Beavatkozás', 'súlyos légzési elégtelenség'],
          ['Oxigén', 'O2'],
        ],
      ),
      NoteBlock(
        id: 'flow',
        type: NoteBlockType.flowchart,
        title: 'Folyamat',
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
    ],
  );
}
