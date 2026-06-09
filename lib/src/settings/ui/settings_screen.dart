import 'package:flutter/material.dart';

import '../../ai/ai_provider.dart';
import '../../debug/debug_console.dart';
import '../data/api_key_store.dart';
import '../models/app_settings.dart';
import '../models/model_catalog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.apiKeyStore,
    required this.loadSettings,
    required this.saveSettings,
    required this.testApiKey,
    this.testApiKeyForProvider,
  });

  final ApiKeyStore apiKeyStore;
  final Future<AppSettings> Function() loadSettings;
  final Future<void> Function(AppSettings settings) saveSettings;
  final Future<bool> Function() testApiKey;
  final Future<bool> Function(AiProvider provider)? testApiKeyForProvider;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyController = TextEditingController();

  AppSettings _settings = AppSettings.defaults();
  bool _loading = true;
  bool _testingKey = false;
  String? _statusText;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final settings = await widget.loadSettings();
    final apiKey = await widget.apiKeyStore.readKeyForProvider(
      settings.activeProvider,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = settings;
      _apiKeyController.text = apiKey ?? '';
      _loading = false;
    });
  }

  Future<void> _selectProvider(AiProvider provider) async {
    final next = _settings.copyWith(activeProvider: provider);
    await _autoSave(next);
    final apiKey = await widget.apiKeyStore.readKeyForProvider(provider);
    if (!mounted) {
      return;
    }
    setState(() {
      _apiKeyController.text = apiKey ?? '';
      _statusText = null;
    });
  }

  Future<void> _autoSave(AppSettings settings) async {
    if (mounted) {
      setState(() => _settings = settings);
    }
    try {
      await widget.saveSettings(settings);
    } catch (error) {
      DebugConsole.log(
        '${_providerLogPrefix(settings.activeProvider)} settings save failed error=$error',
      );
      if (!mounted) {
        return;
      }
      setState(() => _statusText = 'A beállítások mentése nem sikerült');
    }
  }

  Future<void> _saveProviderKey(AiProvider provider, String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return;
    }
    try {
      await widget.apiKeyStore.saveKeyForProvider(provider, trimmed);
      DebugConsole.log(
        '${_providerLogPrefix(provider)} api key saved length=${trimmed.length}',
      );
      if (!mounted) {
        return;
      }
      setState(() => _statusText = '${provider.label} kulcs mentve');
    } catch (error) {
      DebugConsole.log(
        '${_providerLogPrefix(provider)} api key save failed error=$error',
      );
      if (!mounted) {
        return;
      }
      setState(
        () => _statusText = '${provider.label} kulcs mentése nem sikerült',
      );
    }
  }

  Future<void> _deleteKey() async {
    final provider = _settings.activeProvider;
    await widget.apiKeyStore.deleteKeyForProvider(provider);
    DebugConsole.log('${_providerLogPrefix(provider)} api key deleted');
    if (!mounted) {
      return;
    }
    setState(() {
      _apiKeyController.clear();
      _statusText = '${provider.label} kulcs törölve';
    });
  }

  Future<void> _testKey() async {
    final provider = _settings.activeProvider;
    setState(() {
      _testingKey = true;
      _statusText = null;
    });
    DebugConsole.log('${_providerLogPrefix(provider)} api key test started');
    final ok = await _testProviderKey(provider);
    DebugConsole.log(
      ok
          ? '${_providerLogPrefix(provider)} api key test succeeded'
          : '${_providerLogPrefix(provider)} api key test failed',
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _testingKey = false;
      _statusText = ok
          ? '${provider.label} kulcs működik'
          : '${provider.label} kulcs hibás';
    });
  }

  Future<bool> _testProviderKey(AiProvider provider) {
    final providerTester = widget.testApiKeyForProvider;
    if (providerTester != null) {
      return providerTester(provider);
    }
    if (provider == AiProvider.openAi) {
      return widget.testApiKey();
    }
    return Future.value(false);
  }

  Future<void> _updateModel(AiModelSlot slot, String model) async {
    final provider = _settings.activeProvider;
    final next = switch ((provider, slot)) {
      (AiProvider.openAi, AiModelSlot.answer) => _settings.copyWith(
        openAiAnswerModel: model,
      ),
      (AiProvider.openAi, AiModelSlot.extraction) => _settings.copyWith(
        openAiExtractionModel: model,
      ),
      (AiProvider.openAi, AiModelSlot.groundedness) => _settings.copyWith(
        openAiGroundednessModel: model,
      ),
      (AiProvider.openAi, AiModelSlot.embedding) => _settings.copyWith(
        openAiEmbeddingModel: model,
      ),
      (AiProvider.gemini, AiModelSlot.answer) => _settings.copyWith(
        geminiAnswerModel: model,
      ),
      (AiProvider.gemini, AiModelSlot.extraction) => _settings.copyWith(
        geminiExtractionModel: model,
      ),
      (AiProvider.gemini, AiModelSlot.groundedness) => _settings.copyWith(
        geminiGroundednessModel: model,
      ),
      (AiProvider.gemini, AiModelSlot.embedding) => _settings.copyWith(
        geminiEmbeddingModel: model,
      ),
    };
    await _autoSave(next);
    DebugConsole.log(
      '${_providerLogPrefix(provider)} model selected slot=${slot.wireName} model=$model',
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = _settings.activeProvider;
    return Scaffold(
      appBar: AppBar(title: const Text('Beállítások')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              child: Column(
                children: [
                  _Section(
                    title: 'AI',
                    children: [
                      SegmentedButton<AiProvider>(
                        segments: const [
                          ButtonSegment(
                            value: AiProvider.openAi,
                            label: Text('OpenAI'),
                          ),
                          ButtonSegment(
                            value: AiProvider.gemini,
                            label: Text('Gemini'),
                          ),
                        ],
                        selected: {provider},
                        onSelectionChanged: (selection) {
                          _selectProvider(selection.single);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: Key('${provider.wireName}-api-key-field'),
                        controller: _apiKeyController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: '${provider.label} API kulcs',
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (value) => _saveProviderKey(provider, value),
                        onSubmitted: (value) =>
                            _saveProviderKey(provider, value),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: _testingKey ? null : _testKey,
                            child: const Text('Kulcs tesztelése'),
                          ),
                          TextButton(
                            onPressed: _deleteKey,
                            child: const Text('Kulcs törlése'),
                          ),
                        ],
                      ),
                      _ModelDropdown(
                        slot: AiModelSlot.answer,
                        label: 'Válaszadó modell',
                        provider: provider,
                        value: _settings.modelFor(provider, AiModelSlot.answer),
                        onChanged: (value) =>
                            _updateModel(AiModelSlot.answer, value),
                      ),
                      _ModelDropdown(
                        slot: AiModelSlot.extraction,
                        label: 'PDF feldolgozó modell',
                        provider: provider,
                        value: _settings.modelFor(
                          provider,
                          AiModelSlot.extraction,
                        ),
                        onChanged: (value) =>
                            _updateModel(AiModelSlot.extraction, value),
                      ),
                      _ModelDropdown(
                        slot: AiModelSlot.groundedness,
                        label: 'Groundedness modell',
                        provider: provider,
                        value: _settings.modelFor(
                          provider,
                          AiModelSlot.groundedness,
                        ),
                        onChanged: (value) =>
                            _updateModel(AiModelSlot.groundedness, value),
                      ),
                      _ModelDropdown(
                        slot: AiModelSlot.embedding,
                        label: 'Embedding modell',
                        provider: provider,
                        value: _settings.modelFor(
                          provider,
                          AiModelSlot.embedding,
                        ),
                        onChanged: (value) =>
                            _updateModel(AiModelSlot.embedding, value),
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
                    title: 'Beszéd',
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.mic),
                        title: const Text('Hangvezérlés'),
                        subtitle: Text(_voiceModeLabel(_settings.voiceMode)),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.record_voice_over),
                        title: const Text('Felolvasás'),
                        subtitle: Text(_settings.voiceLocale),
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
                    title: 'Validálás',
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('AI fájlok törlése feldolgozás után'),
                        value: _settings.deleteOpenAiFilesAfterProcessing,
                        onChanged: (value) => _autoSave(
                          _settings.copyWith(
                            deleteOpenAiFilesAfterProcessing: value,
                          ),
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Második groundedness check'),
                        value: _settings.groundednessCheckEnabled,
                        onChanged: (value) => _autoSave(
                          _settings.copyWith(groundednessCheckEnabled: value),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  String _providerLogPrefix(AiProvider provider) {
    return provider == AiProvider.openAi ? '[OpenAI]' : '[Google]';
  }

  String _voiceModeLabel(String value) {
    return switch (value) {
      'conversation' => 'Párbeszéd',
      'push_to_talk' => 'Push-to-talk',
      _ => value,
    };
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ModelDropdown extends StatelessWidget {
  const _ModelDropdown({
    required this.slot,
    required this.label,
    required this.provider,
    required this.value,
    required this.onChanged,
  });

  final AiModelSlot slot;
  final String label;
  final AiProvider provider;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = ModelCatalog.options(provider, slot);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DropdownButtonFormField<String>(
        key: Key('${slot.wireName}-model-dropdown'),
        initialValue: options.contains(value) ? value : options.first,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final option in options)
            DropdownMenuItem(value: option, child: Text(option)),
        ],
        onChanged: (value) {
          if (value != null) {
            onChanged(value);
          }
        },
      ),
    );
  }
}
