from fastapi import FastAPI

from app.schemas import ChatRequest, ChatResponse, ConversationSummary, MessageRecord
from app.services.conversation_store import ConversationStore
from app.services.safety import answer_without_corpus

app = FastAPI(title='Djinn Backend', version='0.1.0')
store = ConversationStore()


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


@app.post('/chat', response_model=ChatResponse)
def chat(request: ChatRequest) -> ChatResponse:
    conversation_id = store.ensure_conversation(request.conversation_id)
    store.append_message(
        conversation_id=conversation_id,
        sender='user',
        text=request.message,
    )
    response = answer_without_corpus(conversation_id)
    store.append_message(
        conversation_id=conversation_id,
        sender='assistant',
        text=response.answer,
        status=response.status,
    )
    return response
