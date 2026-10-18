import 'package:kostori/foundation/appdata.dart';

const String kPlayerPanelHideDelayKey = 'playerPanelHideDelaySeconds';
const int kDefaultPlayerPanelHideDelaySeconds = 4;
const int kMaxPlayerPanelHideDelaySeconds = 30;

const String kPlayerSeekMultiplierKey = 'playerSeekMultiplier';
const double kDefaultPlayerSeekMultiplier = 1.0;
const double kMinPlayerSeekMultiplier = 0.5;
const double kMaxPlayerSeekMultiplier = 2.5;

int get playerPanelHideDelaySeconds {
  final value = appdata.implicitData[kPlayerPanelHideDelayKey];
  if (value is num) {
    return value.round().clamp(0, kMaxPlayerPanelHideDelaySeconds).toInt();
  }
  return kDefaultPlayerPanelHideDelaySeconds;
}

double get playerSeekMultiplier {
  final value = appdata.implicitData[kPlayerSeekMultiplierKey];
  if (value is num) {
    return value.toDouble().clamp(
      kMinPlayerSeekMultiplier,
      kMaxPlayerSeekMultiplier,
    );
  }
  return kDefaultPlayerSeekMultiplier;
}
