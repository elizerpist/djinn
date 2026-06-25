import 'note_document.dart';

NoteBlock mixedBlockFromPlainText({
  required String id,
  String? title,
  required String text,
  List<NoteKnowledgeTag> tags = const [],
}) {
  final sections = parseMixedSectionsFromPlainText(text);
  return NoteBlock(
    id: id,
    type: NoteBlockType.mixed,
    title: title,
    tags: tags,
    mixedSections: sections.isEmpty
        ? [
            NoteMixedSection(
              id: '$id-p1',
              type: NoteMixedSectionType.paragraph,
              text: text.trim(),
            ),
          ]
        : sections,
  );
}

NoteBlock mixedBlockFromLegacy(NoteBlock block) {
  if (block.type == NoteBlockType.mixed) {
    return block;
  }

  final section = switch (block.type) {
    NoteBlockType.listItem => NoteMixedSection(
      id: '${block.id}-list',
      type: NoteMixedSectionType.list,
      title: block.title,
      listItems: block.listItems,
      listLayoutMode: block.listLayoutMode,
    ),
    NoteBlockType.table => NoteMixedSection(
      id: '${block.id}-table',
      type: NoteMixedSectionType.table,
      title: block.title,
      rows: block.rows,
      tableColumnWidths: block.tableColumnWidths,
      tableRowHeights: block.tableRowHeights,
      scopedTags: block.scopedTags,
    ),
    NoteBlockType.flowchart ||
    NoteBlockType.heading ||
    NoteBlockType.paragraph ||
    NoteBlockType.mixed => NoteMixedSection(
      id: '${block.id}-p',
      type: NoteMixedSectionType.paragraph,
      title: block.title,
      text: block.text,
      rangeTags: block.rangeTags,
      paragraphStyles: block.paragraphStyles,
    ),
  };

  return block.copyWith(type: NoteBlockType.mixed, mixedSections: [section]);
}

List<NoteMixedSection> parseMixedSectionsFromPlainText(String text) {
  final sections = <NoteMixedSection>[];
  final paragraphLines = <String>[];
  final listItems = <NoteListItem>[];
  var sectionIndex = 1;
  var itemIndex = 1;

  void flushParagraph() {
    final paragraph = paragraphLines.join('\n').trim();
    paragraphLines.clear();
    if (paragraph.isEmpty) {
      return;
    }
    sections.add(
      NoteMixedSection(
        id: 'section-${sectionIndex++}',
        type: NoteMixedSectionType.paragraph,
        text: paragraph,
      ),
    );
  }

  void flushList() {
    if (listItems.isEmpty) {
      return;
    }
    sections.add(
      NoteMixedSection(
        id: 'section-${sectionIndex++}',
        type: NoteMixedSectionType.list,
        listItems: List<NoteListItem>.of(listItems),
        listLayoutMode: NoteListLayoutMode.hierarchy,
      ),
    );
    listItems.clear();
  }

  for (final rawLine in text.replaceAll('\r\n', '\n').split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) {
      flushParagraph();
      flushList();
      continue;
    }

    final listMatch = _listLinePattern.firstMatch(line);
    if (listMatch != null) {
      flushParagraph();
      final marker = listMatch.group(1) ?? '';
      final value = (listMatch.group(2) ?? '').trim();
      listItems.add(
        NoteListItem(
          id: 'item-${itemIndex++}',
          text: value,
          level: marker.startsWith(RegExp(r'\d')) ? 0 : _leadingIndent(rawLine),
        ),
      );
      continue;
    }

    flushList();
    paragraphLines.add(line);
  }

  flushParagraph();
  flushList();
  return sections;
}

final RegExp _listLinePattern = RegExp(r'^([•*-]|\d+[\.)])\s+(.+)$');

int _leadingIndent(String line) {
  final spaces = line.length - line.trimLeft().length;
  return (spaces / 2).floor().clamp(0, 8).toInt();
}
