import 'dart:typed_data';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/debug/debug_console.dart';
import 'package:djinn/src/knowledge/models/local_extraction.dart';
import 'package:djinn/src/notes/models/note_document.dart';
import 'package:djinn/src/notes/models/note_item.dart';
import 'package:djinn/src/notes/pdf/note_pdf_document_builder.dart';
import 'package:djinn/src/notes/pdf/note_pdf_export_models.dart';
import 'package:djinn/src/notes/pdf/note_pdf_export_service.dart';

void main() {
  test('safeNotePdfFilename normalizes empty and unsafe note titles', () {
    expect(
      safeNotePdfFilename('Légzési elégtelenség / terápia'),
      'L_gz_si_el_gtelens_g_ter_pia.pdf',
    );
    expect(safeNotePdfFilename('   '), 'jegyzet.pdf');
    expect(safeNotePdfFilename('already.pdf'), 'already.pdf');
  });

  test('export service rejects notes without exportable content', () async {
    final service = NotePdfExportService(
      buildPdfBytes: (_) async => Uint8List.fromList([1, 2, 3]),
    );
    final note = NoteItem(
      id: 'empty',
      type: NoteItemType.document,
      title: 'Üres',
      plainText: '',
      payloadJson: const NoteDocument(
        blocks: [NoteBlock(id: 'p1', type: NoteBlockType.paragraph, text: '')],
      ).toPayloadJson(),
      auditState: LocalAuditState.edited,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    await expectLater(
      service.generate(note),
      throwsA(isA<NotePdfExportException>()),
    );
  });

  test(
    'export service rejects notes that only contain excluded metadata',
    () async {
      final service = NotePdfExportService(
        buildPdfBytes: (_) async => Uint8List.fromList([1, 2, 3]),
      );
      final note = NoteItem(
        id: 'metadata-only',
        type: NoteItemType.document,
        title: 'Csak meta',
        plainText: '',
        payloadJson: const NoteDocument(
          blocks: [
            NoteBlock(
              id: 'p1',
              type: NoteBlockType.paragraph,
              text: '',
              searchContext: 'hidden search context',
              searchAliases: ['hidden alias'],
              tags: [
                NoteKnowledgeTag(
                  type: NoteKnowledgeTagTypes.topic,
                  label: 'tag',
                ),
              ],
            ),
          ],
        ).toPayloadJson(),
        auditState: LocalAuditState.edited,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      await expectLater(
        service.generate(note),
        throwsA(isA<NotePdfExportException>()),
      );
    },
  );

  test(
    'document builder logs mixed block rendering in document order',
    () async {
      DebugConsole.clear();
      const document = NoteDocument(
        blocks: [
          NoteBlock(id: 'p1', type: NoteBlockType.paragraph, text: 'Első'),
          NoteBlock(
            id: 'f1',
            type: NoteBlockType.flowchart,
            title: 'Döntés',
            nodes: [
              NoteFlowchartNode(id: 'a', label: 'Start', x: 0, y: 0),
              NoteFlowchartNode(id: 'b', label: 'Vége', x: 240, y: 120),
            ],
            edges: [
              NoteFlowchartEdge(
                id: 'e1',
                fromNodeId: 'a',
                toNodeId: 'b',
                label: 'Igen',
              ),
            ],
          ),
          NoteBlock(id: 'p2', type: NoteBlockType.paragraph, text: 'Második'),
        ],
      );
      final note = NoteItem(
        id: 'mixed-order',
        type: NoteItemType.document,
        title: 'Sorrend',
        plainText: document.plainText,
        payloadJson: document.toPayloadJson(),
        auditState: LocalAuditState.edited,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      await const NotePdfExportService().generate(note);

      final logs = DebugConsole.allText;
      final first = logs.indexOf('render block id=p1');
      final flowchart = logs.indexOf('flowchart block=f1');
      final second = logs.indexOf('render block id=p2');
      expect(first, isNonNegative);
      expect(flowchart, isNonNegative);
      expect(second, isNonNegative);
      expect(logs, contains('mode='));
      expect(logs, contains('tiles='));
      expect(first, lessThan(flowchart));
      expect(flowchart, lessThan(second));
    },
  );

  test('document builder starts each batch note on a fresh page', () async {
    DebugConsole.clear();
    NoteItem note(String id, String title, String text) {
      final document = NoteDocument(
        blocks: [
          NoteBlock(id: '$id-p1', type: NoteBlockType.paragraph, text: text),
        ],
      );
      return NoteItem(
        id: id,
        type: NoteItemType.document,
        title: title,
        plainText: document.plainText,
        payloadJson: document.toPayloadJson(),
        auditState: LocalAuditState.edited,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
    }

    final bytes = await const NotePdfDocumentBuilder().buildMany([
      note('note-1', 'Első', 'Első tartalom'),
      note('note-2', 'Második', 'Második tartalom'),
    ]);

    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    final logs = DebugConsole.allText;
    expect(logs, contains('build batch start notes=2'));
    expect(logs, contains('build note start note=note-1 index=1/2'));
    expect(
      logs,
      contains('build note start note=note-2 index=2/2 freshPage=true'),
    );
  });

  test('list marker helper follows checkbox and hierarchy modes', () {
    const checkbox = NoteBlock(
      id: 'c1',
      type: NoteBlockType.listItem,
      listItems: [
        NoteListItem(id: 'a', text: 'A'),
        NoteListItem(id: 'b', text: 'B', checked: true),
      ],
    );
    const hierarchy = NoteBlock(
      id: 'h1',
      type: NoteBlockType.listItem,
      listLayoutMode: NoteListLayoutMode.hierarchy,
      listItems: [
        NoteListItem(id: 'a', text: 'A'),
        NoteListItem(id: 'b', text: 'B', level: 1),
        NoteListItem(id: 'c', text: 'C'),
      ],
    );

    expect(notePdfListMarkersForBlock(checkbox), ['[ ]', '[x]']);
    expect(notePdfListMarkersForBlock(hierarchy), ['1.', '-', '2.']);
  });

  test(
    'document builder creates PDF bytes from ordered note blocks without tag metadata',
    () async {
      const document = NoteDocument(
        tags: [
          NoteKnowledgeTag(
            type: NoteKnowledgeTagTypes.topic,
            label: 'hidden-tag',
          ),
        ],
        blocks: [
          NoteBlock(
            id: 'p1',
            type: NoteBlockType.paragraph,
            text: 'Első bekezdés',
          ),
          NoteBlock(
            id: 't1',
            type: NoteBlockType.table,
            title: 'Táblázat',
            rows: [
              ['Név', 'Érték'],
              ['SpO2', '88-92%'],
            ],
          ),
          NoteBlock(
            id: 'f1',
            type: NoteBlockType.flowchart,
            title: 'Döntés',
            nodes: [
              NoteFlowchartNode(id: 'a', label: 'Súlyos?', x: 0, y: 0),
              NoteFlowchartNode(id: 'b', label: 'Oxigén', x: 220, y: 120),
            ],
            edges: [
              NoteFlowchartEdge(
                id: 'e1',
                fromNodeId: 'a',
                toNodeId: 'b',
                label: 'Igen',
              ),
            ],
          ),
        ],
      );
      final note = NoteItem(
        id: 'note-1',
        type: NoteItemType.document,
        title: 'PDF jegyzet',
        plainText: document.plainText,
        payloadJson: document.toPayloadJson(),
        auditState: LocalAuditState.edited,
        createdAt: DateTime(2026, 6, 23),
        updatedAt: DateTime(2026, 6, 23),
      );

      final result = await const NotePdfExportService().generate(note);

      expect(result.filename, 'PDF_jegyzet.pdf');
      expect(String.fromCharCodes(result.bytes.take(4)), '%PDF');
      expect(result.bytes.length, greaterThan(1000));
    },
  );

  test(
    'export service writes preview file and logs save cancellation',
    () async {
      DebugConsole.clear();
      final tempDir = await Directory.systemTemp.createTemp('note-pdf-test-');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final service = NotePdfExportService(
        buildPdfBytes: (_) async =>
            Uint8List.fromList('%PDF fake bytes'.codeUnits),
        tempDirectoryProvider: () async => tempDir,
        saveFile:
            ({required bytes, required dialogTitle, required fileName}) async {
              expect(dialogTitle, 'PDF mentése');
              expect(fileName, 'Ment_s.pdf');
              expect(String.fromCharCodes(bytes.take(4)), '%PDF');
              return null;
            },
      );
      final note = NoteItem(
        id: 'preview-note',
        type: NoteItemType.document,
        title: 'Mentés',
        plainText: 'Exportálható',
        payloadJson: const NoteDocument(
          blocks: [
            NoteBlock(
              id: 'p1',
              type: NoteBlockType.paragraph,
              text: 'Exportálható',
            ),
          ],
        ).toPayloadJson(),
        auditState: LocalAuditState.edited,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      final preview = await service.createPreviewFile(note);
      final saved = await service.savePreviewFile(preview);

      expect(saved, isNull);
      expect(File(preview.path).existsSync(), isTrue);
      expect(preview.filename, 'Ment_s.pdf');
      expect(DebugConsole.allText, contains('[NotePdfExport] preview path='));
      expect(
        DebugConsole.allText,
        contains('[NotePdfExport] save cancelled filename=Ment_s.pdf'),
      );
    },
  );

  test(
    'export service writes batch preview file from selected notes',
    () async {
      DebugConsole.clear();
      final tempDir = await Directory.systemTemp.createTemp(
        'note-pdf-batch-test-',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final receivedIds = <String>[];
      final service = NotePdfExportService(
        buildPdfBatchBytes: (notes) async {
          receivedIds.addAll(notes.map((note) => note.id));
          return Uint8List.fromList('%PDF batch bytes'.codeUnits);
        },
        tempDirectoryProvider: () async => tempDir,
      );
      NoteItem note(String id, String title) {
        return NoteItem(
          id: id,
          type: NoteItemType.document,
          title: title,
          plainText: 'Exportálható',
          payloadJson: const NoteDocument(
            blocks: [
              NoteBlock(
                id: 'p1',
                type: NoteBlockType.paragraph,
                text: 'Exportálható',
              ),
            ],
          ).toPayloadJson(),
          auditState: LocalAuditState.edited,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );
      }

      final preview = await service.createPreviewFileForNotes([
        note('n1', 'Első'),
        note('n2', 'Második'),
      ]);

      expect(receivedIds, ['n1', 'n2']);
      expect(preview.filename, 'jegyzetek_2.pdf');
      expect(File(preview.path).existsSync(), isTrue);
      expect(DebugConsole.allText, contains('generate batch start notes=2'));
      expect(DebugConsole.allText, contains('preview path='));
    },
  );
}
