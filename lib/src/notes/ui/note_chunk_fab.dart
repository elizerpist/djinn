import 'package:flutter/material.dart';

class NoteChunkFab extends StatefulWidget {
  const NoteChunkFab({
    super.key,
    required this.onAddText,
    required this.onAddList,
    required this.onAddTable,
    required this.onAddFlowchart,
  });

  final VoidCallback onAddText;
  final VoidCallback onAddList;
  final VoidCallback onAddTable;
  final VoidCallback onAddFlowchart;

  @override
  State<NoteChunkFab> createState() => _NoteChunkFabState();
}

class _NoteChunkFabState extends State<NoteChunkFab> {
  bool _expanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  void _run(VoidCallback callback) {
    setState(() => _expanded = false);
    callback();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_expanded) ...[
          _MiniFab(
            key: const ValueKey('note-editor-add-flowchart'),
            tooltip: 'Flowchart chunk hozzáadása',
            icon: Icons.account_tree_outlined,
            onPressed: () => _run(widget.onAddFlowchart),
          ),
          const SizedBox(height: 10),
          _MiniFab(
            key: const ValueKey('note-editor-add-table'),
            tooltip: 'Táblázat chunk hozzáadása',
            icon: Icons.table_chart_outlined,
            onPressed: () => _run(widget.onAddTable),
          ),
          const SizedBox(height: 10),
          _MiniFab(
            key: const ValueKey('note-editor-add-list'),
            tooltip: 'Lista chunk hozzáadása',
            icon: Icons.checklist_outlined,
            onPressed: () => _run(widget.onAddList),
          ),
          const SizedBox(height: 10),
          _MiniFab(
            key: const ValueKey('note-editor-add-text'),
            tooltip: 'Szöveg chunk hozzáadása',
            icon: Icons.notes_outlined,
            onPressed: () => _run(widget.onAddText),
          ),
          const SizedBox(height: 12),
        ],
        FloatingActionButton(
          key: const ValueKey('note-editor-add-fab'),
          tooltip: _expanded ? 'Chunk menü bezárása' : 'Chunk hozzáadása',
          onPressed: _toggle,
          child: AnimatedRotation(
            turns: _expanded ? 0.125 : 0,
            duration: const Duration(milliseconds: 140),
            child: Icon(_expanded ? Icons.close : Icons.add),
          ),
        ),
      ],
    );
  }
}

class _MiniFab extends StatelessWidget {
  const _MiniFab({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: null,
      tooltip: tooltip,
      onPressed: onPressed,
      child: Icon(icon),
    );
  }
}
