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
  String _source = 'siliconFlow';

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
        prompt: '请根据我的番剧品味生成 AI 绘画 tag',
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
            _AiCard(
              icon: Icons.psychology,
              title: t.aiSettings,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _AiSourceSelector(
                    selected: _source,
                    onChanged: (v) => setState(() => _source = v),
                  ),
                  const SizedBox(height: 8),
                  _ModelSelector(
                    provider: _source,
                    onProviderChanged: (v) => setState(() => _source = v),
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
          ],
        ),
      ),
    );
  }
}
