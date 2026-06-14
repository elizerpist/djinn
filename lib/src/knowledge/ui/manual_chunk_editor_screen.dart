import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../data/knowledge_document_repository.dart';
import '../data/mlkit_ocr_engine.dart';
import '../data/pdfrx_local_page_extractor.dart';
import '../models/knowledge_document.dart';
import '../models/local_extraction.dart';
import '../../shared/ui/draggable_bottom_card.dart';
import '../../flowchart/ui/manual_flowchart_draft_editor_screen.dart';

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
  final _pdfController = PdfViewerController();
  final _pageController = TextEditingController(text: '1');
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  LocalChunkKind _kind = LocalChunkKind.text;
  String _sourceMode = 'pdf_text';
  int _pageNumber = 1;
  int _pageCount = 0;
  bool _viewerReady = false;
  bool _saving = false;
  bool _loadingSelectionText = false;
  String? _errorText;
  LocalChunkKind? _selectionKind;
  Offset? _dragStart;
  Offset? _dragCurrent;
  Rect? _selectionRect;

  bool get _isPng => widget.document.localPath.toLowerCase().endsWith('.png');
  bool get _cardVisible => _selectionRect != null;

  @override
  void dispose() {
    _pageController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _chooseSelectionType() async {
    final selected = await showModalBottomSheet<LocalChunkKind>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final option in const [
              LocalChunkKind.text,
              LocalChunkKind.list,
              LocalChunkKind.table,
              LocalChunkKind.score,
              LocalChunkKind.flowchart,
              LocalChunkKind.imageRegion,
              LocalChunkKind.visualFact,
            ])
              ListTile(
                leading: Icon(_iconForKind(option)),
                title: Text(option.label),
                subtitle: Text(_selectionHelp(option)),
                onTap: () => Navigator.of(context).pop(option),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) {
      return;
    }
    _beginSelection(selected);
  }

  void _beginSelection(LocalChunkKind kind) {
    setState(() {
      _kind = kind;
      _selectionKind = kind;
      _selectionRect = null;
      _dragStart = null;
      _dragCurrent = null;
      _errorText = null;
      _sourceMode = _sourceModeForKind(kind);
      _titleController.clear();
      _contentController.clear();
      _pageController.text = _pageNumber.toString();
    });
  }

  Future<void> _completeSelection(Rect rect) async {
    if (rect.width < 18 || rect.height < 18 || _selectionKind == null) {
      setState(() {
        _dragStart = null;
        _dragCurrent = null;
      });
      return;
    }
    setState(() {
      _selectionRect = rect;
      _dragStart = null;
      _dragCurrent = null;
      _loadingSelectionText = true;
      _errorText = null;
    });
    try {
      final content = await _prefillSelectionText();
      if (!mounted) {
        return;
      }
      _contentController.text = content;
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = 'A kijelölt rész előtöltése nem sikerült: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _loadingSelectionText = false);
      }
    }
  }

  Future<String> _prefillSelectionText() async {
    if (!File(widget.document.localPath).existsSync()) {
      return '';
    }
    if (_isPng) {
      final engine = MlKitOcrEngine();
      try {
        return (await engine.recognizeImage(widget.document.localPath))
            .text
            .trim();
      } finally {
        await engine.close();
      }
    }
    final pdfText = await _loadCurrentPdfPageText();
    final wantsOcr = _sourceMode != 'pdf_text' || pdfText.trim().isEmpty;
    if (!wantsOcr) {
      return pdfText.trim();
    }
    final engine = MlKitOcrEngine();
    try {
      final pages = await PdfrxLocalPageExtractor(
        ocrEngine: engine,
        renderScale: 2.0,
      ).extractPages(
        documentId: widget.document.id,
        path: widget.document.localPath,
      );
      final page = pages.where((item) => item.pageNumber == _pageNumber);
      if (page.isEmpty) {
        return pdfText.trim();
      }
      return page.first.bestText.trim();
    } finally {
      await engine.close();
    }
  }

  Future<String> _loadCurrentPdfPageText() async {
    final document = await PdfDocument.openFile(widget.document.localPath);
    try {
      for (final page in document.pages) {
        if (page.pageNumber == _pageNumber) {
          return (await page.loadText())?.fullText ?? '';
        }
      }
      return '';
    } finally {
      await document.dispose();
    }
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
        sourceRectJson: _sourceRectJson(page),
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

  String _sourceRectJson(int pageNumber) {
    final rect = _selectionRect;
    return jsonEncode({
      'source': _sourceMode,
      'created_by': 'manual_chunk_editor',
      'page': pageNumber,
      if (rect != null)
        'viewport_rect': {
          'left': rect.left,
          'top': rect.top,
          'right': rect.right,
          'bottom': rect.bottom,
        },
    });
  }

  void _cancelCard() {
    setState(() {
      _selectionKind = null;
      _selectionRect = null;
      _dragStart = null;
      _dragCurrent = null;
      _errorText = null;
      _saving = false;
    });
  }

  Future<void> _openFlowchartDraftEditor() async {
    final pageNumber = int.tryParse(_pageController.text.trim()) ?? _pageNumber;
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ManualFlowchartDraftEditorScreen(
          initialText: _contentController.text,
          documentId: widget.document.id,
          pageNumber: pageNumber,
        ),
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    setState(() {
      _kind = LocalChunkKind.flowchart;
      _sourceMode = 'flowchart';
      _contentController.text = result;
    });
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _sourceModeForKind(LocalChunkKind kind) {
    return switch (kind) {
      LocalChunkKind.text || LocalChunkKind.list => 'pdf_text',
      LocalChunkKind.table || LocalChunkKind.score => 'table',
      LocalChunkKind.flowchart => 'flowchart',
      LocalChunkKind.imageRegion || LocalChunkKind.visualFact => 'ocr_image',
      LocalChunkKind.unknown => 'pdf_text',
    };
  }

  String _selectionHelp(LocalChunkKind kind) {
    return switch (kind) {
      LocalChunkKind.text => 'Bekezdés vagy rövid szövegrészlet',
      LocalChunkKind.list => 'Felsorolás vagy több soron folytatódó lista',
      LocalChunkKind.table => 'Táblázatrészlet szövegből vagy képből',
      LocalChunkKind.score => 'Score vagy skálaelemek',
      LocalChunkKind.flowchart => 'Folyamatábra részlet',
      LocalChunkKind.imageRegion =>
        'Képes régió OCR vagy későbbi audit számára',
      LocalChunkKind.visualFact =>
        'Képen látható tény, például szín vagy eszköz',
      LocalChunkKind.unknown => 'Bizonytalan típus',
    };
  }

  IconData _iconForKind(LocalChunkKind kind) {
    return switch (kind) {
      LocalChunkKind.text => Icons.notes_outlined,
      LocalChunkKind.list => Icons.format_list_bulleted,
      LocalChunkKind.table => Icons.table_chart_outlined,
      LocalChunkKind.score => Icons.fact_check_outlined,
      LocalChunkKind.flowchart => Icons.account_tree_outlined,
      LocalChunkKind.imageRegion => Icons.crop_free,
      LocalChunkKind.visualFact => Icons.visibility_outlined,
      LocalChunkKind.unknown => Icons.help_outline,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kézi chunkolás')),
      body: Stack(
        children: [
          Positioned.fill(child: _buildViewer(context)),
          if (_selectionKind != null && !_cardVisible)
            Positioned.fill(
              child: _SelectionLayer(
                key: const Key('manual-chunk-selection-layer'),
                start: _dragStart,
                current: _dragCurrent,
                onStart: (position) {
                  setState(() {
                    _dragStart = position;
                    _dragCurrent = position;
                  });
                },
                onUpdate: (position) => setState(() => _dragCurrent = position),
                onEnd: () {
                  final start = _dragStart;
                  final current = _dragCurrent;
                  if (start != null && current != null) {
                    _completeSelection(Rect.fromPoints(start, current));
                  }
                },
              ),
            ),
          if (_selectionKind != null && !_cardVisible)
            const Positioned(
              left: 16,
              right: 16,
              top: 16,
              child: _SelectionBanner(),
            ),
          if (_cardVisible)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DraggableBottomCard(
                onDismiss: _cancelCard,
                child: _ManualChunkCard(
                  kind: _kind,
                  sourceMode: _sourceMode,
                  pageController: _pageController,
                  titleController: _titleController,
                  contentController: _contentController,
                  loading: _loadingSelectionText,
                  saving: _saving,
                  errorText: _errorText,
                  onKindChanged: (value) => setState(() {
                    _kind = value;
                    _sourceMode = _sourceModeForKind(value);
                  }),
                  onSourceModeChanged: (value) => setState(() {
                    _sourceMode = value;
                  }),
                  onCancel: _cancelCard,
                  onEditFlowchart: _openFlowchartDraftEditor,
                  onSave: _save,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _cardVisible
          ? null
          : FloatingActionButton.extended(
              key: const Key('manual-chunk-new-selection'),
              onPressed: _chooseSelectionType,
              icon: const Icon(Icons.crop_free),
              label: const Text('Kijelölés'),
            ),
    );
  }

  Widget _buildViewer(BuildContext context) {
    if (_isPng) {
      return _ManualPngViewer(path: widget.document.localPath);
    }
    return PdfViewer.file(
      widget.document.localPath,
      controller: _pdfController,
      params: PdfViewerParams(
        scrollPhysics: PdfViewerParams.getScrollPhysics(context),
        scrollPhysicsScale: PdfViewerParams.getScrollPhysics(context),
        onViewerReady: (_, controller) {
          if (!mounted) {
            return;
          }
          setState(() {
            _viewerReady = true;
            _pageCount = controller.pageCount;
            _pageNumber = controller.pageNumber ?? 1;
            _pageController.text = _pageNumber.toString();
          });
        },
        onPageChanged: (pageNumber) {
          if (!mounted || pageNumber == null) {
            return;
          }
          setState(() {
            _pageNumber = pageNumber;
            _pageController.text = _pageNumber.toString();
          });
        },
        viewerOverlayBuilder: (context, size, handleLinkTap) => [
          PdfViewerScrollThumb(
            controller: _pdfController,
            orientation: ScrollbarOrientation.right,
          ),
          if (_viewerReady && _pageCount > 1)
            Positioned(
              left: 16,
              right: 16,
              bottom: 84,
              child: _PageCounter(
                pageNumber: _pageNumber,
                pageCount: _pageCount,
              ),
            ),
        ],
      ),
    );
  }
}

class _SelectionLayer extends StatelessWidget {
  const _SelectionLayer({
    super.key,
    required this.start,
    required this.current,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
  });

  final Offset? start;
  final Offset? current;
  final ValueChanged<Offset> onStart;
  final ValueChanged<Offset> onUpdate;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (details) => onStart(details.localPosition),
      onPanUpdate: (details) => onUpdate(details.localPosition),
      onPanEnd: (_) => onEnd(),
      child: CustomPaint(
        painter: _SelectionPainter(start: start, current: current),
      ),
    );
  }
}

class _SelectionPainter extends CustomPainter {
  const _SelectionPainter({required this.start, required this.current});

  final Offset? start;
  final Offset? current;

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.08);
    canvas.drawRect(Offset.zero & size, overlayPaint);
    final startPoint = start;
    final endPoint = current;
    if (startPoint == null || endPoint == null) {
      return;
    }
    final rect = Rect.fromPoints(startPoint, endPoint);
    final fill = Paint()
      ..color = const Color(0xFF2563EB).withValues(alpha: 0.16);
    final stroke = Paint()
      ..color = const Color(0xFF2563EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(rect, fill);
    canvas.drawRect(rect, stroke);
  }

  @override
  bool shouldRepaint(covariant _SelectionPainter oldDelegate) {
    return oldDelegate.start != start || oldDelegate.current != current;
  }
}

class _SelectionBanner extends StatelessWidget {
  const _SelectionBanner();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.68),
      borderRadius: BorderRadius.circular(8),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(
          'Húzz kijelölő téglalapot a PDF-en vagy képen.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _ManualChunkCard extends StatelessWidget {
  const _ManualChunkCard({
    required this.kind,
    required this.sourceMode,
    required this.pageController,
    required this.titleController,
    required this.contentController,
    required this.loading,
    required this.saving,
    required this.errorText,
    required this.onKindChanged,
    required this.onSourceModeChanged,
    required this.onCancel,
    required this.onEditFlowchart,
    required this.onSave,
  });

  final LocalChunkKind kind;
  final String sourceMode;
  final TextEditingController pageController;
  final TextEditingController titleController;
  final TextEditingController contentController;
  final bool loading;
  final bool saving;
  final String? errorText;
  final ValueChanged<LocalChunkKind> onKindChanged;
  final ValueChanged<String> onSourceModeChanged;
  final VoidCallback onCancel;
  final VoidCallback onEditFlowchart;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Material(
        elevation: 14,
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.72,
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                  'Kijelölt chunk mentése',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<LocalChunkKind>(
                  key: const Key('manual-chunk-kind-field'),
                  initialValue: kind,
                  decoration: const InputDecoration(
                    labelText: 'Chunk típusa',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final option in LocalChunkKind.values
                        .where((item) => item != LocalChunkKind.unknown))
                      DropdownMenuItem(value: option, child: Text(option.label)),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      onKindChanged(value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const Key('manual-chunk-source-field'),
                  initialValue: sourceMode,
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
                    DropdownMenuItem(value: 'table', child: Text('Táblázatból')),
                    DropdownMenuItem(value: 'flowchart', child: Text('Flowchartból')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      onSourceModeChanged(value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('manual-chunk-page-field'),
                  controller: pageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Oldal',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('manual-chunk-title-field'),
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Cím / szekció',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                if (kind == LocalChunkKind.flowchart) ...[
                  OutlinedButton.icon(
                    key: const Key('manual-flowchart-open-editor'),
                    onPressed: loading || saving ? null : onEditFlowchart,
                    icon: const Icon(Icons.account_tree_outlined),
                    label: const Text('Interaktív flowchart szerkesztő'),
                  ),
                  const SizedBox(height: 12),
                ],
                Stack(
                  children: [
                    TextField(
                      key: const Key('manual-chunk-content-field'),
                      controller: contentController,
                      minLines: 7,
                      maxLines: 12,
                      decoration: const InputDecoration(
                        labelText: 'Kinyert tartalom',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (loading)
                      const Positioned.fill(
                        child: ColoredBox(
                          color: Color(0x66FFFFFF),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ),
                  ],
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    errorText!,
                    style: const TextStyle(
                      color: Color(0xFFB91C1C),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: saving ? null : onCancel,
                        child: const Text('Mégse'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        key: const Key('manual-chunk-save'),
                        onPressed: saving || loading ? null : onSave,
                        icon: saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save_outlined),
                        label: const Text('Mentés'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PageCounter extends StatelessWidget {
  const _PageCounter({required this.pageNumber, required this.pageCount});

  final int pageNumber;
  final int pageCount;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            '$pageNumber / $pageCount',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _ManualPngViewer extends StatelessWidget {
  const _ManualPngViewer({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF111827),
      alignment: Alignment.center,
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 5,
        child: Image.file(File(path), fit: BoxFit.contain),
      ),
    );
  }
}
