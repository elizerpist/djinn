import 'package:flutter/material.dart';

import '../../chat/models/chat_citation.dart';

class SourcePageScreen extends StatelessWidget {
  const SourcePageScreen({super.key, required this.citation});

  final ChatCitation citation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(citation.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (citation.page != null)
            Text(
              '${citation.page}. oldal',
              style: const TextStyle(
                color: Color(0xFF374151),
                fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(height: 12),
          if (citation.sourceLabel != null)
            Chip(label: Text(citation.sourceLabel!)),
          const SizedBox(height: 12),
          Text(
            citation.excerpt,
            style: const TextStyle(fontSize: 15, height: 1.4),
          ),
        ],
      ),
    );
  }
}
