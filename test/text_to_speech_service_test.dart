import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/debug/debug_console.dart';
import 'package:djinn/src/voice/text_to_speech_service.dart';

void main() {
  setUp(DebugConsole.clear);

  test('does not speak when requested locale is unavailable', () async {
    final driver = FakeTextToSpeechDriver(availableLanguages: const ['en-US']);
    final service = FlutterTextToSpeechService(driver: driver);

    await service.speak(
      text: 'Olvasható válasz.',
      locale: 'hu-HU',
      speechRate: 0.5,
      pitch: 1.0,
    );

    expect(driver.calls, isEmpty);
    expect(DebugConsole.allText, contains('[TTS] language unavailable hu-HU'));
  });

  test('speaks when requested locale is available', () async {
    final driver = FakeTextToSpeechDriver(
      availableLanguages: const ['hu-HU', 'en-US'],
    );
    final service = FlutterTextToSpeechService(driver: driver);

    await service.speak(
      text: 'Olvasható válasz.',
      locale: 'hu-HU',
      speechRate: 0.5,
      pitch: 1.0,
    );

    expect(driver.calls, [
      'language:hu-HU',
      'rate:0.5',
      'pitch:1.0',
      'speak:17',
    ]);
  });
}
