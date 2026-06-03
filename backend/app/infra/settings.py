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

    @classmethod
    def from_env(cls, env: Mapping[str, str] | None = None) -> 'BackendSettings':
        values = environ if env is None else env
        return cls(
            use_qdrant=values.get('DJINN_USE_QDRANT', 'false').lower() == 'true',
            use_postgres=values.get('DJINN_USE_POSTGRES', 'false').lower() == 'true',
            qdrant_url=values.get('DJINN_QDRANT_URL', 'http://localhost:6333'),
            qdrant_collection=values.get('DJINN_QDRANT_COLLECTION', 'djinn_chunks'),
            postgres_dsn=values.get(
                'DJINN_POSTGRES_DSN',
                'postgresql://djinn:djinn_dev_password@localhost:5432/djinn',
            ),
        )
