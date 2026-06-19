import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/note_document.dart';
import 'text_chunk_web_editor_html.dart';

class NoteTextChunkWebEditor extends StatefulWidget {
  const NoteTextChunkWebEditor({
    super.key,
    required this.block,
    required this.onTextChanged,
    required this.onRangeTagsChanged,
    required this.onTagRequested,
  });

  final NoteBlock block;
  final ValueChanged<String> onTextChanged;
  final ValueChanged<List<NoteTextRangeTag>> onRangeTagsChanged;
  final Future<List<NoteKnowledgeTag>?> Function(
    TextRange range,
    List<NoteKnowledgeTag> initialTags,
  )
  onTagRequested;

  static bool get isPlatformAvailable => WebViewPlatform.instance != null;

  @override
  State<NoteTextChunkWebEditor> createState() => _NoteTextChunkWebEditorState();
}

class _NoteTextChunkWebEditorState extends State<NoteTextChunkWebEditor> {
  late final WebViewController _controller;
  late String _loadedHtml;

  @override
  void initState() {
    super.initState();
    _loadedHtml = buildTextChunkWebEditorHtml(widget.block);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'NoteBridge',
        onMessageReceived: _handleBridgeMessage,
      )
      ..loadHtmlString(_loadedHtml);
  }

  @override
  void didUpdateWidget(NoteTextChunkWebEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.id != widget.block.id) {
      _loadedHtml = buildTextChunkWebEditorHtml(widget.block);
      _controller.loadHtmlString(_loadedHtml);
    }
  }

  Future<void> _handleBridgeMessage(JavaScriptMessage message) async {
    final decoded = jsonDecode(message.message);
    if (decoded is! Map<String, Object?>) {
      return;
    }
    switch (decoded['type']) {
      case 'textChanged':
        widget.onTextChanged(decoded['text']?.toString() ?? '');
        break;
      case 'rangeTagsChanged':
        widget.onRangeTagsChanged(_rangeTagsFromBridge(decoded['rangeTags']));
        break;
      case 'tagRequest':
        final range = _rangeFromBridge(decoded['range']);
        if (range == null) {
          return;
        }
        final tags = await widget.onTagRequested(
          range,
          _tagsFromBridge(decoded['tags']),
        );
        if (tags == null || tags.isEmpty) {
          return;
        }
        final encodedTags = jsonEncode([
          for (final tag in tags)
            {
              'type': NoteKnowledgeTagTypes.normalize(tag.type),
              'label': tag.label,
              'colorValue': tag.resolvedColorValue,
              'colorHex':
                  '0x${tag.resolvedColorValue.toRadixString(16).padLeft(8, '0').toUpperCase()}',
            },
        ]);
        await _controller.runJavaScript(
          'window.DjinnEditor.applyTags(${jsonEncode(encodedTags)});',
        );
        break;
    }
  }

  TextRange? _rangeFromBridge(Object? value) {
    if (value is! Map) {
      return null;
    }
    final start = value['start'];
    final end = value['end'];
    if (start is! num || end is! num || end <= start) {
      return null;
    }
    return TextRange(start: start.toInt(), end: end.toInt());
  }

  List<NoteTextRangeTag> _rangeTagsFromBridge(Object? value) {
    if (value is! List) {
      return const [];
    }
    return [
      for (final raw in value)
        if (raw is Map)
          NoteTextRangeTag(
            id: raw['id']?.toString() ?? 'range-1',
            start: raw['start'] is num ? (raw['start'] as num).toInt() : 0,
            end: raw['end'] is num ? (raw['end'] as num).toInt() : 0,
            tag: _tagsFromBridge(raw['tags']).isEmpty
                ? const NoteKnowledgeTag(
                    type: NoteKnowledgeTagTypes.custom,
                    label: '',
                  )
                : _tagsFromBridge(raw['tags']).first,
            tags: _tagsFromBridge(raw['tags']),
          ),
    ].where((tag) => tag.isValid).toList(growable: false);
  }

  List<NoteKnowledgeTag> _tagsFromBridge(Object? value) {
    if (value is! List) {
      return const [];
    }
    return [
      for (final raw in value)
        if (raw is Map)
          NoteKnowledgeTag(
            type: NoteKnowledgeTagTypes.normalize(raw['type']?.toString()),
            label: raw['label']?.toString() ?? '',
            colorValue: raw['colorValue'] is num
                ? (raw['colorValue'] as num).toInt()
                : null,
          ),
    ].where((tag) => tag.label.trim().isNotEmpty).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(
      key: const ValueKey('note-text-web-editor'),
      controller: _controller,
    );
  }
}
