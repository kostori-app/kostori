import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:kostori/pages/watcher/player_controller.dart';

class PlayerItemPanel extends StatefulWidget {
  const PlayerItemPanel({super.key, required this.playerController});

  final PlayerController playerController;

  @override
  State<PlayerItemPanel> createState() => _PlayerItemPanelState();
}

class _PlayerItemPanelState extends State<PlayerItemPanel> {
  late bool haEnable;
  late Animation<Offset> topOffsetAnimation;
  late Animation<Offset> bottomOffsetAnimation;
  late Animation<Offset> leftOffsetAnimation;
  final TextEditingController textController = TextEditingController();
  final FocusNode textFieldFocus = FocusNode();

  @override
  Widget build(BuildContext context) {
    return Observer(builder: (context) {
      return Stack(alignment: Alignment.center, children: []);
    });
  }
}
