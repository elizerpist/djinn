from fastapi import FastAPI, Request, UploadFile

from app.infra.settings import BackendSettings
from app.runtime import DjinnRuntime, build_runtime
from app.schemas import (
    ChatRequest,
    ChatResponse,
    ConversationSummary,
    KnowledgeDocumentRecord,
    KnowledgeStatusResponse,
    MessageRecord,
    SystemReadinessResponse,
)


def create_app(runtime: DjinnRuntime | None = None) -> FastAPI:
    app = FastAPI(title='Djinn Backend', version='0.2.0')
    app.state.runtime = runtime or build_runtime(BackendSettings.from_env())

    @app.get('/health')
    def health() -> dict[str, str]:
        return {'status': 'ok', 'service': 'djinn-backend'}

    @app.get('/system/readiness', response_model=SystemReadinessResponse)
    def system_readiness(request: Request) -> SystemReadinessResponse:
        return _runtime(request).readiness.status()

    @app.get('/conversations', response_model=list[ConversationSummary])
    def list_conversations(request: Request) -> list[ConversationSummary]:
        return _runtime(request).conversations.list_conversations()

    @app.post('/conversations', response_model=ConversationSummary)
    def create_conversation(request: Request) -> ConversationSummary:
        return _runtime(request).conversations.create_conversation()

    @app.get(
        '/conversations/{conversation_id}/messages',
        response_model=list[MessageRecord],
    )
    def list_messages(conversation_id: str, request: Request) -> list[MessageRecord]:
        return _runtime(request).conversations.list_messages(conversation_id)

    @app.get('/knowledge/documents', response_model=list[KnowledgeDocumentRecord])
    def list_knowledge_documents(request: Request) -> list[KnowledgeDocumentRecord]:
        return _runtime(request).documents.list_documents()

    @app.post('/knowledge/documents', response_model=KnowledgeDocumentRecord)
    async def upload_knowledge_document(
        request: Request,
        file: UploadFile,
    ) -> KnowledgeDocumentRecord:
        return await _runtime(request).documents.register_upload(file)

    @app.post(
        '/knowledge/documents/{document_id}/ingest',
        response_model=KnowledgeDocumentRecord,
    )
    def start_knowledge_ingest(
        document_id: str,
        request: Request,
    ) -> KnowledgeDocumentRecord:
        return _runtime(request).documents.start_ingest(document_id)

    @app.get('/knowledge/status', response_model=KnowledgeStatusResponse)
    def knowledge_status(request: Request) -> KnowledgeStatusResponse:
        return _runtime(request).documents.status()

    @app.post('/chat', response_model=ChatResponse)
    def chat(request_body: ChatRequest, request: Request) -> ChatResponse:
        runtime = _runtime(request)
        conversation_id = runtime.conversations.ensure_conversation(
            request_body.conversation_id
        )
        runtime.conversations.append_message(
            conversation_id=conversation_id,
            sender='user',
            text=request_body.message,
        )
        response = runtime.answers.answer(
            conversation_id=conversation_id,
            message=request_body.message,
            knowledge=runtime.documents.status(),
        )
        runtime.conversations.append_message(
            conversation_id=conversation_id,
            sender='assistant',
            text=response.answer,
            status=response.status,
        )
        return response

    return app


def _runtime(request: Request) -> DjinnRuntime:
    return request.app.state.runtime


app = create_app()
