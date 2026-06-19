import 'package:flutter/material.dart';

import '../models/note_document.dart';

class NoteTaggedTextVisualStyle {
  const NoteTaggedTextVisualStyle({
    required this.primaryBackground,
    required this.secondaryUnderlineColors,
  });

  final Color? primaryBackground;
  final List<Color> secondaryUnderlineColors;

  double get bottomPadding => secondaryUnderlineColors.length * 4.0;
}

NoteTaggedTextVisualStyle noteTaggedTextVisualStyle(
  List<NoteKnowledgeTag> tags,
) {
  if (tags.isEmpty) {
    return const NoteTaggedTextVisualStyle(
      primaryBackground: null,
      secondaryUnderlineColors: [],
    );
  }
  return NoteTaggedTextVisualStyle(
    primaryBackground: Color(tags.first.resolvedColorValue),
    secondaryUnderlineColors: [
      for (final tag in tags.skip(1)) Color(tag.resolvedColorValue),
    ],
  );
}

TextStyle noteTaggedEditableTextStyle(
  List<NoteKnowledgeTag> tags, {
  double alpha = 0.22,
}) {
  final visualStyle = noteTaggedTextVisualStyle(tags);
  final primary = visualStyle.primaryBackground;
  if (primary == null) {
    return const TextStyle();
  }
  return TextStyle(
    backgroundColor: primary.withValues(alpha: alpha),
    fontWeight: FontWeight.w600,
  );
}

class NoteSecondaryTagUnderlines extends StatelessWidget {
  const NoteSecondaryTagUnderlines({
    super.key,
    required this.tags,
    required this.prefix,
  });

  final List<NoteKnowledgeTag> tags;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    final secondaryColors = noteTaggedTextVisualStyle(
      tags,
    ).secondaryUnderlineColors;
    if (secondaryColors.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(left: 6, right: 6, bottom: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < secondaryColors.length; index += 1)
            Padding(
              padding: EdgeInsets.only(top: index == 0 ? 1 : 2),
              child: DecoratedBox(
                key: ValueKey('$prefix-secondary-underline-${index + 1}'),
                decoration: BoxDecoration(
                  color: secondaryColors[index],
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const SizedBox(height: 2),
              ),
            ),
        ],
      ),
    );
  }
}
