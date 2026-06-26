import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../debug/debug_console.dart';
import '../models/note_document.dart';
import '../models/note_item.dart';
import '../models/note_list_hierarchy_markers.dart';
import 'note_flowchart_pdf_layout.dart';
import 'note_pdf_export_models.dart';

const _pageFormat = PdfPageFormat.a4;
const _pageMargin = 42.0;
const _sectionGap = 16.0;
const _flowchartMargin = 32.0;
const _flowchartHeaderHeight = 44.0;
const _flowchartDocumentHeaderHeight = 72.0;
const _flowchartFooterHeight = 18.0;

final _ink = PdfColor.fromHex('#111827');
final _muted = PdfColor.fromHex('#6B7280');
final _rule = PdfColor.fromHex('#D1D5DB');
final _softFill = PdfColor.fromHex('#F8FAFC');
final _nodeFill = PdfColor.fromHex('#EFF6FF');
final _nodeStroke = PdfColor.fromHex('#2563EB');
final _edgeStroke = PdfColor.fromHex('#475569');
final _accent = PdfColor.fromHex('#0F766E');

class NotePdfDocumentBuilder {
  const NotePdfDocumentBuilder();

  Future<Uint8List> build(NoteItem note) async {
    return buildMany([note]);
  }

  Future<Uint8List> buildMany(List<NoteItem> notes) async {
    final exportableNotes = List<NoteItem>.from(notes, growable: false);
    DebugConsole.log(
      '[NotePdfExport] build batch start notes=${exportableNotes.length} '
      'ids=${exportableNotes.map((note) => note.id).join(',')}',
    );

    final fonts = await _PdfFonts.load();
    final pdf = pw.Document(
      title: exportableNotes.length == 1
          ? _documentTitle(exportableNotes.single)
          : 'Jegyzetek',
      author: 'Djinn',
      creator: 'Djinn note PDF export',
    );
    final textTheme = _PdfTextTheme(fonts);

    for (var i = 0; i < exportableNotes.length; i += 1) {
      _addNotePages(
        pdf,
        exportableNotes[i],
        textTheme,
        index: i + 1,
        total: exportableNotes.length,
      );
    }

    final bytes = await pdf.save();
    DebugConsole.log(
      '[NotePdfExport] build batch complete notes=${exportableNotes.length} '
      'bytes=${bytes.length}',
    );
    return Uint8List.fromList(bytes);
  }
}

String _documentTitle(NoteItem note) {
  return note.title.trim().isEmpty ? 'Jegyzet' : note.title.trim();
}

void _addNotePages(
  pw.Document pdf,
  NoteItem note,
  _PdfTextTheme textTheme, {
  required int index,
  required int total,
}) {
  final document = NoteDocument.fromPayload(
    note.payloadJson,
    legacyType: note.type.wireName,
    legacyText: note.plainText,
    title: note.title,
  );
  DebugConsole.log(
    '[NotePdfExport] build note start note=${note.id} index=$index/$total '
    'freshPage=${index > 1} blocks=${document.blocks.length}',
  );

  final blocks = document.blocks
      .where(notePdfBlockHasExportableContent)
      .toList(growable: false);
  final pendingBlocks = <NoteBlock>[];
  var headerPending = true;
  for (final block in blocks) {
    if (block.type == NoteBlockType.flowchart) {
      if (pendingBlocks.isNotEmpty) {
        _addOrdinaryPages(
          pdf,
          note,
          pendingBlocks,
          textTheme,
          includeDocumentHeader: headerPending,
        );
        headerPending = false;
        pendingBlocks.clear();
      }
      _addFlowchartPages(
        pdf,
        note,
        block,
        textTheme,
        includeDocumentHeader: headerPending,
      );
      headerPending = false;
    } else {
      pendingBlocks.add(block);
    }
  }
  if (pendingBlocks.isNotEmpty) {
    _addOrdinaryPages(
      pdf,
      note,
      pendingBlocks,
      textTheme,
      includeDocumentHeader: headerPending,
    );
  }
  DebugConsole.log(
    '[NotePdfExport] build note complete note=${note.id} index=$index/$total',
  );
}

bool notePdfBlockHasExportableContent(NoteBlock block) {
  final title = block.title?.trim();
  if (title != null && title.isNotEmpty) {
    return true;
  }
  return switch (block.type) {
    NoteBlockType.heading ||
    NoteBlockType.paragraph => block.text.trim().isNotEmpty,
    NoteBlockType.mixed => block.plainText.trim().isNotEmpty,
    NoteBlockType.listItem =>
      block.text.trim().isNotEmpty ||
          block.listItems.any((item) => item.text.trim().isNotEmpty),
    NoteBlockType.table => block.rows.any(
      (row) => row.any((cell) => cell.trim().isNotEmpty),
    ),
    NoteBlockType.flowchart =>
      block.text.trim().isNotEmpty ||
          block.nodes.isNotEmpty ||
          block.edges.any((edge) => edge.label.trim().isNotEmpty),
  };
}

List<String> notePdfListMarkersForBlock(NoteBlock block) {
  final hierarchyMarkers = block.listLayoutMode == NoteListLayoutMode.hierarchy
      ? noteHierarchyMarkersForItems(block.listItems)
      : const <String, String>{};
  return [
    for (final item in block.listItems)
      if (block.listLayoutMode == NoteListLayoutMode.hierarchy)
        hierarchyMarkers[item.id] ?? ''
      else
        item.checked ? '[x]' : '[ ]',
  ];
}

void _addOrdinaryPages(
  pw.Document pdf,
  NoteItem note,
  List<NoteBlock> blocks,
  _PdfTextTheme textTheme, {
  required bool includeDocumentHeader,
}) {
  if (blocks.isEmpty) {
    return;
  }
  final segment = List<NoteBlock>.from(blocks, growable: false);
  pdf.addPage(
    pw.MultiPage(
      pageFormat: _pageFormat.copyWith(marginLeft: _pageMargin),
      margin: const pw.EdgeInsets.all(_pageMargin),
      footer: (context) => _footer(context, textTheme),
      build: (context) => [
        if (includeDocumentHeader) _documentHeader(note, textTheme),
        for (final block in segment) ...[
          pw.SizedBox(height: _sectionGap),
          ..._blockSection(block, textTheme),
        ],
      ],
    ),
  );
}

class _PdfFonts {
  const _PdfFonts({required this.regular, required this.medium});

  final pw.Font regular;
  final pw.Font medium;

  static Future<_PdfFonts> load() async {
    return _PdfFonts(
      regular: pw.Font.ttf(
        await _loadFontData('assets/fonts/Roboto-Regular.ttf'),
      ),
      medium: pw.Font.ttf(
        await _loadFontData('assets/fonts/Roboto-Medium.ttf'),
      ),
    );
  }

  static Future<ByteData> _loadFontData(String assetPath) async {
    final file = File(assetPath);
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      return ByteData.view(
        bytes.buffer,
        bytes.offsetInBytes,
        bytes.lengthInBytes,
      );
    }
    return rootBundle.load(assetPath);
  }
}

class _PdfTextTheme {
  const _PdfTextTheme(this._fonts);

  final _PdfFonts _fonts;

  pw.TextStyle _base({
    required double fontSize,
    PdfColor? color,
    pw.FontWeight fontWeight = pw.FontWeight.normal,
    double? height,
    double? letterSpacing,
  }) {
    return pw.TextStyle(
      fontNormal: _fonts.regular,
      fontBold: _fonts.medium,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  pw.TextStyle get title => pw.TextStyle(
    fontNormal: _fonts.regular,
    fontBold: _fonts.medium,
    fontSize: 22,
    fontWeight: pw.FontWeight.bold,
    color: _ink,
  );

  pw.TextStyle get section => _base(
    fontSize: 11,
    fontWeight: pw.FontWeight.bold,
    color: _muted,
    letterSpacing: 0.5,
  );

  pw.TextStyle get heading =>
      _base(fontSize: 16, fontWeight: pw.FontWeight.bold, color: _ink);

  pw.TextStyle get body => _base(fontSize: 11, height: 1.35, color: _ink);

  pw.TextStyle get small => _base(fontSize: 9, color: _muted);

  pw.TextStyle get node =>
      _base(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _ink);
}

pw.Widget _documentHeader(NoteItem note, _PdfTextTheme textTheme) {
  final title = note.title.trim().isEmpty ? 'Jegyzet' : note.title.trim();
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(title, style: textTheme.title),
      pw.SizedBox(height: 6),
      pw.Text(
        'Frissítve: ${_formatDate(note.updatedAt)}',
        style: textTheme.small,
      ),
      pw.SizedBox(height: 12),
      pw.Divider(color: _rule, thickness: 0.7),
    ],
  );
}

List<pw.Widget> _blockSection(NoteBlock block, _PdfTextTheme textTheme) {
  DebugConsole.log(
    '[NotePdfExport] render block id=${block.id} type=${block.type.wireName}',
  );
  return [
    _sectionHeader(block, textTheme),
    pw.SizedBox(height: 8),
    switch (block.type) {
      NoteBlockType.heading => _headingBlock(block, textTheme),
      NoteBlockType.paragraph => _paragraphBlock(block, textTheme),
      NoteBlockType.listItem => _listBlock(block, textTheme),
      NoteBlockType.table => _tableBlock(block, textTheme),
      NoteBlockType.flowchart => _paragraphBlock(block, textTheme),
      NoteBlockType.mixed => _mixedBlock(block, textTheme),
    },
  ];
}

pw.Widget _sectionHeader(NoteBlock block, _PdfTextTheme textTheme) {
  final title = block.title?.trim();
  final label = title == null || title.isEmpty
      ? _blockTypeLabel(block.type)
      : '${_blockTypeLabel(block.type)} · $title';
  return pw.Container(
    padding: const pw.EdgeInsets.only(bottom: 4),
    decoration: pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _rule, width: 0.6)),
    ),
    child: pw.Text(label.toUpperCase(), style: textTheme.section),
  );
}

pw.Widget _headingBlock(NoteBlock block, _PdfTextTheme textTheme) {
  final text = block.text.trim();
  return pw.Text(
    text.isEmpty ? block.plainText : text,
    style: textTheme.heading,
  );
}

pw.Widget _paragraphBlock(NoteBlock block, _PdfTextTheme textTheme) {
  final text = block.text.trim();
  return pw.Text(text.isEmpty ? block.plainText : text, style: textTheme.body);
}

pw.Widget _mixedBlock(NoteBlock block, _PdfTextTheme textTheme) {
  if (block.mixedSections.isEmpty) {
    return _paragraphBlock(block, textTheme);
  }
  final children = <pw.Widget>[];
  for (final section in block.mixedSections) {
    final sectionBlock = _blockFromMixedSection(block, section);
    if (!notePdfBlockHasExportableContent(sectionBlock)) {
      continue;
    }
    DebugConsole.log(
      '[NotePdfExport] render mixed section block=${block.id} '
      'section=${section.id} type=${section.type.wireName}',
    );
    if (children.isNotEmpty) {
      children.add(pw.SizedBox(height: 10));
    }
    final sectionTitle = section.title?.trim();
    if (sectionTitle != null && sectionTitle.isNotEmpty) {
      children.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Text(
            sectionTitle,
            style: textTheme.body.copyWith(fontWeight: pw.FontWeight.bold),
          ),
        ),
      );
    }
    children.add(switch (section.type) {
      NoteMixedSectionType.paragraph => _paragraphBlock(
        sectionBlock,
        textTheme,
      ),
      NoteMixedSectionType.list => _listBlock(sectionBlock, textTheme),
      NoteMixedSectionType.table => _tableBlock(sectionBlock, textTheme),
    });
  }
  if (children.isEmpty) {
    return _paragraphBlock(block, textTheme);
  }
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: children,
  );
}

pw.Widget _listBlock(NoteBlock block, _PdfTextTheme textTheme) {
  final items = block.listItems;
  if (items.isEmpty) {
    return pw.Text(block.text.trim(), style: textTheme.body);
  }
  final markers = notePdfListMarkersForBlock(block);
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < items.length; i += 1)
        pw.Padding(
          padding: pw.EdgeInsets.only(
            left: items[i].level.clamp(0, 8).toDouble() * 12,
            bottom: 4,
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: block.listLayoutMode == NoteListLayoutMode.hierarchy
                    ? 18
                    : 24,
                child: pw.Text(markers[i], style: textTheme.body),
              ),
              pw.SizedBox(width: 4),
              pw.Expanded(
                child: pw.Text(items[i].text.trim(), style: textTheme.body),
              ),
            ],
          ),
        ),
    ],
  );
}

pw.Widget _tableBlock(NoteBlock block, _PdfTextTheme textTheme) {
  final rows = block.rows
      .where((row) => row.any((cell) => cell.trim().isNotEmpty))
      .map((row) => row.map((cell) => cell.trim()).toList(growable: false))
      .toList(growable: false);
  if (rows.isEmpty) {
    return pw.Text(block.text.trim(), style: textTheme.body);
  }
  return pw.TableHelper.fromTextArray(
    data: rows.length == 1 ? rows : rows.skip(1).toList(growable: false),
    headers: rows.length > 1 ? rows.first : null,
    cellStyle: textTheme.body,
    headerStyle: textTheme.body.copyWith(fontWeight: pw.FontWeight.bold),
    cellAlignment: pw.Alignment.centerLeft,
    headerAlignment: pw.Alignment.centerLeft,
    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#E5E7EB')),
    border: pw.TableBorder.all(color: _rule, width: 0.5),
  );
}

NoteBlock _blockFromMixedSection(NoteBlock block, NoteMixedSection section) {
  final sectionTitle = section.title?.trim();
  return NoteBlock(
    id: '${block.id}:${section.id}',
    type: switch (section.type) {
      NoteMixedSectionType.paragraph => NoteBlockType.paragraph,
      NoteMixedSectionType.list => NoteBlockType.listItem,
      NoteMixedSectionType.table => NoteBlockType.table,
    },
    title: sectionTitle == null || sectionTitle.isEmpty ? null : sectionTitle,
    text: section.text,
    rangeTags: section.rangeTags,
    paragraphStyles: section.paragraphStyles,
    listItems: section.listItems,
    listLayoutMode: section.listLayoutMode,
    rows: section.rows,
    tableColumnWidths: section.tableColumnWidths,
    tableRowHeights: section.tableRowHeights,
    scopedTags: section.scopedTags,
  );
}

void _addFlowchartPages(
  pw.Document pdf,
  NoteItem note,
  NoteBlock block,
  _PdfTextTheme textTheme, {
  required bool includeDocumentHeader,
}) {
  final portrait = _pageFormat.copyWith(
    marginTop: 0,
    marginBottom: 0,
    marginLeft: 0,
    marginRight: 0,
  );
  final portraitCanvas = _flowchartCanvasSize(portrait);
  final layout = buildNotePdfFlowchartLayout(
    block,
    portraitWidth: portraitCanvas.width,
    portraitHeight: portraitCanvas.height,
    landscapeWidth: portraitCanvas.width,
    landscapeHeight: portraitCanvas.height,
  );
  final mode = layout.pages.isEmpty
      ? NotePdfFlowchartPageMode.portraitSingle
      : layout.pages.first.mode;
  final tileCount =
      layout.pages.where((page) => !page.isOverview).length -
      (mode == NotePdfFlowchartPageMode.overviewAndTiles ? 0 : 1);
  DebugConsole.log(
    '[NotePdfExport] flowchart block=${block.id} nodes=${block.nodes.length} '
    'edges=${block.edges.length} bounds=${layout.bounds.width.toStringAsFixed(1)}x'
    '${layout.bounds.height.toStringAsFixed(1)} mode=${mode.name} '
    'tiles=${math.max(0, tileCount)} pages=${layout.pages.length}',
  );

  for (var i = 0; i < layout.pages.length; i += 1) {
    final page = layout.pages[i];
    final includeHeaderOnPage = includeDocumentHeader && i == 0;
    final pageFormat = portrait;
    final canvasSize = _flowchartCanvasSize(
      pageFormat,
      documentHeaderHeight: includeHeaderOnPage
          ? _flowchartDocumentHeaderHeight
          : 0,
    );
    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(_flowchartMargin),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (includeHeaderOnPage) ...[
                  _documentHeader(note, textTheme),
                  pw.SizedBox(height: 8),
                ],
                _flowchartPageHeader(block, page, textTheme),
                pw.SizedBox(height: 10),
                _flowchartCanvas(layout, page, canvasSize, textTheme),
                pw.Spacer(),
                _footer(context, textTheme),
              ],
            ),
          );
        },
      ),
    );
  }
}

Size _flowchartCanvasSize(
  PdfPageFormat format, {
  double documentHeaderHeight = 0,
}) {
  return Size(
    format.width - _flowchartMargin * 2,
    format.height -
        _flowchartMargin * 2 -
        _flowchartHeaderHeight -
        _flowchartFooterHeight -
        documentHeaderHeight,
  );
}

pw.Widget _flowchartPageHeader(
  NoteBlock block,
  NotePdfFlowchartPage page,
  _PdfTextTheme textTheme,
) {
  final title = block.title?.trim();
  final suffix = page.total > 1
      ? page.isOverview
            ? 'áttekintés ${page.index}/${page.total}'
            : 'részlet ${page.index - 1}/${page.total - 1}'
      : 'vizuális render';
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        title == null || title.isEmpty ? 'Flowchart' : 'Flowchart · $title',
        style: textTheme.section,
      ),
      pw.SizedBox(height: 4),
      pw.Text(suffix, style: textTheme.small),
      pw.SizedBox(height: 6),
      pw.Divider(color: _rule, thickness: 0.7),
    ],
  );
}

pw.Widget _flowchartCanvas(
  NotePdfFlowchartLayout layout,
  NotePdfFlowchartPage page,
  Size canvasSize,
  _PdfTextTheme textTheme,
) {
  final transform = _FlowchartTransform(
    page.sourceRect,
    canvasSize,
    page.scale,
  );
  return pw.Container(
    width: canvasSize.width,
    height: canvasSize.height,
    decoration: pw.BoxDecoration(
      color: _softFill,
      border: pw.Border.all(color: _rule, width: 0.7),
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Stack(
      children: [
        pw.Positioned.fill(
          child: pw.CustomPaint(
            size: PdfPoint(canvasSize.width, canvasSize.height),
            painter: (canvas, size) {
              _paintFlowchart(canvas, layout, transform, canvasSize);
            },
          ),
        ),
        for (final edge in layout.edgeRoutes)
          if (edge.edge.label.trim().isNotEmpty &&
              page.sourceRect.contains(edge.labelAnchor))
            _flowchartEdgeLabel(edge, transform, canvasSize, textTheme),
        for (final node in layout.nodeBoxes)
          if (page.sourceRect.overlaps(node.rect))
            pw.Positioned(
              left: transform.x(node.rect.left),
              top: transform.top(node.rect.top),
              child: pw.Container(
                width: math.max(48, node.rect.width * transform.scale),
                height: math.max(28, node.rect.height * transform.scale),
                padding: const pw.EdgeInsets.all(6),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  node.node.label.trim().isEmpty
                      ? node.node.id
                      : node.node.label.trim(),
                  textAlign: pw.TextAlign.center,
                  maxLines: 3,
                  style: textTheme.node.copyWith(
                    fontSize: math.max(6.5, 9 * transform.scale),
                  ),
                ),
              ),
            ),
      ],
    ),
  );
}

pw.Widget _flowchartEdgeLabel(
  NotePdfFlowchartEdgeRoute edge,
  _FlowchartTransform transform,
  Size canvasSize,
  _PdfTextTheme textTheme,
) {
  final text = edge.edge.label.trim();
  final width = math.max(36.0, math.min(92.0, text.length * 5.6 + 18.0));
  final left = (transform.x(edge.labelAnchor.dx) - width / 2)
      .clamp(4.0, math.max(4.0, canvasSize.width - width - 4.0))
      .toDouble();
  final top = (transform.top(edge.labelAnchor.dy) - 10)
      .clamp(4.0, math.max(4.0, canvasSize.height - 22.0))
      .toDouble();
  return pw.Positioned(
    left: left,
    top: top,
    child: pw.Container(
      width: width,
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#FFFFFF'),
        border: pw.Border.all(color: _rule, width: 0.5),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        maxLines: 1,
        style: textTheme.small.copyWith(
          fontSize: math.max(6.0, 8.0 * transform.scale),
          color: _edgeStroke,
        ),
      ),
    ),
  );
}

void _paintFlowchart(
  PdfGraphics canvas,
  NotePdfFlowchartLayout layout,
  _FlowchartTransform transform,
  Size canvasSize,
) {
  canvas
    ..setStrokeColor(_edgeStroke)
    ..setLineWidth(1.0)
    ..setLineJoin(PdfLineJoin.round)
    ..setLineCap(PdfLineCap.round);
  for (final edge in layout.edgeRoutes) {
    if (edge.points.length < 2) {
      continue;
    }
    var previous = transform.point(edge.points.first);
    for (final point in edge.points.skip(1)) {
      final current = transform.point(point);
      canvas.drawLine(previous.dx, previous.dy, current.dx, current.dy);
      canvas.strokePath();
      previous = current;
    }
    _paintArrowhead(
      canvas,
      transform.point(edge.points[edge.points.length - 2]),
      previous,
    );
  }

  for (final node in layout.nodeBoxes) {
    if (!transform.source.overlaps(node.rect)) {
      continue;
    }
    final rect = transform.rect(node.rect);
    canvas
      ..setFillColor(_nodeFill)
      ..setStrokeColor(_nodeStroke)
      ..setLineWidth(1.2);
    switch (node.node.visualShape) {
      case NoteFlowchartVisualShape.oval:
        canvas.drawEllipse(
          rect.left + rect.width / 2,
          rect.bottom + rect.height / 2,
          rect.width / 2,
          rect.height / 2,
        );
        canvas.fillAndStrokePath();
      case NoteFlowchartVisualShape.diamond:
        canvas
          ..moveTo(rect.left + rect.width / 2, rect.top)
          ..lineTo(rect.right, rect.bottom + rect.height / 2)
          ..lineTo(rect.left + rect.width / 2, rect.bottom)
          ..lineTo(rect.left, rect.bottom + rect.height / 2)
          ..closePath()
          ..fillAndStrokePath();
      case NoteFlowchartVisualShape.rectangle:
        canvas.drawRRect(rect.left, rect.bottom, rect.width, rect.height, 7, 7);
        canvas.fillAndStrokePath();
    }
  }

  canvas
    ..setStrokeColor(_accent)
    ..setLineWidth(0.7)
    ..setLineDashPattern([4, 4], 0);
  final source = transform.source;
  canvas.drawRect(0, 0, canvasSize.width, canvasSize.height);
  canvas.strokePath();
  canvas.setLineDashPattern();
  if (source != layout.bounds) {
    canvas.drawRect(8, 8, 34, 18);
    canvas.strokePath();
  }
}

void _paintArrowhead(PdfGraphics canvas, Offset from, Offset to) {
  final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
  const size = 6.0;
  final left = Offset(
    to.dx - size * math.cos(angle - math.pi / 6),
    to.dy - size * math.sin(angle - math.pi / 6),
  );
  final right = Offset(
    to.dx - size * math.cos(angle + math.pi / 6),
    to.dy - size * math.sin(angle + math.pi / 6),
  );
  canvas
    ..moveTo(to.dx, to.dy)
    ..lineTo(left.dx, left.dy)
    ..moveTo(to.dx, to.dy)
    ..lineTo(right.dx, right.dy)
    ..strokePath();
}

class _FlowchartTransform {
  _FlowchartTransform(this.source, Size canvasSize, double targetScale)
    : scale = math.min(
        targetScale,
        math.min(
          canvasSize.width / source.width,
          canvasSize.height / source.height,
        ),
      ),
      _canvasSize = canvasSize {
    _dx = (canvasSize.width - source.width * scale) / 2 - source.left * scale;
    _dy = (canvasSize.height - source.height * scale) / 2 - source.top * scale;
  }

  final Rect source;
  final Size _canvasSize;
  final double scale;
  late final double _dx;
  late final double _dy;

  double x(double sourceX) => sourceX * scale + _dx;

  double top(double sourceY) => sourceY * scale + _dy;

  double y(double sourceY) => _canvasSize.height - top(sourceY);

  Offset point(Offset sourcePoint) =>
      Offset(x(sourcePoint.dx), y(sourcePoint.dy));

  PdfRect rect(Rect sourceRect) {
    final left = x(sourceRect.left);
    final width = sourceRect.width * scale;
    final height = sourceRect.height * scale;
    final bottom = _canvasSize.height - top(sourceRect.bottom);
    return PdfRect(left, bottom, width, height);
  }
}

pw.Widget _footer(pw.Context context, _PdfTextTheme textTheme) {
  return pw.Align(
    alignment: pw.Alignment.centerRight,
    child: pw.Text(
      '${context.pageNumber}/${context.pagesCount}',
      style: textTheme.small,
    ),
  );
}

String _blockTypeLabel(NoteBlockType type) {
  return switch (type) {
    NoteBlockType.heading => 'Címsor',
    NoteBlockType.paragraph => 'Szöveg',
    NoteBlockType.mixed => 'Szöveg',
    NoteBlockType.listItem => 'Lista',
    NoteBlockType.table => 'Táblázat',
    NoteBlockType.flowchart => 'Flowchart',
  };
}

String _formatDate(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')} '
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}
