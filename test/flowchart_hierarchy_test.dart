import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/local_store/entities.dart';
import 'package:djinn/src/knowledge/models/extracted_knowledge_item.dart';
import 'package:djinn/src/knowledge/models/flowchart_hierarchy.dart';

void main() {
  test('builds sibling decision branches without inheriting child process depth', () {
    const items = [
      ExtractedKnowledgeItem(
        id: 'flow:n1',
        documentId: 'doc-1',
        sourceType: EvidenceSourceType.flowchartNode,
        text: 'Javul?',
        flowchartId: 'flow',
        flowchartElementId: 'n1',
        flowchartShape: 'decision',
        flowchartOrder: 1,
      ),
      ExtractedKnowledgeItem(
        id: 'flow:e1',
        documentId: 'doc-1',
        sourceType: EvidenceSourceType.flowchartEdge,
        text: 'Javul? -> Szállítás [igen]',
        flowchartId: 'flow',
        flowchartElementId: 'e1',
        flowchartFromId: 'n1',
        flowchartToId: 'n2',
        flowchartEdgeLabel: 'igen',
        flowchartOrder: 2,
      ),
      ExtractedKnowledgeItem(
        id: 'flow:n2',
        documentId: 'doc-1',
        sourceType: EvidenceSourceType.flowchartNode,
        text: 'Szállítás',
        flowchartId: 'flow',
        flowchartElementId: 'n2',
        flowchartShape: 'process',
        flowchartOrder: 3,
      ),
      ExtractedKnowledgeItem(
        id: 'flow:e2',
        documentId: 'doc-1',
        sourceType: EvidenceSourceType.flowchartEdge,
        text: 'Javul? -> CPAP [nem]',
        flowchartId: 'flow',
        flowchartElementId: 'e2',
        flowchartFromId: 'n1',
        flowchartToId: 'n3',
        flowchartEdgeLabel: 'nem',
        flowchartOrder: 4,
      ),
      ExtractedKnowledgeItem(
        id: 'flow:n3',
        documentId: 'doc-1',
        sourceType: EvidenceSourceType.flowchartNode,
        text: 'CPAP megfontolása',
        flowchartId: 'flow',
        flowchartElementId: 'n3',
        flowchartShape: 'process',
        flowchartOrder: 5,
      ),
    ];

    final group = const FlowchartHierarchyBuilder().build(items).single;

    expect(group.roots, hasLength(1));
    final root = group.roots.single;
    expect(root.item.text, 'Javul?');
    expect(root.branches, hasLength(2));
    expect(root.branches.map((branch) => branch.label), ['IGEN', 'NEM']);
    expect(root.branches[0].target?.item.text, 'Szállítás');
    expect(root.branches[1].target?.item.text, 'CPAP megfontolása');
    expect(group.rows.map((row) => row.item.text), [
      'Javul?',
      'Javul? -> Szállítás [igen]',
      'Szállítás',
      'Javul? -> CPAP [nem]',
      'CPAP megfontolása',
    ]);
    expect(group.rows.every((row) => row.colorSlots.isEmpty), isTrue);
    expect(group.rows.map((row) => row.depth), [0, 1, 1, 1, 1]);
  });


  test('keeps a node visible when an extracted incoming edge source is missing', () {
    const items = [
      ExtractedKnowledgeItem(
        id: 'flow:n1',
        documentId: 'doc-1',
        sourceType: EvidenceSourceType.flowchartNode,
        text: 'Oxigén adása',
        flowchartId: 'flow',
        flowchartElementId: 'n1',
        flowchartShape: 'process',
        flowchartOrder: 2,
      ),
      ExtractedKnowledgeItem(
        id: 'flow:e-orphan',
        documentId: 'doc-1',
        sourceType: EvidenceSourceType.flowchartEdge,
        text: 'Hiányzó döntés -> Oxigén',
        flowchartId: 'flow',
        flowchartElementId: 'e-orphan',
        flowchartFromId: 'missing-node',
        flowchartToId: 'n1',
        flowchartEdgeLabel: 'igen',
        flowchartOrder: 1,
      ),
      ExtractedKnowledgeItem(
        id: 'flow:n2',
        documentId: 'doc-1',
        sourceType: EvidenceSourceType.flowchartNode,
        text: 'Monitorozás',
        flowchartId: 'flow',
        flowchartElementId: 'n2',
        flowchartShape: 'process',
        flowchartOrder: 3,
      ),
    ];

    final group = const FlowchartHierarchyBuilder().build(items).single;

    expect(group.rows.map((row) => row.item.text), [
      'Oxigén adása',
      'Monitorozás',
    ]);
    expect(group.roots.map((root) => root.item.text), [
      'Oxigén adása',
      'Monitorozás',
    ]);
  });

}
