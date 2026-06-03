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
