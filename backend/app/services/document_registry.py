from datetime import UTC, datetime
from pathlib import Path
from re import sub
from uuid import uuid4

from fastapi import HTTPException, UploadFile

from app.schemas import (
    KnowledgeDocumentRecord,
    KnowledgeDocumentStatus,
    KnowledgeStatusResponse,
)


class DocumentRegistry:
    def __init__(self, storage_dir: Path | None = None) -> None:
        self._storage_dir = storage_dir or Path('corpus/omsz')
        self._storage_dir.mkdir(parents=True, exist_ok=True)
        self._documents: dict[str, KnowledgeDocumentRecord] = {}

    def list_documents(self) -> list[KnowledgeDocumentRecord]:
        return list(self._documents.values())

    async def register_upload(self, file: UploadFile) -> KnowledgeDocumentRecord:
        filename = file.filename or 'document.pdf'
        content_type = file.content_type or ''
        if not filename.lower().endswith('.pdf') and content_type != 'application/pdf':
            raise HTTPException(status_code=400, detail='Only PDF uploads are accepted')

        content = await file.read()
        if not content:
            raise HTTPException(status_code=400, detail='PDF upload is empty')

        document_id = str(uuid4())
        safe_name = self._safe_filename(filename)
        stored_path = self._storage_dir / f'{document_id}-{safe_name}'
        stored_path.write_bytes(content)

        record = KnowledgeDocumentRecord(
            id=document_id,
            filename=filename,
            stored_path=str(stored_path),
            size_bytes=len(content),
            status=KnowledgeDocumentStatus.pending_ingest,
            imported_at=datetime.now(UTC).isoformat(),
            backend_document_id=document_id,
            error_message='Ingest pending: manual clinical validation required before RAG use.',
        )
        self._documents[document_id] = record
        return record

    def start_ingest(self, document_id: str) -> KnowledgeDocumentRecord:
        record = self._documents.get(document_id)
        if record is None:
            raise HTTPException(status_code=404, detail='Document not found')
        stored_path = Path(record.stored_path)
        if not stored_path.exists():
            updated = record.model_copy(
                update={
                    'status': KnowledgeDocumentStatus.failed,
                    'error_message': 'Stored PDF file is missing.',
                }
            )
            self._documents[document_id] = updated
            return updated
        updated = record.model_copy(
            update={
                'status': KnowledgeDocumentStatus.processed,
                'error_message': None,
            }
        )
        self._documents[document_id] = updated
        return updated

    def status(self) -> KnowledgeStatusResponse:
        documents = self.list_documents()
        processed = [doc for doc in documents if doc.status == KnowledgeDocumentStatus.processed]
        pending = [doc for doc in documents if doc.status == KnowledgeDocumentStatus.pending_ingest]
        failed = [doc for doc in documents if doc.status == KnowledgeDocumentStatus.failed]
        return KnowledgeStatusResponse(
            ready=bool(processed),
            document_count=len(documents),
            pending_count=len(pending),
            processed_count=len(processed),
            failed_count=len(failed),
        )

    @staticmethod
    def _safe_filename(filename: str) -> str:
        cleaned = sub(r'[^A-Za-z0-9._-]+', '_', Path(filename).name).strip('._')
        return cleaned or 'document.pdf'
