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

  testWidgets('empty validation screen can create a sample flowchart candidate', (
    tester,
  ) async {
    final repository = MemoryFlowchartValidationRepository(
      zeroReason: FlowchartZeroReason.noDetectedFlowcharts,
    );

    await tester.pumpWidget(
      MaterialApp(home: FlowchartValidationScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mintafolyamat létrehozása'));
    await tester.pumpAndSettle();

    expect(find.text('Flowchart 1. oldal'), findsOneWidget);
    expect(
      DebugConsole.allText,
      contains('[Flowchart] debug sample created flowchart=debug-flowchart'),
    );
  });
}

class MemoryFlowchartValidationRepository
    implements FlowchartValidationRepository, DebugFlowchartSeedRepository {
  MemoryFlowchartValidationRepository({this.zeroReason});

  final _flowcharts = <FlowchartEntity>[];
  final _nodes = <String, ValidationState>{};
  final _nodeEntities = <FlowchartNodeEntity>[];
  final _edgeEntities = <FlowchartEdgeEntity>[];
  final _nodeRejectionReasons = <String, String?>{};
  final FlowchartZeroReason? zeroReason;

  void addNode(String nodePublicId, ValidationState state) {
    _nodes[nodePublicId] = state;
  }

  @override
  Future<List<FlowchartEntity>> listFlowchartsNeedingReview() async {
    return _flowcharts;
  }

  @override
  Future<FlowchartReviewList> listFlowchartReviewState() async {
    return FlowchartReviewList(
      items: _flowcharts,
      zeroReason: _flowcharts.isEmpty ? zeroReason : null,
    );
  }

  @override
  Future<List<FlowchartNodeEntity>> listNodes(String flowchartPublicId) async {
    return _nodeEntities
        .where((node) => node.flowchartPublicId == flowchartPublicId)
        .toList(growable: false);
  }

  @override
  Future<List<FlowchartEdgeEntity>> listEdges(String flowchartPublicId) async {
    return _edgeEntities
        .where((edge) => edge.flowchartPublicId == flowchartPublicId)
        .toList(growable: false);
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

  @override
  Future<void> createDebugFlowchartCandidate() async {
    const flowchartId = 'debug-flowchart';
    _flowcharts
      ..clear()
      ..add(
        FlowchartEntity(
          publicId: flowchartId,
          documentPublicId: 'debug-document',
          pageNumber: 1,
          validationState: ValidationState.unreviewed.wireName,
          extractionConfidence: 1,
        ),
      );
    _nodeEntities
      ..clear()
      ..addAll([
        FlowchartNodeEntity(
          publicId: '$flowchartId:start',
          flowchartPublicId: flowchartId,
          label: 'Betegvizsgálat',
          validationState: ValidationState.unreviewed.wireName,
          positionX: 0,
          positionY: 0,
        ),
        FlowchartNodeEntity(
          publicId: '$flowchartId:end',
          flowchartPublicId: flowchartId,
          label: 'Ellátási döntés',
          validationState: ValidationState.unreviewed.wireName,
          positionX: 160,
          positionY: 0,
        ),
      ]);
    _edgeEntities
      ..clear()
      ..add(
        FlowchartEdgeEntity(
          publicId: '$flowchartId:edge-1',
          flowchartPublicId: flowchartId,
          fromNodePublicId: '$flowchartId:start',
          toNodePublicId: '$flowchartId:end',
          label: 'igen',
          validationState: ValidationState.unreviewed.wireName,
        ),
      );
    DebugConsole.log('[Flowchart] debug sample created flowchart=$flowchartId');
  }
}
