# Flowchart Popup Router Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the approved flowchart popup editor, simplified logical element palette, port-based connection behavior, universal edge deletion, and readable back-edge routing.

**Architecture:** Keep the first implementation compatible with existing saved notes by extending the current note flowchart model instead of replacing it outright. Add logical metadata and port metadata to `NoteFlowchartNode` and `NoteFlowchartEdge`, derive defaults for legacy nodes, then update the editor to use ports for rendering and connection. Edge routing remains a renderer concern and stores only endpoint metadata unless manual routing is added later.

**Tech Stack:** Flutter, Dart, existing `NoteBlock`/`NoteFlowchartNode`/`NoteFlowchartEdge` models, Flutter widget tests, GitHub Actions for build verification.

---

### Task 1: Extend Flowchart Models With Logical Kind And Ports

**Files:**
- Modify: `lib/src/notes/models/note_document.dart`
- Test: `test/note_document_test.dart`

- [ ] **Step 1: Write serialization tests**

Add tests that cover:

```dart
test('flowchart node serializes logical kind role and ports', () {
  const node = NoteFlowchartNode(
    id: 'decision-1',
    label: 'Szaturáció?',
    kind: NoteFlowchartNodeKind.multiDecision,
    role: NoteFlowchartNodeRole.normal,
    visualShape: NoteFlowchartVisualShape.diamond,
    ports: [
      NoteFlowchartPort(id: 'p1', side: NoteFlowchartPortSide.right, label: '95 felett', semantic: NoteFlowchartPortSemantic.custom),
    ],
  );

  final decoded = NoteFlowchartNode.fromJson(node.toJson());

  expect(decoded.kind, NoteFlowchartNodeKind.multiDecision);
  expect(decoded.visualShape, NoteFlowchartVisualShape.diamond);
  expect(decoded.ports.single.side, NoteFlowchartPortSide.right);
  expect(decoded.ports.single.label, '95 felett');
});

test('legacy decision node derives default yes no ports', () {
  final node = NoteFlowchartNode.fromJson({
    'id': 'decision',
    'label': 'Javult?',
    'shape': 'decision',
  });

  expect(node.kind, NoteFlowchartNodeKind.binaryDecision);
  expect(node.ports.map((port) => port.semantic), containsAll([NoteFlowchartPortSemantic.yes, NoteFlowchartPortSemantic.no]));
});
```

- [ ] **Step 2: Implement model additions**

Add enums:

```dart
enum NoteFlowchartNodeKind { universal, binaryDecision, multiDecision }
enum NoteFlowchartNodeRole { normal, start, end }
enum NoteFlowchartVisualShape { rectangle, oval, diamond }
enum NoteFlowchartPortSide { top, right, bottom, left }
enum NoteFlowchartPortSemantic { normal, yes, no, custom }
enum NoteFlowchartRoutingMode { auto, manual }
```

Add `NoteFlowchartPort` and fields to node/edge:

```dart
final NoteFlowchartNodeKind kind;
final NoteFlowchartNodeRole role;
final NoteFlowchartVisualShape visualShape;
final List<NoteFlowchartPort> ports;

final String? fromPortId;
final String? toPortId;
final NoteFlowchartRoutingMode routingMode;
final List<Offset> manualWaypoints;
```

- [ ] **Step 3: Run model tests**

Run: `flutter test test/note_document_test.dart`
Expected: PASS locally when Flutter is available; otherwise push to GitHub Actions.

### Task 2: Replace Palette With Three Logical Elements

**Files:**
- Modify: `lib/src/notes/ui/note_flowchart_editor_screen.dart`
- Test: `test/note_flowchart_editor_screen_test.dart`

- [ ] **Step 1: Write widget test**

Verify the palette shows only universal, binary decision, and multi-branch decision buttons:

```dart
expect(find.byKey(const ValueKey('note-flowchart-palette-universal')), findsOneWidget);
expect(find.byKey(const ValueKey('note-flowchart-palette-binary-decision')), findsOneWidget);
expect(find.byKey(const ValueKey('note-flowchart-palette-multi-decision')), findsOneWidget);
expect(find.byKey(const ValueKey('note-flowchart-palette-subprocess')), findsNothing);
expect(find.byKey(const ValueKey('note-flowchart-palette-dataStore')), findsNothing);
```

- [ ] **Step 2: Implement new palette actions**

Map palette actions to default nodes:

```dart
universal -> kind universal, role normal, visualShape rectangle, ports left/right/top/bottom default pair
binary decision -> kind binaryDecision, visualShape diamond, yes/no ports
multi decision -> kind multiDecision, visualShape diamond, two custom sample ports
```

- [ ] **Step 3: Run palette tests**

Run: `flutter test test/note_flowchart_editor_screen_test.dart`
Expected: PASS.

### Task 3: Add Node Body Popup Editor

**Files:**
- Modify: `lib/src/notes/ui/note_flowchart_editor_screen.dart`
- Test: `test/note_flowchart_editor_screen_test.dart`

- [ ] **Step 1: Write widget test for popup**

Test behavior:

```dart
await tester.tap(find.byKey(const ValueKey('note-flowchart-node-body-node-1')));
await tester.pumpAndSettle();
expect(find.byKey(const ValueKey('note-flowchart-node-popup')), findsOneWidget);
expect(find.byKey(const ValueKey('note-flowchart-node-popup-type-universal')), findsOneWidget);
expect(find.byKey(const ValueKey('note-flowchart-node-popup-add-port-right')), findsOneWidget);
```

Also verify label tap still opens inline editor and not popup.

- [ ] **Step 2: Implement popup bottom sheet**

Add `_openNodeConfig(NoteFlowchartNode node)` that uses `showModalBottomSheet` with:

- segmented logical type control;
- role control: normal/start/end;
- visual shape control;
- port side rows;
- add/delete/rename controls;
- live preview.

Live save through `_emit` after each change.

- [ ] **Step 3: Run popup tests**

Run: `flutter test test/note_flowchart_editor_screen_test.dart`
Expected: PASS.

### Task 4: Make Connections Port-Based And Direction Gesture-Based

**Files:**
- Modify: `lib/src/notes/ui/note_flowchart_editor_screen.dart`
- Modify: `lib/src/notes/models/note_document.dart`
- Test: `test/note_flowchart_editor_screen_test.dart`

- [ ] **Step 1: Write widget test**

Create two universal nodes with side ports. Tap the first node right port, then the second node left port. Assert edge stores `fromPortId` and `toPortId`.

- [ ] **Step 2: Implement port-based connector specs**

Replace fixed input/output behavior with specs generated from node ports. Remove the rule that input cannot be source and output cannot be target.

- [ ] **Step 3: Preserve decision labels**

When source port semantic is yes/no/custom, use that port label as the edge label.

- [ ] **Step 4: Run connection tests**

Run: `flutter test test/note_flowchart_editor_screen_test.dart`
Expected: PASS.

### Task 5: Add Universal Edge Selection And Deletion

**Files:**
- Modify: `lib/src/notes/ui/note_flowchart_editor_screen.dart`
- Test: `test/note_flowchart_editor_screen_test.dart`

- [ ] **Step 1: Write widget test**

Tap an edge label/control for a non-decision edge and delete it. Assert the block edges list is empty.

- [ ] **Step 2: Implement edge hit/label controls**

Keep `_EdgeLabel` but ensure every edge receives a tappable delete affordance. Add label edit if small enough; at minimum deletion must work for every edge.

- [ ] **Step 3: Run edge tests**

Run: `flutter test test/note_flowchart_editor_screen_test.dart`
Expected: PASS.

### Task 6: Implement Orthogonal Back-Edge Routing

**Files:**
- Modify: `lib/src/notes/ui/note_flowchart_editor_screen.dart`
- Test: `test/note_flowchart_editor_screen_test.dart`

- [ ] **Step 1: Write pure routing tests**

Expose a small route helper or annotate painter route classification. Test that a lower-to-upper connection is classified as `backEdge` and produces points that move sideways before moving upward.

- [ ] **Step 2: Implement route helper**

Create helper:

```dart
_FlowchartRoute routeEdge(NoteFlowchartEdge edge, NoteFlowchartNode from, NoteFlowchartNode to, Map<String, Size> sizes)
```

For back-edge: exit sideways, go up outside cards, then enter target.

- [ ] **Step 3: Paint orthogonal paths**

Update `_FlowchartEdgePainter` to draw route points with `Path.moveTo` + `Path.lineTo` and arrow at final segment.

- [ ] **Step 4: Add logs**

Log classification and lane selection when edge routes are computed during edge add or drag commit.

- [ ] **Step 5: Run routing tests**

Run: `flutter test test/note_flowchart_editor_screen_test.dart`
Expected: PASS.

### Task 7: Verify And Commit

**Files:**
- Commit all changed files.

- [ ] **Step 1: Run available tests**

Run targeted Flutter tests if Flutter is available. In this Termux environment, local Flutter builds are not expected to work, so rely on GitHub Actions after push.

- [ ] **Step 2: Commit**

```bash
git add lib/src/notes/models/note_document.dart lib/src/notes/ui/note_flowchart_editor_screen.dart test/note_document_test.dart test/note_flowchart_editor_screen_test.dart docs/superpowers/plans/2026-06-15-flowchart-popup-router-implementation.md
git commit -m "feat: redesign flowchart editor ports"
```

- [ ] **Step 3: Push and verify**

```bash
git push origin feature/knowledge-ocr-inspector
gh run list --branch feature/knowledge-ocr-inspector --limit 1
gh run view <run-id> --json status,conclusion
```

Expected: GitHub Actions succeeds.

## Self-Review

Spec coverage: model, popup editor, connection behavior, edge deletion, back-edge routing, canvas requirements, migration, and debug logging are covered. The first implementation can keep fixed canvas size if full infinite canvas would exceed the current focused editor redesign; routing and ports are the priority.

Placeholder scan: no placeholder items remain.

Type consistency: model names use `NoteFlowchart*` prefix and editor keys use `note-flowchart-*` prefix consistently.
