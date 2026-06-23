import 'dart:math' as math;
import 'dart:ui';

import '../../ai/ai_client.dart';
import 'note_document.dart';

const double noteFlowchartEditorUnitToPdfPoint = 72 / 160;

String noteFlowchartDefaultNodeLabel(NoteFlowchartNode node) {
  return switch (node.kind) {
    NoteFlowchartNodeKind.binaryDecision => 'Döntés?',
    NoteFlowchartNodeKind.multiDecision => 'Többágú döntés',
    NoteFlowchartNodeKind.universal => switch (node.role) {
      NoteFlowchartNodeRole.start => 'Kezdés',
      NoteFlowchartNodeRole.end => 'Vége',
      NoteFlowchartNodeRole.normal => 'Folyamatlépés',
    },
  };
}

Size noteFlowchartEditorNodeSize(NoteFlowchartNode node) {
  final text = node.label.trim().isEmpty
      ? noteFlowchartDefaultNodeLabel(node)
      : node.label.trim();
  final explicitLines = text.split('\n');
  final longestLine = explicitLines.fold<int>(
    0,
    (max, line) => math.max(max, line.length),
  );
  final width = (188 + longestLine * 3.8).clamp(210.0, 370.0).toDouble();
  var estimatedLines = 0;
  final charsPerLine = math.max(16, ((width - 76) / 7.2).floor());
  for (final line in explicitLines) {
    estimatedLines += math.max(1, (line.length / charsPerLine).ceil());
  }
  final minHeight =
      node.kind == NoteFlowchartNodeKind.binaryDecision ||
          node.kind == NoteFlowchartNodeKind.multiDecision ||
          node.shape == AiFlowchartNodeShape.decision
      ? 96.0
      : 78.0;
  final height = (48 + estimatedLines * 20.0)
      .clamp(minHeight, 240.0)
      .toDouble();
  return Size(width, height);
}
