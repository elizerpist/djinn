# Shared PDF And Note Chunks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make PDF/image chunks and note chunks use one shared chunk UI concept while preserving existing persistence for the first slice.

**Architecture:** Add a shared chunk view model and adapters above existing note/PDF storage. Normalize PDF chunk kinds to four values, collapse user-facing PDF modes to AI vs manual OCR-assisted, and route both PDF rows and source viewer actions through explicit source/chunk paths. Keep full database unification as a separate future migration.

**Tech Stack:** Flutter, Dart 3.11, ObjectBox, pdfrx, existing `DebugConsole`, existing note tag sheet and chunk card patterns.

## Global Constraints

- Do not migrate all note and PDF chunks into one physical database table in this slice.
- User-facing chunk kinds are exactly `text`, `list`, `table`, and `flowchart`.
- User-facing PDF/image chunk modes are exactly `AI` and `manual OCR-assisted`.
- Do not keep local-vs-manual-vs-comparison as user-facing PDF chunk modes.
- PDF/image document card tap opens the chunk menu; left PDF/image icon opens the source viewer.
- Logs for PDF chunk workflows must go to `DebugConsole`.
- Flutter tests must be run inside the installed Ubuntu proot, not directly in Termux.
- Do not run local Flutter APK builds on Android/Termux; APK builds run online through GitHub Actions.

---

## File Structure

- Create `lib/src/shared/chunks/shared_chunk.dart`
  - Owns `SharedChunkKind`, `SharedChunkOrigin`, `SharedChunkMode`, and `SharedChunkViewModel`.
- Create `lib/src/notes/ui/note_shared_chunk_adapter.dart`
  - Converts `NoteBlock` data into `SharedChunkViewModel`.
- Create `lib/src/knowledge/ui/pdf_shared_chunk_adapter.dart`
  - Converts `ExtractedKnowledgeItem` data into `SharedChunkViewModel`.
- Modify `lib/src/shared/chunks/chunk_card.dart`
  - Remove extra card kinds and render from shared four-kind model.
- Modify `lib/src/knowledge/models/local_extraction.dart`
  - Restrict new writes to four kinds; map legacy wire names into the four approved kinds.
- Modify `lib/src/knowledge/models/extracted_knowledge_item.dart`
  - Update labels for AI/manual and remove user-facing local terminology.
- Modify `lib/src/knowledge/data/knowledge_document_repository.dart`
  - Map legacy local kinds into four kinds and expose helper behavior for manual-mode filtering.
- Modify `lib/src/knowledge/data/objectbox_knowledge_repository.dart`
  - Same mapping for ObjectBox repository.
- Modify `lib/src/knowledge/data/local_chunk_builder.dart`
  - Stop writing `score`; write `table` for score-like table content.
- Modify `lib/src/knowledge/ui/extracted_knowledge_screen.dart`
  - Replace AI/local/manual/comparison and type filters with AI/manual mode selector and shared cards.
- Modify `lib/src/knowledge/ui/manual_chunk_editor_screen.dart`
  - Limit chunk type choices to four, remove user-facing source dropdown, fix sheet dismissal, add logs.
- Create `lib/src/shared/ui/inline_bottom_sheet_card.dart`
  - Provides adaptive in-page bottom card that fully disappears on dismiss.
- Modify `lib/src/knowledge/ui/knowledge_document_row.dart`
  - Add left source icon tap, right chevron, and keys.
- Modify `lib/src/knowledge/ui/knowledge_base_screen.dart`
  - Card tap opens chunks; icon tap opens source viewer; add logs.
- Modify `lib/src/knowledge/ui/pdf_viewer_screen.dart`
  - Add optional document/repository input, source-box mode toggle, and debug logs.
- Create `lib/src/knowledge/ui/source_chunk_box_overlay.dart`
  - Parses source rect JSON and paints AI/manual source boxes.
- Modify `lib/src/search/ui/search_screen.dart`
  - Remove references to legacy extra chunk kinds.
- Modify `lib/src/rag/retrieval/local_retriever.dart`
  - Treat legacy chunk kind strings through the normalized four-kind mapping.
- Tests:
  - Create `test/shared_chunk_adapter_test.dart`
  - Modify `test/chunk_pipeline_comparison_test.dart`
  - Modify `test/local_chunk_builder_test.dart`
  - Modify `test/extracted_knowledge_screen_test.dart`
  - Modify `test/knowledge_base_screen_test.dart`
  - Create `test/inline_bottom_sheet_card_test.dart`
  - Create `test/pdf_viewer_source_box_overlay_test.dart`

## Test Command Template

Run Flutter tests through Ubuntu:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && flutter test test/<file>.dart'
```

Run static analysis through Ubuntu:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && flutter analyze'
```

---

### Task 1: Shared Chunk Model And Adapters

**Files:**
- Create: `lib/src/shared/chunks/shared_chunk.dart`
- Create: `lib/src/notes/ui/note_shared_chunk_adapter.dart`
- Create: `lib/src/knowledge/ui/pdf_shared_chunk_adapter.dart`
- Test: `test/shared_chunk_adapter_test.dart`

**Interfaces:**
- Produces:
  - `enum SharedChunkKind { text, list, table, flowchart }`
  - `enum SharedChunkOrigin { note, pdf, image }`
  - `enum SharedChunkMode { ai, manual }`
  - `class SharedChunkViewModel`
  - `SharedChunkViewModel sharedChunkFromNoteBlock(...)`
  - `SharedChunkViewModel sharedChunkFromExtractedItem(...)`

- [ ] **Step 1: Write failing adapter tests**

Create `test/shared_chunk_adapter_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/ai/ai_client.dart';
import 'package:djinn/src/knowledge/models/extracted_knowledge_item.dart';
import 'package:djinn/src/knowledge/models/local_extraction.dart';
import 'package:djinn/src/knowledge/ui/pdf_shared_chunk_adapter.dart';
import 'package:djinn/src/local_store/entities.dart';
import 'package:djinn/src/notes/models/note_document.dart';
import 'package:djinn/src/notes/ui/note_shared_chunk_adapter.dart';
import 'package:djinn/src/shared/chunks/shared_chunk.dart';

void main() {
  test('note blocks adapt to shared chunk kinds', () {
    const textBlock = NoteBlock(
      id: 'text-1',
      type: NoteBlockType.paragraph,
      text: 'Légzési elégtelenség',
    );
    const tableBlock = NoteBlock(
      id: 'table-1',
      type: NoteBlockType.table,
      rows: [
        ['Állapot', 'Terápia'],
        ['Súlyos', 'O2'],
      ],
    );

    final text = sharedChunkFromNoteBlock(
      noteId: 'note-1',
      noteTitle: 'Légzés',
      block: textBlock,
    );
    final table = sharedChunkFromNoteBlock(
      noteId: 'note-1',
      noteTitle: 'Légzés',
      block: tableBlock,
    );

    expect(text.origin, SharedChunkOrigin.note);
    expect(text.kind, SharedChunkKind.text);
    expect(text.title, 'Szöveg chunk');
    expect(text.preview, contains('Légzési'));
    expect(table.kind, SharedChunkKind.table);
    expect(table.preview, contains('Súlyos'));
  });

  test('pdf extracted items adapt to shared mode and source metadata', () {
    const item = ExtractedKnowledgeItem(
      id: 'manual-1',
      documentId: 'doc-1',
      sourceType: EvidenceSourceType.tableChunk,
      text: '| A | B |',
      pageNumber: 3,
      pipeline: LocalExtractionPipeline.manual,
      chunkKind: LocalChunkKind.table,
      auditState: LocalAuditState.edited,
      sourceRectJson:
          '{"page":3,"viewport_rect":{"left":10,"top":20,"right":110,"bottom":80}}',
    );

    final shared = sharedChunkFromExtractedItem(
      item,
      filename: 'protocol.pdf',
      isImage: false,
    );

    expect(shared.origin, SharedChunkOrigin.pdf);
    expect(shared.mode, SharedChunkMode.manual);
    expect(shared.kind, SharedChunkKind.table);
    expect(shared.pageLabel, 'Táblázat - 3. oldal');
    expect(shared.hasSourceRect, isTrue);
  });

  test('legacy pdf chunk kinds map into the four shared kinds', () {
    expect(sharedKindFromLocalChunkKind(LocalChunkKind.text), SharedChunkKind.text);
    expect(sharedKindFromLocalChunkKind(LocalChunkKind.list), SharedChunkKind.list);
    expect(sharedKindFromLocalChunkKind(LocalChunkKind.table), SharedChunkKind.table);
    expect(sharedKindFromLocalChunkKind(LocalChunkKind.flowchart), SharedChunkKind.flowchart);
  });
}
```

- [ ] **Step 2: Run failing test**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && flutter test test/shared_chunk_adapter_test.dart'
```

Expected: FAIL because the shared chunk files do not exist.

- [ ] **Step 3: Add shared model**

Create `lib/src/shared/chunks/shared_chunk.dart`:

```dart
import '../../knowledge/models/local_extraction.dart';
import '../../notes/models/note_document.dart';

enum SharedChunkKind { text, list, table, flowchart }

enum SharedChunkOrigin { note, pdf, image }

enum SharedChunkMode { ai, manual }

class SharedChunkViewModel {
  const SharedChunkViewModel({
    required this.id,
    required this.origin,
    required this.kind,
    required this.title,
    required this.preview,
    required this.content,
    required this.tags,
    this.mode,
    this.pageLabel,
    this.sourceRectJson,
    this.auditState,
    this.indexFresh = false,
    this.needsReindex = false,
  });

  final String id;
  final SharedChunkOrigin origin;
  final SharedChunkKind kind;
  final String title;
  final String preview;
  final String content;
  final List<NoteKnowledgeTag> tags;
  final SharedChunkMode? mode;
  final String? pageLabel;
  final String? sourceRectJson;
  final LocalAuditState? auditState;
  final bool indexFresh;
  final bool needsReindex;

  bool get hasSourceRect =>
      sourceRectJson != null && sourceRectJson!.trim().isNotEmpty;
}

SharedChunkKind sharedKindFromLocalChunkKind(LocalChunkKind kind) {
  return switch (kind) {
    LocalChunkKind.text => SharedChunkKind.text,
    LocalChunkKind.list => SharedChunkKind.list,
    LocalChunkKind.table => SharedChunkKind.table,
    LocalChunkKind.flowchart => SharedChunkKind.flowchart,
  };
}

SharedChunkKind sharedKindFromNoteBlockType(NoteBlockType type) {
  return switch (type) {
    NoteBlockType.listItem => SharedChunkKind.list,
    NoteBlockType.table => SharedChunkKind.table,
    NoteBlockType.flowchart => SharedChunkKind.flowchart,
    NoteBlockType.heading || NoteBlockType.paragraph => SharedChunkKind.text,
  };
}
```

- [ ] **Step 4: Add note adapter**

Create `lib/src/notes/ui/note_shared_chunk_adapter.dart`:

```dart
import '../../shared/chunks/shared_chunk.dart';
import '../models/note_document.dart';

SharedChunkViewModel sharedChunkFromNoteBlock({
  required String noteId,
  required String noteTitle,
  required NoteBlock block,
}) {
  final content = block.displayTextForIndexing.trimRight();
  final title = block.title?.trim().isNotEmpty == true
      ? block.title!.trim()
      : _titleFor(block.type);
  return SharedChunkViewModel(
    id: '$noteId:${block.id}',
    origin: SharedChunkOrigin.note,
    kind: sharedKindFromNoteBlockType(block.type),
    title: title,
    preview: content,
    content: content,
    tags: block.tags,
    indexFresh: block.isIndexFresh,
    needsReindex: block.needsReindex,
  );
}

String _titleFor(NoteBlockType type) {
  return switch (type) {
    NoteBlockType.heading => 'Címsor chunk',
    NoteBlockType.paragraph => 'Szöveg chunk',
    NoteBlockType.listItem => 'Lista chunk',
    NoteBlockType.table => 'Táblázat chunk',
    NoteBlockType.flowchart => 'Flowchart chunk',
  };
}
```

- [ ] **Step 5: Add PDF adapter**

Create `lib/src/knowledge/ui/pdf_shared_chunk_adapter.dart`:

```dart
import '../../shared/chunks/shared_chunk.dart';
import '../models/extracted_knowledge_item.dart';
import '../models/local_extraction.dart';

SharedChunkViewModel sharedChunkFromExtractedItem(
  ExtractedKnowledgeItem item, {
  required String filename,
  required bool isImage,
}) {
  return SharedChunkViewModel(
    id: item.id,
    origin: isImage ? SharedChunkOrigin.image : SharedChunkOrigin.pdf,
    mode: item.pipeline == LocalExtractionPipeline.ai
        ? SharedChunkMode.ai
        : SharedChunkMode.manual,
    kind: sharedKindFromLocalChunkKind(item.chunkKind),
    title: item.sectionTitle?.trim().isNotEmpty == true
        ? item.sectionTitle!.trim()
        : item.pageLabel,
    preview: item.text.trim(),
    content: item.text,
    pageLabel: item.pageLabel,
    sourceRectJson: item.sourceRectJson,
    auditState: item.auditState,
    tags: const [],
  );
}
```

- [ ] **Step 6: Run adapter test**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && flutter test test/shared_chunk_adapter_test.dart'
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/src/shared/chunks/shared_chunk.dart lib/src/notes/ui/note_shared_chunk_adapter.dart lib/src/knowledge/ui/pdf_shared_chunk_adapter.dart test/shared_chunk_adapter_test.dart
git commit -m "feat: add shared chunk adapters"
```

---

### Task 2: Normalize Chunk Kinds To Four Values

**Files:**
- Modify: `lib/src/knowledge/models/local_extraction.dart`
- Modify: `lib/src/knowledge/data/local_chunk_builder.dart`
- Modify: `lib/src/knowledge/data/knowledge_document_repository.dart`
- Modify: `lib/src/knowledge/data/objectbox_knowledge_repository.dart`
- Modify: `lib/src/search/ui/search_screen.dart`
- Modify: `lib/src/rag/retrieval/local_retriever.dart`
- Test: `test/chunk_pipeline_comparison_test.dart`
- Test: `test/local_chunk_builder_test.dart`

**Interfaces:**
- Consumes: `SharedChunkKind` mapping from Task 1.
- Produces: `LocalChunkKind` with only four enum values and legacy wire-name normalization.

- [ ] **Step 1: Add failing legacy mapping test**

Append to `test/chunk_pipeline_comparison_test.dart`:

```dart
test('legacy chunk kind wire names normalize into four supported kinds', () {
  expect(LocalChunkKind.fromWireName('text'), LocalChunkKind.text);
  expect(LocalChunkKind.fromWireName('list'), LocalChunkKind.list);
  expect(LocalChunkKind.fromWireName('table'), LocalChunkKind.table);
  expect(LocalChunkKind.fromWireName('flowchart'), LocalChunkKind.flowchart);
  expect(LocalChunkKind.fromWireName('score'), LocalChunkKind.table);
  expect(LocalChunkKind.fromWireName('image_region'), LocalChunkKind.text);
  expect(LocalChunkKind.fromWireName('visual_fact'), LocalChunkKind.text);
  expect(LocalChunkKind.fromWireName('unknown'), LocalChunkKind.text);
});
```

In `test/local_chunk_builder_test.dart`, update any score expectation so score-like content expects `LocalChunkKind.table`.

- [ ] **Step 2: Run failing tests**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && flutter test test/chunk_pipeline_comparison_test.dart test/local_chunk_builder_test.dart'
```

Expected: FAIL because `LocalChunkKind.score`, `imageRegion`, `visualFact`, and `unknown` still exist and score-like builder output still writes score.

- [ ] **Step 3: Replace `LocalChunkKind` enum**

In `lib/src/knowledge/models/local_extraction.dart`, replace `LocalChunkKind` with:

```dart
enum LocalChunkKind {
  text('text'),
  list('list'),
  table('table'),
  flowchart('flowchart');

  const LocalChunkKind(this.wireName);

  final String wireName;

  static LocalChunkKind fromWireName(String? value) {
    return switch (value?.trim()) {
      'list' => LocalChunkKind.list,
      'table' || 'score' => LocalChunkKind.table,
      'flowchart' => LocalChunkKind.flowchart,
      'text' ||
      'image_region' ||
      'visual_fact' ||
      'unknown' ||
      null ||
      _ => LocalChunkKind.text,
    };
  }

  String get label {
    return switch (this) {
      LocalChunkKind.text => 'Szöveg',
      LocalChunkKind.list => 'Felsorolás',
      LocalChunkKind.table => 'Táblázat',
      LocalChunkKind.flowchart => 'Flowchart',
    };
  }
}
```

- [ ] **Step 4: Remove legacy enum references**

Update these patterns:

```dart
LocalChunkKind.score
```

Replace with:

```dart
LocalChunkKind.table
```

Remove branches for:

```dart
LocalChunkKind.imageRegion
LocalChunkKind.visualFact
LocalChunkKind.unknown
```

and map their behavior to `LocalChunkKind.text`.

Specific replacements:

- `lib/src/knowledge/data/local_chunk_builder.dart`: score-like table blocks write `kind: LocalChunkKind.table`.
- `lib/src/knowledge/data/knowledge_document_repository.dart`: `_sourceTypeForLocalKind` maps `text` and `list` to `EvidenceSourceType.textChunk`, `table` to `tableChunk`, `flowchart` to `flowchartNode`.
- `lib/src/knowledge/data/objectbox_knowledge_repository.dart`: same mapping, and `_localKindForSourceType(EvidenceSourceType.scoreChunk.wireName)` returns `LocalChunkKind.table`.
- `lib/src/search/ui/search_screen.dart`: icon switch only handles four values.
- `lib/src/rag/retrieval/local_retriever.dart`: source type helper uses `LocalChunkKind.fromWireName(value)` and only four cases.

- [ ] **Step 5: Run tests**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && flutter test test/chunk_pipeline_comparison_test.dart test/local_chunk_builder_test.dart test/shared_chunk_adapter_test.dart'
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/src/knowledge/models/local_extraction.dart lib/src/knowledge/data/local_chunk_builder.dart lib/src/knowledge/data/knowledge_document_repository.dart lib/src/knowledge/data/objectbox_knowledge_repository.dart lib/src/search/ui/search_screen.dart lib/src/rag/retrieval/local_retriever.dart test/chunk_pipeline_comparison_test.dart test/local_chunk_builder_test.dart test/shared_chunk_adapter_test.dart
git commit -m "refactor: normalize knowledge chunk kinds"
```

---

### Task 3: Shared Chunk Card Four-Kind Rendering

**Files:**
- Modify: `lib/src/shared/chunks/chunk_card.dart`
- Modify: `lib/src/knowledge/ui/extracted_knowledge_screen.dart`
- Test: `test/extracted_knowledge_screen_test.dart`

**Interfaces:**
- Consumes: `SharedChunkViewModel`, `SharedChunkKind`.
- Produces: `ChunkCard` rendering only text/list/table/flowchart.

- [ ] **Step 1: Add failing card assertion**

In `test/extracted_knowledge_screen_test.dart`, in the mixed chunks test, add assertions that no legacy visual labels appear:

```dart
expect(find.text('Score'), findsNothing);
expect(find.text('Kép'), findsNothing);
expect(find.text('Vizuális tény'), findsNothing);
```

- [ ] **Step 2: Run failing extracted screen test**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && flutter test test/extracted_knowledge_screen_test.dart'
```

Expected: FAIL until the extracted screen no longer references legacy `ChunkCardKind` values.

- [ ] **Step 3: Simplify `ChunkCardKind`**

In `lib/src/shared/chunks/chunk_card.dart`, replace:

```dart
enum ChunkCardKind { text, list, table, score, flowchart, imageRegion, visualFact }
```

with:

```dart
import 'shared_chunk.dart';

typedef ChunkCardKind = SharedChunkKind;
```

Update icon/color switches to:

```dart
static IconData _iconFor(ChunkCardKind kind) {
  return switch (kind) {
    SharedChunkKind.text => Icons.subject,
    SharedChunkKind.list => Icons.format_list_bulleted,
    SharedChunkKind.table => Icons.table_chart_outlined,
    SharedChunkKind.flowchart => Icons.account_tree_outlined,
  };
}

static Color _colorFor(ChunkCardKind kind) {
  return switch (kind) {
    SharedChunkKind.text => const Color(0xFF2563EB),
    SharedChunkKind.list => const Color(0xFF059669),
    SharedChunkKind.table => const Color(0xFFEA580C),
    SharedChunkKind.flowchart => const Color(0xFF9333EA),
  };
}
```

- [ ] **Step 4: Update extracted screen card mapping**

In `lib/src/knowledge/ui/extracted_knowledge_screen.dart`, import:

```dart
import '../../shared/chunks/shared_chunk.dart';
import 'pdf_shared_chunk_adapter.dart';
```

Replace `_cardKindFor` with shared adapter usage:

```dart
final shared = sharedChunkFromExtractedItem(
  item,
  filename: '',
  isImage: false,
);
```

and set:

```dart
kind: shared.kind,
```

Remove switch cases for legacy card kinds.

- [ ] **Step 5: Run tests**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && flutter test test/extracted_knowledge_screen_test.dart test/shared_chunk_adapter_test.dart'
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/src/shared/chunks/chunk_card.dart lib/src/knowledge/ui/extracted_knowledge_screen.dart test/extracted_knowledge_screen_test.dart
git commit -m "refactor: render extracted chunks with shared kinds"
```

---

### Task 4: PDF Chunk Menu Modes And Manual Visibility

**Files:**
- Modify: `lib/src/knowledge/ui/extracted_knowledge_screen.dart`
- Modify: `lib/src/knowledge/models/extracted_knowledge_item.dart`
- Test: `test/extracted_knowledge_screen_test.dart`

**Interfaces:**
- Consumes: normalized four-kind chunks and shared card rendering.
- Produces: `_PdfChunkMode { ai, manual }`, manual-mode item filtering, and `[PDFChunks]` logs.

- [ ] **Step 1: Replace old pipeline/type filter test**

In `test/extracted_knowledge_screen_test.dart`, replace the old `pipeline menu and type chips filter extracted chunks` test with:

```dart
testWidgets('pdf chunk menu exposes only AI and manual OCR-assisted modes', (
  tester,
) async {
  final repository = KnowledgeDocumentRepository();
  final document = await repository.addDocument(
    filename: 'mixed.pdf',
    localPath: '/memory/mixed.pdf',
    sizeBytes: 8,
    importedAt: DateTime.utc(2026, 6, 24),
    sha256: 'hash-mixed-ui',
  );
  await repository.saveExtractedEvidence(
    documentPublicId: document.id,
    evidence: const AiExtractedEvidence(
      id: 'ai-text',
      text: 'AI szöveg chunk',
      pageNumber: 1,
      sourceType: AiEvidenceSourceType.textChunk,
    ),
    embedding: List<double>.filled(3072, 0.1),
    embeddingModel: 'gemini-embedding-001',
  );
  await repository.saveLocalChunks(
    document.id,
    const [
      LocalChunk(
        id: 'local-table',
        documentId: 'document-1',
        text: 'Régi lokális OCR chunk',
        pageNumber: 2,
        pipeline: LocalExtractionPipeline.localOcr,
        kind: LocalChunkKind.table,
      ),
      LocalChunk(
        id: 'manual-text',
        documentId: 'document-1',
        text: 'Manuális szöveg chunk',
        pageNumber: 3,
        pipeline: LocalExtractionPipeline.manual,
        kind: LocalChunkKind.text,
      ),
    ],
    replaceExisting: false,
  );

  await tester.pumpWidget(
    MaterialApp(
      home: ExtractedKnowledgeScreen(
        repository: repository,
        document: document,
      ),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.text('AI chunkok'), findsOneWidget);
  expect(find.text('AI szöveg chunk'), findsOneWidget);
  expect(find.text('Régi lokális OCR chunk'), findsNothing);
  expect(find.text('Lokális chunkok'), findsNothing);
  expect(find.text('Összehasonlítás'), findsNothing);
  expect(find.byKey(const ValueKey('extracted-type-all')), findsNothing);

  await tester.tap(find.byKey(const Key('pdf-chunk-mode-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Manuális chunkok').last);
  await tester.pumpAndSettle();

  expect(find.text('Manuális chunkok'), findsOneWidget);
  expect(find.text('Manuális szöveg chunk'), findsOneWidget);
  expect(find.text('Régi lokális OCR chunk'), findsOneWidget);
  expect(find.text('AI szöveg chunk'), findsNothing);
});
```

- [ ] **Step 2: Run failing test**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && flutter test test/extracted_knowledge_screen_test.dart'
```

Expected: FAIL because the screen still exposes old modes and type chips.

- [ ] **Step 3: Replace mode enum**

In `lib/src/knowledge/ui/extracted_knowledge_screen.dart`, replace:

```dart
enum _ExtractedPipelineView { ai, local, manual, comparison }
```

with:

```dart
enum _PdfChunkMode { ai, manual }
```

Add labels:

```dart
extension _PdfChunkModeLabel on _PdfChunkMode {
  String get title {
    return switch (this) {
      _PdfChunkMode.ai => 'AI chunkok',
      _PdfChunkMode.manual => 'Manuális chunkok',
    };
  }
}
```

- [ ] **Step 4: Replace data model**

Replace `_ExtractedKnowledgeData` with:

```dart
class _ExtractedKnowledgeData {
  const _ExtractedKnowledgeData({
    required this.aiItems,
    required this.manualItems,
  });

  final List<ExtractedKnowledgeItem> aiItems;
  final List<ExtractedKnowledgeItem> manualItems;
}
```

Update `_loadData()`:

```dart
Future<_ExtractedKnowledgeData> _loadData() async {
  final allItems = await widget.repository.listExtractedKnowledgeItems(
    widget.document.id,
  );
  final aiItems = allItems
      .where((item) => item.pipeline == LocalExtractionPipeline.ai)
      .toList(growable: false);
  final manualItems = allItems
      .where((item) => item.pipeline != LocalExtractionPipeline.ai)
      .toList(growable: false);
  DebugConsole.log(
    '[PDFChunks] load document=${widget.document.id} '
    'ai=${aiItems.length} manual=${manualItems.length}',
  );
  return _ExtractedKnowledgeData(aiItems: aiItems, manualItems: manualItems);
}
```

Add import:

```dart
import '../../debug/debug_console.dart';
```

- [ ] **Step 5: Replace app bar menu**

Use key `pdf-chunk-mode-menu`:

```dart
PopupMenuButton<_PdfChunkMode>(
  key: const Key('pdf-chunk-mode-menu'),
  tooltip: 'Chunk mód',
  initialValue: _mode,
  onSelected: (value) {
    DebugConsole.log(
      '[PDFChunks] mode changed document=${widget.document.id} mode=${value.name}',
    );
    setState(() => _mode = value);
  },
  itemBuilder: (context) => [
    for (final mode in _PdfChunkMode.values)
      PopupMenuItem(value: mode, child: Text(mode.title)),
  ],
)
```

- [ ] **Step 6: Remove type filter bar and comparison list from build**

The body should choose:

```dart
final items = _mode == _PdfChunkMode.ai ? data.aiItems : data.manualItems;
```

Render `_ExtractedKnowledgeList(items: items, ...)` directly. Remove `_ContentTypeFilterBar`, `_ExtractedTypeFilter`, `_ChunkComparisonList`, and comparison UI if no tests use them after this task.

- [ ] **Step 7: Run test**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && flutter test test/extracted_knowledge_screen_test.dart'
```

Expected: PASS after updating remaining flowchart tests to select manual mode when the stored flowchart data is not AI evidence.

- [ ] **Step 8: Commit**

```bash
git add lib/src/knowledge/ui/extracted_knowledge_screen.dart lib/src/knowledge/models/extracted_knowledge_item.dart test/extracted_knowledge_screen_test.dart
git commit -m "feat: simplify pdf chunk modes"
```

---

### Task 5: Manual Chunk Editor Four Types, Save Logs, And Adaptive Sheet

**Files:**
- Create: `lib/src/shared/ui/inline_bottom_sheet_card.dart`
- Modify: `lib/src/knowledge/ui/manual_chunk_editor_screen.dart`
- Test: `test/inline_bottom_sheet_card_test.dart`

**Interfaces:**
- Produces: `InlineBottomSheetCard`.
- Consumes: four-kind `LocalChunkKind`.

- [ ] **Step 1: Write failing bottom sheet test**

Create `test/inline_bottom_sheet_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/shared/ui/inline_bottom_sheet_card.dart';

void main() {
  testWidgets('inline bottom sheet dismisses by drag without retaining surface', (
    tester,
  ) async {
    var dismissed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              const ColoredBox(
                key: ValueKey('pdf-background'),
                color: Colors.blue,
                child: SizedBox.expand(),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: InlineBottomSheetCard(
                  onDismiss: () => dismissed = true,
                  child: const SizedBox(
                    key: ValueKey('sheet-content'),
                    height: 180,
                    child: Text('Sheet'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('sheet-content')), findsOneWidget);
    await tester.drag(find.byKey(const ValueKey('inline-bottom-sheet-card')), const Offset(0, 180));
    await tester.pumpAndSettle();
    expect(dismissed, isTrue);
  });
}
```

- [ ] **Step 2: Run failing test**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && flutter test test/inline_bottom_sheet_card_test.dart'
```

Expected: FAIL because `InlineBottomSheetCard` does not exist.

- [ ] **Step 3: Add inline sheet widget**

Create `lib/src/shared/ui/inline_bottom_sheet_card.dart`:

```dart
import 'package:flutter/material.dart';

class InlineBottomSheetCard extends StatefulWidget {
  const InlineBottomSheetCard({
    super.key,
    required this.child,
    required this.onDismiss,
    this.dismissThreshold = 96,
  });

  final Widget child;
  final VoidCallback onDismiss;
  final double dismissThreshold;

  @override
  State<InlineBottomSheetCard> createState() => _InlineBottomSheetCardState();
}

class _InlineBottomSheetCardState extends State<InlineBottomSheetCard> {
  double _dragOffset = 0;

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dy).clamp(0, double.infinity);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (_dragOffset >= widget.dismissThreshold || velocity > 700) {
      widget.onDismiss();
      return;
    }
    setState(() => _dragOffset = 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('inline-bottom-sheet-card'),
      behavior: HitTestBehavior.translucent,
      onVerticalDragUpdate: _handleDragUpdate,
      onVerticalDragEnd: _handleDragEnd,
      child: AnimatedSlide(
        duration: _dragOffset == 0 ? const Duration(milliseconds: 160) : Duration.zero,
        curve: Curves.easeOutCubic,
        offset: Offset(0, _dragOffset / MediaQuery.sizeOf(context).height),
        child: widget.child,
      ),
    );
  }
}
```

- [ ] **Step 4: Restrict type choices**

In `manual_chunk_editor_screen.dart`, add:

```dart
const _manualChunkKinds = [
  LocalChunkKind.text,
  LocalChunkKind.list,
  LocalChunkKind.table,
  LocalChunkKind.flowchart,
];
```

Use `_manualChunkKinds` in the selection sheet and the kind dropdown. Remove source dropdown UI from `_ManualChunkCard`; keep `_sourceMode` as internal state from `_sourceModeForKind`.

- [ ] **Step 5: Replace `DraggableBottomCard` usage**

Remove:

```dart
import '../../shared/ui/draggable_bottom_card.dart';
```

Add:

```dart
import '../../shared/ui/inline_bottom_sheet_card.dart';
```

Replace:

```dart
DraggableBottomCard(
  onDismiss: _cancelCard,
  child: _ManualChunkCard(...),
)
```

with:

```dart
InlineBottomSheetCard(
  onDismiss: _cancelCard,
  child: _ManualChunkCard(...),
)
```

Ensure `_ManualChunkCard` uses `Column(mainAxisSize: MainAxisSize.min)` and keeps only a `ConstrainedBox(maxHeight: MediaQuery.sizeOf(context).height * 0.72)` around the scrollable content, not around a full-height white container.

- [ ] **Step 6: Strengthen save/reload logs**

In `_save()`, after `saveLocalChunks`, log:

```dart
final items = await widget.repository.listExtractedKnowledgeItems(widget.document.id);
final manualCount = items
    .where((item) => item.pipeline != LocalExtractionPipeline.ai)
    .length;
_log(
  'save complete document=${widget.document.id} kind=${_kind.wireName} '
  'chunk=${chunk.id} manualCount=$manualCount',
);
```

- [ ] **Step 7: Run tests**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && flutter test test/inline_bottom_sheet_card_test.dart'
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/src/shared/ui/inline_bottom_sheet_card.dart lib/src/knowledge/ui/manual_chunk_editor_screen.dart test/inline_bottom_sheet_card_test.dart
git commit -m "fix: stabilize manual chunk sheet"
```

---

### Task 6: Knowledge Row Navigation Parity With Notes

**Files:**
- Modify: `lib/src/knowledge/ui/knowledge_document_row.dart`
- Modify: `lib/src/knowledge/ui/knowledge_base_screen.dart`
- Test: `test/knowledge_base_screen_test.dart`

**Interfaces:**
- Produces row callbacks:
  - `VoidCallback onOpenChunks`
  - `VoidCallback onOpenSource`

- [ ] **Step 1: Add failing row widget test**

Append to `test/knowledge_base_screen_test.dart`:

```dart
testWidgets('document row card opens chunks and left icon opens source viewer', (
  tester,
) async {
  final document = KnowledgeDocument(
    id: 'doc-1',
    filename: 'source.pdf',
    localPath: '/memory/source.pdf',
    sizeBytes: 4,
    importedAt: DateTime.utc(2026, 6, 24),
    status: KnowledgeDocumentStatus.imported,
  );
  var openedChunks = 0;
  var openedSource = 0;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: KnowledgeDocumentRow(
          document: document,
          selectionMode: false,
          selected: false,
          processing: false,
          onTap: () => openedChunks += 1,
          onOpenSource: () => openedSource += 1,
          onLongPress: () {},
          onSelectionChanged: (_) {},
        ),
      ),
    ),
  );

  expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  await tester.tap(find.text('source.pdf'));
  await tester.pumpAndSettle();
  expect(openedChunks, 1);
  expect(openedSource, 0);

  await tester.tap(find.byKey(const ValueKey('knowledge-document-source-doc-1')));
  await tester.pumpAndSettle();
  expect(openedChunks, 1);
  expect(openedSource, 1);
});
```

- [ ] **Step 2: Run failing test**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && flutter test test/knowledge_base_screen_test.dart'
```

Expected: FAIL because `onOpenSource` does not exist and the row has no chevron.

- [ ] **Step 3: Update row API**

In `KnowledgeDocumentRow`, add:

```dart
required this.onOpenSource,
```

and field:

```dart
final VoidCallback onOpenSource;
```

Wrap the icon in:

```dart
InkResponse(
  key: ValueKey('knowledge-document-source-${document.id}'),
  onTap: selectionMode ? null : onOpenSource,
  radius: 22,
  child: Icon(_documentIcon, color: _documentIconColor),
)
```

Add trailing chevron when not in selection mode:

```dart
if (!selectionMode)
  const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
```

- [ ] **Step 4: Update knowledge screen callbacks**

In `KnowledgeBaseScreen`, change row creation:

```dart
onTap: () => _openExtractedKnowledge(document),
onOpenSource: () => _openDocument(document),
```

Add log before opening chunks:

```dart
DebugConsole.log(
  '[Knowledge/List] open chunks document=${document.id} filename=${document.filename}',
);
```

Add log before source viewer:

```dart
DebugConsole.log(
  '[Knowledge/List] open source document=${document.id} filename=${document.filename}',
);
```

- [ ] **Step 5: Run tests**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && flutter test test/knowledge_base_screen_test.dart'
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/src/knowledge/ui/knowledge_document_row.dart lib/src/knowledge/ui/knowledge_base_screen.dart test/knowledge_base_screen_test.dart
git commit -m "feat: align knowledge document row navigation"
```

---

### Task 7: Source Viewer Box Modes

**Files:**
- Create: `lib/src/knowledge/ui/source_chunk_box_overlay.dart`
- Modify: `lib/src/knowledge/ui/pdf_viewer_screen.dart`
- Modify: `lib/src/knowledge/ui/knowledge_base_screen.dart`
- Test: `test/pdf_viewer_source_box_overlay_test.dart`

**Interfaces:**
- Produces:
  - `enum SourceChunkBoxMode { hidden, ai, manual }`
  - `class SourceChunkBox`
  - `List<SourceChunkBox> sourceChunkBoxesFromItems(...)`

- [ ] **Step 1: Write failing source box parser test**

Create `test/pdf_viewer_source_box_overlay_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/knowledge/models/extracted_knowledge_item.dart';
import 'package:djinn/src/knowledge/models/local_extraction.dart';
import 'package:djinn/src/knowledge/ui/source_chunk_box_overlay.dart';
import 'package:djinn/src/local_store/entities.dart';

void main() {
  test('source box parser filters by mode and page', () {
    const items = [
      ExtractedKnowledgeItem(
        id: 'manual-1',
        documentId: 'doc-1',
        sourceType: EvidenceSourceType.textChunk,
        text: 'Manual',
        pageNumber: 2,
        pipeline: LocalExtractionPipeline.manual,
        sourceRectJson:
            '{"page":2,"viewport_rect":{"left":10,"top":20,"right":110,"bottom":70}}',
      ),
      ExtractedKnowledgeItem(
        id: 'ai-1',
        documentId: 'doc-1',
        sourceType: EvidenceSourceType.textChunk,
        text: 'AI',
        pageNumber: 2,
        pipeline: LocalExtractionPipeline.ai,
        sourceRectJson:
            '{"page":2,"viewport_rect":{"left":20,"top":40,"right":140,"bottom":90}}',
      ),
    ];

    final manual = sourceChunkBoxesFromItems(
      items,
      mode: SourceChunkBoxMode.manual,
      pageNumber: 2,
    );
    final ai = sourceChunkBoxesFromItems(
      items,
      mode: SourceChunkBoxMode.ai,
      pageNumber: 2,
    );
    final hidden = sourceChunkBoxesFromItems(
      items,
      mode: SourceChunkBoxMode.hidden,
      pageNumber: 2,
    );

    expect(manual.map((box) => box.chunkId), ['manual-1']);
    expect(ai.map((box) => box.chunkId), ['ai-1']);
    expect(hidden, isEmpty);
    expect(manual.single.rect.left, 10);
  });
}
```

- [ ] **Step 2: Run failing test**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && flutter test test/pdf_viewer_source_box_overlay_test.dart'
```

Expected: FAIL because overlay parser does not exist.

- [ ] **Step 3: Add overlay parser and painter**

Create `lib/src/knowledge/ui/source_chunk_box_overlay.dart`:

```dart
import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/extracted_knowledge_item.dart';
import '../models/local_extraction.dart';

enum SourceChunkBoxMode { hidden, ai, manual }

class SourceChunkBox {
  const SourceChunkBox({
    required this.chunkId,
    required this.rect,
    required this.mode,
    required this.label,
  });

  final String chunkId;
  final Rect rect;
  final SourceChunkBoxMode mode;
  final String label;
}

List<SourceChunkBox> sourceChunkBoxesFromItems(
  List<ExtractedKnowledgeItem> items, {
  required SourceChunkBoxMode mode,
  required int pageNumber,
}) {
  if (mode == SourceChunkBoxMode.hidden) {
    return const [];
  }
  return [
    for (final item in items)
      if (_matchesMode(item, mode) && item.pageNumber == pageNumber)
        if (_rectFromJson(item.sourceRectJson) case final rect?)
          SourceChunkBox(
            chunkId: item.id,
            rect: rect,
            mode: mode,
            label: item.chunkKind.label,
          ),
  ];
}

bool _matchesMode(ExtractedKnowledgeItem item, SourceChunkBoxMode mode) {
  return switch (mode) {
    SourceChunkBoxMode.hidden => false,
    SourceChunkBoxMode.ai => item.pipeline == LocalExtractionPipeline.ai,
    SourceChunkBoxMode.manual => item.pipeline != LocalExtractionPipeline.ai,
  };
}

Rect? _rectFromJson(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  try {
    final decoded = jsonDecode(value);
    if (decoded is! Map) {
      return null;
    }
    final rect = decoded['viewport_rect'];
    if (rect is! Map) {
      return null;
    }
    final left = (rect['left'] as num?)?.toDouble();
    final top = (rect['top'] as num?)?.toDouble();
    final right = (rect['right'] as num?)?.toDouble();
    final bottom = (rect['bottom'] as num?)?.toDouble();
    if (left == null || top == null || right == null || bottom == null) {
      return null;
    }
    return Rect.fromLTRB(left, top, right, bottom);
  } catch (_) {
    return null;
  }
}

class SourceChunkBoxOverlay extends StatelessWidget {
  const SourceChunkBoxOverlay({
    super.key,
    required this.boxes,
    required this.onTapBox,
  });

  final List<SourceChunkBox> boxes;
  final ValueChanged<String> onTapBox;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: _SourceChunkBoxPainter(boxes))),
        for (final box in boxes)
          Positioned.fromRect(
            rect: box.rect,
            child: InkWell(
              key: ValueKey('source-chunk-box-${box.chunkId}'),
              onTap: () => onTapBox(box.chunkId),
              child: Align(
                alignment: Alignment.topLeft,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      box.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SourceChunkBoxPainter extends CustomPainter {
  const _SourceChunkBoxPainter(this.boxes);

  final List<SourceChunkBox> boxes;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = const Color(0xFF2563EB).withValues(alpha: 0.10);
    final stroke = Paint()
      ..color = const Color(0xFF2563EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final box in boxes) {
      final rrect = RRect.fromRectAndRadius(box.rect, const Radius.circular(8));
      canvas.drawRRect(rrect, fill);
      canvas.drawRRect(rrect, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _SourceChunkBoxPainter oldDelegate) {
    return oldDelegate.boxes != boxes;
  }
}
```

- [ ] **Step 4: Wire viewer mode toggle**

In `PdfViewerScreen`, add optional params:

```dart
final KnowledgeDocumentRepository? repository;
final KnowledgeDocument? document;
```

Load `listExtractedKnowledgeItems(document.id)` when both are non-null. Add an app-bar action or overlay segmented popup with key `source-box-mode-menu`. Log:

```dart
DebugConsole.log(
  '[Knowledge/Viewer] box mode document=${document.id} mode=${_boxMode.name}',
);
```

When box tapped, log:

```dart
DebugConsole.log(
  '[Knowledge/Viewer] box tap document=${document.id} chunk=$chunkId',
);
```

and open `ExtractedKnowledgeScreen` or the validation/editor route for that chunk.

- [ ] **Step 5: Pass repository/document from knowledge screen**

In `_openDocument`, build:

```dart
PdfViewerScreen(
  title: document.filename,
  path: document.localPath,
  repository: widget.repository,
  document: document,
)
```

- [ ] **Step 6: Run tests**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && flutter test test/pdf_viewer_source_box_overlay_test.dart'
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/src/knowledge/ui/source_chunk_box_overlay.dart lib/src/knowledge/ui/pdf_viewer_screen.dart lib/src/knowledge/ui/knowledge_base_screen.dart test/pdf_viewer_source_box_overlay_test.dart
git commit -m "feat: show source chunk boxes in viewer"
```

---

### Task 8: PDF Chunk Tags Bridge

**Files:**
- Modify: `lib/src/local_store/entities.dart`
- Modify: `lib/src/knowledge/models/local_extraction.dart`
- Modify: `lib/src/knowledge/models/extracted_knowledge_item.dart`
- Modify: `lib/src/knowledge/data/knowledge_document_repository.dart`
- Modify: `lib/src/knowledge/data/objectbox_knowledge_repository.dart`
- Modify: `lib/src/knowledge/ui/extracted_knowledge_screen.dart`
- Test: `test/extracted_knowledge_screen_test.dart`

**Interfaces:**
- Produces:
  - `List<NoteKnowledgeTag> ExtractedKnowledgeItem.tags`
  - `Future<void> updateExtractedKnowledgeTags(...)`

- [ ] **Step 1: Add failing tag persistence test**

Add to `test/extracted_knowledge_screen_test.dart`:

```dart
test('manual pdf chunk tags round trip through repository', () async {
  final repository = KnowledgeDocumentRepository();
  final document = await repository.addDocument(
    filename: 'tags.pdf',
    localPath: '/memory/tags.pdf',
    sizeBytes: 8,
    importedAt: DateTime.utc(2026, 6, 24),
    sha256: 'hash-tags',
  );
  await repository.saveLocalChunks(
    document.id,
    const [
      LocalChunk(
        id: 'manual-tagged',
        documentId: 'document-1',
        text: 'Tagelhető chunk',
        pageNumber: 1,
        pipeline: LocalExtractionPipeline.manual,
        kind: LocalChunkKind.text,
      ),
    ],
    replaceExisting: false,
  );

  await repository.updateExtractedKnowledgeTags(
    document.id,
    'manual-tagged',
    const [
      NoteKnowledgeTag(
        type: NoteKnowledgeTagTypes.custom,
        label: 'súlyos',
        colorSlotId: 1,
      ),
    ],
  );

  final items = await repository.listExtractedKnowledgeItems(document.id);
  expect(items.single.tags.single.label, 'súlyos');
});
```

Add imports for note tag types:

```dart
import 'package:djinn/src/notes/models/note_document.dart';
```

- [ ] **Step 2: Run failing test**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && flutter test test/extracted_knowledge_screen_test.dart'
```

Expected: FAIL because PDF chunks do not expose/update tags.

- [ ] **Step 3: Add tag fields**

Add `tagsJson` to `DocumentChunkEntity`:

```dart
String? tagsJson;
```

Add to constructor:

```dart
this.tagsJson,
```

Add `tags` to `LocalChunk` and `ExtractedKnowledgeItem`:

```dart
this.tags = const [],
```

with fields:

```dart
final List<NoteKnowledgeTag> tags;
```

Update `copyWith` for `ExtractedKnowledgeItem`:

```dart
List<NoteKnowledgeTag>? tags,
```

and:

```dart
tags: tags ?? this.tags,
```

- [ ] **Step 4: Add JSON helpers**

In repository files, encode/decode tags:

```dart
String _tagsToJson(List<NoteKnowledgeTag> tags) {
  return jsonEncode([for (final tag in tags) tag.toJson()]);
}

List<NoteKnowledgeTag> _tagsFromJson(String? value) {
  if (value == null || value.trim().isEmpty) {
    return const [];
  }
  final decoded = jsonDecode(value);
  if (decoded is! List) {
    return const [];
  }
  return [
    for (final item in decoded)
      if (item is Map<String, Object?>) NoteKnowledgeTag.fromJson(item),
  ];
}
```

Import `dart:convert` and `../../notes/models/note_document.dart` where needed.

- [ ] **Step 5: Add update method**

In `KnowledgeDocumentRepository`, add:

```dart
Future<void> updateExtractedKnowledgeTags(
  String documentPublicId,
  String itemId,
  List<NoteKnowledgeTag> tags,
) async {
  final extractedItems = _extractedItemsByDocument[documentPublicId];
  if (extractedItems == null) {
    return;
  }
  final index = extractedItems.indexWhere((item) => item.id == itemId);
  if (index == -1) {
    return;
  }
  extractedItems[index] = extractedItems[index].copyWith(tags: tags);
}
```

In `ObjectboxKnowledgeRepository`, locate `DocumentChunkEntity` by source id and update `tagsJson`.

- [ ] **Step 6: Wire tag button in extracted screen**

Use `showTagManagerSheet` for PDF chunk cards:

```dart
await showTagManagerSheet(
  context,
  initialTags: item.tags,
  onChanged: (tags) async {
    await widget.repository.updateExtractedKnowledgeTags(
      widget.document.id,
      item.id,
      tags,
    );
    _reloadData();
  },
  title: 'Chunk tagjei',
);
```

Show existing tags using the shared card/tag chip path.

- [ ] **Step 7: Run ObjectBox code generation if required**

If `entities.dart` change requires generated ObjectBox model updates, run:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && dart run build_runner build --delete-conflicting-outputs'
```

Expected: generated ObjectBox files update without errors.

- [ ] **Step 8: Run tests**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && flutter test test/extracted_knowledge_screen_test.dart test/tag_manager_sheet_test.dart'
```

Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add lib/src/local_store/entities.dart lib/src/knowledge/models/local_extraction.dart lib/src/knowledge/models/extracted_knowledge_item.dart lib/src/knowledge/data/knowledge_document_repository.dart lib/src/knowledge/data/objectbox_knowledge_repository.dart lib/src/knowledge/ui/extracted_knowledge_screen.dart test/extracted_knowledge_screen_test.dart
git add lib/src/local_store/objectbox-model.json lib/src/local_store/objectbox.g.dart
git commit -m "feat: bridge tags for pdf chunks"
```

---

### Task 9: Image Import Naming And Chunkable Behavior

**Files:**
- Modify: `lib/src/knowledge/ui/knowledge_base_screen.dart`
- Modify: `lib/src/knowledge/ui/knowledge_document_row.dart`
- Test: `test/knowledge_base_screen_test.dart`

**Interfaces:**
- Consumes row navigation from Task 6.
- Produces user-facing PDF/image import copy and same card behavior for PNG.

- [ ] **Step 1: Add PNG row behavior test**

Add to `test/knowledge_base_screen_test.dart`:

```dart
testWidgets('png document row uses image icon and chunk/source split behavior', (
  tester,
) async {
  final document = KnowledgeDocument(
    id: 'img-1',
    filename: 'scan.png',
    localPath: '/memory/scan.png',
    sizeBytes: 4,
    importedAt: DateTime.utc(2026, 6, 24),
    status: KnowledgeDocumentStatus.imported,
  );
  var openedChunks = 0;
  var openedSource = 0;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: KnowledgeDocumentRow(
          document: document,
          selectionMode: false,
          selected: false,
          processing: false,
          onTap: () => openedChunks += 1,
          onOpenSource: () => openedSource += 1,
          onLongPress: () {},
          onSelectionChanged: (_) {},
        ),
      ),
    ),
  );

  expect(find.byIcon(Icons.image_outlined), findsOneWidget);
  await tester.tap(find.text('scan.png'));
  await tester.pumpAndSettle();
  expect(openedChunks, 1);
  await tester.tap(find.byKey(const ValueKey('knowledge-document-source-img-1')));
  await tester.pumpAndSettle();
  expect(openedSource, 1);
});
```

- [ ] **Step 2: Run test**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && flutter test test/knowledge_base_screen_test.dart'
```

Expected: PASS if Task 6 already supports this; otherwise update row.

- [ ] **Step 3: Update import copy**

Change FAB tooltip from:

```dart
tooltip: 'PDF/PNG hozzáadása',
```

to:

```dart
tooltip: 'PDF/kép hozzáadása',
```

Update import debug text to keep `type=pdf_png` but add user-facing labels where visible.

- [ ] **Step 4: Run tests**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && flutter test test/knowledge_base_screen_test.dart'
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/knowledge/ui/knowledge_base_screen.dart lib/src/knowledge/ui/knowledge_document_row.dart test/knowledge_base_screen_test.dart
git commit -m "feat: align image documents with pdf chunk workflow"
```

---

### Task 10: Final Verification And Cleanup

**Files:**
- Modify only files that fail analysis/tests.

**Interfaces:**
- Consumes all previous tasks.
- Produces verified implementation against the spec checklist.

- [ ] **Step 1: Run focused tests**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && flutter test test/shared_chunk_adapter_test.dart test/chunk_pipeline_comparison_test.dart test/local_chunk_builder_test.dart test/extracted_knowledge_screen_test.dart test/knowledge_base_screen_test.dart test/inline_bottom_sheet_card_test.dart test/pdf_viewer_source_box_overlay_test.dart'
```

Expected: all tests PASS.

- [ ] **Step 2: Run related note/tag regression tests**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && flutter test test/note_chunk_card_test.dart test/tag_manager_sheet_test.dart test/note_editor_route_test.dart'
```

Expected: all tests PASS.

- [ ] **Step 3: Run static analysis**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && flutter analyze'
```

Expected: no errors. Existing warnings must be listed in the final implementation report if not fixed.

- [ ] **Step 4: Manual debug panel checklist**

On device, test:

```text
1. Import PDF.
2. Tap document card: chunk menu opens.
3. Tap left icon: source viewer opens.
4. Switch source box mode hidden -> manual -> AI.
5. Start manual OCR-assisted chunking.
6. Select text, list, table, and flowchart in separate attempts.
7. Save a manual chunk.
8. Return to manual chunk menu and confirm saved chunk appears.
9. Open debug panel and confirm [Knowledge/List], [Knowledge/Viewer], [PDFChunks], [ManualChunk], [Knowledge/Import] entries exist.
10. Swipe/cancel manual sheet and confirm PDF is not covered by a white surface.
```

- [ ] **Step 5: Update acceptance checklist status**

In implementation notes or final response, report:

```text
PDF-01 DONE/PARTIAL/BLOCKED
PDF-02 DONE/PARTIAL/BLOCKED
PDF-03 DONE/PARTIAL/BLOCKED
PDF-04 DONE/PARTIAL/BLOCKED
PDF-05 DONE/PARTIAL/BLOCKED
PDF-06 DONE/PARTIAL/BLOCKED
PDF-07 DONE/PARTIAL/BLOCKED
PDF-08 DONE/PARTIAL/BLOCKED
PDF-09 DONE/PARTIAL/BLOCKED
PDF-10 DONE/PARTIAL/BLOCKED
PDF-11 DONE/PARTIAL/BLOCKED
PDF-12 DONE/PARTIAL/BLOCKED
```

- [ ] **Step 6: Commit verification fixes**

If any fixes were made:

```bash
git add <changed files>
git commit -m "fix: complete shared pdf chunk verification"
```

If no fixes were needed, do not create an empty commit.

---

## Plan Self-Review

Spec coverage:

- PDF-01: Task 4.
- PDF-02: Task 2 and Task 5.
- PDF-03: Task 4 and Task 5.
- PDF-04: Task 4, Task 5, Task 6, Task 7, Task 10.
- PDF-05: Task 5.
- PDF-06: Task 6.
- PDF-07: Task 6.
- PDF-08: Task 6.
- PDF-09: Task 7.
- PDF-10: Task 1 and Task 3.
- PDF-11: Task 8.
- PDF-12: Task 9.

Type consistency:

- Shared kind names are `text`, `list`, `table`, `flowchart` throughout.
- PDF mode names are `ai` and `manual` throughout.
- Legacy local pipelines remain persisted but are user-facing manual/OCR-assisted content.

Risk notes:

- Task 8 changes ObjectBox entities. If generated files change, commit them with the task.
- If Task 4 breaks old flowchart hierarchy tests, update those tests to select manual mode before expecting local/manual flowchart content.
- If any source rectangles use viewport coordinates that do not align after zoom/scroll, keep the parser and mode controls but mark precise geometric alignment as `PARTIAL` in the final checklist.
