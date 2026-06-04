from enum import StrEnum
from pydantic import BaseModel, Field


class GroundingStatus(StrEnum):
    grounded = 'grounded'
    insufficient_evidence = 'insufficient_evidence'
    out_of_scope = 'out_of_scope'
    unsafe_request = 'unsafe_request'


class Citation(BaseModel):
    document_id: str
    title: str
    page: int | None = None
    section: str | None = None
    excerpt: str


class ChatRequest(BaseModel):
    message: str = Field(min_length=1)
    conversation_id: str | None = None


class ChatResponse(BaseModel):
    conversation_id: str
    answer: str
    status: GroundingStatus
    citations: list[Citation] = Field(default_factory=list)
    refusal_reason: str | None = None


class SourceChunk(BaseModel):
    id: str
    document_id: str
    title: str
    page: int | None = None
    text: str
    metadata: dict[str, str] = Field(default_factory=dict)


class RetrievalResult(BaseModel):
    chunks: list[SourceChunk] = Field(default_factory=list)
    citations: list[Citation] = Field(default_factory=list)


class AnswerDraft(BaseModel):
    answer: str
    cited_chunk_ids: list[str] = Field(default_factory=list)
    abstain: bool
    refusal_reason: str | None = None


class GroundednessVerdict(BaseModel):
    supported: bool
    unsupported_claims: list[str] = Field(default_factory=list)


class ComponentReadiness(BaseModel):
    ready: bool
    detail: str


class SystemReadinessResponse(BaseModel):
    ready: bool
    strict_mode: bool
    components: dict[str, ComponentReadiness]


class MessageRecord(BaseModel):
    id: str
    conversation_id: str
    sender: str
    text: str
    created_at: str
    status: GroundingStatus | None = None


class ConversationSummary(BaseModel):
    id: str
    title: str
    created_at: str
    updated_at: str
    message_count: int


class KnowledgeDocumentStatus(StrEnum):
    pending_ingest = 'pending_ingest'
    processing = 'processing'
    processed = 'processed'
    failed = 'failed'


class KnowledgeDocumentRecord(BaseModel):
    id: str
    filename: str
    stored_path: str
    size_bytes: int
    status: KnowledgeDocumentStatus
    imported_at: str
    backend_document_id: str | None = None
    error_message: str | None = None


class KnowledgeStatusResponse(BaseModel):
    ready: bool
    document_count: int
    pending_count: int
    processed_count: int
    failed_count: int
