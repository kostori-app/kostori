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
        SliverAppbar(title: Text("Player".tl)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverToBoxAdapter(
            child: _SettingCard(
              children: [
                _SettingPartTitle(
                  title: "Player".tl,
                  icon: Icons.radio_button_unchecked_outlined,
                ),
                _SwitchSetting(
                  title: "Audio Option".tl,
                  settingKey: "audioOutType",
                ),
                _SwitchSetting(
                  title: "Hardware Decoding".tl,
                  settingKey: "hAenable",
                ),
                _CallbackSetting(
                  title: "Hardware decoder".tl,
                  actionTitle: 'Set'.tl,
                  callback: () async {
                    showSelection(
                      context: context,
                      title: "Hardware decoder".tl,
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
                  title: "Video renderer".tl,
                  actionTitle: 'Set'.tl,
                  callback: () async {
                    showSelection(
                      context: context,
                      title: "Video renderer".tl,
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
                  title: "Video synchronization mode".tl,
                  actionTitle: 'Set'.tl,
                  callback: () async {
                    showSelection(
                      context: context,
                      title: "Video synchronization mode".tl,
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
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> showSelection({
  required BuildContext context,
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
                    leading: Radio<String>(value: entry.key),
                    title: Text(entry.value),
                    subtitle: Text(entry.key),
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
