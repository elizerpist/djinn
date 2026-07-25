import '../../ai/ai_client.dart';
import '../../notes/models/note_document.dart';

/// Converts the manual/OCR flowchart draft format into the canonical
/// structured FlowchartChunk payload.
///
/// The editor emits lines such as:
/// `node start | start_end | Kezdés`
/// `edge Kezdés -> Következő lépés [igen]`
///
/// If OCR produces only plain lines, every non-empty line becomes a node and
/// the nodes are linked sequentially. This keeps the source workflow useful
/// without introducing a third chunk representation.
NoteBlock manualFlowchartBlockFromDraft({
  required String id,
  required String text,
  String? title,
}) {
  final lines = text
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty && line.toLowerCase() != '[flowchart]')
      .toList(growable: false);
  final nodes = <NoteFlowchartNode>[];
  final edgeDrafts = <String>[];
  final plainLines = <String>[];
  final usedNodeIds = <String>{};
  final nodePattern = RegExp(
    r'^node\s+([^\s|]+)\s*\|\s*([^|]+?)\s*\|\s*(.+)$',
    caseSensitive: false,
  );

  for (final line in lines) {
    final nodeMatch = nodePattern.firstMatch(line);
    if (nodeMatch != null) {
      final nodeId = _uniqueId(
        nodeMatch.group(1)!.trim(),
        usedNodeIds,
        fallbackPrefix: 'draft-node',
      );
      final shape = AiFlowchartNodeShape.fromWireName(
        nodeMatch.group(2)!.trim().toLowerCase(),
      );
      nodes.add(
        NoteFlowchartNode.fromJson({
          'id': nodeId,
          'label': nodeMatch.group(3)!.trim(),
          'shape': shape.wireName,
          'order': nodes.length + 1,
        }),
      );
      continue;
    }
    if (line.toLowerCase().startsWith('edge ')) {
      edgeDrafts.add(line.substring(5).trim());
      continue;
    }
    plainLines.add(line);
  }

  if (nodes.isEmpty) {
    for (var index = 0; index < plainLines.length; index += 1) {
      final nodeId = _uniqueId(
        'draft-node-${index + 1}',
        usedNodeIds,
        fallbackPrefix: 'draft-node',
      );
      nodes.add(
        NoteFlowchartNode.fromJson({
          'id': nodeId,
          'label': plainLines[index],
          'shape': index == 0
              ? AiFlowchartNodeShape.startEnd.wireName
              : AiFlowchartNodeShape.process.wireName,
          'order': index + 1,
        }),
      );
    }
  }

  final nodeIdByReference = <String, String>{};
  for (final node in nodes) {
    nodeIdByReference.putIfAbsent(node.id, () => node.id);
    nodeIdByReference.putIfAbsent(node.label.trim(), () => node.id);
  }
  final edges = <NoteFlowchartEdge>[];
  for (final draft in edgeDrafts) {
    final arrow = draft.indexOf('->');
    if (arrow <= 0 || arrow >= draft.length - 2) {
      continue;
    }
    final fromReference = draft.substring(0, arrow).trim();
    var toReference = draft.substring(arrow + 2).trim();
    var label = '';
    final labelStart = toReference.lastIndexOf('[');
    if (labelStart > 0 && toReference.endsWith(']')) {
      label = toReference.substring(labelStart + 1, toReference.length - 1);
      toReference = toReference.substring(0, labelStart).trim();
    }
    final fromNodeId = nodeIdByReference[fromReference];
    final toNodeId = nodeIdByReference[toReference];
    if (fromNodeId == null || toNodeId == null) {
      continue;
    }
    edges.add(
      NoteFlowchartEdge(
        id: 'draft-edge-${edges.length + 1}',
        fromNodeId: fromNodeId,
        toNodeId: toNodeId,
        label: label.trim(),
        order: edges.length + 1,
      ),
    );
  }

  if (edges.isEmpty && edgeDrafts.isEmpty && nodes.length > 1) {
    for (var index = 0; index < nodes.length - 1; index += 1) {
      edges.add(
        NoteFlowchartEdge(
          id: 'draft-edge-${index + 1}',
          fromNodeId: nodes[index].id,
          toNodeId: nodes[index + 1].id,
          label: '',
          order: index + 1,
        ),
      );
    }
  }

  return NoteBlock(
    id: id,
    type: NoteBlockType.flowchart,
    title: title,
    nodes: List.unmodifiable(nodes),
    edges: List.unmodifiable(edges),
  );
}

String _uniqueId(
  String requested,
  Set<String> used, {
  required String fallbackPrefix,
}) {
  final normalized = requested.trim();
  final base = normalized.isEmpty ? fallbackPrefix : normalized;
  var candidate = base;
  var suffix = 2;
  while (!used.add(candidate)) {
    candidate = '$base-$suffix';
    suffix += 1;
  }
  return candidate;
}
