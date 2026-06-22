import 'package:flutter/material.dart';

import 'text_chunk_span_controller.dart';

class NativeTextChunkEditor extends StatelessWidget {
  const NativeTextChunkEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.textStyle,
    required this.onSelectionChanged,
  });

  final TextChunkSpanController controller;
  final FocusNode focusNode;
  final TextStyle textStyle;
  final SelectionChangedCallback onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('note-text-native-editor'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      child: EditableText(
        controller: controller,
        focusNode: focusNode,
        style: textStyle,
        cursorColor: const Color(0xFF2563EB),
        backgroundCursorColor: Colors.transparent,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        maxLines: null,
        showSelectionHandles: true,
        selectionColor: const Color(0x552563EB),
        selectionControls: materialTextSelectionHandleControls,
        contextMenuBuilder: (context, editableTextState) =>
            AdaptiveTextSelectionToolbar.editableText(
              editableTextState: editableTextState,
            ),
        onSelectionChanged: onSelectionChanged,
      ),
    );
  }
}
