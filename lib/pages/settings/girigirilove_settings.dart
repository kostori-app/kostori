part of kostori_settings;

class GiriGiriLoveSettings extends StatefulWidget {
  const GiriGiriLoveSettings(this.popUp, {Key? key}) : super(key: key);
  final bool popUp;

  @override
  State<GiriGiriLoveSettings> createState() => _GiriGiriLoveSettingsState();
}

class _GiriGiriLoveSettingsState extends State<GiriGiriLoveSettings> {
  // bool showFrame = appdata.settings[5] == "1";
  // bool punchIn = appdata.settings[6] == "1";
  // bool useMyServer = appdata.settings[3] == "1";

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ListTile(
        title: Text("girigirilove"),
      ),
    ]);
  }
}
