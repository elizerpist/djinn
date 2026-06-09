import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android manifest declares voice and TTS capabilities', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android.permission.RECORD_AUDIO'));
    expect(manifest, contains('android.speech.RecognitionService'));
    expect(manifest, contains('android.intent.action.TTS_SERVICE'));
  });
}
