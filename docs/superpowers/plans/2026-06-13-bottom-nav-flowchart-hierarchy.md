# Bottom Nav And Flowchart Hierarchy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the selectable `Hamburger` / `Bottom navigation` app shell and upgrade extracted flowcharts from flat node/edge lists into source-backed, icon-coded, hierarchical flow views.

**Architecture:** Keep the current drawer behavior as the default and add an opt-in bottom-nav shell driven by `AppSettings.navigationMode`. Add `cases/` as a focused feature slice backed by ObjectBox. Extend flowchart extraction metadata without changing the chunking workflow: AI clients parse richer node/edge shape/order data, repositories persist it, and knowledge/validation UIs render a logical hierarchy with inherited Tailwind-style color stripes.

**Tech Stack:** Flutter Material 3, ObjectBox, existing `AiClient` extraction contracts, existing knowledge/flowchart repositories, Flutter widget tests, ObjectBox generator via `dart run build_runner build`.

---

## File Map

- Modify: `lib/src/settings/models/app_settings.dart`
- Modify: `lib/src/local_store/entities.dart`
- Generated: `lib/objectbox.g.dart`, `lib/objectbox-model.json`
- Modify: `lib/src/settings/data/app_settings_repository.dart`
- Modify: `lib/src/settings/ui/settings_screen.dart`
- Create: `lib/src/cases/models/case_workspace.dart`
- Create: `lib/src/cases/data/case_repository.dart`
- Create: `lib/src/cases/ui/cases_screen.dart`
- Create: `lib/src/chat/ui/app_destination.dart`
- Modify: `lib/src/chat/ui/main_screen.dart`
- Modify: `lib/main.dart`
- Modify: `lib/src/ai/ai_client.dart`
- Modify: `lib/src/google/gemini_http_client.dart`
- Modify: `lib/src/openai/openai_http_client.dart`
- Modify: `lib/src/knowledge/data/objectbox_knowledge_repository.dart`
- Modify: `lib/src/flowchart/models/flowchart_view_model.dart`
- Create: `lib/src/flowchart/models/flowchart_hierarchy.dart`
- Create: `lib/src/flowchart/ui/flowchart_symbol.dart`
- Create: `lib/src/flowchart/ui/flowchart_hierarchy_view.dart`
- Modify: `lib/src/knowledge/ui/extracted_knowledge_screen.dart`

## Task 1: Navigation Mode Settings

**Files:** `app_settings.dart`, `entities.dart`, `app_settings_repository.dart`, `settings_screen.dart`, `settings_repository_test.dart`, `settings_screen_test.dart`.

- [ ] **Step 1: Write the failing tests**

```dart
expect(AppSettings.defaults().navigationMode, NavigationMode.drawer);
expect(
  AppSettings.defaults()
      .copyWith(navigationMode: NavigationMode.bottomNav)
      .navigationMode,
  NavigationMode.bottomNav,
);

final settings = AppSettings.defaults().copyWith(
  navigationMode: NavigationMode.bottomNav,
);
await repository.save(settings);
final loaded = await repository.load();
expect(loaded.navigationMode, NavigationMode.bottomNav);
```

- [ ] **Step 2: Verify red**

```bash
flutter test test/settings_repository_test.dart
```

Expected: compile failure because `NavigationMode` and `navigationMode` do not exist.

- [ ] **Step 3: Write minimal implementation**

Add `NavigationMode`, thread `navigationMode` through settings/entity/repository, and regenerate ObjectBox:

```bash
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 4: Write failing settings UI test**

```dart
expect(find.text('Megjelenés'), findsOneWidget);
expect(find.text('Navigáció'), findsOneWidget);
await tester.tap(find.text('Bottom navigation'));
await tester.pumpAndSettle();
expect(settings.navigationMode, NavigationMode.bottomNav);
```

- [ ] **Step 5: Implement settings UI**

Add `Megjelenés` above AI with `SegmentedButton<NavigationMode>` options `Hamburger` and `Bottom navigation`, autosaved through `_autoSave`.

- [ ] **Step 6: Verify green**

```bash
flutter test test/settings_repository_test.dart test/settings_screen_test.dart
```

## Task 2: Cases Data And UI

**Files:** `entities.dart`, `case_workspace.dart`, `case_repository.dart`, `cases_screen.dart`, `main.dart`, `case_repository_test.dart`, `cases_screen_test.dart`.

- [ ] **Step 1: Write failing case repository tests**

```dart
final created = await repository.createCase(title: 'Új eset');
expect((await repository.listCases()).single.title, 'Új eset');
await repository.updateNotes(created.id, 'ABCDE megfigyelés');
await repository.linkChat(created.id, 'chat-1');
await repository.linkDocument(created.id, 'doc-1');
final updated = (await repository.listCases()).single;
expect(updated.notes, 'ABCDE megfigyelés');
expect(updated.linkedChatCount, 1);
expect(updated.linkedDocumentCount, 1);
```

- [ ] **Step 2: Verify red**

```bash
flutter test test/case_repository_test.dart
```

- [ ] **Step 3: Implement case entities/repository**

Add `CaseEntity`, `CaseChatLinkEntity`, `CaseDocumentLinkEntity`, `CaseWorkspace`, `MemoryCaseRepository`, `ObjectBoxCaseRepository`, and methods:

```dart
Future<CaseWorkspace> createCase({String title = 'Új eset'});
Future<List<CaseWorkspace>> listCases();
Future<CaseWorkspace> updateNotes(String caseId, String notes);
Future<void> linkChat(String caseId, String chatThreadId);
Future<void> linkDocument(String caseId, String documentId);
```

- [ ] **Step 4: Regenerate ObjectBox**

```bash
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 5: Write failing case UI tests**

```dart
expect(find.text('Nincs mentett eset'), findsOneWidget);
await tester.tap(find.byTooltip('Új eset'));
await tester.pumpAndSettle();
expect(find.text('Új eset'), findsOneWidget);
```

- [ ] **Step 6: Implement `CasesScreen`**

Use a white app bar style, 8px row cards, FAB above bottom nav, and a detail screen with notes `TextField`.

- [ ] **Step 7: Verify green**

```bash
flutter test test/case_repository_test.dart test/cases_screen_test.dart
```

## Task 3: Drawer/Bottom-Nav Shell

**Files:** `app_destination.dart`, `main_screen.dart`, `main.dart`, `main_screen_navigation_test.dart`, `widget_test.dart`.

- [ ] **Step 1: Write failing shell tests**

```dart
expect(find.byType(Drawer), findsOneWidget);
expect(find.byType(NavigationBar), findsNothing);

settings = AppSettings.defaults().copyWith(
  navigationMode: NavigationMode.bottomNav,
);
expect(find.byType(NavigationBar), findsOneWidget);
expect(find.text('Esetek'), findsOneWidget);
expect(find.text('Tudástár'), findsOneWidget);
expect(find.text('Chat'), findsOneWidget);
expect(find.text('Flow'), findsOneWidget);
expect(find.text('Beáll.'), findsOneWidget);

await tester.tap(find.text('Flow'));
await tester.pumpAndSettle();
expect(find.textContaining('Flowchart validáció nem elérhető'), findsOneWidget);
```

- [ ] **Step 2: Verify red**

```bash
flutter test test/main_screen_navigation_test.dart
```

- [ ] **Step 3: Implement destination descriptors and shell**

Create `AppDestinationId { cases, knowledge, chat, flow, settings }`, keep the drawer default, add the five-item `NavigationBar`, render Chat FAB only on Chat, and add Flow unavailable state when repository is null.

- [ ] **Step 4: Wire case repository**

Add `caseRepository` dependency in `DjinnApp` and `MainScreen`.

- [ ] **Step 5: Verify green**

```bash
flutter test test/main_screen_navigation_test.dart test/widget_test.dart
```

## Task 4: Rich Flowchart Schema And Persistence

**Files:** `ai_client.dart`, `gemini_http_client.dart`, `openai_http_client.dart`, `entities.dart`, `objectbox_knowledge_repository.dart`, `flowchart_validation_repository.dart`, Gemini/OpenAI/repository tests.

- [ ] **Step 1: Write failing parser tests**

Use structured JSON containing:

```json
{
  "id": "n-medication",
  "label": "Kompetencia esetén: gyógyszerelés",
  "shape": "process",
  "order": 4,
  "source_rect": {"x": 0.52, "y": 0.44, "width": 0.22, "height": 0.08}
}
```

Assert:

```dart
expect(result.flowcharts.single.nodes.single.shape, FlowchartNodeShape.process);
expect(result.flowcharts.single.nodes.single.order, 4);
expect(result.flowcharts.single.nodes.single.sourceRectJson, contains('0.52'));
```

- [ ] **Step 2: Verify red**

```bash
flutter test test/gemini_http_client_test.dart test/openai_client_test.dart
```

- [ ] **Step 3: Implement AI flowchart metadata**

Add `FlowchartNodeShape` and optional `shape`, `order`, `sourceRectJson` fields. Supported shapes: `terminator`, `process`, `decision`, `input_output`, `subprocess`, `database`, `connector`, `unknown`.

- [ ] **Step 4: Update schemas and prompts**

Require `shape` and `order` for nodes, optional nullable `source_rect`, and `order` for edges. Prompt explicitly says visible medication/process boxes in image flowcharts must be extracted.

- [ ] **Step 5: Persist metadata**

Add ObjectBox fields and save/read them from `saveFlowchartCandidate`, `listNodes`, `listEdges`, and extracted knowledge items. Regenerate ObjectBox.

- [ ] **Step 6: Verify green**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/gemini_http_client_test.dart test/openai_client_test.dart test/knowledge_document_repository_test.dart
```

## Task 5: Flowchart Hierarchy Renderer

**Files:** `flowchart_hierarchy.dart`, `flowchart_symbol.dart`, `flowchart_hierarchy_view.dart`, `extracted_knowledge_screen.dart`, `simple_flowchart_editor.dart`, hierarchy/UI tests.

- [ ] **Step 1: Write failing hierarchy builder tests**

Input graph:

```dart
start -> decision;
decision -(igen)-> oxygen;
oxygen -> reassess;
reassess -(igen)-> hospital;
decision -(nem)-> exam;
```

Assert row order:

```dart
['Start', 'Légzési elégtelen?', 'igen', 'Oxigén', 'Újraértékelés', 'igen', 'Kórházba szállítás', 'nem', 'További vizsgálat']
```

Assert inherited color slots:

```dart
expect(rows[3].colorSlotChain, ['slot-0', 'slot-1']);
expect(rows[5].colorSlotChain, ['slot-0', 'slot-1', 'slot-2']);
```

- [ ] **Step 2: Verify red**

```bash
flutter test test/flowchart_hierarchy_test.dart
```

- [ ] **Step 3: Implement deterministic hierarchy builder**

Use incoming degree to find starts, sort by explicit `order` then label, walk depth-first, insert branch rows for labeled edges, and guard cycles with a visited edge set.

- [ ] **Step 4: Write failing UI tests**

```dart
expect(find.byIcon(Icons.radio_button_unchecked), findsWidgets);
expect(find.text('Légzési elégtelen?'), findsOneWidget);
expect(find.text('igen'), findsOneWidget);
expect(find.byKey(const Key('flowchart-color-palette')), findsNothing);
await tester.longPress(find.text('Légzési elégtelen?'));
await tester.pumpAndSettle();
expect(find.byKey(const Key('flowchart-color-palette')), findsOneWidget);
```

- [ ] **Step 5: Implement flowchart UI**

Render grouped flowchart cards with shape icons, edge rows, left inherited color stripe stack, Tailwind palette sheet on long press, and shared color slots.

- [ ] **Step 6: Verify green**

```bash
flutter test test/flowchart_hierarchy_test.dart test/extracted_knowledge_screen_test.dart test/flowchart_validation_test.dart
```

## Task 6: Integrated Verification, Commit, Push, Online Build

- [ ] **Step 1: Run focused tests**

```bash
flutter test test/settings_repository_test.dart test/settings_screen_test.dart test/case_repository_test.dart test/cases_screen_test.dart test/main_screen_navigation_test.dart test/gemini_http_client_test.dart test/openai_client_test.dart test/knowledge_document_repository_test.dart test/flowchart_hierarchy_test.dart test/extracted_knowledge_screen_test.dart test/flowchart_validation_test.dart test/widget_test.dart
```

- [ ] **Step 2: Run analyzer**

```bash
flutter analyze
```

- [ ] **Step 3: Commit and push**

```bash
git add .
git commit -m "feat: add selectable navigation shell"
git commit -m "feat: structure flowchart extraction hierarchy"
git push origin feature/knowledge-ocr-inspector
```

- [ ] **Step 4: Read GitHub Actions**

Use the existing online workflow. Do not run local APK build on Termux. Return the direct debug APK URL after the online build succeeds.

## Self-Review

- Spec coverage: navigation setting persistence, settings UI, drawer preservation, bottom nav order, Flow unavailable state, Cases data/UI, richer flowchart extraction, source-backed hierarchy UI, color slots, tests, commit/push/build.
- Known intentional limit: automatic speaker barge-in stays reverted to the previously working button-triggered interrupt workflow; this plan does not re-enable automatic barge-in.
- Placeholder scan: no `TBD` or unassigned implementation steps remain.
