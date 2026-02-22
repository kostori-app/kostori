// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/animation.dart';
import 'package:mobx/mobx.dart';

part 'explore_controller.g.dart';

class ExploreController = _ExploreController with _$ExploreController;

abstract class _ExploreController with Store {
  @observable
  bool showFB = false;

  late AnimationController controller;
  late Animation<double> fadeAnimation;

  void initController(TickerProvider vsync) {
    controller = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 300),
    );
    fadeAnimation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOut,
    );
  }

  void show() {
    showFB = true;
    controller.forward();
  }

  void hide() {
    showFB = false;
    controller.reverse();
  }

  void dispose() {
    controller.dispose();
  }
}
