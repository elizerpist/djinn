import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/knowledge_pack.dart';
import 'knowledge_pack_service.dart';

class SharedFile {
  const SharedFile({required this.path, required this.filename});

  final String path;
  final String filename;
}

typedef ShareAdapter = Future<void> Function(SharedFile file);
typedef TempDirectoryProvider = Future<Directory> Function();

class KnowledgePackShareService {
  const KnowledgePackShareService({
    this.packService = const KnowledgePackService(),
    TempDirectoryProvider? tempDirectoryProvider,
    ShareAdapter? shareAdapter,
  }) : _tempDirectoryProvider = tempDirectoryProvider,
       _shareAdapter = shareAdapter;

  final KnowledgePackService packService;
  final TempDirectoryProvider? _tempDirectoryProvider;
  final ShareAdapter? _shareAdapter;

  Future<SharedFile> share(KnowledgePack pack, {String? filename}) async {
    final directory = await (_tempDirectoryProvider ?? getTemporaryDirectory)();
    await directory.create(recursive: true);
    final safeFilename = _safePackFilename(filename ?? _defaultFilename(pack));
    final file = File(p.join(directory.path, safeFilename));
    await file.writeAsBytes(packService.encode(pack), flush: true);
    final sharedFile = SharedFile(path: file.path, filename: safeFilename);
    await (_shareAdapter ?? _shareWithPlatform)(sharedFile);
    return sharedFile;
  }

  static Future<void> _shareWithPlatform(SharedFile file) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/octet-stream')],
        fileNameOverrides: [file.filename],
        subject: file.filename,
      ),
    );
  }

  String _defaultFilename(KnowledgePack pack) {
    if (pack.documents.length == 1) {
      final filename = pack.documents.single.filename;
      final base = filename.replaceAll(
        RegExp(r'\.pdf$', caseSensitive: false),
        '',
      );
      return '$base.djinnpack';
    }
    return 'djinn-tudastar-${DateTime.now().millisecondsSinceEpoch}.djinnpack';
  }

  String _safePackFilename(String filename) {
    final withExtension = filename.endsWith('.djinnpack')
        ? filename
        : '$filename.djinnpack';
    final safe = withExtension.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    return safe.isEmpty ? 'document.djinnpack' : safe;
  }
}
