import 'package:flutter/material.dart';

import '../../knowledge/models/local_extraction.dart';
import 'chunk_validation_controller.dart';

class ChunkValidationCard extends StatefulWidget {
  const ChunkValidationCard({
    super.key,
    required this.title,
    required this.initialText,
    required this.initialAuditState,
    this.initialReason,
    required this.onCancel,
    required this.onSave,
  });

  final String title;
  final String initialText;
  final LocalAuditState initialAuditState;
  final String? initialReason;
  final VoidCallback onCancel;
  final ValueChanged<ChunkValidationResult> onSave;

  @override
  State<ChunkValidationCard> createState() => _ChunkValidationCardState();
}

class _ChunkValidationCardState extends State<ChunkValidationCard> {
  late final TextEditingController _textController;
  late final TextEditingController _reasonController;
  late ChunkValidationChoice _choice;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText);
    _reasonController = TextEditingController(text: widget.initialReason ?? '');
    _choice = ChunkValidationChoiceMapping.fromAuditState(
      widget.initialAuditState,
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _save() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      return;
    }
    final reason = _reasonController.text.trim();
    widget.onSave(
      ChunkValidationResult(
        auditState: _choice.auditState,
        text: text,
        reason: reason.isEmpty ? null : reason,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Material(
        key: const ValueKey('chunk-validation-card'),
        elevation: 18,
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.82,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1D5DB),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<ChunkValidationChoice>(
                        key: const ValueKey('chunk-validation-status-selector'),
                        segments: [
                          for (final choice in ChunkValidationChoice.values)
                            ButtonSegment(
                              value: choice,
                              label: Text(choice.label),
                            ),
                        ],
                        selected: {_choice},
                        onSelectionChanged: (selection) {
                          setState(() => _choice = selection.single);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const ValueKey('chunk-validation-text-field'),
                        controller: _textController,
                        minLines: 7,
                        maxLines: 14,
                        decoration: const InputDecoration(
                          labelText: 'Kinyert tartalom',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const ValueKey('chunk-validation-reason-field'),
                        controller: _reasonController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Indoklás / megjegyzés',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onCancel,
                        child: const Text('Mégse'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        key: const ValueKey('chunk-validation-save'),
                        onPressed: _save,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Mentés'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
