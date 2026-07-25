import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/notes/models/mixed_chunk_parser.dart';
import 'package:djinn/src/notes/models/note_document.dart';

void main() {
  test('parses paragraph plus bullet list into mixed sections', () {
    final block = mixedBlockFromPlainText(
      id: 'manual-1',
      title: 'Célok',
      text:
          'I. Célok:\n'
          'Az eljárásrend célja:\n'
          '• az ellátás során\n'
          '• a felszerelés meghatározása\n\n'
          'Jelen eljárásrend a korábban kiadott...',
    );

    expect(block.type, NoteBlockType.mixed);
    expect(block.mixedSections.map((section) => section.type), [
      NoteMixedSectionType.paragraph,
      NoteMixedSectionType.list,
      NoteMixedSectionType.paragraph,
    ]);
    expect(block.mixedSections[1].listItems.map((item) => item.text), [
      'az ellátás során',
      'a felszerelés meghatározása',
    ]);
  });

  test('converts legacy table block to one mixed table section', () {
    const legacy = NoteBlock(
      id: 'table-1',
      type: NoteBlockType.table,
      title: 'Eszközök',
      rows: [
        ['Eszköz', 'Mennyiség'],
        ['AED', '1'],
      ],
    );

    final mixed = mixedBlockFromLegacy(legacy);

    expect(mixed.type, NoteBlockType.mixed);
    expect(mixed.mixedSections.single.type, NoteMixedSectionType.table);
    expect(mixed.mixedSections.single.rows.last, ['AED', '1']);
  });

  test('forces every non-empty manual list line into one list section', () {
    final block = listBlockFromPlainText(
      id: 'manual-list',
      title: 'Teendők',
      text: '• Első elem\n  - Második elem\nHarmadik elem',
    );

    expect(block.type, NoteBlockType.mixed);
    expect(block.mixedSections.single.type, NoteMixedSectionType.list);
    expect(block.mixedSections.single.listItems.map((item) => item.text), [
      'Első elem',
      'Második elem',
      'Harmadik elem',
    ]);
    expect(block.mixedSections.single.listItems.map((item) => item.level), [
      0,
      1,
      0,
    ]);
  });

  test('parses one canonical table section and drops markdown separator', () {
    final block = tableBlockFromPlainText(
      id: 'manual-table',
      title: 'Mérések',
      text:
          '| Név | Érték |\n'
          '| --- | :---: |\n'
          '| Pulzus | 80 |',
    );

    expect(block.type, NoteBlockType.mixed);
    expect(block.mixedSections.single.type, NoteMixedSectionType.table);
    expect(block.mixedSections.single.rows, [
      ['Név', 'Érték'],
      ['Pulzus', '80'],
    ]);
  });
}
