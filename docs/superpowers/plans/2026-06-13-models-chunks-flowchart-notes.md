# Models Chunks Flowchart Notes Implementation Plan

> Implementation record for the 2026-06-13 Djinn knowledge/model/flowchart/notes batch. The checklist reflects what this branch implements or verifies.

**Goal:** Finish the approved Djinn fixes for capability-based AI model choices, chunk customization/inspection, selectable chat text, simplified flowchart hierarchy/title handling, colored status chips, and functional case notes links.

**Architecture:** Keep changes inside the current Flutter app boundaries. Model capability rules live in `ModelCatalog` and settings sanitization, AI error mapping stays in provider clients, flowchart display logic stays in `FlowchartHierarchyBuilder` plus `ExtractedKnowledgeScreen`, and case link behavior stays in `CaseRepository` plus `CasesScreen`.

**Tech Stack:** Flutter/Dart, ObjectBox entities already present, existing `flutter_test` widget/unit tests, GitHub Actions for APK build.

---

### Task 1: Capability-Based Model Choices

**Files:**
- Modify: `lib/src/settings/models/model_catalog.dart`
- Modify: `lib/src/settings/data/app_settings_repository.dart`
- Modify: `lib/src/settings/ui/settings_screen.dart`
- Test: `test/settings_repository_test.dart`
- Test: `test/settings_screen_test.dart`

- [x] Add tests that Gemini extraction options exclude `gemma-*`, `*-tts`, and embedding-only models, while answer options may include Gemma text models.
- [x] Add test that loading saved settings with `geminiExtractionModel: gemma-4-31b-it` sanitizes to `gemini-2.5-flash-lite`.
- [x] Implement per-slot Gemini lists: answer, extraction, groundedness, embedding.
- [x] Ensure dropdown displayed fallback is saved back when existing saved value is invalid.
- [x] Run targeted settings tests.

### Task 2: Gemini Error Detail and Training Logs

**Files:**
- Modify: `lib/src/ai/ai_error.dart`
- Modify: `lib/src/google/gemini_http_client.dart`
- Modify: `lib/src/knowledge/data/document_processing_service.dart`
- Test: `test/gemini_http_client_test.dart`
- Test: `test/document_processing_service_test.dart`

- [x] Add test that HTTP 500 maps to retryable server/high-demand style failure, not unknown non-retryable.
- [x] Add test/log expectation that AI Training start includes extraction, embedding, groundedness, chunking mode.
- [x] Implement failure code/factory for provider server errors or map 500 to highDemand retryable.
- [x] Include selected models in debug logs.

### Task 3: Chunk Customization and Inspector UX

**Files:**
- Modify: `lib/src/settings/ui/settings_screen.dart`
- Modify: `lib/src/knowledge/ui/extracted_knowledge_screen.dart`
- Test: `test/settings_screen_test.dart`
- Test: `test/extracted_knowledge_screen_test.dart`

- [x] Keep and clarify compact/normal/detailed chunk mode in settings.
- [x] Keep type-based inspector tabs without replacing existing tabs; search was intentionally not added in this batch.
- [x] Show raw text, metadata, page, type, model in an expandable tile.
- [x] Run extracted knowledge tests.

### Task 4: Selectable Chat Bubble Text

**Files:**
- Modify: `lib/src/chat/ui/chat_bubble.dart`
- Test: `test/chat_bubble_test.dart`

- [x] Add widget test expecting selectable message body text.
- [x] Replace message body `Text` with `SelectableText` while preserving colors/layout.

### Task 5: Flowchart Title and Simplified Connector Rows

**Files:**
- Modify: `lib/src/ai/ai_client.dart`
- Modify: `lib/src/google/gemini_http_client.dart`
- Modify: `lib/src/openai/openai_http_client.dart`
- Modify: `lib/src/knowledge/models/flowchart_hierarchy.dart`
- Modify: `lib/src/knowledge/ui/extracted_knowledge_screen.dart`
- Test: `test/gemini_http_client_test.dart`
- Test: `test/flowchart_hierarchy_test.dart`
- Test: `test/extracted_knowledge_screen_test.dart`

- [x] Strengthen extraction prompt to capture titles above/below diagrams and all process boxes.
- [x] Add row model that marks edge rows as connector-only and target depth as parent+1.
- [x] Render edge rows as centered label pills without arrow, without color stripes, without color picker.
- [x] Ensure `NEM`/`IGEN` branches do not create dedicated node boxes unless the source really has such a box.

### Task 6: Colored Status Chips

**Files:**
- Modify: `lib/src/knowledge/ui/knowledge_document_row.dart`
- Modify: `lib/src/knowledge/ui/extracted_knowledge_screen.dart`
- Test: `test/knowledge_base_screen_test.dart`
- Test: `test/extracted_knowledge_screen_test.dart`

- [x] Add/keep tests for colored imported/processing/ready/failed chips.
- [x] Apply restrained status colors with readable foregrounds.

### Task 7: Functional Case Notes Links

**Files:**
- Modify: `lib/src/cases/data/case_repository.dart`
- Modify: `lib/src/cases/models/case_workspace.dart` if needed
- Modify: `lib/src/cases/ui/cases_screen.dart`
- Test: `test/case_repository_test.dart`
- Test: `test/cases_screen_test.dart`

- [x] Add repository methods to list linked chat IDs and document IDs.
- [x] Replace placeholder list tiles with actual linked lists and add buttons.
- [x] Add dialogs for adding chat/document IDs manually; repositories prevent duplicate links.
- [x] Run case tests.

### Task 8: Verification, Commit, Push, Build

**Files:**
- All touched files.

- [x] Run targeted tests for each subsystem.
- [x] Run `flutter analyze` and broad test batch via proot Ubuntu.
- [ ] Commit changes.
- [ ] Push branch to GitHub.
- [ ] Trigger/inspect GitHub Actions debug APK build.
- [ ] Return final APK link.

## Self-Review

- The plan covers each user request from the approved design: models, errors, chunk customization, chat text, flowchart title/connector, status chips, notes.
- No placeholder menu items should remain in case notes; if a visible control is added, it must work.
- Flowchart connector design is v3: centered `IGEN/NEM` pill, no arrow icon, no separate branch node unless source node exists.
