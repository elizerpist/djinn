# Djinn Full Stack Skeleton Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first working Djinn project: Flutter text chat UI, local FastAPI backend, RAG/flowchart pipeline skeleton, safety contracts, local infra files, tests, git commits, and GitHub push attempt.

**Architecture:** Copy the local `flutteetest` Flutter scaffold into `djinn`, rename it, and replace the counter app with small chat-focused modules. Add a Python FastAPI backend under `backend/` with explicit schemas shared by the future RAG layer. Keep document ingestion separate from chat runtime and make safety/grounding states part of the API from day one.

**Tech Stack:** Flutter/Dart, Material UI, Python, FastAPI, Pydantic, pytest, Qdrant, PostgreSQL, Docker Compose, git/GitHub CLI when available.

---

## File Structure

- Modify: `pubspec.yaml` - rename package to `djinn`, keep Flutter SDK dependencies minimal.
- Modify: `lib/main.dart` - app entrypoint and theme only.
- Create: `lib/src/chat/models/chat_message.dart` - message model and sender enum.
- Create: `lib/src/chat/models/chat_conversation.dart` - conversation summary and message list model.
- Create: `lib/src/chat/data/local_chat_repository.dart` - in-memory/local first chat repository with deterministic backend-style replies.
- Create: `lib/src/chat/ui/main_screen.dart` - conversation list with FAB.
- Create: `lib/src/chat/ui/chat_screen.dart` - text-only chat screen.
- Create: `lib/src/chat/ui/chat_bubble.dart` - reusable messenger-style bubble.
- Create: `lib/src/chat/ui/message_composer.dart` - text input and send button.
- Modify: `test/widget_test.dart` - replace counter test with app smoke test.
- Create: `test/chat_repository_test.dart` - repository behavior tests.
- Create: `backend/app/main.py` - FastAPI app and routes.
- Create: `backend/app/schemas.py` - Pydantic request/response contracts.
- Create: `backend/app/services/conversation_store.py` - in-memory backend conversation state.
- Create: `backend/app/services/safety.py` - grounding/refusal decision logic.
- Create: `backend/app/pipelines/ingest.py` - document ingestion pipeline skeleton.
- Create: `backend/tests/test_api.py` - backend endpoint tests.
- Create: `backend/tests/test_ingest_pipeline.py` - ingestion stage tests.
- Create: `backend/requirements.txt` - backend dependencies.
- Create: `backend/README.md` - local backend run instructions.
- Create: `docker-compose.yml` - Qdrant and PostgreSQL services.
- Create: `.env.example` - backend and infra configuration template.
- Create/Modify: `README.md` - project overview and commands.

---

### Task 1: Bootstrap The Flutter Project

**Files:**
- Copy from: `/data/data/com.termux/files/home/flutteetest`
- Modify: `pubspec.yaml`
- Modify: `README.md`
- Modify: `test/widget_test.dart`

- [ ] **Step 1: Copy scaffold while preserving existing git/docs**

Run from `/data/data/com.termux/files/home/ubuntu/flutteruser/flutterapps/djinn`:

```bash
rsync -a --exclude .git --exclude .dart_tool --exclude build /data/data/com.termux/files/home/flutteetest/ ./
```

Expected: Flutter platform folders and `pubspec.yaml` appear, while `.git/` and `docs/` remain.

- [ ] **Step 2: Rename package metadata**

Edit `pubspec.yaml` so the top fields are:

```yaml
name: djinn
description: "AI-assisted decision support chat app for OMSZ procedure documents."
publish_to: 'none'
version: 0.1.0+1
```

Expected: imports can use `package:djinn/...`.

- [ ] **Step 3: Replace default widget test import**

Edit `test/widget_test.dart` later in Task 5 to import `package:djinn/main.dart` and assert the Djinn main screen instead of counter text.

- [ ] **Step 4: Run dependency resolution**

```bash
/data/data/com.termux/files/home/flutter/bin/flutter pub get
```

Expected: command exits 0 and writes `pubspec.lock`.

- [ ] **Step 5: Commit bootstrap**

```bash
git add .
git commit -m "chore: bootstrap Flutter project"
```

Expected: commit succeeds on `main`.

---

### Task 2: Add Backend API Contracts And Tests

**Files:**
- Create: `backend/app/__init__.py`
- Create: `backend/app/main.py`
- Create: `backend/app/schemas.py`
- Create: `backend/app/services/__init__.py`
- Create: `backend/app/services/conversation_store.py`
- Create: `backend/app/services/safety.py`
- Create: `backend/tests/test_api.py`
- Create: `backend/requirements.txt`

- [ ] **Step 1: Write backend dependencies**

`backend/requirements.txt`:

```text
fastapi==0.115.6
uvicorn[standard]==0.34.0
pydantic==2.10.4
pytest==8.3.4
httpx==0.28.1
```

- [ ] **Step 2: Define schemas**

`backend/app/schemas.py` must define `GroundingStatus`, `Citation`, `ChatRequest`, `ChatResponse`, `ConversationSummary`, and `MessageRecord`. `ChatResponse` includes `answer`, `status`, `citations`, and `refusal_reason`.

- [ ] **Step 3: Implement deterministic safety behavior**

`backend/app/services/safety.py` must return `insufficient_evidence` for questions when no corpus evidence exists. It must not fabricate citations.

- [ ] **Step 4: Implement in-memory conversation store**

`backend/app/services/conversation_store.py` stores conversations in process memory with UUID ids and ISO timestamps.

- [ ] **Step 5: Implement FastAPI routes**

`backend/app/main.py` exposes:

```python
@app.get('/health')
def health() -> dict[str, str]:
    return {'status': 'ok', 'service': 'djinn-backend'}
```

It also exposes `GET /conversations`, `POST /conversations`, `GET /conversations/{conversation_id}/messages`, and `POST /chat`.

- [ ] **Step 6: Write API tests**

`backend/tests/test_api.py` must assert:

```python
def test_health():
    response = client.get('/health')
    assert response.status_code == 200
    assert response.json()['status'] == 'ok'


def test_chat_without_corpus_refuses_with_contract_shape():
    response = client.post('/chat', json={'message': 'Mi az ellátási algoritmus?', 'conversation_id': None})
    body = response.json()
    assert response.status_code == 200
    assert body['status'] == 'insufficient_evidence'
    assert body['citations'] == []
    assert body['refusal_reason'] is not None
```

- [ ] **Step 7: Run backend tests**

```bash
cd backend && python3 -m pytest -q
```

Expected: tests pass.

- [ ] **Step 8: Commit backend contracts**

```bash
git add backend
git commit -m "feat: add local backend contract skeleton"
```

---

### Task 3: Add Document Pipeline Skeleton

**Files:**
- Create: `backend/app/pipelines/__init__.py`
- Create: `backend/app/pipelines/ingest.py`
- Create: `backend/tests/test_ingest_pipeline.py`

- [ ] **Step 1: Define pipeline stage model**

`backend/app/pipelines/ingest.py` must define immutable stage result objects with `name`, `status`, and `notes` fields.

- [ ] **Step 2: Implement dry-run pipeline**

Create `run_dry_pipeline(corpus_dir: str) -> list[PipelineStageResult]` returning stages for: load PDFs, extract text, OCR, detect sections, extract flowcharts, validate flowcharts, chunk, embed, index Qdrant, store metadata.

- [ ] **Step 3: Enforce manual validation state**

The flowchart validation stage must report `manual_validation_required`, not `complete`.

- [ ] **Step 4: Test pipeline stage order**

`backend/tests/test_ingest_pipeline.py` must assert the stage names appear in the documented order and that flowchart validation requires manual validation.

- [ ] **Step 5: Run pipeline tests**

```bash
cd backend && python3 -m pytest -q tests/test_ingest_pipeline.py
```

Expected: tests pass.

- [ ] **Step 6: Commit pipeline skeleton**

```bash
git add backend/app/pipelines backend/tests/test_ingest_pipeline.py
git commit -m "feat: add document ingestion pipeline skeleton"
```

---

### Task 4: Add Flutter Chat Domain And Repository

**Files:**
- Create: `lib/src/chat/models/chat_message.dart`
- Create: `lib/src/chat/models/chat_conversation.dart`
- Create: `lib/src/chat/data/local_chat_repository.dart`
- Create: `test/chat_repository_test.dart`

- [ ] **Step 1: Create message model**

Define `ChatSender { user, assistant }` and `ChatMessage` with `id`, `conversationId`, `sender`, `text`, `createdAt`, and optional `status`.

- [ ] **Step 2: Create conversation model**

Define `ChatConversation` with `id`, `title`, `createdAt`, `updatedAt`, and `messages`.

- [ ] **Step 3: Implement local repository**

`LocalChatRepository` must support `listConversations()`, `createConversation()`, `getMessages(conversationId)`, and `sendMessage(conversationId, text)`. `sendMessage` appends the user message and an assistant refusal message using the future backend wording.

- [ ] **Step 4: Write repository tests**

`test/chat_repository_test.dart` must assert a new conversation exists after creation, sending a message creates two messages, and the assistant response contains `nincs elegendo tudásbázis` or equivalent ASCII-safe fallback text.

- [ ] **Step 5: Run repository tests**

```bash
/data/data/com.termux/files/home/flutter/bin/flutter test test/chat_repository_test.dart
```

Expected: tests pass.

- [ ] **Step 6: Commit Flutter domain**

```bash
git add lib/src/chat test/chat_repository_test.dart
git commit -m "feat: add local chat repository"
```

---

### Task 5: Build Flutter Chat UI

**Files:**
- Modify: `lib/main.dart`
- Create: `lib/src/chat/ui/main_screen.dart`
- Create: `lib/src/chat/ui/chat_screen.dart`
- Create: `lib/src/chat/ui/chat_bubble.dart`
- Create: `lib/src/chat/ui/message_composer.dart`
- Modify: `test/widget_test.dart`

- [ ] **Step 1: Replace counter app entrypoint**

`lib/main.dart` should expose `DjinnApp` and keep `MyApp` as a compatibility alias for simple tests if useful:

```dart
void main() {
  runApp(const DjinnApp());
}
```

- [ ] **Step 2: Implement main screen**

`MainScreen` uses `Scaffold`, `AppBar(title: Text('Djinn'))`, a conversation list, and `FloatingActionButton` with `Icons.add_comment`.

- [ ] **Step 3: Implement chat screen**

`ChatScreen` shows a scrollable list of `ChatBubble` widgets and a bottom `MessageComposer`. Back navigation returns to the main screen.

- [ ] **Step 4: Implement text-only bubbles**

`ChatBubble` aligns by sender and uses different colors for user and assistant messages. No emoji/media controls are added.

- [ ] **Step 5: Implement composer behavior**

`MessageComposer` disables send for blank text and clears the input after a successful send.

- [ ] **Step 6: Replace widget test**

`test/widget_test.dart` must assert the app renders `Djinn`, taps the FAB, sends a message, and finds an assistant bubble.

- [ ] **Step 7: Run Flutter tests**

```bash
/data/data/com.termux/files/home/flutter/bin/flutter test
```

Expected: all Flutter tests pass.

- [ ] **Step 8: Commit chat UI**

```bash
git add lib test
git commit -m "feat: build text chat UI"
```

---

### Task 6: Add Infrastructure And Documentation

**Files:**
- Create: `docker-compose.yml`
- Create: `.env.example`
- Create: `backend/README.md`
- Modify: `README.md`

- [ ] **Step 1: Add local services**

`docker-compose.yml` defines `qdrant` on port `6333` and `postgres` on port `5432` with a `djinn` database.

- [ ] **Step 2: Add env template**

`.env.example` includes `DJINN_BACKEND_HOST`, `DJINN_BACKEND_PORT`, `QDRANT_URL`, and `DATABASE_URL`.

- [ ] **Step 3: Document backend commands**

`backend/README.md` includes install, test, and run commands:

```bash
python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
python3 -m pytest -q
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

- [ ] **Step 4: Document project commands**

`README.md` includes Flutter test/run commands, backend commands, and a clear note that this is not clinically validated.

- [ ] **Step 5: Commit infra docs**

```bash
git add docker-compose.yml .env.example README.md backend/README.md
git commit -m "docs: add local infrastructure instructions"
```

---

### Task 7: Final Verification

**Files:**
- Verify all changed files.

- [ ] **Step 1: Run Flutter analyzer**

```bash
/data/data/com.termux/files/home/flutter/bin/flutter analyze
```

Expected: no fatal analyzer errors.

- [ ] **Step 2: Run Flutter tests**

```bash
/data/data/com.termux/files/home/flutter/bin/flutter test
```

Expected: all Flutter tests pass.

- [ ] **Step 3: Run backend tests**

```bash
cd backend && python3 -m pytest -q
```

Expected: all backend tests pass.

- [ ] **Step 4: Check git status**

```bash
git status --short
```

Expected: clean working tree.

---

### Task 8: GitHub Repository Sync

**Files:**
- Git remote configuration only.

- [ ] **Step 1: Check GitHub CLI authentication**

```bash
gh auth status
```

Expected: authenticated GitHub account, or a clear failure if credentials are not configured.

- [ ] **Step 2: Create remote repository when authenticated**

```bash
gh repo create djinn --private --source . --remote origin --push
```

Expected: GitHub repo exists and current `main` branch is pushed.

- [ ] **Step 3: If repository already exists, attach and push**

```bash
git remote add origin git@github.com:<owner>/djinn.git
git push -u origin main
```

Expected: local `main` tracks `origin/main`.

- [ ] **Step 4: Report sync status**

Report the local path, latest commit hash, remote URL if configured, and any authentication/network blocker.

---

## Self-Review

- Spec coverage: Flutter chat, local backend, document pipeline skeleton, safety contracts, infra, tests, and GitHub sync each have explicit tasks.
- Placeholder scan: no task depends on unspecified production RAG behavior; real OMSZ extraction is intentionally represented by skeleton interfaces and manual validation gates.
- Type consistency: backend uses `GroundingStatus`, `ChatRequest`, and `ChatResponse`; Flutter uses `ChatMessage`, `ChatConversation`, and `LocalChatRepository` consistently.
