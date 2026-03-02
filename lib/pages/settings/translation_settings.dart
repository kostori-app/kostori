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
    if (appdata.implicitData['isSiliconFlow'] == null) {
      appdata.implicitData['isSiliconFlow'] = true;
      appdata.writeImplicitData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SmoothCustomScrollView(
      slivers: [
        SliverAppbar(title: Text("Translation".tl)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverToBoxAdapter(
            child: _SettingCard(
              children: [
                _SettingPartTitle(
                  title: "翻译服务".tl,
                  icon: Icons.radio_button_unchecked_outlined,
                ),
                _SwitchSetting(
                  title: "使用硅基流动Api".tl,
                  settingKey: "isSiliconFlow",
                  dataSource: SwitchDataSource.implicit,
                ),
                RadioGroup<String>(
                  groupValue: selectedValue,
                  onChanged: (value) {
                    if (value == null) return;
                  },
                  child: ListView(
                    shrinkWrap: true,
                    children: translationSourceList.entries.toList().map((
                      entry,
                    ) {
                      return ListTile(
                        leading: (entry.value == 'AI大模型')
                            ? ShaderMask(
                                shaderCallback: (bounds) => LinearGradient(
                                  colors: [
                                    const Color(0xFF6B8DE3),
                                    const Color(0xFF8B5CF6),
                                  ],
                                ).createShader(bounds),
                                child: const Icon(
                                  Icons.auto_awesome,
                                  size: 24,
                                  color: Colors.white,
                                ),
                              )
                            : ShaderMask(
                                shaderCallback: (bounds) => LinearGradient(
                                  colors: [
                                    const Color(0xFF6B8DE3),
                                    const Color(0xFF8B5CF6),
                                  ],
                                ).createShader(bounds),
                                child: const Icon(
                                  Icons.language,
                                  size: 24,
                                  color: Colors.white,
                                ),
                              ),
                        title: Text(entry.key),
                        subtitle: Text(entry.value),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Radio<String>(
                              value:
                                  translationSourceDisplayMap[entry.key]
                                      as String,
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.arrow_forward_ios_rounded),
                          ],
                        ),
                        onLongPress: () async {
                          final source =
                              translationSourceDisplayMap[entry.key]!;
                          final isTraditional = [
                            'bing',
                            'google',
                          ].contains(source);
                          if (!isTraditional) {
                            await showTranslationSourceConfig(
                              title: source,
                              source: source,
                            );
                          }
                        },
                        onTap: () async {
                          final source =
                              translationSourceDisplayMap[entry.key]!;

                          final isTraditional = [
                            'bing',
                            'google',
                          ].contains(source);
                          if (isTraditional) {
                            setState(() {
                              selectedValue = source;
                              appdata.settings['translationSource'] = source;
                              appdata.saveData();
                            });
                          } else {
                            final configs =
                                appdata.settings['translationConfig']
                                    as List<dynamic>? ??
                                [];
                            final sourceConfig = configs.firstWhere(
                              (e) => e['source'] == source,
                              orElse: () => null,
                            );
                            if (sourceConfig == null) {
                              await showTranslationSourceConfig(
                                title: source,
                                source: source,
                              );
                            } else {
                              final isValid = source == 'deepl'
                                  ? sourceConfig['apiKey']?.isNotEmpty == true
                                  : sourceConfig['model']?.isNotEmpty == true &&
                                        sourceConfig['aiTranslatePrompt']
                                                ?.isNotEmpty ==
                                            true &&
                                        sourceConfig['apiKey']?.isNotEmpty ==
                                            true;
                              final isSiliconFlow =
                                  appdata.implicitData['isSiliconFlow'] ?? true;
                              if (isValid ||
                                  (!isSiliconFlow && source == 'siliconFlow')) {
                                setState(() {
                                  selectedValue = source;
                                  appdata.settings['translationSource'] =
                                      source;
                                  appdata.saveData();
                                });
                              } else {
                                await showTranslationSourceConfig(
                                  title: source,
                                  source: source,
                                );
                              }
                            }
                          }
                        },
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> showTranslationSourceConfig({
  required String title,
  required String source,
}) async {
  showPopUpWidget(
    App.rootContext,
    TranslationSourceConfigPage(title: title, source: source),
  );
}

class TranslationSourceConfigPage extends StatefulWidget {
  final String title;
  final String source;

  const TranslationSourceConfigPage({
    super.key,
    required this.title,
    required this.source,
  });

  @override
  State<TranslationSourceConfigPage> createState() =>
      _TranslationSourceConfigPageState();
}

class _TranslationSourceConfigPageState
    extends State<TranslationSourceConfigPage> {
  late final TranslationSource? translationSource;
  late final String aiTranslatePrompt;
  late Map<String, dynamic>? sourceConfig;
  bool isSiliconFlow = true;
  bool visibility = false;
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _aiTranslatePromptController =
      TextEditingController();
  final configs = appdata.settings['translationConfig'] as List<dynamic>? ?? [];
  String deeplApi = '';

  String getModel(TranslationSource translationSource) {
    return switch (translationSource) {
      TranslationSource.bing => 'Bing',
      TranslationSource.google => 'Google',
      TranslationSource.siliconFlow => 'THUDM/GLM-4-9B-0414',
      TranslationSource.doubao => 'doubao-1-5-lite-32k-250115',
      TranslationSource.gemini => 'gemini-2.5-flash-lite',
      TranslationSource.deepl => '',
    };
  }

  @override
  void initState() {
    super.initState();
    translationSource = TranslationSourceExt.fromString(widget.source);
    aiTranslatePrompt = appdata.settings['aiTranslatePrompt'] ?? '';
    isSiliconFlow = appdata.implicitData['isSiliconFlow'] ?? true;
    findSourceConfig();
    initializationSource();
    _modelController.text = sourceConfig!['model'];
    _apiKeyController.text = sourceConfig!['apiKey'];
    _aiTranslatePromptController.text = sourceConfig!['aiTranslatePrompt'];
  }

  void findSourceConfig() {
    sourceConfig = configs.firstWhere(
      (e) => e['source'] == widget.source,
      orElse: () => null,
    );
  }

  Future<void> initializationSource() async {
    if (sourceConfig == null) {
      sourceConfig = {
        'source': widget.source,
        'model': getModel(translationSource!),
        'aiTranslatePrompt': appdata.settings['aiTranslatePrompt'],
        'apiKey': '',
      };
      configs.add(sourceConfig);
      appdata.settings['translationConfig'] = configs;
      appdata.saveData();
      findSourceConfig();
    }
    if (TranslationSource.deepl == translationSource) {
      deeplApi = await _getDeeplApiLimit();
      setState(() {});
    }
  }

  void _save() {
    if (translationSource != TranslationSource.deepl) {
      if (sourceConfig!['model']?.isEmpty == true) return;
      if (sourceConfig!['aiTranslatePrompt']?.isEmpty == true) return;
    }
    if (sourceConfig!['apiKey']?.isEmpty == true) return;

    // 保存
    appdata.settings['translationConfig'] = configs;
    appdata.saveData();

    App.rootContext.showMessage(message: '保存成功');
  }

  Future<String> _getDeeplApiLimit() async {
    try {
      final apiKey = sourceConfig!['apiKey'];
      final headers = {'Authorization': 'DeepL-Auth-Key $apiKey'};
      final response = await AppDio().request(
        "https://api-free.deepl.com/v2/usage",
        options: Options(
          method: 'POST',
          headers: headers,
          receiveTimeout: const Duration(seconds: 20),
        ),
      );
      final json = response.data;
      return '${json['character_count']} / ${json['character_limit']} ';
    } on DioException catch (e) {
      final message =
          e.response?.data?['message']?.toString() ?? e.message ?? '网络请求失败';

      App.rootContext.showMessage(message: message);
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopUpWidgetScaffold(
      title: widget.title,
      body: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(
                    context,
                  ).copyWith(scrollbars: false),
                  child: SingleChildScrollView(
                    child: _buildTranslationSourceWidget(context),
                  ),
                ),
              ),
            ),
            if (isSiliconFlow ||
                TranslationSource.siliconFlow != translationSource)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: FilledButton(onPressed: _save, child: Text('Apply'.tl)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranslationSourceWidget(BuildContext context) {
    return _SettingCard(
      children: [
        _SettingPartTitle(
          title: "Api Configuration".tl,
          icon: Icons.radio_button_unchecked_outlined,
        ),
        if (isSiliconFlow ||
            TranslationSource.siliconFlow != translationSource) ...[
          if (TranslationSource.deepl != translationSource)
            _buildInputSection(context),
          _buildApiKeyInputSection(context),
          if (TranslationSource.deepl != translationSource)
            _buildPromptEditor(context),
          if (TranslationSource.deepl == translationSource)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(deeplApi),
            ),
        ],
      ],
    );
  }

  Widget _buildInputSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.model_training, size: 20),
              const SizedBox(width: 8),
              Text(
                'Model Name'.tl,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _modelController,
            decoration: InputDecoration(
              hintText: getModel(translationSource!),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
              helperMaxLines: 3,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'This field cannot be empty'.tl;
              }
              return null;
            },
            onChanged: (value) {
              sourceConfig!['model'] = value;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildApiKeyInputSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.key, size: 20),
              const SizedBox(width: 8),
              Text('API Key', style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _apiKeyController,
            decoration: InputDecoration(
              hintText: 'apiKey',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  !visibility ? Icons.visibility_off : Icons.visibility,
                  size: 20,
                ),
                onPressed: () {
                  visibility = !visibility;
                  setState(() {});
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'API key cannot be empty'.tl;
              }
              return null;
            },
            onChanged: (value) {
              sourceConfig!['apiKey'] = value;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPromptEditor(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_note, size: 20),
              const SizedBox(width: 8),
              Text(
                'Translation Prompt'.tl,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _aiTranslatePromptController,
            maxLines: 20,
            decoration: InputDecoration(
              hintText:
                  'Please enter translation prompt, use @a as the placeholder for the target language'
                      .tl,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              helperText:
                  'The prompt must contain @a as the placeholder for the target language'
                      .tl,
              helperMaxLines: 2,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'This field cannot be empty'.tl;
              }
              if (!value.contains('@a')) {
                return 'The prompt must contain @a placeholder'.tl;
              }
              return null;
            },
            onChanged: (value) {
              sourceConfig!['aiTranslatePrompt'] = value;
            },
          ),
        ],
      ),
    );
  }
}
