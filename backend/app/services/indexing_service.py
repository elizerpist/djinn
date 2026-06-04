from app.infra.metadata_store import MetadataStore
from app.infra.vector_index import VectorIndex
from app.schemas import SourceChunk


class IndexingError(Exception):
    pass


class IndexingService:
    def __init__(
        self,
        *,
        vector_index: VectorIndex,
        metadata_store: MetadataStore,
        embedding_model: str,
    ) -> None:
        self._vector_index = vector_index
        self._metadata_store = metadata_store
        self._embedding_model = embedding_model

    def replace_document_chunks(
        self,
        document_id: str,
        chunks: list[SourceChunk],
    ) -> None:
        try:
            self._vector_index.replace_document_chunks(document_id, chunks)
            self._metadata_store.replace_document_chunks(
                document_id,
                chunks,
                embedding_model=self._embedding_model,
            )
        except Exception as error:
            self._clear_vector_after_failure(document_id)
            raise IndexingError(str(error)) from error

    def _clear_vector_after_failure(self, document_id: str) -> None:
        try:
            self._vector_index.replace_document_chunks(document_id, [])
        except Exception:
            pass
