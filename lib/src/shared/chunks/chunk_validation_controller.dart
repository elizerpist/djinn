import '../../knowledge/models/local_extraction.dart';

enum ChunkValidationChoice { review, accept, reject }

extension ChunkValidationChoiceMapping on ChunkValidationChoice {
  LocalAuditState get auditState {
    return switch (this) {
      ChunkValidationChoice.review => LocalAuditState.unreviewed,
      ChunkValidationChoice.accept => LocalAuditState.accepted,
      ChunkValidationChoice.reject => LocalAuditState.rejected,
    };
  }

  static ChunkValidationChoice fromAuditState(LocalAuditState state) {
    return switch (state) {
      LocalAuditState.accepted || LocalAuditState.edited =>
        ChunkValidationChoice.accept,
      LocalAuditState.rejected => ChunkValidationChoice.reject,
      LocalAuditState.unreviewed => ChunkValidationChoice.review,
    };
  }

  String get label {
    return switch (this) {
      ChunkValidationChoice.review => 'Review',
      ChunkValidationChoice.accept => 'Elfogad',
      ChunkValidationChoice.reject => 'Elutasít',
    };
  }
}

class ChunkValidationResult {
  const ChunkValidationResult({
    required this.auditState,
    required this.text,
    this.reason,
  });

  final LocalAuditState auditState;
  final String text;
  final String? reason;
}
