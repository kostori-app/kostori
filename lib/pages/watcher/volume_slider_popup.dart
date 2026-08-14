import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/pages/watcher/player_controller.dart';

/// 在指定位置弹出音量调节滑条（仅桌面端）。
/// 滑条范围联动音量增益：开启增益时上限为 200，否则为 100。
Future<void> showVolumeSliderPopup(
  BuildContext context,
  Offset location,
  PlayerController playerController,
) {
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push(_VolumeSliderRoute(location, playerController));
}

class _VolumeSliderRoute<T> extends PopupRoute<T> {
  final Offset location;
  final PlayerController playerController;

  _VolumeSliderRoute(this.location, this.playerController);

  @override
  Color? get barrierColor => Colors.transparent;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => "volume_slider";

  @override
  Duration get transitionDuration => const Duration(milliseconds: 160);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    const width = 280.0;
    const height = 64.0;
    final size = MediaQuery.of(context).size;
    var left = location.dx;
    if (left + width > size.width - 12) {
      left = size.width - width - 12;
    }
    if (left < 12) left = 12;
    // 优先出现在按钮上方，空间不足时放到下方
    var top = location.dy - height - 8;
    if (top < 12) {
      top = location.dy + 48 + 8;
    }
    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          child: _VolumeSliderPanel(playerController: playerController),
        ),
      ],
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: animation.drive(
        Tween<double>(begin: 0, end: 1).chain(CurveTween(curve: Curves.ease)),
      ),
      child: child,
    );
  }
}

class _VolumeSliderPanel extends StatefulWidget {
  const _VolumeSliderPanel({required this.playerController});

  final PlayerController playerController;

  @override
  State<_VolumeSliderPanel> createState() => _VolumeSliderPanelState();
}

class _VolumeSliderPanelState extends State<_VolumeSliderPanel> {
  double _lastVolume = 50;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Observer(
      builder: (context) {
        final upper = widget.playerController.volumeUpperBound;
        final volume = widget.playerController.volume.clamp(0.0, upper);
        final icon = volume <= 0
            ? Icons.volume_off_rounded
            : volume < upper * 0.5
            ? Icons.volume_down_rounded
            : Icons.volume_up_rounded;
        return Container(
          width: 280,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: context.brightness == Brightness.dark
                ? Border.all(color: cs.outlineVariant)
                : null,
            boxShadow: [
              BoxShadow(
                color: cs.shadow.toOpacity(0.22),
                blurRadius: 10,
                blurStyle: BlurStyle.outer,
              ),
            ],
          ),
          child: BlurEffect(
            borderRadius: BorderRadius.circular(14),
            child: Material(
              color: cs.surface.toOpacity(0.85),
              borderRadius: BorderRadius.circular(14),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(icon, size: 20),
                    tooltip: volume <= 0 ? 'Unmute' : 'Mute',
                    onPressed: () {
                      if (volume > 0) {
                        _lastVolume = volume;
                        widget.playerController.setVolume(0);
                      } else {
                        widget.playerController.setVolume(
                          _lastVolume > 0 ? _lastVolume : upper * 0.5,
                        );
                      }
                    },
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 7,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 14,
                        ),
                      ),
                      child: Slider(
                        value: volume,
                        min: 0,
                        max: upper,
                        onChanged: (v) {
                          if (v > 0) _lastVolume = v;
                          widget.playerController.setVolume(v);
                        },
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(
                      '${volume.round()}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
