import 'package:flutter/material.dart';

import '../../debug/debug_console.dart';
import '../../local_store/entities.dart';
import '../models/flowchart_view_model.dart';

typedef NodeValidationChanged =
    Future<void> Function({
      required String nodePublicId,
      required ValidationState state,
      String? rejectionReason,
    });

typedef EdgeValidationChanged =
    Future<void> Function({
      required String edgePublicId,
      required ValidationState state,
      String? rejectionReason,
    });

class SimpleFlowchartEditor extends StatelessWidget {
  const SimpleFlowchartEditor({
    super.key,
    required this.model,
    this.onNodeValidation,
    this.onEdgeValidation,
  });

  final FlowchartViewModel model;
  final NodeValidationChanged? onNodeValidation;
  final EdgeValidationChanged? onEdgeValidation;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text('Csomópontok', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final node in model.nodes)
          _NodeValidationRow(node: node, onChanged: onNodeValidation),
        const SizedBox(height: 20),
        Text('Élek', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final edge in model.edges)
          _EdgeValidationRow(edge: edge, onChanged: onEdgeValidation),
      ],
    );
  }
}

class _NodeValidationRow extends StatelessWidget {
  const _NodeValidationRow({required this.node, required this.onChanged});

  final FlowchartNodeViewModel node;
  final NodeValidationChanged? onChanged;

  @override
  Widget build(BuildContext context) {
    return _ValidationCard(
      title: 'Node',
      initialValue: node.label,
      validationState: node.validationState,
      onValidate: () {
        DebugConsole.log(
          '[Flowchart] node validation requested node=${node.id} state=validated',
        );
        onChanged?.call(
          nodePublicId: node.id,
          state: ValidationState.validated,
        );
      },
      onReject: () {
        DebugConsole.log(
          '[Flowchart] node validation requested node=${node.id} state=rejected',
        );
        onChanged?.call(
          nodePublicId: node.id,
          state: ValidationState.rejected,
          rejectionReason: 'Kézi elutasítás',
        );
      },
    );
  }
}

class _EdgeValidationRow extends StatelessWidget {
  const _EdgeValidationRow({required this.edge, required this.onChanged});

  final FlowchartEdgeViewModel edge;
  final EdgeValidationChanged? onChanged;

  @override
  Widget build(BuildContext context) {
    return _ValidationCard(
      title: '${edge.fromNodeId} → ${edge.toNodeId}',
      initialValue: edge.label,
      validationState: edge.validationState,
      onValidate: () {
        DebugConsole.log(
          '[Flowchart] edge validation requested edge=${edge.id} state=validated',
        );
        onChanged?.call(
          edgePublicId: edge.id,
          state: ValidationState.validated,
        );
      },
      onReject: () {
        DebugConsole.log(
          '[Flowchart] edge validation requested edge=${edge.id} state=rejected',
        );
        onChanged?.call(
          edgePublicId: edge.id,
          state: ValidationState.rejected,
          rejectionReason: 'Kézi elutasítás',
        );
      },
    );
  }
}

class _ValidationCard extends StatelessWidget {
  const _ValidationCard({
    required this.title,
    required this.initialValue,
    required this.validationState,
    required this.onValidate,
    required this.onReject,
  });

  final String title;
  final String initialValue;
  final ValidationState validationState;
  final VoidCallback? onValidate;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: initialValue,
              decoration: const InputDecoration(
                labelText: 'Felismert szöveg',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Elutasítás oka',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: onValidate,
                  child: const Text('Validálás'),
                ),
                OutlinedButton(
                  onPressed: onReject,
                  child: const Text('Elutasítás'),
                ),
                Chip(label: Text(_validationLabel(validationState))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _validationLabel(ValidationState state) {
    return switch (state) {
      ValidationState.unreviewed => 'Nem ellenőrzött',
      ValidationState.partiallyValidated => 'Részben validált',
      ValidationState.validated => 'Validált',
      ValidationState.rejected => 'Elutasított',
    };
  }
}
