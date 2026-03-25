part of 'settings_page.dart';

class PlayerSettings extends StatefulWidget {
  const PlayerSettings({super.key});

  @override
  State<PlayerSettings> createState() => _PlayerSettingsState();
}

class _PlayerSettingsState extends State<PlayerSettings> {
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
                  settingKey: "hAenable",
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
