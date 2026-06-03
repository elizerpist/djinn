import re

from app.schemas import SourceChunk

_MAX_CHARS = 900


def chunk_pages(
    *,
    document_id: str,
    filename: str,
    source_path: str,
    pages: list[tuple[int, str]],
    extraction_method: str = 'pymupdf',
) -> list[SourceChunk]:
    chunks: list[SourceChunk] = []
    for page, text in pages:
        normalized = re.sub(r'\s+', ' ', text).strip()
        if not normalized:
            continue
        parts = _split_text(normalized)
        for index, part in enumerate(parts):
            chunks.append(
                SourceChunk(
                    id=f'{document_id}-{page}-{index}',
                    document_id=document_id,
                    title=filename,
                    page=page,
                    text=part,
                    metadata={
                        'source_path': source_path,
                        'chunk_index': str(index),
                        'extraction_method': extraction_method,
                    },
                )
            )
    return chunks


def _split_text(text: str) -> list[str]:
    if len(text) <= _MAX_CHARS:
        return [text]
    parts: list[str] = []
    cursor = 0
    while cursor < len(text):
        parts.append(text[cursor:cursor + _MAX_CHARS].strip())
        cursor += _MAX_CHARS
    return [part for part in parts if part]
