import 'package:flutter_tts/flutter_tts.dart';

import '../debug/debug_console.dart';

abstract class TextToSpeechDriver {
  Future<List<String>> languages();
  Future<void> setLanguage(String locale);
  Future<void> setSpeechRate(double rate);
  Future<void> setPitch(double pitch);
  Future<void> speak(String text);
  Future<void> pause();
  Future<void> stop();
}

abstract class TextToSpeechService {
  Future<void> speak({
    required String text,
    required String locale,
    required double speechRate,
    required double pitch,
  });

  Future<void> pause();
  Future<void> stop();
}

class FakeTextToSpeechDriver implements TextToSpeechDriver {
  FakeTextToSpeechDriver({required this.availableLanguages});

  final List<String> availableLanguages;
  final calls = <String>[];

  @override
  Future<List<String>> languages() async => availableLanguages;

  @override
  Future<void> setLanguage(String locale) async {
    calls.add('language:$locale');
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    calls.add('rate:$rate');
  }

  @override
  Future<void> setPitch(double pitch) async {
    calls.add('pitch:$pitch');
  }

  @override
  Future<void> speak(String text) async {
    calls.add('speak:${text.length}');
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
  }
}

class FakeTextToSpeechService implements TextToSpeechService {
  final calls = <String>[];

  @override
  Future<void> speak({
    required String text,
    required String locale,
    required double speechRate,
    required double pitch,
  }) async {
    calls.add('speak:$locale:${text.length}');
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
  }
}

class FlutterTextToSpeechService implements TextToSpeechService {
  FlutterTextToSpeechService({
    FlutterTts? flutterTts,
    TextToSpeechDriver? driver,
  }) : _driver = driver ?? _FlutterTtsDriver(flutterTts ?? FlutterTts());

  final TextToSpeechDriver _driver;

  @override
  Future<void> speak({
    required String text,
    required String locale,
    required double speechRate,
    required double pitch,
  }) async {
    final languages = await _driver.languages();
    if (!languages.contains(locale)) {
      DebugConsole.log('[TTS] language unavailable $locale');
      return;
    }
    await _driver.setLanguage(locale);
    await _driver.setSpeechRate(speechRate);
    await _driver.setPitch(pitch);
    DebugConsole.log(
      '[Voice/TTS] speak chars=${text.length} locale=$locale rate=$speechRate pitch=$pitch',
    );
    await _driver.speak(text);
  }

  @override
  Future<void> pause() async {
    DebugConsole.log('[Voice/TTS] pause');
    await _driver.pause();
  }

  @override
  Future<void> stop() async {
    DebugConsole.log('[Voice/TTS] stop');
    await _driver.stop();
  }
}

class _FlutterTtsDriver implements TextToSpeechDriver {
  _FlutterTtsDriver(this._flutterTts);

  final FlutterTts _flutterTts;

  @override
  Future<List<String>> languages() async {
    final result = await _flutterTts.getLanguages;
    if (result is List) {
      return result.map((item) => item.toString()).toList(growable: false);
    }
    return const [];
  }

  @override
  Future<void> setLanguage(String locale) async {
    await _flutterTts.setLanguage(locale);
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    await _flutterTts.setSpeechRate(rate);
  }

  @override
  Future<void> setPitch(double pitch) async {
    await _flutterTts.setPitch(pitch);
  }

  @override
  Future<void> speak(String text) async {
    await _flutterTts.speak(text);
  }

  @override
  Future<void> pause() async {
    await _flutterTts.pause();
  }

  @override
  Future<void> stop() async {
    await _flutterTts.stop();
  }
}
