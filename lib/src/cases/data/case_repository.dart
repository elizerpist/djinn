import 'package:objectbox/objectbox.dart';
import 'package:uuid/uuid.dart';

import '../../../objectbox.g.dart';
import '../../debug/debug_console.dart';
import '../../local_store/entities.dart';
import '../models/case_workspace.dart';

abstract class CaseRepository {
  Future<CaseWorkspace> createCase({String title = 'Új eset'});
  Future<List<CaseWorkspace>> listCases();
  Future<CaseWorkspace> updateNotes(String caseId, String notes);
  Future<void> linkChat(String caseId, String chatThreadId);
  Future<void> linkDocument(String caseId, String documentId);
  Future<List<String>> listLinkedChats(String caseId);
  Future<List<String>> listLinkedDocuments(String caseId);
}

class MemoryCaseRepository implements CaseRepository {
  MemoryCaseRepository({DateTime Function()? clock, Uuid? uuid})
    : _clock = clock ?? DateTime.now,
      _uuid = uuid ?? const Uuid();

  final DateTime Function() _clock;
  final Uuid _uuid;
  final Map<String, _MutableCase> _cases = {};
  final Map<String, Set<String>> _chatLinks = {};
  final Map<String, Set<String>> _documentLinks = {};

  @override
  Future<CaseWorkspace> createCase({String title = 'Új eset'}) async {
    final now = _clock();
    final id = _uuid.v4();
    _cases[id] = _MutableCase(
      id: id,
      title: title.trim().isEmpty ? 'Új eset' : title.trim(),
      notes: '',
      createdAt: now,
      updatedAt: now,
      archived: false,
    );
    DebugConsole.log('[Cases] created case=$id');
    return _toWorkspace(_cases[id]!);
  }

  @override
  Future<List<CaseWorkspace>> listCases() async {
    final items = _cases.values
        .where((item) => !item.archived)
        .map(_toWorkspace)
        .toList(growable: false);
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }

  @override
  Future<CaseWorkspace> updateNotes(String caseId, String notes) async {
    final item = _cases[caseId];
    if (item == null) {
      throw StateError('case not found: $caseId');
    }
    item.notes = notes;
    item.updatedAt = _clock();
    DebugConsole.log(
      '[Cases] notes updated case=$caseId chars=${notes.length}',
    );
    return _toWorkspace(item);
  }

  @override
  Future<void> linkChat(String caseId, String chatThreadId) async {
    _ensureCase(caseId);
    _chatLinks.putIfAbsent(caseId, () => {}).add(chatThreadId);
    DebugConsole.log('[Cases] chat linked case=$caseId chat=$chatThreadId');
  }

  @override
  Future<void> linkDocument(String caseId, String documentId) async {
    _ensureCase(caseId);
    _documentLinks.putIfAbsent(caseId, () => {}).add(documentId);
    DebugConsole.log(
      '[Cases] document linked case=$caseId document=$documentId',
    );
  }

  @override
  Future<List<String>> listLinkedChats(String caseId) async {
    _ensureCase(caseId);
    return List.unmodifiable(_chatLinks[caseId] ?? const <String>{});
  }

  @override
  Future<List<String>> listLinkedDocuments(String caseId) async {
    _ensureCase(caseId);
    return List.unmodifiable(_documentLinks[caseId] ?? const <String>{});
  }

  void _ensureCase(String caseId) {
    if (!_cases.containsKey(caseId)) {
      throw StateError('case not found: $caseId');
    }
  }

  CaseWorkspace _toWorkspace(_MutableCase item) {
    return CaseWorkspace(
      id: item.id,
      title: item.title,
      notes: item.notes,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
      archived: item.archived,
      linkedChatCount: _chatLinks[item.id]?.length ?? 0,
      linkedDocumentCount: _documentLinks[item.id]?.length ?? 0,
    );
  }
}

class ObjectBoxCaseRepository implements CaseRepository {
  ObjectBoxCaseRepository({
    required Store store,
    DateTime Function()? clock,
    Uuid? uuid,
  }) : _caseBox = store.box<CaseEntity>(),
       _chatLinkBox = store.box<CaseChatLinkEntity>(),
       _documentLinkBox = store.box<CaseDocumentLinkEntity>(),
       _clock = clock ?? DateTime.now,
       _uuid = uuid ?? const Uuid();

  final Box<CaseEntity> _caseBox;
  final Box<CaseChatLinkEntity> _chatLinkBox;
  final Box<CaseDocumentLinkEntity> _documentLinkBox;
  final DateTime Function() _clock;
  final Uuid _uuid;

  @override
  Future<CaseWorkspace> createCase({String title = 'Új eset'}) async {
    final now = _clock().millisecondsSinceEpoch;
    final entity = CaseEntity(
      publicId: _uuid.v4(),
      title: title.trim().isEmpty ? 'Új eset' : title.trim(),
      notes: '',
      createdAtMillis: now,
      updatedAtMillis: now,
      archived: false,
    );
    _caseBox.put(entity);
    DebugConsole.log('[Cases] created case=${entity.publicId}');
    return _toWorkspace(entity);
  }

  @override
  Future<List<CaseWorkspace>> listCases() async {
    final items = _caseBox
        .getAll()
        .where((item) => !item.archived)
        .map(_toWorkspace)
        .toList(growable: false);
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }

  @override
  Future<CaseWorkspace> updateNotes(String caseId, String notes) async {
    final entity = _findCase(caseId);
    if (entity == null) {
      throw StateError('case not found: $caseId');
    }
    entity.notes = notes;
    entity.updatedAtMillis = _clock().millisecondsSinceEpoch;
    _caseBox.put(entity);
    DebugConsole.log(
      '[Cases] notes updated case=$caseId chars=${notes.length}',
    );
    return _toWorkspace(entity);
  }

  @override
  Future<void> linkChat(String caseId, String chatThreadId) async {
    if (_findCase(caseId) == null) {
      throw StateError('case not found: $caseId');
    }
    if (_chatLinkBox.getAll().any(
      (link) =>
          link.casePublicId == caseId &&
          link.chatThreadPublicId == chatThreadId,
    )) {
      return;
    }
    _chatLinkBox.put(
      CaseChatLinkEntity(
        publicId: _uuid.v4(),
        casePublicId: caseId,
        chatThreadPublicId: chatThreadId,
      ),
    );
    DebugConsole.log('[Cases] chat linked case=$caseId chat=$chatThreadId');
  }

  @override
  Future<void> linkDocument(String caseId, String documentId) async {
    if (_findCase(caseId) == null) {
      throw StateError('case not found: $caseId');
    }
    if (_documentLinkBox.getAll().any(
      (link) =>
          link.casePublicId == caseId && link.documentPublicId == documentId,
    )) {
      return;
    }
    _documentLinkBox.put(
      CaseDocumentLinkEntity(
        publicId: _uuid.v4(),
        casePublicId: caseId,
        documentPublicId: documentId,
      ),
    );
    DebugConsole.log(
      '[Cases] document linked case=$caseId document=$documentId',
    );
  }

  @override
  Future<List<String>> listLinkedChats(String caseId) async {
    if (_findCase(caseId) == null) {
      throw StateError('case not found: $caseId');
    }
    final links =
        _chatLinkBox
            .getAll()
            .where((link) => link.casePublicId == caseId)
            .toList(growable: false)
          ..sort((a, b) => a.id.compareTo(b.id));
    return List.unmodifiable(
      links.map((link) => link.chatThreadPublicId).toList(growable: false),
    );
  }

  @override
  Future<List<String>> listLinkedDocuments(String caseId) async {
    if (_findCase(caseId) == null) {
      throw StateError('case not found: $caseId');
    }
    final links =
        _documentLinkBox
            .getAll()
            .where((link) => link.casePublicId == caseId)
            .toList(growable: false)
          ..sort((a, b) => a.id.compareTo(b.id));
    return List.unmodifiable(
      links.map((link) => link.documentPublicId).toList(growable: false),
    );
  }

  CaseEntity? _findCase(String caseId) {
    for (final item in _caseBox.getAll()) {
      if (item.publicId == caseId) {
        return item;
      }
    }
    return null;
  }

  CaseWorkspace _toWorkspace(CaseEntity entity) {
    return CaseWorkspace(
      id: entity.publicId,
      title: entity.title,
      notes: entity.notes,
      createdAt: DateTime.fromMillisecondsSinceEpoch(entity.createdAtMillis),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(entity.updatedAtMillis),
      archived: entity.archived,
      linkedChatCount: _chatLinkBox
          .getAll()
          .where((link) => link.casePublicId == entity.publicId)
          .length,
      linkedDocumentCount: _documentLinkBox
          .getAll()
          .where((link) => link.casePublicId == entity.publicId)
          .length,
    );
  }
}

class _MutableCase {
  _MutableCase({
    required this.id,
    required this.title,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.archived,
  });

  final String id;
  final String title;
  String notes;
  final DateTime createdAt;
  DateTime updatedAt;
  final bool archived;
}
