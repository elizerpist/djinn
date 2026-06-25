import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/knowledge/ui/source_chunk_rect.dart';

void main() {
  test('writes and reads normalized page rect json', () {
    final json = sourceRectJsonFromPageRect(
      pageNumber: 3,
      source: 'pdf_text',
      pageRect: const Rect.fromLTWH(120, 80, 240, 160),
      pageSize: const Size(600, 800),
      extra: const {
        'created_by': 'manual_chunk_editor',
      },
    );

    final decoded = jsonDecode(json) as Map<String, Object?>;
    expect(decoded['page'], 3);
    expect(decoded['source'], 'pdf_text');
    expect(decoded, contains('page_rect_normalized'));
    expect(decoded, isNot(contains('viewport_rect')));

    final rect = sourceRectFromJson(json);
    expect(rect, isNotNull);
    expect(rect!.pageNumber, 3);
    expect(rect.normalizedRect.left, closeTo(0.2, 0.0001));
    expect(rect.normalizedRect.top, closeTo(0.1, 0.0001));
    expect(rect.normalizedRect.right, closeTo(0.6, 0.0001));
    expect(rect.normalizedRect.bottom, closeTo(0.3, 0.0001));
    expect(rect.pageRectForSize(const Size(300, 400)), const Rect.fromLTWH(60, 40, 120, 80));
  });

  test('reads legacy viewport rect as page-local fallback', () {
    const legacy =
        '{"page":2,"viewport_rect":{"left":10,"top":20,"right":110,"bottom":70}}';

    final rect = sourceRectFromJson(legacy);

    expect(rect, isNotNull);
    expect(rect!.pageNumber, 2);
    expect(rect.isLegacyViewportRect, isTrue);
    expect(rect.pageRectForSize(const Size(300, 400)), const Rect.fromLTRB(10, 20, 110, 70));
  });

  test('converts normalized top-left page rect to pdf bottom-left coordinates', () {
    final rect = SourceChunkRect(
      pageNumber: 1,
      normalizedRect: const Rect.fromLTRB(0.10, 0.20, 0.70, 0.35),
    );

    final pdfRect = rect.pdfRectForPageSize(const Size(600, 800));

    expect(pdfRect.left, closeTo(60, 0.0001));
    expect(pdfRect.right, closeTo(420, 0.0001));
    expect(pdfRect.top, closeTo(640, 0.0001));
    expect(pdfRect.bottom, closeTo(520, 0.0001));
  });
}
