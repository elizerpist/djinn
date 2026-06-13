import 'package:flutter/material.dart';

class FlowchartBuilderNodeSpec {
  const FlowchartBuilderNodeSpec({
    required this.id,
    required this.title,
    required this.kind,
    required this.laneLabel,
  });

  final String id;
  final String title;
  final String kind;
  final String laneLabel;
}

class FlowchartBuilderTemplate {
  const FlowchartBuilderTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.nodes,
  });

  final String id;
  final String title;
  final String description;
  final List<FlowchartBuilderNodeSpec> nodes;
}

class FlowchartBuilderTemplates {
  static const decision = FlowchartBuilderTemplate(
    id: 'decision-two-branches',
    title: 'Döntés két ággal',
    description: 'Döntés -> IGEN/NEM ág -> folyamatlépés',
    nodes: [
      FlowchartBuilderNodeSpec(
        id: 'tpl-decision-start',
        title: 'Kezdés',
        kind: 'start_end',
        laneLabel: 'Start',
      ),
      FlowchartBuilderNodeSpec(
        id: 'tpl-decision-question',
        title: 'Döntés?',
        kind: 'decision',
        laneLabel: 'IGEN / NEM',
      ),
      FlowchartBuilderNodeSpec(
        id: 'tpl-decision-action',
        title: 'Következő lépés',
        kind: 'process',
        laneLabel: 'Utána',
      ),
    ],
  );

  static const clinical = FlowchartBuilderTemplate(
    id: 'clinical-protocol',
    title: 'Klinikai protokoll',
    description: 'Start -> triázs -> döntések -> záró lépés',
    nodes: [
      FlowchartBuilderNodeSpec(
        id: 'tpl-clinical-start',
        title: 'Kezdés',
        kind: 'start_end',
        laneLabel: 'Start',
      ),
      FlowchartBuilderNodeSpec(
        id: 'tpl-clinical-triage',
        title: 'Triázs',
        kind: 'process',
        laneLabel: 'Utána',
      ),
      FlowchartBuilderNodeSpec(
        id: 'tpl-clinical-decision',
        title: 'Beavatkozás szükséges?',
        kind: 'decision',
        laneLabel: 'IGEN / NEM',
      ),
      FlowchartBuilderNodeSpec(
        id: 'tpl-clinical-close',
        title: 'Dokumentálás és átadás',
        kind: 'process',
        laneLabel: 'Utána',
      ),
    ],
  );

  static const checklist = FlowchartBuilderTemplate(
    id: 'checklist',
    title: 'Ellenőrző lista',
    description: 'Sorban végrehajtott folyamatlépések',
    nodes: [
      FlowchartBuilderNodeSpec(
        id: 'tpl-check-start',
        title: 'Kezdés',
        kind: 'start_end',
        laneLabel: 'Start',
      ),
      FlowchartBuilderNodeSpec(
        id: 'tpl-check-step-1',
        title: 'Első ellenőrzés',
        kind: 'process',
        laneLabel: 'Utána',
      ),
      FlowchartBuilderNodeSpec(
        id: 'tpl-check-step-2',
        title: 'Második ellenőrzés',
        kind: 'process',
        laneLabel: 'Utána',
      ),
    ],
  );

  static const all = [decision, clinical, checklist];
}

class FlowchartBuilderScreen extends StatefulWidget {
  const FlowchartBuilderScreen({super.key, this.template});

  final FlowchartBuilderTemplate? template;

  @override
  State<FlowchartBuilderScreen> createState() => _FlowchartBuilderScreenState();
}

class _FlowchartBuilderScreenState extends State<FlowchartBuilderScreen> {
  final List<_BuilderNode> _nodes = [];
  String _selectedNodeId = 'start';
  int _nextNodeSerial = 1;

  @override
  void initState() {
    super.initState();
    _loadTemplate(widget.template);
  }

  @override
  void didUpdateWidget(covariant FlowchartBuilderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.template?.id != widget.template?.id) {
      _loadTemplate(widget.template);
    }
  }

  void _loadTemplate(FlowchartBuilderTemplate? template) {
    _nodes
      ..clear()
      ..addAll(_nodesForTemplate(template));
    _selectedNodeId = _nodes.first.id;
    _nextNodeSerial = 1;
  }

  List<_BuilderNode> _nodesForTemplate(FlowchartBuilderTemplate? template) {
    final specs = template?.nodes;
    if (specs == null || specs.isEmpty) {
      return const [
        _BuilderNode(
          id: 'start',
          title: 'Kezdés',
          kind: _BuilderNodeKind.startEnd,
          laneLabel: 'Start',
        ),
      ];
    }
    return [
      for (final spec in specs)
        _BuilderNode(
          id: spec.id,
          title: spec.title,
          kind: _builderNodeKindFromWireName(spec.kind),
          laneLabel: spec.laneLabel,
        ),
    ];
  }

  String _newNodeId() {
    while (_nodes.any((node) => node.id == 'node-$_nextNodeSerial')) {
      _nextNodeSerial += 1;
    }
    final id = 'node-$_nextNodeSerial';
    _nextNodeSerial += 1;
    return id;
  }

  _BuilderNode get _selectedNode => _nodes.firstWhere(
    (node) => node.id == _selectedNodeId,
    orElse: () => _nodes.first,
  );

  void _addNode(_BuilderNodeKind kind) {
    final label = switch (kind) {
      _BuilderNodeKind.decision => 'Új döntés',
      _BuilderNodeKind.process => 'Új folyamatlépés',
      _BuilderNodeKind.inputOutput => 'Új bemenet/kimenet',
      _BuilderNodeKind.subprocess => 'Új alfolyamat',
      _BuilderNodeKind.startEnd => 'Vége',
    };
    final node = _BuilderNode(
      id: _newNodeId(),
      title: label,
      kind: kind,
      laneLabel: kind == _BuilderNodeKind.decision ? 'IGEN / NEM' : 'Utána',
    );
    setState(() {
      _nodes.add(node);
      _selectedNodeId = node.id;
    });
    Navigator.of(context).maybePop();
  }

  void _renameSelectedNode(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return;
    }
    setState(() {
      final index = _nodes.indexWhere((node) => node.id == _selectedNodeId);
      if (index == -1) {
        return;
      }
      final current = _nodes[index];
      _nodes[index] = _BuilderNode(
        id: current.id,
        title: trimmed,
        kind: current.kind,
        laneLabel: current.laneLabel,
      );
    });
  }

  void _duplicateSelectedNode() {
    final selected = _selectedNode;
    final node = _BuilderNode(
      id: _newNodeId(),
      title: '${selected.title} másolat',
      kind: selected.kind,
      laneLabel: selected.laneLabel,
    );
    setState(() {
      _nodes.add(node);
      _selectedNodeId = node.id;
    });
  }

  void _deleteSelectedNode() {
    if (_nodes.length <= 1) {
      return;
    }
    setState(() {
      _nodes.removeWhere((node) => node.id == _selectedNodeId);
      _selectedNodeId = _nodes.first.id;
    });
  }

  void _resetBuilder() {
    setState(() => _loadTemplate(widget.template));
  }

  void _openPalette() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          key: const ValueKey('flowchart-builder-palette'),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Elem hozzáadása',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PaletteChip(
                    label: 'Döntés',
                    icon: Icons.change_history,
                    onTap: () => _addNode(_BuilderNodeKind.decision),
                  ),
                  _PaletteChip(
                    label: 'Folyamat',
                    icon: Icons.crop_square,
                    onTap: () => _addNode(_BuilderNodeKind.process),
                  ),
                  _PaletteChip(
                    label: 'Bemenet/Kimenet',
                    icon: Icons.input,
                    onTap: () => _addNode(_BuilderNodeKind.inputOutput),
                  ),
                  _PaletteChip(
                    label: 'Alfolyamat',
                    icon: Icons.view_agenda_outlined,
                    onTap: () => _addNode(_BuilderNodeKind.subprocess),
                  ),
                  _PaletteChip(
                    label: 'Kezdés/Vége',
                    icon: Icons.play_circle_outline,
                    onTap: () => _addNode(_BuilderNodeKind.startEnd),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            _BuilderToolbar(
              selectedNode: _selectedNode,
              canDelete: _nodes.length > 1,
              onDuplicate: _duplicateSelectedNode,
              onDelete: _deleteSelectedNode,
              onReset: _resetBuilder,
            ),
            Expanded(
              child: Container(
                key: const ValueKey('flowchart-builder-canvas'),
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: CustomPaint(
                  painter: _GridPainter(),
                  child: ListView.separated(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: const EdgeInsets.all(16),
                    itemCount: _nodes.length,
                    separatorBuilder: (_, _) => const _BuilderArrow(label: 'Utána'),
                    itemBuilder: (context, index) {
                      final node = _nodes[index];
                      return _BuilderNodeCard(
                        node: node,
                        selected: node.id == _selectedNodeId,
                        onTap: () => setState(() => _selectedNodeId = node.id),
                      );
                    },
                  ),
                ),
              ),
            ),
            _BuilderPropertySheet(
              node: _selectedNode,
              onRename: _renameSelectedNode,
            ),
          ],
        ),
        Positioned(
          right: 20,
          bottom: 104,
          child: FloatingActionButton.small(
            key: const ValueKey('flowchart-builder-add'),
            tooltip: 'Elem hozzáadása',
            onPressed: _openPalette,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

class _BuilderToolbar extends StatelessWidget {
  const _BuilderToolbar({
    required this.selectedNode,
    required this.canDelete,
    required this.onDuplicate,
    required this.onDelete,
    required this.onReset,
  });

  final _BuilderNode selectedNode;
  final bool canDelete;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('flowchart-builder-toolbar'),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            const Icon(Icons.account_tree_outlined, color: Color(0xFF155EEF)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Flowchart építő',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Duplikálás',
              onPressed: onDuplicate,
              icon: const Icon(Icons.content_copy_outlined),
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              tooltip: 'Törlés',
              onPressed: canDelete ? onDelete : null,
              icon: const Icon(Icons.delete_outline),
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              tooltip: 'Újrakezdés',
              onPressed: onReset,
              icon: const Icon(Icons.refresh),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

class _BuilderNodeCard extends StatelessWidget {
  const _BuilderNodeCard({
    required this.node,
    required this.selected,
    required this.onTap,
  });

  final _BuilderNode node;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      key: ValueKey('flowchart-builder-node-${node.id}'),
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Material(
          color: selected ? const Color(0xFFEFF6FF) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: selected ? const Color(0xFF155EEF) : const Color(0xFFE5E7EB),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(_iconFor(node.kind), color: const Color(0xFF111827)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _labelFor(node.kind),
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          node.title,
                          style: const TextStyle(
                            color: Color(0xFF111827),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (node.kind == _BuilderNodeKind.decision) ...[
                    const _DecisionBadge(label: 'IGEN'),
                    const SizedBox(width: 4),
                    const _DecisionBadge(label: 'NEM'),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BuilderArrow extends StatelessWidget {
  const _BuilderArrow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_downward, size: 18, color: Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }
}

class _BuilderPropertySheet extends StatelessWidget {
  const _BuilderPropertySheet({required this.node, required this.onRename});

  final _BuilderNode node;
  final ValueChanged<String> onRename;

  Future<void> _editTitle(BuildContext context) async {
    final controller = TextEditingController(text: node.title);
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elem átnevezése'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Elem neve',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Mégse'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Mentés'),
          ),
        ],
      ),
    );
    if (title != null) {
      onRename(title);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('flowchart-builder-properties'),
      color: Colors.white,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Row(
          children: [
            Icon(_iconFor(node.kind), color: const Color(0xFF155EEF)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    node.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Kapcsolódás: ${node.laneLabel}',
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => _editTitle(context),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Szerkesztés'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaletteChip extends StatelessWidget {
  const _PaletteChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}

class _DecisionBadge extends StatelessWidget {
  const _DecisionBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 0.6;
    const gap = 24.0;
    for (var x = 0.0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

enum _BuilderNodeKind { startEnd, process, decision, inputOutput, subprocess }

_BuilderNodeKind _builderNodeKindFromWireName(String value) {
  return switch (value) {
    'decision' => _BuilderNodeKind.decision,
    'input_output' => _BuilderNodeKind.inputOutput,
    'subprocess' => _BuilderNodeKind.subprocess,
    'start_end' => _BuilderNodeKind.startEnd,
    _ => _BuilderNodeKind.process,
  };
}

class _BuilderNode {
  const _BuilderNode({
    required this.id,
    required this.title,
    required this.kind,
    required this.laneLabel,
  });

  final String id;
  final String title;
  final _BuilderNodeKind kind;
  final String laneLabel;
}

IconData _iconFor(_BuilderNodeKind kind) {
  return switch (kind) {
    _BuilderNodeKind.startEnd => Icons.play_circle_outline,
    _BuilderNodeKind.process => Icons.crop_square,
    _BuilderNodeKind.decision => Icons.change_history,
    _BuilderNodeKind.inputOutput => Icons.input,
    _BuilderNodeKind.subprocess => Icons.view_agenda_outlined,
  };
}

String _labelFor(_BuilderNodeKind kind) {
  return switch (kind) {
    _BuilderNodeKind.startEnd => 'Kezdés/Vége',
    _BuilderNodeKind.process => 'Folyamatlépés',
    _BuilderNodeKind.decision => 'Döntés',
    _BuilderNodeKind.inputOutput => 'Bemenet/Kimenet',
    _BuilderNodeKind.subprocess => 'Alfolyamat',
  };
}
