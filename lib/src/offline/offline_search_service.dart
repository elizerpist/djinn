class OfflineChunk {
  const OfflineChunk({
    required this.id,
    required this.label,
    required this.text,
  });

  final String id;
  final String label;
  final String text;
}

class OfflineSearchResult {
  const OfflineSearchResult({
    required this.id,
    required this.label,
    required this.excerpt,
    this.generatedAnswer = false,
  });

  final String id;
  final String label;
  final String excerpt;
  final bool generatedAnswer;
}

class OfflineSearchService {
  const OfflineSearchService();

  List<OfflineSearchResult> search({
    required String query,
    required List<OfflineChunk> chunks,
    int limit = 8,
  }) {
    final terms = _terms(query);
    if (terms.isEmpty) {
      return const [];
    }
    final scored = <({OfflineChunk chunk, int score})>[];
    for (final chunk in chunks) {
      final text = _normalize(chunk.text);
      final score = terms.where(text.contains).length;
      if (score > 0) {
        scored.add((chunk: chunk, score: score));
      }
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored
        .take(limit)
        .map((item) {
          return OfflineSearchResult(
            id: item.chunk.id,
            label: item.chunk.label,
            excerpt: item.chunk.text,
          );
        })
        .toList(growable: false);
  }

  List<String> _terms(String query) {
    return _normalize(query)
        .split(RegExp(r'\s+'))
        .where((term) => term.length > 2)
        .toSet()
        .toList(growable: false);
  }

  String _normalize(String value) {
    return value.toLowerCase().trim();
  }
}
