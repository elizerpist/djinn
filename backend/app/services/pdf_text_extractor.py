from pathlib import Path

import fitz


class PdfExtractionError(Exception):
    pass


class PdfTextExtractor:
    def extract_pages(self, pdf_path: Path) -> list[tuple[int, str]]:
        try:
            document = fitz.open(pdf_path)
        except Exception as error:
            raise PdfExtractionError(str(error)) from error
        try:
            pages: list[tuple[int, str]] = []
            for index, page in enumerate(document, start=1):
                text = ' '.join(page.get_text('text').split())
                if text:
                    pages.append((index, text))
            return pages
        finally:
            document.close()
