from app.schemas import SourceChunk


class ChunkRepository:
    def __init__(self) -> None:
        self._chunks_by_document: dict[str, list[SourceChunk]] = {}

    def replace_document_chunks(
        self, document_id: str, chunks: list[SourceChunk]
    ) -> None:
        self._chunks_by_document[document_id] = list(chunks)

    def list_chunks(self) -> list[SourceChunk]:
        chunks: list[SourceChunk] = []
        for document_chunks in self._chunks_by_document.values():
            chunks.extend(document_chunks)
        return chunks

    def count_document_chunks(self, document_id: str) -> int:
        return len(self._chunks_by_document.get(document_id, []))

    def clear(self) -> None:
        self._chunks_by_document.clear()
