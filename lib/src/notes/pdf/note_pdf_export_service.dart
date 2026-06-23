import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../debug/debug_console.dart';
import '../models/note_document.dart';
import '../models/note_item.dart';
import 'note_pdf_document_builder.dart';
import 'note_pdf_export_models.dart';

typedef NotePdfByteBuilder = Future<Uint8List> Function(NoteItem note);
typedef NotePdfTempDirectoryProvider = Future<Directory> Function();
typedef NotePdfSaveFile =
    Future<String?> Function({
      required String dialogTitle,
      required String fileName,
      required Uint8List bytes,
    });
typedef NotePdfShareFile = Future<void> Function(NotePdfPreviewFile file);

class NotePdfExportService {
  const NotePdfExportService({
    this.buildPdfBytes,
    this.tempDirectoryProvider,
    this.saveFile,
    this.shareFile,
  });

  final NotePdfByteBuilder? buildPdfBytes;
  final NotePdfTempDirectoryProvider? tempDirectoryProvider;
  final NotePdfSaveFile? saveFile;
  final NotePdfShareFile? shareFile;

  Future<NotePdfExportResult> generate(NoteItem note) async {
    final document = NoteDocument.fromPayload(
      note.payloadJson,
      legacyType: note.type.wireName,
      legacyText: note.plainText,
      title: note.title,
    );
    final hasContent = document.blocks.any(notePdfBlockHasExportableContent);
    if (!hasContent) {
      throw const NotePdfExportException(
        'A jegyzet nem tartalmaz exportálható tartalmat.',
      );
    }
    DebugConsole.log(
      '[NotePdfExport] generate start note=${note.id} blocks=${document.blocks.length}',
    );
    final bytes = await (buildPdfBytes ?? const NotePdfDocumentBuilder().build)(
      note,
    );
    DebugConsole.log(
      '[NotePdfExport] generated filename=${safeNotePdfFilename(note.title)} '
      'bytes=${bytes.length}',
    );
    return NotePdfExportResult(
      filename: safeNotePdfFilename(note.title),
      bytes: bytes,
    );
  }

  Future<NotePdfPreviewFile> createPreviewFile(NoteItem note) async {
    final result = await generate(note);
    final directory = await (tempDirectoryProvider ?? getTemporaryDirectory)();
    await directory.create(recursive: true);
    final file = File(p.join(directory.path, result.filename));
    await file.writeAsBytes(result.bytes, flush: true);
    DebugConsole.log(
      '[NotePdfExport] preview path=${file.path} bytes=${result.bytes.length}',
    );
    return NotePdfPreviewFile(
      path: file.path,
      filename: result.filename,
      bytes: result.bytes,
    );
  }

  Future<String?> savePreviewFile(NotePdfPreviewFile file) async {
    DebugConsole.log('[NotePdfExport] save start filename=${file.filename}');
    try {
      final path = await (saveFile ?? _saveWithPlatform)(
        dialogTitle: 'PDF mentése',
        fileName: file.filename,
        bytes: file.bytes,
      );
      if (path == null) {
        DebugConsole.log(
          '[NotePdfExport] save cancelled filename=${file.filename}',
        );
        return null;
      }
      DebugConsole.log('[NotePdfExport] save success path=$path');
      return path;
    } catch (error) {
      DebugConsole.log('[NotePdfExport] save failed error=$error');
      rethrow;
    }
  }

  Future<void> sharePreviewFile(NotePdfPreviewFile file) async {
    DebugConsole.log('[NotePdfExport] share start filename=${file.filename}');
    try {
      await (shareFile ?? _shareWithPlatform)(file);
      DebugConsole.log(
        '[NotePdfExport] share success filename=${file.filename}',
      );
    } catch (error) {
      DebugConsole.log('[NotePdfExport] share failed error=$error');
      rethrow;
    }
  }

  static Future<String?> _saveWithPlatform({
    required String dialogTitle,
    required String fileName,
    required Uint8List bytes,
  }) {
    return FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      bytes: bytes,
    );
  }

  static Future<void> _shareWithPlatform(NotePdfPreviewFile file) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        fileNameOverrides: [file.filename],
        subject: file.filename,
      ),
    );
  }
}
