// ignore_for_file: use_build_context_synchronously

part of 'settings_page.dart';

class AboutSettings extends StatefulWidget {
  const AboutSettings({super.key});

  @override
  State<AboutSettings> createState() => _AboutSettingsState();
}

class _AboutSettingsState extends State<AboutSettings> {
  bool isCheckingAppUpdate = false;
  bool isCheckingBangumiDataUpdate = false;
  bool isCheckingBangumiDataReset = false;
  bool isUpdateLog = false;

  @override
  Widget build(BuildContext context) {
    return SmoothCustomScrollView(
      slivers: [
        SliverAppbar(title: Text("About".tl)),
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
              "Kostori is a free and open-source app for anime watching.".tl,
            ),
            const SizedBox(height: 8),
          ],
        ).toSliver(),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverToBoxAdapter(
            child: _SettingCard(
              children: [
                _SettingPartTitle(
                  title: "Github".tl,
                  icon: Icons.radio_button_unchecked_outlined,
                ),
                ListTile(
                  title: Text("Check for updates".tl),
                  trailing: Button.filled(
                    isLoading: isCheckingAppUpdate,
                    child: Text("Check".tl),
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
                  title: Text("Update log".tl),
                  trailing: Button.filled(
                    isLoading: isUpdateLog,
                    child: Text("Open".tl),
                    onPressed: () async {
                      setState(() {
                        isUpdateLog = true;
                      });
                      await updateLog(context).then((value) {
                        setState(() {
                          isUpdateLog = false;
                        });
                      });
                    },
                  ).fixHeight(32),
                ),
                _SwitchSetting(
                  title: "Check for updates on startup".tl,
                  settingKey: "checkUpdateOnStart",
                ),
                ListTile(
                  title: Text("Icon producer".tl),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverToBoxAdapter(
            child: _SettingCard(
              children: [
                _SettingPartTitle(
                  title: "Bangumi".tl,
                  icon: Icons.radio_button_unchecked_outlined,
                ),
                ListTile(
                  title: const Text("Bangumi-data"),
                  subtitle: Text(appdata.settings['bangumiDataVer']),
                  trailing: Button.filled(
                    isLoading: isCheckingBangumiDataUpdate,
                    child: Text("Check".tl),
                    onPressed: () {
                      setState(() {
                        isCheckingBangumiDataUpdate = true;
                      });
                      Bangumi.checkBangumiData().then((value) {
                        setState(() {
                          isCheckingBangumiDataUpdate = false;
                        });
                      });
                    },
                  ).fixHeight(32),
                ),
                ListTile(
                  title: Text("Reset Bangumi-data".tl),
                  trailing: Button.filled(
                    isLoading: isCheckingBangumiDataReset,
                    child: Text("Reset".tl),
                    onPressed: () {
                      setState(() {
                        isCheckingBangumiDataReset = true;
                      });
                      Bangumi.resetBangumiData().then((value) {
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
      ],
    );
  }
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
    App.rootContext.showMessage(message: 'Check update failed...'.tl);
    Log.addLog(LogLevel.error, "checkUpdate", '$e\n$s');
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
      App.rootContext.showMessage(message: "No new version available".tl);
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
  final response = await AppDio().request(
    'https://api.github.com/repos/kostori-app/kostori/releases',
    options: Options(method: 'GET'),
  );
  final releases = response.data as List;
  final dragProgress = ValueNotifier(0.0);

  showGeneralDialog(
    context: context,
    barrierLabel: "Dismiss",
    barrierDismissible: true,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, anim1, anim2) {
      return Stack(
        children: [
          ValueListenableBuilder<double>(
            valueListenable: dragProgress,
            builder: (context, progress, _) {
              final dragOpacity = (1.0 - progress).clamp(0.0, 1.0);

              return FadeTransition(
                opacity: anim1,
                child: Opacity(
                  opacity: dragOpacity,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(color: Colors.black.toOpacity(0.2)),
                    ),
                  ),
                ),
              );
            },
          ),

          SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(anim1),
            child: _DraggableBlurSheet(
              releases: releases.map((r) => ReleaseCard(release: r)).toList(),
              maxHeight: MediaQuery.of(context).size.height * 0.75,
              onDragProgress: (progress) => dragProgress.value = progress,
            ),
          ),
        ],
      );
    },
    transitionBuilder: (context, anim1, anim2, child) => child,
  );
}

class _DraggableBlurSheet extends StatefulWidget {
  final List<Widget> releases;
  final double maxHeight;
  final ValueChanged<double>? onDragProgress;

  const _DraggableBlurSheet({
    required this.releases,
    this.onDragProgress,
    required this.maxHeight,
  });

  @override
  State<_DraggableBlurSheet> createState() => _DraggableBlurSheetState();
}

class _DraggableBlurSheetState extends State<_DraggableBlurSheet> {
  double _dragOffset = 0;

  void _updateDrag(double delta) {
    setState(() {
      _dragOffset += delta;
      if (_dragOffset < 0) _dragOffset = 0; // 不允许向上无限拖
      if (_dragOffset > widget.maxHeight) _dragOffset = widget.maxHeight;
    });
    widget.onDragProgress?.call(_dragOffset / widget.maxHeight);
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: GestureDetector(
        onVerticalDragUpdate: (details) => _updateDrag(details.delta.dy),
        onVerticalDragEnd: (details) {
          if (_dragOffset > 100 || (details.primaryVelocity ?? 0) > 700) {
            Navigator.of(context).pop();
          } else {
            _updateDrag(-_dragOffset); // 回弹
          }
        },
        child: Transform.translate(
          offset: Offset(0, _dragOffset),
          child: Container(
            height: widget.maxHeight,
            width: MediaQuery.of(context).size.width,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor.toOpacity(0.9),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Column(
              children: [
                // 顶部拖动条
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Container(
                    height: 4,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // 内容区
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Text(
                                  'Kostori Changelog',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          ...widget.releases,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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

Widget buildMarkdown(BuildContext context, String data) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  final config = MarkdownConfig(
    configs: [
      PConfig(
        textStyle: TextStyle(color: isDark ? Colors.white : Colors.black),
      ),
      CodeConfig(
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          backgroundColor: isDark ? Colors.black26 : Colors.grey[200],
        ),
      ),
    ],
  );

  return MarkdownBlock(data: data, config: config);
}

class ReleaseCard extends StatelessWidget {
  final Map<String, dynamic> release;

  const ReleaseCard({super.key, required this.release});

  String _formatDate(String isoString) {
    final date = DateTime.parse(isoString);
    return DateFormat('yyyy/M/d').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final createdAt = release['created_at'] as String;
    final name = release['name'] as String? ?? release['tag_name'];
    final body = release['body'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 第一行：日期
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  _formatDate(createdAt),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 第二行：版本名 (居中)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 第三部分：Markdown body
            buildMarkdown(context, body),
          ],
        ),
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
        message: "No update available for this architecture (@a)".tlParams({
          "a": await getAppAbi(),
        }),
      );
    }

    if (latestVersion != value.values.first.toString()) {
      Log.addLog(
        LogLevel.info,
        "Version Consistent",
        '$latestVersion -> ${value.values.first.toString()}',
      );
      App.rootContext.showMessage(message: "Inconsistent versions".tl);
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
              message: "Failed to check the hash value. Please try again".tl,
            );
          }
        })
        .catchError((e) {
          if (!mounted) return;
          setState(() {
            isDownloading = false;
          });
          if (CancelToken.isCancel(e)) {
            App.rootContext.showMessage(message: "Download canceled");
          } else {
            App.rootContext.showMessage(message: e.toString());
            Log.addLog(LogLevel.error, 'startDownload', e.toString());
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
      title: "New version available".tl,
      content: isLoading
          ? Center(
              child: MiscComponents.placeholder(
                context,
                50,
                50,
                Colors.transparent,
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Discover the new version @v".tlParams({"v": value.values}),
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
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(8),
                        child: buildMarkdown(context, markdown),
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
            child: Text("Install".tl),
          )
        else if (!isDownloading && App.isAndroid && isVersionConsistent) ...[
          Button.text(
            onPressed: () => _startDownload(Api.gitMirror + downloadUrl),
            child: Text("Mirror".tl),
          ),
          Button.text(
            onPressed: () => _startDownload(downloadUrl),
            child: Text("Download".tl),
          ),
        ],
        Button.text(
          onPressed: () {
            Navigator.pop(context);
            launchUrlString("https://github.com/kostori-app/kostori/releases");
          },
          child: Text("View on GitHub".tl),
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
