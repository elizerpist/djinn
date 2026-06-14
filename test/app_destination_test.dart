import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/chat/ui/app_destination.dart';

void main() {
  test('bottom navigation exposes four destinations without search', () {
    expect(appDestinations.map((destination) => destination.id), [
      AppDestinationId.notes,
      AppDestinationId.knowledge,
      AppDestinationId.chat,
      AppDestinationId.settings,
    ]);
    expect(appDestinations.map((destination) => destination.label), isNot(contains('Keresés')));
  });
}
