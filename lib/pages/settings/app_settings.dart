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
  late final TextEditingController urlCtrl;
  late final TextEditingController userCtrl;
  late final TextEditingController passCtrl;
  bool autoSync = true;
  bool isTesting = false;
  bool upload = true;
  bool obscurePassword = true;

  @override
  void initState() {
    super.initState();
    if (appdata.settings['webdav'] is! List) {
      appdata.settings['webdav'] = [];
    }
    var configs = appdata.settings['webdav'] as List;
    String u = '', us = '', p = '';
    if (configs.whereType<String>().length == 3) {
      u = configs[0];
      us = configs[1];
      p = configs[2];
    }
    urlCtrl = TextEditingController(text: u);
    userCtrl = TextEditingController(text: us);
    passCtrl = TextEditingController(text: p);
    autoSync = appdata.implicitData['webdavAutoSync'] ?? true;
  }

  @override
  void dispose() {
    urlCtrl.dispose();
    userCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  bool get _configured =>
      urlCtrl.text.trim().isNotEmpty &&
      userCtrl.text.trim().isNotEmpty &&
      passCtrl.text.trim().isNotEmpty;

  void onAutoSyncChanged(bool value) {
    setState(() {
      autoSync = value;
      appdata.implicitData['webdavAutoSync'] = value;
      appdata.writeImplicitData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopUpWidgetScaffold(
      title: t.dataSync,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusCard(context, cs),
            const SizedBox(height: 16),
            _buildConfigCard(context, cs),
            const SizedBox(height: 16),
            _buildSyncOptionsCard(context, cs),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: Button.filled(
                isLoading: isTesting,
                onPressed: () => _save(context),
                child: Text(t.save, style: const TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 状态卡片：配置状态 + 上次同步时间 + 最近错误
  Widget _buildStatusCard(BuildContext context, ColorScheme cs) {
    final lastSync = DataSync().lastSyncTime;
    final lastError = DataSync().lastError;
    return Material(
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant, width: 0.6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.cloud_sync_outlined,
                    color: cs.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WebDAV',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        t.dataSync,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _configured
                        ? cs.secondaryContainer
                        : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _configured ? t.configured : t.notConfigured,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _configured
                          ? cs.onSecondaryContainer
                          : cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _infoRow(
              context,
              icon: Icons.history,
              text:
                  '${t.lastSyncTime}: ${lastSync != null ? Utils.dateFormat(lastSync.millisecondsSinceEpoch) : t.neverSynced}',
            ),
            if (lastError != null) ...[
              const SizedBox(height: 8),
              _infoRow(
                context,
                icon: Icons.error_outline,
                text: lastError,
                color: cs.error,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 配置卡片：URL / 用户名 / 密码
  Widget _buildConfigCard(BuildContext context, ColorScheme cs) {
    return Material(
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant, width: 0.6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(context, t.dataSync, Icons.settings_ethernet),
            const SizedBox(height: 12),
            TextField(
              controller: urlCtrl,
              keyboardType: TextInputType.url,
              decoration: _fieldDecoration(
                labelText: 'URL',
                hintText: t.aValidWebDavDirectoryUrl,
                icon: Icons.link,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: userCtrl,
              decoration: _fieldDecoration(
                labelText: t.username,
                icon: Icons.person_outline,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              obscureText: obscurePassword,
              decoration: _fieldDecoration(
                labelText: t.password,
                icon: Icons.key_outlined,
                suffix: IconButton(
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => obscurePassword = !obscurePassword),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
    );
  }

  /// 自动同步 + 操作卡片
  Widget _buildSyncOptionsCard(BuildContext context, ColorScheme cs) {
    return Material(
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant, width: 0.6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                t.autoSyncData,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                t.onceTheOperationIsSuccessfulAppWillAutomaticallySyncDataWithTheServer,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
              trailing: CustomSwitch(
                value: autoSync,
                onChanged: onAutoSyncChanged,
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Text(
                    t.operation,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(
                          value: true,
                          icon: const Icon(
                            Icons.cloud_upload_outlined,
                            size: 18,
                          ),
                          label: Text(t.upload),
                        ),
                        ButtonSegment(
                          value: false,
                          icon: const Icon(
                            Icons.cloud_download_outlined,
                            size: 18,
                          ),
                          label: Text(t.download),
                        ),
                      ],
                      selected: {upload},
                      onSelectionChanged: (s) =>
                          setState(() => upload = s.first),
                      showSelectedIcon: false,
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String labelText,
    String? hintText,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: Icon(icon, size: 20),
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  Widget _sectionTitle(BuildContext context, String title, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _infoRow(
    BuildContext context, {
    required IconData icon,
    required String text,
    Color? color,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color ?? cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: color ?? cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Future<void> _save(BuildContext context) async {
    var oldConfig = appdata.settings['webdav'];
    var oldAutoSync = appdata.implicitData['webdavAutoSync'];

    if (urlCtrl.text.trim().isEmpty &&
        userCtrl.text.trim().isEmpty &&
        passCtrl.text.trim().isEmpty) {
      appdata.settings['webdav'] = [];
      appdata.implicitData['webdavAutoSync'] = false;
      appdata.writeImplicitData();
      appdata.saveData();
      context.showMessage(message: t.saved);
      App.rootPop();
      return;
    }

    appdata.settings['webdav'] = [urlCtrl.text, userCtrl.text, passCtrl.text];
    appdata.implicitData['webdavAutoSync'] = autoSync;
    appdata.writeImplicitData();

    if (!autoSync) {
      appdata.saveData();
      context.showMessage(message: t.saved);
      App.rootPop();
      return;
    }

    setState(() => isTesting = true);
    var testResult = upload
        ? await DataSync().uploadData()
        : await DataSync().downloadData();
    if (testResult.error) {
      setState(() => isTesting = false);
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
  }
}
