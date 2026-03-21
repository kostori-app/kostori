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
  final _promptCtrl = TextEditingController();
  bool _isLoading = false;
  String? _result;
  String _source = 'siliconFlow';

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (_promptCtrl.text.isEmpty) {
      App.rootContext.showMessage(message: 'Please enter a prompt'.tl);
      return;
    }
    setState(() {
      _isLoading = true;
      _result = null;
    });
    try {
      final data = await loadAnimeData();
      if (data.likedItems.isEmpty) {
        App.rootContext.showMessage(message: 'No liked anime found'.tl);
        return;
      }
      final cfg = await AiDatabase.instance.aiConfigDao.getByKey(
        _soulProfileConfigKey,
      );
      if (cfg == null) {
        App.rootContext.showMessage(message: 'AI配置缺失'.tl);
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
        prompt: _promptCtrl.text,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbar(
        title: Text('灵魂侧写'.tl),
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
            _AiSourceSelector(
              selected: _source,
              onChanged: (v) => setState(() => _source = v),
            ),
            const SizedBox(height: 8),
            _AiCard(
              icon: Icons.edit_note,
              title: 'Your Question'.tl,
              child: Column(
                children: [
                  TextField(
                    controller: _promptCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: '例如：分析我的番剧品味'.tl,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                      label: Text(
                        _isLoading ? 'Analyzing...'.tl : 'Analyze'.tl,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_result != null) ...[
              const SizedBox(height: 8),
              _AiCard(
                icon: Icons.auto_awesome,
                title: 'Result'.tl,
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
