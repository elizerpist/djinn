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

  static const values = [
    topic,
    type,
    state,
    symbol,
    node,
    branch,
    custom,
  ];

  static String normalize(String? value) {
    final normalized = value?.trim().toLowerCase().replaceAll(' ', '_') ?? '';
    return values.contains(normalized) ? normalized : custom;
  }
}

class NoteKnowledgeTag {
  const NoteKnowledgeTag({required this.type, required this.label});

  final String type;
  final String label;

  factory NoteKnowledgeTag.fromJson(Object? value) {
    if (value is Map) {
      return NoteKnowledgeTag(
        type: NoteKnowledgeTagTypes.normalize(value['type']?.toString()),
        label: value['label']?.toString().trim() ?? '',
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

  Map<String, Object?> toJson() {
    return {
      'type': NoteKnowledgeTagTypes.normalize(type),
      'label': label.trim(),
    };
  }
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
      if (tags.isNotEmpty) 'tags': tags.map((tag) => tag.toJson()).toList(),
      'blocks': blocks.map((block) => block.toJson()).toList(),
    });
  }

  String get searchMetadataText {
    return _metadataTextFromTags(tags);
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
  final String? searchContext;
  final String searchRole;
  final List<String> searchAliases;
  final List<NoteKnowledgeTag> tags;
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
      searchContext: json['searchContext']?.toString(),
      searchRole: NoteSearchRoles.normalize(json['searchRole']?.toString()),
      searchAliases: _stringsFromJson(json['searchAliases']),
      tags: _tagsFromJson(json['tags']),
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
    parts.addAll(searchAliases.map((alias) => alias.trim()).where(
      (alias) => alias.isNotEmpty,
    ));
    final tagMetadata = _metadataTextFromTags(tags);
    if (tagMetadata.isNotEmpty) {
      parts.add(tagMetadata);
    }
    return parts.join('\n').trim();
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
    String? searchContext,
    String? searchRole,
    List<String>? searchAliases,
    List<NoteKnowledgeTag>? tags,
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
      searchContext: searchContext ?? this.searchContext,
      searchRole: searchRole ?? this.searchRole,
      searchAliases: searchAliases ?? this.searchAliases,
      tags: tags ?? this.tags,
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
      semantic: NoteFlowchartPortSemantic.fromWireName(json['semantic']?.toString()),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'side': side.wireName,
      if (label.trim().isNotEmpty) 'label': label,
      if (semantic != NoteFlowchartPortSemantic.normal) 'semantic': semantic.wireName,
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
      return NoteFlowchartWaypoint(_doubleFromAny(value[0]), _doubleFromAny(value[1]));
    }
    if (value is Map) {
      return NoteFlowchartWaypoint(_doubleFromAny(value['x']), _doubleFromAny(value['y']));
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
  final int order;
  final double x;
  final double y;

  factory NoteFlowchartNode.fromJson(Map<String, Object?> json) {
    final shape = AiFlowchartNodeShape.fromWireName(json['shape']?.toString());
    final label = json['label']?.toString() ?? '';
    final kind = NoteFlowchartNodeKind.maybeFromWireName(json['kind']?.toString()) ?? _legacyKindForShape(shape);
    final role = NoteFlowchartNodeRole.maybeFromWireName(json['role']?.toString()) ?? _legacyRoleForShape(shape, label);
    final visualShape = NoteFlowchartVisualShape.maybeFromWireName(json['visualShape']?.toString()) ?? _legacyVisualShapeForShape(shape);
    final ports = _portsFromJson(json['ports']);
    return NoteFlowchartNode(
      id: json['id']?.toString() ?? 'node-1',
      label: label,
      shape: shape,
      kind: kind,
      role: role,
      visualShape: visualShape,
      ports: ports.isEmpty ? _defaultPortsFor(kind: kind, role: role, shape: shape) : ports,
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
      if (visualShape != NoteFlowchartVisualShape.rectangle) 'visualShape': visualShape.wireName,
      if (ports.isNotEmpty) 'ports': ports.map((port) => port.toJson()).toList(),
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
        .map((item) => NoteFlowchartPort.fromJson(Map<String, Object?>.from(item)))
        .toList(growable: false);
  }

  static NoteFlowchartNodeKind _legacyKindForShape(AiFlowchartNodeShape shape) {
    return shape == AiFlowchartNodeShape.decision ? NoteFlowchartNodeKind.binaryDecision : NoteFlowchartNodeKind.universal;
  }

  static NoteFlowchartNodeRole _legacyRoleForShape(AiFlowchartNodeShape shape, String label) {
    if (shape != AiFlowchartNodeShape.startEnd) {
      return NoteFlowchartNodeRole.normal;
    }
    final normalized = label.trim().toLowerCase();
    if (normalized.contains('vég') || normalized == 'end') {
      return NoteFlowchartNodeRole.end;
    }
    return NoteFlowchartNodeRole.start;
  }

  static NoteFlowchartVisualShape _legacyVisualShapeForShape(AiFlowchartNodeShape shape) {
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
    if (kind == NoteFlowchartNodeKind.binaryDecision || shape == AiFlowchartNodeShape.decision) {
      return const [
        NoteFlowchartPort(id: 'in', side: NoteFlowchartPortSide.top, label: 'Bemenet'),
        NoteFlowchartPort(id: 'yes', side: NoteFlowchartPortSide.bottom, label: 'Igen', semantic: NoteFlowchartPortSemantic.yes),
        NoteFlowchartPort(id: 'no', side: NoteFlowchartPortSide.bottom, label: 'Nem', semantic: NoteFlowchartPortSemantic.no),
      ];
    }
    if (kind == NoteFlowchartNodeKind.multiDecision) {
      return const [
        NoteFlowchartPort(id: 'in', side: NoteFlowchartPortSide.top, label: 'Bemenet'),
        NoteFlowchartPort(id: 'branch-1', side: NoteFlowchartPortSide.right, label: 'Ág 1', semantic: NoteFlowchartPortSemantic.custom),
        NoteFlowchartPort(id: 'branch-2', side: NoteFlowchartPortSide.bottom, label: 'Ág 2', semantic: NoteFlowchartPortSemantic.custom),
      ];
    }
    if (role == NoteFlowchartNodeRole.start) {
      return const [NoteFlowchartPort(id: 'out', side: NoteFlowchartPortSide.bottom, label: 'Kimenet')];
    }
    if (role == NoteFlowchartNodeRole.end) {
      return const [NoteFlowchartPort(id: 'in', side: NoteFlowchartPortSide.top, label: 'Bemenet')];
    }
    return const [
      NoteFlowchartPort(id: 'in', side: NoteFlowchartPortSide.top, label: 'Bemenet'),
      NoteFlowchartPort(id: 'out', side: NoteFlowchartPortSide.bottom, label: 'Kimenet'),
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
  final int order;

  factory NoteFlowchartEdge.fromJson(Map<String, Object?> json) {
    return NoteFlowchartEdge(
      id: json['id']?.toString() ?? 'edge-1',
      fromNodeId: json['fromNodeId']?.toString() ?? '',
      toNodeId: json['toNodeId']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      fromPortId: json['fromPortId']?.toString(),
      toPortId: json['toPortId']?.toString(),
      routingMode: NoteFlowchartRoutingMode.fromWireName(json['routingMode']?.toString()),
      manualWaypoints: _waypointsFromJson(json['manualWaypoints']),
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
      if (routingMode != NoteFlowchartRoutingMode.auto) 'routingMode': routingMode.wireName,
      if (manualWaypoints.isNotEmpty) 'manualWaypoints': manualWaypoints.map((point) => point.toJson()).toList(),
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
    NoteFlowchartRoutingMode? routingMode,
    List<NoteFlowchartWaypoint>? manualWaypoints,
    int? order,
  }) {
    return NoteFlowchartEdge(
      id: id ?? this.id,
      fromNodeId: fromNodeId ?? this.fromNodeId,
      toNodeId: toNodeId ?? this.toNodeId,
      label: label ?? this.label,
      fromPortId: fromPortId ?? this.fromPortId,
      toPortId: toPortId ?? this.toPortId,
      routingMode: routingMode ?? this.routingMode,
      manualWaypoints: manualWaypoints ?? this.manualWaypoints,
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
