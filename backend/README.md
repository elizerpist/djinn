# Djinn Backend

FastAPI backend for the strict, source-bounded Djinn RAG workflow.

> **Opcionális, külön futtatási útvonal.** A Djinn kanonikus termék-,
> navigációs és Chunk-modelljét a repó gyökér `README.md` fájlja határozza meg.
> Ez a fájl kizárólag a történeti/szerveres prototípus üzemeltetési leírása,
> és nem írhatja felül a két kanonikus chunktípust vagy a local-first Android
> architektúrát.

## Safety Contract

- The model receives only retrieved application document chunks and no tools.
- OpenAI generation uses structured output through LangChain.
- LangGraph routes readiness, guardrail, retrieval, citation, groundedness, or
  infrastructure failures to a structured refusal with no citations.
- Qdrant stores vectors; PostgreSQL stores source and indexing audit metadata.
- NeMo Guardrails runs input, retrieval, output, and fact-check policies.
- The OpenAI API key exists only in the backend environment.

This prototype is not clinically validated. Only PyMuPDF text extraction is
trusted in the current answer path. OCR and flowchart interpretation require a
future validated pipeline.

## Configure

From the repository root:

```bash
cp .env.example .env
# Set OPENAI_API_KEY in .env. Never commit the file.
docker compose up -d qdrant postgres
```

Strict production-style runtime requires these values:

```text
OPENAI_API_KEY
DJINN_USE_QDRANT=true
DJINN_USE_POSTGRES=true
DJINN_QDRANT_URL
DJINN_POSTGRES_DSN
```

Model names, embedding dimensions, retrieval threshold/count, context limit,
and collection name have safe defaults in `.env.example`.

## Install And Test

```bash
cd backend
python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
PYTHONPATH=. pytest -q
```

Tests inject fakes and do not make live OpenAI calls or spend provider credits.

## Run

```bash
cd backend
. .venv/bin/activate
uvicorn app.main:app --env-file ../.env --host 127.0.0.1 --port 8000
```

Check strict runtime health:

```bash
curl http://127.0.0.1:8000/health
curl http://127.0.0.1:8000/system/readiness
```

Every component under `/system/readiness` must be ready. The endpoint never
returns API keys or connection secrets.

## Trial Flow

1. Start Qdrant and PostgreSQL and then FastAPI.
2. Confirm `/system/readiness` is ready.
3. Install the `djinn-trial-apk` GitHub artifact on the same phone running the
   backend at `127.0.0.1:8000`.
4. Import a text-bearing PDF with the folder button and sync it.
5. Ask a question. The backend either returns a cited, verified answer or a
   specific fail-closed refusal.

Ingest sends extracted chunks to OpenAI for embeddings. Chat sends the question
and a bounded set of retrieved chunks to OpenAI. It never sends the entire
corpus or enables web search.
