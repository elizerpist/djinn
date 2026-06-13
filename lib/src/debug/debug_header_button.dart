import 'package:flutter/material.dart';

import 'debug_console.dart';

class DebugHeaderButton extends StatelessWidget {
  const DebugHeaderButton({super.key, this.navigatorKey});

  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey('debug-header-button'),
      tooltip: 'Debug log',
      onPressed: () {
        final navContext = navigatorKey?.currentContext ?? context;
        showDialog<void>(
          context: navContext,
          builder: (_) => const DebugConsoleDialog(),
        );
      },
      icon: const Icon(Icons.bug_report_outlined),
    );
  }
}
