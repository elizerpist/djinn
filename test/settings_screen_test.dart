import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:djinn/src/debug/debug_console.dart';
import 'package:djinn/src/settings/data/api_key_store.dart';
import 'package:djinn/src/settings/models/app_settings.dart';
import 'package:djinn/src/settings/ui/settings_screen.dart';

void main() {
  setUp(DebugConsole.clear);

  testWidgets('saves and deletes OpenAI API key', (tester) async {
    final keyStore = MemoryApiKeyStore();
    var settings = AppSettings.defaults();

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          apiKeyStore: keyStore,
          loadSettings: () async => settings,
          saveSettings: (value) async => settings = value,
          testApiKey: () async => true,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('openai-api-key-field')),
      'sk-test',
    );
    await tester.tap(find.text('Mentés'));
    await tester.pumpAndSettle();

    expect(await keyStore.readKey(), 'sk-test');
    expect(DebugConsole.allText, contains('[OpenAI] api key saved'));

    await tester.tap(find.text('Kulcs tesztelése'));
    await tester.pumpAndSettle();

    expect(DebugConsole.allText, contains('[OpenAI] api key test started'));
    expect(DebugConsole.allText, contains('[OpenAI] api key test succeeded'));

    await tester.tap(find.text('Kulcs törlése'));
    await tester.pumpAndSettle();

    expect(await keyStore.hasKey(), isFalse);
    expect(DebugConsole.allText, contains('[OpenAI] api key deleted'));
  });
}
