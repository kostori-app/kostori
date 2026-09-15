part of 'package:kostori/pages/ai_hub/ai_hub_page.dart';

// ═════════════════════════════════════════════
// 模块：AI 冒险（故事选择 + 文字冒险 / 状态面板）
// ═════════════════════════════════════════════

class StoryPage extends ConsumerStatefulWidget {
  const StoryPage({super.key});

  @override
  ConsumerState<StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends ConsumerState<StoryPage> {
  bool _dragOver = false;

  @override
  void initState() {
    super.initState();
    StoryStore.instance.init();
  }

  Future<void> _new() async {
    await showPopUpWidget(App.rootContext, const _StoryEditor());
    if (mounted) setState(() {});
  }

  Future<void> _edit(Story s) async {
    await showPopUpWidget(App.rootContext, _StoryEditor(story: s));
    if (mounted) setState(() {});
  }

  Future<void> _export(Story s) async {
    await saveFile(
      data: utf8.encode(StoryStore.storyToMarkdown(s)),
      filename: '${s.name}.md',
    );
  }

  /// 导入一个故事：**同名则原地更新**（保留 id 与存档，方便升级故事版本）。
  /// 返回 'updated' / 'new'。
  Future<String> _importBytes(Uint8List bytes) async {
    final text = utf8.decode(bytes);
    final parsed = StoryStore.storyFromMarkdown(text);
    final key = parsed.key.trim();
    final name = parsed.name.trim();
    Story? existing;
    // 优先按稳定 key 匹配（名称可能撞车）；没有 key 的老故事回退按名称
    if (key.isNotEmpty) {
      for (final s in StoryStore.instance.stories) {
        if (!s.isBuiltin && s.key.trim() == key) {
          existing = s;
          break;
        }
      }
    }
    if (existing == null) {
      for (final s in StoryStore.instance.stories) {
        if (!s.isBuiltin && s.name.trim() == name) {
          existing = s;
          break;
        }
      }
    }
    final id = existing?.id ?? parsed.id;
    // 角色卡不写进故事文件；若 .md 内联了角色卡则并入独立存储
    final inline = parsed.characters;
    await StoryStore.instance.upsert(
      parsed.copyWith(id: id, characters: const []),
      asBase: true,
    );
    if (inline.isNotEmpty) {
      final current = StoryCharacterStore.instance.get(id);
      await StoryCharacterStore.instance.put(
        id,
        _mergeCharacters(current, inline),
      );
    }
    return existing != null ? 'updated' : 'new';
  }

  /// 合并角色卡：保留已有的，追加新版新增的（按 id 或名字去重）
  List<CharacterCard> _mergeCharacters(
    List<CharacterCard> current,
    List<CharacterCard> incoming,
  ) {
    final out = [...current];
    for (final c in incoming) {
      final dup = out.any(
        (x) =>
            x.id == c.id ||
            (c.name.trim().isNotEmpty && x.name.trim() == c.name.trim()),
      );
      if (!dup) out.add(c);
    }
    return out;
  }

  Future<void> _import() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['md', 'markdown', 'txt'],
    );
    if (result == null || result.files.isEmpty) return;
    try {
      final mode = await _importBytes(await result.files.first.readAsBytes());
      if (mounted) {
        App.rootContext.showMessage(
          message: mode == 'updated' ? t.storyUpdated : t.storyImported,
        );
        setState(() {});
      }
    } catch (e) {
      Log.error('importStory', e.toString());
      App.rootContext.showMessage(message: t.importFailed, level: LogLevel.error);
    }
  }

  /// 拖动导入故事（.md / .markdown / .txt）
  Future<void> _onDrop(DropDoneDetails detail) async {
    var imported = 0;
    for (final file in detail.files) {
      final name = file.name.toLowerCase();
      if (!name.endsWith('.md') &&
          !name.endsWith('.markdown') &&
          !name.endsWith('.txt')) {
        continue;
      }
      try {
        await _importBytes(await file.readAsBytes());
        imported++;
      } catch (_) {}
      // 同名会被原地更新（见 _importBytes）
    }
    if (!mounted) return;
    setState(() => _dragOver = false);
    if (imported > 0) {
      App.rootContext.showMessage(message: t.storyImported);
    } else if (detail.files.isNotEmpty) {
      App.rootContext.showMessage(
        message: t.importFailed,
        level: LogLevel.error,
      );
    }
  }

  Future<void> _delete(Story s) async {
    final ok = await StoryStore.instance.remove(s.id);
    if (!ok && mounted) {
      App.rootContext.showMessage(
        message: t.cannotDeletePreset,
        level: LogLevel.warning,
      );
    }
    if (mounted) setState(() {});
  }

  /// 重启世界：删除该故事存档（会话 + 状态），下次进入即从头开始
  Future<void> _restart(Story s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: t.storyRestart,
        content: Text(t.storyRestartConfirm),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.confirm),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await StorySessionStore.instance.ensureLoaded();
    final session = StorySessionStore.instance.get(s.id);
    if (session != null) {
      await AiConversationService().deleteSession(session.sessionId);
      await StorySessionStore.instance.clear(s.id);
    }
    if (mounted) {
      App.rootContext.showMessage(message: t.saved);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: StoryStore.instance,
      builder: (context, _) {
        final stories = StoryStore.instance.stories;
        return DropTarget(
          onDragDone: _onDrop,
          onDragEntered: (_) {
            if (mounted) setState(() => _dragOver = true);
          },
          onDragExited: (_) {
            if (mounted) setState(() => _dragOver = false);
          },
          child: Stack(
            children: [
              Scaffold(
                appBar: Appbar(
                  title: Text(t.rolePlay),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.receipt_long_outlined),
                      tooltip: t.aiRequestLog,
                      onPressed: () => showPopUpWidget(
                        App.rootContext,
                        const AiRequestLogPage(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.file_open_outlined),
                      tooltip: t.importEntries,
                      onPressed: _import,
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: t.storyNew,
                      onPressed: _new,
                    ),
                  ],
                ),
                body: stories.isEmpty
                    ? _emptyState(context)
                    : ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          for (final s in stories)
                            _StoryCard(
                              story: s,
                              onTap: () =>
                                  context.to(() => StoryGamePage(story: s)),
                              onEdit: () => _edit(s),
                              onExport: () => _export(s),
                              onRestart: () => _restart(s),
                              onDelete: s.isBuiltin ? null : () => _delete(s),
                            ),
                        ],
                      ),
                floatingActionButton: stories.isEmpty
                    ? null
                    : FloatingActionButton(
                        onPressed: _new,
                        tooltip: t.storyNew,
                        child: const Icon(Icons.add),
                      ),
              ),
              if (_dragOver)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      color: Theme.of(
                        context,
                      ).colorScheme.scrim.withValues(alpha: 0.45),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.download_outlined, size: 48),
                          const SizedBox(height: 12),
                          Text(t.storyDropHint),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// 空状态：图标 + 引导 + 新建 / 导入两个入口
  Widget _emptyState(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_stories_outlined,
              size: 64,
              color: scheme.onSurfaceVariant.toOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              t.storyNoStories,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _new,
                  icon: const Icon(Icons.add),
                  label: Text(t.storyNew),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _import,
                  icon: const Icon(Icons.file_open_outlined),
                  label: Text(t.importEntries),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({
    required this.story,
    required this.onTap,
    required this.onEdit,
    required this.onExport,
    required this.onRestart,
    this.onDelete,
  });

  final Story story;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onExport;
  final VoidCallback onRestart;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant, width: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            story.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (story.isBuiltin) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              t.builtin,
                              style: TextStyle(
                                fontSize: 9,
                                color: scheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                        ],
                        if (story.version.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'v${story.version}',
                              style: TextStyle(
                                fontSize: 9,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (story.description.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        story.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                tooltip: t.more,
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'export') onExport();
                  if (v == 'restart') onRestart();
                  if (v == 'delete') onDelete?.call();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text(t.edit)),
                  PopupMenuItem(value: 'export', child: Text(t.exportEntries)),
                  PopupMenuItem(value: 'restart', child: Text(t.storyRestart)),
                  if (onDelete != null)
                    PopupMenuItem(value: 'delete', child: Text(t.delete)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 引用块提示（`> …`）：单独成块，样式与旁白区分
class _StoryCallout extends StatelessWidget {
  const _StoryCallout({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 15, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 骰子判定结果卡片：由系统掷出，样式与普通消息框区分，只读（可复制）
class _DiceResultCard extends StatelessWidget {
  const _DiceResultCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: cs.tertiaryContainer.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.tertiary.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.casino_outlined,
              size: 16,
              color: cs.onTertiaryContainer,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: cs.onTertiaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
