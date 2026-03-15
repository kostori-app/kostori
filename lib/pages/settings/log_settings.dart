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
        SliverAppbar(title: Text("Log".tl)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverToBoxAdapter(
            child: _SettingCard(
              children: [
                _SettingPartTitle(title: "Log".tl, icon: Icons.error_outline),
                _CallbackSetting(
                  title: "Open Log".tl,
                  actionTitle: 'Open'.tl,
                  callback: () => context.to(() => const LogsPage()),
                ),
                _SwitchSetting(title: "Debug Info".tl, settingKey: "debugInfo"),
                _SwitchSetting(
                  title: "Network Info".tl,
                  settingKey: "enableNetLog",
                ),
                _SwitchSetting(
                  title: "Hub Info".tl,
                  settingKey: "enableHubLog",
                ),
                _SwitchSetting(
                  title: "Stats Info".tl,
                  settingKey: "enableStatsLog",
                ),
                _SwitchSetting(
                  title: "Source Info".tl,
                  settingKey: "enableSourceLog",
                ),
                _SwitchSetting(
                  title: "Player Info".tl,
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
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  final levelOrder = [LogLevel.info, LogLevel.warning, LogLevel.error];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: levelOrder.length,
      child: Scaffold(
        appBar: Appbar(
          title: Text("Logs".tl),
          bottom: TabBar(
            tabs: levelOrder
                .map((lvl) => Tab(text: lvl.name.toUpperCase()))
                .toList(),
          ),
          actions: [
            IconButton(
              onPressed: () {
                final RelativeRect position = RelativeRect.fromLTRB(
                  MediaQuery.of(context).size.width,
                  MediaQuery.of(context).padding.top + kToolbarHeight,
                  0.0,
                  0.0,
                );
                showMenu(
                  context: context,
                  position: position,
                  items: [
                    PopupMenuItem(
                      child: Text("Clear".tl),
                      onTap: () {
                        setState(() {
                          Log.clear();
                        });
                      },
                    ),
                    PopupMenuItem(
                      child: Text("Disable Length Limitation".tl),
                      onTap: () {
                        Log.ignoreLimitation = true;
                        context.showMessage(
                          message: "Only valid for this run".tl,
                        );
                      },
                    ),
                    PopupMenuItem(
                      child: Text("Export".tl),
                      onTap: () => saveLog(Log.logs.toString()),
                    ),
                  ],
                );
              },
              icon: const Icon(Icons.more_horiz),
            ),
          ],
        ),
        body: StreamBuilder<List<LogItem>>(
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
                  return Center(
                    child: Text("No logs for @l".tlParams({"l": level.name})),
                  );
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
                                        message: '复制成功',
                                      );
                                    },
                                    child: Text("Copy".tl),
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
        ),
      ),
    );
  }

  void saveLog(String log) async {
    saveFile(data: utf8.encode(log), filename: 'log.txt');
  }
}
