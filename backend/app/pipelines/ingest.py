from dataclasses import dataclass


@dataclass(frozen=True)
class PipelineStageResult:
    name: str
    status: str
    notes: str


_STAGE_RESULTS = [
    PipelineStageResult(
        name='load_pdfs',
        status='dry_run',
        notes='Locate approved OMSZ PDF files in the configured local corpus directory.',
    ),
    PipelineStageResult(
        name='extract_text',
        status='dry_run',
        notes='Extract machine-readable text with PyMuPDF, pdfplumber, or Unstructured adapters.',
    ),
    PipelineStageResult(
        name='run_ocr',
        status='dry_run',
        notes='Run OCR for scanned pages and extracted figure regions when text confidence is low.',
    ),
    PipelineStageResult(
        name='detect_sections',
        status='dry_run',
        notes='Identify page numbers, headings, sections, figures, and source metadata.',
    ),
    PipelineStageResult(
        name='extract_flowcharts',
        status='dry_run',
        notes='Cut flowchart images from PDF pages and preserve page and bounding-box metadata.',
    ),
    PipelineStageResult(
        name='validate_flowcharts',
        status='manual_validation_required',
        notes='Clinical flowchart nodes and decision edges must be manually validated before retrieval use.',
    ),
    PipelineStageResult(
        name='chunk_sources',
        status='dry_run',
        notes='Create text and validated-flowchart chunks with source document, page, section, and figure ids.',
    ),
    PipelineStageResult(
        name='create_embeddings',
        status='dry_run',
        notes='Create embeddings for retrievable chunks after validation gates pass.',
    ),
    PipelineStageResult(
        name='index_qdrant',
        status='dry_run',
        notes='Upsert chunk vectors into Qdrant with stable source metadata ids.',
    ),
    PipelineStageResult(
        name='store_metadata',
        status='dry_run',
        notes='Store document, section, figure, and audit metadata in PostgreSQL.',
    ),
]


def run_dry_pipeline(corpus_dir: str) -> list[PipelineStageResult]:
    if not corpus_dir.strip():
        raise ValueError('corpus_dir must not be blank')
    return list(_STAGE_RESULTS)
