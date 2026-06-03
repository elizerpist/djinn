# Djinn

Djinn is a Flutter + local backend skeleton for an AI-assisted decision-support
chat app over approved OMSZ procedure documents.

This repository is not clinically validated. The current backend refuses to
answer clinical questions unless validated corpus evidence is available.

## Project Layout

- `lib/` - Flutter text-only chat application.
- `backend/` - FastAPI backend and RAG pipeline skeleton.
- `docs/superpowers/specs/` - approved design spec.
- `docs/superpowers/plans/` - implementation plan.
- `docker-compose.yml` - local Qdrant and PostgreSQL services.

## Flutter Setup

Run from the project root inside the Ubuntu/proot Flutter environment:

```bash
export PATH=/home/flutteruser/flutter/bin:$PATH
flutter pub get
flutter test
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
```

From Termux, use:

```bash
proot-distro login ubuntu --user flutteruser -- bash -lc 'export PATH=/home/flutteruser/flutter/bin:$PATH && cd /home/flutteruser/flutterapps/djinn && flutter test'
```

## Backend Setup

```bash
cd backend
python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
PYTHONPATH=. pytest -q
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

## Local RAG Infrastructure

```bash
cp .env.example .env
docker compose up -d qdrant postgres
```

Qdrant listens on `127.0.0.1:6333`. PostgreSQL uses the local development
credentials from `.env.example`.

## Safety Boundary

The assistant must answer only from validated app documents. If retrieval does
not provide enough support, the system returns `insufficient_evidence` with no
citations instead of guessing.
