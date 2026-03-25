// ignore_for_file: unused_element_parameter

part of 'settings_page.dart';

enum SwitchDataSource { settings, implicit }

class _SwitchSetting extends StatefulWidget {
  const _SwitchSetting({
    required this.title,
    required this.settingKey,
    this.dataSource = SwitchDataSource.settings,
    this.onChanged,
    this.subtitle,
    super.key,
  });

  final String title;
  final String settingKey;
  final SwitchDataSource dataSource;
  final VoidCallback? onChanged;
  final String? subtitle;

  @override
  State<_SwitchSetting> createState() => _SwitchSettingState();
}

class _SwitchSettingState extends State<_SwitchSetting> {
  bool _getValue() {
    if (widget.dataSource == SwitchDataSource.settings) {
      final value = appdata.settings[widget.settingKey];
      if (value is bool) return value;
      return false;
    } else {
      final value = appdata.implicitData[widget.settingKey];
      if (value is bool) return value;
      return false;
    }
  }

  void _setValue(bool value) {
    if (widget.dataSource == SwitchDataSource.settings) {
      appdata.settings[widget.settingKey] = value;
      appdata.saveData();
    } else {
      appdata.implicitData[widget.settingKey] = value;
      appdata.writeImplicitData();
    }
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(widget.title),
      subtitle: widget.subtitle == null ? null : Text(widget.subtitle!),
      trailing: CustomSwitch(
        value: _getValue(),
        onChanged: (value) {
          setState(() {
            _setValue(value);
          });
        },
      ),
    );
  }
}

class CustomSwitch extends StatelessWidget {
  /// 开关的当前状态。
  final bool value;

  /// 开关被点击时调用的回调函数。
  final ValueChanged<bool> onChanged;

  /// 开关的整体高度。
  final double height;

  /// 开关的整体宽度。
  final double width;

  /// 开关背景（轨道）的颜色。
  final Color? trackColor;

  /// 滑块的颜色。
  final Color? thumbColor;

  /// 动画持续时间，单位毫秒。
  final int durationInMillisecond;

  /// 开启状态下背景的颜色。
  final Color? activeTrackColor;

  /// 关闭状态下背景的颜色。
  final Color? inactiveTrackColor;

  /// 关闭状态下滑块的颜色。
  final Color? inactiveThumbColor;

  /// 自定义滑块内部的子Widget。
  final Widget? thumbChild;

  final Gradient? activeGradient;

  const CustomSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.height = 21.0,
    this.width = 40.0,
    this.trackColor,
    this.thumbColor,
    this.durationInMillisecond = 300,
    this.activeTrackColor,
    this.inactiveTrackColor,
    this.inactiveThumbColor,
    this.thumbChild,
    this.activeGradient,
  });

  @override
  Widget build(BuildContext context) {
    final Color effectiveTrackColor = value
        ? Theme.of(context).colorScheme.primary
        : inactiveTrackColor ?? Colors.grey.toOpacity(0.5);
    final Color effectiveThumbColor = Colors.white;
    Color fixedGlowColor = Theme.of(context).colorScheme.primary;
    const double fixedGlowRadius = 12.0;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: Duration(milliseconds: durationInMillisecond),
          curve: Curves.easeInOut,
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: effectiveTrackColor,
            borderRadius: BorderRadius.circular(height / 2),
            boxShadow: value
                ? [
                    BoxShadow(
                      color: fixedGlowColor.toOpacity(0.36),
                      blurRadius: fixedGlowRadius,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: AnimatedAlign(
            duration: Duration(milliseconds: durationInMillisecond),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              width: height - 6,
              height: height - 6,
              decoration: BoxDecoration(
                color: effectiveThumbColor,
                shape: BoxShape.circle,
              ),
              child: thumbChild,
            ),
          ),
        ),
      ),
    );
  }
}

class SelectSetting extends StatelessWidget {
  const SelectSetting({
    super.key,
    required this.title,
    required this.settingKey,
    required this.optionTranslation,
    this.onChanged,
    this.help,
  });

  final String title;

  final String settingKey;

  final Map<String, String> optionTranslation;

  final VoidCallback? onChanged;

  final String? help;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 450) {
            return _DoubleLineSelectSettings(
              title: title,
              settingKey: settingKey,
              optionTranslation: optionTranslation,
              onChanged: onChanged,
              help: help,
            );
          } else {
            return _EndSelectorSelectSetting(
              title: title,
              settingKey: settingKey,
              optionTranslation: optionTranslation,
              onChanged: onChanged,
              help: help,
            );
          }
        },
      ),
    );
  }
}

class _DoubleLineSelectSettings extends StatefulWidget {
  const _DoubleLineSelectSettings({
    required this.title,
    required this.settingKey,
    required this.optionTranslation,
    this.onChanged,
    this.help,
  });

  final String title;

  final String settingKey;

  final Map<String, String> optionTranslation;

  final VoidCallback? onChanged;

  final String? help;

  @override
  State<_DoubleLineSelectSettings> createState() =>
      _DoubleLineSelectSettingsState();
}

class _DoubleLineSelectSettingsState extends State<_DoubleLineSelectSettings> {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Row(
        children: [
          Text(widget.title),
          const SizedBox(width: 4),
          if (widget.help != null)
            Button.icon(
              size: 18,
              icon: const Icon(Icons.help_outline),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return ContentDialog(
                      title: t.help,
                      content: Text(
                        widget.help!,
                      ).paddingHorizontal(16).fixWidth(double.infinity),
                      actions: [
                        Button.filled(
                          onPressed: context.pop,
                          child: Text(t.ok),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
        ],
      ),
      subtitle: Text(
        widget.optionTranslation[appdata.settings[widget.settingKey]] ?? "None",
      ),
      trailing: const Icon(Icons.arrow_drop_down),
      onTap: () {
        var renderBox = context.findRenderObject() as RenderBox;
        var offset = renderBox.localToGlobal(Offset.zero);
        var size = renderBox.size;
        var rect = offset & size;
        showMenu(
          elevation: 3,
          color: context.brightness == Brightness.light
              ? const Color(0xFFF6F6F6)
              : const Color(0xFF1E1E1E),
          context: context,
          position: RelativeRect.fromRect(
            rect,
            Offset.zero & MediaQuery.of(context).size,
          ),
          items: widget.optionTranslation.keys
              .map(
                (key) => PopupMenuItem(
                  value: key,
                  height: App.isMobile ? 46 : 40,
                  child: Text(widget.optionTranslation[key]!),
                ),
              )
              .toList(),
        ).then((value) {
          if (value != null) {
            setState(() {
              appdata.settings[widget.settingKey] = value;
            });
            appdata.saveData();
            widget.onChanged?.call();
          }
        });
      },
    );
  }
}

class _EndSelectorSelectSetting extends StatefulWidget {
  const _EndSelectorSelectSetting({
    required this.title,
    required this.settingKey,
    required this.optionTranslation,
    this.onChanged,
    this.help,
  });

  final String title;

  final String settingKey;

  final Map<String, String> optionTranslation;

  final VoidCallback? onChanged;

  final String? help;

  @override
  State<_EndSelectorSelectSetting> createState() =>
      _EndSelectorSelectSettingState();
}

class _EndSelectorSelectSettingState extends State<_EndSelectorSelectSetting> {
  @override
  Widget build(BuildContext context) {
    var options = widget.optionTranslation;
    return ListTile(
      title: Row(
        children: [
          Text(widget.title),
          const SizedBox(width: 4),
          if (widget.help != null)
            Button.icon(
              size: 18,
              icon: const Icon(Icons.help_outline),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return ContentDialog(
                      title: t.help,
                      content: Text(
                        widget.help!,
                      ).paddingHorizontal(16).fixWidth(double.infinity),
                      actions: [
                        Button.filled(
                          onPressed: context.pop,
                          child: Text(t.ok),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
        ],
      ),
      trailing: Select(
        current: options[appdata.settings[widget.settingKey]],
        values: options.values.toList(),
        minWidth: 64,
        onTap: (index) {
          setState(() {
            appdata.settings[widget.settingKey] = options.keys.elementAt(index);
          });
          appdata.saveData();
          widget.onChanged?.call();
        },
      ),
    );
  }
}

class _SliderSetting extends StatefulWidget {
  const _SliderSetting({
    required this.title,
    required this.settingsIndex,
    required this.interval,
    required this.min,
    required this.max,
    this.onChanged,
  });

  final String title;

  final String settingsIndex;

  final double interval;

  final double min;

  final double max;

  final VoidCallback? onChanged;

  @override
  State<_SliderSetting> createState() => _SliderSettingState();
}

class _SliderSettingState extends State<_SliderSetting> {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Row(
        children: [
          Text(widget.title),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              appdata.settings[widget.settingsIndex].toString(),
              style: ts.s12,
            ),
          ),
        ],
      ),
      subtitle: Slider(
        value: appdata.settings[widget.settingsIndex].toDouble(),
        onChanged: (value) {
          if (value.toInt() == value) {
            setState(() {
              appdata.settings[widget.settingsIndex] = value.toInt();
              appdata.saveData();
            });
          } else {
            setState(() {
              appdata.settings[widget.settingsIndex] = value;
              appdata.saveData();
            });
          }
          widget.onChanged?.call();
        },
        divisions: ((widget.max - widget.min) / widget.interval).toInt(),
        min: widget.min,
        max: widget.max,
      ),
    );
  }
}

class _PopupWindowSetting extends StatelessWidget {
  const _PopupWindowSetting({required this.title, required this.builder});

  final Widget Function() builder;

  final String title;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      trailing: const Icon(Icons.arrow_right),
      onTap: () {
        showPopUpWidget(App.rootContext, builder());
      },
    );
  }
}

class _MultiPagesFilter extends StatefulWidget {
  const _MultiPagesFilter({
    required this.title,
    required this.settingsIndex,
    required this.pages,
  });

  final String title;

  final String settingsIndex;

  // key - name
  final Map<String, String> pages;

  @override
  State<_MultiPagesFilter> createState() => _MultiPagesFilterState();
}

class _MultiPagesFilterState extends State<_MultiPagesFilter> {
  late List<String> keys;

  @override
  void initState() {
    keys = List.from(appdata.settings[widget.settingsIndex]);
    keys.remove("");
    super.initState();
  }

  var reorderWidgetKey = UniqueKey();
  var scrollController = ScrollController();
  final _key = GlobalKey();

  @override
  Widget build(BuildContext context) {
    var tiles = keys.map((e) => buildItem(e)).toList();

    var view = ReorderableBuilder<String>(
      key: reorderWidgetKey,
      scrollController: scrollController,
      longPressDelay: App.isDesktop
          ? const Duration(milliseconds: 100)
          : const Duration(milliseconds: 500),
      dragChildBoxDecoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 5,
            offset: Offset(0, 2),
            spreadRadius: 2,
          ),
        ],
      ),
      onReorder: (reorderFunc) {
        setState(() {
          keys = List.from(reorderFunc(keys));
        });
        updateSetting();
      },
      children: tiles,
      builder: (children) {
        return GridView(
          key: _key,
          controller: scrollController,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 1,
            mainAxisExtent: 48,
          ),
          children: children,
        );
      },
    );

    return PopUpWidgetScaffold(
      title: widget.title,
      tailing: [
        if (keys.length < widget.pages.length)
          IconButton(onPressed: showAddDialog, icon: const Icon(Icons.add)),
      ],
      body: view,
    );
  }

  Widget buildItem(String key) {
    Widget removeButton = Padding(
      padding: const EdgeInsets.only(right: 8),
      child: IconButton(
        onPressed: () {
          setState(() {
            keys.remove(key);
          });
          updateSetting();
        },
        icon: const Icon(Icons.delete),
      ),
    );

    return ListTile(
      title: Text(widget.pages[key] ?? "(Invalid) $key"),
      key: Key(key),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [removeButton, const Icon(Icons.drag_handle)],
      ),
    );
  }

  void showAddDialog() {
    var canAdd = <String, String>{};
    widget.pages.forEach((key, value) {
      if (!keys.contains(key)) {
        canAdd[key] = value;
      }
    });
    showDialog(
      context: context,
      builder: (context) {
          return ContentDialog(
          title: t.add,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: canAdd.entries
                .map(
                  (e) => ListTile(
                    title: Text(e.value),
                    key: Key(e.key),
                    onTap: () {
                      context.pop();
                      setState(() {
                        keys.add(e.key);
                      });
                      updateSetting();
                    },
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }

  void updateSetting() {
    appdata.settings[widget.settingsIndex] = keys;
    appdata.saveData();
  }
}

class _CallbackSetting extends StatelessWidget {
  const _CallbackSetting({
    required this.title,
    required this.callback,
    required this.actionTitle,
    this.subtitle,
  });

  final String title;

  final String? subtitle;

  final VoidCallback callback;

  final String actionTitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: Button.normal(
        onPressed: callback,
        child: Text(actionTitle),
      ).fixHeight(28),
      onTap: callback,
    );
  }
}

class _AnimeSourceCallbackSetting extends StatefulWidget {
  const _AnimeSourceCallbackSetting({
    required this.setting,
    required this.sourceKey,
  });

  final MapEntry<String, Map<String, dynamic>> setting;

  final String sourceKey;

  @override
  State<_AnimeSourceCallbackSetting> createState() =>
      __AnimeSourceCallbackSettingState();
}

class __AnimeSourceCallbackSettingState
    extends State<_AnimeSourceCallbackSetting> {
  String get key => widget.setting.key;

  String get buttonText => widget.setting.value['buttonText'] ?? "Click";

  String get title => widget.setting.value['title'] ?? key;

  bool isLoading = false;

  Future<void> onClick() async {
    var func = widget.setting.value['callback'];
    var result = func([]);
    if (result is Future) {
      setState(() {
        isLoading = true;
      });
      try {
        await result;
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title.ts(widget.sourceKey)),
      trailing: Button.normal(
        onPressed: onClick,
        isLoading: isLoading,
        child: Text(buttonText.ts(widget.sourceKey)),
      ).fixHeight(32),
    );
  }
}

class _SettingPartTitle extends StatelessWidget {
  const _SettingPartTitle({
    required this.title,
    required this.icon,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8, right: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: context.colorScheme.onSurface.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 24),
          const SizedBox(width: 8),
          Text(title, style: ts.s18),
          if (trailing != null) ...[const Spacer(), trailing!],
        ],
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  const _SettingCard({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Material(
        color: context.brightness == Brightness.light
            ? Colors.white.toOpacity(0.72)
            : const Color(0xFF1E1E1E).toOpacity(0.72),
        elevation: 4,
        shadowColor: Theme.of(context).colorScheme.shadow,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [...children, const SizedBox(height: 8)],
        ),
      ),
    );
  }
}

class _BuildSectionPadding extends StatelessWidget {
  const _BuildSectionPadding(this.child, {super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverToBoxAdapter(child: child),
    );
  }
}

class _BindModeSelector extends StatelessWidget {
  final BindMode value;
  final bool enabled;
  final ValueChanged<BindMode> onChanged;

  const _BindModeSelector({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.toOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: BindMode.values.map((mode) {
          final label = switch (mode) {
            BindMode.ipv4 => 'IPv4',
            BindMode.ipv6 => 'IPv6',
            BindMode.both => 'Both',
          };
          final selected = value == mode;
          return GestureDetector(
            onTap: enabled ? () => onChanged(mode) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? colorScheme.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: Colors.black.toOpacity(0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected
                      ? colorScheme.onSurface
                      : colorScheme.onSurface.toOpacity(enabled ? 0.45 : 0.25),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? content; // ← 新增，占满整行的内容区

  const _SettingRow({
    required this.title,
    this.subtitle,
    this.trailing,
    this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.toOpacity(0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (content != null) ...[const SizedBox(height: 8), content!],
        ],
      ),
    );
  }
}
