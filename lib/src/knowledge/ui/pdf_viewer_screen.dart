import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../debug/debug_console.dart';
import '../../notes/data/note_repository.dart';
import '../../notes/data/tag_repository.dart';
import '../data/knowledge_document_repository.dart';
import '../models/extracted_knowledge_item.dart';
import '../models/knowledge_document.dart';
import 'extracted_knowledge_screen.dart';
import 'source_chunk_box_overlay.dart';

class PdfViewerScreen extends StatefulWidget {
  const PdfViewerScreen({
    super.key,
    required this.title,
    required this.path,
    this.repository,
    this.document,
    this.noteRepository,
    this.tagRepository,
  });

  final String title;
  final String path;
  final KnowledgeDocumentRepository? repository;
  final KnowledgeDocument? document;
  final NoteRepository? noteRepository;
  final TagRepository? tagRepository;

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  SourceChunkBoxMode _boxMode = SourceChunkBoxMode.hidden;
  List<ExtractedKnowledgeItem> _sourceItems = const [];

  bool get _hasSourceContext =>
      widget.repository != null && widget.document != null;

  @override
  void initState() {
    super.initState();
    _loadSourceItems();
  }

  @override
  void didUpdateWidget(covariant PdfViewerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document?.id != widget.document?.id ||
        oldWidget.repository != widget.repository) {
      _loadSourceItems();
    }
  }

  Future<void> _loadSourceItems() async {
    final repository = widget.repository;
    final document = widget.document;
    if (repository == null || document == null) {
      return;
    }
    final items = await repository.listExtractedKnowledgeItems(document.id);
    if (!mounted) {
      return;
    }
    setState(() => _sourceItems = items);
    DebugConsole.log(
      '[Knowledge/Viewer] boxes loaded document=${document.id} '
      'count=${items.length}',
    );
  }

  void _setBoxMode(SourceChunkBoxMode mode) {
    setState(() => _boxMode = mode);
    final document = widget.document;
    if (document != null) {
      DebugConsole.log(
        '[Knowledge/Viewer] box mode document=${document.id} mode=${mode.name}',
      );
    }
  }

  Future<void> _handleBoxTap(String chunkId) async {
    final repository = widget.repository;
    final document = widget.document;
    if (document != null) {
      DebugConsole.log(
        '[Knowledge/Viewer] box tap document=${document.id} chunk=$chunkId',
      );
    }
    if (repository == null || document == null) {
      return;
    }
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExtractedKnowledgeScreen(
          repository: repository,
          document: document,
          noteRepository: widget.noteRepository,
          tagRepository: widget.tagRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPng = widget.path.toLowerCase().endsWith('.png');
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (_hasSourceContext)
            PopupMenuButton<SourceChunkBoxMode>(
              key: const Key('source-box-mode-menu'),
              tooltip: 'Forrásdobozok',
              initialValue: _boxMode,
              onSelected: _setBoxMode,
              itemBuilder: (context) => [
                for (final mode in SourceChunkBoxMode.values)
                  PopupMenuItem(value: mode, child: Text(mode.label)),
              ],
            ),
        ],
      ),
      body: isPng
          ? _PngViewer(
              path: widget.path,
              items: _sourceItems,
              boxMode: _boxMode,
              onTapBox: _handleBoxTap,
            )
          : _PdfDocumentViewer(
              path: widget.path,
              items: _sourceItems,
              boxMode: _boxMode,
              onTapBox: _handleBoxTap,
            ),
    );
  }
}

class _PdfDocumentViewer extends StatefulWidget {
  const _PdfDocumentViewer({
    required this.path,
    required this.items,
    required this.boxMode,
    required this.onTapBox,
  });

  final String path;
  final List<ExtractedKnowledgeItem> items;
  final SourceChunkBoxMode boxMode;
  final ValueChanged<String> onTapBox;

  @override
  State<_PdfDocumentViewer> createState() => _PdfDocumentViewerState();
}

class _PdfDocumentViewerState extends State<_PdfDocumentViewer> {
  final _controller = PdfViewerController();
  int _pageNumber = 1;
  int _pageCount = 0;
  bool _ready = false;

  @override
  Widget build(BuildContext context) {
    return PdfViewer.file(
      widget.path,
      controller: _controller,
      params: PdfViewerParams(
        scrollPhysics: PdfViewerParams.getScrollPhysics(context),
        scrollPhysicsScale: PdfViewerParams.getScrollPhysics(context),
        pageOverlaysBuilder: (context, pageRect, page) => [
          if (widget.boxMode != SourceChunkBoxMode.hidden)
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: SourceChunkBoxOverlay(
                  boxes: sourceChunkBoxesFromItems(
                    widget.items,
                    mode: widget.boxMode,
                    pageNumber: page.pageNumber,
                    pageSize: pageRect.size,
                  ),
                  onTapBox: widget.onTapBox,
                ),
              ),
            ),
        ],
        onViewerReady: (_, controller) {
          if (!mounted) {
            return;
          }
          setState(() {
            _ready = true;
            _pageCount = controller.pageCount;
            _pageNumber = controller.pageNumber ?? 1;
          });
        },
        onPageChanged: (pageNumber) {
          if (!mounted || pageNumber == null) {
            return;
          }
          setState(() => _pageNumber = pageNumber);
        },
        viewerOverlayBuilder: (context, size, handleLinkTap) => [
          PdfViewerScrollThumb(
            controller: _controller,
            orientation: ScrollbarOrientation.right,
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _PdfPageControls(
              ready: _ready,
              pageNumber: _pageNumber,
              pageCount: _pageCount,
              onPrevious: () => _jumpBy(-5),
              onNext: () => _jumpBy(5),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _jumpBy(int delta) async {
    if (!_controller.isReady) {
      return;
    }
    final current = _controller.pageNumber ?? _pageNumber;
    final target = (current + delta).clamp(1, _controller.pageCount).toInt();
    await _controller.goToPage(
      pageNumber: target,
      anchor: PdfPageAnchor.top,
      duration: Duration.zero,
    );
  }
}

class _PdfPageControls extends StatelessWidget {
  const _PdfPageControls({
    required this.ready,
    required this.pageNumber,
    required this.pageCount,
    required this.onPrevious,
    required this.onNext,
  });

  final bool ready;
  final int pageNumber;
  final int pageCount;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    if (!ready || pageCount <= 1) {
      return const SizedBox.shrink();
    }
    return Align(
      alignment: Alignment.bottomCenter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _pageButton(
                tooltip: 'Ugrás 5 oldallal vissza',
                icon: Icons.keyboard_double_arrow_up,
                onPressed: pageNumber <= 1 ? null : onPrevious,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '$pageNumber / $pageCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _pageButton(
                tooltip: 'Ugrás 5 oldallal előre',
                icon: Icons.keyboard_double_arrow_down,
                onPressed: pageNumber >= pageCount ? null : onNext,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pageButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 34, height: 34),
      color: Colors.white,
      disabledColor: Colors.white38,
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
    );
  }
}

class _PngViewer extends StatelessWidget {
  const _PngViewer({
    required this.path,
    required this.items,
    required this.boxMode,
    required this.onTapBox,
  });

  final String path;
  final List<ExtractedKnowledgeItem> items;
  final SourceChunkBoxMode boxMode;
  final ValueChanged<String> onTapBox;

  @override
  Widget build(BuildContext context) {
    final boxes = sourceChunkBoxesFromItems(
      items,
      mode: boxMode,
      pageNumber: 1,
    );
    return Container(
      color: const Color(0xFF111827),
      alignment: Alignment.center,
      child: Stack(
        fit: StackFit.expand,
        children: [
          InteractiveViewer(
            minScale: 0.5,
            maxScale: 5,
            child: Center(child: Image.file(File(path), fit: BoxFit.contain)),
          ),
          if (boxes.isNotEmpty)
            SourceChunkBoxOverlay(boxes: boxes, onTapBox: onTapBox),
        ],
      ),
    );
  }
}

extension on SourceChunkBoxMode {
  String get label {
    return switch (this) {
      SourceChunkBoxMode.hidden => 'Dobozok rejtve',
      SourceChunkBoxMode.ai => 'AI dobozok',
      SourceChunkBoxMode.manual => 'Manuális dobozok',
    };
  }
}
