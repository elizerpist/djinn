import 'package:flutter/material.dart';

import 'debug_console.dart';

class DebugFloatingButton extends StatelessWidget {
  const DebugFloatingButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 92,
      child: Material(
        color: const Color(0xFF1E293B),
        elevation: 8,
        shape: const CircleBorder(),
        child: IconButton(
          key: const ValueKey('debug-floating-button'),
          tooltip: 'Debug log',
          icon: const Icon(Icons.terminal, size: 18, color: Color(0xFF38BDF8)),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => const DebugConsoleDialog(),
          ),
        ),
      ),
    );
  }
}
