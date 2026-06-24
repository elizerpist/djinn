import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('android workflow publishes traceable APK builds', () {
    final workflow = File(
      '.github/workflows/android-native-build.yml',
    ).readAsStringSync();

    expect(workflow, contains('--dart-define=DJINN_BUILD_SHA'));
    expect(workflow, contains(r'djinn-debug-${SHORT_SHA}.apk'));
    expect(workflow, contains('Direct SHA APK link'));
  });
}
