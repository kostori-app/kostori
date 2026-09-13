// ignore_for_file: use_build_context_synchronously

part of 'settings_page.dart';

class AppSettings extends StatefulWidget {
  const AppSettings({super.key});

  @override
  State<AppSettings> createState() => _AppSettingsState();
}

class _AppSettingsState extends State<AppSettings> {
  final TextEditingController _nicknameCtrl = TextEditingController(
    text: currentUserNickname,
  );

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    super.dispose();
  }

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
                _CallbackSetting(
                  title: t.aiRequestLog,
                  actionTitle: t.manage,
                  callback: () async {
                    showPopUpWidget(context, const AiRequestLogPage());
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
                // 用户昵称（注入 {{user_nickname}} 占位符，聊天头部用户名称同源）
                _CallbackSetting(
                  title: t.userNickname,
                  subtitle: _nicknameCtrl.text.trim().isEmpty
                      ? t.userNicknameHint
                      : _nicknameCtrl.text.trim(),
                  callback: () {
                    showInputDialog(
                      context: context,
                      title: t.userNickname,
                      hintText: t.userNicknameHint,
                      initialValue: _nicknameCtrl.text,
                      onConfirm: (value) {
                        final text = value.toString().trim();
                        setState(() {
                          _nicknameCtrl.text = text;
                          appdata.settings['userNickname'] = text;
                          appdata.saveData();
                        });
                        return null;
                      },
                    );
                  },
                  actionTitle: t.edit,
                ),
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
                            message: t.biometricsNotSupported,
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
                    subtitle: () {
                      final p =
                          appdata.implicitData['ffmpegPath'] as String?;
                      if (p == null || p.trim().isEmpty) {
                        return t.notSet;
                      }
                      return p;
                    }(),
                    callback: () async {
                      final file = await selectFile(
                        ext: App.isWindows ? ['exe'] : [],
                      );
                      if (file != null) {
                        final path = file.path;
                        appdata.implicitData['ffmpegPath'] = path;
                        appdata.writeImplicitData();
                        setState(() {});
                      }
                    },
                    actionTitle: t.set,
                  ),
                ],
              ),
            ),
          ),
        // Hub 管理
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverToBoxAdapter(
            child: _SettingCard(
              children: [
                _SettingPartTitle(
                  title: t.hubManagement,
                  icon: Icons.hub_outlined,
                ),
                _CallbackSetting(
                  title: t.hubUploadedImages,
                  subtitle: t.hubUploadedImagesHint,
                  actionTitle: t.manage,
                  callback: () {
                    showPopUpWidget(context, const _HubUploadedImagesPage());
                  },
                ),
                _CallbackSetting(
                  title: t.hubStickers,
                  actionTitle: t.manage,
                  callback: () {
                    showPopUpWidget(context, const _HubStickersPage());
                  },
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
            const SizedBox(height: 16),
            _buildSelectiveSyncCard(context, cs),
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

  /// 选择性同步入口（按条目选择角色卡 / 故事观）
  Widget _buildSelectiveSyncCard(BuildContext context, ColorScheme cs) {
    return Material(
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant, width: 0.6),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: const Icon(Icons.checklist_outlined, size: 20),
        title: Text(t.selectiveSync),
        subtitle: Text(
          '${t.characterCards} / ${t.rolePlay}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.arrow_right, size: 20),
        onTap: _configured
            ? () => App.rootContext.to(() => const _SelectiveSyncPage())
            : null,
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

/// Hub 上传目录
String get _hubUploadDir =>
    '${App.dataPath}${Platform.pathSeparator}hub_uploads';

/// Hub 上传图片管理页
class _HubUploadedImagesPage extends StatefulWidget {
  const _HubUploadedImagesPage();

  @override
  State<_HubUploadedImagesPage> createState() => _HubUploadedImagesPageState();
}

class _HubUploadedImagesPageState extends State<_HubUploadedImagesPage> {
  List<File> _files = [];
  int _totalBytes = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final dir = Directory(_hubUploadDir);
    final files = <File>[];
    var total = 0;
    if (await dir.exists()) {
      await for (final e in dir.list()) {
        if (e is File) {
          files.add(e);
          try {
            total += await e.length();
          } catch (_) {}
        }
      }
    }
    if (mounted) {
      setState(() {
        _files = files..sort((a, b) => b.path.compareTo(a.path));
        _totalBytes = total;
        _loading = false;
      });
    }
  }

  Future<void> _delete(File e) async {
    try {
      await e.delete();
    } catch (_) {}
    await _reload();
  }

  Future<void> _clearAll() async {
    showConfirmDialog(
      context: context,
      title: t.clear,
      content: t.clearHubUploadsConfirm,
      onConfirm: () async {
        for (final e in _files) {
          try {
            await e.delete();
          } catch (_) {}
        }
        await _reload();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopUpWidgetScaffold(
      title: t.hubUploadedImages,
      body: _loading
          ? const Center(child: PolygonRefreshIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Text(
                        '${_files.length} ${t.hubUploadedImagesHint}',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        bytesToReadableString(_totalBytes),
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: _files.isEmpty ? null : _clearAll,
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: Text(t.clear),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _files.isEmpty
                      ? Center(
                          child: Text(
                            t.noHubUploads,
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _files.length,
                          itemBuilder: (_, i) {
                            final e = _files[i];
                            final name = e.uri.pathSegments.isNotEmpty
                                ? e.uri.pathSegments.last
                                : e.path;
                            return ListTile(
                              dense: true,
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.file(
                                  e,
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      const Icon(Icons.image_outlined),
                                ),
                              ),
                              title: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: FutureBuilder<int>(
                                future: e.length(),
                                builder: (_, snap) => Text(
                                  bytesToReadableString(snap.data ?? 0),
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _delete(e),
                              ),
                              onTap: () {
                                BangumiWidget.showImagePreview(
                                  context: context,
                                  url: e.path,
                                  title: name,
                                  heroTag: name,
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

/// Hub 表情包管理页
class _HubStickersPage extends StatefulWidget {
  const _HubStickersPage();

  @override
  State<_HubStickersPage> createState() => _HubStickersPageState();
}

class _HubStickersPageState extends State<_HubStickersPage> {
  List<HubSticker> _stickers = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() => _stickers = HubStickerManager.load());
  }

  Future<void> _clearAll() async {
    showConfirmDialog(
      context: context,
      title: t.clear,
      content: t.clearHubStickersConfirm,
      onConfirm: () {
        HubStickerManager.clear();
        _reload();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopUpWidgetScaffold(
      title: t.hubStickers,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Text(
                  '${_stickers.length} ${t.hubStickersHint}',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _stickers.isEmpty ? null : _clearAll,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: Text(t.clear),
                ),
              ],
            ),
          ),
          Expanded(
            child: _stickers.isEmpty
                ? Center(
                    child: Text(
                      t.noHubStickers,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  )
                : ListView.builder(
                    itemCount: _stickers.length,
                    itemBuilder: (_, i) {
                      final s = _stickers[i];
                      return ListTile(
                        dense: true,
                        leading: s.isBase64
                            ? const Icon(Icons.emoji_emotions_outlined)
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(
                                  s.url,
                                  width: 36,
                                  height: 36,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      const Icon(Icons.emoji_emotions_outlined),
                                ),
                              ),
                        title: Text(
                          s.label ?? s.url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          s.isBase64
                              ? '${bytesToReadableString(utf8.encode(s.url).length)} · base64'
                              : 'URL',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () {
                            HubStickerManager.remove(s.url);
                            _reload();
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 选择性同步：按条目选择角色卡 / 故事观 / 存档 / 提示词注入 / 世界书
// ─────────────────────────────────────────────

/// 同步条目的状态
enum _SyncState { synced, localOnly, remoteOnly, differs }

class _SelectiveSyncPage extends StatefulWidget {
  const _SelectiveSyncPage();

  @override
  State<_SelectiveSyncPage> createState() => _SelectiveSyncPageState();
}

class _SelectiveSyncPageState extends State<_SelectiveSyncPage> {
  static const _kinds = [
    'cards',
    'stories',
    'sessions',
    'prompts',
    'worldbook',
  ];

  int _tab = 0;
  bool _loading = true;
  bool _busy = false;
  final Map<String, Map<String, RemoteFileInfo>> _remote = {};
  final Map<String, Set<String>> _selected = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _ext(String kind) => kind == 'stories' ? '.md' : '.json';

  String _localDir(String kind) => switch (kind) {
    'cards' => CharacterCardStore.instance.dirPath,
    'stories' => StoryStore.instance.dirPath,
    'sessions' => StorySessionStore.instance.dirPath,
    'prompts' => PromptInjectionStore.instance.dirPath,
    'worldbook' => WorldBookStore.instance.dirPath,
    _ => '',
  };

  Set<String> _sel(String kind) =>
      _selected.putIfAbsent(kind, () => <String>{});

  Future<void> _load() async {
    await CharacterCardStore.instance.ensureLoaded();
    await StoryStore.instance.ensureLoaded();
    await StorySessionStore.instance.ensureLoaded();
    await PromptInjectionStore.instance.ensureLoaded();
    await WorldBookStore.instance.ensureLoaded();
    final sync = DataSync();
    final remote = <String, Map<String, RemoteFileInfo>>{};
    for (final kind in _kinds) {
      final res = await sync.listRemoteEntries(dir: kind);
      remote[kind] = res.success
          ? {for (final e in res.data) e.name: e}
          : {};
    }
    if (!mounted) return;
    setState(() {
      _remote
        ..clear()
        ..addAll(remote);
      _loading = false;
    });
  }

  Set<String> _localIds(String kind) => switch (kind) {
    'cards' => {for (final c in CharacterCardStore.instance.cards) c.id},
    'stories' => {for (final s in StoryStore.instance.stories) s.id},
    'sessions' => {...StorySessionStore.instance.storyIds},
    'prompts' => {for (final i in PromptInjectionStore.instance.items) i.id},
    'worldbook' => {for (final e in WorldBookStore.instance.entries) e.id},
    _ => <String>{},
  };

  String _name(String kind, String id) => switch (kind) {
    'cards' => CharacterCardStore.instance.find(id)?.name ?? id,
    'stories' => StoryStore.instance.find(id)?.name ?? id,
    'sessions' => StoryStore.instance.find(id)?.name ?? id,
    'prompts' => PromptInjectionStore.instance.findById(id)?.name ?? id,
    'worldbook' => _worldBookName(id),
    _ => id,
  };

  String _worldBookName(String id) {
    for (final e in WorldBookStore.instance.entries) {
      if (e.id == id) return e.name.isEmpty ? id : e.name;
    }
    return id;
  }

  String _label(String kind) => switch (kind) {
    'cards' => t.characterCards,
    'stories' => t.rolePlay,
    'sessions' => t.storySessions,
    'prompts' => t.syncPromptInjections,
    'worldbook' => t.syncWorldBook,
    _ => kind,
  };

  io.File _localFile(String kind, String id) =>
      io.File('${_localDir(kind)}/$id${_ext(kind)}');

  _SyncState _stateFor(String kind, String id) {
    final file = _localFile(kind, id);
    final localExists = file.existsSync();
    final remote = (_remote[kind] ?? const {})['$id${_ext(kind)}'];
    if (!localExists && remote == null) return _SyncState.synced;
    if (localExists && remote == null) return _SyncState.localOnly;
    if (!localExists && remote != null) return _SyncState.remoteOnly;
    try {
      return file.lengthSync() == remote!.size
          ? _SyncState.synced
          : _SyncState.differs;
    } catch (_) {
      return _SyncState.differs;
    }
  }

  void _toast(bool ok) {
    App.rootContext.showMessage(
      message: ok ? t.syncSuccess : t.characterImportFailed,
      level: ok ? LogLevel.info : LogLevel.error,
    );
  }

  Future<void> _upload(String kind, Set<String> ids) async {
    if (ids.isEmpty || _busy) return;
    setState(() => _busy = true);
    final sync = DataSync();
    final dir = _localDir(kind);
    final ext = _ext(kind);
    var ok = 0;
    for (final id in ids) {
      final file = io.File('$dir/$id$ext');
      if (file.existsSync()) {
        final r = await sync.uploadFile(
          localPath: file.path,
          remoteName: '$id$ext',
          remoteDir: kind,
        );
        if (r.success) ok++;
      }
      if (kind == 'cards') {
        final png = io.File('$dir/$id.png');
        if (png.existsSync()) {
          await sync.uploadFile(
            localPath: png.path,
            remoteName: '$id.png',
            remoteDir: kind,
          );
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _sel(kind).clear();
    });
    _toast(ok > 0);
    await _load();
  }

  Future<void> _download(String kind, Set<String> ids) async {
    if (ids.isEmpty || _busy) return;
    setState(() => _busy = true);
    final sync = DataSync();
    final dir = _localDir(kind);
    final ext = _ext(kind);
    final remote = _remote[kind] ?? const <String, RemoteFileInfo>{};
    var ok = 0;
    for (final id in ids) {
      if (remote.containsKey('$id$ext')) {
        final r = await sync.downloadFile(
          remoteName: '$id$ext',
          localPath: '$dir/$id$ext',
          remoteDir: kind,
        );
        if (r.success) ok++;
        if (kind == 'cards' && remote.containsKey('$id.png')) {
          await sync.downloadFile(
            remoteName: '$id.png',
            localPath: '$dir/$id.png',
            remoteDir: kind,
          );
        }
      }
    }
    await CharacterCardStore.instance.reload();
    await StoryStore.instance.reload();
    await StorySessionStore.instance.reload();
    await PromptInjectionStore.instance.reload();
    await WorldBookStore.instance.reload();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _sel(kind).clear();
    });
    _toast(ok > 0);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Appbar(
          title: Text(t.selectiveSync),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            tooltip: t.back,
            onPressed: () => context.canPop() ? context.pop() : App.pop(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: t.refresh,
              onPressed: _loading ? null : _load,
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: CapsuleOptions(
            scrollable: true,
            children: [
              for (var i = 0; i < _kinds.length; i++)
                CapsuleOption(
                  text: _label(_kinds[i]),
                  isSelected: _tab == i,
                  onTap: () => setState(() => _tab = i),
                ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _buildList(_kinds[_tab]),
        ),
      ],
    );
  }

  Widget _buildList(String kind) {
    final ids = <String>{
      ..._localIds(kind),
      for (final name in (_remote[kind] ?? const {}).keys)
        if (name.endsWith(_ext(kind)))
          name.substring(0, name.length - _ext(kind).length),
    }.toList()..sort();
    final selected = _sel(kind);
    if (ids.isEmpty) {
      final empty = switch (kind) {
        'cards' => t.characterCardsEmpty,
        'stories' => t.storyNoStories,
        'sessions' => t.storySessions,
        'prompts' => t.noPromptInjectionsYet,
        'worldbook' => t.noWorldBookEntriesYet,
        _ => '',
      };
      return Center(
        child: Text(
          empty,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            children: [
              for (final id in ids) _buildItem(kind, id, selected),
            ],
          ),
        ),
        _buildActions(kind, selected),
      ],
    );
  }

  Widget _buildItem(String kind, String id, Set<String> selected) {
    final scheme = Theme.of(context).colorScheme;
    final isSelected = selected.contains(id);
    final state = _stateFor(kind, id);
    final (label, color) = switch (state) {
      _SyncState.synced => (t.syncStateSynced, scheme.primary),
      _SyncState.localOnly => (t.syncStateLocalOnly, scheme.tertiary),
      _SyncState.remoteOnly => (t.syncStateRemoteOnly, scheme.secondary),
      _SyncState.differs => (t.syncStateDiffers, scheme.error),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected
            ? scheme.primaryContainer
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() {
            if (isSelected) {
              selected.remove(id);
            } else {
              selected.add(id);
            }
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  size: 20,
                  color: isSelected ? scheme.primary : scheme.outline,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _name(kind, id),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$kind/$id${_ext(kind)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 11, color: color),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions(String kind, Set<String> selected) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: (_busy || selected.isEmpty)
                    ? null
                    : () => _upload(kind, selected),
                icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                label: Text('${t.upload} (${selected.length})'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: (_busy || selected.isEmpty)
                    ? null
                    : () => _download(kind, selected),
                icon: const Icon(Icons.cloud_download_outlined, size: 18),
                label: Text('${t.download} (${selected.length})'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
