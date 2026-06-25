import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../debug/debug_console.dart';
import '../data/knowledge_document_repository.dart';
import '../data/mlkit_ocr_engine.dart';
import '../data/pdfrx_local_page_extractor.dart';
import '../models/extracted_knowledge_item.dart';
import '../models/knowledge_document.dart';
import '../models/local_extraction.dart';
import '../../shared/ui/inline_bottom_sheet_card.dart';
import '../../flowchart/ui/manual_flowchart_draft_editor_screen.dart';
import 'source_chunk_box_overlay.dart';

const _manualChunkKinds = [
  LocalChunkKind.text,
  LocalChunkKind.list,
  LocalChunkKind.table,
  LocalChunkKind.flowchart,
];

IconData _staticIconForKind(LocalChunkKind kind) {
  return switch (kind) {
    LocalChunkKind.text => Icons.notes_outlined,
    LocalChunkKind.list => Icons.format_list_bulleted,
    LocalChunkKind.table => Icons.table_chart_outlined,
    LocalChunkKind.flowchart => Icons.account_tree_outlined,
  };
}

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
  List<ExtractedKnowledgeItem> _sourceItems = const [];
  SourceChunkBoxMode _boxMode = SourceChunkBoxMode.hidden;
  int _tableRows = 2;
  int _tableColumns = 2;

  bool get _isPng => widget.document.localPath.toLowerCase().endsWith('.png');
  bool get _cardVisible => _selectionRect != null;

  @override
  void initState() {
    super.initState();
    _log(
      'open document=${widget.document.id} filename=${widget.document.filename} '
      'path=${widget.document.localPath} isPng=$_isPng',
    );
    _reloadSourceItems();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _log(String message) {
    DebugConsole.log('[ManualChunk] $message');
  }

  Future<void> _chooseSelectionType() async {
    _log('type sheet open page=$_pageNumber');
    final selected = await showModalBottomSheet<LocalChunkKind>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final option in _manualChunkKinds)
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
      _log('type sheet cancelled');
      return;
    }
    _beginSelection(selected);
  }

  void _beginSelection(LocalChunkKind kind) {
    final sourceMode = _sourceModeForKind(kind);
    setState(() {
      _kind = kind;
      _selectionKind = kind;
      _selectionRect = null;
      _dragStart = null;
      _dragCurrent = null;
      _errorText = null;
      _sourceMode = sourceMode;
      _titleController.clear();
      _contentController.clear();
      _pageController.text = _pageNumber.toString();
      _tableRows = 2;
      _tableColumns = 2;
    });
    _log('selection type selected kind=${kind.wireName} source=$sourceMode');
  }

  Future<void> _completeSelection(Rect rect) async {
    if (rect.width < 18 || rect.height < 18 || _selectionKind == null) {
      _log(
        'selection ignored reason=too_small_or_missing_kind '
        'rect=${_formatRect(rect)} kind=${_selectionKind?.wireName ?? 'null'}',
      );
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
    _log(
      'selection complete kind=${_selectionKind!.wireName} '
      'rect=${_formatRect(rect)} page=$_pageNumber source=$_sourceMode',
    );
    try {
      final content = await _prefillSelectionText();
      if (!mounted) {
        return;
      }
      final normalizedContent = content.trim().isEmpty
          ? _defaultDraftForKind(_selectionKind!)
          : content;
      _contentController.text = normalizedContent;
      _log('prefill complete chars=${normalizedContent.length}');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _log('prefill failed error=$error');
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
      _log('prefill skipped missing_file path=${widget.document.localPath}');
      return '';
    }
    if (_isPng) {
      _log('prefill start source=png_ocr path=${widget.document.localPath}');
      final engine = MlKitOcrEngine();
      try {
        return (await engine.recognizeImage(
          widget.document.localPath,
        )).text.trim();
      } finally {
        await engine.close();
      }
    }
    _log('prefill start source=pdf_text page=$_pageNumber');
    final pdfText = await _loadCurrentPdfPageText();
    final wantsOcr = _sourceMode != 'pdf_text' || pdfText.trim().isEmpty;
    if (!wantsOcr) {
      _log('prefill using pdf_text chars=${pdfText.trim().length}');
      return pdfText.trim();
    }
    _log(
      'prefill fallback ocr reason=${pdfText.trim().isEmpty ? 'empty_pdf_text' : 'source_mode_ocr'} '
      'source=$_sourceMode',
    );
    final engine = MlKitOcrEngine();
    try {
      final pages =
          await PdfrxLocalPageExtractor(
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
    _log('pdf text open path=${widget.document.localPath} page=$_pageNumber');
    final document = await PdfDocument.openFile(widget.document.localPath);
    try {
      for (final page in document.pages) {
        if (page.pageNumber == _pageNumber) {
          final text = (await page.loadText())?.fullText ?? '';
          _log('pdf text loaded page=$_pageNumber chars=${text.length}');
          return text;
        }
      }
      _log('pdf text page missing page=$_pageNumber');
      return '';
    } finally {
      await document.dispose();
    }
  }

  Future<void> _save() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      _log('save rejected reason=empty_content kind=${_kind.wireName}');
      setState(() => _errorText = 'A chunk tartalma nem lehet üres.');
      return;
    }
    final page = _pageNumber < 1 ? 1 : _pageNumber;
    _log(
      'save start document=${widget.document.id} kind=${_kind.wireName} '
      'page=$page chars=${content.length} source=$_sourceMode rect=${_formatRect(_selectionRect)}',
    );
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
      await widget.repository.saveLocalChunks(widget.document.id, [
        chunk,
      ], replaceExisting: false);
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
      final items = await widget.repository.listExtractedKnowledgeItems(
        widget.document.id,
      );
      final manualCount = items
          .where((item) => item.pipeline != LocalExtractionPipeline.ai)
          .length;
      if (!mounted) {
        return;
      }
      _log(
        'save complete document=${widget.document.id} kind=${_kind.wireName} '
        'chunk=${chunk.id} manualCount=$manualCount',
      );
      await _reloadSourceItems();
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _selectionKind = null;
        _selectionRect = null;
        _dragStart = null;
        _dragCurrent = null;
        _errorText = null;
        _boxMode = SourceChunkBoxMode.manual;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      _log('save failed error=$error');
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
      if (_kind == LocalChunkKind.table)
        'table': {'rows': _tableRows, 'columns': _tableColumns},
    });
  }

  String _defaultDraftForKind(LocalChunkKind kind) {
    return switch (kind) {
      LocalChunkKind.table => _tableTemplate(),
      LocalChunkKind.flowchart => _flowchartTemplate(),
      _ => '',
    };
  }

  String _tableTemplate() {
    final header = List.generate(
      _tableColumns,
      (index) => 'Oszlop ${index + 1}',
    );
    final separator = List.filled(_tableColumns, '---');
    final rows = [
      header,
      separator,
      for (var row = 0; row < _tableRows; row += 1)
        List.generate(
          _tableColumns,
          (column) => 'cella ${row + 1}.${column + 1}',
        ),
    ];
    return rows.map((row) => '| ${row.join(' | ')} |').join('\n');
  }

  String _flowchartTemplate() {
    return [
      '[flowchart]',
      'node draft-node-1 | start_end | Kezdés',
      'node draft-node-2 | process | OCR alapján javítandó elem',
      'edge Kezdés -> OCR alapján javítandó elem',
    ].join('\n');
  }

  void _applyTableAction(String action) {
    setState(() {
      _kind = LocalChunkKind.table;
      _sourceMode = 'table';
      switch (action) {
        case 'add_row':
          _tableRows += 1;
          break;
        case 'add_column':
          _tableColumns += 1;
          break;
        case 'drop_cell':
          break;
      }
      _contentController.text = _tableTemplate();
    });
    _log(
      'table action=$action rows=$_tableRows columns=$_tableColumns '
      'rect=${_formatRect(_selectionRect)}',
    );
  }

  void _applyFlowchartAction(String action) {
    setState(() {
      _kind = LocalChunkKind.flowchart;
      _sourceMode = 'flowchart';
      if (_contentController.text.trim().isEmpty || action == 'draft_nodes') {
        _contentController.text = _flowchartTemplate();
      }
    });
    _log(
      'flowchart action=$action rect=${_formatRect(_selectionRect)} '
      'chars=${_contentController.text.length}',
    );
  }

  void _cancelCard() {
    _log('card cancel kind=${_selectionKind?.wireName ?? _kind.wireName}');
    setState(() {
      _selectionKind = null;
      _selectionRect = null;
      _dragStart = null;
      _dragCurrent = null;
      _errorText = null;
      _saving = false;
    });
  }

  Future<void> _reloadSourceItems() async {
    final items = await widget.repository.listExtractedKnowledgeItems(
      widget.document.id,
    );
    if (!mounted) {
      return;
    }
    setState(() => _sourceItems = items);
    _log(
      'source boxes reloaded document=${widget.document.id} count=${items.length}',
    );
  }

  void _handleSourceBoxTap(String chunkId) {
    _log('source box tap document=${widget.document.id} chunk=$chunkId');
  }

  Future<void> _openFlowchartDraftEditor() async {
    final pageNumber = int.tryParse(_pageController.text.trim()) ?? _pageNumber;
    _log(
      'flowchart draft open document=${widget.document.id} '
      'page=$pageNumber chars=${_contentController.text.length}',
    );
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
      _log('flowchart draft cancelled');
      return;
    }
    setState(() {
      _kind = LocalChunkKind.flowchart;
      _sourceMode = 'flowchart';
      _contentController.text = result;
    });
    _log('flowchart draft applied chars=${result.length}');
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _sourceModeForKind(LocalChunkKind kind) {
    return switch (kind) {
      LocalChunkKind.text || LocalChunkKind.list => 'pdf_text',
      LocalChunkKind.table => 'table',
      LocalChunkKind.flowchart => 'flowchart',
    };
  }

  String _selectionHelp(LocalChunkKind kind) {
    return switch (kind) {
      LocalChunkKind.text => 'Bekezdés vagy rövid szövegrészlet',
      LocalChunkKind.list => 'Felsorolás vagy több soron folytatódó lista',
      LocalChunkKind.table => 'Táblázatrészlet szövegből vagy képből',
      LocalChunkKind.flowchart => 'Folyamatábra részlet',
    };
  }

  IconData _iconForKind(LocalChunkKind kind) {
    return _staticIconForKind(kind);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kézi chunkolás')),
      body: Stack(
        children: [
          Positioned.fill(child: _buildViewer(context)),
          if (_sourceItems.isNotEmpty && _boxMode != SourceChunkBoxMode.hidden)
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: SourceChunkBoxOverlay(
                  boxes: sourceChunkBoxesFromItems(
                    _sourceItems,
                    mode: _boxMode,
                    pageNumber: _pageNumber,
                  ),
                  onTapBox: _handleSourceBoxTap,
                ),
              ),
            ),
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
                  _log('selection drag start at=${_formatOffset(position)}');
                },
                onUpdate: (position) => setState(() => _dragCurrent = position),
                onEnd: () {
                  final start = _dragStart;
                  final current = _dragCurrent;
                  if (start != null && current != null) {
                    _log(
                      'selection drag end start=${_formatOffset(start)} '
                      'end=${_formatOffset(current)}',
                    );
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
            Positioned.fill(
              child: IgnorePointer(
                child: _ExtractionBoxOverlay(
                  rect: _selectionRect!,
                  kind: _kind,
                  tableRows: _tableRows,
                  tableColumns: _tableColumns,
                ),
              ),
            ),
          if (_cardVisible)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: InlineBottomSheetCard(
                onDismiss: _cancelCard,
                child: _ManualChunkCard(
                  kind: _kind,
                  titleController: _titleController,
                  contentController: _contentController,
                  loading: _loadingSelectionText,
                  saving: _saving,
                  errorText: _errorText,
                  tableRows: _tableRows,
                  tableColumns: _tableColumns,
                  onKindChanged: (value) => setState(() {
                    _log(
                      'card kind changed from=${_kind.wireName} '
                      'to=${value.wireName}',
                    );
                    _kind = value;
                    _sourceMode = _sourceModeForKind(value);
                  }),
                  onTableAction: _applyTableAction,
                  onFlowchartAction: _applyFlowchartAction,
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
      _log('viewer build png path=${widget.document.localPath}');
      return _ManualPngViewer(path: widget.document.localPath);
    }
    _log('viewer build pdf path=${widget.document.localPath}');
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
          _log('viewer ready pages=$_pageCount current=$_pageNumber');
        },
        onPageChanged: (pageNumber) {
          if (!mounted || pageNumber == null) {
            return;
          }
          setState(() {
            _pageNumber = pageNumber;
            _pageController.text = _pageNumber.toString();
          });
          _log('viewer page changed page=$_pageNumber');
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

  String _formatOffset(Offset offset) {
    return '${offset.dx.toStringAsFixed(1)},${offset.dy.toStringAsFixed(1)}';
  }

  String _formatRect(Rect? rect) {
    if (rect == null) {
      return 'null';
    }
    return '${rect.left.toStringAsFixed(1)},${rect.top.toStringAsFixed(1)},'
        '${rect.width.toStringAsFixed(1)}x${rect.height.toStringAsFixed(1)}';
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

class _ExtractionBoxOverlay extends StatelessWidget {
  const _ExtractionBoxOverlay({
    required this.rect,
    required this.kind,
    required this.tableRows,
    required this.tableColumns,
  });

  final Rect rect;
  final LocalChunkKind kind;
  final int tableRows;
  final int tableColumns;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ExtractionBoxPainter(rect: rect),
      child: Stack(
        children: [
          Positioned(
            left: rect.left.clamp(12.0, double.infinity),
            top: rect.top.clamp(12.0, double.infinity),
            child: _ExtractionBoxHeader(
              kind: kind,
              tableRows: tableRows,
              tableColumns: tableColumns,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExtractionBoxPainter extends CustomPainter {
  const _ExtractionBoxPainter({required this.rect});

  final Rect rect;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = const Color(0xFF0F766E).withValues(alpha: 0.12);
    final stroke = Paint()
      ..color = const Color(0xFF0F766E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas.drawRRect(rrect, fill);
    canvas.drawRRect(rrect, stroke);
  }

  @override
  bool shouldRepaint(covariant _ExtractionBoxPainter oldDelegate) {
    return oldDelegate.rect != rect;
  }
}

class _ExtractionBoxHeader extends StatelessWidget {
  const _ExtractionBoxHeader({
    required this.kind,
    required this.tableRows,
    required this.tableColumns,
  });

  final LocalChunkKind kind;
  final int tableRows;
  final int tableColumns;

  @override
  Widget build(BuildContext context) {
    final detail = switch (kind) {
      LocalChunkKind.table => '$tableRows x $tableColumns',
      LocalChunkKind.flowchart => 'draft',
      _ => 'manual',
    };
    return DecoratedBox(
      key: const Key('manual-extraction-box-header'),
      decoration: BoxDecoration(
        color: const Color(0xFF0F766E),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_staticIconForKind(kind), color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              '${kind.label} box',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              detail,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualChunkCard extends StatelessWidget {
  const _ManualChunkCard({
    required this.kind,
    required this.titleController,
    required this.contentController,
    required this.loading,
    required this.saving,
    required this.errorText,
    required this.tableRows,
    required this.tableColumns,
    required this.onKindChanged,
    required this.onTableAction,
    required this.onFlowchartAction,
    required this.onCancel,
    required this.onEditFlowchart,
    required this.onSave,
  });

  final LocalChunkKind kind;
  final TextEditingController titleController;
  final TextEditingController contentController;
  final bool loading;
  final bool saving;
  final String? errorText;
  final int tableRows;
  final int tableColumns;
  final ValueChanged<LocalChunkKind> onKindChanged;
  final ValueChanged<String> onTableAction;
  final ValueChanged<String> onFlowchartAction;
  final VoidCallback onCancel;
  final VoidCallback onEditFlowchart;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Material(
        key: const Key('manual-chunk-card-surface'),
        elevation: 14,
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.72,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    key: const Key('manual-chunk-card-header'),
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
                          'Kijelölt chunk mentése',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      key: const Key('manual-chunk-form-scroll'),
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DropdownButtonFormField<LocalChunkKind>(
                            key: const Key('manual-chunk-kind-field'),
                            initialValue: kind,
                            decoration: const InputDecoration(
                              labelText: 'Chunk típusa',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (final option in _manualChunkKinds)
                                DropdownMenuItem(
                                  value: option,
                                  child: Text(option.label),
                                ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                onKindChanged(value);
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          _KindSpecificControls(
                            kind: kind,
                            tableRows: tableRows,
                            tableColumns: tableColumns,
                            loading: loading,
                            saving: saving,
                            onTableAction: onTableAction,
                            onFlowchartAction: onFlowchartAction,
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
                              onPressed: loading || saving
                                  ? null
                                  : onEditFlowchart,
                              icon: const Icon(Icons.account_tree_outlined),
                              label: const Text(
                                'Interaktív flowchart szerkesztő',
                              ),
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
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
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
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KindSpecificControls extends StatelessWidget {
  const _KindSpecificControls({
    required this.kind,
    required this.tableRows,
    required this.tableColumns,
    required this.loading,
    required this.saving,
    required this.onTableAction,
    required this.onFlowchartAction,
  });

  final LocalChunkKind kind;
  final int tableRows;
  final int tableColumns;
  final bool loading;
  final bool saving;
  final ValueChanged<String> onTableAction;
  final ValueChanged<String> onFlowchartAction;

  @override
  Widget build(BuildContext context) {
    final disabled = loading || saving;
    if (kind == LocalChunkKind.table) {
      return DecoratedBox(
        key: const Key('manual-table-toolbar'),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDFA),
          border: Border.all(color: const Color(0xFF99F6E4)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Táblázat rács: $tableRows sor x $tableColumns oszlop',
                style: const TextStyle(
                  color: Color(0xFF115E59),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    key: const Key('manual-table-add-row'),
                    avatar: const Icon(Icons.table_rows_outlined, size: 18),
                    label: const Text('Sor +'),
                    onPressed: disabled ? null : () => onTableAction('add_row'),
                  ),
                  ActionChip(
                    key: const Key('manual-table-add-column'),
                    avatar: const Icon(Icons.view_column_outlined, size: 18),
                    label: const Text('Oszlop +'),
                    onPressed: disabled
                        ? null
                        : () => onTableAction('add_column'),
                  ),
                  ActionChip(
                    key: const Key('manual-table-drop-cell'),
                    avatar: const Icon(Icons.control_point_duplicate, size: 18),
                    label: const Text('Cella dobása'),
                    onPressed: disabled
                        ? null
                        : () => onTableAction('drop_cell'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    if (kind == LocalChunkKind.flowchart) {
      return DecoratedBox(
        key: const Key('manual-flowchart-toolbar'),
        decoration: BoxDecoration(
          color: const Color(0xFFEEF2FF),
          border: Border.all(color: const Color(0xFFC7D2FE)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Flowchart box műveletek',
                style: TextStyle(
                  color: Color(0xFF3730A3),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    key: const Key('manual-flowchart-draft-nodes'),
                    avatar: const Icon(Icons.account_tree_outlined, size: 18),
                    label: const Text('OCR box draft'),
                    onPressed: disabled
                        ? null
                        : () => onFlowchartAction('draft_nodes'),
                  ),
                  ActionChip(
                    key: const Key('manual-flowchart-draft-edges'),
                    avatar: const Icon(Icons.add_link, size: 18),
                    label: const Text('Kapcsolatok'),
                    onPressed: disabled
                        ? null
                        : () => onFlowchartAction('draft_edges'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
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
