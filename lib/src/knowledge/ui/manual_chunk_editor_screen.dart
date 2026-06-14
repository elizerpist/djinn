import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/knowledge_document_repository.dart';
import '../models/knowledge_document.dart';
import '../models/local_extraction.dart';

class ManualChunkEditorScreen extends StatefulWidget {
  const ManualChunkEditorScreen({
    super.key,
    required this.repository,
    required this.document,
  });

  final KnowledgeDocumentRepository repository;
  final KnowledgeDocument document;

  @override
  State<ManualChunkEditorScreen> createState() =>
      _ManualChunkEditorScreenState();
}

class _ManualChunkEditorScreenState extends State<ManualChunkEditorScreen> {
  final _pageController = TextEditingController(text: '1');
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  LocalChunkKind _kind = LocalChunkKind.text;
  String _sourceMode = 'pdf_text';
  bool _saving = false;
  String? _errorText;

  @override
  void dispose() {
    _pageController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      setState(() => _errorText = 'A chunk tartalma nem lehet üres.');
      return;
    }
    final page = int.tryParse(_pageController.text.trim());
    if (page == null || page < 1) {
      setState(() => _errorText = 'Az oldalszám legalább 1 legyen.');
      return;
    }
    setState(() {
      _saving = true;
      _errorText = null;
    });
    try {
      final now = DateTime.now().microsecondsSinceEpoch;
      final chunk = LocalChunk(
        id: 'manual-$now',
        documentId: widget.document.id,
        text: content,
        pageNumber: page,
        sectionTitle: _emptyToNull(_titleController.text),
        pipeline: LocalExtractionPipeline.manual,
        kind: _kind,
        auditState: LocalAuditState.edited,
        sourceRectJson: jsonEncode({
          'source': _sourceMode,
          'created_by': 'manual_chunk_editor',
        }),
        confidence: 1,
      );
      await widget.repository.saveLocalChunks(
        widget.document.id,
        [chunk],
        replaceExisting: false,
      );
      if (!widget.document.status.isReady) {
        await widget.repository.updateStatus(
          widget.document.id,
          KnowledgeDocumentStatus.needsReview,
          activeProvider: 'manual',
          activeModel: 'manual_chunk_editor',
          clearLastErrorCode: true,
        );
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _errorText = 'A kézi chunk mentése nem sikerült: $error';
      });
    }
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Kézi chunkolás')),
      body: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _DocumentCard(document: widget.document),
          const SizedBox(height: 12),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Új kézi tudáselem',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<LocalChunkKind>(
                    key: const Key('manual-chunk-kind-field'),
                    initialValue: _kind,
                    decoration: const InputDecoration(
                      labelText: 'Chunk típusa',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: LocalChunkKind.text,
                        child: Text('Szöveg'),
                      ),
                      DropdownMenuItem(
                        value: LocalChunkKind.list,
                        child: Text('Felsorolás'),
                      ),
                      DropdownMenuItem(
                        value: LocalChunkKind.table,
                        child: Text('Táblázat'),
                      ),
                      DropdownMenuItem(
                        value: LocalChunkKind.score,
                        child: Text('Score'),
                      ),
                      DropdownMenuItem(
                        value: LocalChunkKind.flowchart,
                        child: Text('Flowchart lépés'),
                      ),
                      DropdownMenuItem(
                        value: LocalChunkKind.imageRegion,
                        child: Text('Képterület'),
                      ),
                      DropdownMenuItem(
                        value: LocalChunkKind.visualFact,
                        child: Text('Képi tény'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _kind = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: const Key('manual-chunk-source-field'),
                    initialValue: _sourceMode,
                    decoration: const InputDecoration(
                      labelText: 'Forrás',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'pdf_text',
                        child: Text('PDF szövegrétegből'),
                      ),
                      DropdownMenuItem(
                        value: 'ocr_image',
                        child: Text('Képből / OCR-ból'),
                      ),
                      DropdownMenuItem(
                        value: 'table',
                        child: Text('Táblázatból'),
                      ),
                      DropdownMenuItem(
                        value: 'flowchart',
                        child: Text('Flowchartból'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _sourceMode = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('manual-chunk-page-field'),
                    controller: _pageController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Oldal',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('manual-chunk-title-field'),
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Cím / szekció',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('manual-chunk-content-field'),
                    controller: _contentController,
                    minLines: 8,
                    maxLines: 14,
                    decoration: const InputDecoration(
                      labelText: 'Kinyert tartalom',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _errorText!,
                      style: const TextStyle(
                        color: Color(0xFFB91C1C),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    key: const Key('manual-chunk-save'),
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Mentés'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({required this.document});

  final KnowledgeDocument document;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              document.filename.toLowerCase().endsWith('.png')
                  ? Icons.image_outlined
                  : Icons.picture_as_pdf,
              color: const Color(0xFF2563EB),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.filename,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'A mentett kézi chunk a kinyert tartalmak között jelenik meg.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
