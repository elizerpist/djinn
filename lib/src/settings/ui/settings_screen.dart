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
  });

  final ApiKeyStore apiKeyStore;
  final Future<AppSettings> Function() loadSettings;
  final Future<void> Function(AppSettings settings) saveSettings;
  final Future<bool> Function() testApiKey;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _answerModelController = TextEditingController();
  final _extractionModelController = TextEditingController();
  final _groundednessModelController = TextEditingController();
  final _embeddingModelController = TextEditingController();

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
    _answerModelController.dispose();
    _extractionModelController.dispose();
    _groundednessModelController.dispose();
    _embeddingModelController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final settings = await widget.loadSettings();
    final apiKey = await widget.apiKeyStore.readKey();
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = settings;
      _apiKeyController.text = apiKey ?? '';
      _answerModelController.text = settings.answerModel;
      _extractionModelController.text = settings.extractionModel;
      _groundednessModelController.text = settings.groundednessModel;
      _embeddingModelController.text = settings.embeddingModel;
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _statusText = null;
    });
    try {
      final apiKey = _apiKeyController.text.trim();
      if (apiKey.isNotEmpty) {
        await widget.apiKeyStore.saveKey(apiKey);
        DebugConsole.log('[OpenAI] api key saved length=${apiKey.length}');
      }
      final settings = _settings.copyWith(
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
      );
      await widget.saveSettings(settings);
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = settings;
        _statusText = 'Beállítások mentve';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _statusText = 'A mentés nem sikerült');
      DebugConsole.log('[OpenAI] settings save failed');
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

  Future<void> _updateSettings(AppSettings settings) async {
    setState(() => _settings = settings);
    await widget.saveSettings(settings);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Beállítások')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
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
                        FilledButton(
                          onPressed: _saving ? null : _save,
                          child: const Text('Mentés'),
                        ),
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
                  ],
                ),
                const SizedBox(height: 12),
                _Section(
                  padding: EdgeInsets.zero,
                  children: [
                    ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                      ],
                    ),
                  ],
                ),
              ],
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
  const _ModelField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
