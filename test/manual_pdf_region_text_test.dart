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

  test('joins word fragments on the same visual line with spaces', () {
    final text = textFromFragmentsInPdfRect(
      fragments: const [
        PdfTextRegionFragment(text: 'Az', bounds: PdfRect(40, 700, 58, 684)),
        PdfTextRegionFragment(
          text: 'eljárásrend',
          bounds: PdfRect(62, 700, 145, 684),
        ),
        PdfTextRegionFragment(
          text: 'célja:',
          bounds: PdfRect(150, 700, 194, 684),
        ),
        PdfTextRegionFragment(text: '•', bounds: PdfRect(44, 672, 50, 656)),
        PdfTextRegionFragment(text: 'az', bounds: PdfRect(64, 672, 80, 656)),
        PdfTextRegionFragment(
          text: 'ellátás',
          bounds: PdfRect(84, 672, 135, 656),
        ),
        PdfTextRegionFragment(
          text: 'során',
          bounds: PdfRect(139, 672, 178, 656),
        ),
      ],
      selectedRect: const PdfRect(30, 720, 220, 640),
    );

    expect(text, 'Az eljárásrend célja:\n• az ellátás során');
  });

  test('adds a blank line for paragraph gaps and keeps numbered markers', () {
    final text = textFromFragmentsInPdfRect(
      fragments: const [
        PdfTextRegionFragment(text: 'I.', bounds: PdfRect(40, 700, 52, 684)),
        PdfTextRegionFragment(
          text: 'Célok:',
          bounds: PdfRect(80, 700, 128, 684),
        ),
        PdfTextRegionFragment(text: 'Jelen', bounds: PdfRect(40, 650, 78, 634)),
        PdfTextRegionFragment(
          text: 'eljárásrend',
          bounds: PdfRect(82, 650, 165, 634),
        ),
      ],
      selectedRect: const PdfRect(30, 720, 220, 620),
    );

    expect(text, 'I. Célok:\n\nJelen eljárásrend');
  });
}
