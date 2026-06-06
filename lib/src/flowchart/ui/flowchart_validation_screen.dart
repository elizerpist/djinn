import 'package:flutter/material.dart';

import '../../local_store/entities.dart';
import '../data/flowchart_validation_repository.dart';
import '../models/flowchart_view_model.dart';
import 'simple_flowchart_editor.dart';

class FlowchartValidationScreen extends StatefulWidget {
  const FlowchartValidationScreen({super.key, required this.repository});

  final FlowchartValidationRepository repository;

  @override
  State<FlowchartValidationScreen> createState() =>
      _FlowchartValidationScreenState();
}

class _FlowchartValidationScreenState extends State<FlowchartValidationScreen> {
  List<FlowchartEntity> _flowcharts = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final flowcharts = await widget.repository.listFlowchartsNeedingReview();
    if (!mounted) {
      return;
    }
    setState(() {
      _flowcharts = flowcharts;
      _loading = false;
    });
  }

  Future<void> _openFlowchart(FlowchartEntity flowchart) async {
    final nodes = await widget.repository.listNodes(flowchart.publicId);
    final edges = await widget.repository.listEdges(flowchart.publicId);
    if (!mounted) {
      return;
    }
    final model = FlowchartViewModel(
      id: flowchart.publicId,
      nodes: nodes
          .map(
            (node) => FlowchartNodeViewModel(
              id: node.publicId,
              label: node.label,
              x: node.positionX,
              y: node.positionY,
              validationState: _validationStateFromWire(node.validationState),
              rejectionReason: node.rejectionReason,
            ),
          )
          .toList(growable: false),
      edges: edges
          .map(
            (edge) => FlowchartEdgeViewModel(
              id: edge.publicId,
              fromNodeId: edge.fromNodePublicId,
              toNodeId: edge.toNodePublicId,
              label: edge.label,
              validationState: _validationStateFromWire(edge.validationState),
              rejectionReason: edge.rejectionReason,
            ),
          )
          .toList(growable: false),
    );
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Flowchart validáció')),
          body: SimpleFlowchartEditor(
            model: model,
            onNodeValidation: widget.repository.updateNodeValidation,
            onEdgeValidation: widget.repository.updateEdgeValidation,
          ),
        ),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flowchart validáció')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _flowcharts.isEmpty
          ? const Center(child: Text('Nincs validálandó flowchart'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _flowcharts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final flowchart = _flowcharts[index];
                return ListTile(
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  leading: const Icon(Icons.account_tree),
                  title: Text('Flowchart ${flowchart.pageNumber}. oldal'),
                  subtitle: Text(flowchart.validationState),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openFlowchart(flowchart),
                );
              },
            ),
    );
  }

  ValidationState _validationStateFromWire(String value) {
    for (final state in ValidationState.values) {
      if (state.wireName == value) {
        return state;
      }
    }
    return ValidationState.unreviewed;
  }
}
