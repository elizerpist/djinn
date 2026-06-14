import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/offline/offline_search_service.dart';

void main() {
  test('returns source excerpts without generated answer', () {
    final service = OfflineSearchService();
    final results = service.search(
      query: 'thrombectomia',
      chunks: const [
        OfflineChunk(
          id: 'c1',
          label: '1. oldal',
          text: 'Thrombectomia indikaciok reszletezese.',
        ),
        OfflineChunk(id: 'c2', label: '2. oldal', text: 'Mas tema.'),
      ],
    );

    expect(results.single.id, 'c1');
    expect(results.single.generatedAnswer, isFalse);
  });

  test('boosts repeated terms and label matches for BM25-like ranking', () {
    final service = OfflineSearchService();
    final results = service.search(
      query: 'oxigen terapia',
      chunks: const [
        OfflineChunk(
          id: 'weak',
          label: 'Egyeb ellatas',
          text: 'Oxigen egyszer szerepel ebben a reszben.',
        ),
        OfflineChunk(
          id: 'strong',
          label: 'Oxigen terapia',
          text: 'Oxigen terapia celja. Oxigen adasa es terapia kovetese.',
        ),
      ],
    );

    expect(results.first.id, 'strong');
  });

}
