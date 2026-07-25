import 'dart:convert';

import 'package:flutter/material.dart';

import '../../chunks/models/chunk.dart';

enum ChunkExportScope {
  currentChunk('current_chunk', 'Aktuális chunk'),
  selectedChunks('selected_chunks', 'Kijelölt chunkok'),
  currentNote('current_note', 'Aktuális Jegyzet'),
  currentPdf('current_pdf', 'Aktuális PDF-forrás');

  const ChunkExportScope(this.wireName, this.label);

  final String wireName;
  final String label;
}

class ChunkExportSelection {
  const ChunkExportSelection({
    required this.scope,
    required this.includeSourceMetadata,
  });

  final ChunkExportScope scope;
  final bool includeSourceMetadata;
}

Future<ChunkExportSelection?> showChunkExportSheet(
  BuildContext context, {
  required List<ChunkKind> chunks,
  required List<ChunkExportScope> scopes,
  required ChunkExportScope initialScope,
}) {
  assert(scopes.isNotEmpty);
  assert(scopes.contains(initialScope));
  return showModalBottomSheet<ChunkExportSelection>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => ChunkExportSheet(
      chunks: chunks,
      scopes: scopes,
      initialScope: initialScope,
    ),
  );
}

class ChunkExportSheet extends StatefulWidget {
  const ChunkExportSheet({
    super.key,
    required this.chunks,
    required this.scopes,
    required this.initialScope,
  });

  final List<ChunkKind> chunks;
  final List<ChunkExportScope> scopes;
  final ChunkExportScope initialScope;

  @override
  State<ChunkExportSheet> createState() => _ChunkExportSheetState();
}

class _ChunkExportSheetState extends State<ChunkExportSheet> {
  late ChunkExportScope _scope = widget.initialScope;
  bool _includeSourceMetadata = true;
  bool _showPreview = false;

  int _count(ChunkKind kind) {
    return widget.chunks.where((item) => item == kind).length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      key: const ValueKey('chunk-export-sheet'),
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Chunk export',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Adatvesztésmentes Djinn JSON · schema v2',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 20),
              Text(
                'Tartomány',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              RadioGroup<ChunkExportScope>(
                groupValue: _scope,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _scope = value);
                  }
                },
                child: Column(
                  children: [
                    for (final scope in widget.scopes)
                      RadioListTile<ChunkExportScope>(
                        key: ValueKey('chunk-export-scope-${scope.wireName}'),
                        value: scope,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(scope.label),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Kanonikus típusok',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _ChunkKindCount(
                      key: const ValueKey('chunk-export-kind-count-note_chunk'),
                      icon: Icons.article_outlined,
                      label: 'Jegyzetchunk',
                      count: _count(ChunkKind.noteChunk),
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ChunkKindCount(
                      key: const ValueKey(
                        'chunk-export-kind-count-flowchart_chunk',
                      ),
                      icon: Icons.account_tree_outlined,
                      label: 'Flowchart chunk',
                      count: _count(ChunkKind.flowchartChunk),
                      color: const Color(0xFF7C3AED),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                key: const ValueKey('chunk-export-include-source'),
                value: _includeSourceMetadata,
                contentPadding: EdgeInsets.zero,
                title: const Text('Forrásmetaadatok beágyazása'),
                subtitle: const Text(
                  'Forrástípus, hivatkozás, oldal és eredeti szöveg',
                ),
                onChanged: (value) {
                  setState(() => _includeSourceMetadata = value);
                },
              ),
              if (_showPreview) ...[
                const SizedBox(height: 8),
                Container(
                  key: const ValueKey('chunk-export-preview'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    const JsonEncoder.withIndent('  ').convert({
                      'schema_version': 2,
                      'scope': _scope.wireName,
                      'kinds': {
                        ChunkKind.noteChunk.wireName: _count(
                          ChunkKind.noteChunk,
                        ),
                        ChunkKind.flowchartChunk.wireName: _count(
                          ChunkKind.flowchartChunk,
                        ),
                      },
                      'include_source_metadata': _includeSourceMetadata,
                    }),
                    style: const TextStyle(
                      color: Color(0xFFE2E8F0),
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('chunk-export-preview-action'),
                      onPressed: () {
                        setState(() => _showPreview = !_showPreview);
                      },
                      icon: const Icon(Icons.preview_outlined),
                      label: Text(
                        _showPreview ? 'Előnézet bezárása' : 'Előnézet',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey('chunk-export-confirm'),
                      onPressed: widget.chunks.isEmpty
                          ? null
                          : () => Navigator.of(context).pop(
                              ChunkExportSelection(
                                scope: _scope,
                                includeSourceMetadata: _includeSourceMetadata,
                              ),
                            ),
                      icon: const Icon(Icons.ios_share_outlined),
                      label: const Text('Exportálás'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChunkKindCount extends StatelessWidget {
  const _ChunkKindCount({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '$count',
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
