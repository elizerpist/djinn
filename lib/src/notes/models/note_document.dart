import 'dart:convert';

import '../../ai/ai_client.dart';

enum NoteBlockType {
  paragraph('paragraph'),
  heading('heading'),
  listItem('list_item'),
  table('table'),
  flowchart('flowchart'),
  mixed('mixed');

  const NoteBlockType(this.wireName);

  final String wireName;

  static NoteBlockType fromWireName(String? value) {
    return NoteBlockType.values.firstWhere(
      (type) => type.wireName == value,
      orElse: () => NoteBlockType.paragraph,
    );
  }
}

class NoteSearchRoles {
  static const none = '';
  static const definition = 'definition';
  static const fact = 'fact';
  static const process = 'process';
  static const tableRule = 'table_rule';
  static const example = 'example';
  static const analogy = 'analogy';
  static const ignore = 'ignore';

  static const values = [
    none,
    definition,
    fact,
    process,
    tableRule,
    example,
    analogy,
    ignore,
  ];

  static String normalize(String? value) {
    final trimmed = value?.trim() ?? '';
    return values.contains(trimmed) ? trimmed : none;
  }

  static String label(String value) {
    return switch (normalize(value)) {
      definition => 'Definíció',
      fact => 'Tény',
      process => 'Folyamat',
      tableRule => 'Táblázatos szabály',
      example => 'Példa',
      analogy => 'Analógia',
      ignore => 'Keresésből kihagyás',
      _ => 'Nincs szerep',
    };
  }
}

class NoteKnowledgeTagTypes {
  static const topic = 'topic';
  static const type = 'type';
  static const state = 'state';
  static const symbol = 'symbol';
  static const node = 'node';
  static const branch = 'branch';
  static const custom = 'custom';

  static const values = [topic, type, state, symbol, node, branch, custom];

  static String normalize(String? value) {
    final normalized = value?.trim().toLowerCase().replaceAll(' ', '_') ?? '';
    return values.contains(normalized) ? normalized : custom;
  }
}

class NoteKnowledgeTag {
  const NoteKnowledgeTag({
    this.id,
    required this.type,
    required this.label,
    this.colorValue,
    this.colorSlotId,
    this.folderId,
  });

  final String? id;
  final String type;
  final String label;
  final int? colorValue;
  final int? colorSlotId;
  final String? folderId;

  factory NoteKnowledgeTag.fromJson(Object? value) {
    if (value is Map) {
      return NoteKnowledgeTag(
        id: value['id']?.toString().trim().isNotEmpty == true
            ? value['id']?.toString().trim()
            : null,
        type: NoteKnowledgeTagTypes.normalize(value['type']?.toString()),
        label: value['label']?.toString().trim() ?? '',
        colorValue: _tagColorFromJson(
          value['colorValue'] ?? value['color'] ?? value['colorHex'],
        ),
        colorSlotId: _tagIntFromJson(value['colorSlotId']),
        folderId: value['folderId']?.toString().trim().isNotEmpty == true
            ? value['folderId']?.toString().trim()
            : null,
      );
    }
    return NoteKnowledgeTag.parse(value?.toString() ?? '');
  }

  static NoteKnowledgeTag parse(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return const NoteKnowledgeTag(
        type: NoteKnowledgeTagTypes.custom,
        label: '',
      );
    }
    final separator = trimmed.indexOf(':');
    if (separator <= 0) {
      return NoteKnowledgeTag(
        type: NoteKnowledgeTagTypes.custom,
        label: trimmed,
      );
    }
    final type = trimmed.substring(0, separator).trim();
    final label = trimmed.substring(separator + 1).trim();
    return NoteKnowledgeTag(
      type: NoteKnowledgeTagTypes.normalize(type),
      label: label,
    );
  }

  static List<NoteKnowledgeTag> parseMany(String value) {
    return value
        .split(',')
        .map(NoteKnowledgeTag.parse)
        .where((tag) => tag.label.trim().isNotEmpty)
        .toList(growable: false);
  }

  String get metadataText {
    final normalizedType = NoteKnowledgeTagTypes.normalize(type);
    final trimmedLabel = label.trim();
    if (trimmedLabel.isEmpty) {
      return '';
    }
    return '$normalizedType:$trimmedLabel';
  }

  int get resolvedColorValue {
    final slotId = colorSlotId;
    if (slotId != null) {
      final bounded = slotId.clamp(0, noteTagColorSlots.length - 1).toInt();
      return noteTagColorSlots[bounded];
    }
    return colorValue ?? _stableTagColorValue(metadataText);
  }

  Map<String, Object?> toJson() {
    final trimmedId = id?.trim();
    final trimmedFolderId = folderId?.trim();
    return {
      if (trimmedId != null && trimmedId.isNotEmpty) 'id': trimmedId,
      'type': NoteKnowledgeTagTypes.normalize(type),
      'label': label.trim(),
      if (colorSlotId != null) 'colorSlotId': colorSlotId,
      if (trimmedFolderId != null && trimmedFolderId.isNotEmpty)
        'folderId': trimmedFolderId,
      if (colorValue != null) 'colorValue': colorValue,
    };
  }

  NoteKnowledgeTag copyWith({
    String? id,
    bool clearId = false,
    String? type,
    String? label,
    int? colorValue,
    bool clearColorValue = false,
    int? colorSlotId,
    bool clearColorSlotId = false,
    String? folderId,
    bool clearFolderId = false,
  }) {
    return NoteKnowledgeTag(
      id: clearId ? null : id ?? this.id,
      type: type ?? this.type,
      label: label ?? this.label,
      colorValue: clearColorValue ? null : colorValue ?? this.colorValue,
      colorSlotId: clearColorSlotId ? null : colorSlotId ?? this.colorSlotId,
      folderId: clearFolderId ? null : folderId ?? this.folderId,
    );
  }
}

class NoteTextRangeTag {
  const NoteTextRangeTag({
    required this.id,
    required this.start,
    required this.end,
    required this.tag,
    this.tags = const [],
  });

  final String id;
  final int start;
  final int end;
  final NoteKnowledgeTag tag;
  final List<NoteKnowledgeTag> tags;

  List<NoteKnowledgeTag> get resolvedTags {
    if (tags.isNotEmpty) {
      return tags;
    }
    return tag.label.trim().isEmpty ? const [] : [tag];
  }

  factory NoteTextRangeTag.fromJson(Map<String, Object?> json) {
    final parsedTags = _tagsFromJson(json['tags']);
    final primaryTag = parsedTags.isNotEmpty
        ? parsedTags.first
        : NoteKnowledgeTag.fromJson(json['tag']);
    return NoteTextRangeTag(
      id: json['id']?.toString() ?? 'range-1',
      start: json['start'] is int ? json['start'] as int : 0,
      end: json['end'] is int ? json['end'] as int : 0,
      tag: primaryTag,
      tags: parsedTags,
    );
  }

  bool get isValid => start >= 0 && end > start && resolvedTags.isNotEmpty;

  NoteTextRangeTag clampToTextLength(int length) {
    final normalizedLength = length < 0 ? 0 : length;
    final clampedStart = start.clamp(0, normalizedLength).toInt();
    final clampedEnd = end.clamp(0, normalizedLength).toInt();
    return NoteTextRangeTag(
      id: id,
      start: clampedStart,
      end: clampedEnd,
      tag: tag,
      tags: tags,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'start': start,
      'end': end,
      'tag': tag.toJson(),
      if (tags.isNotEmpty) 'tags': tags.map((tag) => tag.toJson()).toList(),
    };
  }

  NoteTextRangeTag copyWith({
    String? id,
    int? start,
    int? end,
    NoteKnowledgeTag? tag,
    List<NoteKnowledgeTag>? tags,
  }) {
    return NoteTextRangeTag(
      id: id ?? this.id,
      start: start ?? this.start,
      end: end ?? this.end,
      tag: tag ?? this.tag,
      tags: tags ?? this.tags,
    );
  }
}

/// User-controlled rich-text background fill.
///
/// This is deliberately separate from [NoteTextRangeTag]: knowledge tags are
/// metadata, while fills are editable presentation data. [targetKey] scopes a
/// range inside a rich NoteChunk section (for example `list:item-1` or
/// `table:0:1`). Flowchart labels keep the same range model directly on their
/// node or edge.
class NoteTextFill {
  const NoteTextFill({
    required this.id,
    required this.start,
    required this.end,
    required this.colorValue,
    this.targetKey,
  });

  final String id;
  final int start;
  final int end;
  final int colorValue;
  final String? targetKey;

  bool get isValid =>
      id.trim().isNotEmpty && start >= 0 && end > start && colorValue != 0;

  factory NoteTextFill.fromJson(Object? value) {
    if (value is! Map) {
      return const NoteTextFill(id: '', start: 0, end: 0, colorValue: 0);
    }
    final json = Map<Object?, Object?>.from(value);
    final target = json['targetKey']?.toString().trim();
    return NoteTextFill(
      id: json['id']?.toString() ?? '',
      start: _tagIntFromJson(json['start']) ?? 0,
      end: _tagIntFromJson(json['end']) ?? 0,
      colorValue: _tagColorFromJson(json['colorValue']) ?? 0,
      targetKey: target == null || target.isEmpty ? null : target,
    );
  }

  NoteTextFill clampToTextLength(int length) {
    final normalizedLength = length < 0 ? 0 : length;
    final clampedStart = start.clamp(0, normalizedLength).toInt();
    final clampedEnd = end.clamp(clampedStart, normalizedLength).toInt();
    return copyWith(start: clampedStart, end: clampedEnd);
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'start': start,
      'end': end,
      'colorValue': colorValue,
      if (targetKey != null && targetKey!.trim().isNotEmpty)
        'targetKey': targetKey,
    };
  }

  NoteTextFill copyWith({
    String? id,
    int? start,
    int? end,
    int? colorValue,
    String? targetKey,
    bool clearTargetKey = false,
  }) {
    return NoteTextFill(
      id: id ?? this.id,
      start: start ?? this.start,
      end: end ?? this.end,
      colorValue: colorValue ?? this.colorValue,
      targetKey: clearTargetKey ? null : targetKey ?? this.targetKey,
    );
  }
}

List<NoteTextFill> transformNoteTextFillsForEdit(
  List<NoteTextFill> fills, {
  required String oldText,
  required String newText,
  String? targetKey,
}) {
  if (oldText == newText) {
    return [
      for (final fill in fills)
        if (!_noteTextFillMatchesTarget(fill, targetKey))
          fill
        else
          fill.clampToTextLength(newText.length),
    ].where((fill) => fill.isValid).toList(growable: false);
  }

  var editStart = 0;
  final sharedPrefixLimit = oldText.length < newText.length
      ? oldText.length
      : newText.length;
  while (editStart < sharedPrefixLimit &&
      oldText.codeUnitAt(editStart) == newText.codeUnitAt(editStart)) {
    editStart += 1;
  }

  var sharedSuffixLength = 0;
  final oldSuffixLimit = oldText.length - editStart;
  final newSuffixLimit = newText.length - editStart;
  final sharedSuffixLimit = oldSuffixLimit < newSuffixLimit
      ? oldSuffixLimit
      : newSuffixLimit;
  while (sharedSuffixLength < sharedSuffixLimit &&
      oldText.codeUnitAt(oldText.length - sharedSuffixLength - 1) ==
          newText.codeUnitAt(newText.length - sharedSuffixLength - 1)) {
    sharedSuffixLength += 1;
  }

  final oldEditEnd = oldText.length - sharedSuffixLength;
  final insertedLength = newText.length - editStart - sharedSuffixLength;
  final editDelta = insertedLength - (oldEditEnd - editStart);

  int transformStart(int position) {
    if (position < editStart) {
      return position;
    }
    if (position >= oldEditEnd) {
      return position + editDelta;
    }
    return editStart;
  }

  int transformEnd(int position) {
    if (position <= editStart) {
      return position;
    }
    if (position >= oldEditEnd) {
      return position + editDelta;
    }
    return editStart + insertedLength;
  }

  return [
    for (final fill in fills)
      if (!_noteTextFillMatchesTarget(fill, targetKey))
        fill
      else
        fill
            .copyWith(
              start: transformStart(fill.start),
              end: transformEnd(fill.end),
            )
            .clampToTextLength(newText.length),
  ].where((fill) => fill.isValid).toList(growable: false);
}

bool _noteTextFillMatchesTarget(NoteTextFill fill, String? targetKey) {
  return targetKey == null ||
      fill.targetKey == targetKey ||
      (targetKey == 'paragraph' && fill.targetKey == null);
}

/// Replaces or clears a selected fill interval without deleting formatting
/// outside the selection.
List<NoteTextFill> replaceNoteTextFillRange(
  List<NoteTextFill> fills, {
  required int start,
  required int end,
  required String? targetKey,
  required int? colorValue,
  required String Function() idFactory,
}) {
  if (start < 0 || end <= start) {
    return List.unmodifiable(fills);
  }
  final result = <NoteTextFill>[];
  for (final fill in fills) {
    if (!_noteTextFillMatchesTarget(fill, targetKey) ||
        fill.end <= start ||
        fill.start >= end) {
      result.add(fill);
      continue;
    }
    if (fill.start < start) {
      result.add(fill.copyWith(id: idFactory(), end: start));
    }
    if (fill.end > end) {
      result.add(fill.copyWith(id: idFactory(), start: end));
    }
  }
  if (colorValue != null && colorValue != 0) {
    result.add(
      NoteTextFill(
        id: idFactory(),
        start: start,
        end: end,
        colorValue: colorValue,
        targetKey: targetKey,
      ),
    );
  }
  result.removeWhere((fill) => !fill.isValid);
  result.sort((left, right) {
    final target = (left.targetKey ?? '').compareTo(right.targetKey ?? '');
    if (target != 0) {
      return target;
    }
    final position = left.start.compareTo(right.start);
    return position != 0 ? position : left.end.compareTo(right.end);
  });
  return List.unmodifiable(result);
}

List<NoteTextRangeTag> transformNoteTextRangeTagsForEdit(
  List<NoteTextRangeTag> ranges, {
  required String oldText,
  required String newText,
}) {
  return [
    for (final range in ranges)
      if (_transformNoteTextRangeForEdit(
            start: range.start,
            end: range.end,
            oldText: oldText,
            newText: newText,
          )
          case final transformed?)
        range.copyWith(start: transformed.start, end: transformed.end),
  ].where((range) => range.isValid).toList(growable: false);
}

List<NoteTextParagraphStyle> transformNoteTextParagraphStylesForEdit(
  List<NoteTextParagraphStyle> styles, {
  required String oldText,
  required String newText,
}) {
  return [
    for (final style in styles)
      if (_transformNoteTextRangeForEdit(
            start: style.start,
            end: style.end,
            oldText: oldText,
            newText: newText,
          )
          case final transformed?)
        style.copyWith(start: transformed.start, end: transformed.end),
  ].where((style) => style.isValid).toList(growable: false);
}

List<NoteTextRangeTag> replaceNoteTextRangeTags(
  List<NoteTextRangeTag> ranges, {
  required int start,
  required int end,
  required List<NoteKnowledgeTag> tags,
  required String Function() idFactory,
}) {
  return _replaceNoteTextRangeTagsWithLineage(
    ranges,
    start: start,
    end: end,
    tags: tags,
    idFactory: idFactory,
  ).rangeTags;
}

({List<NoteTextRangeTag> rangeTags, List<NoteScopedTagAssignment> scopedTags})
replaceNoteTextRangeTagsAndRemapScopedTags(
  List<NoteTextRangeTag> ranges, {
  required List<NoteScopedTagAssignment> scopedTags,
  required int start,
  required int end,
  required List<NoteKnowledgeTag> tags,
  required String Function() rangeIdFactory,
  required String Function() scopedTagIdFactory,
}) {
  final replacement = _replaceNoteTextRangeTagsWithLineage(
    ranges,
    start: start,
    end: end,
    tags: tags,
    idFactory: rangeIdFactory,
  );
  if (!replacement.didReplace) {
    return (
      rangeTags: replacement.rangeTags,
      scopedTags: List.unmodifiable(scopedTags),
    );
  }
  final remappedScopedTags = <NoteScopedTagAssignment>[];
  for (final assignment in scopedTags) {
    if (assignment.target.kind != NoteTagTargetKind.textRange) {
      remappedScopedTags.add(assignment);
      continue;
    }
    final oldRangeId = assignment.target.rangeId;
    final targetRangeIds = oldRangeId == null
        ? null
        : replacement.preservedRangeIdsByOriginalId[oldRangeId];
    if (targetRangeIds == null || targetRangeIds.isEmpty) {
      continue;
    }
    for (var index = 0; index < targetRangeIds.length; index += 1) {
      remappedScopedTags.add(
        assignment.copyWith(
          id: index == 0 ? assignment.id : scopedTagIdFactory(),
          target: assignment.target.copyWith(rangeId: targetRangeIds[index]),
        ),
      );
    }
  }
  return (
    rangeTags: replacement.rangeTags,
    scopedTags: List.unmodifiable(remappedScopedTags),
  );
}

({
  List<NoteTextRangeTag> rangeTags,
  Map<String, List<String>> preservedRangeIdsByOriginalId,
  bool didReplace,
})
_replaceNoteTextRangeTagsWithLineage(
  List<NoteTextRangeTag> ranges, {
  required int start,
  required int end,
  required List<NoteKnowledgeTag> tags,
  required String Function() idFactory,
}) {
  if (start < 0 || end <= start) {
    return (
      rangeTags: List.unmodifiable(ranges),
      preservedRangeIdsByOriginalId: const <String, List<String>>{},
      didReplace: false,
    );
  }
  final result = <NoteTextRangeTag>[];
  final preservedRangeIdsByOriginalId = <String, List<String>>{};
  for (final range in ranges) {
    if (range.end <= start || range.start >= end) {
      result.add(range);
      preservedRangeIdsByOriginalId[range.id] = [range.id];
      continue;
    }
    final preservedIds = <String>[];
    if (range.start < start) {
      final left = range.copyWith(id: idFactory(), end: start);
      result.add(left);
      preservedIds.add(left.id);
    }
    if (range.end > end) {
      final right = range.copyWith(id: idFactory(), start: end);
      result.add(right);
      preservedIds.add(right.id);
    }
    preservedRangeIdsByOriginalId[range.id] = List.unmodifiable(preservedIds);
  }
  if (tags.isNotEmpty) {
    result.add(
      NoteTextRangeTag(
        id: idFactory(),
        start: start,
        end: end,
        tag: tags.first,
        tags: tags,
      ),
    );
  }
  result.removeWhere((range) => !range.isValid);
  result.sort((left, right) {
    final position = left.start.compareTo(right.start);
    return position != 0 ? position : left.end.compareTo(right.end);
  });
  final validRangeIds = result.map((range) => range.id).toSet();
  final validPreservedRangeIdsByOriginalId = {
    for (final entry in preservedRangeIdsByOriginalId.entries)
      entry.key: List<String>.unmodifiable(
        entry.value.where(validRangeIds.contains),
      ),
  };
  return (
    rangeTags: List.unmodifiable(result),
    preservedRangeIdsByOriginalId: Map.unmodifiable(
      validPreservedRangeIdsByOriginalId,
    ),
    didReplace: true,
  );
}

({int start, int end})? _transformNoteTextRangeForEdit({
  required int start,
  required int end,
  required String oldText,
  required String newText,
}) {
  if (start < 0 || end <= start) {
    return null;
  }
  if (oldText == newText) {
    final clampedStart = start.clamp(0, newText.length).toInt();
    final clampedEnd = end.clamp(clampedStart, newText.length).toInt();
    return clampedEnd > clampedStart
        ? (start: clampedStart, end: clampedEnd)
        : null;
  }
  var editStart = 0;
  final sharedPrefixLimit = oldText.length < newText.length
      ? oldText.length
      : newText.length;
  while (editStart < sharedPrefixLimit &&
      oldText.codeUnitAt(editStart) == newText.codeUnitAt(editStart)) {
    editStart += 1;
  }
  var sharedSuffixLength = 0;
  final sharedSuffixLimit =
      (oldText.length - editStart) < (newText.length - editStart)
      ? oldText.length - editStart
      : newText.length - editStart;
  while (sharedSuffixLength < sharedSuffixLimit &&
      oldText.codeUnitAt(oldText.length - sharedSuffixLength - 1) ==
          newText.codeUnitAt(newText.length - sharedSuffixLength - 1)) {
    sharedSuffixLength += 1;
  }
  final oldEditEnd = oldText.length - sharedSuffixLength;
  final insertedLength = newText.length - editStart - sharedSuffixLength;
  final editDelta = insertedLength - (oldEditEnd - editStart);
  final transformedStart = start < editStart
      ? start
      : start >= oldEditEnd
      ? start + editDelta
      : editStart;
  final transformedEnd = end <= editStart
      ? end
      : end >= oldEditEnd
      ? end + editDelta
      : editStart + insertedLength;
  final clampedStart = transformedStart.clamp(0, newText.length).toInt();
  final clampedEnd = transformedEnd.clamp(clampedStart, newText.length).toInt();
  return clampedEnd > clampedStart
      ? (start: clampedStart, end: clampedEnd)
      : null;
}

class NoteTextParagraphStyle {
  const NoteTextParagraphStyle({
    required this.id,
    required this.start,
    required this.end,
    this.level = 0,
  });

  final String id;
  final int start;
  final int end;
  final int level;

  bool get isValid => id.trim().isNotEmpty && start >= 0 && end > start;

  factory NoteTextParagraphStyle.fromJson(Object? value) {
    if (value is! Map) {
      return const NoteTextParagraphStyle(id: '', start: 0, end: 0);
    }
    final normalized = Map<Object?, Object?>.from(value);
    final rawLevel = normalized['level'];
    return NoteTextParagraphStyle(
      id: normalized['id']?.toString() ?? '',
      start: normalized['start'] is int ? normalized['start'] as int : 0,
      end: normalized['end'] is int ? normalized['end'] as int : 0,
      level: (rawLevel is int ? rawLevel : 0).clamp(0, 8).toInt(),
    );
  }

  NoteTextParagraphStyle clampToTextLength(int length) {
    final normalizedLength = length < 0 ? 0 : length;
    final clampedStart = start.clamp(0, normalizedLength).toInt();
    final clampedEnd = end.clamp(clampedStart, normalizedLength).toInt();
    return copyWith(start: clampedStart, end: clampedEnd);
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'start': start,
      'end': end,
      if (level != 0) 'level': level.clamp(0, 8).toInt(),
    };
  }

  NoteTextParagraphStyle copyWith({
    String? id,
    int? start,
    int? end,
    int? level,
  }) {
    return NoteTextParagraphStyle(
      id: id ?? this.id,
      start: start ?? this.start,
      end: end ?? this.end,
      level: (level ?? this.level).clamp(0, 8).toInt(),
    );
  }
}

enum NoteTagTargetKind {
  textRange('text_range'),
  listItem('list_item'),
  tableRow('table_row'),
  tableColumn('table_column'),
  tableCell('table_cell'),
  flowchartNode('flowchart_node'),
  flowchartEdge('flowchart_edge');

  const NoteTagTargetKind(this.wireName);

  final String wireName;

  static NoteTagTargetKind fromWireName(String? value) {
    for (final kind in values) {
      if (kind.wireName == value) {
        return kind;
      }
    }
    return NoteTagTargetKind.textRange;
  }
}

class NoteTagTarget {
  const NoteTagTarget({
    required this.kind,
    this.rangeId,
    this.listItemId,
    this.rowIndex,
    this.columnIndex,
    this.elementId,
  });

  final NoteTagTargetKind kind;
  final String? rangeId;
  final String? listItemId;
  final int? rowIndex;
  final int? columnIndex;
  final String? elementId;

  factory NoteTagTarget.fromJson(Object? value) {
    if (value is! Map) {
      return const NoteTagTarget(kind: NoteTagTargetKind.textRange);
    }
    return NoteTagTarget(
      kind: NoteTagTargetKind.fromWireName(value['kind']?.toString()),
      rangeId: value['rangeId']?.toString(),
      listItemId: value['listItemId']?.toString(),
      rowIndex: value['rowIndex'] is int ? value['rowIndex'] as int : null,
      columnIndex: value['columnIndex'] is int
          ? value['columnIndex'] as int
          : null,
      elementId: value['elementId']?.toString(),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'kind': kind.wireName,
      if (rangeId != null) 'rangeId': rangeId,
      if (listItemId != null) 'listItemId': listItemId,
      if (rowIndex != null) 'rowIndex': rowIndex,
      if (columnIndex != null) 'columnIndex': columnIndex,
      if (elementId != null) 'elementId': elementId,
    };
  }

  NoteTagTarget copyWith({
    NoteTagTargetKind? kind,
    String? rangeId,
    String? listItemId,
    int? rowIndex,
    int? columnIndex,
    String? elementId,
    bool clearRangeId = false,
    bool clearListItemId = false,
    bool clearRowIndex = false,
    bool clearColumnIndex = false,
    bool clearElementId = false,
  }) {
    return NoteTagTarget(
      kind: kind ?? this.kind,
      rangeId: clearRangeId ? null : rangeId ?? this.rangeId,
      listItemId: clearListItemId ? null : listItemId ?? this.listItemId,
      rowIndex: clearRowIndex ? null : rowIndex ?? this.rowIndex,
      columnIndex: clearColumnIndex ? null : columnIndex ?? this.columnIndex,
      elementId: clearElementId ? null : elementId ?? this.elementId,
    );
  }
}

class NoteScopedTagAssignment {
  const NoteScopedTagAssignment({
    required this.id,
    required this.target,
    required this.tags,
  });

  final String id;
  final NoteTagTarget target;
  final List<NoteKnowledgeTag> tags;

  factory NoteScopedTagAssignment.fromJson(Map<String, Object?> json) {
    return NoteScopedTagAssignment(
      id: json['id']?.toString() ?? 'tag-assignment-1',
      target: NoteTagTarget.fromJson(json['target']),
      tags: _tagsFromJson(json['tags']),
    );
  }

  bool get isValid => tags.any((tag) => tag.label.trim().isNotEmpty);

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'target': target.toJson(),
      'tags': tags.map((tag) => tag.toJson()).toList(),
    };
  }

  NoteScopedTagAssignment copyWith({
    String? id,
    NoteTagTarget? target,
    List<NoteKnowledgeTag>? tags,
  }) {
    return NoteScopedTagAssignment(
      id: id ?? this.id,
      target: target ?? this.target,
      tags: tags ?? this.tags,
    );
  }
}

const List<int> noteTagColorSlots = [
  0xFF2563EB,
  0xFF059669,
  0xFF7C3AED,
  0xFFEA580C,
  0xFFDC2626,
  0xFF0D9488,
  0xFFDB2777,
  0xFF475569,
];

int _stableTagColorValue(String seed) {
  var hash = 0;
  for (final codeUnit in seed.codeUnits) {
    hash = (hash * 31 + codeUnit) & 0x7fffffff;
  }
  if (hash == 0) {
    return noteTagColorSlots.first;
  }
  return noteTagColorSlots[hash % noteTagColorSlots.length];
}

int? _tagColorFromJson(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  final raw = value?.toString().trim();
  if (raw == null || raw.isEmpty) {
    return null;
  }
  final normalized = raw
      .replaceFirst('#', '')
      .replaceFirst('0x', '')
      .replaceFirst('0X', '');
  final argb = normalized.length == 6 ? 'FF$normalized' : normalized;
  return int.tryParse(argb, radix: 16);
}

int? _tagIntFromJson(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString().trim() ?? '');
}

List<NoteKnowledgeTag> _tagsFromJson(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value
      .map(NoteKnowledgeTag.fromJson)
      .where((tag) => tag.label.trim().isNotEmpty)
      .toList(growable: false);
}

String _metadataTextFromTags(List<NoteKnowledgeTag> tags) {
  return tags
      .map((tag) => tag.metadataText)
      .where((value) => value.isNotEmpty)
      .join('\n')
      .trim();
}

List<NoteTextRangeTag> _rangeTagsFromJson(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value
      .whereType<Map>()
      .map((item) => NoteTextRangeTag.fromJson(Map<String, Object?>.from(item)))
      .where((tag) => tag.isValid)
      .toList(growable: false);
}

List<NoteTextParagraphStyle> _paragraphStylesFromJson(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value
      .map(NoteTextParagraphStyle.fromJson)
      .where((style) => style.isValid)
      .toList(growable: false);
}

List<NoteTextFill> _textFillsFromJson(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value
      .map(NoteTextFill.fromJson)
      .where((fill) => fill.isValid)
      .toList(growable: false);
}

List<NoteScopedTagAssignment> _scopedTagsFromJson(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value
      .whereType<Map>()
      .map(
        (item) =>
            NoteScopedTagAssignment.fromJson(Map<String, Object?>.from(item)),
      )
      .where((assignment) => assignment.isValid)
      .toList(growable: false);
}

String stableNoteContentHash(String value) {
  const offset = 0x811c9dc5;
  const prime = 0x01000193;
  var hash = offset;
  for (final byte in utf8.encode(value.trim())) {
    hash ^= byte;
    hash = (hash * prime) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

class NoteDocument {
  const NoteDocument({
    required this.blocks,
    this.schemaVersion = 1,
    this.tags = const [],
  });

  final int schemaVersion;
  final List<NoteKnowledgeTag> tags;
  final List<NoteBlock> blocks;

  factory NoteDocument.empty() {
    return const NoteDocument(
      blocks: [
        NoteBlock(id: 'block-1', type: NoteBlockType.paragraph, text: ''),
      ],
    );
  }

  factory NoteDocument.fromPayload(
    String payloadJson, {
    String? legacyType,
    String? legacyText,
    String? title,
  }) {
    try {
      final decoded = jsonDecode(payloadJson) as Object?;
      if (decoded is Map<String, Object?>) {
        final type = decoded['type'];
        final blocks = decoded['blocks'];
        if (type == 'document' && blocks is List) {
          final parsedBlocks = blocks
              .whereType<Map>()
              .map(
                (item) => NoteBlock.fromJson(Map<String, Object?>.from(item)),
              )
              .toList(growable: false);
          return NoteDocument(
            schemaVersion: decoded['schemaVersion'] is int
                ? decoded['schemaVersion'] as int
                : 1,
            tags: _tagsFromJson(decoded['tags']),
            blocks: parsedBlocks.isEmpty
                ? NoteDocument.empty().blocks
                : parsedBlocks,
          );
        }
        return NoteDocument.fromLegacy(
          legacyType: legacyType ?? type?.toString(),
          legacyText: legacyText,
          legacyPayload: decoded,
          title: title,
        );
      }
    } catch (_) {
      // Legacy plain text payloads intentionally fall through.
    }
    return NoteDocument.fromLegacy(
      legacyType: legacyType,
      legacyText: legacyText ?? payloadJson,
      title: title,
    );
  }

  factory NoteDocument.fromLegacy({
    String? legacyType,
    String? legacyText,
    Map<String, Object?>? legacyPayload,
    String? title,
  }) {
    final normalized = legacyType?.trim().toLowerCase();
    if (normalized == 'table') {
      final rows = _rowsFromLegacyPayload(legacyPayload);
      if (rows.isNotEmpty) {
        return NoteDocument(
          blocks: [
            NoteBlock(
              id: 'block-1',
              type: NoteBlockType.table,
              title: title,
              rows: rows,
            ),
          ],
        );
      }
    }
    if (normalized == 'flowchart') {
      final text = _legacyText(legacyText, legacyPayload);
      return NoteDocument(
        blocks: [
          NoteBlock(
            id: 'block-1',
            type: NoteBlockType.flowchart,
            title: title,
            text: text,
          ),
        ],
      );
    }
    final text = _legacyText(legacyText, legacyPayload);
    return NoteDocument(
      blocks: [
        NoteBlock(id: 'block-1', type: NoteBlockType.paragraph, text: text),
      ],
    );
  }

  String toPayloadJson() {
    return jsonEncode({
      'schemaVersion': schemaVersion,
      'type': 'document',
      if (tags.isNotEmpty) 'tags': tags.map((tag) => tag.toJson()).toList(),
      'blocks': blocks.map((block) => block.toJson()).toList(),
    });
  }

  String get searchMetadataText {
    return _metadataTextFromTags(tags);
  }

  List<NoteKnowledgeTag> get knownTags {
    final tagsByMetadata = <String, NoteKnowledgeTag>{};

    void remember(NoteKnowledgeTag tag) {
      final key = tag.metadataText.trim();
      if (key.isEmpty) {
        return;
      }
      tagsByMetadata[key] = tag;
    }

    for (final tag in tags) {
      remember(tag);
    }
    for (final block in blocks) {
      for (final tag in block.knownTags) {
        remember(tag);
      }
    }

    final values = tagsByMetadata.values.toList(growable: false);
    values.sort((a, b) => a.metadataText.compareTo(b.metadataText));
    return values;
  }

  String get plainText {
    return blocks
        .map((block) => block.plainText)
        .where((text) => text.trim().isNotEmpty)
        .join('\n\n')
        .trim();
  }

  String get preview {
    final value = plainText.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (value.length <= 180) {
      return value;
    }
    return '${value.substring(0, 177)}...';
  }

  NoteDocument copyWith({
    List<NoteBlock>? blocks,
    List<NoteKnowledgeTag>? tags,
  }) {
    return NoteDocument(
      schemaVersion: schemaVersion,
      tags: tags ?? this.tags,
      blocks: blocks ?? this.blocks,
    );
  }

  static String _legacyText(
    String? legacyText,
    Map<String, Object?>? legacyPayload,
  ) {
    final direct = legacyText?.trim();
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }
    final text = legacyPayload?['text']?.toString().trim();
    if (text != null && text.isNotEmpty) {
      return text;
    }
    final lines = legacyPayload?['lines'];
    if (lines is List) {
      return lines.map((line) => line.toString()).join('\n').trim();
    }
    return '';
  }

  static List<List<String>> _rowsFromLegacyPayload(
    Map<String, Object?>? legacyPayload,
  ) {
    final rows = legacyPayload?['rows'];
    if (rows is! List) {
      return const [];
    }
    return rows
        .whereType<List>()
        .map(
          (row) =>
              row.map((cell) => cell.toString().trim()).toList(growable: false),
        )
        .where((row) => row.any((cell) => cell.isNotEmpty))
        .toList(growable: false);
  }
}

enum NoteListLayoutMode {
  checkbox('checkbox'),
  hierarchy('hierarchy');

  const NoteListLayoutMode(this.wireName);

  final String wireName;

  static NoteListLayoutMode fromWireName(String? value) {
    return switch (value) {
      'hierarchy' => NoteListLayoutMode.hierarchy,
      _ => NoteListLayoutMode.checkbox,
    };
  }
}

class NoteListItem {
  const NoteListItem({
    required this.id,
    required this.text,
    this.level = 0,
    this.checked = false,
    this.tags = const [],
  });

  final String id;
  final String text;
  final int level;
  final bool checked;
  final List<NoteKnowledgeTag> tags;

  factory NoteListItem.fromJson(Map<String, Object?> json) {
    return NoteListItem(
      id: json['id']?.toString() ?? 'item-1',
      text: json['text']?.toString() ?? '',
      level: json['level'] is int ? json['level'] as int : 0,
      checked: json['checked'] == true,
      tags: _tagsFromJson(json['tags']),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'text': text,
      if (level != 0) 'level': level,
      if (checked) 'checked': true,
      if (tags.isNotEmpty) 'tags': tags.map((tag) => tag.toJson()).toList(),
    };
  }

  String get searchMetadataText {
    return _metadataTextFromTags(tags);
  }

  NoteListItem copyWith({
    String? id,
    String? text,
    int? level,
    bool? checked,
    List<NoteKnowledgeTag>? tags,
  }) {
    return NoteListItem(
      id: id ?? this.id,
      text: text ?? this.text,
      level: level ?? this.level,
      checked: checked ?? this.checked,
      tags: tags ?? this.tags,
    );
  }
}

String _noteIndent(int level) =>
    List.filled(level.clamp(0, 8).toInt(), '  ').join();

enum NoteMixedSectionType {
  paragraph('paragraph'),
  list('list'),
  table('table');

  const NoteMixedSectionType(this.wireName);

  final String wireName;

  static NoteMixedSectionType fromWireName(String? value) {
    return switch (value) {
      'list' => NoteMixedSectionType.list,
      'table' => NoteMixedSectionType.table,
      _ => NoteMixedSectionType.paragraph,
    };
  }
}

enum NoteMixedParagraphRole {
  paragraph('paragraph'),
  heading('heading');

  const NoteMixedParagraphRole(this.wireName);

  final String wireName;

  static NoteMixedParagraphRole fromWireName(String? value) {
    return switch (value) {
      'heading' => NoteMixedParagraphRole.heading,
      _ => NoteMixedParagraphRole.paragraph,
    };
  }
}

class NoteMixedSection {
  const NoteMixedSection({
    required this.id,
    required this.type,
    this.title,
    this.text = '',
    this.paragraphRole = NoteMixedParagraphRole.paragraph,
    this.headingLevel = 1,
    this.paragraphIndentLevel = 0,
    this.textColorValue,
    this.underlineColorValue,
    this.backgroundColorValue,
    this.rangeTags = const [],
    this.textFills = const [],
    this.paragraphStyles = const [],
    this.listItems = const [],
    this.listLayoutMode = NoteListLayoutMode.checkbox,
    this.rows = const [],
    this.tableColumnWidths = const [],
    this.tableRowHeights = const [],
    this.scopedTags = const [],
  });

  final String id;
  final NoteMixedSectionType type;
  final String? title;
  final String text;
  final NoteMixedParagraphRole paragraphRole;
  final int headingLevel;
  final int paragraphIndentLevel;
  final int? textColorValue;
  final int? underlineColorValue;
  final int? backgroundColorValue;
  final List<NoteTextRangeTag> rangeTags;
  final List<NoteTextFill> textFills;
  final List<NoteTextParagraphStyle> paragraphStyles;
  final List<NoteListItem> listItems;
  final NoteListLayoutMode listLayoutMode;
  final List<List<String>> rows;
  final List<double> tableColumnWidths;
  final List<double> tableRowHeights;
  final List<NoteScopedTagAssignment> scopedTags;

  factory NoteMixedSection.fromJson(Map<String, Object?> json) {
    return NoteMixedSection(
      id: json['id']?.toString() ?? 'section-1',
      type: NoteMixedSectionType.fromWireName(json['type']?.toString()),
      title: json['title']?.toString(),
      text: json['text']?.toString() ?? '',
      paragraphRole: NoteMixedParagraphRole.fromWireName(
        json['paragraphRole']?.toString(),
      ),
      headingLevel: (_tagIntFromJson(json['headingLevel']) ?? 1)
          .clamp(1, 3)
          .toInt(),
      paragraphIndentLevel: (_tagIntFromJson(json['paragraphIndentLevel']) ?? 0)
          .clamp(0, 8)
          .toInt(),
      textColorValue: _tagColorFromJson(json['textColorValue']),
      underlineColorValue: _tagColorFromJson(json['underlineColorValue']),
      backgroundColorValue: _tagColorFromJson(json['backgroundColorValue']),
      rangeTags: _rangeTagsFromJson(json['rangeTags']),
      textFills: _textFillsFromJson(json['textFills']),
      paragraphStyles: _paragraphStylesFromJson(json['paragraphStyles']),
      listItems: NoteBlock._listItemsFromJson(json['listItems']),
      listLayoutMode: NoteListLayoutMode.fromWireName(
        json['listLayoutMode']?.toString(),
      ),
      rows: NoteBlock._rowsFromJson(json['rows']),
      tableColumnWidths: NoteBlock._doublesFromJson(json['tableColumnWidths']),
      tableRowHeights: NoteBlock._doublesFromJson(json['tableRowHeights']),
      scopedTags: _scopedTagsFromJson(json['scopedTags']),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'type': type.wireName,
      if (title != null && title!.trim().isNotEmpty) 'title': title,
      if (text.isNotEmpty) 'text': text,
      if (paragraphRole != NoteMixedParagraphRole.paragraph)
        'paragraphRole': paragraphRole.wireName,
      if (headingLevel != 1) 'headingLevel': headingLevel.clamp(1, 3).toInt(),
      if (paragraphIndentLevel != 0)
        'paragraphIndentLevel': paragraphIndentLevel.clamp(0, 8).toInt(),
      if (textColorValue != null) 'textColorValue': textColorValue,
      if (underlineColorValue != null)
        'underlineColorValue': underlineColorValue,
      if (backgroundColorValue != null)
        'backgroundColorValue': backgroundColorValue,
      if (rangeTags.isNotEmpty)
        'rangeTags': rangeTags.map((tag) => tag.toJson()).toList(),
      if (textFills.isNotEmpty)
        'textFills': textFills.map((fill) => fill.toJson()).toList(),
      if (paragraphStyles.isNotEmpty)
        'paragraphStyles': paragraphStyles
            .map((style) => style.toJson())
            .toList(),
      if (listItems.isNotEmpty)
        'listItems': listItems.map((item) => item.toJson()).toList(),
      if (listLayoutMode != NoteListLayoutMode.checkbox)
        'listLayoutMode': listLayoutMode.wireName,
      if (rows.isNotEmpty) 'rows': rows,
      if (tableColumnWidths.isNotEmpty) 'tableColumnWidths': tableColumnWidths,
      if (tableRowHeights.isNotEmpty) 'tableRowHeights': tableRowHeights,
      if (scopedTags.isNotEmpty)
        'scopedTags': scopedTags
            .map((assignment) => assignment.toJson())
            .toList(),
    };
  }

  String get plainText {
    final lines = <String>[];
    if (title?.trim().isNotEmpty == true) {
      lines.add(title!.trim());
    }
    switch (type) {
      case NoteMixedSectionType.paragraph:
        if (text.trim().isNotEmpty) {
          lines.add(text.trim());
        }
        break;
      case NoteMixedSectionType.list:
        if (listItems.isEmpty) {
          if (text.trim().isNotEmpty) {
            lines.add(text.trim());
          }
        } else {
          lines.addAll(
            listItems
                .map((item) => '${_noteIndent(item.level)}${item.text.trim()}')
                .where((line) => line.trim().isNotEmpty),
          );
        }
        break;
      case NoteMixedSectionType.table:
        for (final row in rows) {
          final line = row
              .map((cell) => cell.trim())
              .where((cell) => cell.isNotEmpty)
              .join(' | ');
          if (line.isNotEmpty) {
            lines.add(line);
          }
        }
        break;
    }
    return lines.join('\n').trim();
  }

  List<NoteKnowledgeTag> get knownTags {
    final tagsByMetadata = <String, NoteKnowledgeTag>{};

    void remember(NoteKnowledgeTag tag) {
      final key = tag.metadataText.trim();
      if (key.isNotEmpty) {
        tagsByMetadata[key] = tag;
      }
    }

    for (final rangeTag in rangeTags) {
      for (final tag in rangeTag.resolvedTags) {
        remember(tag);
      }
    }
    for (final assignment in scopedTags) {
      for (final tag in assignment.tags) {
        remember(tag);
      }
    }
    for (final item in listItems) {
      for (final tag in item.tags) {
        remember(tag);
      }
    }

    final values = tagsByMetadata.values.toList(growable: false);
    values.sort((a, b) => a.metadataText.compareTo(b.metadataText));
    return values;
  }

  NoteMixedSection copyWith({
    String? id,
    NoteMixedSectionType? type,
    String? title,
    String? text,
    NoteMixedParagraphRole? paragraphRole,
    int? headingLevel,
    int? paragraphIndentLevel,
    int? textColorValue,
    int? underlineColorValue,
    int? backgroundColorValue,
    List<NoteTextRangeTag>? rangeTags,
    List<NoteTextFill>? textFills,
    List<NoteTextParagraphStyle>? paragraphStyles,
    List<NoteListItem>? listItems,
    NoteListLayoutMode? listLayoutMode,
    List<List<String>>? rows,
    List<double>? tableColumnWidths,
    List<double>? tableRowHeights,
    List<NoteScopedTagAssignment>? scopedTags,
  }) {
    return NoteMixedSection(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      text: text ?? this.text,
      paragraphRole: paragraphRole ?? this.paragraphRole,
      headingLevel: (headingLevel ?? this.headingLevel).clamp(1, 3).toInt(),
      paragraphIndentLevel: (paragraphIndentLevel ?? this.paragraphIndentLevel)
          .clamp(0, 8)
          .toInt(),
      textColorValue: textColorValue ?? this.textColorValue,
      underlineColorValue: underlineColorValue ?? this.underlineColorValue,
      backgroundColorValue: backgroundColorValue ?? this.backgroundColorValue,
      rangeTags: rangeTags ?? this.rangeTags,
      textFills: textFills ?? this.textFills,
      paragraphStyles: paragraphStyles ?? this.paragraphStyles,
      listItems: listItems ?? this.listItems,
      listLayoutMode: listLayoutMode ?? this.listLayoutMode,
      rows: rows ?? this.rows,
      tableColumnWidths: tableColumnWidths ?? this.tableColumnWidths,
      tableRowHeights: tableRowHeights ?? this.tableRowHeights,
      scopedTags: scopedTags ?? this.scopedTags,
    );
  }
}

class NoteBlock {
  const NoteBlock({
    required this.id,
    required this.type,
    this.text = '',
    this.title,
    this.searchContext,
    this.searchRole = NoteSearchRoles.none,
    this.searchAliases = const [],
    this.tags = const [],
    this.rangeTags = const [],
    this.textFills = const [],
    this.paragraphStyles = const [],
    this.scopedTags = const [],
    this.level = 0,
    this.rows = const [],
    this.tableColumnWidths = const [],
    this.tableRowHeights = const [],
    this.nodes = const [],
    this.edges = const [],
    this.listItems = const [],
    this.listLayoutMode = NoteListLayoutMode.checkbox,
    this.mixedSections = const [],
    this.indexedContentHash,
    this.indexedAt,
  });

  final String id;
  final NoteBlockType type;
  final String text;
  final String? title;
  final String? searchContext;
  final String searchRole;
  final List<String> searchAliases;
  final List<NoteKnowledgeTag> tags;
  final List<NoteTextRangeTag> rangeTags;
  final List<NoteTextFill> textFills;
  final List<NoteTextParagraphStyle> paragraphStyles;
  final List<NoteScopedTagAssignment> scopedTags;
  final int level;
  final List<List<String>> rows;
  final List<double> tableColumnWidths;
  final List<double> tableRowHeights;
  final List<NoteFlowchartNode> nodes;
  final List<NoteFlowchartEdge> edges;
  final List<NoteListItem> listItems;
  final NoteListLayoutMode listLayoutMode;
  final List<NoteMixedSection> mixedSections;
  final String? indexedContentHash;
  final DateTime? indexedAt;

  factory NoteBlock.fromJson(Map<String, Object?> json) {
    return NoteBlock(
      id: json['id']?.toString() ?? 'block-1',
      type: NoteBlockType.fromWireName(json['type']?.toString()),
      text: json['text']?.toString() ?? '',
      title: json['title']?.toString(),
      searchContext: json['searchContext']?.toString(),
      searchRole: NoteSearchRoles.normalize(json['searchRole']?.toString()),
      searchAliases: _stringsFromJson(json['searchAliases']),
      tags: _tagsFromJson(json['tags']),
      rangeTags: _rangeTagsFromJson(json['rangeTags']),
      textFills: _textFillsFromJson(json['textFills']),
      paragraphStyles: _paragraphStylesFromJson(json['paragraphStyles']),
      scopedTags: _scopedTagsFromJson(json['scopedTags']),
      level: json['level'] is int ? json['level'] as int : 0,
      rows: _rowsFromJson(json['rows']),
      tableColumnWidths: _doublesFromJson(json['tableColumnWidths']),
      tableRowHeights: _doublesFromJson(json['tableRowHeights']),
      nodes: _nodesFromJson(json['nodes']),
      edges: _edgesFromJson(json['edges']),
      listItems: _listItemsFromJson(json['listItems']),
      listLayoutMode: NoteListLayoutMode.fromWireName(
        json['listLayoutMode']?.toString(),
      ),
      mixedSections: _mixedSectionsFromJson(json['mixedSections']),
      indexedContentHash: json['indexedContentHash']?.toString(),
      indexedAt: DateTime.tryParse(json['indexedAt']?.toString() ?? ''),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'type': type.wireName,
      if (text.isNotEmpty) 'text': text,
      if (title != null && title!.trim().isNotEmpty) 'title': title,
      if (searchContext != null && searchContext!.trim().isNotEmpty)
        'searchContext': searchContext,
      if (NoteSearchRoles.normalize(searchRole) != NoteSearchRoles.none)
        'searchRole': NoteSearchRoles.normalize(searchRole),
      if (searchAliases.where((alias) => alias.trim().isNotEmpty).isNotEmpty)
        'searchAliases': searchAliases
            .map((alias) => alias.trim())
            .where((alias) => alias.isNotEmpty)
            .toList(growable: false),
      if (tags.isNotEmpty) 'tags': tags.map((tag) => tag.toJson()).toList(),
      if (rangeTags.isNotEmpty)
        'rangeTags': rangeTags.map((tag) => tag.toJson()).toList(),
      if (textFills.isNotEmpty)
        'textFills': textFills.map((fill) => fill.toJson()).toList(),
      if (paragraphStyles.isNotEmpty)
        'paragraphStyles': paragraphStyles
            .map((style) => style.toJson())
            .toList(),
      if (scopedTags.isNotEmpty)
        'scopedTags': scopedTags
            .map((assignment) => assignment.toJson())
            .toList(),
      if (level != 0) 'level': level,
      if (rows.isNotEmpty) 'rows': rows,
      if (tableColumnWidths.isNotEmpty) 'tableColumnWidths': tableColumnWidths,
      if (tableRowHeights.isNotEmpty) 'tableRowHeights': tableRowHeights,
      if (nodes.isNotEmpty)
        'nodes': nodes.map((node) => node.toJson()).toList(),
      if (edges.isNotEmpty)
        'edges': edges.map((edge) => edge.toJson()).toList(),
      if (listItems.isNotEmpty)
        'listItems': listItems.map((item) => item.toJson()).toList(),
      if (listLayoutMode != NoteListLayoutMode.checkbox)
        'listLayoutMode': listLayoutMode.wireName,
      if (mixedSections.isNotEmpty)
        'mixedSections': mixedSections
            .map((section) => section.toJson())
            .toList(),
      if (indexedContentHash != null) 'indexedContentHash': indexedContentHash,
      if (indexedAt != null) 'indexedAt': indexedAt!.toIso8601String(),
    };
  }

  String get plainText {
    return switch (type) {
      NoteBlockType.table => _tableText,
      NoteBlockType.flowchart => _flowchartText,
      NoteBlockType.listItem => _listText,
      NoteBlockType.mixed => _mixedText,
      NoteBlockType.heading || NoteBlockType.paragraph => text.trim(),
    };
  }

  String get plainTextForIndexing {
    final base = switch (type) {
      NoteBlockType.listItem => _listText,
      _ => plainText,
    };
    final metadata = searchMetadataText;
    if (metadata.isEmpty) {
      return base;
    }
    return '$metadata\n$base'.trim();
  }

  String get displayTextForIndexing {
    return switch (type) {
      NoteBlockType.listItem => _listText,
      _ => plainText,
    };
  }

  String get searchMetadataText {
    final parts = <String>[];
    final context = searchContext?.trim();
    if (context != null && context.isNotEmpty) {
      parts.add(context);
    }
    final role = NoteSearchRoles.normalize(searchRole);
    if (role != NoteSearchRoles.none && role != NoteSearchRoles.ignore) {
      parts.add(role.replaceAll('_', ' '));
    }
    parts.addAll(
      searchAliases
          .map((alias) => alias.trim())
          .where((alias) => alias.isNotEmpty),
    );
    final tagMetadata = _metadataTextFromTags(tags);
    if (tagMetadata.isNotEmpty) {
      parts.add(tagMetadata);
    }
    return parts.join('\n').trim();
  }

  List<NoteKnowledgeTag> get knownTags {
    final tagsByMetadata = <String, NoteKnowledgeTag>{};

    void remember(NoteKnowledgeTag tag) {
      final key = tag.metadataText.trim();
      if (key.isNotEmpty) {
        tagsByMetadata[key] = tag;
      }
    }

    for (final tag in tags) {
      remember(tag);
    }
    for (final rangeTag in rangeTags) {
      for (final tag in rangeTag.resolvedTags) {
        remember(tag);
      }
    }
    for (final assignment in scopedTags) {
      for (final tag in assignment.tags) {
        remember(tag);
      }
    }
    for (final item in listItems) {
      for (final tag in item.tags) {
        remember(tag);
      }
    }
    for (final section in mixedSections) {
      for (final tag in section.knownTags) {
        remember(tag);
      }
    }

    final values = tagsByMetadata.values.toList(growable: false);
    values.sort((a, b) => a.metadataText.compareTo(b.metadataText));
    return values;
  }

  bool get hasContent => plainTextForIndexing.trim().isNotEmpty;

  String get contentHash => stableNoteContentHash(plainTextForIndexing);

  bool get isIndexFresh =>
      indexedContentHash != null && indexedContentHash == contentHash;

  bool get needsReindex =>
      hasContent && indexedContentHash != null && !isIndexFresh;

  String get _listText {
    final lines = <String>[];
    if (title?.trim().isNotEmpty == true) {
      lines.add(title!.trim());
    }
    if (listItems.isEmpty) {
      final trimmed = text.trim();
      if (trimmed.isNotEmpty) {
        lines.add('${_indent(level)}$trimmed');
      }
      return lines.join('\n').trimRight();
    }
    lines.addAll(
      listItems
          .map((item) => '${_indent(item.level)}${item.text.trim()}')
          .where((line) => line.trim().isNotEmpty),
    );
    return lines.join('\n').trimRight();
  }

  String _indent(int level) => _noteIndent(level);

  String get _tableText {
    final lines = <String>[];
    if (title?.trim().isNotEmpty == true) {
      lines.add(title!.trim());
    }
    for (final row in rows) {
      final line = row
          .map((cell) => cell.trim())
          .where((cell) => cell.isNotEmpty)
          .join(' | ');
      if (line.isNotEmpty) {
        lines.add(line);
      }
    }
    return lines.join('\n').trim();
  }

  String get _flowchartText {
    final lines = <String>[];
    if (title?.trim().isNotEmpty == true) {
      lines.add(title!.trim());
    }
    if (text.trim().isNotEmpty) {
      lines.add(text.trim());
    }
    for (final node in nodes) {
      lines.add(node.label);
    }
    final nodesById = {for (final node in nodes) node.id: node.label};
    for (final edge in edges) {
      final from = nodesById[edge.fromNodeId] ?? edge.fromNodeId;
      final to = nodesById[edge.toNodeId] ?? edge.toNodeId;
      final label = edge.label.trim();
      lines.add(label.isEmpty ? '$from -> $to' : '$from -> $to [$label]');
    }
    return lines.where((line) => line.trim().isNotEmpty).join('\n').trim();
  }

  String get _mixedText {
    final parts = <String>[];
    if (title?.trim().isNotEmpty == true) {
      parts.add(title!.trim());
    }
    parts.addAll(
      mixedSections
          .map((section) => section.plainText)
          .where((text) => text.trim().isNotEmpty),
    );
    if (parts.isEmpty && text.trim().isNotEmpty) {
      parts.add(text.trim());
    }
    return parts.join('\n\n').trim();
  }

  NoteBlock copyWith({
    String? id,
    NoteBlockType? type,
    String? text,
    String? title,
    String? searchContext,
    String? searchRole,
    List<String>? searchAliases,
    List<NoteKnowledgeTag>? tags,
    List<NoteTextRangeTag>? rangeTags,
    List<NoteTextFill>? textFills,
    List<NoteTextParagraphStyle>? paragraphStyles,
    List<NoteScopedTagAssignment>? scopedTags,
    int? level,
    List<List<String>>? rows,
    List<double>? tableColumnWidths,
    List<double>? tableRowHeights,
    List<NoteFlowchartNode>? nodes,
    List<NoteFlowchartEdge>? edges,
    List<NoteListItem>? listItems,
    NoteListLayoutMode? listLayoutMode,
    List<NoteMixedSection>? mixedSections,
    String? indexedContentHash,
    DateTime? indexedAt,
    bool clearIndex = false,
  }) {
    return NoteBlock(
      id: id ?? this.id,
      type: type ?? this.type,
      text: text ?? this.text,
      title: title ?? this.title,
      searchContext: searchContext ?? this.searchContext,
      searchRole: searchRole ?? this.searchRole,
      searchAliases: searchAliases ?? this.searchAliases,
      tags: tags ?? this.tags,
      rangeTags: rangeTags ?? this.rangeTags,
      textFills: textFills ?? this.textFills,
      paragraphStyles: paragraphStyles ?? this.paragraphStyles,
      scopedTags: scopedTags ?? this.scopedTags,
      level: level ?? this.level,
      rows: rows ?? this.rows,
      tableColumnWidths: tableColumnWidths ?? this.tableColumnWidths,
      tableRowHeights: tableRowHeights ?? this.tableRowHeights,
      nodes: nodes ?? this.nodes,
      edges: edges ?? this.edges,
      listItems: listItems ?? this.listItems,
      listLayoutMode: listLayoutMode ?? this.listLayoutMode,
      mixedSections: mixedSections ?? this.mixedSections,
      indexedContentHash: clearIndex
          ? null
          : indexedContentHash ?? this.indexedContentHash,
      indexedAt: clearIndex ? null : indexedAt ?? this.indexedAt,
    );
  }

  static List<List<String>> _rowsFromJson(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<List>()
        .map(
          (row) => row.map((cell) => cell.toString()).toList(growable: false),
        )
        .toList(growable: false);
  }

  static List<double> _doublesFromJson(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .map((item) {
          if (item is num) {
            return item.toDouble();
          }
          return double.tryParse(item.toString());
        })
        .whereType<double>()
        .where((item) => item.isFinite && item > 0)
        .toList(growable: false);
  }

  static List<NoteFlowchartNode> _nodesFromJson(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map>()
        .map(
          (item) => NoteFlowchartNode.fromJson(Map<String, Object?>.from(item)),
        )
        .toList(growable: false);
  }

  static List<NoteFlowchartEdge> _edgesFromJson(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map>()
        .map(
          (item) => NoteFlowchartEdge.fromJson(Map<String, Object?>.from(item)),
        )
        .toList(growable: false);
  }

  static List<NoteListItem> _listItemsFromJson(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map>()
        .map((item) => NoteListItem.fromJson(Map<String, Object?>.from(item)))
        .toList(growable: false);
  }

  static List<NoteMixedSection> _mixedSectionsFromJson(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map>()
        .map(
          (item) => NoteMixedSection.fromJson(Map<String, Object?>.from(item)),
        )
        .toList(growable: false);
  }

  static List<String> _stringsFromJson(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
}

enum NoteFlowchartNodeKind {
  universal('universal'),
  binaryDecision('binary_decision'),
  multiDecision('multi_decision');

  const NoteFlowchartNodeKind(this.wireName);

  final String wireName;

  static NoteFlowchartNodeKind? maybeFromWireName(String? value) {
    for (final item in values) {
      if (item.wireName == value) {
        return item;
      }
    }
    return null;
  }
}

enum NoteFlowchartNodeRole {
  normal('normal'),
  start('start'),
  end('end');

  const NoteFlowchartNodeRole(this.wireName);

  final String wireName;

  static NoteFlowchartNodeRole? maybeFromWireName(String? value) {
    for (final item in values) {
      if (item.wireName == value) {
        return item;
      }
    }
    return null;
  }
}

enum NoteFlowchartVisualShape {
  rectangle('rectangle'),
  oval('oval'),
  diamond('diamond');

  const NoteFlowchartVisualShape(this.wireName);

  final String wireName;

  static NoteFlowchartVisualShape? maybeFromWireName(String? value) {
    for (final item in values) {
      if (item.wireName == value) {
        return item;
      }
    }
    return null;
  }
}

enum NoteFlowchartPortSide {
  top('top'),
  right('right'),
  bottom('bottom'),
  left('left');

  const NoteFlowchartPortSide(this.wireName);

  final String wireName;

  static NoteFlowchartPortSide fromWireName(String? value) {
    for (final item in values) {
      if (item.wireName == value) {
        return item;
      }
    }
    return NoteFlowchartPortSide.bottom;
  }
}

enum NoteFlowchartPortSemantic {
  normal('normal'),
  yes('yes'),
  no('no'),
  custom('custom');

  const NoteFlowchartPortSemantic(this.wireName);

  final String wireName;

  static NoteFlowchartPortSemantic fromWireName(String? value) {
    for (final item in values) {
      if (item.wireName == value) {
        return item;
      }
    }
    return NoteFlowchartPortSemantic.normal;
  }
}

enum NoteFlowchartRoutingMode {
  auto('auto'),
  manual('manual');

  const NoteFlowchartRoutingMode(this.wireName);

  final String wireName;

  static NoteFlowchartRoutingMode fromWireName(String? value) {
    for (final item in values) {
      if (item.wireName == value) {
        return item;
      }
    }
    return NoteFlowchartRoutingMode.auto;
  }
}

class NoteFlowchartPort {
  const NoteFlowchartPort({
    required this.id,
    required this.side,
    this.label = '',
    this.semantic = NoteFlowchartPortSemantic.normal,
  });

  final String id;
  final NoteFlowchartPortSide side;
  final String label;
  final NoteFlowchartPortSemantic semantic;

  factory NoteFlowchartPort.fromJson(Map<String, Object?> json) {
    return NoteFlowchartPort(
      id: json['id']?.toString() ?? 'port-1',
      side: NoteFlowchartPortSide.fromWireName(json['side']?.toString()),
      label: json['label']?.toString() ?? '',
      semantic: NoteFlowchartPortSemantic.fromWireName(
        json['semantic']?.toString(),
      ),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'side': side.wireName,
      if (label.trim().isNotEmpty) 'label': label,
      if (semantic != NoteFlowchartPortSemantic.normal)
        'semantic': semantic.wireName,
    };
  }

  NoteFlowchartPort copyWith({
    String? id,
    NoteFlowchartPortSide? side,
    String? label,
    NoteFlowchartPortSemantic? semantic,
  }) {
    return NoteFlowchartPort(
      id: id ?? this.id,
      side: side ?? this.side,
      label: label ?? this.label,
      semantic: semantic ?? this.semantic,
    );
  }
}

class NoteFlowchartWaypoint {
  const NoteFlowchartWaypoint(this.x, this.y);

  final double x;
  final double y;

  factory NoteFlowchartWaypoint.fromJson(Object? value) {
    if (value is List && value.length >= 2) {
      return NoteFlowchartWaypoint(
        _doubleFromAny(value[0]),
        _doubleFromAny(value[1]),
      );
    }
    if (value is Map) {
      return NoteFlowchartWaypoint(
        _doubleFromAny(value['x']),
        _doubleFromAny(value['y']),
      );
    }
    return const NoteFlowchartWaypoint(0, 0);
  }

  Object toJson() => [x, y];
}

class NoteFlowchartNode {
  const NoteFlowchartNode({
    required this.id,
    required this.label,
    this.shape = AiFlowchartNodeShape.process,
    this.kind = NoteFlowchartNodeKind.universal,
    this.role = NoteFlowchartNodeRole.normal,
    this.visualShape = NoteFlowchartVisualShape.rectangle,
    this.ports = const [],
    this.labelFills = const [],
    this.order = 0,
    this.x = 0,
    this.y = 0,
  });

  final String id;
  final String label;
  final AiFlowchartNodeShape shape;
  final NoteFlowchartNodeKind kind;
  final NoteFlowchartNodeRole role;
  final NoteFlowchartVisualShape visualShape;
  final List<NoteFlowchartPort> ports;
  final List<NoteTextFill> labelFills;
  final int order;
  final double x;
  final double y;

  factory NoteFlowchartNode.fromJson(Map<String, Object?> json) {
    final shape = AiFlowchartNodeShape.fromWireName(json['shape']?.toString());
    final label = json['label']?.toString() ?? '';
    final kind =
        NoteFlowchartNodeKind.maybeFromWireName(json['kind']?.toString()) ??
        _legacyKindForShape(shape);
    final role =
        NoteFlowchartNodeRole.maybeFromWireName(json['role']?.toString()) ??
        _legacyRoleForShape(shape, label);
    final visualShape =
        NoteFlowchartVisualShape.maybeFromWireName(
          json['visualShape']?.toString(),
        ) ??
        _legacyVisualShapeForShape(shape);
    final ports = _portsFromJson(json['ports']);
    return NoteFlowchartNode(
      id: json['id']?.toString() ?? 'node-1',
      label: label,
      shape: shape,
      kind: kind,
      role: role,
      visualShape: visualShape,
      ports: ports.isEmpty
          ? _defaultPortsFor(kind: kind, role: role, shape: shape)
          : ports,
      labelFills: _textFillsFromJson(json['labelFills']),
      order: json['order'] is int ? json['order'] as int : 0,
      x: _doubleFromAny(json['x']),
      y: _doubleFromAny(json['y']),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'label': label,
      'shape': shape.wireName,
      if (kind != NoteFlowchartNodeKind.universal) 'kind': kind.wireName,
      if (role != NoteFlowchartNodeRole.normal) 'role': role.wireName,
      if (visualShape != NoteFlowchartVisualShape.rectangle)
        'visualShape': visualShape.wireName,
      if (ports.isNotEmpty)
        'ports': ports.map((port) => port.toJson()).toList(),
      if (labelFills.isNotEmpty)
        'labelFills': labelFills.map((fill) => fill.toJson()).toList(),
      'order': order,
      if (x != 0) 'x': x,
      if (y != 0) 'y': y,
    };
  }

  NoteFlowchartNode copyWith({
    String? id,
    String? label,
    AiFlowchartNodeShape? shape,
    NoteFlowchartNodeKind? kind,
    NoteFlowchartNodeRole? role,
    NoteFlowchartVisualShape? visualShape,
    List<NoteFlowchartPort>? ports,
    List<NoteTextFill>? labelFills,
    int? order,
    double? x,
    double? y,
  }) {
    return NoteFlowchartNode(
      id: id ?? this.id,
      label: label ?? this.label,
      shape: shape ?? this.shape,
      kind: kind ?? this.kind,
      role: role ?? this.role,
      visualShape: visualShape ?? this.visualShape,
      ports: ports ?? this.ports,
      labelFills: labelFills ?? this.labelFills,
      order: order ?? this.order,
      x: x ?? this.x,
      y: y ?? this.y,
    );
  }

  static List<NoteFlowchartPort> _portsFromJson(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map>()
        .map(
          (item) => NoteFlowchartPort.fromJson(Map<String, Object?>.from(item)),
        )
        .toList(growable: false);
  }

  static NoteFlowchartNodeKind _legacyKindForShape(AiFlowchartNodeShape shape) {
    return shape == AiFlowchartNodeShape.decision
        ? NoteFlowchartNodeKind.binaryDecision
        : NoteFlowchartNodeKind.universal;
  }

  static NoteFlowchartNodeRole _legacyRoleForShape(
    AiFlowchartNodeShape shape,
    String label,
  ) {
    if (shape != AiFlowchartNodeShape.startEnd) {
      return NoteFlowchartNodeRole.normal;
    }
    final normalized = label.trim().toLowerCase();
    if (normalized.contains('vég') || normalized == 'end') {
      return NoteFlowchartNodeRole.end;
    }
    return NoteFlowchartNodeRole.start;
  }

  static NoteFlowchartVisualShape _legacyVisualShapeForShape(
    AiFlowchartNodeShape shape,
  ) {
    return switch (shape) {
      AiFlowchartNodeShape.startEnd => NoteFlowchartVisualShape.oval,
      AiFlowchartNodeShape.decision => NoteFlowchartVisualShape.diamond,
      _ => NoteFlowchartVisualShape.rectangle,
    };
  }

  static List<NoteFlowchartPort> _defaultPortsFor({
    required NoteFlowchartNodeKind kind,
    required NoteFlowchartNodeRole role,
    required AiFlowchartNodeShape shape,
  }) {
    if (kind == NoteFlowchartNodeKind.binaryDecision ||
        shape == AiFlowchartNodeShape.decision) {
      return const [
        NoteFlowchartPort(
          id: 'in',
          side: NoteFlowchartPortSide.top,
          label: 'Bemenet',
        ),
        NoteFlowchartPort(
          id: 'yes',
          side: NoteFlowchartPortSide.bottom,
          label: 'Igen',
          semantic: NoteFlowchartPortSemantic.yes,
        ),
        NoteFlowchartPort(
          id: 'no',
          side: NoteFlowchartPortSide.bottom,
          label: 'Nem',
          semantic: NoteFlowchartPortSemantic.no,
        ),
      ];
    }
    if (kind == NoteFlowchartNodeKind.multiDecision) {
      return const [
        NoteFlowchartPort(
          id: 'in',
          side: NoteFlowchartPortSide.top,
          label: 'Bemenet',
        ),
        NoteFlowchartPort(
          id: 'branch-1',
          side: NoteFlowchartPortSide.right,
          label: 'Ág 1',
          semantic: NoteFlowchartPortSemantic.custom,
        ),
        NoteFlowchartPort(
          id: 'branch-2',
          side: NoteFlowchartPortSide.bottom,
          label: 'Ág 2',
          semantic: NoteFlowchartPortSemantic.custom,
        ),
      ];
    }
    if (role == NoteFlowchartNodeRole.start) {
      return const [
        NoteFlowchartPort(
          id: 'out',
          side: NoteFlowchartPortSide.bottom,
          label: 'Kimenet',
        ),
      ];
    }
    if (role == NoteFlowchartNodeRole.end) {
      return const [
        NoteFlowchartPort(
          id: 'in',
          side: NoteFlowchartPortSide.top,
          label: 'Bemenet',
        ),
      ];
    }
    return const [
      NoteFlowchartPort(
        id: 'in',
        side: NoteFlowchartPortSide.top,
        label: 'Bemenet',
      ),
      NoteFlowchartPort(
        id: 'out',
        side: NoteFlowchartPortSide.bottom,
        label: 'Kimenet',
      ),
    ];
  }
}

class NoteFlowchartEdge {
  const NoteFlowchartEdge({
    required this.id,
    required this.fromNodeId,
    required this.toNodeId,
    required this.label,
    this.fromPortId,
    this.toPortId,
    this.routingMode = NoteFlowchartRoutingMode.auto,
    this.manualWaypoints = const [],
    this.labelFills = const [],
    this.order = 0,
  });

  final String id;
  final String fromNodeId;
  final String toNodeId;
  final String label;
  final String? fromPortId;
  final String? toPortId;
  final NoteFlowchartRoutingMode routingMode;
  final List<NoteFlowchartWaypoint> manualWaypoints;
  final List<NoteTextFill> labelFills;
  final int order;

  factory NoteFlowchartEdge.fromJson(Map<String, Object?> json) {
    return NoteFlowchartEdge(
      id: json['id']?.toString() ?? 'edge-1',
      fromNodeId: json['fromNodeId']?.toString() ?? '',
      toNodeId: json['toNodeId']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      fromPortId: json['fromPortId']?.toString(),
      toPortId: json['toPortId']?.toString(),
      routingMode: NoteFlowchartRoutingMode.fromWireName(
        json['routingMode']?.toString(),
      ),
      manualWaypoints: _waypointsFromJson(json['manualWaypoints']),
      labelFills: _textFillsFromJson(json['labelFills']),
      order: json['order'] is int ? json['order'] as int : 0,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'fromNodeId': fromNodeId,
      'toNodeId': toNodeId,
      'label': label,
      if (fromPortId != null) 'fromPortId': fromPortId,
      if (toPortId != null) 'toPortId': toPortId,
      if (routingMode != NoteFlowchartRoutingMode.auto)
        'routingMode': routingMode.wireName,
      if (manualWaypoints.isNotEmpty)
        'manualWaypoints': manualWaypoints
            .map((point) => point.toJson())
            .toList(),
      if (labelFills.isNotEmpty)
        'labelFills': labelFills.map((fill) => fill.toJson()).toList(),
      'order': order,
    };
  }

  NoteFlowchartEdge copyWith({
    String? id,
    String? fromNodeId,
    String? toNodeId,
    String? label,
    String? fromPortId,
    String? toPortId,
    bool clearFromPortId = false,
    bool clearToPortId = false,
    NoteFlowchartRoutingMode? routingMode,
    List<NoteFlowchartWaypoint>? manualWaypoints,
    List<NoteTextFill>? labelFills,
    int? order,
  }) {
    return NoteFlowchartEdge(
      id: id ?? this.id,
      fromNodeId: fromNodeId ?? this.fromNodeId,
      toNodeId: toNodeId ?? this.toNodeId,
      label: label ?? this.label,
      fromPortId: clearFromPortId ? null : fromPortId ?? this.fromPortId,
      toPortId: clearToPortId ? null : toPortId ?? this.toPortId,
      routingMode: routingMode ?? this.routingMode,
      manualWaypoints: manualWaypoints ?? this.manualWaypoints,
      labelFills: labelFills ?? this.labelFills,
      order: order ?? this.order,
    );
  }

  static List<NoteFlowchartWaypoint> _waypointsFromJson(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value.map(NoteFlowchartWaypoint.fromJson).toList(growable: false);
  }
}

double _doubleFromAny(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
