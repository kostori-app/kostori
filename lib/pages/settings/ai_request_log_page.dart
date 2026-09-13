// AI 请求日志：查看每次对话/任务的请求与响应

part of 'settings_page.dart';

class AiRequestLogPage extends StatefulWidget {
  const AiRequestLogPage({super.key});

  @override
  State<AiRequestLogPage> createState() => _AiRequestLogPageState();
}

class _AiRequestLogPageState extends State<AiRequestLogPage> {
  @override
  void initState() {
    super.initState();
    AiRequestLogService.instance.ensureLoaded();
  }

  String _fmt(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}';

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: t.aiRequestLog,
        content: Text(t.areYouSureYouWantToClearYourHistory),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.confirm),
          ),
        ],
      ),
    );
    if (ok == true) await AiRequestLogService.instance.clear();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopUpWidgetScaffold(
      title: t.aiRequestLog,
      tailing: [
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: t.clear,
          onPressed: _clear,
        ),
      ],
      body: ListenableBuilder(
            listenable: AiRequestLogService.instance,
            builder: (context, _) {
              final entries = AiRequestLogService.instance.entries;
              if (entries.isEmpty) {
                return Center(
                  child: Text(
                    t.noHistoryYet,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                );
              }
              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  for (final e in entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _SettingCard(
                        padding: EdgeInsets.zero,
                        children: [
                          ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                            title: Text(
                              '${e.taskType} · ${e.provider}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              [
                                _fmt(e.time),
                                if (e.model != null && e.model!.isNotEmpty)
                                  e.model!,
                                '${e.durationMs}ms',
                                if (e.tokens != null) '${e.tokens} tok',
                                if (e.error != null) e.error!,
                              ].join(' · '),
                              style: const TextStyle(fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            childrenPadding: const EdgeInsets.fromLTRB(
                              16,
                              0,
                              16,
                              12,
                            ),
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  t.aiLogRequest,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: scheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              SelectableText(
                                e.request,
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  t.aiLogResponse,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: scheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              SelectableText(
                                e.response,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
    );
  }
}
