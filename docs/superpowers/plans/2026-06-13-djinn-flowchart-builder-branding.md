# Djinn Flowchart Builder And Branding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the approved Flowchart hub and builder direction, clean up extracted flowchart rendering, replace raw case-link IDs with pickers, and move Djinn branding/debug controls into the app shell.

**Architecture:** Keep the Flowchart feature inside the existing bottom-nav destination, adding a focused hub screen with subheader tabs for validation, extracted views, builder, and templates. Keep extracted-flowchart rendering data-driven so the same flowchart can switch between multiple views without changing stored evidence. Keep case link pickers repository-backed and lightweight.

**Tech Stack:** Flutter, Material 3, ObjectBox-backed repositories, existing widget tests, existing Flutter test runner.

---

### Task 1: Flowchart Hub Navigation

**Files:**
- Modify: `lib/src/chat/ui/app_destination.dart`
- Modify: `lib/src/chat/ui/main_screen.dart`
- Create: `lib/src/flowchart/ui/flowchart_hub_screen.dart`
- Test: `test/main_screen_navigation_test.dart`
- Test: `test/flowchart_hub_screen_test.dart`

- [x] Write failing tests proving bottom nav order is `Esetek / Flow / Chat / Tudástár / Beáll.` and the Flow screen shows `Validálás`, `Kinyert`, `Építő`, `Sablonok`.
- [x] Run targeted tests and confirm they fail because the hub screen/order does not exist.
- [x] Implement `FlowchartHubScreen` and switch the Flow destination to use it.
- [~] Run targeted tests and confirm they pass. (Blocked locally by Termux ARM64 Dart TLS alignment; GitHub Actions must run this.)

### Task 2: Extracted Flowchart Multi-View UI

**Files:**
- Modify: `lib/src/knowledge/models/flowchart_hierarchy.dart`
- Modify: `lib/src/knowledge/ui/extracted_knowledge_screen.dart`
- Test: `test/flowchart_hierarchy_test.dart`
- Test: `test/extracted_knowledge_screen_test.dart`

- [x] Write failing tests proving flowchart rows no longer render color rails and support named view switches: `Törzs + ágkártyák`, `Térkép + olvasólista`, `Swimlane ágak`, `Kinyitható döntéskártya`.
- [x] Write a failing hierarchy test for a `JAVUL?` decision where `IGEN -> SZÁLLÍTÁS` and `NEM -> CPAP` stay sibling branches.
- [x] Write a failing hierarchy test proving a node stays visible when OCR/AI returns an edge from a missing source node.
- [x] Write a failing UI test proving a flowchart group title can be renamed from the extracted-content menu.
- [x] Implement branch grouping and the four named views.
- [x] Keep orphaned/partially extracted nodes visible instead of hiding them behind invalid incoming edges.
- [x] Add UI-level flowchart group title rename from the extracted flowchart card.
- [~] Run targeted tests and confirm they pass. (Blocked locally by Termux ARM64 Dart TLS alignment; GitHub Actions must run this.)

### Task 3: Flowchart Builder UI

**Files:**
- Create: `lib/src/flowchart/ui/flowchart_builder_screen.dart`
- Modify: `lib/src/flowchart/ui/flowchart_hub_screen.dart`
- Test: `test/flowchart_builder_screen_test.dart`

- [x] Write failing tests for the approved builder screen: grid canvas, toolbar, add FAB, bottom property sheet, and element palette.
- [x] Write failing tests proving builder node IDs stay unique after delete/add and template selection opens a seeded builder.
- [x] Implement the builder UI as a functional first pass with local in-memory nodes.
- [x] Make templates actionable: selecting a template switches to the builder and preloads editable nodes.
- [x] Use monotonic builder node IDs so delete/add cannot duplicate node keys.
- [~] Run targeted tests and confirm they pass. (Blocked locally by Termux ARM64 Dart TLS alignment; GitHub Actions must run this.)

### Task 4: Case Note Pickers

**Files:**
- Modify: `lib/src/cases/data/case_repository.dart`
- Modify: `lib/src/cases/ui/cases_screen.dart`
- Test: `test/cases_screen_test.dart`

- [x] Write failing tests proving chat and PDF links are selected through picker dialogs, not raw ID text fields.
- [x] Add repository picker item APIs for linked chat/PDF candidates.
- [x] Implement picker dialogs with friendly labels and existing IDs hidden as metadata.
- [~] Run targeted tests and confirm they pass. (Blocked locally by Termux ARM64 Dart TLS alignment; GitHub Actions must run this.)

### Task 5: Branding, Header Debug, Splash, Overscroll

**Files:**
- Modify: `pubspec.yaml`
- Create: `assets/branding/djinn_svg.svg`
- Modify: `lib/main.dart`
- Modify: `lib/src/debug/debug_floating_button.dart`
- Create: `lib/src/debug/debug_header_button.dart`
- Modify: chat/flow/list screens as needed for consistent overscroll physics.
- Test: `test/widget_test.dart`
- Test: `test/debug_floating_button_test.dart`
- Test: `test/main_screen_navigation_test.dart`

- [x] Write failing tests proving the app loading screen shows Djinn branding, the debug button is in the header, and the old floating button is not present in the app shell.
- [x] Copy `/storage/emulated/0/aaaaa/djinn_svg.svg` into the repo as an asset.
- [x] Implement branded loading, header icon, and header debug button.
- [x] Apply consistent `BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics())` where chat/flow lists currently feel different from cases/PDF lists.
- [~] Run targeted tests and confirm they pass. (Blocked locally by Termux ARM64 Dart TLS alignment; GitHub Actions must run this.)

### Task 6: Verification And Delivery

**Files:**
- All touched source and tests.

- [~] Run targeted tests. (Local Flutter fails before test execution: Dart TLS segment underaligned.)
- [~] Run `flutter analyze`. (Local Flutter/Dart VM fails before analyzer startup.)
- [~] Run `flutter test`. (Local Flutter/Dart VM fails before test startup.)
- [ ] Commit all implementation changes.
- [ ] Push the branch to GitHub.
- [ ] Trigger/observe GitHub Actions and report the debug APK link when the online build succeeds.
