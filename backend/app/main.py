from fastapi import FastAPI, UploadFile

from app.infra.metadata_store import LocalMetadataStore
from app.schemas import (
    ChatRequest,
    ChatResponse,
    ConversationSummary,
    KnowledgeDocumentRecord,
    KnowledgeStatusResponse,
    MessageRecord,
)
from app.services.answer_service import AnswerService
from app.services.chunk_repository import ChunkRepository
from app.services.conversation_store import ConversationStore
from app.services.document_registry import DocumentRegistry
from app.services.indexing_service import IndexingService
from app.services.pdf_text_extractor import PdfTextExtractor
from app.services.retrieval import RetrievalService

app = FastAPI(title='Djinn Backend', version='0.1.0')
store = ConversationStore()
chunks = ChunkRepository()
metadata = LocalMetadataStore()
indexing = IndexingService(
    vector_index=chunks,
    metadata_store=metadata,
    embedding_model='local-test',
)
retrieval = RetrievalService(repository=chunks, minimum_score=1)
answers = AnswerService(retrieval=retrieval)
documents = DocumentRegistry(indexing_service=indexing, extractor=PdfTextExtractor())


@app.get('/health')
def health() -> dict[str, str]:
    return {'status': 'ok', 'service': 'djinn-backend'}


@app.get('/conversations', response_model=list[ConversationSummary])
def list_conversations() -> list[ConversationSummary]:
    return store.list_conversations()


@app.post('/conversations', response_model=ConversationSummary)
def create_conversation() -> ConversationSummary:
    return store.create_conversation()


@app.get('/conversations/{conversation_id}/messages', response_model=list[MessageRecord])
def list_messages(conversation_id: str) -> list[MessageRecord]:
    return store.list_messages(conversation_id)




@app.get('/knowledge/documents', response_model=list[KnowledgeDocumentRecord])
def list_knowledge_documents() -> list[KnowledgeDocumentRecord]:
    return documents.list_documents()


@app.post('/knowledge/documents', response_model=KnowledgeDocumentRecord)
async def upload_knowledge_document(file: UploadFile) -> KnowledgeDocumentRecord:
    return await documents.register_upload(file)


@app.post('/knowledge/documents/{document_id}/ingest', response_model=KnowledgeDocumentRecord)
def start_knowledge_ingest(document_id: str) -> KnowledgeDocumentRecord:
    return documents.start_ingest(document_id)


@app.get('/knowledge/status', response_model=KnowledgeStatusResponse)
def knowledge_status() -> KnowledgeStatusResponse:
    return documents.status()


@app.post('/chat', response_model=ChatResponse)
def chat(request: ChatRequest) -> ChatResponse:
    conversation_id = store.ensure_conversation(request.conversation_id)
    store.append_message(
        conversation_id=conversation_id,
        sender='user',
        text=request.message,
    )
    knowledge = documents.status()
    response = answers.answer(
        conversation_id=conversation_id,
        message=request.message,
        knowledge=knowledge,
    )
    store.append_message(
        conversation_id=conversation_id,
        sender='assistant',
        text=response.answer,
        status=response.status,
    )
    return response
