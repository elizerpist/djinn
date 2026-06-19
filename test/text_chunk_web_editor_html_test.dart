import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/notes/models/note_document.dart';
import 'package:djinn/src/notes/ui/text_chunk_web_editor_html.dart';

void main() {
  test('builds the approved contenteditable text rail contract', () {
    const block = NoteBlock(
      id: 'text-1',
      type: NoteBlockType.paragraph,
      text: 'DO2 magas aramlasu oxygen',
      rangeTags: [
        NoteTextRangeTag(
          id: 'range-1',
          start: 0,
          end: 3,
          tag: NoteKnowledgeTag(
            type: NoteKnowledgeTagTypes.symbol,
            label: 'DO2',
            colorValue: 0xFF0D9488,
          ),
          tags: [
            NoteKnowledgeTag(
              type: NoteKnowledgeTagTypes.symbol,
              label: 'DO2',
              colorValue: 0xFF0D9488,
            ),
            NoteKnowledgeTag(
              type: NoteKnowledgeTagTypes.topic,
              label: 'legzes',
              colorValue: 0xFF2563EB,
            ),
            NoteKnowledgeTag(
              type: NoteKnowledgeTagTypes.state,
              label: 'sulyos',
              colorValue: 0xFFDC2626,
            ),
          ],
        ),
      ],
    );

    final html = buildTextChunkWebEditorHtml(block);

    expect(html, contains('contenteditable="true"'));
    expect(html, contains('line.after(rail)'));
    expect(html, contains('NoteBridge.postMessage'));
    expect(html, contains('"textChanged"'));
    expect(html, contains('"rangeTagsChanged"'));
    expect(html, contains('"--secondary-lines", "2"'));
    expect(html, contains('0xFF2563EB'));
    expect(html, contains('0xFFDC2626'));
  });
}
