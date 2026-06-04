from app.schemas import AnswerDraft, GroundednessVerdict, SourceChunk
from app.services.answer_verifier import AnswerVerifier


def test_verifier_resolves_only_retrieved_chunk_ids():
    verifier = AnswerVerifier(provider=FakeProvider(supported=True))

    result = verifier.verify(_draft(['chunk-1']), [_chunk('chunk-1')])

    assert result.allowed is True
    assert result.citations[0].document_id == 'doc-1'
    assert result.citations[0].page == 1


def test_verifier_blocks_unknown_citation_id():
    verifier = AnswerVerifier(provider=FakeProvider(supported=True))

    result = verifier.verify(_draft(['outside']), [_chunk('chunk-1')])

    assert result.allowed is False
    assert result.reason == 'citation_verification_failed'


def test_verifier_blocks_duplicate_citations():
    verifier = AnswerVerifier(provider=FakeProvider(supported=True))

    result = verifier.verify(
        _draft(['chunk-1', 'chunk-1']),
        [_chunk('chunk-1')],
    )

    assert result.allowed is False
    assert result.reason == 'citation_verification_failed'


def test_verifier_blocks_unsupported_groundedness():
    verifier = AnswerVerifier(provider=FakeProvider(supported=False))

    result = verifier.verify(_draft(['chunk-1']), [_chunk('chunk-1')])

    assert result.allowed is False
    assert result.reason == 'groundedness_verification_failed'


class FakeProvider:
    def __init__(self, *, supported: bool) -> None:
        self._supported = supported

    def verify_groundedness(self, answer: str, chunks: list[SourceChunk]):
        return GroundednessVerdict(
            supported=self._supported,
            unsupported_claims=[] if self._supported else ['unsupported'],
        )


def _draft(cited_chunk_ids: list[str]) -> AnswerDraft:
    return AnswerDraft(
        answer='ABCDE vizsgalat szukseges.',
        cited_chunk_ids=cited_chunk_ids,
        abstain=False,
        refusal_reason=None,
    )


def _chunk(chunk_id: str) -> SourceChunk:
    return SourceChunk(
        id=chunk_id,
        document_id='doc-1',
        title='protocol.pdf',
        page=1,
        text='ABCDE vizsgalat szukseges.',
        metadata={
            'source_path': 'corpus/omsz/protocol.pdf',
            'extraction_method': 'pymupdf',
        },
    )
