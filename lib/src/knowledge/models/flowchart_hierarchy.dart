import '../../local_store/entities.dart';
import 'extracted_knowledge_item.dart';

class FlowchartHierarchyGroup {
  const FlowchartHierarchyGroup({
    required this.id,
    required this.rows,
    required this.roots,
  });

  final String id;
  final List<FlowchartHierarchyRow> rows;
  final List<FlowchartHierarchyNode> roots;

  String get title {
    for (final row in rows) {
      final value = row.item.sectionTitle?.trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    for (final root in roots) {
      final value = root.item.sectionTitle?.trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return 'Flowchart';
  }
}

class FlowchartHierarchyNode {
  const FlowchartHierarchyNode({required this.item, required this.branches});

  final ExtractedKnowledgeItem item;
  final List<FlowchartHierarchyBranch> branches;
}

class FlowchartHierarchyBranch {
  const FlowchartHierarchyBranch({required this.edge, this.target});

  final ExtractedKnowledgeItem edge;
  final FlowchartHierarchyNode? target;

  String get label {
    final value = edge.flowchartEdgeLabel?.trim();
    if (value == null || value.isEmpty) {
      return '';
    }
    return value.toUpperCase();
  }
}

class FlowchartHierarchyRow {
  const FlowchartHierarchyRow({
    required this.item,
    required this.depth,
    this.colorSlots = const [],
  });

  final ExtractedKnowledgeItem item;
  final int depth;
  final List<int> colorSlots;

  bool get isEdge => item.sourceType == EvidenceSourceType.flowchartEdge;

  bool get isConnector => isEdge;

  String get connectorLabel {
    final label = item.flowchartEdgeLabel?.trim();
    if (label == null || label.isEmpty) {
      return '';
    }
    return label.toUpperCase();
  }
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
        _buildGroup(
          flowchartId,
          items
              .where((item) => item.flowchartId == flowchartId)
              .toList(growable: false),
        ),
    ];
  }

  FlowchartHierarchyGroup _buildGroup(
    String flowchartId,
    List<ExtractedKnowledgeItem> items,
  ) {
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
      if (from == null || !nodes.containsKey(from)) {
        continue;
      }
      edgesByFrom.putIfAbsent(from, () => []).add(item);
      if (to != null && nodes.containsKey(to)) {
        incoming[to] = (incoming[to] ?? 0) + 1;
      }
    }
    for (final edges in edgesByFrom.values) {
      edges.sort(_compareItems);
    }
    final starts = nodes.values
        .where((node) => (incoming[node.flowchartElementId ?? node.id] ?? 0) == 0)
        .toList(growable: false)
      ..sort(_compareItems);
    final orderedStarts = starts.isEmpty
        ? (nodes.values.toList(growable: false)..sort(_compareItems))
        : starts;
    final roots = [
      for (final start in orderedStarts)
        _buildNode(start, nodes, edgesByFrom, path: const {}),
    ];
    final rows = <FlowchartHierarchyRow>[];
    for (final root in roots) {
      _flattenNode(root, rows, depth: 0);
    }
    return FlowchartHierarchyGroup(id: flowchartId, rows: rows, roots: roots);
  }

  FlowchartHierarchyNode _buildNode(
    ExtractedKnowledgeItem node,
    Map<String, ExtractedKnowledgeItem> nodes,
    Map<String, List<ExtractedKnowledgeItem>> edgesByFrom, {
    required Set<String> path,
  }) {
    final nodeId = node.flowchartElementId ?? node.id;
    if (path.contains(nodeId)) {
      return FlowchartHierarchyNode(item: node, branches: const []);
    }
    final nextPath = {...path, nodeId};
    final branches = <FlowchartHierarchyBranch>[];
    for (final edge in edgesByFrom[nodeId] ?? const <ExtractedKnowledgeItem>[]) {
      final targetId = edge.flowchartToId;
      final targetItem = targetId == null ? null : nodes[targetId];
      branches.add(
        FlowchartHierarchyBranch(
          edge: edge,
          target: targetItem == null
              ? null
              : _buildNode(targetItem, nodes, edgesByFrom, path: nextPath),
        ),
      );
    }
    return FlowchartHierarchyNode(
      item: node,
      branches: List.unmodifiable(branches),
    );
  }

  void _flattenNode(
    FlowchartHierarchyNode node,
    List<FlowchartHierarchyRow> rows, {
    required int depth,
  }) {
    rows.add(FlowchartHierarchyRow(item: node.item, depth: depth));
    for (final branch in node.branches) {
      rows.add(FlowchartHierarchyRow(item: branch.edge, depth: depth + 1));
      final target = branch.target;
      if (target != null) {
        _flattenNode(target, rows, depth: depth + 1);
      }
    }
  }

  int _compareItems(ExtractedKnowledgeItem a, ExtractedKnowledgeItem b) {
    final order = a.flowchartOrder.compareTo(b.flowchartOrder);
    if (order != 0) {
      return order;
    }
    return a.id.compareTo(b.id);
  }
}
