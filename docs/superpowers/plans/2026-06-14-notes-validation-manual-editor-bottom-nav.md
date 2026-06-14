# Notes Validation Manual Editor Bottom Nav Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `Jegyzetek` a first-class manual knowledge library, remove top-level audit/view navigation in favor of fixed bottom navigation, and add a reusable manual edit/validation card for extracted text that can be freely dragged down to cancel or dismissed by swipe.

**Architecture:** Keep the current local ObjectBox-first architecture and the existing PDF/manual chunk extraction pipeline. Add a shared chunk-card and shared draggable bottom-card layer used by PDF extracted chunks, manual notes, and manual selection editing. Validation/editing stays source-local: long-tap on a PDF or note chunk opens the same bottom validation card, while the top-level app shell is always bottom nav.

**Tech Stack:** Flutter/Dart, ObjectBox, existing `KnowledgeDocumentRepository`/ObjectBox repositories, `pdfrx`, `google_mlkit_text_recognition`, `flutter_test`, GitHub Actions for Android APK builds.

---

## Included Spec Commitments

This plan includes the requested spec from:

`/data/data/com.termux/files/home/ubuntu/flutteruser/flutterapps/djinn/docs/superpowers/specs/2026-06-14-djinn-notes-chunk-validation-design.md`

Required product commitments:

- Bottom navigation only: `Jegyzetek`, `Tudástár`, `Chat`, `Keresés`, `Beállítások`.
- No standalone `Audit`, `Flow`, or `Validálás` top-level destination.
- `Jegyzetek` manages first-class manual knowledge items: text chunks, tables, and flowcharts.
- Manual notes are independent knowledge items, not created as PDF attachments.
- Note cards and PDF chunk cards use one shared card language.
- Validation opens by long-tapping PDF or note chunk cards.
- The validation card contains editable content, a reason/comment field, and status selector: `Review`, `Elfogad`, `Elutasít`.
- Saving `Elfogad` enables RAG/citation eligibility; saving `Elutasít` disables eligibility and stores a reason.
- Flowchart node/edge validation remains internally supported, but entry is through flowchart cards in PDF or notes context.
- Extracted flowcharts must be editable interactively after extraction: users can add, edit, delete, and reconnect nodes/edges before accepting the flowchart.
- No local Flutter APK build on Termux; Android APK build must run in GitHub Actions after commit and push.

## Current Code Facts

- `lib/src/chat/ui/app_destination.dart` currently defines `cases`, `flow`, `chat`, `knowledge`, `settings`.
- `lib/src/chat/ui/main_screen.dart` still supports drawer and bottom nav through `AppSettings.navigationMode`.
- `lib/src/settings/models/app_settings.dart`, `lib/src/settings/data/app_settings_repository.dart`, and `lib/src/settings/ui/settings_screen.dart` persist and expose `navigationMode`.
- `lib/src/flowchart/ui/flowchart_hub_screen.dart` currently acts as a top-level `Audit` destination.
- `lib/src/knowledge/ui/extracted_knowledge_screen.dart` already has pipeline filtering and type chips, but chunk cards do not open a shared validation/edit card.
- `lib/src/knowledge/ui/manual_chunk_editor_screen.dart` already has full-screen PDF/PNG selection and a bottom card, but the card is fixed and not freely draggable.
- `KnowledgeDocumentRepository.updateExtractedKnowledgeAuditState(...)` can already update audit state and optional text in memory.
- `ObjectBoxKnowledgeRepository.updateExtractedKnowledgeAuditState(...)` can update `DocumentChunkEntity.text`, chunk audit state, and flowchart node/edge validation state; it needs reason/comment persistence wired consistently.

## File Map

- Modify `lib/src/chat/ui/app_destination.dart`: fixed destination ids and labels for bottom nav.
- Modify `lib/src/chat/ui/main_screen.dart`: always render bottom nav; route to `NotesScreen`, `KnowledgeBaseScreen`, chat list, `SearchScreen`, and `SettingsScreen`.
- Modify `lib/src/settings/models/app_settings.dart`: remove `navigationMode` from product behavior; keep backward-compatible load if needed.
- Modify `lib/src/settings/data/app_settings_repository.dart`: tolerate old stored `navigationMode`, and write `bottom_nav` for compatibility while UI no longer exposes the choice.
- Modify `lib/src/settings/ui/settings_screen.dart`: remove the navigation mode selector from appearance settings.
- Create `lib/src/notes/models/note_item.dart`: note item type, payload, validation metadata.
- Create `lib/src/notes/models/note_folder.dart`: note folder model for the notes library.
- Create `lib/src/notes/data/note_repository.dart`: abstract repository plus in-memory implementation for tests.
- Create `lib/src/notes/data/objectbox_note_repository.dart`: ObjectBox implementation.
- Modify `lib/src/local_store/entities.dart`: add note folder/item entities and fields needed for validation eligibility.
- Regenerate `lib/objectbox.g.dart` and `lib/objectbox-model.json` after entity changes.
- Create `lib/src/notes/ui/notes_screen.dart`: notes library screen.
- Create `lib/src/notes/ui/note_creation_sheet.dart`: unified FAB sheet for text/table/flowchart notes.
- Create `lib/src/shared/chunks/chunk_card.dart`: shared PDF/note chunk card.
- Create `lib/src/shared/chunks/chunk_validation_card.dart`: shared editable validation card.
- Create `lib/src/shared/chunks/chunk_validation_controller.dart`: result/value object mapping UI state to `LocalAuditState`.
- Create `lib/src/shared/ui/draggable_bottom_card.dart`: reusable freely draggable bottom card with cancelable downward gesture.
- Create `lib/src/flowchart/models/editable_flowchart.dart`: editable graph model for extracted flowcharts.
- Create `lib/src/flowchart/data/flowchart_edit_repository.dart`: save/load/update API for editable extracted flowcharts.
- Create `lib/src/flowchart/ui/interactive_flowchart_editor_screen.dart`: interactive editor launched from extracted flowchart cards.
- Create `lib/src/flowchart/ui/flowchart_editor_canvas.dart`: node/edge canvas with selection and add/edit/delete controls.
- Modify `lib/src/knowledge/ui/extracted_knowledge_screen.dart`: use shared chunk cards, long-tap validation, and extracted text manual editor.
- Modify `lib/src/knowledge/ui/manual_chunk_editor_screen.dart`: wrap `_ManualChunkCard` with the reusable draggable bottom card.
- Modify `lib/src/knowledge/data/knowledge_document_repository.dart`: add a richer edit method while preserving the old audit method as a delegating compatibility method.
- Modify `lib/src/knowledge/data/objectbox_knowledge_repository.dart`: persist edited text, audit state, and reason for document chunks and flowchart nodes/edges.
- Modify `lib/src/knowledge/data/objectbox_knowledge_document_repository.dart`: forward the richer edit method.
- Modify `lib/src/rag/retrieval/local_retriever.dart`: enforce accepted/edited eligibility consistently for document chunks and later note chunks.
- Create `lib/src/search/ui/search_screen.dart`: real local search shell over notes and extracted chunks.

## Data Model Decisions

Shared card view model:

```dart
enum ChunkCardKind { text, list, table, score, flowchart, imageRegion, visualFact }

class ChunkCardViewModel {
  const ChunkCardViewModel({
    required this.id,
    required this.title,
    required this.preview,
    required this.kind,
    required this.auditState,
    required this.sourceLabel,
    required this.pipelineLabel,
    this.pageLabel,
  });

  final String id;
  final String title;
  final String preview;
  final ChunkCardKind kind;
  final LocalAuditState auditState;
  final String sourceLabel;
  final String pipelineLabel;
  final String? pageLabel;
}
```

Validation choice mapping:

```dart
enum ChunkValidationChoice { review, accept, reject }

extension ChunkValidationChoiceMapping on ChunkValidationChoice {
  LocalAuditState get auditState {
    return switch (this) {
      ChunkValidationChoice.review => LocalAuditState.unreviewed,
      ChunkValidationChoice.accept => LocalAuditState.accepted,
      ChunkValidationChoice.reject => LocalAuditState.rejected,
    };
  }
}
```

Note ObjectBox entities:

```dart
@Entity()
class NoteFolderEntity {
  NoteFolderEntity({
    this.id = 0,
    required this.publicId,
    required this.title,
    required this.createdAtMillis,
    required this.updatedAtMillis,
    this.sortOrder = 0,
  });

  @Id()
  int id;
  @Unique()
  String publicId;
  @Index()
  String title;
  int createdAtMillis;
  int updatedAtMillis;
  int sortOrder;
}

@Entity()
class NoteItemEntity {
  NoteItemEntity({
    this.id = 0,
    required this.publicId,
    required this.type,
    required this.title,
    required this.plainText,
    required this.payloadJson,
    required this.auditState,
    required this.createdAtMillis,
    required this.updatedAtMillis,
    this.folderPublicId,
    this.reason,
  });

  @Id()
  int id;
  @Unique()
  String publicId;
  @Index()
  String? folderPublicId;
  @Index()
  String type;
  String title;
  String plainText;
  String payloadJson;
  @Index()
  String auditState;
  String? reason;
  int createdAtMillis;
  int updatedAtMillis;
}
```

RAG/citation eligibility is derived:

- `LocalAuditState.accepted` and `LocalAuditState.edited` are eligible.
- `LocalAuditState.unreviewed` and `LocalAuditState.rejected` are not eligible.
- Rejected items remain visible in lists unless filtered out.

## Task 1: Fixed Bottom Navigation Shell

**Files:**
- Modify `test/main_screen_navigation_test.dart`
- Modify `lib/src/chat/ui/app_destination.dart`
- Modify `lib/src/chat/ui/main_screen.dart`
- Modify `lib/src/settings/models/app_settings.dart`
- Modify `lib/src/settings/data/app_settings_repository.dart`
- Modify `lib/src/settings/ui/settings_screen.dart`
- Modify `test/settings_repository_test.dart`
- Modify `test/settings_screen_test.dart`

- [ ] **Step 1: Replace navigation expectations with fixed bottom nav tests**

Update `test/main_screen_navigation_test.dart` so it asserts the app always renders `NavigationBar`, never renders a drawer menu, and shows labels:

```dart
expect(labels, ['Jegyzetek', 'Tudástár', 'Chat', 'Keresés', 'Beáll.']);
expect(find.text('Audit'), findsNothing);
expect(find.text('Validálás'), findsNothing);
expect(find.text('Flow'), findsNothing);
```

- [ ] **Step 2: Run the red navigation tests**

Run: `flutter test test/main_screen_navigation_test.dart`

Expected: fail because `AppDestinationId.flow`, drawer mode, and `navigationMode` still exist.

- [ ] **Step 3: Change destination model**

Replace `AppDestinationId` with:

```dart
enum AppDestinationId { notes, knowledge, chat, search, settings }
```

Replace `appDestinations` with `Jegyzetek`, `Tudástár`, `Chat`, `Keresés`, `Beállítások` in that order.

- [ ] **Step 4: Make `MainScreen` bottom-nav-only**

Remove `_buildDrawerShell`, `_buildDrawer`, `_openFlowchartValidation`, and all `navigationMode` branches. `build` should return `_buildBottomNavShell()` directly.

`_buildDestinationBody` should route to `NotesScreen`, `KnowledgeBaseScreen`, chat list, `SearchScreen`, and `SettingsScreen`. Add `noteRepository` to `MainScreen`; Task 2 creates the type.

- [ ] **Step 5: Remove navigation selector from settings UI**

Delete the `SegmentedButton<AppNavigationMode>` from settings. Existing persisted values should be ignored by the shell.

- [ ] **Step 6: Keep settings backward compatibility**

Keep `AppNavigationMode` only as a compatibility parse/write field if removing it would require risky ObjectBox migration. Defaults and writes should use `bottom_nav`.

- [ ] **Step 7: Run green navigation/settings tests**

Run: `flutter test test/main_screen_navigation_test.dart test/settings_repository_test.dart test/settings_screen_test.dart`

Expected: pass in CI.

## Task 2: Notes Domain And Repository

**Files:**
- Create `lib/src/notes/models/note_item.dart`
- Create `lib/src/notes/models/note_folder.dart`
- Create `lib/src/notes/data/note_repository.dart`
- Create `lib/src/notes/data/objectbox_note_repository.dart`
- Modify `lib/src/local_store/entities.dart`
- Regenerate `lib/objectbox.g.dart`
- Regenerate `lib/objectbox-model.json`
- Create `test/note_repository_test.dart`

- [ ] **Step 1: Write repository tests**

Create tests for folder filtering and validation eligibility:

```dart
final repository = MemoryNoteRepository();
final stroke = await repository.createFolder('Stroke');
await repository.createNote(
  type: NoteItemType.text,
  title: 'RAVE score',
  plainText: 'RACE vagy RAVE elemek',
  payloadJson: '{"text":"RACE vagy RAVE elemek"}',
  folderId: stroke.id,
);
expect(await repository.listNotes(folderId: stroke.id), hasLength(1));
```

And:

```dart
final accepted = await repository.updateNoteValidation(
  note.id,
  auditState: LocalAuditState.accepted,
  plainText: note.plainText,
  reason: 'ellenőrizve',
);
expect(accepted.ragEligible, isTrue);
expect(accepted.citationEligible, isTrue);
```

- [ ] **Step 2: Run red repository tests**

Run: `flutter test test/note_repository_test.dart`

Expected: fail because notes repository and models do not exist.

- [ ] **Step 3: Add note models and repositories**

Implement `NoteItemType`, `NoteItem`, `NoteFolder`, `NoteRepository`, and `MemoryNoteRepository` with methods:

```dart
Future<List<NoteFolder>> listFolders();
Future<NoteFolder> createFolder(String title);
Future<void> deleteFolder(String folderId);
Future<List<NoteItem>> listNotes({String? folderId, NoteItemType? type});
Future<NoteItem> createNote({required NoteItemType type, required String title, required String plainText, required String payloadJson, String? folderId});
Future<NoteItem> updateNoteValidation(String noteId, {required LocalAuditState auditState, String? plainText, String? payloadJson, String? reason});
Future<void> deleteNotes(List<String> noteIds);
```

- [ ] **Step 4: Add ObjectBox entities and repository**

Add `NoteFolderEntity` and `NoteItemEntity` as defined above. Implement `ObjectBoxNoteRepository` with the same interface and sorting by `updatedAtMillis` descending.

- [ ] **Step 5: Regenerate ObjectBox code**

Run: `dart run build_runner build --delete-conflicting-outputs`

Expected: `lib/objectbox.g.dart` and `lib/objectbox-model.json` update with new entities.

- [ ] **Step 6: Run green repository tests**

Run: `flutter test test/note_repository_test.dart`

Expected: pass.

## Task 3: Notes Screen And Unified Creation Sheet

**Files:**
- Create `lib/src/notes/ui/notes_screen.dart`
- Create `lib/src/notes/ui/note_creation_sheet.dart`
- Create `test/notes_screen_test.dart`

- [ ] **Step 1: Write notes screen widget tests**

Test that `Jegyzetek` renders, the header menu toggles `notes-folder-bar`, and the FAB opens one creation sheet with key `note-create-type-dropdown` and no `PDF-hez csatolás` action.

- [ ] **Step 2: Run red notes tests**

Run: `flutter test test/notes_screen_test.dart`

Expected: fail because `NotesScreen` does not exist.

- [ ] **Step 3: Implement `NotesScreen` shell**

Layout:

- `Scaffold`
- `AppBar(title: Text('Jegyzetek'))`
- `PopupMenuButton` key `notes-header-menu`
- optional horizontal folder bar key `notes-folder-bar`
- note list with `BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics())`
- FAB key `notes-create-fab`

Header menu items must call real handlers or stay hidden. Do not render disabled placeholder actions.

- [ ] **Step 4: Implement note creation sheet**

`NoteCreationSheet` uses one top dropdown:

- `Szöveges chunk`: multiline text.
- `Táblázat`: row-per-line editor where columns are separated by `|`, storing structured JSON and plain text.
- `Flowchart`: node/edge text editor with one line per step and `A -> B [label]` edge syntax, storing structured JSON and plain text.

Saving creates `LocalAuditState.unreviewed`.

- [ ] **Step 5: Run green notes tests**

Run: `flutter test test/notes_screen_test.dart`

Expected: pass.

## Task 4: Shared Chunk Card Contract

**Files:**
- Create `lib/src/shared/chunks/chunk_card.dart`
- Modify `lib/src/knowledge/ui/extracted_knowledge_screen.dart`
- Modify `lib/src/notes/ui/notes_screen.dart`
- Create `test/chunk_card_test.dart`
- Modify `test/extracted_knowledge_screen_test.dart`
- Modify `test/notes_screen_test.dart`

- [ ] **Step 1: Write shared card tests**

Test that `KnowledgeChunkCard` renders title, metadata, preview, `Review` chip, and calls `onLongPress`.

- [ ] **Step 2: Run red card tests**

Run: `flutter test test/chunk_card_test.dart`

Expected: fail because the shared card does not exist.

- [ ] **Step 3: Implement `KnowledgeChunkCard`**

Use the current PDF chunk card visual language: white material card, 8 px radius, leading icon by kind, title, metadata line, preview, status chip colors, optional overflow menu only when actions are supplied.

- [ ] **Step 4: Replace local card renderers**

Map `ExtractedKnowledgeItem` and `NoteItem` to `ChunkCardViewModel`. Keep existing flowchart hierarchy rendering when type filter is flowchart-only.

- [ ] **Step 5: Run green card and screen tests**

Run: `flutter test test/chunk_card_test.dart test/extracted_knowledge_screen_test.dart test/notes_screen_test.dart`

Expected: pass.

## Task 5: Reusable Free-Drag Bottom Card

**Files:**
- Create `lib/src/shared/ui/draggable_bottom_card.dart`
- Create `test/draggable_bottom_card_test.dart`
- Modify `lib/src/knowledge/ui/manual_chunk_editor_screen.dart`
- Modify `lib/src/shared/chunks/chunk_validation_card.dart` after Task 6 creates it

- [ ] **Step 1: Write drag behavior tests**

Tests:

```dart
await tester.drag(find.byKey(const ValueKey('draggable-bottom-card')), const Offset(0, 80));
await tester.pumpAndSettle();
expect(dismissed, isFalse);

await tester.drag(find.byKey(const ValueKey('draggable-bottom-card')), const Offset(0, 240));
await tester.pumpAndSettle();
expect(dismissed, isTrue);
```

- [ ] **Step 2: Run red drag tests**

Run: `flutter test test/draggable_bottom_card_test.dart`

Expected: fail because `DraggableBottomCard` does not exist.

- [ ] **Step 3: Implement free-drag card**

Requirements:

- `GestureDetector` handles vertical drag start/update/end.
- Positive `_dragOffset` moves the card; upward drag clamps to zero.
- `Transform.translate(offset: Offset(0, _dragOffset))` drives the free motion.
- Downward drag beyond `0.35 * cardHeight` or velocity above `900` dismisses.
- Release below threshold animates back to zero.
- Parent receives `onDismissed`; the component does not call `Navigator.pop` internally.

- [ ] **Step 4: Wrap manual selection card**

In `ManualChunkEditorScreen`, replace the fixed positioned `_ManualChunkCard` with:

```dart
DraggableBottomCard(
  key: const ValueKey('manual-chunk-draggable-card'),
  onDismissed: _cancelCard,
  child: _ManualChunkCard(...),
)
```

Remove duplicate drag handles.

- [ ] **Step 5: Run green drag/manual tests**

Run: `flutter test test/draggable_bottom_card_test.dart test/manual_chunk_editor_screen_test.dart`

Expected: pass.

## Task 6: Editable Validation Card For Extracted Text And Notes

**Files:**
- Create `lib/src/shared/chunks/chunk_validation_controller.dart`
- Create `lib/src/shared/chunks/chunk_validation_card.dart`
- Create `test/chunk_validation_card_test.dart`
- Modify `lib/src/knowledge/data/knowledge_document_repository.dart`
- Modify `lib/src/knowledge/data/objectbox_knowledge_repository.dart`
- Modify `lib/src/knowledge/data/objectbox_knowledge_document_repository.dart`
- Modify `lib/src/notes/data/note_repository.dart`
- Modify `lib/src/notes/data/objectbox_note_repository.dart`

- [ ] **Step 1: Write validation card tests**

Test that the card edits content, reason, and saves `ChunkValidationChoice.accept` from the `Elfogad` selector.

- [ ] **Step 2: Run red validation card tests**

Run: `flutter test test/chunk_validation_card_test.dart`

Expected: fail because the validation card does not exist.

- [ ] **Step 3: Implement validation result and card**

`ChunkValidationCard` contains source summary, editable multiline content field key `chunk-validation-content`, reason field key `chunk-validation-reason`, segmented status selector, `Mégse`, and save button key `chunk-validation-save`. Empty content disables save and displays `A tartalom nem lehet üres.`

- [ ] **Step 4: Add richer repository method for PDF extracted items**

Add to memory and ObjectBox repositories:

```dart
Future<void> updateExtractedKnowledgeItem(
  String documentPublicId,
  String itemId, {
  required LocalAuditState auditState,
  String? text,
  String? reason,
});
```

Keep `updateExtractedKnowledgeAuditState` as a delegating compatibility method.

- [ ] **Step 5: Persist reason in ObjectBox**

For `DocumentChunkEntity`, store reason in matching `ExtractionAuditItemEntity.reason`. For `FlowchartNodeEntity` and `FlowchartEdgeEntity`, store reason in `rejectionReason` when supplied and clear stale rejection reason when accepted without reason.

- [ ] **Step 6: Run green validation tests**

Run: `flutter test test/chunk_validation_card_test.dart test/chunk_pipeline_comparison_test.dart`

Expected: pass.

## Task 7: Extracted Content Manual Editor Integration

**Files:**
- Modify `lib/src/knowledge/ui/extracted_knowledge_screen.dart`
- Modify `test/extracted_knowledge_screen_test.dart`

- [ ] **Step 1: Write extracted content edit tests**

Long-press an extracted text card, edit content in `chunk-validation-content`, choose `Elfogad`, save, and assert the updated text appears.

- [ ] **Step 2: Run red extracted content tests**

Run: `flutter test test/extracted_knowledge_screen_test.dart`

Expected: fail because long-tap validation/edit is not wired.

- [ ] **Step 3: Convert screen to state-refreshing loader**

Change `_dataFuture` from `late final` to reloadable state and add `_refresh()`.

- [ ] **Step 4: Open validation card from long press**

Pass `onLongPress` to `KnowledgeChunkCard`. Store `ExtractedKnowledgeItem? _editingItem`. Render `DraggableBottomCard` with `ChunkValidationCard` in a `Stack` over the list. On save, call `repository.updateExtractedKnowledgeItem(...)`, close the card, and refresh.

- [ ] **Step 5: Preserve flowchart behavior**

For flowchart nodes/edges, the same card edits the node label or edge label text. Full graph editing remains reachable from flowchart group card actions, not top-level bottom nav.

- [ ] **Step 6: Run green extracted content tests**

Run: `flutter test test/extracted_knowledge_screen_test.dart`

Expected: pass.


## Task 8: Interactive Flowchart Extraction Editor

**Files:**
- Create `lib/src/flowchart/models/editable_flowchart.dart`
- Create `lib/src/flowchart/data/flowchart_edit_repository.dart`
- Create `lib/src/flowchart/ui/interactive_flowchart_editor_screen.dart`
- Create `lib/src/flowchart/ui/flowchart_editor_canvas.dart`
- Modify `lib/src/knowledge/ui/extracted_knowledge_screen.dart`
- Modify `lib/src/knowledge/data/knowledge_document_repository.dart`
- Modify `lib/src/knowledge/data/objectbox_knowledge_repository.dart`
- Modify `lib/src/knowledge/data/objectbox_knowledge_document_repository.dart`
- Modify `lib/src/local_store/entities.dart` only if existing `FlowchartEntity`, `FlowchartNodeEntity`, and `FlowchartEdgeEntity` cannot represent the needed fields
- Create `test/editable_flowchart_test.dart`
- Create `test/interactive_flowchart_editor_screen_test.dart`
- Modify `test/extracted_knowledge_screen_test.dart`

- [ ] **Step 1: Write editable graph model tests**

Create `test/editable_flowchart_test.dart` with tests for adding a missing process node between an existing decision and target, updating branch labels, and serializing back to node/edge lists:

```dart
test('editable flowchart inserts a missing process on an existing branch', () {
  final graph = EditableFlowchart(
    id: 'flow-1',
    title: 'COPD ellátás',
    pageNumber: 3,
    nodes: const [
      EditableFlowNode(id: 'n1', label: 'Légzési elégtelenség?', shape: 'decision', sortOrder: 1),
      EditableFlowNode(id: 'n2', label: 'Szállítás', shape: 'process', sortOrder: 2),
    ],
    edges: const [
      EditableFlowEdge(id: 'e1', fromNodeId: 'n1', toNodeId: 'n2', label: 'IGEN', sortOrder: 1),
    ],
  );

  final updated = graph.insertNodeOnEdge(
    edgeId: 'e1',
    nodeId: 'n-meds',
    label: 'Gyógyszeres kezelés',
    shape: 'process',
  );

  expect(updated.nodes.map((node) => node.label), contains('Gyógyszeres kezelés'));
  expect(updated.edges.any((edge) => edge.fromNodeId == 'n1' && edge.toNodeId == 'n-meds'), isTrue);
  expect(updated.edges.any((edge) => edge.fromNodeId == 'n-meds' && edge.toNodeId == 'n2'), isTrue);
  expect(updated.edges.where((edge) => edge.id == 'e1'), isEmpty);
});
```

- [ ] **Step 2: Run red graph tests**

Run: `flutter test test/editable_flowchart_test.dart`

Expected: fail because `EditableFlowchart` does not exist.

- [ ] **Step 3: Implement editable flowchart model**

`EditableFlowchart` must contain:

```dart
class EditableFlowchart {
  const EditableFlowchart({
    required this.id,
    required this.title,
    required this.pageNumber,
    required this.nodes,
    required this.edges,
  });

  final String id;
  final String title;
  final int pageNumber;
  final List<EditableFlowNode> nodes;
  final List<EditableFlowEdge> edges;
}
```

`EditableFlowNode` fields: `id`, `label`, `shape`, `sortOrder`, `validationState`, `sourceRectJson`, `x`, `y`.

`EditableFlowEdge` fields: `id`, `fromNodeId`, `toNodeId`, `label`, `sortOrder`, `validationState`, `sourceRectJson`.

Methods:

```dart
EditableFlowchart renameTitle(String title);
EditableFlowchart updateNode(String nodeId, {String? label, String? shape});
EditableFlowchart addNode(EditableFlowNode node);
EditableFlowchart removeNode(String nodeId);
EditableFlowchart updateEdge(String edgeId, {String? fromNodeId, String? toNodeId, String? label});
EditableFlowchart addEdge(EditableFlowEdge edge);
EditableFlowchart removeEdge(String edgeId);
EditableFlowchart insertNodeOnEdge({required String edgeId, required String nodeId, required String label, required String shape});
```

- [ ] **Step 4: Write repository round-trip tests**

Add tests that load extracted flowchart items from `KnowledgeDocumentRepository`, convert them to `EditableFlowchart`, save edits, and list extracted knowledge again with the new node/edge present.

Test expectation:

```dart
final items = await repository.listExtractedKnowledgeItems('doc-1');
expect(items.where((item) => item.text.contains('Gyógyszeres kezelés')), isNotEmpty);
expect(items.where((item) => item.sourceType == EvidenceSourceType.flowchartEdge), hasLength(2));
```

- [ ] **Step 5: Implement `FlowchartEditRepository` API**

Add an adapter over the existing knowledge repositories:

```dart
abstract class FlowchartEditRepository {
  Future<EditableFlowchart?> loadFlowchart(String documentPublicId, String flowchartId);
  Future<void> saveFlowchart(String documentPublicId, EditableFlowchart flowchart);
}
```

For memory repository, update `_flowchartsByDocument` or the equivalent extracted item store. For ObjectBox, update `FlowchartEntity`, `FlowchartNodeEntity`, and `FlowchartEdgeEntity` inside one write transaction.

- [ ] **Step 6: Write editor screen widget tests**

Create `test/interactive_flowchart_editor_screen_test.dart`:

```dart
testWidgets('interactive flowchart editor edits nodes and inserts missing process', (tester) async {
  final repository = MemoryFlowchartEditRepository.seeded(
    EditableFlowchart(
      id: 'flow-1',
      title: 'COPD ellátás',
      pageNumber: 3,
      nodes: const [
        EditableFlowNode(id: 'n1', label: 'Légzési elégtelenség?', shape: 'decision', sortOrder: 1),
        EditableFlowNode(id: 'n2', label: 'Szállítás', shape: 'process', sortOrder: 2),
      ],
      edges: const [
        EditableFlowEdge(id: 'e1', fromNodeId: 'n1', toNodeId: 'n2', label: 'IGEN', sortOrder: 1),
      ],
    ),
  );

  await tester.pumpWidget(MaterialApp(
    home: InteractiveFlowchartEditorScreen(
      documentPublicId: 'doc-1',
      flowchartId: 'flow-1',
      repository: repository,
    ),
  ));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const ValueKey('flow-editor-edge-e1')));
  await tester.tap(find.byKey(const ValueKey('flow-editor-insert-process')));
  await tester.enterText(find.byKey(const ValueKey('flow-editor-node-label-field')), 'Gyógyszeres kezelés');
  await tester.tap(find.byKey(const ValueKey('flow-editor-save-node')));
  await tester.tap(find.byKey(const ValueKey('flow-editor-save')));

  final saved = await repository.loadFlowchart('doc-1', 'flow-1');
  expect(saved!.nodes.map((node) => node.label), contains('Gyógyszeres kezelés'));
});
```

- [ ] **Step 7: Run red editor tests**

Run: `flutter test test/interactive_flowchart_editor_screen_test.dart`

Expected: fail because the editor screen and repository do not exist.

- [ ] **Step 8: Implement editor UI**

`InteractiveFlowchartEditorScreen` must provide:

- app bar title from flowchart title;
- editable title action key `flow-editor-rename-title`;
- canvas/list hybrid rendering using `FlowchartEditorCanvas`;
- selectable node cards by key `flow-editor-node-<id>`;
- selectable edge rows by key `flow-editor-edge-<id>`;
- add-node action;
- add-edge action;
- insert-process-on-selected-edge action key `flow-editor-insert-process`;
- delete selected action;
- save action key `flow-editor-save`.

Canvas can be a structured vertical graph editor first, not a freeform diagramming canvas. It must still be interactive: user can select items, edit labels/shapes, insert missing nodes, and reconnect branches.

- [ ] **Step 9: Launch editor from extracted flowchart cards**

In `ExtractedKnowledgeScreen`, flowchart group cards get a real action `Flowchart szerkesztése`. It opens `InteractiveFlowchartEditorScreen` with `document.id` and `flowchartId`. After returning `true`, refresh extracted items.

Do not expose this as a top-level bottom nav destination.

- [ ] **Step 10: Preserve validation semantics after edit**

When a user saves edited flowchart data:

- edited/new nodes become `LocalAuditState.edited` or `ValidationState.validated` only if the user explicitly chooses accept in the validation card;
- otherwise they remain `Review` / `unreviewed`;
- deleted nodes/edges are removed from trusted RAG/citation evidence immediately.

- [ ] **Step 11: Run green flowchart editor tests**

Run:

```bash
flutter test \
  test/editable_flowchart_test.dart \
  test/interactive_flowchart_editor_screen_test.dart \
  test/extracted_knowledge_screen_test.dart
```

Expected: pass.

## Task 9: Notes Validation Integration

**Files:**
- Modify `lib/src/notes/ui/notes_screen.dart`
- Modify `test/notes_screen_test.dart`

- [ ] **Step 1: Write note long-tap validation test**

Long-press a note card, edit it through the same validation card, save accepted state, and assert repository state is accepted.

- [ ] **Step 2: Run red notes validation test**

Run: `flutter test test/notes_screen_test.dart`

Expected: fail because long-tap validation is not wired.

- [ ] **Step 3: Wire note validation**

Notes list uses `KnowledgeChunkCard(onLongPress: ...)`. Opening and saving uses the same `DraggableBottomCard` and `ChunkValidationCard` as extracted PDF chunks. For table and flowchart notes, preserve structured `payloadJson`; when plain text changes, write `manual_plain_text_override` into the payload.

- [ ] **Step 4: Run green notes validation test**

Run: `flutter test test/notes_screen_test.dart`

Expected: pass.

## Task 10: Search Screen As Real Bottom Nav Destination

**Files:**
- Create `lib/src/search/ui/search_screen.dart`
- Create `test/search_screen_test.dart`
- Modify `lib/src/chat/ui/main_screen.dart`

- [ ] **Step 1: Write search screen tests**

Create a test that indexes an accepted note and searches it through `SearchScreen` using field key `search-query-field`.

- [ ] **Step 2: Run red search tests**

Run: `flutter test test/search_screen_test.dart`

Expected: fail because `SearchScreen` does not exist.

- [ ] **Step 3: Implement simple local search**

Search should be real:

- text field key `search-query-field`;
- searches accepted/edited notes by `title` and `plainText`;
- searches extracted chunks by `text`, `sectionTitle`, and `pageLabel`;
- shows source label: `Jegyzet`, `PDF`, `Flowchart`;
- rejected/unreviewed items are hidden from results by default.

- [ ] **Step 4: Run green search tests**

Run: `flutter test test/search_screen_test.dart test/main_screen_navigation_test.dart`

Expected: pass.

## Task 11: Remove Standalone Audit/Flow Top-Level Entry

**Files:**
- Modify `lib/src/flowchart/ui/flowchart_hub_screen.dart`
- Modify `test/flowchart_hub_screen_test.dart`
- Modify `test/flowchart_validation_test.dart` only if app-shell assumptions changed
- Modify `lib/src/chat/ui/main_screen.dart`

- [ ] **Step 1: Rewrite hub test as internal-only screen test**

Update `test/flowchart_hub_screen_test.dart` so it no longer asserts top-level `Audit` navigation. It may still assert internal builder/template behavior.

- [ ] **Step 2: Remove `FlowchartHubScreen` from `MainScreen` destination routing**

Do not delete `FlowchartHubScreen`; keep it available for internal flowchart note/PDF editor entry points. Remove direct `MainScreen` route or bottom nav destination pointing to it.

- [ ] **Step 3: Run flowchart tests**

Run: `flutter test test/flowchart_hub_screen_test.dart test/flowchart_validation_test.dart`

Expected: pass.

## Task 12: RAG Eligibility Enforcement

**Files:**
- Modify `lib/src/rag/retrieval/local_retriever.dart`
- Modify or create `test/local_retriever_validation_test.dart`

- [ ] **Step 1: Write retrieval eligibility tests**

Add a test with one accepted chunk, one unreviewed chunk, and one rejected chunk. Query for a term present in all three. Assert only accepted/edited chunks can become trusted evidence.

- [ ] **Step 2: Run red retrieval tests**

Run: `flutter test test/local_retriever_validation_test.dart`

Expected: fail if unreviewed chunks are currently returned as trusted evidence.

- [ ] **Step 3: Enforce eligibility**

In retrieval, skip source chunks whose `auditState` maps to `unreviewed` or `rejected` when building trusted evidence. Keep them visible in inspector screens.

- [ ] **Step 4: Run green retrieval tests**

Run: `flutter test test/local_retriever_validation_test.dart`

Expected: pass.

## Task 13: Integration Verification And GitHub Build

**Files:**
- All changed files.

- [ ] **Step 1: Run static diff check**

Run: `git diff --check`

Expected: no whitespace errors.

- [ ] **Step 2: Run focused test batch**

Run where Flutter test is available:

```bash
flutter test \
  test/main_screen_navigation_test.dart \
  test/settings_repository_test.dart \
  test/settings_screen_test.dart \
  test/note_repository_test.dart \
  test/notes_screen_test.dart \
  test/editable_flowchart_test.dart \
  test/interactive_flowchart_editor_screen_test.dart \
  test/chunk_card_test.dart \
  test/chunk_validation_card_test.dart \
  test/draggable_bottom_card_test.dart \
  test/manual_chunk_editor_screen_test.dart \
  test/extracted_knowledge_screen_test.dart \
  test/search_screen_test.dart \
  test/flowchart_hub_screen_test.dart \
  test/flowchart_validation_test.dart
```

Expected: pass in CI. Do not attempt a local Android APK build on Termux.

- [ ] **Step 3: Run analyze**

Run: `flutter analyze`

Expected: no new analyzer errors.

- [ ] **Step 4: Commit**

Use one commit after tests are green:

```bash
git add lib test docs
git commit -m "feat: add notes validation manual editor flow"
```

- [ ] **Step 5: Push and verify GitHub Actions**

Run: `git push origin feature/knowledge-ocr-inspector`

Then inspect the GitHub Actions workflow run. The Android debug APK build must happen online, not locally.

## Self-Review

- Spec coverage: bottom-nav-only, `Jegyzetek`, no standalone `Audit`/`Flow`/`Validálás`, note folders, unified creation sheet, shared chunk cards, long-tap validation, editable validation content, interactive flowchart extraction editor, status selector, RAG/citation semantics, flowchart internal validation entry, and GitHub build policy are covered.
- Manual editor coverage: extracted text can be edited from the validation card; manual PDF/PNG selection card uses free drag with cancelable downward motion.
- Placeholder scan: the plan says to hide or fully implement export/import menu entries; no disabled placeholder controls should be visible.
- Type consistency: UI validation maps through `ChunkValidationChoice` to `LocalAuditState`; repository methods use `updateExtractedKnowledgeItem`; notes use `NoteRepository.updateNoteValidation`.
- Risk: ObjectBox schema changes require regenerating `objectbox.g.dart` and model JSON in the same commit. If generation is unavailable locally, the implementation branch must run generation in a suitable environment before pushing.
