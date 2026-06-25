import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

class SourceChunkRect {
  const SourceChunkRect({
    required this.pageNumber,
    required this.normalizedRect,
    this.legacyViewportRect,
  });

  final int pageNumber;
  final Rect normalizedRect;
  final Rect? legacyViewportRect;

  bool get isLegacyViewportRect => legacyViewportRect != null;

  Rect pageRectForSize(Size pageSize) {
    final legacy = legacyViewportRect;
    if (legacy != null) {
      return legacy;
    }
    return Rect.fromLTRB(
      normalizedRect.left * pageSize.width,
      normalizedRect.top * pageSize.height,
      normalizedRect.right * pageSize.width,
      normalizedRect.bottom * pageSize.height,
    );
  }

  PdfRect pdfRectForPageSize(Size pageSize) {
    final pageRect = pageRectForSize(pageSize);
    return PdfRect(
      pageRect.left,
      pageSize.height - pageRect.top,
      pageRect.right,
      pageSize.height - pageRect.bottom,
    );
  }
}

String sourceRectJsonFromPageRect({
  required int pageNumber,
  required String source,
  required Rect pageRect,
  required Size pageSize,
  Map<String, Object?> extra = const {},
}) {
  final normalized = _normalizedRect(pageRect, pageSize);
  return jsonEncode({
    ...extra,
    'source': source,
    'page': pageNumber,
    'page_rect_normalized': {
      'left': normalized.left,
      'top': normalized.top,
      'right': normalized.right,
      'bottom': normalized.bottom,
    },
  });
}

SourceChunkRect? sourceRectFromJson(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  try {
    final decoded = jsonDecode(value);
    if (decoded is! Map) {
      return null;
    }
    final pageNumber = ((decoded['page'] as num?)?.toInt() ?? 1).clamp(
      1,
      1 << 30,
    );
    final normalized = _rectFromMap(decoded['page_rect_normalized']);
    if (normalized != null) {
      return SourceChunkRect(
        pageNumber: pageNumber,
        normalizedRect: _clampedUnitRect(normalized),
      );
    }
    final legacy = _rectFromMap(decoded['viewport_rect']);
    if (legacy != null) {
      return SourceChunkRect(
        pageNumber: pageNumber,
        normalizedRect: Rect.zero,
        legacyViewportRect: legacy,
      );
    }
    return null;
  } catch (_) {
    return null;
  }
}

Rect _normalizedRect(Rect rect, Size pageSize) {
  if (pageSize.width <= 0 || pageSize.height <= 0) {
    return Rect.zero;
  }
  return _clampedUnitRect(
    Rect.fromLTRB(
      rect.left / pageSize.width,
      rect.top / pageSize.height,
      rect.right / pageSize.width,
      rect.bottom / pageSize.height,
    ),
  );
}

Rect _clampedUnitRect(Rect rect) {
  return Rect.fromLTRB(
    rect.left.clamp(0.0, 1.0),
    rect.top.clamp(0.0, 1.0),
    rect.right.clamp(0.0, 1.0),
    rect.bottom.clamp(0.0, 1.0),
  );
}

Rect? _rectFromMap(Object? value) {
  if (value is! Map) {
    return null;
  }
  final left = (value['left'] as num?)?.toDouble();
  final top = (value['top'] as num?)?.toDouble();
  final right = (value['right'] as num?)?.toDouble();
  final bottom = (value['bottom'] as num?)?.toDouble();
  if (left == null || top == null || right == null || bottom == null) {
    return null;
  }
  return Rect.fromLTRB(left, top, right, bottom);
}
