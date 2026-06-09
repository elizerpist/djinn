import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DebugConsole {
  DebugConsole._();

  static const _maxEntries = 500;
  static final List<String> _entries = <String>[];
  static final ValueNotifier<int> _version = ValueNotifier<int>(0);

  static void log(String message) {
    final now = DateTime.now();
    final stamp =
        '[${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}.'
        '${(now.millisecond ~/ 10).toString().padLeft(2, '0')}]';
    if (_entries.length >= _maxEntries) {
      _entries.removeAt(0);
    }
    _entries.add('$stamp $message');
    _version.value += 1;
  }

  static void clear() {
    _entries.clear();
    _version.value += 1;
  }

  static List<String> get entries => List.unmodifiable(_entries);

  static String get allText => _entries.join('\n');

  static ValueNotifier<int> get notifier => _version;
}

class DebugConsoleDialog extends StatefulWidget {
  const DebugConsoleDialog({super.key});

  @override
  State<DebugConsoleDialog> createState() => _DebugConsoleDialogState();
}

class _DebugConsoleDialogState extends State<DebugConsoleDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _controller.text = DebugConsole.allText;
    DebugConsole.notifier.addListener(_refresh);
  }

  @override
  void dispose() {
    DebugConsole.notifier.removeListener(_refresh);
    _controller.dispose();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) {
      return;
    }
    final text = DebugConsole.allText;
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    setState(() {});
  }

  Future<void> _copyAll() async {
    if (_controller.text.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: _controller.text));
    if (!mounted) {
      return;
    }
    setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final count = DebugConsole.entries.length;
    return Dialog(
      backgroundColor: const Color(0xFF111827),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 40),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.terminal,
                    size: 16,
                    color: Color(0xFF38BDF8),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Debug Console',
                    style: TextStyle(
                      color: Color(0xFFE5E7EB),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '($count)',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    key: const ValueKey('debug-console-copy'),
                    onPressed: count == 0 ? null : _copyAll,
                    icon: Icon(
                      _copied ? Icons.check : Icons.copy_outlined,
                      size: 16,
                    ),
                    color: _copied
                        ? const Color(0xFF22C55E)
                        : const Color(0xFF93C5FD),
                    tooltip: 'Copy debug log',
                  ),
                  IconButton(
                    key: const ValueKey('debug-console-clear'),
                    onPressed: count == 0 ? null : DebugConsole.clear,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    color: const Color(0xFFF87171),
                    tooltip: 'Clear debug log',
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 16),
                    color: const Color(0xFFCBD5E1),
                    tooltip: 'Close debug log',
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF374151)),
            Flexible(
              child: count == 0
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Meg nincs debug log.',
                        style: TextStyle(color: Color(0xFF94A3B8)),
                      ),
                    )
                  : TextField(
                      controller: _controller,
                      readOnly: true,
                      maxLines: null,
                      style: const TextStyle(
                        color: Color(0xFFE5E7EB),
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                        height: 1.45,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(14),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
