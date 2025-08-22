part of 'settings_page.dart';

class AppearanceSettings extends StatefulWidget {
  const AppearanceSettings({super.key});

  @override
  State<AppearanceSettings> createState() => _AppearanceSettingsState();
}

class _AppearanceSettingsState extends State<AppearanceSettings>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final themeModes = {
    "system": "System".tl,
    "light": "Light".tl,
    "dark": "Dark".tl,
  };
  int themeMode = 0;

  @override
  void initState() {
    super.initState();
    themeMode = themeModes.keys.toList().indexOf(
      appdata.settings["theme_mode"],
    );
    _tabController = TabController(
      length: themeModes.length,
      vsync: this,
      initialIndex: themeMode,
    );
    _tabController.addListener(() {
      switch (_tabController.index) {
        case 0:
          appdata.settings["theme_mode"] = "system";
          appdata.saveData();
          App.forceRebuild();
          break;
        case 1:
          appdata.settings["theme_mode"] = "light";
          appdata.saveData();
          App.forceRebuild();
          break;
        case 2:
          appdata.settings["theme_mode"] = "dark";
          appdata.saveData();
          App.forceRebuild();
          break;
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SmoothCustomScrollView(
      slivers: [
        SliverAppbar(
          title: Text("Appearance".tl),
          bottom: TabBar(
            controller: _tabController,
            tabs: themeModes.values.map((label) => Tab(text: label)).toList(),
            dividerColor: Colors.transparent,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverToBoxAdapter(
            child: _SettingCard(
              children: [
                _SwitchSetting(
                  title: "AMOLED".tl,
                  settingKey: "AMOLED",
                  onChanged: () {
                    App.forceRebuild();
                  },
                ),
                _SwitchSetting(
                  title: "动态取色".tl,
                  settingKey: "dynamicColor",
                  onChanged: () async {
                    await App.init();
                    App.forceRebuild();
                  },
                ),
                if (!appdata.settings['dynamicColor'])
                  ThemePreviewScroller(seedColorMap: standardColorMap),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ThemePreviewScroller extends StatefulWidget {
  final Map<Color, String> seedColorMap;

  const ThemePreviewScroller({super.key, required this.seedColorMap});

  @override
  State<ThemePreviewScroller> createState() => _ThemePreviewScrollerState();
}

class _ThemePreviewScrollerState extends State<ThemePreviewScroller> {
  late Color? selected;

  @override
  void initState() {
    super.initState();
    selected = standardColorMap.entries
        .firstWhere(
          (entry) => entry.value == appdata.settings["color"],
          orElse: () => const MapEntry(Colors.grey, 'Unknown'),
        )
        .key;
  }

  Future<Color?> _pickColor() async {
    Color? result = await showDialog(
      context: context,
      builder: (context) => ColorPickPage(
        initialColor:
            Utils.hexToColor(appdata.implicitData['customColor']) ??
            Color(0xFF66ccff),
      ),
    );
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.seedColorMap.entries.toList();

    final selectedScheme = selected != null
        ? ColorScheme.fromSeed(
            seedColor: selected!,
            brightness:
                MediaQuery.of(context).platformBrightness == Brightness.dark
                ? Brightness.dark
                : Brightness.light,
          )
        : null;

    final width = MediaQuery.of(context).size.width;
    const kTwoPanelChangeWidth = 720.0;

    final isNarrow = width <= kTwoPanelChangeWidth;

    final brightness = MediaQuery.of(context).platformBrightness;

    // 选中的色卡Widget
    final selectedWidget = selectedScheme == null
        ? const SizedBox()
        : Column(
            children: [
              ThemePreviewCard(
                scheme: selectedScheme,
                seedColor: selected!,
                isSelected: true,
                onTap: null,
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 160,
                child: Center(
                  child: Text(
                    appdata.settings["color"],
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          );

    // 色卡列表Widget
    final colorListWidget = SizedBox(
      height: 280,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final color = entries[index].key;
          final name = entries[index].value;

          final scheme = ColorScheme.fromSeed(
            seedColor: color,
            brightness: brightness == Brightness.dark
                ? Brightness.dark
                : Brightness.light,
          );

          final isSelected = color == selected;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                ThemePreviewCard(
                  scheme: scheme,
                  seedColor: color,
                  isSelected: isSelected,
                  onTap: () {
                    setState(() {
                      selected = color;
                      appdata.settings["color"] = name;
                      appdata.saveData().then((_) async {
                        await App.init();
                        App.forceRebuild();
                      });
                    });
                  },
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 160,
                  child: Center(
                    child: Text(
                      name.tl,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    // 自定义色卡Widget
    final customColor =
        Utils.hexToColor(appdata.implicitData['customColor']) ??
        const Color(0xFF6677ff);
    final customScheme = ColorScheme.fromSeed(
      seedColor: customColor,
      brightness: brightness == Brightness.dark
          ? Brightness.dark
          : Brightness.light,
    );

    final customWidget = Column(
      children: [
        ThemePreviewCard(
          scheme: customScheme,
          seedColor: customColor,
          isSelected: selected == customColor,
          onTap: () {
            setState(() {
              selected = customColor;
              appdata.settings["color"] = "Custom";
              appdata.saveData().then((_) async {
                await App.init();
                App.forceRebuild();
              });
            });
          },
          onLongPress: () async {
            final result = await _pickColor();
            if (result != null) {
              setState(() {
                selected = result;
                appdata.implicitData['customColor'] = Utils.colorToHex(result);
                appdata.writeImplicitData();
                appdata.settings["color"] = "Custom";
                appdata.saveData().then((_) async {
                  await App.init();
                  App.forceRebuild();
                });
              });
            }
          },
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 160,
          child: Center(
            child: Text(
              "Custom".tl,
              style: TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );

    if (isNarrow) {
      return SizedBox(
        height: 600,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 12),
                selectedWidget,
                const SizedBox(width: 16),
                customWidget,
                const SizedBox(width: 12),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(child: colorListWidget),
          ],
        ),
      );
    } else {
      return SizedBox(
        height: 280,
        child: Row(
          children: [
            if (selectedScheme != null) ...[
              const SizedBox(width: 12),
              selectedWidget,
              const SizedBox(width: 16),
            ],
            Expanded(child: colorListWidget),
            const SizedBox(width: 16),
            customWidget,
            const SizedBox(width: 12),
          ],
        ),
      );
    }
  }
}

class ThemePreviewCard extends StatelessWidget {
  final ColorScheme scheme;
  final Color seedColor;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ThemePreviewCard({
    super.key,
    required this.scheme,
    required this.seedColor,
    required this.isSelected,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 240,
      child: Card(
        shape: RoundedRectangleBorder(
          side: isSelected
              ? BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                )
              : BorderSide.none,
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 4,
        clipBehavior: Clip.antiAlias,
        color: scheme.surface,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Column(
            children: [
              _colorTile("Primary", scheme.primary),
              _colorTile("Secondary", scheme.secondary),
              _colorTile("Tertiary", scheme.tertiary),
              _colorTile("Surface", scheme.surface),
            ],
          ),
        ),
      ),
    );
  }

  Widget _colorTile(String label, Color color) {
    return Expanded(
      child: Container(
        color: color,
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color:
                ThemeData.estimateBrightnessForColor(color) == Brightness.dark
                ? Colors.white
                : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class ColorPickPage extends StatefulWidget {
  final Color initialColor;

  const ColorPickPage({super.key, required this.initialColor});

  @override
  State<ColorPickPage> createState() => _ColorPickPageState();
}

class _ColorPickPageState extends State<ColorPickPage> {
  late Color pickerColor;
  late TextEditingController controller;

  @override
  void initState() {
    super.initState();
    pickerColor = widget.initialColor;
    controller = TextEditingController(text: Utils.colorToHex(pickerColor));
  }

  void _onTextChanged(String value) {
    final color = Utils.hexToColor(value);
    if (color != null) {
      setState(() {
        pickerColor = color;
        controller.text = Utils.colorToHex(color);
        controller.selection = TextSelection.fromPosition(
          TextPosition(offset: controller.text.length),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('选择颜色'.tl),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ColorPicker(
              color: pickerColor,
              onColorChanged: (Color color) {
                pickerColor = color;
                controller.text = Utils.colorToHex(color);
              },
              pickersEnabled: <ColorPickerType, bool>{
                ColorPickerType.wheel: true,
                ColorPickerType.primary: true,
                ColorPickerType.accent: true,
                // ColorPickerType.custom: false,
              },
              pickerTypeLabels: <ColorPickerType, String>{
                ColorPickerType.wheel: "色轮".tl,
                ColorPickerType.primary: "主要".tl,
                ColorPickerType.accent: '强调'.tl,
                ColorPickerType.custom: '自定义'.tl,
              },
              copyPasteBehavior: const ColorPickerCopyPasteBehavior(
                copyButton: true,
                pasteButton: true,
                longPressMenu: true,
                secondaryMenu: true,
                secondaryOnDesktopLongOnDevice: true,
              ),
              enableShadesSelection: true,
              enableTonalPalette: true,
              enableOpacity: true,
              showColorCode: true,
              showColorName: true,
              showMaterialName: true,
              showRecentColors: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: '输入十六进制颜色码，例如 #FF000000'.tl,
                border: OutlineInputBorder(),
              ),
              maxLength: 9,
              onSubmitted: _onTextChanged,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'#[0-9a-fA-F]*')),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('取消'.tl),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(pickerColor),
          child: Text('确定'.tl),
        ),
      ],
    );
  }
}
