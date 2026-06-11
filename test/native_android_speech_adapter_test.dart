import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/voice/native_android_speech_adapter.dart';
import 'package:djinn/src/voice/speech_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('test.djinn/native_speech');
  const eventChannel = EventChannel('test.djinn/native_speech_events');

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(methodChannel, null);
    messenger.setMockStreamHandler(eventChannel, null);
  });

  test(
    'stop keeps event stream alive long enough to receive final result',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      MockStreamHandlerEventSink? sink;
      final methodCalls = <String>[];

      messenger.setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(
          onListen: (_, events) {
            sink = events;
            events.success(const {
              'type': 'status',
              'status': 'listening',
            });
          },
        ),
      );
      messenger.setMockMethodCallHandler(methodChannel, (call) async {
        methodCalls.add(call.method);
        if (call.method == 'stop') {
          scheduleMicrotask(() {
            sink?.success(const {
              'type': 'result',
              'text': 'stroke ellatas',
              'final': true,
            });
            sink?.success(const {
              'type': 'status',
              'status': 'done',
            });
          });
        }
        return null;
      });

      final adapter = NativeAndroidSpeechAdapter(
        methodChannel: methodChannel,
        eventChannel: eventChannel,
      );
      final events = <SpeechEvent>[];
      final done = adapter
          .listen(locale: 'hu-HU')
          .listen(events.add)
          .asFuture<void>();

      await Future<void>.delayed(Duration.zero);
      await adapter.stop();
      await done.timeout(const Duration(seconds: 1));

      expect(methodCalls, containsAllInOrder(['start', 'stop']));
      expect(
        events,
        contains(
          isA<SpeechResultEvent>()
              .having((event) => event.text, 'text', 'stroke ellatas')
              .having((event) => event.finalResult, 'finalResult', isTrue),
        ),
      );
    },
  );

  test('no match after partial commits the best partial as final', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    MockStreamHandlerEventSink? sink;

    messenger.setMockStreamHandler(
      eventChannel,
      MockStreamHandler.inline(
        onListen: (_, events) {
          sink = events;
          events.success(const {
            'type': 'status',
            'status': 'listening',
          });
          events.success(const {
            'type': 'result',
            'text': 'mellkasi fajdalom',
            'final': false,
          });
        },
      ),
    );
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      if (call.method == 'stop') {
        scheduleMicrotask(() {
          sink?.success(const {
            'type': 'error',
            'code': 'error_no_match',
          });
          sink?.success(const {
            'type': 'status',
            'status': 'done',
          });
        });
      }
      return null;
    });

    final adapter = NativeAndroidSpeechAdapter(
      methodChannel: methodChannel,
      eventChannel: eventChannel,
    );
    final events = <SpeechEvent>[];
    final done = adapter
        .listen(locale: 'hu-HU')
        .listen(events.add)
        .asFuture<void>();

    await Future<void>.delayed(Duration.zero);
    await adapter.stop();
    await done.timeout(const Duration(seconds: 1));

    expect(
      events,
      contains(
        isA<SpeechResultEvent>()
            .having((event) => event.text, 'text', 'mellkasi fajdalom')
            .having((event) => event.finalResult, 'finalResult', isTrue),
      ),
    );
    expect(events.whereType<SpeechErrorEvent>(), isEmpty);
  });
}
