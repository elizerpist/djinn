import 'package:djinn/src/debug/debug_console.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(DebugConsole.clear);

  test('records timestamped entries and notifies listeners', () {
    var notifications = 0;
    void listener() => notifications += 1;
    DebugConsole.notifier.addListener(listener);
    addTearDown(() => DebugConsole.notifier.removeListener(listener));

    DebugConsole.log('[OpenAI] key test started');

    expect(DebugConsole.entries, hasLength(1));
    expect(DebugConsole.entries.single, contains('[OpenAI] key test started'));
    expect(
      DebugConsole.entries.single,
      matches(r'^\[\d{2}:\d{2}:\d{2}\.\d{2}\] '),
    );
    expect(notifications, 1);
  });

  test('keeps only newest 500 entries and clears all text', () {
    for (var i = 0; i < 520; i += 1) {
      DebugConsole.log('row $i');
    }

    expect(DebugConsole.entries, hasLength(500));
    expect(DebugConsole.entries.first, contains('row 20'));
    expect(DebugConsole.entries.last, contains('row 519'));

    DebugConsole.clear();

    expect(DebugConsole.entries, isEmpty);
    expect(DebugConsole.allText, '');
  });
}
