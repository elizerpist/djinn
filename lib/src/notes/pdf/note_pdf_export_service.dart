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
typedef NotePdfBatchByteBuilder =
    Future<Uint8List> Function(List<NoteItem> notes);
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
    this.buildPdfBatchBytes,
    this.tempDirectoryProvider,
    this.saveFile,
    this.shareFile,
  });

  final NotePdfByteBuilder? buildPdfBytes;
  final NotePdfBatchByteBuilder? buildPdfBatchBytes;
  final NotePdfTempDirectoryProvider? tempDirectoryProvider;
  final NotePdfSaveFile? saveFile;
  final NotePdfShareFile? shareFile;

  Future<NotePdfExportResult> generate(NoteItem note) async {
    return generateMany([note]);
  }

  Future<NotePdfExportResult> generateMany(List<NoteItem> notes) async {
    final selected = List<NoteItem>.from(notes, growable: false);
    if (selected.isEmpty) {
      throw const NotePdfExportException(
        'Nincs kijelölt jegyzet PDF exporthoz.',
      );
    }
    for (final note in selected) {
      _validateExportable(note);
    }
    DebugConsole.log(
      '[NotePdfExport] generate batch start notes=${selected.length} '
      'ids=${selected.map((note) => note.id).join(',')}',
    );
    final bytes = await _buildBytes(selected);
    final filename = selected.length == 1
        ? safeNotePdfFilename(selected.single.title)
        : 'jegyzetek_${selected.length}.pdf';
    DebugConsole.log(
      '[NotePdfExport] generated filename=$filename notes=${selected.length} '
      'bytes=${bytes.length}',
    );
    return NotePdfExportResult(filename: filename, bytes: bytes);
  }

  Future<NotePdfPreviewFile> createPreviewFile(NoteItem note) async {
    return createPreviewFileForNotes([note]);
  }

  Future<NotePdfPreviewFile> createPreviewFileForNotes(
    List<NoteItem> notes,
  ) async {
    final result = await generateMany(notes);
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

  void _validateExportable(NoteItem note) {
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
  }

  Future<Uint8List> _buildBytes(List<NoteItem> notes) {
    if (notes.length == 1 && buildPdfBytes != null) {
      return buildPdfBytes!(notes.single);
    }
    if (buildPdfBatchBytes != null) {
      return buildPdfBatchBytes!(notes);
    }
    if (notes.length == 1) {
      return const NotePdfDocumentBuilder().build(notes.single);
    }
    return const NotePdfDocumentBuilder().buildMany(notes);
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
