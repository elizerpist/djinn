import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:djinn/src/debug/debug_console.dart';
import 'package:djinn/src/flowchart/data/flowchart_validation_repository.dart';
import 'package:djinn/src/flowchart/models/flowchart_view_model.dart';
import 'package:djinn/src/flowchart/ui/flowchart_validation_screen.dart';
import 'package:djinn/src/flowchart/ui/simple_flowchart_editor.dart';
import 'package:djinn/src/local_store/entities.dart';

void main() {
  setUp(DebugConsole.clear);

  test('rejecting a node prevents it from being answerable', () async {
    final repository = MemoryFlowchartValidationRepository();
    repository.addNode('node-1', ValidationState.unreviewed);

    await repository.updateNodeValidation(
      nodePublicId: 'node-1',
      state: ValidationState.rejected,
      rejectionReason: 'Hibás OCR',
    );

    expect(await repository.isNodeAnswerable('node-1'), isFalse);
    expect(
      DebugConsole.allText,
      contains('[Flowchart] node validation node=node-1 state=rejected'),
    );
  });

  testWidgets('simple editor lists nodes and validates a node', (tester) async {
    String? validatedNodeId;
    final model = FlowchartViewModel(
      id: 'flow-1',
      nodes: const [
        FlowchartNodeViewModel(
          id: 'node-1',
          label: 'Start',
          x: 0,
          y: 0,
          validationState: ValidationState.unreviewed,
        ),
      ],
      edges: const [
        FlowchartEdgeViewModel(
          id: 'edge-1',
          fromNodeId: 'node-1',
          toNodeId: 'node-2',
          label: 'igen',
          validationState: ValidationState.unreviewed,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SimpleFlowchartEditor(
            model: model,
            onNodeValidation:
                ({
                  required nodePublicId,
                  required state,
                  rejectionReason,
                }) async {
                  validatedNodeId = nodePublicId;
                },
          ),
        ),
      ),
    );

    expect(find.text('Start'), findsOneWidget);
    expect(find.text('igen'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Validálás').first);
    await tester.pump();

    expect(validatedNodeId, 'node-1');
    expect(
      DebugConsole.allText,
      contains(
        '[Flowchart] node validation requested node=node-1 state=validated',
      ),
    );
  });

  testWidgets('empty flowchart validation screen explains zero reason', (
    tester,
  ) async {
    final repository = MemoryFlowchartValidationRepository(
      zeroReason: FlowchartZeroReason.noDetectedFlowcharts,
    );

    await tester.pumpWidget(
      MaterialApp(home: FlowchartValidationScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Nincs feldolgozott vagy felismert flowchart'),
      findsOneWidget,
    );
    expect(
      DebugConsole.allText,
      contains(
        '[Flowchart] validation screen loaded count=0 reason=no_detected_flowcharts',
      ),
    );
  });
}

class MemoryFlowchartValidationRepository
    implements FlowchartValidationRepository {
  MemoryFlowchartValidationRepository({this.zeroReason});

  final _nodes = <String, ValidationState>{};
  final _nodeRejectionReasons = <String, String?>{};
  final FlowchartZeroReason? zeroReason;

  void addNode(String nodePublicId, ValidationState state) {
    _nodes[nodePublicId] = state;
  }

  @override
  Future<List<FlowchartEntity>> listFlowchartsNeedingReview() async {
    return const [];
  }

  @override
  Future<FlowchartReviewList> listFlowchartReviewState() async {
    return FlowchartReviewList(items: const [], zeroReason: zeroReason);
  }

  @override
  Future<List<FlowchartNodeEntity>> listNodes(String flowchartPublicId) async {
    return const [];
  }

  @override
  Future<List<FlowchartEdgeEntity>> listEdges(String flowchartPublicId) async {
    return const [];
  }

  @override
  Future<void> updateNodeValidation({
    required String nodePublicId,
    required ValidationState state,
    String? rejectionReason,
  }) async {
    DebugConsole.log(
      '[Flowchart] node validation node=$nodePublicId state=${state.wireName}',
    );
    _nodes[nodePublicId] = state;
    _nodeRejectionReasons[nodePublicId] = rejectionReason;
  }

  @override
  Future<void> updateEdgeValidation({
    required String edgePublicId,
    required ValidationState state,
    String? rejectionReason,
  }) async {}

  @override
  Future<bool> isNodeAnswerable(String nodePublicId) async {
    return _nodes[nodePublicId] != ValidationState.rejected;
  }
}
