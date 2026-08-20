part of 'settings_page.dart';

class LogSettings extends StatefulWidget {
  const LogSettings({super.key});

  @override
  State<LogSettings> createState() => _LogSettingsState();
}

class _LogSettingsState extends State<LogSettings> {
  @override
  Widget build(BuildContext context) {
    return SmoothCustomScrollView(
      slivers: [
        SliverAppbar(title: Text(t.log)),
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

class LogsPage extends StatefulWidget {
  const LogsPage({super.key, this.inSheet = false});

  /// 在 Sheet 中展示（无 Scaffold/Appbar，仅操作按钮 + 内容）
  final bool inSheet;

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  final levelOrder = [LogLevel.info, LogLevel.warning, LogLevel.error];

  @override
  Widget build(BuildContext context) {
    final tabs = levelOrder
        .map((lvl) => Tab(text: lvl.name.toUpperCase()))
        .toList();
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
                  onDisableLimit: () {
                    Log.ignoreLimitation = true;
                    context.showMessage(message: t.onlyValidForThisRun);
                  },
                  onExport: () => saveLog(Log.logs.toString()),
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
              onDisableLimit: () {
                Log.ignoreLimitation = true;
                context.showMessage(message: t.onlyValidForThisRun);
              },
              onExport: () => saveLog(Log.logs.toString()),
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
                            Text(log.content),
                            const SizedBox(height: 4),
                            Text(
                              log.time.toString().replaceAll(
                                RegExp(r"\.\w+"),
                                "",
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
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

  void saveLog(String log) async {
    saveFile(data: utf8.encode(log), filename: 'log.txt');
  }
}

/// 日志页右上角"更多"按钮：菜单锚定在按钮处弹出（在 Sheet 内也定位正确）
class _LogMenuButton extends StatelessWidget {
  const _LogMenuButton({
    required this.onClear,
    required this.onDisableLimit,
    required this.onExport,
  });

  final VoidCallback onClear;
  final VoidCallback onDisableLimit;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: t.more,
      icon: const Icon(Icons.more_horiz),
      onSelected: (value) {
        switch (value) {
          case 'clear':
            onClear();
            break;
          case 'disableLimit':
            onDisableLimit();
            break;
          case 'export':
            onExport();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 'clear', child: Text(t.clear)),
        PopupMenuItem(
          value: 'disableLimit',
          child: Text(t.disableLengthLimitation),
        ),
        PopupMenuItem(value: 'export', child: Text(t.export)),
      ],
    );
  }
}
