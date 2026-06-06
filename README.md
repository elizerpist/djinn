# Djinn

Djinn is a Flutter mobile chat client for AI-assisted decision support over
imported procedure PDFs. The current usable runtime target is Local APK B mode:
the Android app stores the user's knowledge base and chat state locally, while
calling OpenAI with the user's in-app API key.

This is a non-clinically-validated prototype. It must not be used as the sole
basis for patient-care decisions. Flowchart extraction and validation UI exists,
but clinical validation of imported OMSZ procedures remains mandatory before use.

## Local APK B mode

Djinn runs the first usable AI mode inside the Android APK. The user enters an OpenAI API key in Settings. The app imports PDFs into app-private storage, processes them through OpenAI using the user's key, stores chunks, embeddings, flowchart structures, validation state, and chat history locally in ObjectBox, and answers only from retrieved local sources.

Termux, FastAPI, Qdrant, and PostgreSQL are not required for B mode. Backend mode is a separate future runtime path and does not act as an automatic fallback.

B mode is intentionally fail-closed: if the API key is missing, local documents are not ready, retrieval finds insufficient evidence, citations fail verification, or the optional groundedness check fails, the assistant refuses instead of using outside knowledge.

## Architecture

- Flutter stores local conversations and imports PDFs from the phone.
- ObjectBox stores local documents, chunks, embeddings, flowchart validation
  state, and chat history inside the APK sandbox.
- OpenAI is called directly from the app through provider adapters using the
  user's API key from secure storage.
- Retrieval, citation verification, and optional groundedness checks are
  source-bounded and fail closed.
- Backend mode remains a separate runtime path for later hosted deployments; it
  is not an automatic fallback for B mode.

## Legacy Backend Notes

Prerequisites: Python 3.12+, Docker Compose, and a valid OpenAI API key.

```bash
cp .env.example .env
# Edit .env and set OPENAI_API_KEY. Never commit .env.
docker compose up -d qdrant postgres

cd backend
python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
PYTHONPATH=. pytest -q
uvicorn app.main:app --env-file ../.env --host 127.0.0.1 --port 8000
```

Verify all strict components before importing documents or chatting:

```bash
curl http://127.0.0.1:8000/health
curl http://127.0.0.1:8000/system/readiness
```

`/system/readiness` must return `"ready": true`. A missing OpenAI key or
unreachable Qdrant/PostgreSQL/guardrails component blocks AI answers and ingest
instead of falling back to an ungrounded answer.

## Phone APK

GitHub Actions publishes APK artifacts after every push to `main`. The debug APK
can be used for Local APK B mode without Termux or a local backend. Open the app,
enter the OpenAI API key in Settings, import PDFs from the Tudastar screen, and
let the app process them into the local ObjectBox knowledge base.

Download and install the same-phone trial:

```bash
gh -R elizerpist/djinn run list --limit 1
gh -R elizerpist/djinn run download <RUN_ID> -n djinn-trial-apk
adb install -r app-debug.apk
```

The APK can open without a backend. Strict AI answers require an in-app OpenAI
API key, at least one locally processed PDF, and enough retrieved local evidence
for citation verification.

## Flutter Development

```bash
export PATH=/home/flutteruser/flutter/bin:$PATH
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

The default debug build uses Local APK B mode. No `DJINN_BACKEND_URL` is needed
for the local ObjectBox/OpenAI path.

## Project Layout

- `lib/` - Flutter messenger-style mobile client and Local APK B mode runtime.
- `docs/superpowers/` - approved architecture spec and implementation plan.

Default tests use injected fakes and never call live OpenAI, so they do not spend
OpenAI credits.
