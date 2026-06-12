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
      body: isPng ? _PngViewer(path: path) : PdfViewer.file(path),
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
