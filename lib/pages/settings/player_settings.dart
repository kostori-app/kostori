part of 'settings_page.dart';

class PlayerSettings extends StatefulWidget {
  const PlayerSettings({super.key});

  @override
  State<PlayerSettings> createState() => _PlayerSettingsState();
}

class _PlayerSettingsState extends State<PlayerSettings> {
  String? _playerLoadingImage() {
    final v = appdata.implicitData['playerLoadingImage'];
    return v is String && v.isNotEmpty ? v : null;
  }

  bool _hasPlayerLoadingImage() => _playerLoadingImage() != null;

  String _playerLoadingImageSubtitle() {
    final v = _playerLoadingImage();
    if (v == null) return t.notSet;
    if (v.startsWith('data:')) return 'base64 · ${v.length ~/ 1024} KB';
    if (v.startsWith('assets/')) return v;
    if (v.startsWith('file://')) return v.split('/').last;
    return v.length > 40 ? '${v.substring(0, 40)}…' : v;
  }

  Future<void> _showPlayerLoadingImageDialog() async {
    if (_hasPlayerLoadingImage()) {
      // 已设置：清除
      showConfirmDialog(
        context: context,
        title: t.playerLoadingImage,
        content: t.reset,
        onConfirm: () {
          appdata.implicitData.remove('playerLoadingImage');
          appdata.writeImplicitData();
          if (mounted) setState(() {});
        },
      );
      return;
    }
    // 未设置：输入图片路径/URL/data
    await showInputDialog(
      context: context,
      title: t.playerLoadingImage,
      hintText: t.inputImagePath,
      confirmText: t.confirm,
      cancelText: t.cancel,
      onConfirm: (value) {
        final v = value.toString().trim();
        if (v.isEmpty) return null;
        appdata.implicitData['playerLoadingImage'] = v;
        appdata.writeImplicitData();
        if (mounted) setState(() {});
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SmoothCustomScrollView(
      slivers: [
        SliverAppbar(title: Text(t.player)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverToBoxAdapter(
            child: _SettingCard(
              children: [
                _SettingPartTitle(
                  title: t.player,
                  icon: Icons.radio_button_unchecked_outlined,
                ),
                _SwitchSetting(
                  title: t.audioOption,
                  settingKey: "audioOutType",
                ),
                _SwitchSetting(
                  title: t.hardwareDecoding,
                  settingKey: "haEnable",
                ),
                _CallbackSetting(
                  title: t.hardwareDecoder,
                  actionTitle: t.set,
                  callback: () async {
                    showSelection(
                      title: t.hardwareDecoder,
                      options: hardwareDecodersList,
                      currentValue: appdata.settings['hardwareDecoder'],
                      onChanged: (result) {
                        appdata.settings['hardwareDecoder'] = result;
                        appdata.saveData();
                      },
                    );
                  },
                ),
                _CallbackSetting(
                  title: t.videoRenderer,
                  actionTitle: t.set,
                  callback: () async {
                    showSelection(
                      title: t.videoRenderer,
                      options: androidVideoRenderersList,
                      currentValue: appdata.settings['androidVideoRenderer'],
                      onChanged: (result) {
                        appdata.settings['androidVideoRenderer'] = result;
                        appdata.saveData();
                      },
                    );
                  },
                ),
                _CallbackSetting(
                  title: t.videoSynchronizationMode,
                  actionTitle: t.set,
                  callback: () async {
                    showSelection(
                      title: t.videoSynchronizationMode,
                      options: videoSynchronizationModeList,
                      currentValue:
                          appdata.settings['videoSynchronizationMode'],
                      onChanged: (result) {
                        appdata.settings['videoSynchronizationMode'] = result;
                        appdata.saveData();
                      },
                    );
                  },
                ),
                _CallbackSetting(
                  title: t.playerLoadingImage,
                  subtitle: _playerLoadingImageSubtitle(),
                  actionTitle: _hasPlayerLoadingImage() ? t.reset : t.set,
                  callback: _showPlayerLoadingImageDialog,
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
                _SettingPartTitle(
                  title: t.m3u8AdFilter,
                  icon: Icons.filter_alt_outlined,
                ),
                _SwitchSetting(
                  title: t.enableAdFilter,
                  settingKey: 'm3u8AdFilterEnabled',
                ),
                _CallbackSetting(
                  title: t.filterRules,
                  actionTitle: t.manage,
                  callback: () {
                    showPopUpWidget(App.rootContext, const M3u8RulesPage());
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

Future<void> showSelection({
  required String title,
  required Map<String, String> options,
  required String currentValue,
  required void Function(String value) onChanged,
}) async {
  String selectedValue = currentValue;

  showPopUpWidget(
    App.rootContext,
    StatefulBuilder(
      builder: (context, setState) {
        final entries = options.entries.toList();

        return PopUpWidgetScaffold(
          title: title,
          body: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: RadioGroup<String>(
              groupValue: selectedValue,
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  selectedValue = value;
                });

                onChanged(value);
              },
              child: ListView(
                shrinkWrap: true,
                children: entries.map((entry) {
                  return ListTile(
                    title: Text(entry.key),
                    subtitle: Text(entry.value),
                    trailing: Radio<String>(value: entry.key),
                    onTap: () {
                      setState(() {
                        selectedValue = entry.key;
                      });

                      onChanged(entry.key);
                    },
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class M3u8RulesPage extends StatefulWidget {
  const M3u8RulesPage({super.key});

  @override
  State<M3u8RulesPage> createState() => _M3u8RulesPageState();
}

class _M3u8RulesPageState extends State<M3u8RulesPage> {
  late List<M3u8AdRule> rules;

  @override
  void initState() {
    super.initState();
    rules = M3u8AdRuleStore.rules;
  }

  void _save() {
    M3u8AdRuleStore.save(rules);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return PopUpWidgetScaffold(
      title: t.adFilterRules,
      tailing: [
        IconButton(icon: const Icon(Icons.add), onPressed: _showAddDialog),
      ],
      body: ListView.builder(
        itemCount: rules.length,
        itemBuilder: (context, i) {
          return Column(
            children: [
              ListTile(
                title: Text(rules[i].name),
                subtitle: Text(_ruleSubtitle(rules[i])),
                leading: CustomSwitch(
                  value: rules[i].enabled,
                  onChanged: (v) {
                    rules[i] = M3u8AdRule(
                      name: rules[i].name,
                      type: rules[i].type,
                      enabled: v,
                      pattern: rules[i].pattern,
                      blockedDomains: rules[i].blockedDomains,
                      maxDuration: rules[i].maxDuration,
                      tag: rules[i].tag,
                      caseSensitive: rules[i].caseSensitive,
                    );
                    _save();
                  },
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () {
                    rules.removeAt(i);
                    _save();
                  },
                ),
              ),
              if (i < rules.length - 1) const Divider(height: 1, indent: 16),
            ],
          );
        },
      ),
    );
  }

  String _ruleSubtitle(M3u8AdRule rule) => switch (rule.type) {
    M3u8RuleType.urlPattern => '${t.urlRegex}: ${rule.pattern}',
    M3u8RuleType.keyword => '${t.keywordMatch}: ${rule.pattern}',
    M3u8RuleType.domainBlock =>
      '${t.domainBlock}: ${rule.blockedDomains?.join(', ')}',
    M3u8RuleType.maxDuration => '${t.durationFilter} < ${rule.maxDuration}s',
    M3u8RuleType.tagPresent => '${t.tagMark}: ${rule.tag}',
  };

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    var selectedType = M3u8RuleType.urlPattern;

    ContentDialog.show(
      context: context,
      title: t.addRule,
      content: StatefulBuilder(
        builder: (context, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(labelText: t.ruleName),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: M3u8RuleType.values.map((type) {
                return FilterChip(
                  label: Text(_typeName(type)),
                  selected: selectedType == type,
                  onSelected: (_) => setState(() => selectedType = type),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: valueCtrl,
              decoration: InputDecoration(labelText: _typeHint(selectedType)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (nameCtrl.text.isEmpty || valueCtrl.text.isEmpty) return;
            rules.add(
              M3u8AdRule(
                name: nameCtrl.text,
                type: selectedType,
                pattern:
                    selectedType == M3u8RuleType.urlPattern ||
                        selectedType == M3u8RuleType.keyword
                    ? valueCtrl.text
                    : null,
                blockedDomains: selectedType == M3u8RuleType.domainBlock
                    ? valueCtrl.text.split(',').map((s) => s.trim()).toList()
                    : null,
                maxDuration: selectedType == M3u8RuleType.maxDuration
                    ? double.tryParse(valueCtrl.text)
                    : null,
                tag: selectedType == M3u8RuleType.tagPresent
                    ? valueCtrl.text
                    : null,
              ),
            );
            _save();
            App.rootContext.pop();
          },
          child: Text(t.add),
        ),
      ],
    );
  }

  String _typeName(M3u8RuleType type) => switch (type) {
    M3u8RuleType.urlPattern => t.urlRegex,
    M3u8RuleType.keyword => t.keywordMatch,
    M3u8RuleType.domainBlock => t.domainBlock,
    M3u8RuleType.maxDuration => t.durationFilter,
    M3u8RuleType.tagPresent => t.tagMark,
  };

  String _typeHint(M3u8RuleType type) => switch (type) {
    M3u8RuleType.urlPattern => t.regexHint,
    M3u8RuleType.keyword => t.keywordHint,
    M3u8RuleType.domainBlock => t.domainHint,
    M3u8RuleType.maxDuration => t.durationHint,
    M3u8RuleType.tagPresent => t.tagHint,
  };
}
