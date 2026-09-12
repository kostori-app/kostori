part of 'ai_hub_page.dart';

enum _SummaryRange { week, month, quarter, custom }

class SummaryPage extends ConsumerStatefulWidget {
  const SummaryPage({super.key, this.initialRange});

  final _SummaryRange? initialRange;

  @override
  ConsumerState<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends ConsumerState<SummaryPage> {
  bool _isLoading = false;
  String? _result;
  String _source = aiHubProvider();
  late _SummaryRange _range;
  DateTimeRange? _customRange;

  @override
  void initState() {
    super.initState();
    _range = widget.initialRange ?? _SummaryRange.week;
  }

  // 本次生成的统计数据（用于结果卡片上方的统计条）
  int _activeTitles = 0;
  int _totalWatchSec = 0;
  int _totalClicks = 0;

  Future<void> _generate() async {
    setState(() {
      _isLoading = true;
      _result = null;
    });
    try {
      final allStats = await StatsManager().getStatsAll();
      final now = DateTime.now();
      final cutoff = switch (_range) {
        _SummaryRange.week => now.subtract(const Duration(days: 7)),
        _SummaryRange.month => DateTime(now.year, now.month, 1),
        _SummaryRange.quarter => DateTime(
          now.year,
          ((now.month - 1) ~/ 3) * 3 + 1,
          1,
        ),
        _SummaryRange.custom =>
          _customRange?.start ?? now.subtract(const Duration(days: 7)),
      };

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
        App.rootContext.showMessage(message: t.noActivityInTimeRange);
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

      final rangeLabel = switch (_range) {
        _SummaryRange.week => t.summaryThisWeek,
        _SummaryRange.month => t.summaryThisMonth,
        _SummaryRange.quarter => t.summaryThisQuarter,
        _SummaryRange.custom => t.aiCustomRange,
      };
      final prompt =
          '''
Generate a $rangeLabel anime watch report based on the following data:

- Active titles: ${activeStats.length}
- Total watch time: ${Utils.formatHMS(totalWatch)}
- Total clicks: $totalClicks
- Watched titles: ${watchedTitles.take(20).join(', ')}
''';

      await PromptInjectionStore.instance.ensureLoaded();
      final injection = PromptInjectionStore.instance.findById(
        kInjectionSummary,
      );
      final systemPrompt = injection?.content ?? summarySystemPrompt;

      final result = await AiConversationService().runTask(
        provider: _source,
        taskType: 'summary',
        prompt: prompt,
        systemPrompt: systemPrompt,
        sessionTitle: '$rangeLabel总结 ${now.toString().substring(0, 10)}',
      );

      if (result.success) {
        setState(() {
          _result = result.data;
          _activeTitles = activeStats.length;
          _totalWatchSec = totalWatch;
          _totalClicks = totalClicks;
        });
      } else {
        App.rootContext.showMessage(message: result.errorMessage ?? 'Error');
      }
    } catch (e) {
      App.rootContext.showMessage(message: '${t.error}: $e');
      Log.error('Summary', e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: _customRange,
    );
    if (picked == null) return;
    setState(() {
      _customRange = picked;
      _range = _SummaryRange.custom;
    });
  }

  Widget _statHeader(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget stat(IconData icon, String label, String value) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: scheme.primary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        stat(
          Icons.schedule,
          t.statsWatchDuration,
          Utils.formatHMS(_totalWatchSec),
        ),
        stat(Icons.movie_outlined, t.aiStatActiveTitles, '$_activeTitles'),
        stat(Icons.touch_app_outlined, t.statsClicks, '$_totalClicks'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbar(
        title: Text(t.summary),
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
            _AiSettingsCard(
              provider: _source,
              onChanged: (v) => setState(() => _source = v),
            ),
            const SizedBox(height: 8),
            _AiCard(
              icon: Icons.date_range,
              title: t.timeRange,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in [
                    (_SummaryRange.week, t.thisWeek),
                    (_SummaryRange.month, t.thisMonth),
                    (_SummaryRange.quarter, t.summaryThisQuarter),
                    (_SummaryRange.custom, t.aiCustomRange),
                  ])
                    SizedBox(
                      width: 84,
                      child: _RangeChip(
                        label: entry.$2,
                        selected: _range == entry.$1,
                        onTap: () => entry.$1 == _SummaryRange.custom
                            ? _pickCustomRange()
                            : setState(() => _range = entry.$1),
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
                        child: PolygonRefreshIndicator(),
                      )
                    : const Icon(Icons.summarize),
                label: Text(_isLoading ? t.generating : t.generateSummary),
              ),
            ),
            if (_result != null) ...[
              const SizedBox(height: 8),
              _AiResultCard(
                icon: Icons.article_outlined,
                title: t.summaryReport,
                content: _result!,
                header: _statHeader(context),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
