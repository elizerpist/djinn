import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../pdf/note_pdf_export_models.dart';
import '../pdf/note_pdf_export_service.dart';

class NotePdfPreviewScreen extends StatefulWidget {
  const NotePdfPreviewScreen({
    super.key,
    required this.file,
    this.exportService = const NotePdfExportService(),
    this.viewerBuilder,
  });

  final NotePdfPreviewFile file;
  final NotePdfExportService exportService;
  final WidgetBuilder? viewerBuilder;

  @override
  State<NotePdfPreviewScreen> createState() => _NotePdfPreviewScreenState();
}

class _NotePdfPreviewScreenState extends State<NotePdfPreviewScreen> {
  final _controller = PdfViewerController();
  int _pageNumber = 1;
  int _pageCount = 0;
  bool _ready = false;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('note-pdf-preview-screen'),
      appBar: AppBar(
        title: Text(widget.file.filename),
        actions: [
          IconButton(
            key: const ValueKey('note-pdf-preview-save'),
            tooltip: 'PDF mentése',
            onPressed: _busy ? null : _save,
            icon: const Icon(Icons.save_alt),
          ),
          IconButton(
            key: const ValueKey('note-pdf-preview-share'),
            tooltip: 'PDF megosztása',
            onPressed: _busy ? null : _share,
            icon: const Icon(Icons.share),
          ),
        ],
      ),
      body:
          widget.viewerBuilder?.call(context) ??
          PdfViewer.file(
            widget.file.path,
            controller: _controller,
            params: PdfViewerParams(
              scrollPhysics: PdfViewerParams.getScrollPhysics(context),
              scrollPhysicsScale: PdfViewerParams.getScrollPhysics(context),
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
          ),
    );
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final path = await widget.exportService.savePreviewFile(widget.file);
      if (!mounted || path == null) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF mentve: $path')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF mentés sikertelen: $error')));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      await widget.exportService.sharePreviewFile(widget.file);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF megosztás sikertelen: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
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
          color: Colors.black.withValues(alpha: 0.76),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Előző oldalak',
                color: Colors.white,
                onPressed: onPrevious,
                icon: const Icon(Icons.keyboard_double_arrow_up),
              ),
              Text(
                '$pageNumber / $pageCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                tooltip: 'Következő oldalak',
                color: Colors.white,
                onPressed: onNext,
                icon: const Icon(Icons.keyboard_double_arrow_down),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
