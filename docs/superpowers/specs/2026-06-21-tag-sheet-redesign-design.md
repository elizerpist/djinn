# Tag Sheet Redesign

Date: 2026-06-21
Status: design approved for implementation planning

## Context

The notes editor has a tag manager sheet for applying knowledge tags to selected note content. The old sheet duplicated tag state across separate active and saved tag containers, exposed a user-facing tag type dropdown, and relied on explicit save behavior. The redesigned sheet should match the interaction model validated in the browser preview at `/data/data/com.termux/files/home/tag-sheet-code-preview/index.html`.

This spec applies to the tag sheet opened from selected text/list/table/flowchart scope rails and from whole-chunk/global tag entry points. It does not redesign folders. Folders remain file organization. Tags are semantic markers for words, sentences, selected ranges, list items, table cells/scopes, or flowchart elements.

## Product Model

A user-facing tag is only:

- name;
- color;
- active/inactive state for the current target.

The normal user flow must not require choosing a category/type. Internally, the app may continue storing tags with a default type such as `custom` for backwards compatibility, but the type field is not shown in the sheet and is not part of the user's decision.

The target scope is separate from the tag itself. The system knows whether the tag was applied to a text range, list item, table cell/scope, flowchart node, flowchart edge, or whole chunk. The user should not have to encode that target as a tag type.

## Sheet Layout

The sheet is a bottom sheet with a maximum height capped at the bottom of the Android status bar / safe area. This existing maximum-height behavior remains.

The sheet has three vertical regions:

1. Header: title and close button.
2. Tag pill area: one adaptive wrapping container for all tags.
3. Fixed editor area: name field, color palette, and `Új tag hozzáadása` button.

The entire sheet must not become one scroll view. Only the tag pill area scrolls when needed.

The fixed editor area is always visible. It is anchored to the bottom of the sheet and is not part of the tag pill scroll region.

When there are few tags, the sheet should be only as tall as its content requires. When more tags are added, the sheet height grows until it reaches its maximum allowed height. After that, additional tag overflow is handled by scrolling only the tag pill area.

## Keyboard Behavior

When the user focuses the name field and the Android keyboard opens, the sheet moves with the visible viewport so the fixed editor area sits directly above the keyboard.

The sheet must still respect the same maximum top boundary: it may slide upward, but it must not extend beyond the status bar / safe area cap. If the keyboard leaves insufficient room for all tags, the pill area scrolls.

Implementation should use Flutter's keyboard/viewInsets behavior for the production app. The browser preview used `visualViewport` only to model the same behavior in HTML.

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
- color palette using the existing `noteTagColorSlots` colors;
- `Új tag hozzáadása` button.

There is no `Mentés` button. All changes are immediate.

There is no pill-row plus button. New tag creation is done with the bottom `Új tag hozzáadása` button.

When the user enters a name and taps `Új tag hozzáadása`:

- if not editing an existing tag, create a new reusable tag and immediately activate it for the current target;
- if editing an existing tag, update the reusable tag's name/color;
- editing an inactive tag does not activate it for the current target;
- if the edited tag was active on the current target, keep the updated tag active;
- clear the name field after successful add/update;
- advance the selected color to the next unused slot where practical.

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

The sheet pill design must visually match the rail tag pills. The rail remains the place where selected-target actions live. The sheet is only for choosing, creating, editing, and deleting reusable tags for the current target.

After a sheet change, the selected target feedback updates immediately:

- rail pill row reflects the active tags;
- text/list/table highlight or underline rendering updates immediately;
- global chunk tag capsules update immediately;
- flowchart edit-card/canvas tag feedback updates according to existing flowchart tag rules.

For multi-tag text feedback, keep the existing rule: primary tag controls background highlight, secondary tags render as underline layers. The sheet redesign does not change multi-tag rendering rules outside the sheet.

## Data Compatibility

Existing `NoteKnowledgeTag` storage can remain compatible with the current model:

- store user-created tags with a default normalized type, preferably `custom`;
- preserve `label` and `colorValue`;
- keep scoped target storage unchanged.

The UI must treat tag identity primarily as the user-visible label within the reusable tag list. Duplicate visible labels should not be created in the same saved-tag registry. If a duplicate label is added, update or select the existing tag rather than creating another visually identical pill.

## Non-Goals

Do not redesign folders, collections, or note file organization.

Do not add tag categories back into the normal sheet UI.

Do not add a separate active tag container.

Do not add a separate saved tag container.

Do not add a `Mentés` button.

Do not put edit/delete buttons outside the pill.

Do not make the fixed editor area scroll away with the pill list.

Do not make the whole sheet scroll when only the pill area overflows.

## Acceptance Criteria

- The sheet shows one adaptive tag pill area, not separate active/saved sections.
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
