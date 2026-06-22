import 'package:flutter/material.dart';

import '../../models/note_document.dart';
import 'text_chunk_controller.dart';
import 'text_chunk_underlines.dart';

class NativeTextChunkEditor extends StatelessWidget {
  const NativeTextChunkEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.rangeTags,
    required this.textStyle,
    required this.onSelectionChanged,
  });

  final TextChunkEditingController controller;
  final FocusNode focusNode;
  final List<NoteTextRangeTag> rangeTags;
  final TextStyle textStyle;
  final SelectionChangedCallback onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    return _NativeTextChunkEditorBody(
      controller: controller,
      focusNode: focusNode,
      rangeTags: rangeTags,
      textStyle: textStyle,
      onSelectionChanged: onSelectionChanged,
    );
  }
}

class _NativeTextChunkEditorBody extends StatefulWidget {
  const _NativeTextChunkEditorBody({
    required this.controller,
    required this.focusNode,
    required this.rangeTags,
    required this.textStyle,
    required this.onSelectionChanged,
  });

  final TextChunkEditingController controller;
  final FocusNode focusNode;
  final List<NoteTextRangeTag> rangeTags;
  final TextStyle textStyle;
  final SelectionChangedCallback onSelectionChanged;

  @override
  State<_NativeTextChunkEditorBody> createState() =>
      _NativeTextChunkEditorBodyState();
}

class _NativeTextChunkEditorBodyState
    extends State<_NativeTextChunkEditorBody> {
  final _editableKey = GlobalKey<EditableTextState>();

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final focusNode = widget.focusNode;
    final rangeTags = widget.rangeTags;
    final textStyle = widget.textStyle;
    final onSelectionChanged = widget.onSelectionChanged;
    controller.configureTextChunkPresentation(rangeTags: rangeTags);
    final underlineLanes = textChunkSecondaryUnderlineLaneCount(rangeTags);
    final fontSize = textStyle.fontSize ?? 16;
    final strutStyle = underlineLanes > 0
        ? StrutStyle(
            fontSize: fontSize,
            height:
                (fontSize +
                    (underlineLanes * textChunkUnderlineLaneHeight) +
                    textChunkUnderlineTopGap) /
                fontSize,
            forceStrutHeight: true,
          )
        : null;
    return GestureDetector(
      key: const ValueKey('note-text-chunk-field'),
      behavior: HitTestBehavior.translucent,
      onTap: focusNode.requestFocus,
      child: SingleChildScrollView(
        key: const ValueKey('note-text-scroll'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              key: const ValueKey('note-text-native-editor'),
              children: [
                EditableText(
                  key: _editableKey,
                  controller: controller,
                  focusNode: focusNode,
                  style: textStyle,
                  cursorColor: const Color(0xFF2563EB),
                  backgroundCursorColor: Colors.transparent,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  maxLines: null,
                  strutStyle: strutStyle,
                  showSelectionHandles: true,
                  selectionColor: const Color(0x552563EB),
                  selectionControls: materialTextSelectionHandleControls,
                  contextMenuBuilder: (context, editableTextState) =>
                      AdaptiveTextSelectionToolbar.editableText(
                        editableTextState: editableTextState,
                      ),
                  onSelectionChanged: onSelectionChanged,
                ),
                Positioned.fill(
                  child: TextChunkSecondaryUnderlineOverlay(
                    editableKey: _editableKey,
                    rangeTags: rangeTags,
                    textLength: controller.text.length,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
