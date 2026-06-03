# Djinn Backend

Local FastAPI backend skeleton for Djinn.

## Setup

```bash
cd backend
python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
```

## Test

```bash
cd backend
. .venv/bin/activate
PYTHONPATH=. pytest -q
```

## Run

```bash
cd backend
. .venv/bin/activate
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

## Current Behavior

The backend intentionally refuses unsupported clinical answers because no
validated OMSZ corpus is indexed yet. The response contract already includes
`status`, `citations`, and `refusal_reason` for the future RAG implementation.

## Pipeline

`app.pipelines.ingest.run_dry_pipeline()` exposes the planned document pipeline
stages: PDF loading, text extraction, OCR, section detection, flowchart
extraction, manual clinical validation, chunking, embeddings, Qdrant indexing,
and PostgreSQL metadata storage.
