# Tag Sheet Redesign

Date: 2026-06-21
Status: design approved for implementation planning

## Context

The notes editor has a tag manager sheet for applying knowledge tags to selected note content. The old sheet duplicated tag state across separate active and saved tag containers, exposed a user-facing tag type dropdown, and relied on explicit save behavior. The redesigned sheet should match the interaction model validated in the browser preview at `/data/data/com.termux/files/home/tag-sheet-code-preview/index.html`.

This spec applies to the tag sheet opened from selected text/list/table/flowchart scope rails and from whole-chunk/global tag entry points. It does not redesign note folders or file organization folders. Those remain file organization. Tags are semantic markers for words, sentences, selected ranges, list items, table cells/scopes, or flowchart elements. The tag sheet may have tag folders, but those are only saved-tag organization/filtering groups inside the tag registry and are separate from note/file folders.

## Product Model

A user-facing tag is only:

- name;
- color slot;
- optional tag folder;
- active/inactive state for the current target.

The normal user flow must not require choosing a category/type. Internally, the app may continue storing tags with a default type such as `custom` for backwards compatibility, but the type field is not shown in the sheet and is not part of the user's decision.

The target scope is separate from the tag itself. The system knows whether the tag was applied to a text range, list item, table cell/scope, flowchart node, flowchart edge, or whole chunk. The user should not have to encode that target as a tag type.

## Sheet Layout

The sheet is a bottom sheet with a maximum height capped at the bottom of the Android status bar / safe area. This existing maximum-height behavior remains.

The sheet has four vertical regions:

1. Header: title and close button.
2. Fixed tag folder bar: horizontal filter/drop-target strip.
3. Tag pill area: one adaptive wrapping container for the filtered tags.
4. Fixed editor area: name field, color palette, and `Új tag hozzáadása` button.

The entire sheet must not become one scroll view. Only the tag pill area scrolls when needed.

The tag folder bar is fixed at the top of the sheet under the header. It is not part of the pill scroll region. If the sheet expands to its maximum height, this folder bar remains at the top of the expanded sheet, directly under the status-bar/safe-area-capped top edge.

The fixed editor area is always visible. It is anchored to the bottom of the sheet and is not part of the tag pill scroll region.

When there are few tags, the sheet should be only as tall as its content requires. When more tags are added, the sheet height grows until it reaches its maximum allowed height. After that, additional tag overflow is handled by scrolling only the tag pill area.

## Keyboard Behavior

When the user focuses the name field and the Android keyboard opens, the sheet moves with the visible viewport so the fixed editor area sits directly above the keyboard.

The sheet must still respect the same maximum top boundary: it may slide upward, but it must not extend beyond the status bar / safe area cap. If the keyboard leaves insufficient room for all tags, the pill area scrolls.

Implementation should use Flutter's keyboard/viewInsets behavior for the production app. The browser preview used `visualViewport` only to model the same behavior in HTML.

## Tag Folder Bar

The sheet includes a fixed horizontal tag folder bar directly below the header and above the tag pill area.

The folder bar contains, in this order:

- `Összes`: shows every tag and is not a drop target;
- `Mappa nélkül`: shows tags that have no tag folder and is a drop target that clears a tag's folder;
- `Új mappa`: creates a new tag folder and switches the sheet to it;
- user-created tag folders.

The folder bar scrolls horizontally when needed. It is fixed relative to the sheet and never scrolls with the tag pill area.

Selecting a folder filters the pill area to that folder. `Összes` shows all tags. `Mappa nélkül` shows only tags whose `folderId` is null/empty.

Tag pills are draggable. Dropping a pill on a user-created tag folder moves that tag into the folder. Dropping a pill on `Mappa nélkül` removes the tag's folder assignment. `Összes` is only a filter and must not accept drops.

New tags are created in the active concrete tag folder. If the active view is `Összes` or `Mappa nélkül`, the new tag is created without a folder.

Tag folders are organization metadata for reusable tags only. They must not affect whether a tag is active on the current note target and must not affect retrieval semantics.

## Tag Pill Area

There is exactly one tag container in the sheet. Do not render separate containers for active tags and saved tags.

All reusable tags appear in the same adaptive wrapping layout. The layout may reorder/wrap based on pill dimensions to use the smallest practical vertical space, as in the current adaptive behavior.

Every tag is rendered as a full-color rail-style pill:

- the whole pill uses the tag color as its background;
- text is white and compact;
- shape matches the rail/global tag capsule style;
- no avatar-dot plus grey chip design;
- no `topic:`, `custom:`, or other type prefix is shown.

Active state is represented by opacity:

- active on the current target: full opacity;
- inactive for the current target: reduced opacity.

Tapping the tag name area toggles the tag for the current target. Toggle changes are applied immediately.

## Pill Actions

Each tag pill contains its actions inside the pill on the right side:

- pencil icon: edit the tag name/color in the fixed editor area;
- `x` icon: delete the tag from the reusable tag list and remove it from the current target if active.

The pencil and `x` are inside the colored pill, not outside it.

Deleting a reusable tag from the sheet must not silently rewrite unrelated existing note content outside the current editing target. If a later global-delete-all-usages feature is needed, it must be a separate explicit action with confirmation.

## Fixed Editor Area

The fixed bottom editor area contains:

- `Név` text field;
- color palette using the existing tag color slots;
- `Új tag hozzáadása` button.

There is no `Mentés` button. All changes are immediate.

There is no pill-row plus button. New tag creation is done with the bottom `Új tag hozzáadása` button.

When the user enters a name and taps `Új tag hozzáadása`:

- if not editing an existing tag, create a new reusable tag in the active concrete tag folder, or without a folder when the active view is `Összes`/`Mappa nélkül`;
- immediately activate the new tag for the current target;
- if editing an existing tag, update the reusable tag's name/color slot;
- editing an inactive tag does not activate it for the current target;
- if the edited tag was active on the current target, keep the updated tag active;
- preserve the tag's existing folder when editing;
- clear the name field after successful add/update;
- advance the selected color slot to the next unused slot where practical.

Pressing enter/done in the name field should perform the same add/update action.

## Auto-Save Semantics

The sheet has no explicit final save action. The following operations apply immediately to the current target:

- tapping an inactive tag pill to activate it;
- tapping an active tag pill to deactivate it;
- creating a new tag;
- editing an active tag;
- editing an inactive tag, which updates only the reusable tag definition;
- deleting an active tag;
- deleting an inactive tag, which removes only the reusable tag definition from the sheet registry;
- deleting all tags from the current target through the rail clear action.

Closing the sheet does not commit or discard pending tag changes because there should be no pending changes. The only exception is partially typed text in the name field that has not been added; closing the sheet discards that draft text.

## Rail And Highlight Integration

The sheet pill design must visually match the rail tag pills. The rail remains the place where selected-target actions live. The sheet is only for choosing, creating, editing, deleting, and organizing reusable tags for the current target.

All visual tag rendering in the app must resolve tag name and color through the central tag database. The persisted target assignment should point to tag identity, not duplicate display name/color values as the source of truth.

After a sheet change, every visible usage of that tag updates immediately from the central tag database:

- sheet pill rows;
- selected-scope rail pill rows;
- global chunk tag capsules;
- note preview tag capsules;
- text chunk primary highlight and secondary underline rendering;
- list chunk tag feedback;
- table cell/row/column effective tag feedback;
- flowchart node outlines;
- flowchart edge/line tag coloring;
- flowchart edit-card node/branch tag feedback;
- source/read-only previews that show tag colors or tag names.

For multi-tag text feedback, keep the existing rule: primary tag controls background highlight, secondary tags render as underline layers. The sheet redesign does not change multi-tag rendering rules outside the sheet; it changes where the name/color are resolved from.

## Tag Database And Color Slots

Reusable tags must live in a central local database table/store owned by the app. The tag sheet reads from and writes to this database. Other app surfaces that display tags must also read tag metadata from this database instead of relying on duplicated name/color snapshots inside chunk data.

Each reusable tag record stores at least:

- stable tag id;
- display name/label;
- color slot id;
- optional tag folder id;
- default normalized type for compatibility, preferably `custom`;
- created/updated timestamps if the local data layer normally tracks them.

Color handling is slot-based. The database stores the tag's color slot id, not an arbitrary per-assignment color value. The actual color value is resolved through the app's slot palette. The current `noteTagColorSlots` palette can be the initial slot set, but persisted tags should reference slots rather than copying color integers into every usage.

When the user changes a tag's color in the sheet, the tag record receives a new color slot id. Every app surface that renders that tag reads the updated slot and immediately shows the new color. The same rule applies to name changes: change the tag record once, and all surfaces render the new name.

Scoped tag assignments should store references to tag ids. They must not be the source of truth for tag name, color, or folder. Existing data that stores embedded `NoteKnowledgeTag` values should be migrated or resolved through a compatibility layer so old notes still render, but new writes should use tag id references plus the central tag registry.

Duplicate visible labels should not be created in the same tag database unless a future explicit duplicate-name design exists. If a duplicate label is added, update/select the existing tag rather than creating another visually identical pill.

Tag folders are stored in the same tag database layer or a directly related local table/store. Moving a tag between folders updates only that tag's folder id. It does not rewrite target assignments.

## Data Compatibility

Existing `NoteKnowledgeTag` storage can remain readable through a migration/compatibility path:

- embedded labels become or resolve to central tag records;
- embedded `colorValue` values map to the nearest/existing color slot where possible;
- user-created tags continue to use a default normalized type, preferably `custom`;
- scoped target storage keeps the same target kinds, but new tag assignments should reference central tag ids;
- retrieval/search metadata should continue to receive the tag label/type text it needs, resolved from the central tag record.

## Non-Goals

Do not redesign note folders, collections, or file organization. Tag folders are allowed only inside the tag sheet/tag database as reusable-tag organization.

Do not add tag categories back into the normal sheet UI.

Do not add a separate active tag container.

Do not add a separate saved tag container.

Do not add a `Mentés` button.

Do not put edit/delete buttons outside the pill.

Do not make the fixed editor area scroll away with the pill list.

Do not make the whole sheet scroll when only the pill area overflows.

Do not store tag color/name as the authoritative value separately in every target assignment.

Do not make tag folders affect retrieval semantics or note/file organization.

## Acceptance Criteria

- The sheet shows one adaptive tag pill area, not separate active/saved sections.
- A fixed horizontal tag folder bar appears above the pill area and stays out of the pill scroll region.
- `Összes`, `Mappa nélkül`, `Új mappa`, and user-created tag folders behave as specified.
- Dragging a pill onto a tag folder moves the tag into that folder; dragging onto `Mappa nélkül` clears its folder.
- New tags are assigned to the active concrete tag folder, or no folder in `Összes`/`Mappa nélkül`.
- All sheet tags are full-color rail-style pills.
- Active tags are full opacity; inactive tags are visibly lower opacity.
- Each pill contains its label, pencil action, and `x` action inside the colored capsule.
- The tag type dropdown is absent.
- The `Mentés` button is absent.
- The bottom `Név`, color palette, and `Új tag hozzáadása` controls stay visible while the pill area scrolls.
- The sheet grows with tag content until the status-bar/safe-area max height, then only the pill area scrolls.
- When the keyboard opens, the fixed bottom controls remain above the keyboard and the sheet does not exceed its max top boundary.
- Tapping tags, adding tags, editing active tags, and deleting active tags update the current target immediately.
- Closing the sheet does not revert any applied tag changes.
- Existing scoped tag data remains compatible with current note storage and retrieval.
- Reusable tags are read/written through a central local tag database.
- Tag records store color slot ids; renderers resolve actual colors from the slot palette.
- Updating a tag name or color slot updates rails, chunk previews, text highlights/underlines, table feedback, flowchart node outlines, flowchart lines, and source previews wherever that tag appears.
