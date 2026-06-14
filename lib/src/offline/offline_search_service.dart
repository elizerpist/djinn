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
    final phrase = _normalize(query);
    final documentFrequencies = <String, int>{};
    for (final term in terms) {
      documentFrequencies[term] = chunks.where((chunk) {
        final normalized = _normalize('${chunk.label} ${chunk.text}');
        return normalized.contains(term);
      }).length;
    }

    final scored = <({OfflineChunk chunk, double score})>[];
    for (final chunk in chunks) {
      final label = _normalize(chunk.label);
      final text = _normalize(chunk.text);
      final combined = '$label $text';
      var score = 0.0;
      for (final term in terms) {
        final occurrences = _occurrences(combined, term);
        if (occurrences == 0) {
          continue;
        }
        final df = documentFrequencies[term] ?? 1;
        final idf = 1 + (chunks.length / (1 + df));
        final labelBoost = label.contains(term) ? 1.8 : 1.0;
        score += occurrences * idf * labelBoost;
      }
      if (phrase.length > 8 && text.contains(phrase)) {
        score += terms.length * 4;
      }
      if (score > 0) {
        scored.add((chunk: chunk, score: score));
      }
    }
    scored.sort((a, b) {
      final score = b.score.compareTo(a.score);
      if (score != 0) {
        return score;
      }
      return a.chunk.label.compareTo(b.chunk.label);
    });
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

  int _occurrences(String text, String term) {
    var count = 0;
    var start = 0;
    while (true) {
      final index = text.indexOf(term, start);
      if (index == -1) {
        return count;
      }
      count += 1;
      start = index + term.length;
    }
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ő', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ű', 'u')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }
}
