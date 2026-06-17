import 'package:flutter/material.dart';

import '../../ai/ai_error.dart';
import '../../ai/ai_provider.dart';
import '../../debug/debug_console.dart';
import '../../branding/djinn_brand_mark.dart';
import '../../debug/debug_header_button.dart';
import '../../openai/openai_client.dart';
import '../data/api_key_store.dart';
import '../models/app_settings.dart';
import '../models/model_catalog.dart';
import '../../voice/voice_mode.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.apiKeyStore,
    required this.loadSettings,
    required this.saveSettings,
    required this.testApiKey,
    this.testApiKeyForProvider,
    this.onSettingsChanged,
  });

  final ApiKeyStore apiKeyStore;
  final Future<AppSettings> Function() loadSettings;
  final Future<void> Function(AppSettings settings) saveSettings;
  final Future<bool> Function() testApiKey;
  final Future<bool> Function(AiProvider provider, String model)?
      testApiKeyForProvider;
  final ValueChanged<AppSettings>? onSettingsChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  final Map<AiProvider, String> _pendingApiKeys = {};
  final Set<AiProvider> _apiKeySaveRunning = {};
  AppSettings? _pendingSettings;
  bool _settingsSaveRunning = false;

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
    _pendingSettings = settings;
    if (_settingsSaveRunning) {
      return;
    }
    _settingsSaveRunning = true;
    await _drainSettingsSaves();
  }

  Future<void> _drainSettingsSaves() async {
    try {
      while (true) {
        final next = _pendingSettings;
        if (next == null) {
          break;
        }
        _pendingSettings = null;
        await widget.saveSettings(next);
        widget.onSettingsChanged?.call(next);
        DebugConsole.log(
          '${_providerLogPrefix(next.activeProvider)} settings saved '
          'provider=${next.activeProvider.wireName} '
          'voiceMode=${next.voiceMode.wireName} '
          'navigationMode=${AppNavigationMode.bottomNav.wireName}',
        );
      }
    } catch (error) {
      DebugConsole.log(
        '${_providerLogPrefix(_settings.activeProvider)} settings save failed error=$error',
      );
      if (!mounted) {
        return;
      }
      setState(() => _statusText = 'A beállítások mentése nem sikerült');
    } finally {
      _settingsSaveRunning = false;
      if (_pendingSettings != null) {
        _settingsSaveRunning = true;
        await _drainSettingsSaves();
      }
    }
  }

  Future<void> _saveProviderKey(AiProvider provider, String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _pendingApiKeys[provider] = trimmed;
    if (_apiKeySaveRunning.contains(provider)) {
      return;
    }
    _apiKeySaveRunning.add(provider);
    await _drainProviderKeySaves(provider);
  }

  Future<void> _drainProviderKeySaves(AiProvider provider) async {
    try {
      String? saved;
      while (true) {
        final next = _pendingApiKeys[provider];
        if (next == null || next == saved) {
          break;
        }
        await widget.apiKeyStore.saveKeyForProvider(provider, next);
        saved = next;
      }
      final latest = saved;
      if (latest == null) {
        return;
      }
      DebugConsole.log(
        '${_providerLogPrefix(provider)} api key saved length=${latest.length}',
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
    } finally {
      _apiKeySaveRunning.remove(provider);
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
    var ok = false;
    var statusText = '${provider.label} API kulcs nincs beallitva.';
    try {
      ok = await _testProviderKey(provider);
      statusText = ok
          ? '${provider.label} kulcs működik (${_settings.modelFor(provider, AiModelSlot.answer)})'
          : '${provider.label} API kulcs nincs beallitva.';
      DebugConsole.log(
        ok
            ? '${_providerLogPrefix(provider)} api key test succeeded'
            : '${_providerLogPrefix(provider)} api key test failed',
      );
    } catch (error) {
      statusText = _keyTestErrorStatus(provider, error);
      DebugConsole.log(
        '${_providerLogPrefix(provider)} api key test failed error=$error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _testingKey = false;
          _statusText = statusText;
        });
      }
    }
  }

  Future<bool> _testProviderKey(AiProvider provider) {
    final providerTester = widget.testApiKeyForProvider;
    if (providerTester != null) {
      return providerTester(
        provider,
        _settings.modelFor(provider, AiModelSlot.answer),
      );
    }
    if (provider == AiProvider.openAi) {
      return widget.testApiKey();
    }
    return Future.value(false);
  }

  String _keyTestErrorStatus(AiProvider provider, Object error) {
    if (error is AiProviderException) {
      return error.failure.userMessage;
    }
    if (error is OpenAiException) {
      return '${provider.label} API kulcs teszt sikertelen: ${error.message}';
    }
    return '${provider.label} API kulcs teszt sikertelen: $error';
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
    return Scaffold(
      appBar: AppBar(
        title: const DjinnAppBarTitle(title: 'Beállítások'),
        actions: const [DebugHeaderButton()],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                _SettingsMenuCard(
                  key: const Key('settings-card-ai'),
                  icon: Icons.auto_awesome,
                  title: 'AI',
                  subtitle: 'API kulcsok, szolgáltató és modellválasztás',
                  onTap: () => _openSection(
                    title: 'AI',
                    icon: Icons.auto_awesome,
                    builder: _buildAiSection,
                  ),
                ),
                _SettingsMenuCard(
                  key: const Key('settings-card-language'),
                  icon: Icons.record_voice_over_outlined,
                  title: 'Nyelv és felolvasás',
                  subtitle: 'Felolvasási nyelv és TTS hang',
                  onTap: () => _openSection(
                    title: 'Nyelv és felolvasás',
                    icon: Icons.record_voice_over_outlined,
                    builder: _buildLanguageSection,
                  ),
                ),
                _SettingsMenuCard(
                  key: const Key('settings-card-voice'),
                  icon: Icons.mic_none,
                  title: 'Hangbevitel',
                  subtitle: 'Párbeszéd mód és natív push-to-talk',
                  onTap: () => _openSection(
                    title: 'Hangbevitel',
                    icon: Icons.mic_none,
                    builder: _buildVoiceSection,
                  ),
                ),
                _SettingsMenuCard(
                  key: const Key('settings-card-mode'),
                  icon: Icons.tune,
                  title: 'Működési mód',
                  subtitle: 'AI válasz és explicit offline keresés',
                  onTap: () => _openSection(
                    title: 'Működési mód',
                    icon: Icons.tune,
                    builder: _buildModeSection,
                  ),
                ),
                _SettingsMenuCard(
                  key: const Key('settings-card-validation'),
                  icon: Icons.verified_outlined,
                  title: 'Validálás',
                  subtitle: 'Groundedness és feldolgozás utáni takarítás',
                  onTap: () => _openSection(
                    title: 'Validálás',
                    icon: Icons.verified_outlined,
                    builder: _buildValidationSection,
                  ),
                ),
                _SettingsMenuCard(
                  key: const Key('settings-card-about'),
                  icon: Icons.info_outline,
                  title: 'Az app működése',
                  subtitle: 'Chunkolás, embedding, vektorsearch és graph',
                  onTap: () => _openSection(
                    title: 'Az app működése',
                    icon: Icons.info_outline,
                    builder: _buildAboutSection,
                  ),
                ),
              ],
            ),
    );
  }

  void _openSection({
    required String title,
    required IconData icon,
    required Widget Function(BuildContext context, VoidCallback refresh) builder,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _SettingsSectionPage(
          title: title,
          icon: icon,
          builder: builder,
        ),
      ),
    );
  }

  Widget _buildAiSection(BuildContext context, VoidCallback refresh) {
    final provider = _settings.activeProvider;
    return _Section(
      title: 'AI',
      children: [
        SegmentedButton<AiProvider>(
          segments: const [
            ButtonSegment(value: AiProvider.openAi, label: Text('OpenAI')),
            ButtonSegment(value: AiProvider.gemini, label: Text('Gemini')),
          ],
          selected: {provider},
          onSelectionChanged: (selection) async {
            await _selectProvider(selection.single);
            refresh();
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
          onSubmitted: (value) => _saveProviderKey(provider, value),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: _testingKey
                  ? null
                  : () async {
                      await _testKey();
                      refresh();
                    },
              child: const Text('Kulcs tesztelése'),
            ),
            TextButton(
              onPressed: () async {
                await _deleteKey();
                refresh();
              },
              child: const Text('Kulcs törlése'),
            ),
          ],
        ),
        _ModelDropdown(
          slot: AiModelSlot.answer,
          label: 'Válaszadó modell',
          provider: provider,
          value: _settings.modelFor(provider, AiModelSlot.answer),
          onChanged: (value) async {
            await _updateModel(AiModelSlot.answer, value);
            refresh();
          },
        ),
        _ModelDropdown(
          slot: AiModelSlot.extraction,
          label: 'PDF feldolgozó modell',
          provider: provider,
          value: _settings.modelFor(provider, AiModelSlot.extraction),
          onChanged: (value) async {
            await _updateModel(AiModelSlot.extraction, value);
            refresh();
          },
        ),
        _ModelDropdown(
          slot: AiModelSlot.groundedness,
          label: 'Groundedness modell',
          provider: provider,
          value: _settings.modelFor(provider, AiModelSlot.groundedness),
          onChanged: (value) async {
            await _updateModel(AiModelSlot.groundedness, value);
            refresh();
          },
        ),
        _ModelDropdown(
          slot: AiModelSlot.embedding,
          label: 'Embedding modell',
          provider: provider,
          value: _settings.modelFor(provider, AiModelSlot.embedding),
          onChanged: (value) async {
            await _updateModel(AiModelSlot.embedding, value);
            refresh();
          },
        ),
        _ChunkingModeDropdown(
          value: _settings.chunkingMode,
          onChanged: (value) async {
            await _autoSave(_settings.copyWith(chunkingMode: value));
            refresh();
          },
        ),
        if (_statusText != null) ...[
          const SizedBox(height: 12),
          Text(
            _statusText!,
            style: const TextStyle(color: Color(0xFF166534)),
          ),
        ],
      ],
    );
  }

  Widget _buildLanguageSection(BuildContext context, VoidCallback refresh) {
    return _Section(
      title: 'Nyelv és felolvasás',
      children: [
        _TtsLocaleDropdown(
          value: _settings.voiceLocale,
          onChanged: (value) async {
            await _autoSave(_settings.copyWith(voiceLocale: value));
            refresh();
          },
        ),
      ],
    );
  }

  Widget _buildVoiceSection(BuildContext context, VoidCallback refresh) {
    return _Section(
      title: 'Hangbevitel',
      children: [
        _VoiceModeDropdown(
          value: _settings.voiceMode,
          onChanged: (value) async {
            await _autoSave(_settings.copyWith(voiceMode: value));
            refresh();
          },
        ),
      ],
    );
  }

  Widget _buildModeSection(BuildContext context, VoidCallback refresh) {
    return _Section(
      title: 'Működési mód',
      children: [
        RadioGroup<String>(
          groupValue: _settings.answerMode,
          onChanged: (value) async {
            if (value != null) {
              await _autoSave(_settings.copyWith(answerMode: value));
              refresh();
            }
          },
          child: Column(
            key: const Key('answer-mode-selector'),
            children: const [
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                value: AnswerModes.ai,
                title: Text('AI válasz'),
              ),
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                value: AnswerModes.offline,
                title: Text('Offline keresés'),
                subtitle: Text('Nem hív AI API-t'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _LocalIndexingModeDropdown(
          value: _settings.localIndexingMode,
          onChanged: (value) async {
            await _autoSave(_settings.copyWith(localIndexingMode: value));
            refresh();
          },
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.search),
          title: const Text('Offline forráskeresés'),
          subtitle: Text(
            LocalIndexingModes.description(_settings.localIndexingMode),
          ),
        ),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.phone_android),
          title: Text('B mód: Local ObjectBox'),
          subtitle: Text('Aktív'),
        ),
      ],
    );
  }

  Widget _buildValidationSection(BuildContext context, VoidCallback refresh) {
    return _Section(
      title: 'Validálás',
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('AI fájlok törlése feldolgozás után'),
          value: _settings.deleteOpenAiFilesAfterProcessing,
          onChanged: (value) async {
            await _autoSave(
              _settings.copyWith(deleteOpenAiFilesAfterProcessing: value),
            );
            refresh();
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Második groundedness check'),
          value: _settings.groundednessCheckEnabled,
          onChanged: (value) async {
            await _autoSave(
              _settings.copyWith(groundednessCheckEnabled: value),
            );
            refresh();
          },
        ),
      ],
    );
  }

  Widget _buildAboutSection(BuildContext context, VoidCallback refresh) {
    return _Section(
      title: 'Az app működése',
      children: const [
        _AboutBlock(
          title: 'Mi az a chunkolás?',
          body:
              'A chunkolás a PDF vagy kép tartalmát kisebb, önállóan kereshető tudáselemekre bontja. Egy chunk lehet bekezdés, felsorolás, táblázatsor, score elem, képi tény vagy flowchart lépés. A cél az, hogy a kérdésre ne az egész dokumentumot kelljen átnézni, hanem csak a releváns részleteket.',
        ),
        _AboutBlock(
          title: 'Mi történik OCR közben?',
          body:
              'A lokális OCR a dokumentum oldalait képként is feldolgozza, ezért a szkennelt táblázatokból, képalapú szövegből és ábrákból is próbál kinyerni tartalmat. Ez AI nélkül, a készüléken futó feldolgozási lépés.',
        ),
        _AboutBlock(
          title: 'Mi az embedding?',
          body:
              'Az embedding egy számsor, amely a chunk jelentését írja le kereshető formában. Ha egy chunk csak ki van nyerve, akkor olvasható és auditálható. Ha embedding is készült hozzá, akkor szemantikus keresésben is részt tud venni.',
        ),
        _AboutBlock(
          title: 'Mi az a vektorsearch?',
          body:
              'A vektorsearch a kérdés embeddingjét hasonlítja össze a chunkok embeddingjeivel. Így nem csak pontos kulcsszavakra talál, hanem jelentés alapján is. Például egy másképp megfogalmazott kérdés is megtalálhatja ugyanazt az eljárásrendi részletet.',
        ),
        _AboutBlock(
          title: 'Mi az a graph / VectorGraph?',
          body:
              'A graph a chunkok közötti kapcsolatokat tárolja: melyik rész melyik szekcióhoz tartozik, mi folytatódik a következő oldalon, melyik táblázat vagy flowchart milyen bizonyítékból származik. A VectorGraph a vektoros találatokat ezekkel a kapcsolatokkal egészíti ki, hogy a válasz kontextusban maradjon.',
        ),
        _AboutBlock(
          title: 'Offline jegyzetírási útmutató',
          body:
              'Adj keresési kontextust, ha a blokk címe önmagában túl általános, például Magyarázat vagy Jegyzet. Egy blokk lehetőleg egy témát tartalmazzon. Definíciókat írj külön listaelembe, például DO2 = oxygénkínálat. Használj role mezőt definíció, tény, folyamat, táblázatos szabály, példa vagy analógia jelölésére. Aliasokhoz vedd fel a rövidítéseket és szimbólumokat. Ha egy blokk több témát kever, bontsd külön blokkokra, mert offline módban az app explicit kulcsszavakból, szimbólumokból, metadata boostból és graph kapcsolatokból dolgozik.',
        ),
        _AboutBlock(
          title: 'Mi az audit szerepe?',
          body:
              'Az audit arra való, hogy a user vagy egy későbbi AI ellenőrizze a kinyert tartalmat. Az auditált és indexelt chunk erősebb forrás lehet, mint egy nyers, bizonytalan OCR vagy AI kinyerés.',
        ),
        _AboutBlock(
          title: 'Mi a kézi chunk?',
          body:
              'A kézi chunk akkor kell, ha az automatikus kinyerés kihagyott vagy rosszul tagolt valamit. A kézzel mentett elem ugyanúgy bekerül a tudástárba, külön pipeline-ként látszik, exportálható, auditálható és később indexelhető.',
        ),
        _AboutBlock(
          title: 'Mi a B mód?',
          body:
              'A jelenlegi B mód helyi ObjectBox alapú tudástár. A dokumentum, a kinyert chunk, az audit állapot, a graph kapcsolat és a vektoros index az app helyi adatbázisában él. Ez gyors, offline-barát és nem igényel saját backend szervert.',
        ),
      ],
    );
  }

  String _providerLogPrefix(AiProvider provider) {
    return provider == AiProvider.openAi ? '[OpenAI]' : '[Google]';
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

class _SettingsMenuCard extends StatelessWidget {
  const _SettingsMenuCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: const Color(0xFF2563EB)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: Color(0xFF6B7280)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsSectionPage extends StatefulWidget {
  const _SettingsSectionPage({
    required this.title,
    required this.icon,
    required this.builder,
  });

  final String title;
  final IconData icon;
  final Widget Function(BuildContext context, VoidCallback refresh) builder;

  @override
  State<_SettingsSectionPage> createState() => _SettingsSectionPageState();
}

class _SettingsSectionPageState extends State<_SettingsSectionPage> {
  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(widget.icon, size: 20),
            const SizedBox(width: 8),
            Flexible(child: Text(widget.title)),
          ],
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [widget.builder(context, _refresh)],
      ),
    );
  }
}

class _AboutBlock extends StatelessWidget {
  const _AboutBlock({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF374151),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChunkingModeDropdown extends StatelessWidget {
  const _ChunkingModeDropdown({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DropdownButtonFormField<String>(
        key: const Key('chunking-mode-dropdown'),
        initialValue: ChunkingModes.normalize(value),
        decoration: const InputDecoration(
          labelText: 'Chunkolási mód',
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(
            value: ChunkingModes.compact,
            child: Text('Kompakt'),
          ),
          DropdownMenuItem(value: ChunkingModes.normal, child: Text('Normál')),
          DropdownMenuItem(
            value: ChunkingModes.detailed,
            child: Text('Részletes'),
          ),
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

class _LocalIndexingModeDropdown extends StatelessWidget {
  const _LocalIndexingModeDropdown({
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final normalized = LocalIndexingModes.normalize(value);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DropdownButtonFormField<String>(
        key: const Key('local-indexing-mode-dropdown'),
        initialValue: normalized,
        decoration: const InputDecoration(
          labelText: 'Lokális indexelés',
          border: OutlineInputBorder(),
        ),
        items: [
          for (final option in LocalIndexingModes.values)
            DropdownMenuItem(
              value: option,
              child: Text(LocalIndexingModes.label(option)),
            ),
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

class _TtsLocaleDropdown extends StatelessWidget {
  const _TtsLocaleDropdown({required this.value, required this.onChanged});

  static const _options = [
    ('hu-HU', 'Magyar'),
    ('en-US', 'English (US)'),
    ('de-DE', 'Deutsch'),
  ];

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final safeValue = _options.any((item) => item.$1 == value)
        ? value
        : 'hu-HU';
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DropdownButtonFormField<String>(
        key: const Key('tts-locale-dropdown'),
        initialValue: safeValue,
        decoration: const InputDecoration(
          labelText: 'Felolvasás hangja',
          border: OutlineInputBorder(),
        ),
        items: _options
            .map(
              (option) =>
                  DropdownMenuItem(value: option.$1, child: Text(option.$2)),
            )
            .toList(growable: false),
        onChanged: (value) {
          if (value != null) {
            onChanged(value);
          }
        },
      ),
    );
  }
}

class _VoiceModeDropdown extends StatelessWidget {
  const _VoiceModeDropdown({required this.value, required this.onChanged});

  final VoiceMode value;
  final ValueChanged<VoiceMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DropdownButtonFormField<VoiceMode>(
        key: const Key('voice-mode-dropdown'),
        initialValue: value,
        decoration: const InputDecoration(
          labelText: 'Hangbevitel módja',
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(
            value: VoiceMode.whisperConversation,
            child: Text('Párbeszéd mód'),
          ),
          DropdownMenuItem(
            value: VoiceMode.nativeAndroidPtt,
            child: Text('Natív push-to-talk'),
          ),
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
