import 'dart:convert';

import '../../ai/ai_client.dart';

enum NoteBlockType {
  paragraph('paragraph'),
  heading('heading'),
  listItem('list_item'),
  table('table'),
  flowchart('flowchart');

  const NoteBlockType(this.wireName);

  final String wireName;

  static NoteBlockType fromWireName(String? value) {
    return NoteBlockType.values.firstWhere(
      (type) => type.wireName == value,
      orElse: () => NoteBlockType.paragraph,
    );
  }
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
  const NoteDocument({required this.blocks, this.schemaVersion = 1});

  final int schemaVersion;
  final List<NoteBlock> blocks;

  factory NoteDocument.empty() {
    return const NoteDocument(blocks: [
      NoteBlock(id: 'block-1', type: NoteBlockType.paragraph, text: ''),
    ]);
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
              .map((item) => NoteBlock.fromJson(Map<String, Object?>.from(item)))
              .toList(growable: false);
          return NoteDocument(
            schemaVersion: decoded['schemaVersion'] is int
                ? decoded['schemaVersion'] as int
                : 1,
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
        return NoteDocument(blocks: [
          NoteBlock(
            id: 'block-1',
            type: NoteBlockType.table,
            title: title,
            rows: rows,
          ),
        ]);
      }
    }
    if (normalized == 'flowchart') {
      final text = _legacyText(legacyText, legacyPayload);
      return NoteDocument(blocks: [
        NoteBlock(
          id: 'block-1',
          type: NoteBlockType.flowchart,
          title: title,
          text: text,
        ),
      ]);
    }
    final text = _legacyText(legacyText, legacyPayload);
    return NoteDocument(blocks: [
      NoteBlock(
        id: 'block-1',
        type: NoteBlockType.paragraph,
        text: text,
      ),
    ]);
  }

  String toPayloadJson() {
    return jsonEncode({
      'schemaVersion': schemaVersion,
      'type': 'document',
      'blocks': blocks.map((block) => block.toJson()).toList(),
    });
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

  NoteDocument copyWith({List<NoteBlock>? blocks}) {
    return NoteDocument(
      schemaVersion: schemaVersion,
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
          (row) => row
              .map((cell) => cell.toString().trim())
              .toList(growable: false),
        )
        .where((row) => row.any((cell) => cell.isNotEmpty))
        .toList(growable: false);
  }
}

class NoteListItem {
  const NoteListItem({
    required this.id,
    required this.text,
    this.level = 0,
    this.checked = false,
  });

  final String id;
  final String text;
  final int level;
  final bool checked;

  factory NoteListItem.fromJson(Map<String, Object?> json) {
    return NoteListItem(
      id: json['id']?.toString() ?? 'item-1',
      text: json['text']?.toString() ?? '',
      level: json['level'] is int ? json['level'] as int : 0,
      checked: json['checked'] == true,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'text': text,
      if (level != 0) 'level': level,
      if (checked) 'checked': true,
    };
  }

  NoteListItem copyWith({String? id, String? text, int? level, bool? checked}) {
    return NoteListItem(
      id: id ?? this.id,
      text: text ?? this.text,
      level: level ?? this.level,
      checked: checked ?? this.checked,
    );
  }
}

class NoteBlock {
  const NoteBlock({
    required this.id,
    required this.type,
    this.text = '',
    this.title,
    this.level = 0,
    this.rows = const [],
    this.nodes = const [],
    this.edges = const [],
    this.listItems = const [],
    this.indexedContentHash,
    this.indexedAt,
  });

  final String id;
  final NoteBlockType type;
  final String text;
  final String? title;
  final int level;
  final List<List<String>> rows;
  final List<NoteFlowchartNode> nodes;
  final List<NoteFlowchartEdge> edges;
  final List<NoteListItem> listItems;
  final String? indexedContentHash;
  final DateTime? indexedAt;

  factory NoteBlock.fromJson(Map<String, Object?> json) {
    return NoteBlock(
      id: json['id']?.toString() ?? 'block-1',
      type: NoteBlockType.fromWireName(json['type']?.toString()),
      text: json['text']?.toString() ?? '',
      title: json['title']?.toString(),
      level: json['level'] is int ? json['level'] as int : 0,
      rows: _rowsFromJson(json['rows']),
      nodes: _nodesFromJson(json['nodes']),
      edges: _edgesFromJson(json['edges']),
      listItems: _listItemsFromJson(json['listItems']),
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
      if (level != 0) 'level': level,
      if (rows.isNotEmpty) 'rows': rows,
      if (nodes.isNotEmpty) 'nodes': nodes.map((node) => node.toJson()).toList(),
      if (edges.isNotEmpty) 'edges': edges.map((edge) => edge.toJson()).toList(),
      if (listItems.isNotEmpty) 'listItems': listItems.map((item) => item.toJson()).toList(),
      if (indexedContentHash != null) 'indexedContentHash': indexedContentHash,
      if (indexedAt != null) 'indexedAt': indexedAt!.toIso8601String(),
    };
  }

  String get plainText {
    return switch (type) {
      NoteBlockType.table => _tableText,
      NoteBlockType.flowchart => _flowchartText,
      NoteBlockType.listItem => _listText,
      NoteBlockType.heading || NoteBlockType.paragraph => text.trim(),
    };
  }

  String get plainTextForIndexing {
    return switch (type) {
      NoteBlockType.listItem => _listText,
      _ => plainText,
    };
  }

  bool get hasContent => plainTextForIndexing.trim().isNotEmpty;

  String get contentHash => stableNoteContentHash(plainTextForIndexing);

  bool get isIndexFresh => indexedContentHash != null && indexedContentHash == contentHash;

  bool get needsReindex => hasContent && indexedContentHash != null && !isIndexFresh;

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

  String _indent(int level) => List.filled(level.clamp(0, 8).toInt(), '  ').join();

  String get _tableText {
    final lines = <String>[];
    if (title?.trim().isNotEmpty == true) {
      lines.add(title!.trim());
    }
    for (final row in rows) {
      final line = row.map((cell) => cell.trim()).where((cell) => cell.isNotEmpty).join(' | ');
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

  NoteBlock copyWith({
    String? id,
    NoteBlockType? type,
    String? text,
    String? title,
    int? level,
    List<List<String>>? rows,
    List<NoteFlowchartNode>? nodes,
    List<NoteFlowchartEdge>? edges,
    List<NoteListItem>? listItems,
    String? indexedContentHash,
    DateTime? indexedAt,
    bool clearIndex = false,
  }) {
    return NoteBlock(
      id: id ?? this.id,
      type: type ?? this.type,
      text: text ?? this.text,
      title: title ?? this.title,
      level: level ?? this.level,
      rows: rows ?? this.rows,
      nodes: nodes ?? this.nodes,
      edges: edges ?? this.edges,
      listItems: listItems ?? this.listItems,
      indexedContentHash: clearIndex ? null : indexedContentHash ?? this.indexedContentHash,
      indexedAt: clearIndex ? null : indexedAt ?? this.indexedAt,
    );
  }

  static List<List<String>> _rowsFromJson(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<List>()
        .map((row) => row.map((cell) => cell.toString()).toList(growable: false))
        .toList(growable: false);
  }

  static List<NoteFlowchartNode> _nodesFromJson(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map>()
        .map((item) => NoteFlowchartNode.fromJson(Map<String, Object?>.from(item)))
        .toList(growable: false);
  }

  static List<NoteFlowchartEdge> _edgesFromJson(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map>()
        .map((item) => NoteFlowchartEdge.fromJson(Map<String, Object?>.from(item)))
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
}

class NoteFlowchartNode {
  const NoteFlowchartNode({
    required this.id,
    required this.label,
    this.shape = AiFlowchartNodeShape.process,
    this.order = 0,
    this.x = 0,
    this.y = 0,
  });

  final String id;
  final String label;
  final AiFlowchartNodeShape shape;
  final int order;
  final double x;
  final double y;

  factory NoteFlowchartNode.fromJson(Map<String, Object?> json) {
    return NoteFlowchartNode(
      id: json['id']?.toString() ?? 'node-1',
      label: json['label']?.toString() ?? '',
      shape: AiFlowchartNodeShape.fromWireName(json['shape']?.toString()),
      order: json['order'] is int ? json['order'] as int : 0,
      x: _doubleFromJson(json['x']),
      y: _doubleFromJson(json['y']),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'label': label,
      'shape': shape.wireName,
      'order': order,
      if (x != 0) 'x': x,
      if (y != 0) 'y': y,
    };
  }

  NoteFlowchartNode copyWith({
    String? id,
    String? label,
    AiFlowchartNodeShape? shape,
    int? order,
    double? x,
    double? y,
  }) {
    return NoteFlowchartNode(
      id: id ?? this.id,
      label: label ?? this.label,
      shape: shape ?? this.shape,
      order: order ?? this.order,
      x: x ?? this.x,
      y: y ?? this.y,
    );
  }

  static double _doubleFromJson(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class NoteFlowchartEdge {
  const NoteFlowchartEdge({
    required this.id,
    required this.fromNodeId,
    required this.toNodeId,
    required this.label,
    this.order = 0,
  });

  final String id;
  final String fromNodeId;
  final String toNodeId;
  final String label;
  final int order;

  factory NoteFlowchartEdge.fromJson(Map<String, Object?> json) {
    return NoteFlowchartEdge(
      id: json['id']?.toString() ?? 'edge-1',
      fromNodeId: json['fromNodeId']?.toString() ?? '',
      toNodeId: json['toNodeId']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      order: json['order'] is int ? json['order'] as int : 0,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'fromNodeId': fromNodeId,
      'toNodeId': toNodeId,
      'label': label,
      'order': order,
    };
  }

  NoteFlowchartEdge copyWith({
    String? id,
    String? fromNodeId,
    String? toNodeId,
    String? label,
    int? order,
  }) {
    return NoteFlowchartEdge(
      id: id ?? this.id,
      fromNodeId: fromNodeId ?? this.fromNodeId,
      toNodeId: toNodeId ?? this.toNodeId,
      label: label ?? this.label,
      order: order ?? this.order,
    );
  }
}
