import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import '../models/local_extraction.dart';
import 'local_document_processing_service.dart';
import 'mlkit_ocr_engine.dart';

class PdfrxLocalPageExtractor implements LocalPageExtractor {
  const PdfrxLocalPageExtractor({
    required this.ocrEngine,
    this.renderScale = 2.0,
  });

  final OcrEngine ocrEngine;
  final double renderScale;

  @override
  Future<List<LocalDocumentPage>> extractPages({
    required String documentId,
    required String path,
  }) async {
    final lowerPath = path.toLowerCase();
    if (lowerPath.endsWith('.png')) {
      final ocr = await ocrEngine.recognizeImage(path);
      return [
        LocalDocumentPage(
          documentId: documentId,
          pageNumber: 1,
          pdfText: '',
          ocrText: ocr.text,
          ocrBlocksJson: ocr.blocksJson,
          sourceImagePath: path,
        ),
      ];
    }
    return _extractPdfPages(documentId: documentId, pdfPath: path);
  }

  Future<List<LocalDocumentPage>> _extractPdfPages({
    required String documentId,
    required String pdfPath,
  }) async {
    final document = await PdfDocument.openFile(pdfPath);
    try {
      final pages = <LocalDocumentPage>[];
      for (final page in document.pages) {
        final rawText = await page.loadText();
        final imagePath = await _renderPageToPng(pdfPath: pdfPath, page: page);
        final ocr = await ocrEngine.recognizeImage(imagePath);
        pages.add(
          LocalDocumentPage(
            documentId: documentId,
            pageNumber: page.pageNumber,
            pdfText: rawText?.fullText ?? '',
            ocrText: ocr.text,
            ocrBlocksJson: ocr.blocksJson,
            sourceImagePath: imagePath,
          ),
        );
      }
      return pages;
    } finally {
      await document.dispose();
    }
  }

  Future<String> _renderPageToPng({
    required String pdfPath,
    required PdfPage page,
  }) async {
    final cacheDir = await getTemporaryDirectory();
    final safeName = path.basenameWithoutExtension(pdfPath).replaceAll(
      RegExp(r'[^A-Za-z0-9_.-]+'),
      '_',
    );
    final output = File(
      path.join(
        cacheDir.path,
        'djinn-local-ocr-$safeName-p${page.pageNumber}.png',
      ),
    );
    final width = (page.width * renderScale).round().clamp(1, 4096);
    final height = (page.height * renderScale).round().clamp(1, 4096);
    final pdfImage = await page.render(
      fullWidth: width.toDouble(),
      fullHeight: height.toDouble(),
      backgroundColor: 0xffffffff,
    );
    if (pdfImage == null) {
      throw StateError('PDF page render failed: ${page.pageNumber}');
    }
    ui.Image? uiImage;
    try {
      uiImage = await pdfImage.createImage();
      final byteData = await uiImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) {
        throw StateError('PDF page PNG encoding failed: ${page.pageNumber}');
      }
      await output.writeAsBytes(
        Uint8List.view(byteData.buffer),
        flush: true,
      );
      return output.path;
    } finally {
      uiImage?.dispose();
      pdfImage.dispose();
    }
  }
}
