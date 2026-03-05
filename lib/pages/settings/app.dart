// ignore_for_file: use_build_context_synchronously

part of 'settings_page.dart';

class AppSettings extends StatefulWidget {
  const AppSettings({super.key});

  @override
  State<AppSettings> createState() => _AppSettingsState();
}

class _AppSettingsState extends State<AppSettings> {
  @override
  Widget build(BuildContext context) {
    return SmoothCustomScrollView(
      slivers: [
        SliverAppbar(title: Text("App".tl)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverToBoxAdapter(
            child: _SettingCard(
              children: [
                _SettingPartTitle(title: "Data".tl, icon: Icons.storage),
                ListTile(
                  title: Text("Cache Size".tl),
                  subtitle: Text(
                    bytesToReadableString(CacheManager().currentSize),
                  ),
                ),
                _CallbackSetting(
                  title: "Clear Cache".tl,
                  actionTitle: "Clear".tl,
                  callback: () async {
                    var loadingDialog = showLoadingDialog(
                      App.rootContext,
                      barrierDismissible: false,
                      allowCancel: false,
                    );
                    await CacheManager().clear();
                    loadingDialog.close();
                    context.showMessage(message: "Cache cleared".tl);
                    setState(() {});
                  },
                ),
                _CallbackSetting(
                  title: "Cache Limit".tl,
                  subtitle: "${appdata.settings['cacheSize']} MB",
                  callback: () {
                    showInputDialog(
                      context: context,
                      title: "Set Cache Limit".tl,
                      hintText: "Size in MB".tl,
                      inputValidator: RegExp(r"^\d+$"),
                      onConfirm: (value) {
                        appdata.settings['cacheSize'] = int.parse(value);
                        appdata.saveData();
                        setState(() {});
                        CacheManager().setLimitSize(
                          appdata.settings['cacheSize'],
                        );
                        return null;
                      },
                    );
                  },
                  actionTitle: 'Set'.tl,
                ),
                _CallbackSetting(
                  title: "Export App Data".tl,
                  actionTitle: 'Export'.tl,
                  callback: () async {
                    var controller = showLoadingDialog(context);
                    var file = await exportAppData();
                    await saveFile(filename: "data.kostori", file: file);
                    controller.close();
                  },
                ),
                _CallbackSetting(
                  title: "Import App Data".tl,
                  actionTitle: 'Import'.tl,
                  callback: () async {
                    var controller = showLoadingDialog(context);
                    var file = await selectFile(ext: ['kostori']);
                    if (file != null) {
                      var cacheFile = File(
                        FilePath.join(App.cachePath, "import_data_temp"),
                      );
                      await file.saveTo(cacheFile.path);
                      try {
                        await importAppData(cacheFile);
                      } catch (e, s) {
                        Log.error("Import data", e.toString(), s);
                        context.showMessage(
                          message: "Failed to import data".tl,
                        );
                      } finally {
                        cacheFile.deleteIgnoreError();
                        App.forceRebuild();
                      }
                    }
                    controller.close();
                  },
                ),
                _CallbackSetting(
                  title: "Data Sync".tl,
                  actionTitle: 'Set'.tl,
                  callback: () async {
                    showPopUpWidget(context, const _WebdavSetting());
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
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
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverToBoxAdapter(
            child: _SettingCard(
              children: [
                _SettingPartTitle(title: "User".tl, icon: Icons.person_outline),
                SelectSetting(
                  title: "Language".tl,
                  settingKey: "language",
                  optionTranslation: {
                    "system": "System".tl,
                    "zh-CN": "Simplified Chinese".tl,
                    "zh-TW": "Traditional Chinese".tl,
                    "en-US": "English".tl,
                  },
                  onChanged: () => App.forceRebuild(),
                ),
                if (!App.isLinux)
                  _SwitchSetting(
                    title: "Authorization Required".tl,
                    settingKey: "authorizationRequired",
                    onChanged: () async {
                      var current = appdata.settings['authorizationRequired'];
                      if (current) {
                        final auth = LocalAuthentication();
                        final bool canAuthenticateWithBiometrics =
                            await auth.canCheckBiometrics;
                        final bool canAuthenticate =
                            canAuthenticateWithBiometrics ||
                            await auth.isDeviceSupported();
                        if (!canAuthenticate) {
                          context.showMessage(
                            message: "Biometrics not supported".tl,
                          );
                          setState(() {
                            appdata.settings['authorizationRequired'] = false;
                          });
                          appdata.saveData();
                          return;
                        }
                      }
                    },
                  ),
                const SizedBox(height: 8),
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

class _WebdavSetting extends StatefulWidget {
  const _WebdavSetting();

  @override
  State<_WebdavSetting> createState() => _WebdavSettingState();
}

class _WebdavSettingState extends State<_WebdavSetting> {
  String url = "";
  String user = "";
  String pass = "";
  bool autoSync = true;

  bool isTesting = false;
  bool upload = true;

  @override
  void initState() {
    super.initState();
    if (appdata.settings['webdav'] is! List) {
      appdata.settings['webdav'] = [];
    }
    var configs = appdata.settings['webdav'] as List;
    if (configs.whereType<String>().length != 3) {
      return;
    }
    url = configs[0];
    user = configs[1];
    pass = configs[2];
    autoSync = appdata.implicitData['webdavAutoSync'] ?? true;
  }

  void onAutoSyncChanged(bool value) {
    setState(() {
      autoSync = value;
      appdata.implicitData['webdavAutoSync'] = value;
      appdata.writeImplicitData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopUpWidgetScaffold(
      title: "Webdav",
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                labelText: "URL",
                hintText: "A valid WebDav directory URL".tl,
                border: OutlineInputBorder(),
              ),
              controller: TextEditingController(text: url),
              onChanged: (value) => url = value,
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                labelText: "Username".tl,
                border: const OutlineInputBorder(),
              ),
              controller: TextEditingController(text: user),
              onChanged: (value) => user = value,
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                labelText: "Password".tl,
                border: const OutlineInputBorder(),
              ),
              controller: TextEditingController(text: pass),
              onChanged: (value) => pass = value,
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(Icons.sync),
              title: Text("Auto Sync Data".tl),
              contentPadding: EdgeInsets.zero,
              trailing: Switch(value: autoSync, onChanged: onAutoSyncChanged),
            ),
            const SizedBox(height: 12),
            RadioGroup<bool>(
              groupValue: upload,
              onChanged: (v) => setState(() => upload = v!),
              child: Row(
                children: [
                  Text("Operation".tl),
                  Radio(value: true),
                  Text("Upload".tl),
                  Radio(value: false),
                  Text("Download".tl),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: autoSync
                  ? Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Once the operation is successful, app will automatically sync data with the server."
                                  .tl,
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),
            Center(
              child: Button.filled(
                isLoading: isTesting,
                onPressed: () async {
                  var oldConfig = appdata.settings['webdav'];
                  var oldAutoSync = appdata.implicitData['webdavAutoSync'];

                  if (url.trim().isEmpty &&
                      user.trim().isEmpty &&
                      pass.trim().isEmpty) {
                    appdata.settings['webdav'] = [];
                    appdata.implicitData['webdavAutoSync'] = false;
                    appdata.writeImplicitData();
                    appdata.saveData();
                    context.showMessage(message: "Saved".tl);
                    App.rootPop();
                    return;
                  }

                  appdata.settings['webdav'] = [url, user, pass];
                  appdata.implicitData['webdavAutoSync'] = autoSync;
                  appdata.writeImplicitData();

                  if (!autoSync) {
                    appdata.saveData();
                    context.showMessage(message: "Saved".tl);
                    App.rootPop();
                    return;
                  }

                  setState(() {
                    isTesting = true;
                  });
                  var testResult = upload
                      ? await DataSync().uploadData()
                      : await DataSync().downloadData();
                  if (testResult.error) {
                    setState(() {
                      isTesting = false;
                    });
                    appdata.settings['webdav'] = oldConfig;
                    appdata.implicitData['webdavAutoSync'] = oldAutoSync;
                    appdata.writeImplicitData();
                    appdata.saveData();
                    context.showMessage(message: testResult.errorMessage!);
                    context.showMessage(message: "Saved Failed".tl);
                  } else {
                    appdata.saveData();
                    context.showMessage(message: "Saved".tl);
                    App.rootPop();
                  }
                },
                child: Text("Continue".tl),
              ),
            ),
          ],
        ).paddingHorizontal(16),
      ),
    );
  }
}
