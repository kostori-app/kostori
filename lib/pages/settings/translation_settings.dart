part of 'settings_page.dart';

class TranslationSettings extends StatefulWidget {
  const TranslationSettings({super.key});

  @override
  State<TranslationSettings> createState() => _TranslationSettingsState();
}

class _TranslationSettingsState extends State<TranslationSettings> {
  String selectedValue = '';

  @override
  void initState() {
    super.initState();
    selectedValue = appdata.settings['translationSource'] ?? 'bing';
  }

  void _selectSource(String source) {
    setState(() {
      selectedValue = source;
      appdata.settings['translationSource'] = source;
      appdata.saveData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SmoothCustomScrollView(
      slivers: [
        SliverAppbar(title: Text(t.translation)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverToBoxAdapter(
            child: _SettingCard(
              children: [
                _SettingPartTitle(
                  title: t.translationService,
                  icon: Icons.translate_outlined,
                ),
                RadioGroup<String>(
                  groupValue: selectedValue,
                  onChanged: (value) {
                    if (value == null) return;
                  },
                  child: ListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    children: translationSourceList.entries
                        .where((e) {
                          final source =
                              translationSourceDisplayMap[e.key] as String;
                          return source != 'ai';
                        })
                        .map((entry) {
                          final source =
                              translationSourceDisplayMap[entry.key]!;
                          final isDeepL = source == 'deepl';
                          final isAi = [
                            'siliconFlow',
                            'doubao',
                            'gemini',
                            'qiniu',
                            'deepseek',
                            'openrouter',
                          ].contains(source);

                          return ListTile(
                            leading: ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [Color(0xFF6B8DE3), Color(0xFF8B5CF6)],
                              ).createShader(bounds),
                              child: Icon(
                                isAi ? Icons.auto_awesome : Icons.language,
                                size: 24,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(entry.key),
                            subtitle: Text(entry.value),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [Radio<String>(value: source)],
                            ),
                            onTap: () async {
                              if (isDeepL) {
                                final key =
                                    appdata.settings['deeplKey'] as String?;
                                if (key == null || key.isEmpty) {
                                  await showPopUpWidget(
                                    App.rootContext,
                                    const _DeepLConfigPage(),
                                  );
                                  return;
                                }
                              }
                              if (isAi) {
                                final keyRow = await AiDatabase
                                    .instance
                                    .aiApiKeyDao
                                    .getByProvider(source);
                                if (keyRow == null ||
                                    keyRow.apiKey.isEmpty ||
                                    !keyRow.isEnabled) {
                                  App.rootContext.showMessage(
                                    message: t
                                        .pleaseConfigureApiKeyInAiSettingsFirst,
                                  );
                                  return;
                                }
                              }
                              _selectSource(source);
                            },
                            onLongPress: isDeepL
                                ? () => showPopUpWidget(
                                    App.rootContext,
                                    const _DeepLConfigPage(),
                                  )
                                : null,
                          );
                        })
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: context.padding.bottom + 80,
          ),
          sliver: SliverToBoxAdapter(child: _ManualTranslationCard()),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// DeepL 配置页（仅保留此 AI 配置）
// ─────────────────────────────────────────────

class _DeepLConfigPage extends StatefulWidget {
  const _DeepLConfigPage();

  @override
  State<_DeepLConfigPage> createState() => _DeepLConfigPageState();
}

class _DeepLConfigPageState extends State<_DeepLConfigPage> {
  final _apiKeyCtrl = TextEditingController();
  bool _obscure = true;
  String _usage = '';

  @override
  void initState() {
    super.initState();
    _apiKeyCtrl.text = appdata.settings.s.deeplKey;
    _fetchUsage(_apiKeyCtrl.text);
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchUsage(String? apiKey) async {
    if (apiKey == null || apiKey.isEmpty) return;
    try {
      final response = await AppDio().request(
        'https://api-free.deepl.com/v2/usage',
        options: Options(
          method: 'POST',
          headers: {'Authorization': 'DeepL-Auth-Key $apiKey'},
          receiveTimeout: const Duration(seconds: 20),
        ),
      );
      final json = response.data;
      if (mounted) {
        setState(() {
          _usage = '${json['character_count']} / ${json['character_limit']}';
        });
      }
    } catch (_) {}
  }

  void _save() {
    final key = _apiKeyCtrl.text.trim();
    if (key.isEmpty) {
      App.rootContext.showMessage(message: t.apiKeyCannotBeEmpty);
      return;
    }
    appdata.settings.update((s) => s.copyWith(deeplKey: key));
    appdata.saveData();
    App.rootContext.showMessage(message: t.saved);
    App.rootContext.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopUpWidgetScaffold(
      title: 'DeepL',
      body: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.5,
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                child: SingleChildScrollView(
                  child: _SettingCard(
                    children: [
                      _SettingPartTitle(
                        title: t.apiConfiguration,
                        icon: Icons.key_outlined,
                      ),
                      // API Key
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextFormField(
                          controller: _apiKeyCtrl,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: 'API Key',
                            prefixIcon: const Icon(Icons.key, size: 20),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                          onChanged: (v) => _fetchUsage(v),
                        ),
                      ),
                      // 用量显示
                      if (_usage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Row(
                            children: [
                              const Icon(Icons.data_usage, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                '${t.usage} $_usage',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.colorScheme.outline,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.extended(
                onPressed: _save,
                label: Text(t.apply),
                icon: const Icon(Icons.check),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
