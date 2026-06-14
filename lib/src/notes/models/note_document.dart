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
  });

  final String id;
  final NoteBlockType type;
  final String text;
  final String? title;
  final int level;
  final List<List<String>> rows;
  final List<NoteFlowchartNode> nodes;
  final List<NoteFlowchartEdge> edges;

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
    };
  }

  String get plainText {
    return switch (type) {
      NoteBlockType.table => _tableText,
      NoteBlockType.flowchart => _flowchartText,
      NoteBlockType.heading ||
      NoteBlockType.paragraph ||
      NoteBlockType.listItem => text.trim(),
    };
  }

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
}

class NoteFlowchartNode {
  const NoteFlowchartNode({
    required this.id,
    required this.label,
    this.shape = AiFlowchartNodeShape.process,
    this.order = 0,
  });

  final String id;
  final String label;
  final AiFlowchartNodeShape shape;
  final int order;

  factory NoteFlowchartNode.fromJson(Map<String, Object?> json) {
    return NoteFlowchartNode(
      id: json['id']?.toString() ?? 'node-1',
      label: json['label']?.toString() ?? '',
      shape: AiFlowchartNodeShape.fromWireName(json['shape']?.toString()),
      order: json['order'] is int ? json['order'] as int : 0,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'label': label,
      'shape': shape.wireName,
      'order': order,
    };
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
}
