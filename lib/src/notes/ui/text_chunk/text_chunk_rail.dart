import 'package:flutter/material.dart';

import '../../models/note_document.dart';
import '../native_selection_rail_bridge.dart';
import 'text_chunk_paragraphs.dart';

NativeSelectionRailState textChunkNativeRailState({
  required TextRange? activeRange,
  required List<NoteTextRangeTag> rangeTags,
  required bool canDeleteTag,
  required bool bottomRowExpanded,
  required bool roundedCard,
  required bool greyBackground,
  required bool borderVisible,
}) {
  if (activeRange == null) {
    return const NativeSelectionRailState.hidden();
  }
  return NativeSelectionRailState.visible(
    rangeStart: activeRange.start,
    rangeEnd: activeRange.end,
    tags: textChunkNativeRailTagsForRange(
      range: activeRange,
      rangeTags: rangeTags,
    ),
    canDeleteTag: canDeleteTag,
    hasTaggedRanges: rangeTags.isNotEmpty,
    bottomRowExpanded: bottomRowExpanded,
    roundedCard: roundedCard,
    greyBackground: greyBackground,
    borderVisible: borderVisible,
  );
}

List<NativeSelectionRailTag> textChunkNativeRailTagsForRange({
  required TextRange? range,
  required List<NoteTextRangeTag> rangeTags,
}) {
  return textChunkTagsForRange(range: range, rangeTags: rangeTags)
      .map(
        (tag) => NativeSelectionRailTag(
          id: tag.metadataText,
          label: tag.label,
          colorValue: tag.colorValue,
        ),
      )
      .toList(growable: false);
}
