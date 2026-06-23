# Note PDF Export Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add single-note `Export as PDF` with in-app preview, save/share actions, ordered chunk sections, and readable visual flowchart rendering with large-chart pagination.

**Architecture:** Build a focused notes PDF export subsystem under `lib/src/notes/pdf/`. The export service converts `NoteItem`/`NoteDocument` into PDF bytes using a small export model, writes a temp file for preview, then lets the preview screen save or share the same bytes. Flowchart export uses a deterministic render model so oversized charts can choose portrait, landscape, or overview-plus-tiles without relying on Flutter widget screenshots.

**Tech Stack:** Flutter, Dart, `pdf` package for PDF generation, existing `pdfrx` viewer for preview, existing `file_picker` for platform save, existing `share_plus` for sharing, existing `DebugConsole` for logs.

## Global Constraints

- Spec source: `docs/superpowers/specs/2026-06-23-note-pdf-export-design.md`.
- The PDF must not render global note tags, chunk tags, text range tag highlights/badges, search context, search roles, aliases, indexing metadata, editor rails, buttons, handles, or dropdown UI.
- The PDF block order is determined only by `NoteDocument.blocks`.
- Flowchart chunks must render visually, not as plain text.
- Large or wide flowcharts must not be shrunk below readable text size; use landscape and/or overview plus tiled detail pages.
- Logs use `[NotePdfExport]` and must avoid dumping full note text.
- Flutter tests run from Ubuntu/proot:
  `proot-distro login ubuntu -- bash -lc 'export PATH=/data/data/com.termux/files/home/flutter/bin:$PATH; cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && flutter test ...'`
- Do not run local Flutter APK builds on Termux/Android; APK builds happen on GitHub Actions after push.

---

## File Structure

- Create `lib/src/notes/pdf/note_pdf_export_models.dart`
  - Export metadata, exceptions, sanitized filenames, flowchart render model types, and pagination strategy enum.

- Create `lib/src/notes/pdf/note_flowchart_pdf_layout.dart`
  - Pure flowchart geometry: node sizes, chart bounds, edge routes, fit/tile decisions. No Flutter widgets, no filesystem.

- Create `lib/src/notes/pdf/note_pdf_document_builder.dart`
  - Converts `NoteItem` into PDF bytes. Renders title, block section headers, paragraphs, lists, tables, and flowcharts.

- Create `lib/src/notes/pdf/note_pdf_export_service.dart`
  - Orchestrates validation, logging, PDF generation, temp file write, save, and share.

- Create `lib/src/notes/ui/note_pdf_preview_screen.dart`
  - Fullscreen preview using `PdfViewerScreen`/`pdfrx` style with Back, Save, Share actions.

- Modify `lib/src/notes/ui/notes_screen.dart`
  - Add `Export as PDF` single-note menu item and call export flow.
  - Inject optional export service for widget tests.

- Modify `pubspec.yaml` / `pubspec.lock`
  - Add `pdf` dependency.

- Add tests:
  - `test/note_pdf_export_service_test.dart`
  - `test/note_flowchart_pdf_layout_test.dart`
  - Update `test/notes_screen_test.dart`

## Task 1: Export Models And Filenames

**Files:**
- Create: `lib/src/notes/pdf/note_pdf_export_models.dart`
- Test: `test/note_pdf_export_service_test.dart`

**Interfaces:**
- Produces:
  - `class NotePdfExportException implements Exception`
  - `class NotePdfExportResult`
  - `class NotePdfPreviewFile`
  - `enum NotePdfFlowchartPageMode`
  - `String safeNotePdfFilename(String title)`

- [ ] **Step 1: Write the failing filename and empty-note tests**

Add tests:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/notes/models/note_document.dart';
import 'package:djinn/src/notes/models/note_item.dart';
import 'package:djinn/src/notes/pdf/note_pdf_export_models.dart';
import 'package:djinn/src/notes/pdf/note_pdf_export_service.dart';

void main() {
  test('safeNotePdfFilename normalizes empty and unsafe note titles', () {
    expect(safeNotePdfFilename('Légzési elégtelenség / terápia'), 'L_gz_si_el_gtelens_g_ter_pia.pdf');
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
      payloadJson: const NoteDocument(blocks: [
        NoteBlock(id: 'p1', type: NoteBlockType.paragraph, text: ''),
      ]).toPayloadJson(),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    await expectLater(
      service.generate(note),
      throwsA(isA<NotePdfExportException>()),
    );
  });
}
```

- [ ] **Step 2: Run tests and verify RED**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'export PATH=/data/data/com.termux/files/home/flutter/bin:$PATH; cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && flutter test test/note_pdf_export_service_test.dart'
```

Expected: FAIL because `note_pdf_export_models.dart` and `NotePdfExportService` do not exist.

- [ ] **Step 3: Add minimal models and service shell**

Implement `note_pdf_export_models.dart`:

```dart
import 'dart:typed_data';

class NotePdfExportException implements Exception {
  const NotePdfExportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class NotePdfExportResult {
  const NotePdfExportResult({
    required this.filename,
    required this.bytes,
  });

  final String filename;
  final Uint8List bytes;
}

class NotePdfPreviewFile {
  const NotePdfPreviewFile({
    required this.path,
    required this.filename,
    required this.bytes,
  });

  final String path;
  final String filename;
  final Uint8List bytes;
}

enum NotePdfFlowchartPageMode {
  portraitSingle,
  landscapeSingle,
  overviewAndTiles,
}

String safeNotePdfFilename(String title) {
  final trimmed = title.trim();
  final base = trimmed.toLowerCase().endsWith('.pdf')
      ? trimmed.substring(0, trimmed.length - 4)
      : trimmed;
  final safe = base.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  final normalized = safe.replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '');
  return '${normalized.isEmpty ? 'jegyzet' : normalized}.pdf';
}
```

Implement minimal `note_pdf_export_service.dart`:

```dart
import 'dart:typed_data';

import '../models/note_document.dart';
import '../models/note_item.dart';
import 'note_pdf_export_models.dart';

typedef NotePdfByteBuilder = Future<Uint8List> Function(NoteItem note);

class NotePdfExportService {
  const NotePdfExportService({this.buildPdfBytes});

  final NotePdfByteBuilder? buildPdfBytes;

  Future<NotePdfExportResult> generate(NoteItem note) async {
    final document = NoteDocument.fromPayload(
      note.payloadJson,
      legacyType: note.type.wireName,
      legacyText: note.plainText,
      title: note.title,
    );
    final hasContent = document.blocks.any((block) => block.hasContent);
    if (!hasContent) {
      throw const NotePdfExportException('A jegyzet nem tartalmaz exportálható tartalmat.');
    }
    final bytes = await (buildPdfBytes ?? (_) async => Uint8List(0))(note);
    return NotePdfExportResult(
      filename: safeNotePdfFilename(note.title),
      bytes: bytes,
    );
  }
}
```

- [ ] **Step 4: Run tests and verify GREEN**

Run the same test command.

Expected: PASS.

## Task 2: Flowchart Layout And Pagination

**Files:**
- Modify: `lib/src/notes/pdf/note_pdf_export_models.dart`
- Create: `lib/src/notes/pdf/note_flowchart_pdf_layout.dart`
- Test: `test/note_flowchart_pdf_layout_test.dart`

**Interfaces:**
- Consumes: `NotePdfFlowchartPageMode`
- Produces:
  - `class NotePdfFlowchartLayout`
  - `class NotePdfFlowchartPage`
  - `class NotePdfFlowchartNodeBox`
  - `class NotePdfFlowchartEdgeRoute`
  - `NotePdfFlowchartLayout buildNotePdfFlowchartLayout(NoteBlock block, {required double portraitWidth, required double portraitHeight, required double landscapeWidth, required double landscapeHeight})`

- [ ] **Step 1: Write flowchart layout tests**

Add tests:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/notes/models/note_document.dart';
import 'package:djinn/src/notes/pdf/note_flowchart_pdf_layout.dart';
import 'package:djinn/src/notes/pdf/note_pdf_export_models.dart';

void main() {
  test('flowchart layout computes bounds and edge routes', () {
    const block = NoteBlock(
      id: 'flow',
      type: NoteBlockType.flowchart,
      nodes: [
        NoteFlowchartNode(id: 'a', label: 'Start', x: 0, y: 0),
        NoteFlowchartNode(id: 'b', label: 'End', x: 260, y: 160),
      ],
      edges: [
        NoteFlowchartEdge(id: 'e1', fromNodeId: 'a', toNodeId: 'b', label: 'go'),
      ],
    );

    final layout = buildNotePdfFlowchartLayout(
      block,
      portraitWidth: 500,
      portraitHeight: 700,
      landscapeWidth: 760,
      landscapeHeight: 440,
    );

    expect(layout.nodeBoxes.map((box) => box.node.id), containsAll(['a', 'b']));
    expect(layout.edgeRoutes.single.edge.id, 'e1');
    expect(layout.bounds.width, greaterThan(260));
    expect(layout.pages.single.mode, NotePdfFlowchartPageMode.portraitSingle);
  });

  test('wide flowchart chooses landscape when portrait would be too small', () {
    final block = NoteBlock(
      id: 'wide',
      type: NoteBlockType.flowchart,
      nodes: [
        for (var i = 0; i < 4; i += 1)
          NoteFlowchartNode(id: 'n$i', label: 'Node $i', x: i * 220, y: 0),
      ],
      edges: [
        for (var i = 0; i < 3; i += 1)
          NoteFlowchartEdge(id: 'e$i', fromNodeId: 'n$i', toNodeId: 'n${i + 1}'),
      ],
    );

    final layout = buildNotePdfFlowchartLayout(
      block,
      portraitWidth: 260,
      portraitHeight: 700,
      landscapeWidth: 820,
      landscapeHeight: 420,
    );

    expect(layout.pages.single.mode, NotePdfFlowchartPageMode.landscapeSingle);
  });

  test('very large flowchart chooses overview plus tiled detail pages', () {
    final block = NoteBlock(
      id: 'huge',
      type: NoteBlockType.flowchart,
      nodes: [
        for (var row = 0; row < 3; row += 1)
          for (var col = 0; col < 6; col += 1)
            NoteFlowchartNode(
              id: 'n$row-$col',
              label: 'Node $row $col',
              x: col * 260,
              y: row * 180,
            ),
      ],
    );

    final layout = buildNotePdfFlowchartLayout(
      block,
      portraitWidth: 260,
      portraitHeight: 360,
      landscapeWidth: 420,
      landscapeHeight: 260,
    );

    expect(layout.pages.first.mode, NotePdfFlowchartPageMode.overviewAndTiles);
    expect(layout.pages.length, greaterThan(2));
    expect(layout.pages.where((page) => page.isOverview), hasLength(1));
  });
}
```

- [ ] **Step 2: Run tests and verify RED**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'export PATH=/data/data/com.termux/files/home/flutter/bin:$PATH; cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && flutter test test/note_flowchart_pdf_layout_test.dart'
```

Expected: FAIL because layout classes do not exist.

- [ ] **Step 3: Implement pure layout model**

Implement:

```dart
import 'dart:math' as math;
import 'dart:ui';

import '../models/note_document.dart';
import 'note_pdf_export_models.dart';

const double _nodeWidth = 156;
const double _nodeMinHeight = 64;
const double _chartPadding = 24;
const double _minReadableScale = 0.72;
const double _tileOverlap = 56;

class NotePdfFlowchartLayout {
  const NotePdfFlowchartLayout({
    required this.bounds,
    required this.nodeBoxes,
    required this.edgeRoutes,
    required this.pages,
  });

  final Rect bounds;
  final List<NotePdfFlowchartNodeBox> nodeBoxes;
  final List<NotePdfFlowchartEdgeRoute> edgeRoutes;
  final List<NotePdfFlowchartPage> pages;
}

class NotePdfFlowchartNodeBox {
  const NotePdfFlowchartNodeBox({required this.node, required this.rect});

  final NoteFlowchartNode node;
  final Rect rect;
}

class NotePdfFlowchartEdgeRoute {
  const NotePdfFlowchartEdgeRoute({required this.edge, required this.points});

  final NoteFlowchartEdge edge;
  final List<Offset> points;
}

class NotePdfFlowchartPage {
  const NotePdfFlowchartPage({
    required this.mode,
    required this.sourceRect,
    required this.scale,
    this.isOverview = false,
    this.index = 1,
    this.total = 1,
  });

  final NotePdfFlowchartPageMode mode;
  final Rect sourceRect;
  final double scale;
  final bool isOverview;
  final int index;
  final int total;
}

NotePdfFlowchartLayout buildNotePdfFlowchartLayout(
  NoteBlock block, {
  required double portraitWidth,
  required double portraitHeight,
  required double landscapeWidth,
  required double landscapeHeight,
}) {
  final nodes = [...block.nodes]..sort((a, b) => a.order.compareTo(b.order));
  final nodeBoxes = [
    for (var i = 0; i < nodes.length; i += 1)
      NotePdfFlowchartNodeBox(
        node: nodes[i],
        rect: Rect.fromLTWH(
          nodes[i].x == 0 && nodes[i].y == 0 ? 80.0 : nodes[i].x,
          nodes[i].x == 0 && nodes[i].y == 0 ? 80.0 + i * 120.0 : nodes[i].y,
          _nodeWidth,
          _heightFor(nodes[i].label),
        ),
      ),
  ];
  final bounds = _boundsFor(nodeBoxes).inflate(_chartPadding);
  final boxesById = {for (final box in nodeBoxes) box.node.id: box};
  final edgeRoutes = [
    for (final edge in block.edges)
      if (boxesById[edge.fromNodeId] != null && boxesById[edge.toNodeId] != null)
        NotePdfFlowchartEdgeRoute(
          edge: edge,
          points: _route(edge, boxesById[edge.fromNodeId]!.rect, boxesById[edge.toNodeId]!.rect),
        ),
  ];
  final pages = _pagesFor(
    bounds,
    portraitWidth: portraitWidth,
    portraitHeight: portraitHeight,
    landscapeWidth: landscapeWidth,
    landscapeHeight: landscapeHeight,
  );
  return NotePdfFlowchartLayout(
    bounds: bounds,
    nodeBoxes: nodeBoxes,
    edgeRoutes: edgeRoutes,
    pages: pages,
  );
}

double _heightFor(String label) {
  final lines = (label.trim().length / 24).ceil().clamp(1, 4).toInt();
  return math.max(_nodeMinHeight, 46 + lines * 14);
}

Rect _boundsFor(List<NotePdfFlowchartNodeBox> boxes) {
  if (boxes.isEmpty) {
    return const Rect.fromLTWH(0, 0, _nodeWidth, _nodeMinHeight);
  }
  var rect = boxes.first.rect;
  for (final box in boxes.skip(1)) {
    rect = rect.expandToInclude(box.rect);
  }
  return rect;
}

List<Offset> _route(NoteFlowchartEdge edge, Rect from, Rect to) {
  if (edge.routingMode == NoteFlowchartRoutingMode.manual && edge.manualWaypoints.isNotEmpty) {
    return [
      from.center,
      ...edge.manualWaypoints.map((point) => Offset(point.x, point.y)),
      to.center,
    ];
  }
  final start = Offset(from.right, from.center.dy);
  final end = Offset(to.left, to.center.dy);
  final midX = (start.dx + end.dx) / 2;
  return [start, Offset(midX, start.dy), Offset(midX, end.dy), end];
}

List<NotePdfFlowchartPage> _pagesFor(
  Rect bounds, {
  required double portraitWidth,
  required double portraitHeight,
  required double landscapeWidth,
  required double landscapeHeight,
}) {
  final portraitScale = math.min(portraitWidth / bounds.width, portraitHeight / bounds.height);
  if (portraitScale >= _minReadableScale) {
    return [
      NotePdfFlowchartPage(
        mode: NotePdfFlowchartPageMode.portraitSingle,
        sourceRect: bounds,
        scale: portraitScale.clamp(0.1, 1.0).toDouble(),
      ),
    ];
  }
  final landscapeScale = math.min(landscapeWidth / bounds.width, landscapeHeight / bounds.height);
  if (landscapeScale >= _minReadableScale) {
    return [
      NotePdfFlowchartPage(
        mode: NotePdfFlowchartPageMode.landscapeSingle,
        sourceRect: bounds,
        scale: landscapeScale.clamp(0.1, 1.0).toDouble(),
      ),
    ];
  }
  final detailWidth = landscapeWidth / _minReadableScale;
  final detailHeight = landscapeHeight / _minReadableScale;
  final tiles = <Rect>[];
  var y = bounds.top;
  while (y < bounds.bottom) {
    var x = bounds.left;
    while (x < bounds.right) {
      tiles.add(
        Rect.fromLTWH(x, y, detailWidth, detailHeight)
            .inflate(_tileOverlap)
            .intersect(bounds),
      );
      x += detailWidth - _tileOverlap;
    }
    y += detailHeight - _tileOverlap;
  }
  final total = tiles.length + 1;
  return [
    NotePdfFlowchartPage(
      mode: NotePdfFlowchartPageMode.overviewAndTiles,
      sourceRect: bounds,
      scale: math.min(landscapeWidth / bounds.width, landscapeHeight / bounds.height),
      isOverview: true,
      index: 1,
      total: total,
    ),
    for (var i = 0; i < tiles.length; i += 1)
      NotePdfFlowchartPage(
        mode: NotePdfFlowchartPageMode.overviewAndTiles,
        sourceRect: tiles[i],
        scale: _minReadableScale,
        index: i + 2,
        total: total,
      ),
  ];
}
```

- [ ] **Step 4: Run flowchart layout tests and verify GREEN**

Run the same `flutter test test/note_flowchart_pdf_layout_test.dart` command.

Expected: PASS.

## Task 3: PDF Document Builder

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/src/notes/pdf/note_pdf_document_builder.dart`
- Modify: `lib/src/notes/pdf/note_pdf_export_service.dart`
- Test: `test/note_pdf_export_service_test.dart`

**Interfaces:**
- Consumes: `buildNotePdfFlowchartLayout`
- Produces:
  - `class NotePdfDocumentBuilder`
  - `Future<Uint8List> build(NoteItem note)`

- [ ] **Step 1: Add dependency**

Run:

```bash
flutter pub add pdf
```

If running inside Ubuntu is needed:

```bash
proot-distro login ubuntu -- bash -lc 'export PATH=/data/data/com.termux/files/home/flutter/bin:$PATH; cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && flutter pub add pdf'
```

- [ ] **Step 2: Extend PDF byte tests**

Append tests in `test/note_pdf_export_service_test.dart`:

```dart
test('document builder creates PDF bytes from ordered note blocks without tag metadata', () async {
  const document = NoteDocument(
    tags: [NoteKnowledgeTag(type: NoteKnowledgeTagTypes.topic, label: 'hidden-tag')],
    blocks: [
      NoteBlock(id: 'p1', type: NoteBlockType.paragraph, text: 'Első bekezdés'),
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
          NoteFlowchartEdge(id: 'e1', fromNodeId: 'a', toNodeId: 'b', label: 'Igen'),
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
    createdAt: DateTime(2026, 6, 23),
    updatedAt: DateTime(2026, 6, 23),
  );
  final result = await const NotePdfExportService().generate(note);

  expect(result.filename, 'PDF_jegyzet.pdf');
  expect(String.fromCharCodes(result.bytes.take(4)), '%PDF');
  expect(result.bytes.length, greaterThan(1000));
});
```

- [ ] **Step 3: Run tests and verify RED**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'export PATH=/data/data/com.termux/files/home/flutter/bin:$PATH; cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && flutter test test/note_pdf_export_service_test.dart'
```

Expected: FAIL because default builder returns empty bytes.

- [ ] **Step 4: Implement `NotePdfDocumentBuilder`**

Implement PDF rendering for all block types with fixed, testable rules. Use `pw.MultiPage` for ordinary note content. Add dedicated flowchart pages from the `NotePdfFlowchartLayout.pages` list. Draw flowchart nodes, edges, labels, and arrowheads through `pw.CustomPaint`; do not use Flutter widget screenshots and do not use a text-only flowchart fallback when nodes are present.

Required behavior:

```dart
class NotePdfDocumentBuilder {
  const NotePdfDocumentBuilder();

  Future<Uint8List> build(NoteItem note) async {
    final document = NoteDocument.fromPayload(
      note.payloadJson,
      legacyType: note.type.wireName,
      legacyText: note.plainText,
      title: note.title,
    );
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageTheme: _portraitTheme(),
        footer: _footer,
        build: (context) => [
          _title(note),
          for (final block in document.blocks)
            if (block.hasContent) ..._sectionFor(block),
        ],
      ),
    );
    for (final block in document.blocks.where((block) => block.type == NoteBlockType.flowchart && block.nodes.isNotEmpty)) {
      _addFlowchartPages(pdf, block);
    }
    return pdf.save();
  }
}
```

Wire `NotePdfExportService.generate` to use `const NotePdfDocumentBuilder().build(note)` when `buildPdfBytes` is null.

- [ ] **Step 5: Run tests and verify GREEN**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'export PATH=/data/data/com.termux/files/home/flutter/bin:$PATH; cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && flutter test test/note_pdf_export_service_test.dart test/note_flowchart_pdf_layout_test.dart'
```

Expected: PASS.

## Task 4: Temp File, Save, Share, And Logs

**Files:**
- Modify: `lib/src/notes/pdf/note_pdf_export_service.dart`
- Test: `test/note_pdf_export_service_test.dart`

**Interfaces:**
- Produces:
  - `Future<NotePdfPreviewFile> createPreviewFile(NoteItem note)`
  - `Future<String?> save(NotePdfPreviewFile file)`
  - `Future<void> share(NotePdfPreviewFile file)`
  - constructor injection for temp dir, save adapter, share adapter.

- [ ] **Step 1: Add service orchestration tests**

Add tests:

```dart
test('createPreviewFile writes generated PDF bytes and logs lifecycle', () async {
  final tempDir = await Directory.systemTemp.createTemp('note-pdf-test-');
  addTearDown(() async => tempDir.delete(recursive: true));
  DebugConsole.clear();
  final service = NotePdfExportService(
    tempDirectoryProvider: () async => tempDir,
    buildPdfBytes: (_) async => Uint8List.fromList('%PDF test'.codeUnits),
  );
  final note = _noteWithText('Export note', 'Tartalom');

  final preview = await service.createPreviewFile(note);

  expect(preview.filename, 'Export_note.pdf');
  expect(await File(preview.path).readAsBytes(), preview.bytes);
  final logs = DebugConsole.messages.join('\n');
  expect(logs, contains('[NotePdfExport] start note='));
  expect(logs, contains('[NotePdfExport] generated bytes='));
  expect(logs, contains('[NotePdfExport] preview path='));
});

test('save returns selected path and logs cancellation', () async {
  DebugConsole.clear();
  final service = NotePdfExportService(
    saveAdapter: ({required filename, required bytes}) async => null,
  );
  final preview = NotePdfPreviewFile(
    path: '/tmp/test.pdf',
    filename: 'test.pdf',
    bytes: Uint8List.fromList([1, 2, 3]),
  );

  final path = await service.save(preview);

  expect(path, isNull);
  expect(DebugConsole.messages.join('\n'), contains('[NotePdfExport] save canceled'));
});
```

Add helper:

```dart
NoteItem _noteWithText(String title, String text) {
  final document = NoteDocument(blocks: [
    NoteBlock(id: 'p1', type: NoteBlockType.paragraph, text: text),
  ]);
  return NoteItem(
    id: 'note-${title.hashCode}',
    type: NoteItemType.document,
    title: title,
    plainText: document.plainText,
    payloadJson: document.toPayloadJson(),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}
```

- [ ] **Step 2: Run tests and verify RED**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'export PATH=/data/data/com.termux/files/home/flutter/bin:$PATH; cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && flutter test test/note_pdf_export_service_test.dart'
```

Expected: FAIL because orchestration methods do not exist.

- [ ] **Step 3: Implement temp/save/share orchestration**

Add injected typedefs:

```dart
typedef NotePdfTempDirectoryProvider = Future<Directory> Function();
typedef NotePdfSaveAdapter = Future<String?> Function({
  required String filename,
  required Uint8List bytes,
});
typedef NotePdfShareAdapter = Future<void> Function(NotePdfPreviewFile file);
```

Default save uses:

```dart
FilePicker.saveFile(
  dialogTitle: 'Jegyzet PDF export',
  fileName: file.filename,
  type: FileType.custom,
  allowedExtensions: const ['pdf'],
  bytes: file.bytes,
);
```

Default share writes/shares with MIME `application/pdf`.

- [ ] **Step 4: Run tests and verify GREEN**

Run the same service test command.

Expected: PASS.

## Task 5: Preview Screen

**Files:**
- Create: `lib/src/notes/ui/note_pdf_preview_screen.dart`
- Test: `test/note_pdf_preview_screen_test.dart`

**Interfaces:**
- Consumes: `NotePdfPreviewFile`, `NotePdfExportService.save`, `NotePdfExportService.share`
- Produces: `class NotePdfPreviewScreen extends StatelessWidget/StatefulWidget`

- [ ] **Step 1: Write preview widget tests**

Test that actions are present and save cancellation keeps preview open:

```dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/notes/pdf/note_pdf_export_models.dart';
import 'package:djinn/src/notes/pdf/note_pdf_export_service.dart';
import 'package:djinn/src/notes/ui/note_pdf_preview_screen.dart';

void main() {
  testWidgets('PDF preview exposes back save and share actions', (tester) async {
    final preview = NotePdfPreviewFile(
      path: '/tmp/missing.pdf',
      filename: 'note.pdf',
      bytes: Uint8List.fromList('%PDF'.codeUnits),
    );
    final service = NotePdfExportService(
      saveAdapter: ({required filename, required bytes}) async => null,
      shareAdapter: (_) async {},
    );
    await tester.pumpWidget(MaterialApp(home: NotePdfPreviewScreen(file: preview, service: service)));

    expect(find.byKey(const ValueKey('note-pdf-preview-screen')), findsOneWidget);
    expect(find.byKey(const ValueKey('note-pdf-preview-save')), findsOneWidget);
    expect(find.byKey(const ValueKey('note-pdf-preview-share')), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test and verify RED**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'export PATH=/data/data/com.termux/files/home/flutter/bin:$PATH; cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && flutter test test/note_pdf_preview_screen_test.dart'
```

Expected: FAIL because preview screen does not exist.

- [ ] **Step 3: Implement preview screen**

Use `PdfViewerScreen` body logic or `PdfViewer.file` directly. Keep action keys stable:

- `note-pdf-preview-screen`
- `note-pdf-preview-save`
- `note-pdf-preview-share`

On save/share errors, show snackbar and log through service.

- [ ] **Step 4: Run preview test and verify GREEN**

Run the same preview test command.

Expected: PASS.

## Task 6: Notes Menu Integration

**Files:**
- Modify: `lib/src/notes/ui/notes_screen.dart`
- Test: `test/notes_screen_test.dart`

**Interfaces:**
- Consumes: `NotePdfExportService.createPreviewFile`, `NotePdfPreviewScreen`
- Produces:
  - optional `NotePdfExportService? pdfExportService` constructor parameter on `NotesScreen`.
  - selected-note menu item value `export-pdf`.

- [ ] **Step 1: Write failing notes menu test**

Add a widget test:

```dart
testWidgets('selected-note menu opens PDF preview export for one note', (tester) async {
  final repository = MemoryNoteRepository();
  final note = await repository.createDocumentNote(
    title: 'PDF export note',
    document: const NoteDocument(blocks: [
      NoteBlock(id: 'p1', type: NoteBlockType.paragraph, text: 'Exportálható tartalom'),
    ]),
  );
  final tempDir = await Directory.systemTemp.createTemp('notes-pdf-widget-');
  addTearDown(() async => tempDir.delete(recursive: true));
  final service = NotePdfExportService(
    tempDirectoryProvider: () async => tempDir,
    buildPdfBytes: (_) async => Uint8List.fromList('%PDF widget'.codeUnits),
  );
  await tester.pumpWidget(MaterialApp(home: NotesScreen(repository: repository, pdfExportService: service)));
  await tester.pumpAndSettle();

  await tester.longPress(find.byKey(ValueKey('note-box-${note.id}')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('notes-selection-menu')));
  await tester.pumpAndSettle();

  expect(find.text('Export as PDF'), findsOneWidget);
  await tester.tap(find.text('Export as PDF'));
  await tester.pumpAndSettle();

  expect(find.byKey(const ValueKey('note-pdf-preview-screen')), findsOneWidget);
});
```

- [ ] **Step 2: Run test and verify RED**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'export PATH=/data/data/com.termux/files/home/flutter/bin:$PATH; cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && flutter test test/notes_screen_test.dart'
```

Expected: FAIL because constructor/menu item does not exist.

- [ ] **Step 3: Implement menu integration**

In `NotesScreen`:

- add `final NotePdfExportService? pdfExportService;`
- include `PopupMenuItem(value: 'export-pdf', child: Text('Export as PDF'))` only when `count == 1`;
- handle it:

```dart
if (value == 'export-pdf') {
  await _exportNoteAsPdf(selected.single);
  return;
}
```

Add `_exportNoteAsPdf`:

```dart
Future<void> _exportNoteAsPdf(NoteItem note) async {
  final service = widget.pdfExportService ?? const NotePdfExportService();
  try {
    final file = await service.createPreviewFile(note);
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => NotePdfPreviewScreen(file: file, service: service),
      ),
    );
  } on NotePdfExportException catch (error) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
  } catch (error) {
    DebugConsole.log('[NotePdfExport] failed error=$error');
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF export sikertelen: $error')));
  }
}
```

- [ ] **Step 4: Run notes tests and verify GREEN**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'export PATH=/data/data/com.termux/files/home/flutter/bin:$PATH; cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && flutter test test/notes_screen_test.dart test/note_pdf_preview_screen_test.dart test/note_pdf_export_service_test.dart test/note_flowchart_pdf_layout_test.dart'
```

Expected: PASS.

## Task 7: Verification, Checklist, Commit, Push

**Files:**
- Modify: `docs/superpowers/checklists/2026-06-23-note-pdf-export.md`

**Interfaces:**
- Consumes all previous task deliverables.

- [ ] **Step 1: Format**

Run:

```bash
dart format lib/src/notes/pdf lib/src/notes/ui/note_pdf_preview_screen.dart lib/src/notes/ui/notes_screen.dart test/note_pdf_export_service_test.dart test/note_flowchart_pdf_layout_test.dart test/note_pdf_preview_screen_test.dart test/notes_screen_test.dart
```

- [ ] **Step 2: Analyze**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'export PATH=/data/data/com.termux/files/home/flutter/bin:$PATH; cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && flutter analyze'
```

Expected: `No issues found!`

- [ ] **Step 3: Targeted tests**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'export PATH=/data/data/com.termux/files/home/flutter/bin:$PATH; cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && flutter test test/notes_screen_test.dart test/note_pdf_preview_screen_test.dart test/note_pdf_export_service_test.dart test/note_flowchart_pdf_layout_test.dart'
```

Expected: all targeted tests pass.

- [ ] **Step 4: Full tests**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'export PATH=/data/data/com.termux/files/home/flutter/bin:$PATH; cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && flutter test'
```

Expected: all tests pass except known ObjectBox host library environment skips.

- [ ] **Step 5: Update checklist statuses**

Mark every requirement in `docs/superpowers/checklists/2026-06-23-note-pdf-export.md` as `DONE`, `PARTIAL`, or `BLOCKED` based on evidence.

- [ ] **Step 6: Commit and push**

Run:

```bash
git status --short
git add pubspec.yaml pubspec.lock lib/src/notes/pdf lib/src/notes/ui/note_pdf_preview_screen.dart lib/src/notes/ui/notes_screen.dart test/note_pdf_export_service_test.dart test/note_flowchart_pdf_layout_test.dart test/note_pdf_preview_screen_test.dart test/notes_screen_test.dart docs/superpowers/checklists/2026-06-23-note-pdf-export.md docs/superpowers/plans/2026-06-23-note-pdf-export.md
git commit -m "feat: export notes as pdf"
git push origin feature/tag-sheet-registry-text-markers
```

Expected: branch pushed and GitHub Actions starts Android native build.
