import '../../local_store/entities.dart';
import 'extracted_knowledge_item.dart';

class FlowchartHierarchyGroup {
  const FlowchartHierarchyGroup({required this.id, required this.rows});

  final String id;
  final List<FlowchartHierarchyRow> rows;
}

class FlowchartHierarchyRow {
  const FlowchartHierarchyRow({
    required this.item,
    required this.depth,
    required this.colorSlots,
  });

  final ExtractedKnowledgeItem item;
  final int depth;
  final List<int> colorSlots;

  bool get isEdge => item.sourceType == EvidenceSourceType.flowchartEdge;
}

class FlowchartHierarchyBuilder {
  const FlowchartHierarchyBuilder();

  List<FlowchartHierarchyGroup> build(List<ExtractedKnowledgeItem> items) {
    final flowchartIds = <String>[];
    for (final item in items) {
      final flowchartId = item.flowchartId;
      if (flowchartId != null && !flowchartIds.contains(flowchartId)) {
        flowchartIds.add(flowchartId);
      }
    }
    return [
      for (final flowchartId in flowchartIds)
        FlowchartHierarchyGroup(
          id: flowchartId,
          rows: _buildGroup(
            items
                .where((item) => item.flowchartId == flowchartId)
                .toList(growable: false),
          ),
        ),
    ];
  }

  List<FlowchartHierarchyRow> _buildGroup(List<ExtractedKnowledgeItem> items) {
    final nodes = <String, ExtractedKnowledgeItem>{};
    final edgesByFrom = <String, List<ExtractedKnowledgeItem>>{};
    final incoming = <String, int>{};
    for (final item in items) {
      if (item.sourceType == EvidenceSourceType.flowchartNode) {
        final id = item.flowchartElementId ?? item.id;
        nodes[id] = item;
        incoming.putIfAbsent(id, () => 0);
      }
    }
    for (final item in items) {
      if (item.sourceType != EvidenceSourceType.flowchartEdge) {
        continue;
      }
      final from = item.flowchartFromId;
      final to = item.flowchartToId;
      if (from == null || to == null) {
        continue;
      }
      edgesByFrom.putIfAbsent(from, () => []).add(item);
      incoming[to] = (incoming[to] ?? 0) + 1;
    }
    for (final edges in edgesByFrom.values) {
      edges.sort(_compareItems);
    }
    final starts =
        nodes.values
            .where(
              (node) =>
                  (incoming[node.flowchartElementId ?? node.id] ?? 0) == 0,
            )
            .toList(growable: false)
          ..sort(_compareItems);
    final orderedStarts = starts.isEmpty
        ? (nodes.values.toList(growable: false)..sort(_compareItems))
        : starts;
    final rows = <FlowchartHierarchyRow>[];
    final expanded = <String>{};
    var rootSlot = 0;
    for (final start in orderedStarts) {
      final slot = rootSlot++;
      _walkNode(
        start,
        nodes,
        edgesByFrom,
        rows,
        expanded,
        depth: 0,
        colorSlots: [slot],
        nextSlot: slot + 1,
      );
    }
    final listedNodes = rows
        .where((row) => row.item.sourceType == EvidenceSourceType.flowchartNode)
        .map((row) => row.item.flowchartElementId ?? row.item.id)
        .toSet();
    for (final node in nodes.values.toList(
      growable: false,
    )..sort(_compareItems)) {
      final id = node.flowchartElementId ?? node.id;
      if (!listedNodes.contains(id)) {
        rows.add(
          FlowchartHierarchyRow(item: node, depth: 0, colorSlots: [rootSlot++]),
        );
      }
    }
    return rows;
  }

  int _walkNode(
    ExtractedKnowledgeItem node,
    Map<String, ExtractedKnowledgeItem> nodes,
    Map<String, List<ExtractedKnowledgeItem>> edgesByFrom,
    List<FlowchartHierarchyRow> rows,
    Set<String> expanded, {
    required int depth,
    required List<int> colorSlots,
    required int nextSlot,
  }) {
    final nodeId = node.flowchartElementId ?? node.id;
    rows.add(
      FlowchartHierarchyRow(item: node, depth: depth, colorSlots: colorSlots),
    );
    if (!expanded.add(nodeId)) {
      return nextSlot;
    }
    var slotCursor = nextSlot;
    final edges = edgesByFrom[nodeId] ?? const [];
    for (final edge in edges) {
      final branchSlot = slotCursor++;
      final branchColors = [...colorSlots, branchSlot];
      rows.add(
        FlowchartHierarchyRow(
          item: edge,
          depth: depth + 1,
          colorSlots: branchColors,
        ),
      );
      final targetId = edge.flowchartToId;
      final target = targetId == null ? null : nodes[targetId];
      if (target != null) {
        slotCursor = _walkNode(
          target,
          nodes,
          edgesByFrom,
          rows,
          expanded,
          depth: depth + 2,
          colorSlots: branchColors,
          nextSlot: slotCursor,
        );
      }
    }
    return slotCursor;
  }

  int _compareItems(ExtractedKnowledgeItem a, ExtractedKnowledgeItem b) {
    final order = a.flowchartOrder.compareTo(b.flowchartOrder);
    if (order != 0) {
      return order;
    }
    return a.id.compareTo(b.id);
  }
}
