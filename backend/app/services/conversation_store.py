from datetime import UTC, datetime
from uuid import uuid4

from app.schemas import ConversationSummary, MessageRecord


class ConversationStore:
    def __init__(self) -> None:
        self._messages: dict[str, list[MessageRecord]] = {}
        self._created_at: dict[str, str] = {}
        self._updated_at: dict[str, str] = {}
        self._titles: dict[str, str] = {}

    def create_conversation(self, title: str = 'Uj chat') -> ConversationSummary:
        conversation_id = str(uuid4())
        now = self._now()
        self._messages[conversation_id] = []
        self._created_at[conversation_id] = now
        self._updated_at[conversation_id] = now
        self._titles[conversation_id] = title
        return self._summary(conversation_id)

    def ensure_conversation(self, conversation_id: str | None) -> str:
        if conversation_id and conversation_id in self._messages:
            return conversation_id
        return self.create_conversation().id

    def list_conversations(self) -> list[ConversationSummary]:
        return [self._summary(conversation_id) for conversation_id in self._messages]

    def list_messages(self, conversation_id: str) -> list[MessageRecord]:
        return list(self._messages.get(conversation_id, []))

    def append_message(
        self,
        *,
        conversation_id: str,
        sender: str,
        text: str,
        status: object | None = None,
    ) -> MessageRecord:
        record = MessageRecord(
            id=str(uuid4()),
            conversation_id=conversation_id,
            sender=sender,
            text=text,
            created_at=self._now(),
            status=status,
        )
        self._messages.setdefault(conversation_id, []).append(record)
        self._updated_at[conversation_id] = record.created_at
        if sender == 'user' and self._titles.get(conversation_id) == 'Uj chat':
            self._titles[conversation_id] = text[:48]
        return record

    def _summary(self, conversation_id: str) -> ConversationSummary:
        return ConversationSummary(
            id=conversation_id,
            title=self._titles[conversation_id],
            created_at=self._created_at[conversation_id],
            updated_at=self._updated_at[conversation_id],
            message_count=len(self._messages[conversation_id]),
        )

    @staticmethod
    def _now() -> str:
        return datetime.now(UTC).isoformat()
