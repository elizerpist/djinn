import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

import 'package:djinn/src/knowledge/ui/manual_pdf_region_text.dart';

void main() {
  test('keeps only pdf text fragments overlapping the selected rect', () {
    final text = textFromFragmentsInPdfRect(
      fragments: const [
        PdfTextRegionFragment(
          text: 'Fejléc',
          bounds: PdfRect(20, 780, 180, 740),
        ),
        PdfTextRegionFragment(
          text: 'Kijelölt első sor',
          bounds: PdfRect(80, 620, 260, 590),
        ),
        PdfTextRegionFragment(
          text: 'Kijelölt második sor',
          bounds: PdfRect(82, 585, 270, 555),
        ),
        PdfTextRegionFragment(
          text: 'Másik bekezdés',
          bounds: PdfRect(80, 430, 270, 390),
        ),
      ],
      selectedRect: const PdfRect(60, 640, 300, 540),
    );

    expect(text, 'Kijelölt első sor\nKijelölt második sor');
  });
}
