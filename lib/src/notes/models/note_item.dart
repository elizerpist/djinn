import '../../knowledge/models/local_extraction.dart';
import 'note_document.dart';

enum NoteItemType {
  document('document'),
  text('text'),
  table('table'),
  flowchart('flowchart');

  const NoteItemType(this.wireName);

  final String wireName;

  static NoteItemType fromWireName(String? value) {
    return NoteItemType.values.firstWhere(
      (item) => item.wireName == value,
      orElse: () => NoteItemType.text,
    );
  }

  String get label {
    return switch (this) {
      NoteItemType.document => 'Jegyzet',
      NoteItemType.text => 'Szöveg',
      NoteItemType.table => 'Táblázat',
      NoteItemType.flowchart => 'Flowchart',
    };
  }
}

class NoteItem {
  const NoteItem({
    required this.id,
    required this.type,
    required this.title,
    required this.plainText,
    required this.payloadJson,
    required this.auditState,
    required this.createdAt,
    required this.updatedAt,
    this.folderId,
    this.reason,
  });

  final String id;
  final String? folderId;
  final NoteItemType type;
  final String title;
  final String plainText;
  final String payloadJson;
  final LocalAuditState auditState;
  final String? reason;
  final DateTime createdAt;
  final DateTime updatedAt;

  NoteDocument get document => NoteDocument.fromPayload(
        payloadJson,
        legacyType: type.wireName,
        legacyText: plainText,
        title: title,
      );

  String get preview => document.preview.isEmpty ? plainText : document.preview;

  bool get ragEligible =>
      auditState == LocalAuditState.accepted ||
      auditState == LocalAuditState.edited;

  bool get citationEligible => ragEligible;

  NoteItem copyWith({
    String? folderId,
    bool clearFolderId = false,
    NoteItemType? type,
    String? title,
    String? plainText,
    String? payloadJson,
    LocalAuditState? auditState,
    String? reason,
    bool clearReason = false,
    DateTime? updatedAt,
  }) {
    return NoteItem(
      id: id,
      folderId: clearFolderId ? null : folderId ?? this.folderId,
      type: type ?? this.type,
      title: title ?? this.title,
      plainText: plainText ?? this.plainText,
      payloadJson: payloadJson ?? this.payloadJson,
      auditState: auditState ?? this.auditState,
      reason: clearReason ? null : reason ?? this.reason,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  NoteItem copyWithDocument({
    required NoteDocument document,
    String? title,
    LocalAuditState? auditState,
    String? reason,
    bool clearReason = false,
    DateTime? updatedAt,
  }) {
    return copyWith(
      type: NoteItemType.document,
      title: title,
      plainText: document.plainText,
      payloadJson: document.toPayloadJson(),
      auditState: auditState,
      reason: reason,
      clearReason: clearReason,
      updatedAt: updatedAt,
    );
  }

  factory NoteItem.fromJson(Map<String, Object?> json) {
    return NoteItem(
      id: json['id'] as String,
      folderId: json['folderId'] as String?,
      type: NoteItemType.fromWireName(json['type'] as String?),
      title: json['title'] as String? ?? '',
      plainText: json['plainText'] as String? ?? '',
      payloadJson: json['payloadJson'] as String? ?? '{}',
      auditState: LocalAuditState.fromWireName(json['auditState'] as String?),
      reason: json['reason'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      if (folderId != null) 'folderId': folderId,
      'type': type.wireName,
      'title': title,
      'plainText': plainText,
      'payloadJson': payloadJson,
      'auditState': auditState.wireName,
      if (reason != null) 'reason': reason,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
