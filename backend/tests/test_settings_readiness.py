from app.infra.settings import BackendSettings
from app.schemas import ComponentReadiness, SystemReadinessResponse


def test_strict_settings_parse_provider_models_and_thresholds():
    settings = BackendSettings.from_env(
        {
            'OPENAI_API_KEY': 'secret',
            'DJINN_OPENAI_CHAT_MODEL': 'gpt-5-mini',
            'DJINN_OPENAI_EMBEDDING_MODEL': 'text-embedding-3-large',
            'DJINN_OPENAI_EMBEDDING_DIMENSIONS': '3072',
            'DJINN_RETRIEVAL_MIN_SCORE': '0.72',
            'DJINN_RETRIEVAL_LIMIT': '4',
        }
    )

    assert settings.openai_configured is True
    assert settings.openai_chat_model == 'gpt-5-mini'
    assert settings.openai_embedding_model == 'text-embedding-3-large'
    assert settings.openai_embedding_dimensions == 3072
    assert settings.retrieval_min_score == 0.72
    assert settings.retrieval_limit == 4
    assert settings.strict_mode is True


def test_readiness_response_does_not_serialize_secrets():
    response = SystemReadinessResponse(
        ready=False,
        strict_mode=True,
        components={
            'openai': ComponentReadiness(ready=False, detail='not configured'),
        },
    )

    encoded = response.model_dump_json()
    assert 'secret' not in encoded
    assert 'api_key' not in encoded
