part of 'image_manipulation_page.dart';

/// 拼接编辑器当前使用的外/内边框样式快照。
///
/// 从各 [StateProvider] 读取，供画笔与预览复用，避免每个页面重复读取 7 个 provider。
@immutable
class CollageBorderStyle {
  const CollageBorderStyle({
    required this.showOuterBorder,
    required this.outerBorderColor,
    required this.outerBorderWidth,
    required this.outerBorderRadius,
    required this.showInnerBorders,
    required this.innerBorderColor,
    required this.innerBorderWidth,
  });

  /// 订阅式读取：边框设置变化时会触发重建（预览用）。
  factory CollageBorderStyle.watch(WidgetRef ref) => CollageBorderStyle(
    showOuterBorder: ref.watch(showOuterBorderProvider),
    outerBorderColor: ref.watch(outerBorderColorProvider),
    outerBorderWidth: ref.watch(outerBorderWidthProvider),
    outerBorderRadius: ref.watch(outerBorderRadiusProvider),
    showInnerBorders: ref.watch(showInnerBordersProvider),
    innerBorderColor: ref.watch(innerBorderColorProvider),
    innerBorderWidth: ref.watch(innerBorderWidthProvider),
  );

  /// 一次性读取（导出用，不需要订阅）。
  factory CollageBorderStyle.read(WidgetRef ref) => CollageBorderStyle(
    showOuterBorder: ref.read(showOuterBorderProvider),
    outerBorderColor: ref.read(outerBorderColorProvider),
    outerBorderWidth: ref.read(outerBorderWidthProvider),
    outerBorderRadius: ref.read(outerBorderRadiusProvider),
    showInnerBorders: ref.read(showInnerBordersProvider),
    innerBorderColor: ref.read(innerBorderColorProvider),
    innerBorderWidth: ref.read(innerBorderWidthProvider),
  );

  final bool showOuterBorder;
  final Color outerBorderColor;
  final double outerBorderWidth;
  final double outerBorderRadius;
  final bool showInnerBorders;
  final Color innerBorderColor;
  final double innerBorderWidth;

  @override
  bool operator ==(Object other) =>
      other is CollageBorderStyle &&
      other.showOuterBorder == showOuterBorder &&
      other.outerBorderColor == outerBorderColor &&
      other.outerBorderWidth == outerBorderWidth &&
      other.outerBorderRadius == outerBorderRadius &&
      other.showInnerBorders == showInnerBorders &&
      other.innerBorderColor == innerBorderColor &&
      other.innerBorderWidth == innerBorderWidth;

  @override
  int get hashCode => Object.hash(
    showOuterBorder,
    outerBorderColor,
    outerBorderWidth,
    outerBorderRadius,
    showInnerBorders,
    innerBorderColor,
    innerBorderWidth,
  );
}

/// 拼接画笔基类：统一持有边框样式与 shouldRepaint 的边框判断。
abstract class CollagePainter extends CustomPainter {
  const CollagePainter({required this.border});

  final CollageBorderStyle border;

  /// 内容（图片、裁剪高度等）是否变化；子类按需覆盖。
  bool contentChanged(covariant CollagePainter oldDelegate) => false;

  @override
  bool shouldRepaint(covariant CollagePainter oldDelegate) =>
      oldDelegate.border != border || contentChanged(oldDelegate);
}

/// 拼接编辑器抽象页。
///
/// 长图 / 横图 / 字幕 / 九宫格等拼接共用同一套骨架：图片解码缓存、排序、删除、
/// 边框设置、预览、导出分享与底部操作栏，差异由子类通过下面几个钩子提供：
/// [title]、[buildPainter]、[computeCanvasSize]，以及可选的
/// [extraEditorActions]、[cropModeActions]、[buildCropBody]。
abstract class CollageEditorPage extends ConsumerStatefulWidget {
  const CollageEditorPage({super.key, required this.images});

  final List<File> images;
}

abstract class CollageEditorState<T extends CollageEditorPage>
    extends ConsumerState<T> {
  late List<File> imageList;
  bool isReorderMode = false;
  bool isCroppingMode = false;

  /// 解码后的图片缓存：避免每次 build 都重新解码（性能关键）
  List<ui.Image>? uiImages;

  final ScrollController scrollController = ScrollController();

  // ───────────────────────── 子类实现 ─────────────────────────

  /// 页面标题。
  String get title;

  /// 根据图片与边框配置构造画笔。
  CustomPainter buildPainter(List<ui.Image> images, CollageBorderStyle border);

  /// 计算导出/预览画布的逻辑尺寸。
  Size computeCanvasSize(List<ui.Image> images, CollageBorderStyle border);

  /// 导出文件名前缀。
  String get exportPrefix => '拼图';

  /// 导出失败提示文案。
  String exportFailureMessage(Object error) =>
      t.saveFailedE(e: error.toString());

  /// 排序列表中单项的外边距。
  EdgeInsets get reorderItemPadding => EdgeInsets.zero;

  /// 普通模式底部栏的额外按钮（插在「排序」与「保存」之间）。
  List<Widget> extraEditorActions() => const [];

  /// 裁剪模式的底部栏按钮；返回 null 表示没有裁剪模式。
  List<Widget>? cropModeActions() => null;

  /// 裁剪模式主体内容。
  Widget buildCropBody() => const SizedBox.shrink();

  /// 叠加在主体之上的额外浮层（如裁剪实时预览）。
  List<Widget> extraOverlayWidgets() => const [];

  /// 预览最大宽度。
  double previewMaxWidth(Size canvasSize) => 650;

  /// 无图片时的提示。
  String get emptyHint => t.failedToLoadImagesOrNoImages;

  /// 图片列表变化后同步子类额外数据（裁剪高度、原图尺寸等）。
  void onImagesChanged() {}

  /// 首帧额外初始化。
  void onInit() {}

  /// 排序后同步子类额外数据，索引已经过规范化。
  void onReorderExtra(int oldIndex, int newIndex) {}

  /// 删除后同步子类额外数据。
  void onRemoveExtra(int index) {}

  // ───────────────────────── 生命周期 ─────────────────────────

  @override
  void initState() {
    super.initState();
    imageList = List.of(widget.images);
    onInit();
    ensureImages().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  Future<List<ui.Image>> loadUiImages() async {
    final result = <ui.Image>[];
    for (final file in imageList) {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      result.add(frame.image);
    }
    return result;
  }

  Future<List<ui.Image>> ensureImages() async =>
      uiImages ??= await loadUiImages();

  void onReorder(int oldIndex, int newIndex) {
    final normalized = oldIndex < newIndex ? newIndex - 1 : newIndex;
    setState(() {
      imageList.insert(normalized, imageList.removeAt(oldIndex));
      final images = uiImages;
      if (images != null) {
        images.insert(normalized, images.removeAt(oldIndex));
      }
      onReorderExtra(oldIndex, normalized);
    });
  }

  void removeImage(int index) {
    if (index < 0 || index >= imageList.length) return;
    setState(() {
      imageList.removeAt(index);
      uiImages?.removeAt(index);
      onRemoveExtra(index);
    });
  }

  void showBorderSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const BorderSettingsSheet(),
    );
  }

  // ───────────────────────── 导出 / 分享 ─────────────────────────

  bool get inEditorMode => isReorderMode || isCroppingMode;

  void exitEditorMode() => setState(() {
    isReorderMode = false;
    isCroppingMode = false;
  });

  Future<Uint8List?> renderBytes(BuildContext context) async {
    final border = CollageBorderStyle.read(ref);
    final images = await ensureImages();
    if (images.isEmpty || !context.mounted) return null;
    return composePainterToPng(
      painter: buildPainter(images, border),
      size: computeCanvasSize(images, border),
      dpr: MediaQuery.devicePixelRatioOf(context),
    );
  }

  Future<void> exportCollage() async {
    await ImageExporter.run(
      context,
      filename: '${exportPrefix}_${DateTime.now().millisecondsSinceEpoch}',
      generate: ImageExporter.bytes(() => renderBytes(context)),
      generatingMessage: t.generating,
      failureMessageBuilder: exportFailureMessage,
    );
    await ref.read(imagesProvider.notifier).loadImages();
  }

  // ───────────────────────── 共用 UI ─────────────────────────

  Widget buildReorderView() {
    return ReorderableListView(
      onReorderItem: onReorder,
      buildDefaultDragHandles: false,
      scrollController: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        for (int i = 0; i < imageList.length; i++)
          ReorderableDragStartListener(
            key: ValueKey(imageList[i].path),
            index: i,
            child: Padding(
              padding: reorderItemPadding,
              child: Stack(
                children: [
                  Image.file(imageList[i], fit: BoxFit.fitWidth),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => removeImage(i),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget buildMainCanvasPreview() {
    final border = CollageBorderStyle.watch(ref);
    final images = uiImages;
    if (images == null) {
      return const Center(child: PolygonRefreshIndicator());
    }
    if (images.isEmpty) {
      return Center(child: Text(emptyHint));
    }
    final size = computeCanvasSize(images, border);
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: previewMaxWidth(size)),
          child: FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: CustomPaint(
                size: size,
                painter: buildPainter(images, border),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 底部条形按钮（分段胶囊外观）。
  Widget buildCapsuleAction({
    required IconData icon,
    required String label,
    VoidCallback? onPressed,
    bool primary = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return CapsuleButton(
      flat: !primary,
      primary: primary,
      leading: Icon(icon, size: 16),
      text: label,
      enabled: onPressed != null,
      onTap: onPressed ?? () {},
      color: primary ? null : Colors.white.toOpacity(0.15),
      fgColor: primary ? null : cs.onSurface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget buildBottomButtons() {
    final actions = <Widget>[];
    if (isReorderMode) {
      actions.add(
        buildCapsuleAction(
          icon: Icons.check,
          label: t.finishSorting,
          primary: true,
          onPressed: () => setState(() => isReorderMode = false),
        ),
      );
    } else if (isCroppingMode) {
      actions.addAll(cropModeActions() ?? const []);
    } else {
      actions.add(
        buildCapsuleAction(
          icon: Icons.color_lens,
          label: t.borderColor,
          onPressed: showBorderSettings,
        ),
      );
      actions.add(
        buildCapsuleAction(
          icon: Icons.sort,
          label: t.sortImages,
          onPressed: () => setState(() => isReorderMode = true),
        ),
      );
      actions.addAll(extraEditorActions());
      actions.add(
        buildCapsuleAction(
          icon: Icons.save_alt,
          label: t.saveAndShare,
          primary: true,
          onPressed: exportCollage,
        ),
      );
    }
    return FrostedBottomBar(
      child: CapsuleButtonBar(
        alignment: WrapAlignment.center,
        children: actions,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !inEditorMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && inEditorMode) exitEditorMode();
      },
      child: Scaffold(
        appBar: Appbar(
          title: Text(title),
          backgroundColor: Colors.transparent,
          leading: _ModeAwareBackButton(
            editorMode: inEditorMode,
            onExitMode: exitEditorMode,
          ),
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: Center(
                child: isReorderMode
                    ? ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 650),
                        child: buildReorderView(),
                      )
                    : isCroppingMode
                    ? ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 650),
                        child: buildCropBody(),
                      )
                    : buildMainCanvasPreview(),
              ),
            ),
            buildBottomButtons(),
            ...extraOverlayWidgets(),
          ],
        ),
      ),
    );
  }
}
