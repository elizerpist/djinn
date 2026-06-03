from app.pipelines.ingest import run_dry_pipeline


EXPECTED_STAGE_NAMES = [
    'load_pdfs',
    'extract_text',
    'run_ocr',
    'detect_sections',
    'extract_flowcharts',
    'validate_flowcharts',
    'chunk_sources',
    'create_embeddings',
    'index_qdrant',
    'store_metadata',
]


def test_dry_pipeline_exposes_document_processing_stage_order():
    results = run_dry_pipeline(corpus_dir='corpus/omsz')

    assert [stage.name for stage in results] == EXPECTED_STAGE_NAMES


def test_flowchart_stage_requires_manual_validation():
    results = run_dry_pipeline(corpus_dir='corpus/omsz')
    validation_stage = next(stage for stage in results if stage.name == 'validate_flowcharts')

    assert validation_stage.status == 'manual_validation_required'
    assert 'clinical' in validation_stage.notes.lower()
