// ignore_for_file: use_build_context_synchronously

part of 'settings_page.dart';

class AboutSettings extends ConsumerStatefulWidget {
  const AboutSettings({super.key});

  @override
  ConsumerState<AboutSettings> createState() => _AboutSettingsState();
}

class _AboutSettingsState extends ConsumerState<AboutSettings> {
  bool isCheckingAppUpdate = false;
  bool isCheckingBangumiDataUpdate = false;
  bool isCheckingBangumiDataReset = false;
  bool isUpdateLog = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SmoothCustomScrollView(
      slivers: [
        SliverAppbar(title: Text(t.about)),
        SizedBox(
          height: 136,
          width: double.infinity,
          child: Center(
            child: Container(
              width: 136,
              height: 136,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(136),
              ),
              clipBehavior: Clip.antiAlias,
              child: const Image(
                image: AssetImage("images/app_icon.png"),
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
        ).paddingTop(16).toSliver(),
        Column(
          children: [
            const SizedBox(height: 8),
            Text("V${App.version}", style: const TextStyle(fontSize: 16)),
            Text(
              t.kostoriIsAFreeAndOpenSourceAppForAnimeWatching,
            ),
            const SizedBox(height: 8),
          ],
        ).toSliver(),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          sliver: SliverToBoxAdapter(
            child: _SettingCard(
              children: [
                _SettingPartTitle(
                  title: "Github",
                  icon: Icons.radio_button_unchecked_outlined,
                ),
                ListTile(
                  title: Text(t.checkForUpdates),
                  trailing: Button.filled(
                    isLoading: isCheckingAppUpdate,
                    child: Text(t.check),
                    onPressed: () {
                      setState(() {
                        isCheckingAppUpdate = true;
                      });
                      checkUpdateUi().then((value) {
                        setState(() {
                          isCheckingAppUpdate = false;
                        });
                      });
                    },
                  ).fixHeight(32),
                ),
                ListTile(
                  title: Text(t.updateLog),
                  trailing: Button.filled(
                    isLoading: isUpdateLog,
                    child: Text(t.open),
                    onPressed: () async {
                      setState(() {
                        isUpdateLog = true;
                      });
                      try {
                        await updateLog(context);
                      } catch (e) {
                        App.rootContext.showMessage(
                          message: t.requestFailed,
                          level: LogLevel.warning,
                        );
                      } finally {
                        if (mounted) {
                          setState(() {
                            isUpdateLog = false;
                          });
                        }
                      }
                    },
                  ).fixHeight(32),
                ),
                _SwitchSetting(
                  title: t.checkForUpdatesOnStartup,
                  settingKey: "checkUpdateOnStart",
                ),
                ListTile(
                  title: Text(t.iconProducer),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () {
                    launchUrlString("https://www.pixiv.net/users/18071897");
                  },
                ),
                ListTile(
                  title: const Text("Github"),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () {
                    launchUrlString("https://github.com/kostori-app/kostori");
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          sliver: SliverToBoxAdapter(
            child: _SettingCard(
              children: [
                _SettingPartTitle(
                  title: t.bangumi,
                  icon: Icons.radio_button_unchecked_outlined,
                ),
                ListTile(
                  title: const Text("Bangumi-data"),
                  subtitle: Text(appdata.settings['bangumiDataVer']),
                  trailing: Button.filled(
                    isLoading: isCheckingBangumiDataUpdate,
                    child: Text(t.check),
                    onPressed: () {
                      setState(() {
                        isCheckingBangumiDataUpdate = true;
                      });
                      Bangumi.instance.checkBangumiData(isUpdata: true).then((
                        value,
                      ) {
                        setState(() {
                          isCheckingBangumiDataUpdate = false;
                        });
                      });
                    },
                  ).fixHeight(32),
                ),
                ListTile(
                  title: Text(t.resetBangumiData),
                  trailing: Button.filled(
                    isLoading: isCheckingBangumiDataReset,
                    child: Text(t.reset),
                    onPressed: () {
                      setState(() {
                        isCheckingBangumiDataReset = true;
                      });
                      Bangumi.instance.resetBangumiData().then((value) {
                        setState(() {
                          isCheckingBangumiDataReset = false;
                        });
                      });
                    },
                  ).fixHeight(32),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          sliver: SliverToBoxAdapter(
            child: _SettingCard(
              children: [
                _SettingPartTitle(
                  title: t.information,
                  icon: Icons.radio_button_unchecked_outlined,
                ),
                ListTile(
                  title: Text(t.deviceField),
                  trailing: Button.filled(
                    child: Text(t.open),
                    onPressed: () async {
                      await DeviceInfo.showDeviceInfoDialog();
                    },
                  ).fixHeight(32),
                ),
                ListTile(
                  title: Text(t.properties),
                  trailing: Button.filled(
                    child: Text(t.open),
                    onPressed: () async {
                      await showDeviceInfoDialog();
                    },
                  ).fixHeight(32),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> showDeviceInfoDialog() async {
  final packageInfo = await PackageInfo.fromPlatform();
  final appMap = {
    t.appNameField: packageInfo.appName,
    t.packageNameField: packageInfo.packageName,
    t.versionField: packageInfo.version,
    t.buildNumberField: packageInfo.buildNumber,
    if (packageInfo.buildSignature.isNotEmpty)
      t.buildSignatureField: packageInfo.buildSignature,
    if (packageInfo.installerStore?.isNotEmpty ?? false)
      t.installerStoreField: packageInfo.installerStore!,
    if (packageInfo.installTime != null)
      t.installTimeField: packageInfo.installTime!.toIso8601String(),
    if (packageInfo.updateTime != null)
      t.updateTimeField: packageInfo.updateTime!.toIso8601String(),
  };

  final infoMap = appMap;

  showDialog(
    context: App.rootContext,
    builder: (context) {
      return ContentDialog(
        title: t.appInfo,
        content: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: 500.0),
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false, overscroll: false),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: infoMap.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Material(
                        color: context.brightness == Brightness.light
                            ? Colors.white.toOpacity(0.72)
                            : const Color(0xFF1E1E1E).toOpacity(0.72),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: InkWell(
                          onLongPress: () {
                            Clipboard.setData(
                              ClipboardData(
                                text: '${entry.key}: ${entry.value}',
                              ),
                            );
                            App.rootContext.showMessage(message: t.copySuccess);
                          },
                          onTap: () {},
                          child: ListTile(
                            dense: true,
                            title: Text(
                              entry.key,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(entry.value),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              final allText = infoMap.entries
                  .map((e) => '${e.key}: ${e.value}')
                  .join('\n');
              Clipboard.setData(ClipboardData(text: allText));
              App.rootContext.showMessage(message: t.allCopiedSuccess);
            },
            child: Text(t.copy),
          ),
        ],
      );
    },
  );
}

Future<Map<bool, String?>> checkUpdate() async {
  try {
    var res = await AppDio().get(
      "https://raw.githubusercontent.com/kostori-app/kostori/refs/heads/master/pubspec.yaml",
    );
    if (res.statusCode == 200) {
      final data = loadYaml(res.data);
      if (data["version"] != null) {
        String fetchedVersion = data["version"].split("+")[0];
        bool hasNew = _compareVersion(fetchedVersion, App.version);
        return {hasNew: fetchedVersion};
      }
    }
    return {false: null};
  } catch (e, s) {
    App.rootContext.showMessage(
      message: t.checkUpdateFailed,
      level: LogLevel.error,
    );
    Log.error("checkUpdate", '$e\n$s');
    return {false: null};
  }
}

Future<void> checkUpdateUi([
  bool showMessageIfNoUpdate = true,
  bool delay = false,
]) async {
  var value = await checkUpdate();

  if (!value.containsKey(true)) {
    if (showMessageIfNoUpdate) {
      App.rootContext.showMessage(message: t.noNewVersionAvailable);
    }
    return;
  }

  if (delay) await Future.delayed(const Duration(seconds: 2));

  showDialog(
    context: App.rootContext,
    barrierDismissible: false,
    builder: (context) {
      return UpdateDialog(checkUpdate: value);
    },
  );
}

/// return true if version1 > version2
bool _compareVersion(String version1, String version2) {
  var v1 = version1.split(".");
  var v2 = version2.split(".");
  for (var i = 0; i < v1.length; i++) {
    if (int.parse(v1[i]) > int.parse(v2[i])) {
      return true;
    }
  }
  return false;
}

Future<void> updateLog(BuildContext context) async {
  List<dynamic> releases;
  try {
    final response = await AppDio().request(
      'https://api.github.com/repos/kostori-app/kostori/releases',
      options: Options(method: 'GET'),
    );

    releases = response.data as List;
  } on DioException catch (e) {
    final message =
        e.response?.data?['message']?.toString() ?? e.message ?? t.networkRequestFailed;

    App.rootContext.showMessage(message: message, level: LogLevel.warning);

    return;
  } catch (e) {
    App.rootContext.showMessage(
      message: e.toString(),
      level: LogLevel.warning,
    );
    return;
  }
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => Sheet(
      title: t.kostoriChangelog,
      icon: Icons.history,
      initialSize: 0.75,
      builder: (context, sc) => ListView.separated(
        controller: sc,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        itemCount: releases.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) => ReleaseCard(release: releases[index]),
      ),
    ),
  );
}

/// 检查最新版本信息
Future<Map<String, dynamic>> fetchLatestRelease() async {
  final response = await AppDio().request(
    'https://api.github.com/repos/kostori-app/kostori/releases/latest',
    options: Options(method: 'GET'),
  );

  final tagName = response.data['tag_name']?.toString() ?? '';
  final assets = (response.data['assets'] as List).cast<Map<String, dynamic>>();
  final body = response.data['body']?.toString() ?? '';

  return {
    'version': tagName, // 最新版本号
    'assets': assets, // Assets 列表
    'body': body, // Release 描述
  };
}

/// 获取匹配当前 ABI 的 Android 资源
Future<Map<String, dynamic>?> getMatchedAndroidAsset(
  List<Map<String, dynamic>> assets,
) async {
  if (!App.isAndroid) return null;
  final abi = await getAppAbi();
  final asset = assets.firstWhere(
    (a) => (a['name'] as String).contains(abi),
    orElse: () => {},
  );
  if (asset.isEmpty) return null;
  return asset;
}

/// 获取应用 ABI
Future<String> getAppAbi() async {
  const platform = MethodChannel('kostori/abi');
  try {
    final abi = await platform.invokeMethod<String>('getAbi');
    return abi ?? 'unknown';
  } on PlatformException catch (e) {
    return 'error: ${e.message}';
  }
}

/// 计算文件的 SHA256
Future<String> calculateSha256(File file) async {
  final bytes = await file.readAsBytes();
  return sha256.convert(bytes).toString();
}

/// 检查下载的 APK 是否完整
Future<bool> verifyFileSha256(File file, String expectedSha256) async {
  if (!await file.exists()) return false;
  final actualSha256 = await calculateSha256(file);
  return actualSha256 == expectedSha256;
}

/// 下载 APK 并返回 DownloadTask
AppDownloadTask prepareDownloadTask(
  String url,
  String savePath,
  void Function(double) onProgress,
) {
  final task = AppDownloadTask(url: url, savePath: savePath);
  task.progressStream.listen(
    onProgress,
    onError: (err) {
      if (!App.rootContext.mounted) return;
      App.rootContext.showMessage(message: err.toString());
    },
    cancelOnError: true,
  );
  return task;
}

/// 获取下载目录和文件路径
Future<File> getDownloadFile(String fileName) async {
  Directory? dir;

  if (Platform.isAndroid) {
    // 安卓使用 AbsolutePath 或下载目录
    dir =
        await AbsolutePath.absoluteDirectory(
          dirType: DirectoryType.downloads,
        ) ??
        await getApplicationDocumentsDirectory();
  } else if (Platform.isIOS) {
    // iOS 使用应用文档目录
    dir = await getApplicationDocumentsDirectory();
  } else {
    // 其他平台，如桌面
    dir = await getDownloadsDirectory();
  }
  final filePath = path.join(dir!.path, fileName);
  final file = File(filePath);
  if (!file.existsSync() && App.isAndroid) await file.create(recursive: true);
  return file;
}

/// 权限检查
Future<bool> checkInstallPermission() async {
  var status = await Permission.requestInstallPackages.status;
  if (status.isGranted) return true;
  if (status.isDenied) {
    return (await Permission.requestInstallPackages.request()).isGranted;
  }
  if (status.isPermanentlyDenied) {
    openAppSettings();
    return false;
  }
  return (await Permission.requestInstallPackages.request()).isGranted;
}

Future<bool> checkStoragePermission() async {
  var status = await Permission.storage.status;
  if (status.isGranted) return true;
  if (status.isDenied) return (await Permission.storage.request()).isGranted;
  if (status.isPermanentlyDenied) {
    openAppSettings();
    return false;
  }
  return (await Permission.storage.request()).isGranted;
}

class ReleaseCard extends StatefulWidget {
  final Map<String, dynamic> release;

  const ReleaseCard({super.key, required this.release});

  @override
  State<ReleaseCard> createState() => _ReleaseCardState();
}

class _ReleaseCardState extends State<ReleaseCard> {
  final TranslationController _tc = TranslationController();
  bool _expanded = false;

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final release = widget.release;
    final createdAt = release['created_at'] as String? ?? '';
    final createdAtDate = DateTime.tryParse(createdAt);
    final createdAtText = createdAtDate == null
        ? createdAt
        : DateFormat('yyyy/M/d').format(createdAtDate);
    final name =
        release['name'] as String? ?? release['tag_name']?.toString() ?? '';
    final body = release['body'] as String? ?? '';

    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: cs.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          createdAtText,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TranslateIconButton(
                    data: body,
                    controller: _tc,
                    iconSize: 18,
                  ),
                  IconButton(
                    tooltip: _expanded ? t.collapse : t.expand,
                    onPressed: () => setState(() => _expanded = !_expanded),
                    icon: AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        size: 20,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomMarkdownWidget(data: body),
                  TranslationOutput(
                    controller: _tc,
                    padding: const EdgeInsets.only(top: 8),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class UpdateDialog extends StatefulWidget {
  final Map<bool, String?> checkUpdate;

  const UpdateDialog({super.key, required this.checkUpdate});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  double downloadProgress = 0.0;
  bool isDownloading = false;
  bool fileValid = false;
  AppDownloadTask? task;
  StreamSubscription<double>? _sub;
  Map<dynamic, dynamic> releaseData = {};

  String latestVersion = '';
  Map<String, dynamic>? matchedAsset;
  File? file;
  String expectedSha256 = '';
  String markdown = '';
  bool isVersionConsistent = true;

  Map<bool, String?> get value => widget.checkUpdate;

  bool isLoading = false;

  @override
  void initState() {
    _initData();
    super.initState();
  }

  Future<void> _initData() async {
    isLoading = true;
    releaseData = await fetchLatestRelease();

    latestVersion = releaseData['version'] as String? ?? '';

    markdown = releaseData['body'] ?? '';

    final assets = releaseData['assets'] as List<Map<String, dynamic>>? ?? [];
    matchedAsset = await getMatchedAndroidAsset(assets);

    final name = matchedAsset?['name'] ?? '';
    final digest = matchedAsset?['digest'] as String? ?? '';
    expectedSha256 = digest.startsWith('sha256:')
        ? digest.substring(7)
        : digest;

    file = await getDownloadFile(name);
    fileValid = await verifyFileSha256(file!, expectedSha256);

    if (matchedAsset == null && App.isAndroid) {
      App.rootContext.showMessage(
        message: t.noUpdateAvailableForThisArchitectureA(a: await getAppAbi()),
      );
    }

    if (latestVersion != value.values.first.toString()) {
      Log.info(
        "Version Consistent",
        '$latestVersion -> ${value.values.first.toString()}',
      );
      App.rootContext.showMessage(message: t.inconsistentVersions);
      isVersionConsistent = false;
    }

    isLoading = false;
    if (mounted) setState(() {});
  }

  void _startDownload(String url) {
    if (isDownloading || file == null) return;

    setState(() {
      isDownloading = true;
      downloadProgress = 0.0;
    });

    task = prepareDownloadTask(url, file!.path, (progress) {
      if (!mounted) return;
      setState(() {
        downloadProgress = progress;
      });
    });

    _sub = task?.progressStream.listen(
      (_) {},
      onError: (err) {
        if (!mounted) return;
        App.rootContext.showMessage(message: err.toString());
      },
      cancelOnError: true,
    );

    task
        ?.start()
        .then((_) async {
          if (!mounted) return;
          final valid = await verifyFileSha256(file!, expectedSha256);
          setState(() {
            fileValid = valid;
            isDownloading = false;
          });
          if (!valid) {
            App.rootContext.showMessage(
              message: t.failedToCheckTheHashValuePleaseTryAgain,
            );
          }
        })
        .catchError((e) {
          if (!mounted) return;
          setState(() {
            isDownloading = false;
          });
          if (CancelToken.isCancel(e)) {
            App.rootContext.showMessage(
              message: t.downloadCanceled,
              level: LogLevel.warning,
            );
          } else {
            App.rootContext.showMessage(message: e.toString());
            Log.error('startDownload', e.toString());
          }
        });
  }

  @override
  void dispose() {
    task?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final downloadUrl = matchedAsset?['browser_download_url'] ?? '';

    return ContentDialog(
      title: t.newVersionAvailable,
      content: isLoading
          ? Center(child: KostoriRefreshIndicator())
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.discoverTheNewVersionV(v: value.values),
                ),
                const SizedBox(height: 12),
                if (isDownloading)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: LinearProgressIndicator(value: downloadProgress),
                      ),
                      const SizedBox(height: 8),
                      Text('${(downloadProgress * 100).toStringAsFixed(0)}%'),
                    ],
                  )
                else
                  Material(
                    color: context.brightness == Brightness.light
                        ? Colors.white.toOpacity(0.72)
                        : const Color(0xFF1E1E1E).toOpacity(0.72),
                    elevation: 4,
                    shadowColor: Theme.of(context).colorScheme.shadow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 600),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(8),
                        child: TranslationWidget(
                          data: markdown,
                          title: Text(
                            t.kostoriChangelog,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
      actions: [
        if (fileValid && App.isAndroid)
          Button.text(
            onPressed: () async {
              if (!await checkInstallPermission() ||
                  !await checkStoragePermission()) {
                return;
              }
              const platform = MethodChannel('kostori/install_apk');
              await platform.invokeMethod('installApk', {
                "apkPath": file!.path,
              });
            },
            child: Text(t.install),
          )
        else if (!isDownloading && App.isAndroid && isVersionConsistent) ...[
          Button.text(
            onPressed: () => _startDownload(Api.gitMirror + downloadUrl),
            child: Text(t.mirror),
          ),
          Button.text(
            onPressed: () => _startDownload(downloadUrl),
            child: Text(t.download),
          ),
        ],
        Button.text(
          onPressed: () {
            Navigator.pop(context);
            launchUrlString("https://github.com/kostori-app/kostori/releases");
          },
          child: Text(t.viewOnGithub),
        ),
      ],
      cancel: () {
        task?.cancel();
        _sub?.cancel();
        if (mounted) {
          setState(() {
            isDownloading = false;
            downloadProgress = 0.0;
          });
        }
      },
    );
  }
}
