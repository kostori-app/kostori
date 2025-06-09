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
            Text(
              "V${App.version}",
              style: const TextStyle(fontSize: 16),
            ),
            Text(
                "Kostori is a free and open-source app for anime watching.".tl),
            const SizedBox(height: 8),
          ],
        ).toSliver(),
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
        ).toSliver(),
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
        ).toSliver(),
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
        ).toSliver(),
        _SwitchSetting(
          title: "Check for updates on startup".tl,
          settingKey: "checkUpdateOnStart",
        ).toSliver(),
        ListTile(
          title: Text("Icon producer".tl),
          trailing: const Icon(Icons.open_in_new),
          onTap: () {
            launchUrlString("https://www.pixiv.net/users/18071897");
          },
        ).toSliver(),
        ListTile(
          title: const Text("Github"),
          trailing: const Icon(Icons.open_in_new),
          onTap: () {
            launchUrlString("https://github.com/kostori-app/kostori");
          },
        ).toSliver(),
      ],
    );
  }
}

Future<Map<bool, String?>> checkUpdate() async {
  try {
    var res = await AppDio().get(
        "https://raw.githubusercontent.com/kostori-app/kostori/refs/heads/master/pubspec.yaml");
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

Future<void> checkUpdateUi([bool showMessageIfNoUpdate = true]) async {
  var value = await checkUpdate();
  if (value.containsKey(true)) {
    showDialog(
      context: App.rootContext,
      builder: (context) {
        return ContentDialog(
          title: "New version available".tl,
          content: Text(
            "Discover the new version @v".tlParams({"v": value.values}),
          ),
          actions: [
            Button.text(
              onPressed: () {
                Navigator.pop(context);
                launchUrlString(
                    "https://github.com/kostori-app/kostori/releases");
              },
              child: Text("Update".tl),
            ),
          ],
        );
      },
    );
  } else if (showMessageIfNoUpdate) {
    App.rootContext.showMessage(message: "No new version available".tl);
  }
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
