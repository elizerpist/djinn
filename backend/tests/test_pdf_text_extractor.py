from pathlib import Path

import fitz

from app.services.pdf_text_extractor import PdfTextExtractor


def test_extracts_text_by_page(tmp_path: Path):
    pdf_path = tmp_path / 'sample.pdf'
    document = fitz.open()
    page = document.new_page()
    page.insert_text((72, 72), 'Mellkasi fajdalom ABCDE vizsgalat')
    document.save(pdf_path)
    document.close()

    pages = PdfTextExtractor().extract_pages(pdf_path)

    assert pages == [(1, 'Mellkasi fajdalom ABCDE vizsgalat')]
