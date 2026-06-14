import '../models/editable_flowchart.dart';

abstract class FlowchartEditRepository {
  Future<EditableFlowchart?> loadEditableFlowchart({
    required String documentId,
    required String flowchartId,
  });

  Future<void> saveEditableFlowchart(EditableFlowchart flowchart);
}
