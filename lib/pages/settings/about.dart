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
        return {hasNew: fetchedVersion}; // 返回 Map
      }
    }
    return {false: null}; // 返回 Map
  } catch (e, s) {
    App.rootContext.showMessage(message: '检查更新失败...');
    Log.addLog(LogLevel.error, "checkUpdate", '$e\n$s');
    return {false: null}; // 返回 Map
  }
}

Future<void> checkUpdateUi([
  bool showMessageIfNoUpdate = true,
  bool delay = false,
]) async {
  var value = await checkUpdate();
  double downloadProgress = 0.0;
  String? taskId;
  bool isDownloading = false;
  bool downloadStopped = false;
  bool isVersionConsistent = true;

  if (!value.containsKey(true)) {
    if (showMessageIfNoUpdate) {
      App.rootContext.showMessage(message: "No new version available".tl);
    }
    return;
  }

  if (delay) {
    await Future.delayed(const Duration(seconds: 2));
  }

  late StateSetter dialogSetState;

  ReceivePort port = ReceivePort();
  if (IsolateNameServer.lookupPortByName('downloader_send_port') != null) {
    IsolateNameServer.removePortNameMapping('downloader_send_port');
  }
  IsolateNameServer.registerPortWithName(port.sendPort, 'downloader_send_port');
  bool fileValid = false;
  String abi = '';
  String filePath = '';
  String downloadUrl = '';
  String name = '';
  Directory? dir;
  File file;
  final response = await AppDio().request(
    'https://api.github.com/repos/kostori-app/kostori/releases/latest',
    options: Options(method: 'GET'),
  );
  if (response.data['tag_name'] != value.values) {
    App.rootContext.showMessage(message: "版本不一致".tl);
    isVersionConsistent = false;
  }
  final assets = (response.data['assets'] as List).cast<Map<String, dynamic>>();
  if (App.isAndroid) {
    abi = await getAppAbi();
  }
  final matchedAsset = assets.firstWhere(
    (a) => (a['name'] as String).contains(abi),
    orElse: () => {},
  );

  if (matchedAsset.isEmpty && App.isAndroid) {
    App.rootContext.showMessage(
      message: "No update available for this architecture ($abi)",
    );
  }

  if (App.isAndroid) {
    name = matchedAsset['name'];
    downloadUrl = matchedAsset['browser_download_url'];
    final digest = matchedAsset['digest'] as String? ?? '';
    final expectedSha256 = digest.startsWith('sha256:')
        ? digest.substring(7)
        : digest;
    dir = await AbsolutePath.absoluteDirectory(
      dirType: DirectoryType.downloads,
    );
    filePath = path.join(dir!.path, name);
    file = File(filePath);

    if (await file.exists()) {
      final actualSha256 = await calculateSha256(file);
      fileValid = (actualSha256 == expectedSha256);
    }
    Log.addLog(
      LogLevel.info,
      "infoPrint",
      '$name \n $downloadUrl \n $expectedSha256 \n $filePath',
    );
    port.listen((dynamic data) async {
      String id = data[0];
      int statusInt = data[1];
      int progress = data[2];

      DownloadTaskStatus status = DownloadTaskStatus.values[statusInt];

      if (id == taskId) {
        dialogSetState(() {
          downloadProgress = progress / 100;
          isDownloading = status == DownloadTaskStatus.running;
          if (!isDownloading && progress != 100 && !downloadStopped) {
            downloadStopped = true;
            App.rootContext.showMessage(message: "下载失败".tl);
          }
        });
        if (progress == 100) {
          if (await file.exists()) {
            final actualSha256 = await calculateSha256(file);
            dialogSetState.call(() {
              fileValid = (actualSha256 == expectedSha256);
            });
            if (!fileValid) {
              App.rootContext.showMessage(message: "检查哈希值失败,请重试".tl);
            }
          }
        }
      }
    });
    FlutterDownloader.registerCallback(downloadCallback);
  }

  showDialog(
    context: App.rootContext,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          dialogSetState = setState;

          return ContentDialog(
            title: "New version available".tl,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Discover the new version @v".tlParams({"v": value.values}),
                ),
                const SizedBox(height: 12),
                (isDownloading)
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: LinearProgressIndicator(
                              value: downloadProgress,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${(downloadProgress * 100).toStringAsFixed(0)}%',
                          ),
                        ],
                      )
                    : Material(
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
                            child: buildMarkdown(
                              context,
                              response.data['body'],
                            ),
                          ),
                        ),
                      ),
              ],
            ),
            actions: [
              if (fileValid && App.isAndroid && matchedAsset.isNotEmpty)
                Button.text(
                  onPressed: () async {
                    try {
                      bool installPermGranted =
                          await checkAndRequestInstallPermission();
                      bool storagePermGranted =
                          await checkAndRequestStoragePermission();

                      if (!installPermGranted || !storagePermGranted) {
                        return;
                      }

                      const platform = MethodChannel('kostori/install_apk');
                      await platform.invokeMethod('installApk', {
                        "apkPath": filePath,
                      });
                    } catch (e) {
                      Log.addLog(
                        LogLevel.error,
                        "AndroidPackageInstaller",
                        e.toString(),
                      );
                    }
                  },
                  child: Text("Install".tl),
                )
              else if (!isDownloading &&
                  App.isAndroid &&
                  matchedAsset.isNotEmpty &&
                  isVersionConsistent) ...[
                Button.text(
                  onPressed: () async {
                    setState(() {
                      isDownloading = true;
                      downloadStopped = false;
                      fileValid = false;
                      downloadProgress = 0.0;
                    });

                    taskId = await FlutterDownloader.enqueue(
                      url: Api.gitMirror + downloadUrl,
                      savedDir: dir!.path,
                      fileName: name,
                      showNotification: true,
                      openFileFromNotification: true,
                    );
                  },
                  child: Text("Mirror".tl),
                ),
                Button.text(
                  onPressed: () async {
                    setState(() {
                      isDownloading = true;
                      downloadStopped = false;
                      fileValid = false;
                      downloadProgress = 0.0;
                    });

                    taskId = await FlutterDownloader.enqueue(
                      url: downloadUrl,
                      savedDir: dir!.path,
                      fileName: name,
                      showNotification: true,
                      openFileFromNotification: true,
                    );
                  },
                  child: Text("Download".tl),
                ),
              ],
              Button.text(
                onPressed: () {
                  Navigator.pop(context);
                  launchUrlString(
                    "https://github.com/kostori-app/kostori/releases",
                  );
                },
                child: Text("View on GitHub".tl),
              ),
            ],
            cancel: () {
              if (App.isAndroid) {
                if (taskId != null) {
                  FlutterDownloader.cancel(taskId: taskId!);
                  setState(() {
                    isDownloading = false;
                    downloadProgress = 0.0;
                    taskId = null;
                    IsolateNameServer.removePortNameMapping(
                      'downloader_send_port',
                    );
                  });
                }
              }
            },
          );
        },
      );
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

Future<String> calculateSha256(File file) async {
  final bytes = await file.readAsBytes();
  final digest = sha256.convert(bytes);
  return digest.toString();
}

Future<String> getAppAbi() async {
  const platform = MethodChannel('kostori/abi');
  try {
    final abi = await platform.invokeMethod<String>('getAbi');
    return abi ?? 'unknown';
  } on PlatformException catch (e) {
    return 'error: ${e.message}';
  }
}

@pragma('vm:entry-point')
void downloadCallback(String id, int status, int progress) {
  final SendPort? send = IsolateNameServer.lookupPortByName(
    'downloader_send_port',
  );
  send?.send([id, status, progress]);
}

Future<bool> checkAndRequestInstallPermission() async {
  var status = await Permission.requestInstallPackages.status;

  if (status.isGranted) {
    return true;
  }

  if (status.isDenied) {
    var result = await Permission.requestInstallPackages.request();
    return result.isGranted;
  }

  if (status.isPermanentlyDenied) {
    openAppSettings();
    return false;
  }

  var result = await Permission.requestInstallPackages.request();
  return result.isGranted;
}

Future<bool> checkAndRequestStoragePermission() async {
  var status = await Permission.storage.status;

  if (status.isGranted) {
    return true;
  }

  if (status.isDenied) {
    var result = await Permission.storage.request();
    return result.isGranted;
  }

  if (status.isPermanentlyDenied) {
    openAppSettings();
    return false;
  }

  var result = await Permission.storage.request();
  return result.isGranted;
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
