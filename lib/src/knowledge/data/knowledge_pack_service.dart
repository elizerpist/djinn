import 'dart:convert';

import 'package:archive/archive.dart';

import '../models/chunk_package.dart';
import '../models/knowledge_pack.dart';

class KnowledgePackService {
  const KnowledgePackService();

  List<int> encode(KnowledgePack pack) {
    final archive = Archive();
    final manifestDocuments = <Map<String, Object?>>[];

    for (var index = 0; index < pack.documents.length; index += 1) {
      final document = pack.documents[index];
      final directory = 'documents/$index';
      final pdfPath = '$directory/document.pdf';
      final chunksPath = '$directory/chunks.json';
      manifestDocuments.add({
        'filename': document.filename,
        'document_hash': document.documentHash,
        'pdf_path': pdfPath,
        'chunks_path': chunksPath,
      });
      archive.addFile(
        ArchiveFile(pdfPath, document.pdfBytes.length, document.pdfBytes),
      );
      final chunkBytes = utf8.encode(
        jsonEncode(document.chunkPackage.toJson()),
      );
      archive.addFile(ArchiveFile(chunksPath, chunkBytes.length, chunkBytes));
    }

    final manifestBytes = utf8.encode(
      jsonEncode({
        'schema_version': pack.schemaVersion,
        'documents': manifestDocuments,
      }),
    );
    archive.addFile(
      ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
    );
    return ZipEncoder().encode(archive);
  }

  KnowledgePack decode(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final manifestFile = archive.findFile('manifest.json');
    if (manifestFile == null) {
      throw const FormatException('Knowledge pack manifest is missing.');
    }
    final manifest = jsonDecode(utf8.decode(manifestFile.content as List<int>));
    if (manifest is! Map) {
      throw const FormatException('Knowledge pack manifest must be an object.');
    }
    final documentItems = manifest['documents'];
    if (documentItems is! List) {
      throw const FormatException('Knowledge pack documents must be a list.');
    }
    return KnowledgePack(
      schemaVersion: _requiredInt(manifest, 'schema_version'),
      documents: documentItems
          .map((item) {
            if (item is! Map) {
              throw const FormatException(
                'Knowledge pack document must be an object.',
              );
            }
            final document = Map<String, Object?>.from(item);
            final pdfFile = archive.findFile(
              _requiredString(document, 'pdf_path'),
            );
            final chunksFile = archive.findFile(
              _requiredString(document, 'chunks_path'),
            );
            if (pdfFile == null || chunksFile == null) {
              throw const FormatException(
                'Knowledge pack document file missing.',
              );
            }
            final chunksJson = jsonDecode(
              utf8.decode(chunksFile.content as List<int>),
            );
            if (chunksJson is! Map) {
              throw const FormatException(
                'Knowledge pack chunks must be an object.',
              );
            }
            return KnowledgePackDocument(
              filename: _requiredString(document, 'filename'),
              documentHash: _requiredString(document, 'document_hash'),
              pdfBytes: List<int>.from(pdfFile.content as List<int>),
              chunkPackage: ChunkPackage.fromJson(
                Map<String, Object?>.from(chunksJson),
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

String _requiredString(Map<dynamic, dynamic> json, String key) {
  final value = json[key];
  if (value is String) {
    return value;
  }
  throw FormatException('Knowledge pack field "$key" must be a string.');
}

int _requiredInt(Map<dynamic, dynamic> json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  throw FormatException('Knowledge pack field "$key" must be an integer.');
}
