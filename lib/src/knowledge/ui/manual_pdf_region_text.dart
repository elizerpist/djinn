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
  final selected = fragments
      .where((fragment) => fragment.bounds.overlaps(selectedRect))
      .where((fragment) => fragment.text.trim().isNotEmpty)
      .toList(growable: false);
  if (selected.isEmpty) {
    return '';
  }

  selected.sort(_comparePdfFragmentsReadingOrder);
  final lines = _groupFragmentsIntoLines(selected);
  final buffer = StringBuffer();
  double? previousCenterY;
  double? previousHeight;

  for (final line in lines) {
    if (buffer.isNotEmpty) {
      final gap = previousCenterY == null
          ? 0
          : (previousCenterY - line.centerY).abs();
      final threshold = (previousHeight ?? line.height) * 1.75;
      buffer.write(gap > threshold ? '\n\n' : '\n');
    }
    buffer.write(_joinLineFragments(line.fragments));
    previousCenterY = line.centerY;
    previousHeight = line.height;
  }

  return buffer.toString().trim();
}

List<PdfTextRegionFragment> textRegionFragmentsFromPageText(
  PdfPageText pageText,
) {
  return [
    for (final fragment in pageText.fragments)
      PdfTextRegionFragment(text: fragment.text, bounds: fragment.bounds),
  ];
}

int _comparePdfFragmentsReadingOrder(
  PdfTextRegionFragment a,
  PdfTextRegionFragment b,
) {
  final centerA = _centerY(a.bounds);
  final centerB = _centerY(b.bounds);
  if ((centerA - centerB).abs() > _lineTolerance(a, b)) {
    return centerB.compareTo(centerA);
  }
  return a.bounds.left.compareTo(b.bounds.left);
}

List<_PdfTextLine> _groupFragmentsIntoLines(List<PdfTextRegionFragment> items) {
  final lines = <_PdfTextLine>[];
  for (final fragment in items) {
    final center = _centerY(fragment.bounds);
    final existingIndex = lines.indexWhere(
      (line) => (line.centerY - center).abs() <= line.height * 0.55,
    );
    if (existingIndex < 0) {
      lines.add(_PdfTextLine([fragment]));
    } else {
      lines[existingIndex] = lines[existingIndex].append(fragment);
    }
  }

  for (var i = 0; i < lines.length; i += 1) {
    lines[i] = lines[i].sorted();
  }
  return lines;
}

String _joinLineFragments(List<PdfTextRegionFragment> fragments) {
  final buffer = StringBuffer();
  for (final fragment in fragments) {
    final text = fragment.text.trim();
    if (text.isEmpty) {
      continue;
    }
    if (buffer.isEmpty || _noSpaceBefore(text)) {
      buffer.write(text);
    } else {
      buffer.write(' $text');
    }
  }
  return buffer.toString().replaceAllMapped(
    RegExp(r'\s+([,.;:])'),
    (match) => match.group(1)!,
  );
}

bool _noSpaceBefore(String text) => RegExp(r'^[,.;:!?)]').hasMatch(text);

double _centerY(PdfRect rect) => (rect.top + rect.bottom) / 2;

double _height(PdfRect rect) => (rect.top - rect.bottom).abs();

double _lineTolerance(PdfTextRegionFragment a, PdfTextRegionFragment b) =>
    (_height(a.bounds) + _height(b.bounds)) * 0.35;

class _PdfTextLine {
  const _PdfTextLine(this.fragments);

  final List<PdfTextRegionFragment> fragments;

  double get centerY =>
      _average(fragments.map((fragment) => _centerY(fragment.bounds)));

  double get height =>
      _average(fragments.map((fragment) => _height(fragment.bounds)));

  _PdfTextLine append(PdfTextRegionFragment fragment) =>
      _PdfTextLine([...fragments, fragment]);

  _PdfTextLine sorted() {
    final next = [...fragments]
      ..sort((a, b) => a.bounds.left.compareTo(b.bounds.left));
    return _PdfTextLine(next);
  }
}

double _average(Iterable<double> values) {
  var total = 0.0;
  var count = 0;
  for (final value in values) {
    total += value;
    count += 1;
  }
  return count == 0 ? 0 : total / count;
}
