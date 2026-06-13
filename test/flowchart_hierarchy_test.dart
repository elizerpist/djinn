import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/local_store/entities.dart';
import 'package:djinn/src/knowledge/models/extracted_knowledge_item.dart';
import 'package:djinn/src/knowledge/models/flowchart_hierarchy.dart';

void main() {
  test(
    'orders flowchart nodes under branch edges with inherited color slots',
    () {
      const items = [
        ExtractedKnowledgeItem(
          id: 'flow:n1',
          documentId: 'doc-1',
          sourceType: EvidenceSourceType.flowchartNode,
          text: 'Légzési elégtelenség?',
          flowchartId: 'flow',
          flowchartElementId: 'n1',
          flowchartShape: 'decision',
          flowchartOrder: 1,
        ),
        ExtractedKnowledgeItem(
          id: 'flow:e1',
          documentId: 'doc-1',
          sourceType: EvidenceSourceType.flowchartEdge,
          text: 'Légzési elégtelenség? -> Oxigén [igen]',
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
          text: 'Oxigén',
          flowchartId: 'flow',
          flowchartElementId: 'n2',
          flowchartShape: 'process',
          flowchartOrder: 3,
        ),
      ];

      final groups = const FlowchartHierarchyBuilder().build(items);

      expect(groups, hasLength(1));
      expect(groups.single.rows.map((row) => row.item.text), [
        'Légzési elégtelenség?',
        'Légzési elégtelenség? -> Oxigén [igen]',
        'Oxigén',
      ]);
      expect(groups.single.rows.map((row) => row.depth), [0, 1, 2]);
      expect(groups.single.rows.last.colorSlots, [0, 1]);
    },
  );
}
