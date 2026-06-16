class LocalVectorChunk {
  const LocalVectorChunk({
    required this.id,
    required this.label,
    required this.text,
  });

  final String id;
  final String label;
  final String text;
}

class LocalVectorSearchResult {
  const LocalVectorSearchResult({
    required this.id,
    required this.score,
  });

  final String id;
  final double score;
}

class LocalVectorSearchService {
  const LocalVectorSearchService();

  List<LocalVectorSearchResult> search({
    required String query,
    required List<LocalVectorChunk> chunks,
    required String mode,
    int limit = 8,
  }) {
    final queryVector = _vectorize(query, mode: mode);
    if (queryVector.isEmpty || chunks.isEmpty || limit <= 0) {
      return const [];
    }
    final scored = <({String id, double score})>[];
    for (final chunk in chunks) {
      final textScore = _cosine(queryVector, _vectorize(chunk.text, mode: mode));
      final labelScore = _cosine(queryVector, _vectorize(chunk.label, mode: mode));
      var score = textScore * 0.88 + labelScore * 0.12;
      if (textScore == 0 && labelScore > 0) {
        score *= 0.35;
      }
      score = _applyNegationFit(query, chunk.text, score);
      if (score > 0) {
        scored.add((id: chunk.id, score: score));
      }
    }
    scored.sort((a, b) {
      final score = b.score.compareTo(a.score);
      if (score != 0) {
        return score;
      }
      return a.id.compareTo(b.id);
    });
    final bestScore = scored.isEmpty ? 0.0 : scored.first.score;
    final threshold = bestScore <= 0 ? 0.0 : bestScore * 0.72;
    return scored
        .where((item) => item.score >= threshold && item.score >= 0.08)
        .take(limit)
        .map((item) => LocalVectorSearchResult(id: item.id, score: item.score))
        .toList(growable: false);
  }

  double _applyNegationFit(String query, String text, double score) {
    if (score <= 0) {
      return score;
    }
    final negated = _negatedTerms(_normalize(query));
    if (negated.isEmpty) {
      return score;
    }
    final normalizedText = _normalize(text);
    var adjusted = score;
    for (final term in negated) {
      if (!_containsTerm(normalizedText, term)) {
        continue;
      }
      if (_hasNegatedTerm(normalizedText, term) ||
          _containsStandaloneNem(normalizedText)) {
        adjusted *= 1.12;
      } else {
        adjusted *= 0.32;
      }
    }
    return adjusted;
  }

  Set<String> _negatedTerms(String normalized) {
    final tokens = normalized
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    final terms = <String>{};
    for (var i = 0; i < tokens.length; i += 1) {
      final token = tokens[i];
      if (token == 'nem' && i + 1 < tokens.length) {
        terms.add(tokens[i + 1]);
      } else if (token.startsWith('nem') && token.length > 5) {
        terms.add(token.substring(3));
      }
    }
    return terms.where((term) => term.length > 2).toSet();
  }

  bool _containsTerm(String normalizedText, String term) {
    final tokens = normalizedText.split(RegExp(r'\s+'));
    return tokens.any((token) => token == term || (term.length >= 4 && token.contains(term)));
  }

  bool _hasNegatedTerm(String normalizedText, String term) {
    final compact = normalizedText.replaceAll(' ', '');
    if (compact.contains('nem$term')) {
      return true;
    }
    final tokens = normalizedText.split(RegExp(r'\s+'));
    for (var i = 0; i < tokens.length - 1; i += 1) {
      if (tokens[i] == 'nem' &&
          (tokens[i + 1] == term ||
              (term.length >= 4 && tokens[i + 1].contains(term)))) {
        return true;
      }
    }
    return false;
  }

  bool _containsStandaloneNem(String normalizedText) {
    return normalizedText.split(RegExp(r'\s+')).contains('nem');
  }

  Map<int, double> _vectorize(String value, {required String mode}) {
    final normalized = _normalize(value);
    if (normalized.isEmpty) {
      return const {};
    }
    final dimensions = _dimensionsFor(mode);
    final features = <int, double>{};
    void add(String feature, double weight) {
      if (feature.trim().isEmpty) {
        return;
      }
      final bucket = _hash('$mode:$feature') % dimensions;
      features[bucket] = (features[bucket] ?? 0) + weight;
    }

    final terms = normalized
        .split(RegExp(r'\s+'))
        .where((term) => term.length > 1)
        .toList(growable: false);
    for (final term in terms) {
      add('term:$term', 2.8);
      if (term.length >= 4) {
        for (var i = 0; i <= term.length - 3; i += 1) {
          add('tri:${term.substring(i, i + 3)}', 0.7);
        }
      }
    }
    for (var i = 0; i < terms.length - 1; i += 1) {
      add('bigram:${terms[i]}_${terms[i + 1]}', 1.4);
    }
    for (var i = 0; i < terms.length - 2; i += 1) {
      add('trigram:${terms[i]}_${terms[i + 1]}_${terms[i + 2]}', 1.9);
    }
    return features;
  }

  int _dimensionsFor(String mode) {
    return switch (mode) {
      'mediapipe_text_embedder' => 512,
      'onnx_multilingual_e5' => 768,
      'embedding_gemma' => 1024,
      _ => 512,
    };
  }

  double _cosine(Map<int, double> a, Map<int, double> b) {
    if (a.isEmpty || b.isEmpty) {
      return 0;
    }
    var dot = 0.0;
    var normA = 0.0;
    var normB = 0.0;
    for (final value in a.values) {
      normA += value * value;
    }
    for (final entry in b.entries) {
      normB += entry.value * entry.value;
      dot += (a[entry.key] ?? 0) * entry.value;
    }
    if (normA == 0 || normB == 0) {
      return 0;
    }
    return dot / (_sqrt(normA) * _sqrt(normB));
  }

  double _sqrt(double value) {
    if (value <= 0) {
      return 0;
    }
    var x = value;
    for (var i = 0; i < 8; i += 1) {
      x = 0.5 * (x + value / x);
    }
    return x;
  }

  int _hash(String value) {
    const offset = 0x811c9dc5;
    const prime = 0x01000193;
    var hash = offset;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * prime) & 0x7fffffff;
    }
    return hash;
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
