// AI 会话记录（ai_tasks 表）：查看 / 删除不再需要的消息条目。
// 典型用途：删掉存档后残留的记忆、辅助任务（生成设定/标题/头像等）产生的噪音。

part of 'settings_page.dart';

class AiTasksManagerPage extends StatefulWidget {
  const AiTasksManagerPage({super.key});

  @override
  State<AiTasksManagerPage> createState() => _AiTasksManagerPageState();
}

class _AiTasksManagerPageState extends State<AiTasksManagerPage> {
  static const _filters = ['all', 'story', 'chat', 'group', 'aux', 'orphan'];

  String _filter = 'all';
  List<AiTask> _tasks = const [];
  Set<String> _sessionIds = const {};
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final tasks = await AiTaskDatabase.instance.aiTaskDao.watchAll().first;
      final sessions = await AiDatabase.instance.aiSessionDao
          .watchAllSessions()
          .first;
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _sessionIds = {for (final s in sessions) s.sessionId};
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isOrphan(AiTask t) => !_sessionIds.contains(t.sessionId);

  List<AiTask> get _filtered => _tasks.where((t) {
    switch (_filter) {
      case 'story':
        return t.taskType == 'story';
      case 'chat':
        return t.taskType == 'chat';
      case 'group':
        return t.taskType == 'group';
      case 'aux':
        return t.taskType != 'story' &&
            t.taskType != 'chat' &&
            t.taskType != 'group';
      case 'orphan':
        return _isOrphan(t);
      default:
        return true;
    }
  }).toList();

  String _label(String f) => switch (f) {
    'story' => t.aiTaskStory,
    'chat' => t.aiTaskChat,
    'group' => t.aiTaskGroup,
    'aux' => t.aiTaskAux,
    'orphan' => t.aiTaskOrphan,
    _ => t.aiTaskAll,
  };

  String _fmt(DateTime time) =>
      '${time.year}-${time.month.toString().padLeft(2, '0')}-'
      '${time.day.toString().padLeft(2, '0')} '
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  Future<void> _delete(AiTask task) async {
    await AiConversationService().deleteMessage(task.id);
    await _reload();
  }

  Future<void> _deleteFiltered() async {
    final items = _filtered;
    if (items.isEmpty || _busy) return;
    final ok = await showDialog<bool>(
      context: App.rootContext,
      builder: (ctx) => ContentDialog(
        title: t.delete,
        content: Text('${t.areYouSureYouWantToClearYourHistory}\n(${items.length})'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.confirm),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    for (final task in items) {
      try {
        await AiConversationService().deleteMessage(task.id);
      } catch (_) {}
    }
    setState(() => _busy = false);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = _filtered;
    return PopUpWidgetScaffold(
      title: t.aiTaskRecords,
      tailing: [
        if (_busy)
          const Padding(
            padding: EdgeInsets.all(12),
            child: PolygonRefreshIndicator(size: 18),
          )
        else
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: t.aiTaskDeleteFiltered,
            onPressed: items.isEmpty ? null : _deleteFiltered,
          ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: CapsuleOptions(
                children: [
                  for (final f in _filters)
                    CapsuleOption(
                      text: _label(f),
                      isSelected: _filter == f,
                      onTap: () => setState(() => _filter = f),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: PolygonRefreshIndicator())
                : items.isEmpty
                ? Center(
                    child: Text(
                      t.aiTaskEmpty,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    itemCount: items.length,
                    itemBuilder: (context, i) => _taskCard(items[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _taskCard(AiTask task) {
    final scheme = Theme.of(context).colorScheme;
    final orphan = _isOrphan(task);
    final output = task.outputContent ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          title: Text(
            '${task.role} · ${task.taskType}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            [
              _fmt(task.createdAt),
              if (task.modelName != null && task.modelName!.isNotEmpty)
                task.modelName!,
              if (orphan) t.aiTaskOrphanHint,
            ].join(' · '),
            style: TextStyle(
              fontSize: 11,
              color: orphan ? scheme.error : scheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: t.delete,
            onPressed: () => _delete(task),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
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
            SizedBox(
              width: double.infinity,
              child: SelectableText(contextMenuBuilder: appEditableSelectionContextMenu,
                task.inputContent,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            if (output.isNotEmpty) ...[
              const SizedBox(height: 10),
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
              SizedBox(
                width: double.infinity,
                child: SelectableText(contextMenuBuilder: appEditableSelectionContextMenu,
                  output,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
