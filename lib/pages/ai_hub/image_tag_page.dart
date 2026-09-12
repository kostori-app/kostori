part of 'ai_hub_page.dart';

// ═════════════════════════════════════════════
// 模块2：AI 绘画 Tag
// ═════════════════════════════════════════════

class ImageTagPage extends ConsumerStatefulWidget {
  const ImageTagPage({super.key});

  @override
  ConsumerState<ImageTagPage> createState() => _ImageTagPageState();
}

class _ImageTagPageState extends ConsumerState<ImageTagPage>
    with _AnimeDataMixin {
  bool _isLoading = false;
  List<String> _tags = [];
  String _source = aiHubProvider();
  String _style = 'anime';
  int _count = 30;

  static const _stylePrompts = <String, String>{
    'anime': '自然语言描述的动漫插画 tag',
    'danbooru': 'Danbooru 标准标签（用下划线连接）',
    'realistic': '写实摄影风格 tag',
  };

  // AI 出图
  AiImageGenConfig _imageConfig = const AiImageGenConfig();
  late final TextEditingController _imageBaseUrlCtrl;
  Uint8List? _imageBytes;
  bool _generatingImage = false;

  @override
  void initState() {
    super.initState();
    _imageConfig = AiImageGenConfig.load();
    _imageBaseUrlCtrl = TextEditingController(text: _imageConfig.baseUrl);
  }

  @override
  void dispose() {
    _imageBaseUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImageModel() async {
    final provider = _imageConfig.provider;
    final models = await (AiDatabase.instance.select(
      AiDatabase.instance.aiModels,
    )..where((t) => t.provider.equals(provider))).get();
    if (!mounted) return;
    var custom = _imageConfig.model;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    t.aiImageModel,
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextFormField(
                  initialValue: _imageConfig.model,
                  onChanged: (v) => custom = v,
                  decoration: InputDecoration(
                    hintText: t.custom,
                    isDense: true,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.check),
                      onPressed: () {
                        _updateImageConfig(
                          _imageConfig.copyWith(model: custom.trim()),
                        );
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: models.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(t.noModelsReturned),
                      )
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          for (final m in models)
                            ListTile(
                              title: Text(m.label),
                              selected: _imageConfig.model == m.modelId,
                              onTap: () {
                                _updateImageConfig(
                                  _imageConfig.copyWith(model: m.modelId),
                                );
                                Navigator.pop(ctx);
                              },
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _updateImageConfig(AiImageGenConfig config) {
    setState(() => _imageConfig = config);
    config.save();
  }

  Future<void> _generateImage() async {
    if (_tags.isEmpty) {
      App.rootContext.showMessage(message: t.aiImageNeedTags);
      return;
    }
    setState(() => _generatingImage = true);
    final res = await AiImageService.generate(
      prompt: _tags.join(', '),
      config: _imageConfig,
    );
    if (!mounted) return;
    setState(() {
      _generatingImage = false;
      if (res.success) _imageBytes = res.data;
    });
    if (res.error) {
      App.rootContext.showMessage(
        message: '${t.aiImageGen}: ${res.errorMessage}',
        level: LogLevel.error,
      );
    }
  }

  Future<void> _saveGeneratedImage() async {
    final bytes = _imageBytes;
    if (bytes == null) return;
    final filename =
        'kostori_ai_${DateTime.now().millisecondsSinceEpoch}.png';
    await ImageSaver.saveOrShareImage(bytes: bytes, filename: filename);
  }

  Future<void> _generate() async {
    setState(() {
      _isLoading = true;
      _tags = [];
    });
    try {
      final data = await loadAnimeData();
      if (data.likedItems.isEmpty) {
        App.rootContext.showMessage(message: t.noLikedAnimeFound);
        return;
      }

      await PromptInjectionStore.instance.ensureLoaded();
      final injection = PromptInjectionStore.instance.findById(
        kInjectionImageTag,
      );
      final systemPrompt = (injection?.content ?? imageTagSystemPrompt)
          .replaceAll('{animeCount}', '${data.likedItems.length}')
          .replaceAll('{animeNames}', data.animeNames)
          .replaceAll('{topTags}', data.topTags);

      final result = await AiConversationService().runTask(
        provider: _source,
        taskType: 'image_tag',
        prompt:
            '请根据我的番剧品味生成 $_count 个${_stylePrompts[_style]}，用英文逗号分隔',
        systemPrompt: systemPrompt,
        sessionTitle: 'AI Tag ${DateTime.now().toString().substring(0, 10)}',
      );

      if (result.success) {
        final raw = result.data;
        setState(() {
          _tags = raw
              .split(',')
              .map((t) => t.trim())
              .where((t) => t.isNotEmpty)
              .toList();
        });
      }
    } catch (e) {
      App.rootContext.showMessage(message: '${t.error}: $e');
      Log.error('ImageTag', e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbar(
        title: Text(t.imageTag),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              builder: (_) => const _SessionHistorySheet(taskType: 'image_tag'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            _AiSettingsCard(
              provider: _source,
              onChanged: (v) => setState(() => _source = v),
            ),
            const SizedBox(height: 8),
            _AiCard(
              icon: Icons.brush_outlined,
              title: t.aiTagStyle,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in [
                    ('anime', t.aiTagStyleAnime),
                    ('danbooru', t.aiTagStyleDanbooru),
                    ('realistic', t.aiTagStyleRealistic),
                  ])
                    SizedBox(
                      width: 92,
                      child: _RangeChip(
                        label: entry.$2,
                        selected: _style == entry.$1,
                        onTap: () => setState(() => _style = entry.$1),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _AiCard(
              icon: Icons.tag,
              title: t.aiTagCount,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final n in [20, 30, 50])
                    SizedBox(
                      width: 78,
                      child: _RangeChip(
                        label: '$n',
                        selected: _count == n,
                        onTap: () => setState(() => _count = n),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0),
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _generate,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: PolygonRefreshIndicator(),
                        )
                      : const Icon(Icons.brush),
                  label: Text(_isLoading ? t.generating : t.generateTag),
                ),
              ),
            ),
            if (_tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              _AiCard(
                icon: Icons.tag,
                title: t.generatedTags,
                trailing: IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: t.copyAll,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _tags.join(', ')));
                    App.rootContext.showMessage(message: t.copied);
                  },
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _tags.map((tag) {
                    return GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: tag));
                        App.rootContext.showMessage(message: t.tagCopied);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
            const SizedBox(height: 8),
            _buildImageGenCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGenCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget label(String text) => Text(
      text,
      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
    );
    final isSd = _imageConfig.engine == AiImageEngine.sd;

    return _AiCard(
      icon: Icons.image_outlined,
      title: t.aiImageGen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          label(t.aiSource),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in OpenAiProviderRegistry.allProviders.entries)
                ChoiceChip(
                  label: Text(s.value.name),
                  selected: _imageConfig.provider == s.key,
                  onSelected: (v) {
                    if (v) {
                      _updateImageConfig(
                        _imageConfig.copyWith(provider: s.key, model: ''),
                      );
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: 10),
          label(t.aiImageEngine),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text(t.aiImageEngineOpenai),
                selected: !isSd,
                onSelected: (v) {
                  if (v) {
                    _updateImageConfig(
                      _imageConfig.copyWith(engine: AiImageEngine.openai),
                    );
                  }
                },
              ),
              ChoiceChip(
                label: Text(t.aiImageEngineSd),
                selected: isSd,
                onSelected: (v) {
                  if (v) {
                    _updateImageConfig(
                      _imageConfig.copyWith(engine: AiImageEngine.sd),
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          label(t.aiImageSize),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in ['512x512', '768x768', '1024x1024'])
                ChoiceChip(
                  label: Text(s),
                  selected: _imageConfig.size == s,
                  onSelected: (v) {
                    if (v) {
                      _updateImageConfig(_imageConfig.copyWith(size: s));
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (isSd) ...[
            label(t.aiImageSteps),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final n in [20, 30, 50])
                  ChoiceChip(
                    label: Text('$n'),
                    selected: _imageConfig.steps == n,
                    onSelected: (v) {
                      if (v) {
                        _updateImageConfig(_imageConfig.copyWith(steps: n));
                      }
                    },
                  ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 10),
            Row(
              children: [
                label(t.aiImageModel),
                const Spacer(),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _pickImageModel,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 220),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            _imageConfig.model.isEmpty
                                ? t.set
                                : _imageConfig.model,
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.arrow_drop_down,
                          size: 16,
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (isSd) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _imageBaseUrlCtrl,
              decoration: InputDecoration(
                labelText: t.aiImageBaseUrl,
                hintText: 'http://127.0.0.1:7860',
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) =>
                  _updateImageConfig(_imageConfig.copyWith(baseUrl: v)),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _generatingImage ? null : _generateImage,
              icon: _generatingImage
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: PolygonRefreshIndicator(),
                    )
                  : const Icon(Icons.image),
              label: Text(
                _generatingImage ? t.aiImageGenerating : t.aiImageGenerate,
              ),
            ),
          ),
          if (_imageBytes != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(_imageBytes!, fit: BoxFit.contain),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _saveGeneratedImage,
                icon: const Icon(Icons.download_outlined, size: 18),
                label: Text(t.save),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
