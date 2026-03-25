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
      final cfg = await AiDatabase.instance.aiConfigDao.getByKey(
        _soulProfileConfigKey,
      );
      if (cfg == null) {
        App.rootContext.showMessage(message: t.aiConfigMissing);
        return;
      }
      final systemPrompt = cfg.systemPrompt
          .replaceAll('{animeCount}', '${data.likedItems.length}')
          .replaceAll('{animeNames}', data.animeNames)
          .replaceAll('{topTags}', data.topTags);

      await AiDatabase.instance.aiConfigDao.upsert(
        AiConfigsCompanion.insert(
          configKey: '${_soulProfileConfigKey}_runtime',
          systemPrompt: systemPrompt,
          temperature: const Value(0.9),
        ),
      );

      final result = await AiConversationService().runTask(
        provider: _source,
        taskType: 'soul_profile',
        prompt: '分析我的番剧品味，给出灵魂侧写',
        configKey: '${_soulProfileConfigKey}_runtime',
        sessionTitle: '灵魂侧写 ${DateTime.now().toString().substring(0, 10)}',
      );
      if (result.success) {
        setState(() => _result = result.data);
      } else {
        App.rootContext.showMessage(message: result.errorMessage ?? 'Error');
      }
    } catch (e) {
      App.rootContext.showMessage(message: 'Error: $e');
      Log.error('SoulProfile', e.toString());
    } finally {
      await AiDatabase.instance.aiConfigDao.deleteByKey(
        '${_soulProfileConfigKey}_runtime',
      );
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportScreenshot() async {
    if (_result == null) return;
    try {
      final bytes = await ImageSaver.captureWidgetToImage(
        context: context,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '灵魂侧写',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              CustomMarkdownWidget(data: _result!),
            ],
          ),
        ),
      );
      if (bytes == null) return;
      final filename = 'summary_${DateTime.now().millisecondsSinceEpoch}.png';
      await ImageSaver.saveOrShareImage(bytes: bytes, filename: filename);
    } catch (e) {
      ImageSaver.showResult(success: false, message: t.screenshotFailed);
    } finally {
      await ref.read(imagesProvider.notifier).loadImages();
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
                  _ModelSelector(provider: _source),
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
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.analytics),
                label: Text(_isLoading ? t.analyzing : t.analyze),
              ),
            ),
            if (_result != null) ...[
              const SizedBox(height: 8),
              _AiCard(
                icon: Icons.auto_awesome,
                title: t.result,
                trailing: IconButton(
                  icon: const Icon(Icons.download_outlined, size: 18),
                  tooltip: t.exportScreenshot,
                  onPressed: _exportScreenshot,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    CustomMarkdownWidget(data: _result!),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
