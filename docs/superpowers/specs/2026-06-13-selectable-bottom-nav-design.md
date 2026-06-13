# Selectable Bottom Nav Design

Date: 2026-06-13

## Goal

Add a user-selectable main navigation layout to Djinn without removing the
current hamburger drawer. The user can choose between:

- `Hamburger` - the current drawer-based layout.
- `Bottom navigation` - a five-item Material bottom navigation shell.

The selected bottom navigation order is fixed:

1. `Esetek`
2. `Tudástár`
3. `Chat`
4. `Flow`
5. `Beállítások`

`Esetek` is the new leftmost app expansion area. It starts as the entry point
for saved cases, notes, linked chats, and linked source PDFs.

## Context

`MainScreen` currently owns the top-level Flutter UI. It uses a `Scaffold` with
a `Drawer`, a white `AppBar`, a conversation list body, and a FAB for creating a
new chat. Top-level module access is currently:

- `Beszélgetések` in the drawer, which closes the drawer and stays on the chat
  list.
- `Tudástár`, pushed as `KnowledgeBaseScreen`.
- `Flowchart validáció`, pushed as `FlowchartValidationScreen` when the
  repository is available.
- `Beállítások`, pushed as `SettingsScreen`.

`AppSettings` already stores voice/runtime and AI behavior fields. It should not
reuse `runtimeMode` for navigation. Navigation needs its own setting so voice
mode and UI layout remain independent.

The app also has a global debug floating button. Bottom navigation must leave
space for that overlay and for screen-specific FABs.

## User-Visible Success Criteria

1. The existing hamburger drawer remains available and behaves as it does now.
2. Settings includes a `Megjelenés` section with a `Navigáció` segmented choice:
   `Hamburger` and `Bottom navigation`.
3. The selected navigation mode persists across app launches.
4. In bottom navigation mode, the visible order is exactly:
   `Esetek`, `Tudástár`, `Chat`, `Flow`, `Beállítások`.
5. `Chat` is the center item and opens the current conversation list.
6. `Beállítások` is the rightmost item.
7. `Flow` is still visible even when the flowchart repository is unavailable;
   the tab shows an unavailable state instead of crashing or disappearing.
8. The debug floating button and per-screen FABs do not overlap the bottom nav.
9. Switching modes does not lose conversations, imported PDFs, settings, or
   flow validation state.

## Scope

In scope for this spec:

- Persisting a navigation mode setting.
- Adding the settings UI for choosing the navigation mode.
- Refactoring the top-level shell so it can render either drawer mode or bottom
  navigation mode.
- Preserving the current drawer behavior.
- Adding the five-item bottom navigation shell.
- Adding an `Esetek` destination as the new leftmost tab.
- Defining the initial `Esetek` data model and screen behavior so the tab has a
  clear product direction.

Out of scope for the first implementation plan:

- Replacing the existing knowledge-base redesign spec.
- Changing AI provider/model settings beyond the new navigation control.
- Reworking chat message UI.
- Full clinical case validation workflows.
- Cloud sync or account-based case sharing.
- Local APK builds on Termux/Android; APK builds still run through GitHub
  Actions.

## Navigation Setting

Add a navigation enum:

- `drawer`
- `bottom_nav`

Default value: `drawer`.

Rationale: defaulting to `drawer` preserves the current app behavior for
existing users and keeps the new layout opt-in.

The setting should live in `AppSettings` as a separate `navigationMode` field
and persist through `AppSettingsRepository` and `AppSettingsEntity`. Legacy
settings without this field load as `drawer`. Unknown stored values also fall
back to `drawer`.

Settings UI:

- Section title: `Megjelenés`.
- Control label: `Navigáció`.
- Segmented options:
  - `Hamburger`
  - `Bottom navigation`

The control should save immediately, like the existing switch settings. In
drawer mode, the shell applies the new navigation mode after the settings route
is popped. In bottom navigation mode, the settings tab reports the completed
save to the shell; if the user selects `Hamburger`, the shell switches to drawer
mode and returns to the chat home.

## Shell Design

Introduce a top-level shell concept that can render the same destinations in two
forms:

- Drawer shell.
- Bottom navigation shell.

Use one destination model rather than duplicating labels and icons across
drawer and bottom nav code.

Destinations:

| Destination | Label | Icon Intent | Availability |
| --- | --- | --- | --- |
| Cases | `Esetek` | note/case/work item | Always visible |
| Knowledge | `Tudástár` | folder/PDF library | Always visible |
| Chat | `Chat` | chat bubble | Always visible |
| Flow | `Flow` | account tree/flowchart | Visible; may show unavailable state |
| Settings | `Beállítások` | settings | Always visible |

Drawer mode can keep the current `Djinn` header and `Local ObjectBox mód`
subtitle. The drawer should add `Esetek` as a top-level item so both navigation
modes expose the same modules.

Bottom navigation mode should use Flutter's Material 3 `NavigationBar`. It must
respect the phone safe area and keep labels readable. If `Beállítások` is too
long on narrow screens, the visual label may use `Beáll.` while
tooltip/accessibility text remains `Beállítások`.

## Destination Behavior

### Chat

`Chat` is the center bottom-nav item and maps to the current conversation list.
The existing `Új chat` FAB remains available only on the chat destination.
Opening a conversation continues to push `ChatScreen` as a detail route.

### Tudástár

`Tudástár` opens the knowledge-base list as a top-level destination in bottom
nav mode. To avoid nested scaffolds, extract the reusable knowledge content from
`KnowledgeBaseScreen` into a content widget or equivalent composition. The
existing full-screen `KnowledgeBaseScreen` can remain as the route used by
drawer mode until the drawer shell is refactored further.

### Flow

`Flow` opens flowchart validation as a top-level destination in bottom nav mode.
If `flowchartValidationRepository` is null, the tab shows a compact unavailable
state with no destructive action. Drawer mode may keep the current disabled row.

### Beállítások

`Beállítások` opens settings as a top-level destination in bottom nav mode.
Avoid nested scaffolds by extracting reusable settings content from
`SettingsScreen`, while keeping `SettingsScreen` as a route wrapper for drawer
mode.

### Esetek

`Esetek` is the new leftmost destination. It is the app's saved work area:
case-like workspaces combining notes, linked chats, linked PDFs, and later
exportable summaries.

Initial screen behavior:

- Empty state when no cases exist.
- List of saved cases when cases exist.
- Each case row shows title, updated time, note preview, linked chat count, and
  linked PDF count.
- FAB creates a new case.
- Opening a case shows an editable note area and link sections for chats and
  PDFs.

Initial data model:

- `CaseEntity`
  - public id;
  - title;
  - notes text;
  - created timestamp;
  - updated timestamp;
  - optional archived flag.
- `CaseChatLinkEntity`
  - case public id;
  - chat thread public id.
- `CaseDocumentLinkEntity`
  - case public id;
  - knowledge document public id.

This keeps `Esetek` useful without coupling it to RAG processing or clinical
validation rules. Later iterations can add generated summaries, export, search,
tags, and case-specific RAG filters.

## Layout Details

Bottom navigation mode:

- The selected destination body fills the available space above the nav bar.
- Screen-specific FABs float above the bottom nav and safe area.
- The global debug floating button shifts above the bottom nav and any active
  screen FAB to prevent overlap.
- Top app bars should remain simple and white, matching the existing style.
- Use the existing Material 3 theme and seed color.

Drawer mode:

- Preserve the current visual behavior.
- Add `Esetek` to the drawer item list.
- Keep `Tudástár`, `Flowchart validáció`, and `Beállítások` behavior compatible
  with current routes unless a shared shell refactor makes inline destinations
  cleaner.

## Data Flow

App startup:

1. Load dependencies as today.
2. Load `AppSettings`.
3. Pass the current navigation mode into `MainScreen` or a new shell widget.
4. Render drawer shell or bottom-nav shell.

Settings update:

1. User changes `Navigáció` in settings.
2. The app saves the updated `AppSettings`.
3. The shell reloads settings or receives an update callback.
4. The shell rebuilds using the selected navigation mode.

Cases:

1. `Esetek` loads saved case summaries from local ObjectBox.
2. Creating a case inserts a local case record.
3. Editing notes updates the case and timestamp.
4. Linking chats or PDFs creates link records without copying the original
   chat/document data.

## Error Handling

- Missing or unknown navigation mode values fall back to `drawer`.
- Settings save failure shows the same kind of inline status message as current
  settings errors.
- Flow unavailable state is non-fatal and does not remove the bottom nav item.
- Case load/save failures show a local error state and log to the debug console
  without exposing sensitive content.
- ObjectBox migration errors should fail visibly during app startup rather than
  silently discarding cases or settings.

## Testing

Focused tests should cover:

- `AppSettings.defaults()` uses `drawer`.
- Stored `bottom_nav` round-trips through `AppSettingsRepository`.
- Unknown stored navigation values fall back to `drawer`.
- Settings UI shows the `Megjelenés` / `Navigáció` control.
- Choosing `Bottom navigation` calls `saveSettings` with `bottom_nav`.
- Drawer mode renders the drawer and does not render the bottom nav.
- Bottom navigation mode renders five destinations in the required order.
- Tapping `Chat`, `Tudástár`, `Flow`, `Beállítások`, and `Esetek` changes the
  active destination.
- Flow unavailable state appears when the repository is null.
- Chat FAB appears on `Chat` and not on unrelated top-level destinations.
- Case repository can create, list, update, and link cases to existing chat and
  document ids.

## Implementation Boundaries

Keep the implementation split into small units:

- `settings/models/app_settings.dart` owns `NavigationMode`.
- `settings/data/app_settings_repository.dart` maps it to ObjectBox.
- `chat/ui/main_screen.dart` or a new shell file owns top-level navigation.
- Reusable destination descriptors own labels, icons, and availability.
- `cases/` owns case models, repository, and UI.
- Existing knowledge, flow, and settings screens expose reusable content widgets
  only if needed to avoid nested scaffolds.

Do not mix the new navigation setting into voice/runtime mode. Do not refactor
RAG processing, PDF ingestion, or AI provider behavior as part of this feature.
