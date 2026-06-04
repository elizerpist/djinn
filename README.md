# Djinn

Djinn is a Flutter mobile chat client with a strict FastAPI RAG backend for
AI-assisted decision support over imported procedure PDFs.

This is a non-clinically-validated prototype. It must not be used as the sole
basis for patient-care decisions. The current trusted ingest path supports
text-bearing PDFs only; OCR and flowchart interpretation are not yet trusted or
included in answers.

## Architecture

- Flutter stores local conversations and imports PDFs from the phone.
- FastAPI extracts text, chunks it, and writes OpenAI embeddings to Qdrant.
- PostgreSQL stores durable source-chunk and indexing audit metadata.
- LangGraph orchestrates retrieval, generation, citation verification, and
  fail-closed refusals.
- NeMo Guardrails checks input, retrieved evidence, output, and source-bounded
  facts.
- OpenAI is called only by the backend. The API key is never stored in Flutter,
  compiled into an APK, or provided to GitHub Actions.

## Local Backend

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

## Phone Trial APK

GitHub Actions publishes two artifacts after every push to `main`:

- `djinn-trial-apk`: debug APK configured for `http://127.0.0.1:8000` and
  cleartext localhost access. Use this when FastAPI runs in Termux on the same
  phone. Qdrant and PostgreSQL may be local or remote, but must be reachable by
  that backend.
- `djinn-release-apk`: release APK. Set the repository variable
  `DJINN_BACKEND_URL` to a reachable HTTPS backend before treating it as a
  usable release build.

Download and install the same-phone trial:

```bash
gh -R elizerpist/djinn run list --limit 1
gh -R elizerpist/djinn run download <RUN_ID> -n djinn-trial-apk
adb install -r app-debug.apk
```

The trial APK can open without a backend, but strict AI answers require a valid
backend `OPENAI_API_KEY`, reachable Qdrant and PostgreSQL, initialized NeMo
Guardrails, at least one successfully ingested text PDF, and a ready
`/system/readiness` response.

## Flutter Development

```bash
export PATH=/home/flutteruser/flutter/bin:$PATH
flutter pub get
flutter analyze
flutter test
flutter build apk --debug --dart-define=DJINN_BACKEND_URL=http://127.0.0.1:8000
```

For an Android emulator backend running on the host, the app default remains
`http://10.0.2.2:8000`. Release builds should receive an HTTPS URL through
`DJINN_BACKEND_URL`.

## Project Layout

- `lib/` - Flutter messenger-style mobile client.
- `backend/app/` - strict RAG runtime, adapters, graph, and FastAPI routes.
- `backend/guardrails/` - versioned NeMo Guardrails policies.
- `backend/tests/` - offline provider/adapter/workflow/API tests.
- `docs/superpowers/` - approved architecture spec and implementation plan.
- `docker-compose.yml` - local Qdrant and PostgreSQL services.

Default CI uses injected fakes and never calls live OpenAI, Qdrant, or
PostgreSQL services, so it does not spend OpenAI credits.
