import 'package:flutter_tts/flutter_tts.dart';

abstract class TtsAdapter {
  Future<bool> isLanguageAvailable(String locale);

  Future<void> speak(
    String text, {
    required String locale,
    double rate = 0.5,
    double pitch = 1.0,
  });

  Future<void> pause();

  Future<void> stop();
}

class FlutterTtsAdapter implements TtsAdapter {
  FlutterTtsAdapter({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;

  @override
  Future<bool> isLanguageAvailable(String locale) async {
    final result = await _tts.isLanguageAvailable(locale);
    return result == true || result == 1;
  }

  @override
  Future<void> speak(
    String text, {
    required String locale,
    double rate = 0.5,
    double pitch = 1.0,
  }) async {
    await _tts.awaitSpeakCompletion(true);
    await _tts.setLanguage(locale);
    await _tts.setSpeechRate(rate);
    await _tts.setPitch(pitch);
    await _tts.speak(text);
  }

  @override
  Future<void> pause() => _tts.pause();

  @override
  Future<void> stop() => _tts.stop();
}

class FakeTtsAdapter implements TtsAdapter {
  final spokenTexts = <String>[];
  var stopCount = 0;
  var pauseCount = 0;
  var available = true;

  @override
  Future<bool> isLanguageAvailable(String locale) async => available;

  @override
  Future<void> speak(
    String text, {
    required String locale,
    double rate = 0.5,
    double pitch = 1.0,
  }) async {
    spokenTexts.add(text);
  }

  @override
  Future<void> pause() async {
    pauseCount += 1;
  }

  @override
  Future<void> stop() async {
    stopCount += 1;
  }
}
