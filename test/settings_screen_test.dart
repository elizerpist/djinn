import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:djinn/src/ai/ai_error.dart';
import 'package:djinn/src/ai/ai_provider.dart';
import 'package:djinn/src/debug/debug_console.dart';
import 'package:djinn/src/settings/data/api_key_store.dart';
import 'package:djinn/src/settings/models/app_settings.dart';
import 'package:djinn/src/settings/models/model_catalog.dart';
import 'package:djinn/src/settings/ui/settings_screen.dart';
import 'package:djinn/src/voice/voice_mode.dart';

void main() {
  setUp(DebugConsole.clear);

  testWidgets('shows AI block with provider pills and model dropdowns', (
    tester,
  ) async {
    final keyStore = MemoryApiKeyStore();
    var settings = AppSettings.defaults();

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          apiKeyStore: keyStore,
          loadSettings: () async => settings,
          saveSettings: (value) async => settings = value,
          testApiKey: () async => true,
          testApiKeyForProvider: (_, _) async => true,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('AI'), findsOneWidget);
    expect(find.text('OpenAI'), findsOneWidget);
    expect(find.text('Gemini'), findsOneWidget);
    expect(find.text('Válaszadó modell'), findsOneWidget);
    expect(find.text('PDF feldolgozó modell'), findsOneWidget);
    expect(find.text('Groundedness modell'), findsOneWidget);
    expect(find.text('Embedding modell'), findsOneWidget);
    expect(find.text('Chunkolási mód'), findsOneWidget);
    expect(find.text('Nyelv és felolvasás'), findsOneWidget);
    expect(find.text('Felolvasás hangja'), findsOneWidget);
    expect(find.text('Hangmód'), findsOneWidget);
    expect(find.text('Párbeszéd mód'), findsOneWidget);
    expect(find.byKey(const Key('voice-mode-dropdown')), findsOneWidget);
    expect(find.text('Működési mód'), findsOneWidget);
    expect(find.text('Validálás'), findsOneWidget);
    expect(find.text('Mentés'), findsNothing);
    expect(find.text('Haladó modellbeállítások'), findsNothing);
  });

  testWidgets('chunking mode dropdown autosaves detailed mode', (tester) async {
    final keyStore = MemoryApiKeyStore();
    var settings = AppSettings.defaults();

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          apiKeyStore: keyStore,
          loadSettings: () async => settings,
          saveSettings: (value) async => settings = value,
          testApiKey: () async => true,
          testApiKeyForProvider: (_, _) async => true,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(settings.chunkingMode, ChunkingModes.normal);

    await tester.ensureVisible(find.byKey(const Key('chunking-mode-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chunking-mode-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Részletes').last);
    await tester.pumpAndSettle();

    expect(settings.chunkingMode, ChunkingModes.detailed);
  });

  testWidgets('tts locale dropdown autosaves selected voice locale', (
    tester,
  ) async {
    final keyStore = MemoryApiKeyStore();
    var settings = AppSettings.defaults();

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          apiKeyStore: keyStore,
          loadSettings: () async => settings,
          saveSettings: (value) async => settings = value,
          testApiKey: () async => true,
          testApiKeyForProvider: (_, _) async => true,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('tts-locale-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tts-locale-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English (US)').last);
    await tester.pumpAndSettle();

    expect(settings.voiceLocale, 'en-US');
    expect(find.text('Push-to-talk'), findsNothing);
    expect(find.text('Párbeszéd'), findsNothing);
  });

  testWidgets('voice mode dropdown autosaves native PTT', (tester) async {
    final keyStore = MemoryApiKeyStore();
    var settings = AppSettings.defaults();

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          apiKeyStore: keyStore,
          loadSettings: () async => settings,
          saveSettings: (value) async => settings = value,
          testApiKey: () async => true,
          testApiKeyForProvider: (_, _) async => true,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('voice-mode-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('voice-mode-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Natív push-to-talk').last);
    await tester.pumpAndSettle();

    expect(settings.voiceMode, VoiceMode.nativeAndroidPtt);
    expect(DebugConsole.allText, contains('voiceMode=native_android_ptt'));
  });

  testWidgets('answer mode selector autosaves forced offline mode', (
    tester,
  ) async {
    final keyStore = MemoryApiKeyStore();
    var settings = AppSettings.defaults();

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          apiKeyStore: keyStore,
          loadSettings: () async => settings,
          saveSettings: (value) async => settings = value,
          testApiKey: () async => true,
          testApiKeyForProvider: (_, _) async => true,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Offline keresés'));
    await tester.pumpAndSettle();

    expect(find.text('AI válasz'), findsOneWidget);
    expect(find.text('Offline keresés'), findsOneWidget);
    expect(find.text('Automatikus fallback'), findsOneWidget);

    await tester.tap(find.text('Offline keresés'));
    await tester.pumpAndSettle();

    expect(settings.answerMode, AnswerModes.offline);
    expect(settings.offlineFallbackEnabled, isFalse);
  });

  testWidgets('provider pill changes API key field and autosaves', (
    tester,
  ) async {
    final keyStore = MemoryApiKeyStore();
    var settings = AppSettings.defaults();

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          apiKeyStore: keyStore,
          loadSettings: () async => settings,
          saveSettings: (value) async => settings = value,
          testApiKey: () async => true,
          testApiKeyForProvider: (_, _) async => true,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Gemini'));
    await tester.pumpAndSettle();

    expect(settings.activeProvider, AiProvider.gemini);
    expect(find.byKey(const Key('gemini-api-key-field')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('gemini-api-key-field')),
      'AIza-test',
    );
    await tester.pumpAndSettle();

    expect(await keyStore.readKeyForProvider(AiProvider.gemini), 'AIza-test');
    expect(DebugConsole.allText, contains('[Google] api key saved length=9'));
  });

  testWidgets('model dropdown autosaves selected Gemini extraction model', (
    tester,
  ) async {
    final keyStore = MemoryApiKeyStore();
    var settings = AppSettings.defaults().copyWith(
      activeProvider: AiProvider.gemini,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          apiKeyStore: keyStore,
          loadSettings: () async => settings,
          saveSettings: (value) async => settings = value,
          testApiKey: () async => true,
          testApiKeyForProvider: (_, _) async => true,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('extraction-model-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('gemini-2.5-flash').last);
    await tester.pumpAndSettle();

    expect(settings.geminiExtractionModel, 'gemini-2.5-flash');
    expect(
      DebugConsole.allText,
      contains(
        '[Google] model selected slot=extraction model=gemini-2.5-flash',
      ),
    );
  });

  test('Gemini model catalog includes current Gemini, Gemma and Embedding 2 models', () {
    expect(ModelCatalog.geminiTextModels, contains('gemini-3.5-flash'));
    expect(ModelCatalog.geminiTextModels, contains('gemini-3-flash-preview'));
    expect(ModelCatalog.geminiTextModels, contains('gemini-3.1-flash-lite'));
    expect(ModelCatalog.geminiTextModels, contains('gemma-4-26b-a4b-it'));
    expect(ModelCatalog.geminiTextModels, contains('gemma-4-31b-it'));
    expect(ModelCatalog.geminiEmbeddingModels, contains('gemini-embedding-2'));
  });

  testWidgets('Gemini key test uses selected answer model and surfaces quota', (
    tester,
  ) async {
    final keyStore = MemoryApiKeyStore();
    await keyStore.saveKeyForProvider(AiProvider.gemini, 'gemini-key');
    var settings = AppSettings.defaults().copyWith(
      activeProvider: AiProvider.gemini,
      geminiAnswerModel: 'gemma-4-31b-it',
    );
    final testedModels = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          apiKeyStore: keyStore,
          loadSettings: () async => settings,
          saveSettings: (value) async => settings = value,
          testApiKey: () async => true,
          testApiKeyForProvider: (provider, model) async {
            expect(provider, AiProvider.gemini);
            testedModels.add(model);
            throw AiProviderException(
              AiFailure.quota(
                AiProvider.gemini,
                'Quota exceeded for model: $model',
              ),
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Kulcs tesztelése'));
    await tester.pumpAndSettle();

    expect(testedModels, ['gemma-4-31b-it']);
    expect(find.textContaining('Gemini kvota'), findsOneWidget);
    expect(find.textContaining('gemma-4-31b-it'), findsOneWidget);
    expect(find.textContaining('kulcs hibás'), findsNothing);
  });

  testWidgets('tests and deletes active provider API key', (tester) async {
    final keyStore = MemoryApiKeyStore();
    var settings = AppSettings.defaults();

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          apiKeyStore: keyStore,
          loadSettings: () async => settings,
          saveSettings: (value) async => settings = value,
          testApiKey: () async => true,
          testApiKeyForProvider: (_, _) async => true,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('openai-api-key-field')),
      'sk-test',
    );
    await tester.pumpAndSettle();

    expect(await keyStore.readKey(), 'sk-test');

    await tester.tap(find.text('Kulcs tesztelése'));
    await tester.pumpAndSettle();

    expect(DebugConsole.allText, contains('[OpenAI] api key test started'));
    expect(DebugConsole.allText, contains('[OpenAI] api key test succeeded'));

    await tester.tap(find.text('Kulcs törlése'));
    await tester.pumpAndSettle();

    expect(await keyStore.hasKey(), isFalse);
    expect(DebugConsole.allText, contains('[OpenAI] api key deleted'));
  });

  testWidgets('API key autosave is independent from settings save failures', (
    tester,
  ) async {
    final keyStore = MemoryApiKeyStore();

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          apiKeyStore: keyStore,
          loadSettings: () async => AppSettings.defaults(),
          saveSettings: (_) async => throw StateError('settings store failed'),
          testApiKey: () async => true,
          testApiKeyForProvider: (_, _) async => true,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('openai-api-key-field')),
      'sk-test',
    );
    await tester.pumpAndSettle();

    expect(await keyStore.readKey(), 'sk-test');
    expect(DebugConsole.allText, contains('[OpenAI] api key saved length=7'));
    expect(DebugConsole.allText, isNot(contains('settings save failed')));
  });

  testWidgets('API key autosave keeps the latest value when writes race', (
    tester,
  ) async {
    final keyStore = _DelayedMemoryApiKeyStore({
      'sk-partial': const Duration(milliseconds: 30),
      'sk-final': const Duration(milliseconds: 30),
      'sk-newer': Duration.zero,
    });
    var settings = AppSettings.defaults();

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          apiKeyStore: keyStore,
          loadSettings: () async => settings,
          saveSettings: (value) async => settings = value,
          testApiKey: () async => true,
          testApiKeyForProvider: (_, _) async => true,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('openai-api-key-field')),
      'sk-partial',
    );
    await tester.enterText(
      find.byKey(const Key('openai-api-key-field')),
      'sk-final',
    );
    await tester.pump(const Duration(milliseconds: 35));
    await tester.enterText(
      find.byKey(const Key('openai-api-key-field')),
      'sk-newer',
    );
    await tester.pump(const Duration(milliseconds: 80));

    expect(await keyStore.readKeyForProvider(AiProvider.openAi), 'sk-newer');
  });
}

class _DelayedMemoryApiKeyStore extends MemoryApiKeyStore {
  _DelayedMemoryApiKeyStore(this.delays);

  final Map<String, Duration> delays;

  @override
  Future<void> saveKeyForProvider(AiProvider provider, String value) async {
    final delay = delays[value.trim()] ?? Duration.zero;
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    await super.saveKeyForProvider(provider, value);
  }
}
