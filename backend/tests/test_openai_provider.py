from app.infra.openai_provider import OpenAIAnswerProvider
from app.schemas import AnswerDraft, GroundednessVerdict, SourceChunk


def test_openai_provider_passes_closed_context_and_parses_draft():
    model = FakeStructuredModel(
        AnswerDraft(
            answer='ABCDE vizsgalat szukseges.',
            cited_chunk_ids=['chunk-1'],
            abstain=False,
            refusal_reason=None,
        )
    )
    provider = OpenAIAnswerProvider(draft_model=model, verifier_model=model)

    draft = provider.generate('Mi a teendo?', [_chunk('chunk-1')])

    assert draft.cited_chunk_ids == ['chunk-1']
    assert 'chunk-1' in model.last_prompt
    assert 'Kizarolag' in model.last_prompt


def test_openai_provider_parses_groundedness_verdict():
    verifier = FakeStructuredModel(
        GroundednessVerdict(supported=True, unsupported_claims=[])
    )
    provider = OpenAIAnswerProvider(draft_model=verifier, verifier_model=verifier)

    verdict = provider.verify_groundedness('ABCDE', [_chunk('chunk-1')])

    assert verdict.supported is True
    assert 'ABCDE' in verifier.last_prompt
    assert 'chunk-1' in verifier.last_prompt


class FakeStructuredModel:
    def __init__(self, response):
        self.response = response
        self.last_prompt = ''

    def invoke(self, prompt: str):
        self.last_prompt = prompt
        return self.response


def _chunk(chunk_id: str) -> SourceChunk:
    return SourceChunk(
        id=chunk_id,
        document_id='doc-1',
        title='omsz.pdf',
        page=1,
        text='Mellkasi fajdalom eseten ABCDE vizsgalat szukseges.',
        metadata={'extraction_method': 'pymupdf'},
    )
