# Djinn PDF Import Hybrid RAG Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add persistent chat history, phone PDF import, local knowledge-base status, backend document upload endpoints, and GitHub native Android build validation.

**Architecture:** Flutter keeps local chat/document state in JSON-backed repositories and exposes a folder button that opens a knowledge-base screen. PDF picking/copying is isolated behind an importer service so tests can exercise storage without platform file dialogs. FastAPI gains a document registry/upload API and chat refusal behavior that distinguishes no corpus from pending ingest.

**Tech Stack:** Flutter/Dart, file_picker, path_provider, path, http, Python FastAPI, Pydantic, pytest, python-multipart, GitHub Actions.

---

## File Structure

- Modify: `pubspec.yaml` - add Flutter dependencies for file picking, local paths, and HTTP.
- Create: `lib/src/core/storage/json_file_store.dart` - small JSON file persistence helper.
- Create: `lib/src/knowledge/models/knowledge_document.dart` - document model/status/readiness.
- Create: `lib/src/knowledge/data/knowledge_document_repository.dart` - persistent document metadata store.
- Create: `lib/src/knowledge/data/pdf_import_service.dart` - copy selected PDFs into app storage.
- Create: `lib/src/knowledge/data/knowledge_api_client.dart` - backend upload/status client boundary.
- Create: `lib/src/knowledge/ui/knowledge_base_screen.dart` - document list/import UI.
- Modify: `lib/src/chat/data/local_chat_repository.dart` - persist conversations and include knowledge readiness in refusal text.
- Modify: `lib/src/chat/ui/main_screen.dart` - add folder button and inject knowledge repository.
- Modify: `lib/src/chat/ui/chat_screen.dart` - show knowledge-base readiness banner.
- Modify: `lib/main.dart` - initialize app repositories asynchronously.
- Create/Modify tests: `test/chat_repository_test.dart`, `test/knowledge_document_repository_test.dart`, `test/widget_test.dart`.
- Modify: `backend/requirements.txt` - add `python-multipart`.
- Modify: `backend/app/schemas.py` - add document/status schemas.
- Create: `backend/app/services/document_registry.py` - backend document registry and safe storage.
- Modify: `backend/app/main.py` - add knowledge endpoints and pending-ingest chat behavior.
- Create/Modify tests: `backend/tests/test_knowledge_api.py`, `backend/tests/test_api.py`.

---

### Task 1: Backend Knowledge API

**Files:**
- Modify: `backend/requirements.txt`
- Modify: `backend/app/schemas.py`
- Create: `backend/app/services/document_registry.py`
- Modify: `backend/app/main.py`
- Create: `backend/tests/test_knowledge_api.py`
- Modify: `backend/tests/test_api.py`

- [ ] **Step 1: Add failing backend tests**

Create tests asserting that non-PDF upload returns 400, PDF upload registers `pending_ingest`, document list returns the item, status is not ready while pending, and `/chat` refusal mentions pending ingest when pending documents exist.

- [ ] **Step 2: Run tests red**

Run: `cd backend && . .venv/bin/activate && PYTHONPATH=. pytest -q backend/tests/test_knowledge_api.py backend/tests/test_api.py`
Expected: FAIL because knowledge endpoints do not exist.

- [ ] **Step 3: Implement schemas and registry**

Add `KnowledgeDocumentStatus`, `KnowledgeDocumentRecord`, and `KnowledgeStatusResponse`. Implement `DocumentRegistry` with safe PDF filename handling, unique IDs, in-memory metadata, and file storage under `backend/corpus/omsz`.

- [ ] **Step 4: Implement endpoints**

Add `GET /knowledge/documents`, `POST /knowledge/documents`, `POST /knowledge/documents/{document_id}/ingest`, and `GET /knowledge/status`. Upload accepts only `.pdf` or `application/pdf`; ingest keeps `pending_ingest` with `manual_validation_required` notes.

- [ ] **Step 5: Run backend tests green**

Run: `cd backend && . .venv/bin/activate && PYTHONPATH=. pytest -q`
Expected: all backend tests pass.

- [ ] **Step 6: Commit**

Commit message: `feat: add backend knowledge document API`.

---

### Task 2: Persistent Flutter Chat Store

**Files:**
- Create: `lib/src/core/storage/json_file_store.dart`
- Modify: `lib/src/chat/models/chat_message.dart`
- Modify: `lib/src/chat/models/chat_conversation.dart`
- Modify: `lib/src/chat/data/local_chat_repository.dart`
- Modify: `test/chat_repository_test.dart`

- [ ] **Step 1: Add failing persistence test**

Extend `test/chat_repository_test.dart` to create a temp JSON store, send a message, create a new repository with the same store, and verify the conversation/messages reload.

- [ ] **Step 2: Run test red**

Run: `flutter test test/chat_repository_test.dart`
Expected: FAIL because repository has no persistent store constructor/API.

- [ ] **Step 3: Add JSON serialization and store helper**

Add `toJson`/`fromJson` to chat models and create `JsonFileStore` with `readList` and `writeList` methods.

- [ ] **Step 4: Persist repository changes**

Make `LocalChatRepository.load()` initialize from store, and persist after create/send.

- [ ] **Step 5: Run test green and commit**

Run: `flutter test test/chat_repository_test.dart`.
Commit message: `feat: persist chat history locally`.

---

### Task 3: Flutter Knowledge Store And Import Service

**Files:**
- Create: `lib/src/knowledge/models/knowledge_document.dart`
- Create: `lib/src/knowledge/data/knowledge_document_repository.dart`
- Create: `lib/src/knowledge/data/pdf_import_service.dart`
- Create: `lib/src/knowledge/data/knowledge_api_client.dart`
- Create: `test/knowledge_document_repository_test.dart`
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add dependencies**

Run: `flutter pub add file_picker path_provider path http`.

- [ ] **Step 2: Add failing knowledge repository tests**

Tests cover add/list/update persistence and derived readiness: empty -> none, pending docs -> pending, processed docs -> ready.

- [ ] **Step 3: Run tests red**

Run: `flutter test test/knowledge_document_repository_test.dart`.
Expected: FAIL because knowledge modules do not exist.

- [ ] **Step 4: Implement models/repository/importer/client**

Implement document model JSON serialization, repository persistence, importer copy-by-path/copy-by-bytes helpers, and API client method signatures for status/upload.

- [ ] **Step 5: Run tests green and commit**

Run: `flutter test test/knowledge_document_repository_test.dart`.
Commit message: `feat: add local knowledge document store`.

---

### Task 4: Flutter Knowledge UI And Chat Readiness

**Files:**
- Create: `lib/src/knowledge/ui/knowledge_base_screen.dart`
- Modify: `lib/main.dart`
- Modify: `lib/src/chat/ui/main_screen.dart`
- Modify: `lib/src/chat/ui/chat_screen.dart`
- Modify: `test/widget_test.dart`

- [ ] **Step 1: Add failing widget tests**

Update widget test to assert the folder icon opens the knowledge-base screen, empty document state appears, and chat screen shows knowledge status.

- [ ] **Step 2: Run widget test red**

Run: `flutter test test/widget_test.dart`.
Expected: FAIL because folder button/knowledge screen do not exist.

- [ ] **Step 3: Implement app repository initialization**

Use `path_provider` in production and temp stores in tests where needed. `DjinnApp` should accept optional repositories for test injection.

- [ ] **Step 4: Implement UI**

Add folder button, knowledge-base screen, import action, document rows, retry action placeholder, and readiness banner in chat.

- [ ] **Step 5: Run Flutter tests green and commit**

Run: `flutter test`.
Commit message: `feat: add knowledge base import UI`.

---

### Task 5: Final Verification And Push

**Files:**
- Verify all changed files.

- [ ] **Step 1: Run backend tests**

Run: `cd backend && . .venv/bin/activate && PYTHONPATH=. pytest -q`.
Expected: all backend tests pass.

- [ ] **Step 2: Run Flutter analyzer and tests**

Run: `flutter analyze && flutter test`.
Expected: no analyzer issues and all tests pass.

- [ ] **Step 3: Push to GitHub**

Run: `git push`.
Expected: `main` pushes to `origin/main`.

- [ ] **Step 4: Watch GitHub Actions**

Run: `gh run list --repo elizerpist/djinn --limit 1` then `gh run watch <run-id> --repo elizerpist/djinn --exit-status`.
Expected: Android native build succeeds and uploads `djinn-release-apk`.

---

## Self-Review

- Spec coverage: covers persistent chat, mobile PDF import entry point, local document status, backend upload/status endpoints, chat refusal behavior, and CI native build.
- Placeholder scan: no TODO/TBD steps; retry ingest is explicitly a pending-ingest backend contract in this milestone.
- Type consistency: Flutter uses `KnowledgeDocumentStatus.pendingIngest`; backend uses serialized `pending_ingest` status.
