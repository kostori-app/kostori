part of 'settings_page.dart';

class LogSettings extends StatefulWidget {
  const LogSettings({super.key});

  @override
  State<LogSettings> createState() => _LogSettingsState();
}

class _LogSettingsState extends State<LogSettings> {
  @override
  void initState() {
    super.initState();
    // 预置归档设置默认值（与 Log 读取一致，保证滑块与行为同步）。
    // 延迟到帧后再写，避免 build 阶段 notify 触发 setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appdata.implicitData.putIfAbsent('logRetainCount', () => 2);
      appdata.implicitData.putIfAbsent('logFileSizeMb', () => 4);
      appdata.writeImplicitData();
    });
  }

  Future<void> _exportLogFile() async {
    final content = await Log.readAllLogs();
    if (content.trim().isEmpty) {
      context.showMessage(message: t.noData);
      return;
    }
    saveLog(content);
  }

  void saveLog(String log) async {
    saveFile(data: utf8.encode(log), filename: 'log.txt');
  }

  /// 清空日志（内存列表 + 落盘文件）
  Future<void> _clearAllLogs() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.clear),
        content: Text(t.clearLogsFileConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.delete),
          ),
        ],
      ),
    );
    if (ok == true) {
      Log.clear();
      await Log.deleteLogFiles();
      if (mounted) context.showMessage(message: t.cleared);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SmoothCustomScrollView(
      slivers: [
        SliverAppbar(title: Text(t.log)),
        // ── 日志管理 ──────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverToBoxAdapter(
            child: _SettingCard(
              children: [
                _SettingPartTitle(title: t.log, icon: Icons.error_outline),
                _CallbackSetting(
                  title: t.openLog,
                  actionTitle: t.open,
                  callback: () => context.to(() => const LogsPage()),
                ),
                _CallbackSetting(
                  title: t.exportLogFile,
                  actionTitle: t.export,
                  callback: _exportLogFile,
                ),
                _CallbackSetting(
                  title: t.clearLog,
                  actionTitle: t.clear,
                  callback: _clearAllLogs,
                ),
              ],
            ),
          ),
        ),
        // ── 日志设置 ──────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverToBoxAdapter(
            child: _SettingCard(
              children: [
                _SettingPartTitle(
                  title: t.logSettings,
                  icon: Icons.settings_outlined,
                ),
                _SwitchSetting(
                  title: t.disableLengthLimitation,
                  settingKey: "logIgnoreLimitation",
                  dataSource: SwitchDataSource.implicit,
                ),
                _IntSliderSetting(
                  title: t.logRetainCount,
                  settingsIndex: "logRetainCount",
                  dataSource: SwitchDataSource.implicit,
                  options: const [1, 2, 3, 5, 10],
                ),
                _IntSliderSetting(
                  title: t.logFileSizeMb,
                  settingsIndex: "logFileSizeMb",
                  dataSource: SwitchDataSource.implicit,
                  options: const [1, 2, 4, 8, 16, 32],
                ),
                _SwitchSetting(title: t.debugInfo, settingKey: "debugInfo"),
                _SwitchSetting(
                  title: t.logPrivacyProtection,
                  subtitle: t.logPrivacyProtectionDesc,
                  settingKey: "redactSensitiveLogs",
                  dataSource: SwitchDataSource.implicit,
                ),
                _SwitchSetting(
                  title: t.networkInfo,
                  settingKey: "enableNetLog",
                ),
                _SwitchSetting(title: t.hubInfo, settingKey: "enableHubLog"),
                _SwitchSetting(
                  title: t.statsInfo,
                  settingKey: "enableStatsLog",
                ),
                _SwitchSetting(
                  title: t.sourceInfo,
                  settingKey: "enableSourceLog",
                ),
                _SwitchSetting(
                  title: t.playerInfo,
                  settingKey: "enablePlayerLog",
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 日志美化：识别正文里的 JSON 段并缩进格式化（保留前缀文字）
String _prettyLogContent(String raw) {
  final s = raw;
  if (s.length < 2) return s;
  int start = -1;
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (c == '{' || c == '[') {
      start = i;
      break;
    }
  }
  if (start < 0) return s;
  final prefix = s.substring(0, start);
  final tail = s.substring(start).trimRight();
  try {
    final obj = jsonDecode(tail);
    final pretty = const JsonEncoder.withIndent('  ').convert(obj);
    return prefix.trim().isEmpty ? pretty : '$prefix\n$pretty';
  } catch (_) {
    return s;
  }
}

class LogsPage extends StatefulWidget {
  const LogsPage({super.key, this.inSheet = false});

  /// 在 Sheet 中展示（无 Scaffold/Appbar，仅操作按钮 + 内容）
  final bool inSheet;

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  final levelOrder = [LogLevel.info, LogLevel.warning, LogLevel.error];
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    // 先让页面进入（loading），再在下一帧构建日志列表，避免点开时卡顿
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tabs = levelOrder
        .map((lvl) => Tab(text: lvl.name.toUpperCase()))
        .toList();
    if (!_ready) {
      return const Center(child: PolygonRefreshIndicator());
    }
    if (widget.inSheet) {
      // Sheet 内展示：无 Scaffold/Appbar，仅操作按钮 + 内容
      return DefaultTabController(
        length: levelOrder.length,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: TabBar(tabs: tabs)),
                _LogMenuButton(
                  onClear: () => setState(() => Log.clear()),
                ),
              ],
            ),
            Expanded(child: _buildLogs()),
          ],
        ),
      );
    }
    return DefaultTabController(
      length: levelOrder.length,
      child: Scaffold(
        appBar: Appbar(
          title: Text(t.logs),
          bottom: TabBar(tabs: tabs),
          actions: [
            _LogMenuButton(
              onClear: () => setState(() => Log.clear()),
            ),
          ],
        ),
        body: _buildLogs(),
      ),
    );
  }

  Widget _buildLogs() {
    return StreamBuilder<List<LogItem>>(
      stream: Log.stream,
      initialData: Log.logs,
      builder: (context, snapshot) {
        final logsByLevel = {
          LogLevel.info: <LogItem>[],
          LogLevel.warning: <LogItem>[],
          LogLevel.error: <LogItem>[],
        };

        for (var log in snapshot.data ?? []) {
          logsByLevel[log.level]!.add(log);
        }

        return TabBarView(
          children: levelOrder.map((level) {
            final logs = logsByLevel[level]!;

            if (logs.isEmpty) {
              return Center(child: Text(t.noLogsForL(l: level.name)));
            }

            return ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(12),
              itemCount: logs.length,
              itemBuilder: (context, index) {
                index = logs.length - index - 1;
                final log = logs[index];
                // 过长日志截断展示，避免长卡片拖慢滑动；查看详情仍可看全文
                final isLong =
                    log.content.split('\n').length > 10 ||
                    log.content.length > 700;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Material(
                    elevation: 2,
                    color: Theme.of(context).brightness == Brightness.light
                        ? Colors.white.toOpacity(0.85)
                        : const Color(0xFF1E1E1E).toOpacity(0.85),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: SelectionArea(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (log.source.icon != null) ...[
                                  Icon(log.source.icon!, size: 14),
                                  const SizedBox(width: 6),
                                ],
                                Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                    horizontal: 6,
                                  ),
                                  child: Text(log.title),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  decoration: BoxDecoration(
                                    color: [
                                      Theme.of(context).colorScheme.error,
                                      Theme.of(
                                        context,
                                      ).colorScheme.errorContainer,
                                      Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer,
                                    ][log.level.index],
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                    horizontal: 6,
                                  ),
                                  child: Text(
                                    log.level.name,
                                    style: TextStyle(
                                      color: log.level.index == 0
                                          ? Colors.white
                                          : Colors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _prettyLogContent(log.content),
                              maxLines: isLong ? 10 : null,
                              overflow: isLong
                                  ? TextOverflow.ellipsis
                                  : TextOverflow.clip,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              log.time.toString().replaceAll(
                                RegExp(r"\.\w+"),
                                "",
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isLong)
                                    TextButton(
                                      onPressed: () =>
                                          _openLogDetail(log),
                                      child: Text(t.details),
                                    ),
                                  TextButton(
                                    onPressed: () {
                                      Clipboard.setData(
                                        ClipboardData(text: log.content),
                                      );
                                      App.rootContext.showMessage(
                                        message: t.copySuccess,
                                      );
                                    },
                                    child: Text(t.copy),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }).toList(),
        );
      },
    );
  }

  /// 长日志详情：独立页面查看完整内容（可选中/复制）
  void _openLogDetail(LogItem log) {
    context.to(() => _LogDetailPage(log: log));
  }

  void saveLog(String log) async {
    saveFile(data: utf8.encode(log), filename: 'log.txt');
  }
}

/// 单条日志详情页
class _LogDetailPage extends StatelessWidget {
  final LogItem log;

  const _LogDetailPage({required this.log});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: Appbar(
        title: Text('${log.title} · ${log.level.name}'),
        actions: [
          IconButton(
            tooltip: t.copy,
            icon: const Icon(Icons.copy),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: log.content));
              App.rootContext.showMessage(message: t.copySuccess);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: SelectionArea(
          child: Text(
            _prettyLogContent(log.content),
            style: TextStyle(
              fontSize: 13.5,
              height: 1.6,
              color: cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

/// 日志页右上角"更多"按钮：菜单锚定在按钮处弹出（在 Sheet 内也定位正确）
class _LogMenuButton extends StatelessWidget {
  const _LogMenuButton({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: t.more,
      icon: const Icon(Icons.more_horiz),
      onSelected: (value) {
        if (value == 'clear') onClear();
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 'clear', child: Text(t.clear)),
      ],
    );
  }
}
