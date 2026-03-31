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
        SliverAppbar(title: Text(t.app)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverToBoxAdapter(
            child: _SettingCard(
              children: [
                _SettingPartTitle(title: t.data, icon: Icons.storage),
                ListTile(
                  title: Text(t.cacheSize),
                  subtitle: Text(
                    bytesToReadableString(CacheManager().currentSize),
                  ),
                ),
                _CallbackSetting(
                  title: t.clearCache,
                  actionTitle: t.clear,
                  callback: () async {
                    var loadingDialog = showLoadingDialog(
                      App.rootContext,
                      barrierDismissible: false,
                      allowCancel: false,
                    );
                    await CacheManager().clear();
                    loadingDialog.close();
                    context.showMessage(message: t.cacheCleared);
                    setState(() {});
                  },
                ),
                _CallbackSetting(
                  title: t.cacheLimit,
                  subtitle: "${appdata.settings['cacheSize']} MB",
                  callback: () {
                    showInputDialog(
                      context: context,
                      title: t.setCacheLimit,
                      hintText: t.sizeInMb,
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
                  actionTitle: t.set,
                ),
                _CallbackSetting(
                  title: t.exportAppData,
                  actionTitle: t.export,
                  callback: () async {
                    var controller = showLoadingDialog(context);
                    var file = await exportAppData();
                    await saveFile(filename: "data.kostori", file: file);
                    controller.close();
                  },
                ),
                _CallbackSetting(
                  title: t.importAppData,
                  actionTitle: t.import,
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
                        context.showMessage(message: t.failedToImport);
                      } finally {
                        cacheFile.deleteIgnoreError();
                        App.forceRebuild();
                      }
                    }
                    controller.close();
                  },
                ),
                _CallbackSetting(
                  title: t.dataSync,
                  actionTitle: t.set,
                  callback: () async {
                    showPopUpWidget(context, const _WebdavSetting());
                  },
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverToBoxAdapter(
            child: _SettingCard(
              children: [
                _SettingPartTitle(title: t.user, icon: Icons.person_outline),
                SelectSetting(
                  title: t.language,
                  settingKey: "language",
                  optionTranslation: {
                    "system": t.system,
                    "zh-CN": t.simplifiedChinese,
                    "zh-TW": t.traditionalChinese,
                    "en-US": "English",
                  },
                  onChanged: () async {
                    var lang = appdata.settings['language'];
                    await LocaleSettings.setLocaleRaw(lang);
                    App.forceRebuild();
                  },
                ),
                if (!App.isLinux)
                  _SwitchSetting(
                    title: t.authorizationRequired,
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
                            message: "Biometrics not supported",
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
              ],
            ),
          ),
        ),
        // 桌面平台：FFmpeg 设置
        if (App.isDesktop)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverToBoxAdapter(
              child: _SettingCard(
                children: [
                  _SettingPartTitle(title: 'FFmpeg', icon: Icons.video_file),
                  _CallbackSetting(
                    title: t.selectFile,
                    subtitle: appdata.settings['ffmpegPath'] ?? 'ffmpeg',
                    callback: () async {
                      final file = await selectFile(
                        ext: App.isWindows ? ['exe'] : [],
                      );
                      if (file != null) {
                        final path = file.path;
                        appdata.settings['ffmpegPath'] = path;
                        appdata.saveData();
                        setState(() {});
                      }
                    },
                    actionTitle: t.set,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
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
                hintText: t.aValidWebDavDirectoryUrl,
                border: OutlineInputBorder(),
              ),
              controller: TextEditingController(text: url),
              onChanged: (value) => url = value,
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                labelText: t.username,
                border: const OutlineInputBorder(),
              ),
              controller: TextEditingController(text: user),
              onChanged: (value) => user = value,
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                labelText: t.password,
                border: const OutlineInputBorder(),
              ),
              controller: TextEditingController(text: pass),
              onChanged: (value) => pass = value,
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(Icons.sync),
              title: Text(t.autoSyncData),
              contentPadding: EdgeInsets.zero,
              trailing: Switch(value: autoSync, onChanged: onAutoSyncChanged),
            ),
            const SizedBox(height: 12),
            RadioGroup<bool>(
              groupValue: upload,
              onChanged: (v) => setState(() => upload = v!),
              child: Row(
                children: [
                  Text(t.operation),
                  Radio(value: true),
                  Text(t.upload),
                  Radio(value: false),
                  Text(t.download),
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
                              t.onceTheOperationIsSuccessfulAppWillAutomaticallySyncDataWithTheServer,
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
                    context.showMessage(message: t.saved);
                    App.rootPop();
                    return;
                  }

                  appdata.settings['webdav'] = [url, user, pass];
                  appdata.implicitData['webdavAutoSync'] = autoSync;
                  appdata.writeImplicitData();

                  if (!autoSync) {
                    appdata.saveData();
                    context.showMessage(message: t.saved);
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
                    context.showMessage(message: t.savedFailed);
                  } else {
                    appdata.saveData();
                    context.showMessage(message: t.saved);
                    App.rootPop();
                  }
                },
                child: Text(t.continueText),
              ),
            ),
          ],
        ).paddingHorizontal(16),
      ),
    );
  }
}
