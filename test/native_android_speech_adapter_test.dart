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
              'sessionId': 42,
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
              'sessionId': 42,
              'text': 'stroke ellatas',
              'final': true,
            });
            sink?.success(const {
              'type': 'status',
              'sessionId': 42,
              'status': 'done',
            });
          });
        }
        if (call.method == 'start') {
          return <String, Object?>{'sessionId': 42, 'locale': 'hu-HU'};
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
            'sessionId': 42,
            'status': 'listening',
          });
          events.success(const {
            'type': 'result',
            'sessionId': 42,
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
            'sessionId': 42,
            'code': 'error_no_match',
          });
          sink?.success(const {
            'type': 'status',
            'sessionId': 42,
            'status': 'done',
          });
        });
      }
      if (call.method == 'start') {
        return <String, Object?>{'sessionId': 42, 'locale': 'hu-HU'};
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

  test('passes Android silence timing options to native recognizer', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    Map<Object?, Object?>? startArguments;

    messenger.setMockStreamHandler(
      eventChannel,
      MockStreamHandler.inline(onListen: (_, __) {}),
    );
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      if (call.method == 'start') {
        startArguments = (call.arguments as Map).cast<Object?, Object?>();
        return <String, Object?>{'sessionId': 42, 'locale': 'hu-HU'};
      }
      return null;
    });

    final adapter = NativeAndroidSpeechAdapter(
      methodChannel: methodChannel,
      eventChannel: eventChannel,
      completeSilenceTimeout: const Duration(milliseconds: 3500),
      possibleCompleteSilenceTimeout: const Duration(milliseconds: 2200),
      minimumSpeechLength: const Duration(milliseconds: 1200),
    );
    final subscription = adapter.listen(locale: 'hu-HU').listen((_) {});

    await Future<void>.delayed(Duration.zero);

    expect(startArguments, isNotNull);
    expect(startArguments!['locale'], 'hu-HU');
    expect(startArguments!['completeSilenceMillis'], 3500);
    expect(startArguments!['possibleCompleteSilenceMillis'], 2200);
    expect(startArguments!['minimumSpeechMillis'], 1200);

    await subscription.cancel();
  });
}
