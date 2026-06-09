import 'package:flutter/material.dart';

import '../../debug/debug_console.dart';

class AdminSummary {
  const AdminSummary({
    required this.documentCount,
    required this.chunkCount,
    required this.flowchartCount,
  });

  final int documentCount;
  final int chunkCount;
  final int flowchartCount;
}

class AdminScreen extends StatefulWidget {
  const AdminScreen({
    super.key,
    required this.loadSummary,
    required this.clearKnowledgeBase,
    this.exportTrainingPack,
    this.importTrainingPack,
  });

  final Future<AdminSummary> Function() loadSummary;
  final Future<void> Function() clearKnowledgeBase;
  final Future<String?> Function()? exportTrainingPack;
  final Future<String?> Function()? importTrainingPack;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late Future<AdminSummary> _summary = widget.loadSummary();
  String? _statusText;

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tudástár törlése'),
        content: const Text(
          'A helyi dokumentumok, chunkok és embeddingek törlődnek.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Mégse'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Törlés megerősítése'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await widget.clearKnowledgeBase();
    DebugConsole.log('[Admin] knowledge base cleared');
    if (!mounted) {
      return;
    }
    setState(() {
      _summary = widget.loadSummary();
    });
  }

  Future<void> _exportTrainingPack() async {
    final exportTrainingPack = widget.exportTrainingPack;
    if (exportTrainingPack == null) {
      return;
    }
    final target = await exportTrainingPack();
    if (!mounted || target == null) {
      return;
    }
    DebugConsole.log('[Admin] training pack exported target=$target');
    setState(() => _statusText = 'Export kész: $target');
  }

  Future<void> _importTrainingPack() async {
    final importTrainingPack = widget.importTrainingPack;
    if (importTrainingPack == null) {
      return;
    }
    final source = await importTrainingPack();
    if (!mounted || source == null) {
      return;
    }
    DebugConsole.log('[Admin] training pack imported source=$source');
    setState(() {
      _statusText = 'Import kész: $source';
      _summary = widget.loadSummary();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin')),
      body: FutureBuilder<AdminSummary>(
        future: _summary,
        builder: (context, snapshot) {
          final summary = snapshot.data;
          if (summary == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SummaryTile(label: 'PDF', value: summary.documentCount),
              _SummaryTile(label: 'chunk', value: summary.chunkCount),
              _SummaryTile(label: 'flowchart', value: summary.flowchartCount),
              if (_statusText != null) ...[
                const SizedBox(height: 12),
                Text(
                  _statusText!,
                  style: const TextStyle(
                    color: Color(0xFF166534),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ListTile(
                tileColor: Colors.white,
                leading: const Icon(Icons.archive),
                title: const Text('Training pack export/import'),
                subtitle: const Text('.djinnpack mentés és visszatöltés'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton(
                      onPressed: widget.exportTrainingPack == null
                          ? null
                          : _exportTrainingPack,
                      child: const Text('Export'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: widget.importTrainingPack == null
                          ? null
                          : _importTrainingPack,
                      child: const Text('Import'),
                    ),
                  ],
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _confirmClear,
                icon: const Icon(Icons.delete),
                label: const Text('Tudástár törlése'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      tileColor: Colors.white,
      title: Text('$value $label'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
