import 'package:kostori/foundation/appdata.dart';

const String kPlayerPanelHideDelayKey = 'playerPanelHideDelaySeconds';
const int kDefaultPlayerPanelHideDelaySeconds = 4;
const int kMaxPlayerPanelHideDelaySeconds = 30;

int get playerPanelHideDelaySeconds {
  final value = appdata.implicitData[kPlayerPanelHideDelayKey];
  if (value is num) {
    return value.round().clamp(0, kMaxPlayerPanelHideDelaySeconds).toInt();
  }
  return kDefaultPlayerPanelHideDelaySeconds;
}
