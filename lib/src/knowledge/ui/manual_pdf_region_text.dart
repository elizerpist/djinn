import 'package:pdfrx/pdfrx.dart';

class PdfTextRegionFragment {
  const PdfTextRegionFragment({required this.text, required this.bounds});

  final String text;
  final PdfRect bounds;
}

String textFromFragmentsInPdfRect({
  required List<PdfTextRegionFragment> fragments,
  required PdfRect selectedRect,
}) {
  return fragments
      .where((fragment) => fragment.bounds.overlaps(selectedRect))
      .map((fragment) => fragment.text.trim())
      .where((text) => text.isNotEmpty)
      .join('\n')
      .trim();
}

List<PdfTextRegionFragment> textRegionFragmentsFromPageText(
  PdfPageText pageText,
) {
  return [
    for (final fragment in pageText.fragments)
      PdfTextRegionFragment(text: fragment.text, bounds: fragment.bounds),
  ];
}
