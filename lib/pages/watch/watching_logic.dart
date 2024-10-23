part of kostori_watcher;

class AnimeWatchingLogic extends StateController {
  String? errorMessage;

  bool isLoading = true;

  AnimeWatchingLogic(
      this.order, this.data, int initialPlaying, this.updateHistory) {
    if (initialPlaying <= 0) {
      initialPlaying = 1;
    }
    order <= 0 ? order = 1 : order;
  }

  final void Function() updateHistory;

  WatchingData data;

  var focusNode = FocusNode();

  ///当前的页面, 0和最后一个为空白页, 用于进行章节跳转
  late int _index;

  ///当前的页面, 0和最后一个为空白页, 用于进行章节跳转
  int get index => _index;

  set index(int value) {
    _index = value;
    for (var element in _indexChangeCallbacks) {
      element(value);
    }
    updateHistory();
  }

  final _indexChangeCallbacks = <void Function(int)>[];

  void addIndexChangeCallback(void Function(int) callback) {
    _indexChangeCallbacks.add(callback);
  }

  void removeIndexChangeCallback(void Function(int) callback) {
    _indexChangeCallbacks.remove(callback);
  }

  ///当前的章节位置, 从1开始
  int order;

  ///重载
  void reload() {
    index = 1;
    // pageController = PageController(initialPage: 1);
    isLoading = true;
    update();
  }

  ///刷新状态改变
  void change() {
    isLoading = !isLoading;
    update();
  }

  ///下一集
  void jumpToNextChapter() {
    var eps = data.eps;
    if (!data.hasEp || order == eps?.length) {
      /// 还没想好的下一集的视频播放地址

      return;
    }
    order += 1;
    isLoading = true;
    index = 1;
    update();
  }

  ///上一集
  void jumpToLastChapter() {
    if (order == 1 || !data.hasEp) {
      ///还没想好的上一集的视频播放地址
      return;
    }

    order -= 1;
    isLoading = true;
    index = 1;
    update();
  }

  bool isFullScreen = false;

  ///控制全屏
  void fullscreen() {
    const channel = MethodChannel("kostori/full_screen");
    channel.invokeMethod("set", !isFullScreen);
    isFullScreen = !isFullScreen;
    focusNode.requestFocus();

    if (isFullScreen) {
      StateController.find<WindowFrameController>().hideWindowFrame();
    } else {
      StateController.find<WindowFrameController>().showWindowFrame();
    }
  }

  ///键位控制
  void handleKeyboard(KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.arrowDown:
        case LogicalKeyboardKey.arrowUp:
        case LogicalKeyboardKey.f12:
          fullscreen();
      }
    }
  }
}
