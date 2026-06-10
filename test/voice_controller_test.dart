import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/debug/debug_console.dart';
import 'package:djinn/src/voice/speech_adapter.dart';
import 'package:djinn/src/voice/tts_adapter.dart';
import 'package:djinn/src/voice/voice_controller.dart';

void main() {
  setUp(DebugConsole.clear);

  test('speech timeout becomes noSpeech and does not send chat', () async {
    var sent = 0;
    final controller = VoiceController(
      speech: FakeSpeechAdapter(
        events: const [
          SpeechEvent.status('listening'),
          SpeechEvent.error('error_speech_timeout'),
        ],
      ),
      tts: FakeTtsAdapter(),
      onFinalTranscript: (_) async => sent += 1,
    );

    await controller.listenOnce(locale: 'hu-HU');

    expect(controller.state, VoiceState.noSpeech);
    expect(sent, 0);
    expect(
      DebugConsole.allText,
      contains('[Voice/STT] error code=error_speech_timeout'),
    );
  });

  test(
    'empty interim results are ignored and final transcript is sent once',
    () async {
      final sent = <String>[];
      final controller = VoiceController(
        speech: FakeSpeechAdapter(
          events: const [
            SpeechEvent.result('', false),
            SpeechEvent.result('szia', false),
            SpeechEvent.result('szia djinn', true),
            SpeechEvent.result('szia djinn', true),
          ],
        ),
        tts: FakeTtsAdapter(),
        onFinalTranscript: (text) async => sent.add(text),
      );

      await controller.listenOnce(locale: 'hu-HU');

      expect(sent, ['szia djinn']);
      expect(controller.state, VoiceState.idle);
    },
  );

  test('speak does not start duplicate TTS sessions', () async {
    final tts = _BlockingTtsAdapter();
    final controller = VoiceController(
      speech: FakeSpeechAdapter(events: const []),
      tts: tts,
      onFinalTranscript: (_) async {},
    );

    final speaking = controller.speak('valasz', locale: 'hu-HU');
    await Future<void>.delayed(Duration.zero);
    await controller.speak('valasz', locale: 'hu-HU');

    expect(tts.spokenTexts, ['valasz']);
    expect(controller.state, VoiceState.speaking);
    tts.complete();
    await speaking;
  });

  test('completed TTS returns to idle and allows same text again', () async {
    final tts = FakeTtsAdapter();
    final controller = VoiceController(
      speech: FakeSpeechAdapter(events: const []),
      tts: tts,
      onFinalTranscript: (_) async {},
    );

    await controller.speak('valasz', locale: 'hu-HU');
    await controller.speak('valasz', locale: 'hu-HU');

    expect(tts.spokenTexts, ['valasz', 'valasz']);
    expect(controller.state, VoiceState.idle);
  });

  test('failed final transcript send recovers to error state', () async {
    final controller = VoiceController(
      speech: FakeSpeechAdapter(
        events: const [SpeechEvent.result('kerdes', true)],
      ),
      tts: FakeTtsAdapter(),
      onFinalTranscript: (_) async => throw StateError('send failed'),
    );

    await controller.listenOnce(locale: 'hu-HU');

    expect(controller.state, VoiceState.error);
  });

  test('stop TTS is silent when already idle', () async {
    final tts = FakeTtsAdapter();
    final controller = VoiceController(
      speech: FakeSpeechAdapter(events: const []),
      tts: tts,
      onFinalTranscript: (_) async {},
    );

    await controller.stopTts();

    expect(tts.stopCount, 0);
    expect(DebugConsole.allText, isNot(contains('[Voice/TTS] stop')));
  });

  test('pause and resume TTS controls state', () async {
    final tts = _BlockingTtsAdapter();
    final controller = VoiceController(
      speech: FakeSpeechAdapter(events: const []),
      tts: tts,
      onFinalTranscript: (_) async {},
    );

    final speaking = controller.speak('valasz', locale: 'hu-HU');
    await Future<void>.delayed(Duration.zero);
    await controller.pauseTts();

    expect(controller.state, VoiceState.paused);
    expect(tts.pauseCount, 1);

    tts.complete();
    await speaking;
  });

  test('listening stops active TTS before recording speech', () async {
    final tts = _BlockingTtsAdapter();
    final controller = VoiceController(
      speech: FakeSpeechAdapter(
        events: const [SpeechEvent.result('uj kerdes', true)],
      ),
      tts: tts,
      onFinalTranscript: (_) async {},
    );

    final speaking = controller.speak('elozo valasz', locale: 'hu-HU');
    await Future<void>.delayed(Duration.zero);
    await controller.listenOnce(locale: 'hu-HU');

    expect(tts.stopCount, 1);
    tts.complete();
    await speaking;
  });

  test('dispose stops active speech recognition', () {
    final speech = FakeSpeechAdapter(events: const []);
    final controller = VoiceController(
      speech: speech,
      tts: FakeTtsAdapter(),
      onFinalTranscript: (_) async {},
    );

    controller.dispose();

    expect(speech.stopCount, 1);
  });
}

class _BlockingTtsAdapter extends FakeTtsAdapter {
  final _completion = Completer<void>();

  @override
  Future<void> speak(
    String text, {
    required String locale,
    double rate = 0.5,
    double pitch = 1.0,
  }) async {
    spokenTexts.add(text);
    await _completion.future;
  }

  void complete() {
    if (!_completion.isCompleted) {
      _completion.complete();
    }
  }
}
