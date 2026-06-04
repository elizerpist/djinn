from dataclasses import dataclass
from os import environ
from typing import Mapping


@dataclass(frozen=True)
class BackendSettings:
    use_qdrant: bool
    use_postgres: bool
    qdrant_url: str
    qdrant_collection: str
    postgres_dsn: str
    openai_api_key: str | None
    openai_chat_model: str
    openai_embedding_model: str
    openai_embedding_dimensions: int
    strict_mode: bool
    retrieval_min_score: float
    retrieval_limit: int
    max_context_chars: int

    @property
    def openai_configured(self) -> bool:
        return bool(self.openai_api_key)

    @classmethod
    def from_env(cls, env: Mapping[str, str] | None = None) -> 'BackendSettings':
        values = environ if env is None else env
        return cls(
            use_qdrant=values.get('DJINN_USE_QDRANT', 'false').lower() == 'true',
            use_postgres=values.get('DJINN_USE_POSTGRES', 'false').lower() == 'true',
            qdrant_url=values.get(
                'DJINN_QDRANT_URL',
                values.get('QDRANT_URL', 'http://localhost:6333'),
            ),
            qdrant_collection=values.get('DJINN_QDRANT_COLLECTION', 'djinn_chunks'),
            postgres_dsn=values.get(
                'DJINN_POSTGRES_DSN',
                values.get(
                    'DATABASE_URL',
                    'postgresql://djinn:djinn_dev_password@localhost:5432/djinn',
                ),
            ),
            openai_api_key=values.get('OPENAI_API_KEY') or None,
            openai_chat_model=values.get('DJINN_OPENAI_CHAT_MODEL', 'gpt-5-mini'),
            openai_embedding_model=values.get(
                'DJINN_OPENAI_EMBEDDING_MODEL',
                'text-embedding-3-large',
            ),
            openai_embedding_dimensions=int(
                values.get('DJINN_OPENAI_EMBEDDING_DIMENSIONS', '3072')
            ),
            strict_mode=values.get('DJINN_STRICT_MODE', 'true').lower() == 'true',
            retrieval_min_score=float(
                values.get('DJINN_RETRIEVAL_MIN_SCORE', '0.70')
            ),
            retrieval_limit=int(values.get('DJINN_RETRIEVAL_LIMIT', '3')),
            max_context_chars=int(values.get('DJINN_MAX_CONTEXT_CHARS', '12000')),
        )
