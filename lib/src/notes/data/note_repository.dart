import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

import '../../knowledge/models/local_extraction.dart';
import '../models/note_document.dart';
import '../models/note_folder.dart';
import '../models/note_item.dart';

abstract class NoteRepository {
  Future<void> load();
  Future<List<NoteFolder>> listFolders();
  Future<NoteFolder> createFolder(String title);
  Future<void> deleteFolder(String folderId);
  Future<List<NoteItem>> listNotes({String? folderId, NoteItemType? type});
  Future<NoteItem> createDocumentNote({
    required String title,
    required NoteDocument document,
    String? folderId,
  });
  Future<NoteItem> createNote({
    required NoteItemType type,
    required String title,
    required String plainText,
    required String payloadJson,
    String? folderId,
  });
  Future<NoteItem> updateNoteDocument(
    String noteId, {
    required String title,
    required NoteDocument document,
    LocalAuditState? auditState,
    String? reason,
  });
  Future<NoteItem> updateNoteValidation(
    String noteId, {
    required LocalAuditState auditState,
    String? plainText,
    String? payloadJson,
    String? reason,
  });
  Future<void> deleteNotes(List<String> noteIds);
}

class MemoryNoteRepository implements NoteRepository {
  MemoryNoteRepository({Uuid? uuid, DateTime Function()? clock})
      : _uuid = uuid ?? const Uuid(),
        _clock = clock ?? DateTime.now;

  final Uuid _uuid;
  final DateTime Function() _clock;
  final List<NoteFolder> _folders = [];
  final List<NoteItem> _notes = [];

  @override
  Future<void> load() async {}

  @override
  Future<List<NoteFolder>> listFolders() async {
    final folders = [..._folders]
      ..sort((a, b) {
        final order = a.sortOrder.compareTo(b.sortOrder);
        if (order != 0) {
          return order;
        }
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
    return List.unmodifiable(folders);
  }

  @override
  Future<NoteFolder> createFolder(String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('folder title must not be blank');
    }
    final now = _clock();
    final folder = NoteFolder(
      id: _uuid.v4(),
      title: trimmed,
      createdAt: now,
      updatedAt: now,
      sortOrder: _folders.length,
    );
    _folders.add(folder);
    return folder;
  }

  @override
  Future<void> deleteFolder(String folderId) async {
    _folders.removeWhere((folder) => folder.id == folderId);
    for (var i = 0; i < _notes.length; i += 1) {
      if (_notes[i].folderId == folderId) {
        _notes[i] = _notes[i].copyWith(clearFolderId: true, updatedAt: _clock());
      }
    }
  }

  @override
  Future<List<NoteItem>> listNotes({String? folderId, NoteItemType? type}) async {
    final notes = _notes.where((note) {
      if (folderId != null && note.folderId != folderId) {
        return false;
      }
      if (type != null && note.type != type) {
        return false;
      }
      return true;
    }).toList(growable: false)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List.unmodifiable(notes);
  }

  @override
  Future<NoteItem> createDocumentNote({
    required String title,
    required NoteDocument document,
    String? folderId,
  }) async {
    final trimmedTitle = title.trim();
    final plainText = document.plainText.trim();
    if (trimmedTitle.isEmpty) {
      throw ArgumentError('note title must not be blank');
    }
    if (plainText.isEmpty) {
      throw ArgumentError('note text must not be blank');
    }
    final now = _clock();
    final note = NoteItem(
      id: _uuid.v4(),
      folderId: folderId,
      type: NoteItemType.document,
      title: trimmedTitle,
      plainText: plainText,
      payloadJson: document.toPayloadJson(),
      auditState: LocalAuditState.unreviewed,
      createdAt: now,
      updatedAt: now,
    );
    _notes.insert(0, note);
    return note;
  }

  @override
  Future<NoteItem> createNote({
    required NoteItemType type,
    required String title,
    required String plainText,
    required String payloadJson,
    String? folderId,
  }) async {
    final document = NoteDocument.fromPayload(
      payloadJson.trim().isEmpty ? '{}' : payloadJson,
      legacyType: type.wireName,
      legacyText: plainText,
      title: title,
    );
    return createDocumentNote(
      title: title,
      document: document,
      folderId: folderId,
    );
  }

  @override
  Future<NoteItem> updateNoteDocument(
    String noteId, {
    required String title,
    required NoteDocument document,
    LocalAuditState? auditState,
    String? reason,
  }) async {
    final index = _notes.indexWhere((note) => note.id == noteId);
    if (index == -1) {
      throw StateError('note not found: $noteId');
    }
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw ArgumentError('note title must not be blank');
    }
    final trimmedReason = reason?.trim();
    final updated = _notes[index].copyWithDocument(
      title: trimmedTitle,
      document: document,
      auditState: auditState,
      reason: trimmedReason == null || trimmedReason.isEmpty ? null : trimmedReason,
      clearReason: trimmedReason == null || trimmedReason.isEmpty,
      updatedAt: _clock(),
    );
    _notes[index] = updated;
    return updated;
  }

  @override
  Future<NoteItem> updateNoteValidation(
    String noteId, {
    required LocalAuditState auditState,
    String? plainText,
    String? payloadJson,
    String? reason,
  }) async {
    final index = _notes.indexWhere((note) => note.id == noteId);
    if (index == -1) {
      throw StateError('note not found: $noteId');
    }
    final existing = _notes[index];
    final document = payloadJson == null && plainText != null
        ? NoteDocument(blocks: [
            NoteBlock(
              id: 'block-1',
              type: NoteBlockType.paragraph,
              text: plainText.trim(),
            ),
          ])
        : NoteDocument.fromPayload(
            payloadJson ?? existing.payloadJson,
            legacyType: existing.type.wireName,
            legacyText: plainText ?? existing.plainText,
            title: existing.title,
          );
    return updateNoteDocument(
      noteId,
      title: existing.title,
      document: document,
      auditState: auditState,
      reason: reason,
    );
  }

  @override
  Future<void> deleteNotes(List<String> noteIds) async {
    final ids = noteIds.toSet();
    _notes.removeWhere((note) => ids.contains(note.id));
  }

  void replaceMemoryState({
    required List<NoteFolder> folders,
    required List<NoteItem> notes,
  }) {
    _folders
      ..clear()
      ..addAll(folders);
    _notes
      ..clear()
      ..addAll(notes);
  }
}

class FileNoteRepository extends MemoryNoteRepository {
  FileNoteRepository({required File file, super.uuid, super.clock})
      : _file = file;

  final File _file;

  @override
  Future<void> load() async {
    if (!_file.existsSync()) {
      return;
    }
    final data = jsonDecode(await _file.readAsString()) as Map<String, Object?>;
    final folders = (data['folders'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => NoteFolder.fromJson(Map<String, Object?>.from(item)))
        .toList(growable: false);
    final notes = (data['notes'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => NoteItem.fromJson(Map<String, Object?>.from(item)))
        .toList(growable: false);
    _replaceState(folders: folders, notes: notes);
  }

  @override
  Future<NoteFolder> createFolder(String title) async {
    final folder = await super.createFolder(title);
    await _persist();
    return folder;
  }

  @override
  Future<void> deleteFolder(String folderId) async {
    await super.deleteFolder(folderId);
    await _persist();
  }

  @override
  Future<NoteItem> createDocumentNote({
    required String title,
    required NoteDocument document,
    String? folderId,
  }) async {
    final note = await super.createDocumentNote(
      title: title,
      document: document,
      folderId: folderId,
    );
    await _persist();
    return note;
  }

  @override
  Future<NoteItem> createNote({
    required NoteItemType type,
    required String title,
    required String plainText,
    required String payloadJson,
    String? folderId,
  }) async {
    final document = NoteDocument.fromPayload(
      payloadJson.trim().isEmpty ? '{}' : payloadJson,
      legacyType: type.wireName,
      legacyText: plainText,
      title: title,
    );
    return createDocumentNote(
      title: title,
      document: document,
      folderId: folderId,
    );
  }

  @override
  Future<NoteItem> updateNoteDocument(
    String noteId, {
    required String title,
    required NoteDocument document,
    LocalAuditState? auditState,
    String? reason,
  }) async {
    final note = await super.updateNoteDocument(
      noteId,
      title: title,
      document: document,
      auditState: auditState,
      reason: reason,
    );
    await _persist();
    return note;
  }

  @override
  Future<NoteItem> updateNoteValidation(
    String noteId, {
    required LocalAuditState auditState,
    String? plainText,
    String? payloadJson,
    String? reason,
  }) async {
    final note = await super.updateNoteValidation(
      noteId,
      auditState: auditState,
      plainText: plainText,
      payloadJson: payloadJson,
      reason: reason,
    );
    await _persist();
    return note;
  }

  @override
  Future<void> deleteNotes(List<String> noteIds) async {
    await super.deleteNotes(noteIds);
    await _persist();
  }

  void _replaceState({
    required List<NoteFolder> folders,
    required List<NoteItem> notes,
  }) {
    replaceMemoryState(folders: folders, notes: notes);
  }

  Future<void> _persist() async {
    if (!_file.parent.existsSync()) {
      _file.parent.createSync(recursive: true);
    }
    final folders = await listFolders();
    final notes = await listNotes();
    await _file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'folders': folders.map((folder) => folder.toJson()).toList(),
        'notes': notes.map((note) => note.toJson()).toList(),
      }),
    );
  }
}
