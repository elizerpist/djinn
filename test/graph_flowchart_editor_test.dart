import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:djinn/src/flowchart/models/flowchart_view_model.dart';
import 'package:djinn/src/flowchart/ui/graph_flowchart_editor.dart';
import 'package:djinn/src/local_store/entities.dart';

void main() {
  testWidgets('renders nodes and edge labels on canvas', (tester) async {
    final model = FlowchartViewModel(
      id: 'flow-1',
      nodes: const [
        FlowchartNodeViewModel(
          id: 'n1',
          label: 'Start',
          x: 20,
          y: 20,
          validationState: ValidationState.unreviewed,
        ),
        FlowchartNodeViewModel(
          id: 'n2',
          label: 'Döntés',
          x: 180,
          y: 20,
          validationState: ValidationState.unreviewed,
        ),
      ],
      edges: const [
        FlowchartEdgeViewModel(
          id: 'e1',
          fromNodeId: 'n1',
          toNodeId: 'n2',
          label: 'igen',
          validationState: ValidationState.unreviewed,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GraphFlowchartEditor(model: model)),
      ),
    );

    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Döntés'), findsOneWidget);
    expect(find.text('igen'), findsOneWidget);
  });
}
