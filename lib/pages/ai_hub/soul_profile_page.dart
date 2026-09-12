part of 'ai_hub_page.dart';
// ═════════════════════════════════════════════
// 模块1：灵魂侧写
// ═════════════════════════════════════════════

class SoulProfilePage extends ConsumerStatefulWidget {
  const SoulProfilePage({super.key});

  @override
  ConsumerState<SoulProfilePage> createState() => _SoulProfilePageState();
}

class _SoulProfilePageState extends ConsumerState<SoulProfilePage>
    with _AnimeDataMixin {
  bool _isLoading = false;
  String? _result;
  String _source = 'siliconFlow';

  Future<void> _run() async {
    setState(() {
      _isLoading = true;
      _result = null;
    });
    try {
      final data = await loadAnimeData();
      if (data.likedItems.isEmpty) {
        App.rootContext.showMessage(message: t.noLikedAnimeFound);
        return;
      }
      await PromptInjectionStore.instance.ensureLoaded();
      final injection = PromptInjectionStore.instance.findById(
        kInjectionSoulProfiler,
      );
      final systemPrompt = (injection?.content ?? soulProfilerSystemPrompt)
          .replaceAll('{animeCount}', '${data.likedItems.length}')
          .replaceAll('{animeNames}', data.animeNames)
          .replaceAll('{topTags}', data.topTags);

      final result = await AiConversationService().runTask(
        provider: _source,
        taskType: 'soul_profile',
        prompt: '分析我的番剧品味，给出灵魂侧写',
        systemPrompt: systemPrompt,
        sessionTitle: '灵魂侧写 ${DateTime.now().toString().substring(0, 10)}',
      );
      if (result.success) {
        setState(() => _result = result.data);
      } else {
        App.rootContext.showMessage(message: result.errorMessage ?? 'Error');
      }
    } catch (e) {
      App.rootContext.showMessage(message: '${t.error}: $e');
      Log.error('SoulProfile', e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbar(
        title: Text(t.soulProfile),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              builder: (_) =>
                  const _SessionHistorySheet(taskType: 'soul_profile'),
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
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _run,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: PolygonRefreshIndicator(),
                      )
                    : const Icon(Icons.analytics),
                label: Text(_isLoading ? t.analyzing : t.analyze),
              ),
            ),
            if (_result != null) ...[
              const SizedBox(height: 8),
              _AiResultCard(
                icon: Icons.auto_awesome,
                title: t.soulProfileTitle,
                content: _result!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
