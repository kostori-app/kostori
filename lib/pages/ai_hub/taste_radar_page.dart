part of 'ai_hub_page.dart';

// ═════════════════════════════════════════════
// 模块：追番口味雷达
// ═════════════════════════════════════════════

class TasteRadarPage extends ConsumerStatefulWidget {
  const TasteRadarPage({super.key});

  @override
  ConsumerState<TasteRadarPage> createState() => _TasteRadarPageState();
}

class _TasteRadarPageState extends ConsumerState<TasteRadarPage>
    with _AnimeDataMixin {
  bool _isLoading = false;
  List<({String label, double value, int count})> _axes = [];
  int _likedCount = 0;

  Future<void> _run() async {
    setState(() => _isLoading = true);
    try {
      final data = await loadAnimeData();
      if (data.likedItems.isEmpty) {
        App.rootContext.showMessage(message: t.noLikedAnimeFound);
        return;
      }
      final top = data.tagData.take(6).toList();
      final maxV = top.isEmpty ? 1.0 : (top.first['value'] as num).toDouble();
      setState(() {
        _likedCount = data.likedItems.length;
        _axes = [
          for (final e in top)
            (
              label: e['word'].toString(),
              count: (e['value'] as num).toInt(),
              value: ((e['value'] as num).toDouble() / maxV).clamp(0.08, 1.0),
            ),
        ];
      });
    } catch (e) {
      App.rootContext.showMessage(message: '${t.error}: $e');
      Log.error('TasteRadar', e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: Appbar(title: Text(t.tasteRadar)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            _AiCard(
              icon: Icons.radar,
              title: t.tasteRadar,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.tasteRadarDescription,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
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
                              child: PolygonRefreshIndicator(),
                            )
                          : const Icon(Icons.radar),
                      label: Text(_isLoading ? t.analyzing : t.analyze),
                    ),
                  ),
                ],
              ),
            ),
            if (_axes.isNotEmpty) ...[
              const SizedBox(height: 8),
              _AiCard(
                icon: Icons.radar,
                title: '$_likedCount ${t.animes}',
                child: SizedBox(
                  height: 300,
                  child: RadarChart(
                    RadarChartData(
                      radarShape: RadarShape.polygon,
                      radarBackgroundColor: Colors.transparent,
                      radarBorderData: BorderSide(
                        color: scheme.outlineVariant,
                      ),
                      gridBorderData: BorderSide(
                        color: scheme.outlineVariant,
                        width: 0.6,
                      ),
                      tickBorderData: BorderSide(
                        color: scheme.outlineVariant,
                        width: 0.6,
                      ),
                      titlePositionPercentageOffset: 0.14,
                      getTitle: (index, angle) =>
                          RadarChartTitle(text: _axes[index].label),
                      dataSets: [
                        RadarDataSet(
                          fillColor: scheme.primary.withValues(alpha: 0.25),
                          borderColor: scheme.primary,
                          borderWidth: 2,
                          entryRadius: 2,
                          dataEntries: [
                            for (final a in _axes) RadarEntry(value: a.value),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in _axes)
                    Chip(
                      label: Text('${a.label}  ${a.count}'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
