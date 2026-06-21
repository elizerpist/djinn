# Native Keyboard Selection Rail Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the inline textchunk rail with a native Android keyboard-attached selection rail while keeping Flutter `EditableText` as the visible editor.

**Architecture:** Dart computes active selection/tag range and serializes a `NativeSelectionRailState` to Android. Android renders and animates the rail as a native view driven by `WindowInsetsAnimation.Callback`; rail button taps return action IDs to Dart. `TextChunkCanvasEditor` no longer receives or renders an inline selection rail, but underline line expansion remains.

**Tech Stack:** Flutter/Dart, widget tests with mocked `MethodChannel`, Android Kotlin, Flutter Android embedding v2, GitHub Actions for Android build.

## Global Constraints

- Do not restore the custom-rendered text editor path from `cfc7620`; visible text editing stays native `EditableText`.
- Do not use Flutter `viewInsets` as the final rail animation driver; Android rail must be native and keyboard-animation driven.
- Do not insert rail placeholders or rail spacers into the native text layout.
- Keep collapsed-cursor tagged-range rail behavior.
- Keep ordinary typing in untagged text rail-free.
- Local Flutter APK builds are not expected to work on Termux/Android ARM64; use GitHub Actions for APK verification.

---

## File Structure

- Create `lib/src/notes/ui/native_selection_rail_bridge.dart`: Dart state model, method channel bridge, native action dispatch.
- Modify `lib/src/notes/ui/note_text_chunk_editor_screen.dart`: own native rail controller, send active range state, handle native actions, stop passing `selectionRail` to `TextChunkCanvasEditor`.
- Modify `lib/src/notes/ui/text_chunk_canvas_editor.dart`: remove rail-specific placeholders/widgets while keeping underline spacer behavior.
- Create `android/app/src/main/kotlin/com/elizerpist/djinn/rail/SelectionRailChannels.kt`: channel names.
- Create `android/app/src/main/kotlin/com/elizerpist/djinn/rail/NativeSelectionRailBridge.kt`: Android method handler and native view host.
- Modify `android/app/src/main/kotlin/com/elizerpist/djinn/MainActivity.kt`: register the native rail bridge.
- Create `test/native_selection_rail_bridge_test.dart`: unit tests for state serialization and action callbacks.
- Modify `test/note_text_chunk_editor_screen_test.dart`: replace inline rail expectations with native bridge expectations and assert no rail placeholders.

## Task 1: Dart Native Rail Bridge

**Files:**
- Create: `lib/src/notes/ui/native_selection_rail_bridge.dart`
- Test: `test/native_selection_rail_bridge_test.dart`

**Interfaces:**
- Produces: `NativeSelectionRailController`, `NativeSelectionRailState`, `NativeSelectionRailAction`, `NativeSelectionRailTag`.
- Consumes later: `NoteTextChunkEditorScreen` calls `setStateModel(...)`, `dispose()`, and assigns `onAction`.

- [x] **Step 1: Write failing serialization and action tests**

Add tests that:

```dart
final calls = <MethodCall>[];
messenger.setMockMethodCallHandler(channel, (call) async {
  calls.add(call);
  return null;
});
final controller = NativeSelectionRailController(methodChannel: channel);
await controller.setStateModel(
  NativeSelectionRailState.visible(
    rangeStart: 2,
    rangeEnd: 7,
    tags: const [
      NativeSelectionRailTag(id: 'topic:Alpha', label: 'Alpha', colorValue: 0xFF2563EB),
    ],
    canDeleteTag: true,
    hasTaggedRanges: true,
    bottomRowExpanded: true,
    roundedCard: false,
    greyBackground: false,
    borderVisible: true,
  ),
);
expect(calls.single.method, 'setState');
expect(calls.single.arguments, containsPair('visible', true));
expect(calls.single.arguments, containsPair('rangeStart', 2));
```

Also test native `performAction` calls:

```dart
NativeSelectionRailAction? action;
controller.onAction = (nextAction) => action = nextAction;
await testerBinding.defaultBinaryMessenger.handlePlatformMessage(
  channel.name,
  channel.codec.encodeMethodCall(
    const MethodCall('performAction', {'action': 'indent'}),
  ),
  (_) {},
);
expect(action, NativeSelectionRailAction.indent);
```

- [x] **Step 2: Run bridge tests red**

Run: `flutter test test/native_selection_rail_bridge_test.dart`
Expected: fails because the bridge file does not exist.

- [x] **Step 3: Implement minimal bridge**

Create immutable state/tag classes, action enum parser, `MethodChannel.setMethodCallHandler`, and `setStateModel`/`hide` methods.

- [x] **Step 4: Run bridge tests green**

Run: `flutter test test/native_selection_rail_bridge_test.dart`
Expected: pass.

## Task 2: Text Screen Uses Native Rail State

**Files:**
- Modify: `lib/src/notes/ui/note_text_chunk_editor_screen.dart`
- Test: `test/note_text_chunk_editor_screen_test.dart`

**Interfaces:**
- Consumes: `NativeSelectionRailController`, `NativeSelectionRailState`, `NativeSelectionRailAction`.
- Produces: active rail state sent to native bridge; existing action methods invoked from native callbacks.

- [x] **Step 1: Write failing widget tests**

Add tests with a mocked native rail channel:

- selection sends `visible=true`;
- collapsed cursor inside tagged range sends `visible=true`;
- typing ordinary untagged text sends `visible=false`;
- native action `indent` changes paragraph indentation through existing `_changeParagraphIndent`;
- inline rail widget is absent.

- [x] **Step 2: Run targeted tests red**

Run: `flutter test test/note_text_chunk_editor_screen_test.dart`
Expected: new tests fail because the screen still renders inline rail and has no native bridge.

- [x] **Step 3: Wire controller into screen**

Instantiate `NativeSelectionRailController`, assign `onAction`, update native state from `_updateSelectionState`, `_handleControllerChanged`, range tag mutations, style toggles, and `dispose()`.

- [x] **Step 4: Replace inline rail output**

Pass `selectionRail: null` to `TextChunkCanvasEditor`. Use `_activeRailRange` only for native rail state and selected-tag action state.

- [x] **Step 5: Run targeted tests green**

Run: `flutter test test/note_text_chunk_editor_screen_test.dart test/native_selection_rail_bridge_test.dart`
Expected: pass.

## Task 3: Remove Inline Rail From Text Canvas

**Files:**
- Modify: `lib/src/notes/ui/text_chunk_canvas_editor.dart`
- Test: `test/note_text_chunk_editor_screen_test.dart`, `test/text_chunk_layout_model_test.dart`

**Interfaces:**
- Consumes: no `selectionRail` use from screen.
- Produces: no rail-line placeholders or inline rail widgets; underline spacer code remains.

- [x] **Step 1: Write or update regression assertions**

Assert there is no `note-text-inline-selection-rail`, no `note-text-inline-selection-spacer`, and logs do not include `rail-line-` or nonzero `placeholderDelta` for rail cases. Keep existing underline tests passing.

- [x] **Step 2: Run tests red if inline rail remains**

Run: `flutter test test/note_text_chunk_editor_screen_test.dart`
Expected: fails while inline rail code remains.

- [x] **Step 3: Remove rail placeholder/widget code**

Delete rail target spacer, rail native spacer, rail placeholder creation, inline rail `Positioned` widgets, and rail-specific line marker offsets. Keep underline placeholder planning.

- [x] **Step 4: Run tests green**

Run: `flutter test test/note_text_chunk_editor_screen_test.dart test/text_chunk_layout_model_test.dart`
Expected: pass.

## Task 4: Android Native Rail Host

**Files:**
- Create: `android/app/src/main/kotlin/com/elizerpist/djinn/rail/SelectionRailChannels.kt`
- Create: `android/app/src/main/kotlin/com/elizerpist/djinn/rail/NativeSelectionRailBridge.kt`
- Modify: `android/app/src/main/kotlin/com/elizerpist/djinn/MainActivity.kt`

**Interfaces:**
- Consumes: method channel `djinn.selection_rail/native`, method `setState`, native action method `performAction`.
- Produces: native keyboard-attached rail view with action buttons and tag pills.

- [x] **Step 1: Add native channel registration**

Register `NativeSelectionRailBridge(this, flutterEngine.dartExecutor.binaryMessenger)` from `MainActivity.configureFlutterEngine`.

- [x] **Step 2: Implement state parsing and native view**

Use a `FrameLayout` container added to `android.R.id.content`. Render action buttons with fixed IDs matching Dart enum names. Render tag pills from serialized `tags`.

- [x] **Step 3: Implement keyboard-synchronized positioning**

On Android R+, install `WindowInsetsAnimation.Callback(DISPATCH_MODE_CONTINUE_ON_SUBTREE)` on the content root. On each `onProgress`, read `WindowInsets.Type.ime()` bottom and position the native rail against the keyboard top in the same native frame. Also handle `onApplyWindowInsets` fallback for non-animated or older paths.

- [ ] **Step 4: Compile through CI**

Local Android build is not required on Termux. GitHub Actions must compile Kotlin and build the APK.

## Task 5: Verification, Checklist, Commit, Push

**Files:**
- Modify: `docs/superpowers/specs/2026-06-22-native-keyboard-selection-rail-design.md`
- Modify: `docs/superpowers/plans/2026-06-22-native-keyboard-selection-rail.md`

**Interfaces:**
- Consumes: NKR acceptance checklist.
- Produces: verified branch and Android debug APK.

- [x] **Step 1: Run available local checks**

Run what works locally. If Flutter fails due Termux TLS alignment, record that exact limitation and rely on Actions.

- [ ] **Step 2: Commit and push**

Commit focused implementation and tests. Push `fix/textchunk-rail-dynamic-spacing`.

- [ ] **Step 3: Trigger GitHub Actions**

Run Android native build workflow on the branch. Wait for success or inspect logs and fix failures.

- [ ] **Step 4: Update checklist**

Mark NKR-001 through NKR-009 honestly based on tests, inspection, and Actions. Do not mark complete if any required behavior is unverified.
