import 'package:flutter/material.dart';

import '../../debug/debug_console.dart';
import '../data/api_key_store.dart';
import '../models/app_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.apiKeyStore,
    required this.loadSettings,
    required this.saveSettings,
    required this.testApiKey,
    this.testGoogleApiKey,
  });

  final ApiKeyStore apiKeyStore;
  final Future<AppSettings> Function() loadSettings;
  final Future<void> Function(AppSettings settings) saveSettings;
  final Future<bool> Function() testApiKey;
  final Future<bool> Function()? testGoogleApiKey;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _googleApiKeyController = TextEditingController();
  final _answerModelController = TextEditingController();
  final _extractionModelController = TextEditingController();
  final _groundednessModelController = TextEditingController();
  final _embeddingModelController = TextEditingController();
  final _googleAnswerModelController = TextEditingController();
  final _googleExtractionModelController = TextEditingController();
  final _googleGroundednessModelController = TextEditingController();
  final _googleEmbeddingModelController = TextEditingController();
  final _voiceLocaleController = TextEditingController();
  final _ttsRateController = TextEditingController();
  final _ttsPitchController = TextEditingController();

  AppSettings _settings = AppSettings.defaults();
  bool _loading = true;
  bool _saving = false;
  String? _statusText;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _googleApiKeyController.dispose();
    _answerModelController.dispose();
    _extractionModelController.dispose();
    _groundednessModelController.dispose();
    _embeddingModelController.dispose();
    _googleAnswerModelController.dispose();
    _googleExtractionModelController.dispose();
    _googleGroundednessModelController.dispose();
    _googleEmbeddingModelController.dispose();
    _voiceLocaleController.dispose();
    _ttsRateController.dispose();
    _ttsPitchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final settings = await widget.loadSettings();
    final apiKey = await widget.apiKeyStore.readKey();
    final googleApiKey = await widget.apiKeyStore.readKey(
      provider: ApiKeyProvider.google,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = settings;
      _apiKeyController.text = apiKey ?? '';
      _googleApiKeyController.text = googleApiKey ?? '';
      _answerModelController.text = settings.answerModel;
      _extractionModelController.text = settings.extractionModel;
      _groundednessModelController.text = settings.groundednessModel;
      _embeddingModelController.text = settings.embeddingModel;
      _googleAnswerModelController.text = settings.googleAnswerModel;
      _googleExtractionModelController.text = settings.googleExtractionModel;
      _googleGroundednessModelController.text =
          settings.googleGroundednessModel;
      _googleEmbeddingModelController.text = settings.googleEmbeddingModel;
      _voiceLocaleController.text = settings.voiceLocale;
      _ttsRateController.text = settings.ttsSpeechRate.toString();
      _ttsPitchController.text = settings.ttsPitch.toString();
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _statusText = null;
    });
    var apiKeySaved = false;
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isNotEmpty) {
      try {
        await widget.apiKeyStore.saveKey(apiKey);
        apiKeySaved = true;
        DebugConsole.log('[OpenAI] api key saved length=${apiKey.length}');
      } catch (error) {
        DebugConsole.log('[OpenAI] api key save failed error=$error');
        if (mounted) {
          setState(() {
            _statusText = 'OpenAI kulcs mentése nem sikerült';
            _saving = false;
          });
        }
        return;
      }
    }
    final googleApiKey = _googleApiKeyController.text.trim();
    if (googleApiKey.isNotEmpty) {
      try {
        await widget.apiKeyStore.saveKey(
          googleApiKey,
          provider: ApiKeyProvider.google,
        );
        DebugConsole.log(
          '[Google] api key saved length=${googleApiKey.length}',
        );
      } catch (error) {
        DebugConsole.log('[Google] api key save failed error=$error');
        if (mounted) {
          setState(() {
            _statusText = 'Google API kulcs mentése nem sikerült';
            _saving = false;
          });
        }
        return;
      }
    }
    try {
      final settings = _settings.copyWith(
        aiProvider: _settings.aiProvider,
        answerModel: _answerModelController.text.trim().isEmpty
            ? _settings.answerModel
            : _answerModelController.text.trim(),
        extractionModel: _extractionModelController.text.trim().isEmpty
            ? _settings.extractionModel
            : _extractionModelController.text.trim(),
        groundednessModel: _groundednessModelController.text.trim().isEmpty
            ? _settings.groundednessModel
            : _groundednessModelController.text.trim(),
        embeddingModel: _embeddingModelController.text.trim().isEmpty
            ? _settings.embeddingModel
            : _embeddingModelController.text.trim(),
        googleAnswerModel: _googleAnswerModelController.text.trim().isEmpty
            ? _settings.googleAnswerModel
            : _googleAnswerModelController.text.trim(),
        googleExtractionModel:
            _googleExtractionModelController.text.trim().isEmpty
            ? _settings.googleExtractionModel
            : _googleExtractionModelController.text.trim(),
        googleGroundednessModel:
            _googleGroundednessModelController.text.trim().isEmpty
            ? _settings.googleGroundednessModel
            : _googleGroundednessModelController.text.trim(),
        googleEmbeddingModel:
            _googleEmbeddingModelController.text.trim().isEmpty
            ? _settings.googleEmbeddingModel
            : _googleEmbeddingModelController.text.trim(),
        voiceLocale: _voiceLocaleController.text.trim().isEmpty
            ? _settings.voiceLocale
            : _voiceLocaleController.text.trim(),
        ttsSpeechRate:
            double.tryParse(_ttsRateController.text.trim()) ??
            _settings.ttsSpeechRate,
        ttsPitch:
            double.tryParse(_ttsPitchController.text.trim()) ??
            _settings.ttsPitch,
      );
      await widget.saveSettings(settings);
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = settings;
        _statusText = 'Beállítások mentve';
      });
    } catch (error) {
      DebugConsole.log('[OpenAI] settings save failed error=$error');
      if (!mounted) {
        return;
      }
      setState(
        () => _statusText = apiKeySaved
            ? 'OpenAI kulcs mentve, a modellbeállítások mentése nem sikerült'
            : 'A modellbeállítások mentése nem sikerült',
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _deleteKey() async {
    await widget.apiKeyStore.deleteKey();
    DebugConsole.log('[OpenAI] api key deleted');
    if (!mounted) {
      return;
    }
    setState(() {
      _apiKeyController.clear();
      _statusText = 'OpenAI kulcs törölve';
    });
  }

  Future<void> _deleteGoogleKey() async {
    await widget.apiKeyStore.deleteKey(provider: ApiKeyProvider.google);
    DebugConsole.log('[Google] api key deleted');
    if (!mounted) {
      return;
    }
    setState(() {
      _googleApiKeyController.clear();
      _statusText = 'Google API kulcs törölve';
    });
  }

  Future<void> _testKey() async {
    DebugConsole.log('[OpenAI] api key test started');
    final ok = await widget.testApiKey();
    DebugConsole.log(
      ok ? '[OpenAI] api key test succeeded' : '[OpenAI] api key test failed',
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _statusText = ok ? 'OpenAI kulcs működik' : 'OpenAI kulcs hibás';
    });
  }

  Future<void> _testGoogleKey() async {
    final tester = widget.testGoogleApiKey;
    if (tester == null) {
      setState(() => _statusText = 'Google kulcsteszt nincs bekötve');
      return;
    }
    DebugConsole.log('[Google] api key test started');
    final ok = await tester();
    DebugConsole.log(
      ok ? '[Google] api key test succeeded' : '[Google] api key test failed',
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _statusText = ok ? 'Google API kulcs működik' : 'Google API kulcs hibás';
    });
  }

  Future<void> _updateSettings(AppSettings settings) async {
    setState(() => _settings = settings);
    await widget.saveSettings(settings);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Beállítások')),
      bottomNavigationBar: _loading
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: const Text('Mentés'),
                ),
              ),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Section(
                      title: 'AI szolgáltató',
                      children: [
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'openai',
                              label: Text('OpenAI'),
                              icon: Icon(Icons.psychology),
                            ),
                            ButtonSegment(
                              value: 'google',
                              label: Text('Gemini'),
                              icon: Icon(Icons.auto_awesome),
                            ),
                          ],
                          selected: {_settings.aiProvider},
                          onSelectionChanged: (selection) => _updateSettings(
                            _settings.copyWith(aiProvider: selection.single),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton(
                              key: const Key('ai-provider-google'),
                              onPressed: () => _updateSettings(
                                _settings.copyWith(aiProvider: 'google'),
                              ),
                              child: const Text('Gemini használata'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _Section(
                      title: 'Beszéd',
                      children: [
                        _ModelField(
                          controller: _voiceLocaleController,
                          label: 'Hangfelismerés nyelve',
                          fieldKey: const Key('voice-locale-field'),
                        ),
                        _ModelField(
                          controller: _ttsRateController,
                          label: 'Felolvasás sebessége',
                          fieldKey: const Key('tts-rate-field'),
                        ),
                        _ModelField(
                          controller: _ttsPitchController,
                          label: 'Felolvasás hangmagassága',
                          fieldKey: const Key('tts-pitch-field'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _Section(
                      title: 'OpenAI kapcsolat',
                      children: [
                        TextField(
                          key: const Key('openai-api-key-field'),
                          controller: _apiKeyController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'OpenAI API kulcs',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: _testKey,
                              child: const Text('Kulcs tesztelése'),
                            ),
                            TextButton(
                              onPressed: _deleteKey,
                              child: const Text('Kulcs törlése'),
                            ),
                          ],
                        ),
                        if (_statusText != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _statusText!,
                            style: const TextStyle(color: Color(0xFF166534)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    _Section(
                      title: 'Google Gemini kapcsolat',
                      children: [
                        TextField(
                          key: const Key('google-api-key-field'),
                          controller: _googleApiKeyController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Google API kulcs',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: _testGoogleKey,
                              child: const Text('Google kulcs tesztelése'),
                            ),
                            TextButton(
                              onPressed: _deleteGoogleKey,
                              child: const Text('Google kulcs törlése'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _Section(
                      title: 'Működési mód',
                      children: const [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.phone_android),
                          title: Text('B mód: Local ObjectBox'),
                          subtitle: Text('Aktív'),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.cloud_off),
                          title: Text('A mód: Backend'),
                          subtitle: Text('Jelenleg nincs bekötve'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _Section(
                      title: 'Validálás és adatkezelés',
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'OpenAI fájlok törlése feldolgozás után',
                          ),
                          value: _settings.deleteOpenAiFilesAfterProcessing,
                          onChanged: (value) => _updateSettings(
                            _settings.copyWith(
                              deleteOpenAiFilesAfterProcessing: value,
                            ),
                          ),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Második groundedness check'),
                          value: _settings.groundednessCheckEnabled,
                          onChanged: (value) => _updateSettings(
                            _settings.copyWith(groundednessCheckEnabled: value),
                          ),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Fizetős AI hívások engedélyezése'),
                          value: _settings.allowPaidAi,
                          onChanged: (value) => _updateSettings(
                            _settings.copyWith(allowPaidAi: value),
                          ),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Megerősítés AI feldolgozás előtt'),
                          value: _settings.confirmBeforeAiProcessing,
                          onChanged: (value) => _updateSettings(
                            _settings.copyWith(
                              confirmBeforeAiProcessing: value,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _Section(
                      padding: EdgeInsets.zero,
                      children: [
                        ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            16,
                          ),
                          title: const Text('Haladó modellbeállítások'),
                          children: [
                            _ModelField(
                              controller: _answerModelController,
                              label: 'Válaszoló modell',
                            ),
                            _ModelField(
                              controller: _extractionModelController,
                              label: 'PDF feldolgozó modell',
                            ),
                            _ModelField(
                              controller: _groundednessModelController,
                              label: 'Groundedness modell',
                            ),
                            _ModelField(
                              controller: _embeddingModelController,
                              label: 'Embedding modell',
                            ),
                            _ModelField(
                              controller: _googleAnswerModelController,
                              label: 'Gemini válaszoló modell',
                            ),
                            _ModelField(
                              controller: _googleExtractionModelController,
                              label: 'Gemini PDF feldolgozó modell',
                            ),
                            _ModelField(
                              controller: _googleGroundednessModelController,
                              label: 'Gemini groundedness modell',
                            ),
                            _ModelField(
                              controller: _googleEmbeddingModelController,
                              label: 'Gemini embedding modell',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({this.title, required this.children, this.padding});

  final String? title;
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(title!, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
            ],
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ModelField extends StatelessWidget {
  const _ModelField({
    required this.controller,
    required this.label,
    this.fieldKey,
  });

  final TextEditingController controller;
  final String label;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TextField(
        key: fieldKey,
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
