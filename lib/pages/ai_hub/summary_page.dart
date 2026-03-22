part of 'ai_hub_page.dart';

enum _SummaryRange { week, month }

class SummaryPage extends ConsumerStatefulWidget {
  const SummaryPage({super.key});

  @override
  ConsumerState<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends ConsumerState<SummaryPage> {
  bool _isLoading = false;
  String? _result;
  String _source = 'siliconFlow';
  _SummaryRange _range = _SummaryRange.week;

  Future<void> _generate() async {
    setState(() {
      _isLoading = true;
      _result = null;
    });
    try {
      final allStats = await StatsManager().getStatsAll();
      final now = DateTime.now();
      final cutoff = _range == _SummaryRange.week
          ? now.subtract(const Duration(days: 7))
          : DateTime(now.year, now.month, 1);

      final activeStats = allStats.where((s) {
        final allEvents = [
          ...s.totalClickCount,
          ...s.totalWatchDurations,
          ...s.comment,
          ...s.rating,
        ];
        return allEvents.any((e) => e.date.isAfter(cutoff));
      }).toList();

      if (activeStats.isEmpty) {
        App.rootContext.showMessage(message: '该时间段内暂无活动记录'.tl);
        return;
      }

      int totalWatch = 0;
      int totalClicks = 0;
      final watchedTitles = <String>[];

      for (final s in activeStats) {
        for (final e in s.totalWatchDurations) {
          if (e.date.isAfter(cutoff)) {
            for (final r in e.platformEventRecords) {
              totalWatch += r.value;
            }
          }
        }
        for (final e in s.totalClickCount) {
          if (e.date.isAfter(cutoff)) {
            for (final r in e.platformEventRecords) {
              totalClicks += r.value;
            }
          }
        }
        if (s.title != null) watchedTitles.add(s.title!);
      }

      final rangeLabel = _range == _SummaryRange.week ? '本周' : '本月';
      final prompt =
          '''
Generate a $rangeLabel anime watch report based on the following data:

- Active titles: ${activeStats.length}
- Total watch time: ${Utils.formatHMS(totalWatch)}
- Total clicks: $totalClicks
- Watched titles: ${watchedTitles.take(20).join(', ')}
''';

      final cfg = await AiDatabase.instance.aiConfigDao.getByKey(
        _summaryConfigKey,
      );
      if (cfg == null) {
        App.rootContext.showMessage(message: 'AI配置缺失'.tl);
        return;
      }

      final result = await AiConversationService().runTask(
        provider: _source,
        taskType: 'summary',
        prompt: prompt,
        configKey: _summaryConfigKey,
        sessionTitle: '$rangeLabel总结 ${now.toString().substring(0, 10)}',
      );

      if (result.success) {
        setState(() => _result = result.data);
      } else {
        App.rootContext.showMessage(message: result.errorMessage ?? 'Error');
      }
    } catch (e) {
      App.rootContext.showMessage(message: 'Error: $e');
      Log.error('Summary', e.toString());
    } finally {
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
                _range == _SummaryRange.week ? '本周总结' : '本月总结',
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
      ImageSaver.showResult(success: false, message: '截图失败: $e');
    } finally {
      await ref.read(imagesProvider.notifier).loadImages();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbar(
        title: Text('周月总结'.tl),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              builder: (_) => const _SessionHistorySheet(taskType: 'summary'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            // ── 服务商 + 模型选择 ──────────────────
            _AiCard(
              icon: Icons.psychology,
              title: 'AI 设置'.tl,
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
            _AiCard(
              icon: Icons.date_range,
              title: '时间范围'.tl,
              child: Row(
                children: [
                  Expanded(
                    child: _RangeChip(
                      label: '本周'.tl,
                      selected: _range == _SummaryRange.week,
                      onTap: () => setState(() => _range = _SummaryRange.week),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _RangeChip(
                      label: '本月'.tl,
                      selected: _range == _SummaryRange.month,
                      onTap: () => setState(() => _range = _SummaryRange.month),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _generate,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.summarize),
                label: Text(_isLoading ? 'Generating...'.tl : '生成总结'.tl),
              ),
            ),
            if (_result != null) ...[
              const SizedBox(height: 8),
              _AiCard(
                icon: Icons.article_outlined,
                title: '总结报告'.tl,
                trailing: IconButton(
                  icon: const Icon(Icons.download_outlined, size: 18),
                  tooltip: '导出截图'.tl,
                  onPressed: _exportScreenshot,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
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
