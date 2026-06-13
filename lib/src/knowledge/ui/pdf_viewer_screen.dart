import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

class PdfViewerScreen extends StatelessWidget {
  const PdfViewerScreen({super.key, required this.title, required this.path});

  final String title;
  final String path;

  @override
  Widget build(BuildContext context) {
    final isPng = path.toLowerCase().endsWith('.png');
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: isPng ? _PngViewer(path: path) : _PdfDocumentViewer(path: path),
    );
  }
}

class _PdfDocumentViewer extends StatefulWidget {
  const _PdfDocumentViewer({required this.path});

  final String path;

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
  const _PngViewer({required this.path});

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
