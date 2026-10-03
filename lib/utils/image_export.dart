import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/foundation/offscreen_host.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/utils/io.dart';

/// 图片导出的进度回报器。
///
/// 框架只依赖这个接口，与具体界面解耦：GUI 下转发到加载弹窗
/// （见 [LoadingImageExportReporter]），无头 / 无界面场景退化为日志
/// （见 [SilentImageExportReporter]）。
abstract class ImageExportReporter {
  const ImageExportReporter();

  /// 更新提示文案。
  void message(String text);

  /// 生成阶段进度；[total] 为 1 时无进度可报。
  void progress(int done, int total);
}

/// GUI 环境：把进度转发到 [LoadingDialogController]。
class LoadingImageExportReporter implements ImageExportReporter {
  const LoadingImageExportReporter(this._controller);

  final LoadingDialogController _controller;

  @override
  void message(String text) => _controller.setMessage(text);

  @override
  void progress(int done, int total) {
    if (total <= 1) return;
    _controller.setProgress(done / total);
    _controller.setMessage(
      t.screenshotGeneratingProgress(current: done, total: total),
    );
  }
}

/// 无头 / 无界面环境：进度只写日志，不触碰任何 widget。
class SilentImageExportReporter implements ImageExportReporter {
  const SilentImageExportReporter();

  @override
  void message(String text) => Log.info('图片导出', text);

  @override
  void progress(int done, int total) {
    if (total <= 1) return;
    Log.info(
      '图片导出',
      t.screenshotGeneratingProgress(current: done, total: total),
    );
  }
}

/// 图片生成器：接收进度回报，产出 1~N 张图片字节。
typedef ImageExportGenerator = Future<List<Uint8List>> Function(
  ImageExportReporter reporter,
);

/// 截图所需的渲染宿主：可插入 [OverlayEntry] 的 Overlay、宿主上下文与配色。
///
/// 界面内截图与无头截图的差异被收敛到这里，[ImageExporter] 的其余部分不再
/// 需要关心自己跑在 GUI 还是无头模式。
class ImageCaptureHost {
  const ImageCaptureHost._({
    required this.context,
    required this.overlay,
    required this.theme,
    required this.mediaQuery,
    required this.offscreen,
  });

  /// 宿主上下文，用于 [precacheImage] 等需要上下文的 API。
  final BuildContext context;

  /// 承载离屏渲染的 Overlay。
  final OverlayState overlay;

  /// 截图使用的配色。
  final ThemeData theme;

  /// 截图使用的屏幕信息；无头模式下来自离屏宿主的固定尺寸。
  final MediaQueryData mediaQuery;

  /// 是否来自无头离屏宿主（[OffscreenHost]）。
  final bool offscreen;

  /// 解析当前可用的渲染宿主，全部拿不到时返回 null。
  ///
  /// 优先级：显式传入的 [overlay] → [context] 所在的 [OverlayWidget] →
  /// GUI 根导航器的 Overlay → 无头离屏宿主（必要时自动 [OffscreenHost.attach]）。
  ///
  /// 只有确认处于无头模式（没有 runApp）时才会挂载离屏宿主，
  /// 避免在 GUI 里覆盖掉应用根 widget。
  static ImageCaptureHost? resolve({
    BuildContext? context,
    OverlayState? overlay,
    ThemeData? themeOverride,
    Brightness? brightness,
  }) {
    if (context != null && context.mounted) {
      final stateOverlay =
          overlay ??
          context
              .findAncestorStateOfType<OverlayWidgetState>()
              ?.overlayKey
              .currentState ??
          Navigator.maybeOf(context)?.overlay;
      final theme = themeOverride ?? _themeOf(context);
      if (stateOverlay != null && stateOverlay.mounted && theme != null) {
        return ImageCaptureHost._(
          context: context,
          overlay: stateOverlay,
          theme: theme,
          mediaQuery: _tuned(_mediaQueryOf(context), theme, themeOverride),
          offscreen: false,
        );
      }
    }

    // 已经 runApp（GUI）却没拿到宿主：属于调用方问题，不能再去挂离屏树
    if (App.rootNavigatorKey.currentContext != null) return null;

    // 无头模式：回退到离屏宿主
    final host = OffscreenHost.instance;
    if (!host.attached) {
      host.attach(brightness: themeOverride?.brightness ?? brightness);
    }
    final offscreenContext = host.context;
    final offscreenOverlay = host.overlay;
    if (offscreenContext == null || offscreenOverlay == null) return null;
    final theme = themeOverride ?? host.theme;
    return ImageCaptureHost._(
      context: offscreenContext,
      overlay: offscreenOverlay,
      theme: theme,
      mediaQuery: _tuned(_mediaQueryOf(offscreenContext), theme, themeOverride),
      offscreen: true,
    );
  }

  /// 配色被覆盖时同步 MediaQuery 的明暗，否则依赖 [MediaQuery.platformBrightnessOf]
  /// 的组件（如分享卡片外框）会和主题对不上。
  static MediaQueryData _tuned(
    MediaQueryData data,
    ThemeData theme,
    ThemeData? themeOverride,
  ) {
    if (themeOverride == null) return data;
    return data.copyWith(platformBrightness: theme.brightness);
  }

  static ThemeData? _themeOf(BuildContext context) {
    try {
      return Theme.of(context);
    } catch (_) {
      return null;
    }
  }

  static MediaQueryData _mediaQueryOf(BuildContext context) {
    try {
      return MediaQuery.of(context);
    } catch (_) {
      return const MediaQueryData(size: Size(800, 600), devicePixelRatio: 1);
    }
  }
}

/// 图片导出的统一框架。
///
/// 把「生成图片 → 保存 / 分享 → 结果提示」拆成三层，各页面只需要提供一个
/// [ImageExportGenerator]：
///
/// 1. **生成**：离屏渲染任意 Widget（[ImageExporter.offscreen]，GUI 与无头通用）、
///    截取界面上已有的 [TileableRepaintBoundary]（[ImageExporter.repaintBoundary]）、
///    直接用 [CustomPainter] 绘制（[ImageExporter.painter]）、
///    或已有字节（[ImageExporter.bytes]）。
/// 2. **收尾**：超长内容纵向切分、逐张编码、像素比失败降级重试、
///    网络图预热与稳定等待，全部由框架处理。
/// 3. **交付**：[ImageExporter.run] 自动区分 GUI 与无头——GUI 下弹进度窗并
///    存文件 / 复制剪贴板 / 分享，无头下只落盘并记日志。
abstract final class ImageExporter {
  /// 默认输出像素比。
  static const double targetPixelRatio = 2.0;

  /// 单张图片允许的最大像素边长；超过则切成多张。
  ///
  /// 超过这个尺寸不只是 GPU 最大纹理（约 4096~16384）的问题：
  /// 微信 / Twitter 等第三方 App 对超长图会压缩、缩放甚至拒绝。
  static const double maxSinglePixel = 4096.0;

  /// 离屏渲染的默认逻辑宽度。
  static const double defaultWidth = 800.0;

  /// 等待离屏子树渲染稳定的最长时间。
  static const Duration settleTimeout = Duration(seconds: 20);

  /// 生成并保存 / 分享图片，返回是否成功。
  ///
  /// [context] 为 null 或已卸载时按无头模式处理：直接执行生成器并落盘，
  /// 不弹窗、不复制剪贴板、不拉起分享面板。
  ///
  /// [share] 为 false 时只写入图片目录并提示，适合「保存」语义的按钮。
  static Future<bool> run(
    BuildContext? context, {
    required String filename,
    required ImageExportGenerator generate,
    bool share = true,
    String? generatingMessage,
    String? savingMessage,
    String? desktopSuccessMessage,
    String? mobileSuccessMessage,
    String? failureMessage,
    String Function(Object error)? failureMessageBuilder,
  }) {
    String failMessage(Object e) =>
        failureMessageBuilder?.call(e) ?? failureMessage ?? t.screenshotFailed;

    Future<bool> task(
      ImageExportReporter reporter, {
      void Function()? onSaved,
    }) async {
      reporter.message(generatingMessage ?? t.calGeneratingScreenshot);

      List<Uint8List> bytes;
      try {
        bytes = await generate(reporter);
      } catch (e, s) {
        Log.error('导出失败', '$e\n$s');
        ImageSaver.showResult(success: false, message: failMessage(e));
        return false;
      }

      if (bytes.isEmpty) return false;

      final names = [
        for (var i = 0; i < bytes.length; i++)
          bytes.length == 1 ? '$filename.png' : '${filename}_${i + 1}.png',
      ];

      reporter.message(savingMessage ?? t.savingImage);

      try {
        await ImageSaver.saveOrShareImages(
          bytes: bytes,
          filenames: names,
          share: share,
          headless: onSaved == null,
          desktopSuccessMessage: desktopSuccessMessage,
          mobileSuccessMessage: mobileSuccessMessage,
          onProgress: reporter.progress,
          onSaved: onSaved,
        );
      } catch (e, s) {
        Log.error('保存失败', '$e\n$s');
        ImageSaver.showResult(success: false, message: failMessage(e));
        return false;
      }
      return true;
    }

    if (context == null || !context.mounted) {
      return task(const SilentImageExportReporter());
    }

    return runWithLoadingDialog<bool>(
      context,
      message: generatingMessage ?? t.calGeneratingScreenshot,
      task: (loading) =>
          task(LoadingImageExportReporter(loading), onSaved: loading.close),
    );
  }

  /// 离屏渲染任意 [Widget]（GUI 与无头通用）。
  ///
  /// 框架自动完成：解析渲染宿主、包裹 MediaQuery/Theme/正文样式、
  /// 预热网络图并等待渲染稳定、超长内容纵向切分。
  static ImageExportGenerator offscreen({
    required Widget child,
    BuildContext? context,
    OverlayState? overlay,
    ThemeData? themeOverride,
    Brightness? brightness,
    double width = defaultWidth,
    double pixelRatio = targetPixelRatio,
    double maxPixel = maxSinglePixel,
    List<ImageProvider> imageProviders = const [],
    Duration timeout = settleTimeout,
    TextStyle? textStyle,
    bool Function()? readyWhen,
  }) {
    return (reporter) async {
      final host = ImageCaptureHost.resolve(
        context: context,
        overlay: overlay,
        themeOverride: themeOverride,
        brightness: brightness,
      );
      if (host == null) {
        throw StateError('no image capture host available');
      }
      return captureWidget(
        host: host,
        child: child,
        width: width,
        pixelRatio: pixelRatio,
        maxPixel: maxPixel,
        imageProviders: imageProviders,
        timeout: timeout,
        textStyle: textStyle,
        readyWhen: readyWhen,
        reporter: reporter,
      );
    };
  }

  /// 核心原语：把 [child] 渲染进 [host] 的离屏容器并抓帧。
  static Future<List<Uint8List>> captureWidget({
    required ImageCaptureHost host,
    required Widget child,
    double width = defaultWidth,
    double pixelRatio = targetPixelRatio,
    double maxPixel = maxSinglePixel,
    List<ImageProvider> imageProviders = const [],
    Duration timeout = settleTimeout,
    TextStyle? textStyle,
    bool Function()? readyWhen,
    ImageExportReporter? reporter,
  }) async {
    final boundaryKey = GlobalKey();

    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -10000,
        child: SizedBox(
          width: width,
          child: TileableRepaintBoundary(
            key: boundaryKey,
            child: MediaQuery(
              data: host.mediaQuery,
              child: Theme(
                data: host.theme,
                child: DefaultTextStyle(
                  // 离屏渲染拿不到宿主的正文样式，这里显式给一个，保证文字可见
                  style:
                      textStyle ??
                      TextStyle(
                        color: host.theme.colorScheme.onSurface,
                        fontSize: 13,
                      ),
                  child: Material(child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    host.overlay.insert(entry);

    try {
      await _settle(
        boundaryKey: boundaryKey,
        context: host.context,
        extraProviders: imageProviders,
        timeout: timeout,
        readyWhen: readyWhen,
      );

      final boundary = boundaryKey.currentContext?.findRenderObject();
      if (boundary is! TileableRepaintBoundaryRenderObject) {
        throw StateError('TileableRepaintBoundary not found');
      }
      return await captureBoundaryTiles(
        boundary,
        pixelRatio: pixelRatio,
        maxPixel: maxPixel,
        onProgress: reporter?.progress,
      );
    } finally {
      entry.remove();
    }
  }

  /// 截取界面上的 [TileableRepaintBoundary]；内容过长时自动纵向切成多张。
  ///
  /// [imageProviders] 可显式补充需要预热的网络图，框架也会自动从子树收集。
  /// [singleImage] 为 true 时强制输出整张，不按 [maxSinglePixel] 切片。
  static ImageExportGenerator repaintBoundary(
    GlobalKey key, {
    List<ImageProvider> imageProviders = const [],
    Duration timeout = settleTimeout,
    bool Function()? readyWhen,
    bool singleImage = false,
  }) {
    return (reporter) async {
      final renderObject = key.currentContext?.findRenderObject();
      if (renderObject is! TileableRepaintBoundaryRenderObject) {
        throw StateError('TileableRepaintBoundary not found');
      }
      // 等待当前帧绘制完成，确保内容已全部渲染
      await WidgetsBinding.instance.endOfFrame;
      if (!renderObject.attached) {
        throw StateError('TileableRepaintBoundary detached');
      }
      await _settle(
        boundaryKey: key,
        context: key.currentContext!,
        extraProviders: imageProviders,
        timeout: timeout,
        readyWhen: readyWhen,
      );
      if (!renderObject.attached) {
        throw StateError('TileableRepaintBoundary detached');
      }
      return captureBoundaryTiles(
        renderObject,
        maxPixel: singleImage ? double.infinity : ImageExporter.maxSinglePixel,
        onProgress: reporter.progress,
      );
    };
  }

  /// 直接产出字节（AI 生图、ffmpeg 输出、词云导出等）。
  static ImageExportGenerator bytes(Future<Uint8List?> Function() generate) {
    return (_) async {
      final data = await generate();
      return data == null ? const [] : [data];
    };
  }

  /// 用 [CustomPainter] 直接绘制成 PNG（拼图、角色卡占位头像等）。
  ///
  /// 不需要 widget 树，因此在 GUI 与无头模式下行为完全一致。
  static ImageExportGenerator painter({
    required CustomPainter painter,
    required Size size,
    double pixelRatio = targetPixelRatio,
  }) {
    return (_) async => [await painterToPng(painter, size, pixelRatio)];
  }

  /// 把 [painter] 绘制到 [size] 画布并编码为 PNG 字节。
  static Future<Uint8List> painterToPng(
    CustomPainter painter,
    Size size, [
    double pixelRatio = targetPixelRatio,
  ]) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.scale(pixelRatio);
    painter.paint(canvas, size);
    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(
        (size.width * pixelRatio).ceil(),
        (size.height * pixelRatio).ceil(),
      );
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) throw StateError('生成图片数据失败');
        return data.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    } finally {
      picture.dispose();
    }
  }

  /// 离屏渲染并只取一张完整 PNG，方便 HTTP 接口直接返回整图。
  ///
  /// 与 [offscreen] 不同，这里不会把超长内容切成多片（传 [maxPixel] 的
  /// 默认值即整张直出），而是依赖 [captureSafe] 在纹理不足时降比重试。
  /// 返回 null 表示宿主不可用或渲染失败，调用方无需再 try/catch。
  static Future<Uint8List?> captureSingle({
    required Widget child,
    BuildContext? context,
    OverlayState? overlay,
    ThemeData? themeOverride,
    Brightness? brightness,
    double width = defaultWidth,
    double pixelRatio = targetPixelRatio,
    double maxPixel = double.infinity,
    List<ImageProvider> imageProviders = const [],
    Duration timeout = settleTimeout,
    TextStyle? textStyle,
    bool Function()? readyWhen,
  }) async {
    try {
      final bytes = await offscreen(
        child: child,
        context: context,
        overlay: overlay,
        themeOverride: themeOverride,
        brightness: brightness,
        width: width,
        pixelRatio: pixelRatio,
        maxPixel: maxPixel,
        imageProviders: imageProviders,
        timeout: timeout,
        textStyle: textStyle,
        readyWhen: readyWhen,
      )(const SilentImageExportReporter());
      return bytes.firstOrNull;
    } catch (e, s) {
      Log.error('图片导出失败', '$e\n$s');
      return null;
    }
  }

  /// 等待离屏子树渲染稳定：先收集并预热网络图，再逐帧等到解码完成、重绘结束。
  ///
  /// 不用固定 sleep，而是等「布局完成 + 图片进了 ImageCache + 子树报告就绪」，
  /// 因此无网络图的导出只需两帧，纯静态内容（二维码卡片、词云、年度热力图）
  /// 比原来的固定 400~500ms 快一个数量级。
  ///
  /// [readyWhen] 用于子树需要异步加载数据的场景（如分享卡片先拉接口再渲染）。
  static Future<void> _settle({
    required GlobalKey boundaryKey,
    required BuildContext context,
    List<ImageProvider> extraProviders = const [],
    required Duration timeout,
    bool Function()? readyWhen,
  }) async {
    // 首帧完成后子树才完成布局，此时才能收集到其中的图片 provider
    await WidgetsBinding.instance.endOfFrame;

    final boundary = boundaryKey.currentContext?.findRenderObject();
    if (boundary is! TileableRepaintBoundaryRenderObject || !boundary.hasSize) {
      return;
    }

    final providers = <ImageProvider>{
      ...extraProviders,
      ...collectImageProviders(boundaryKey.currentContext),
    };

    // 加载失败的图（404 / 离线）永远不会进缓存，必须从等待集合里剔除，
    // 否则会空转到超时。precacheImage 抛错即视为失败。
    final failed = <ImageProvider>{};
    if (providers.isNotEmpty) {
      await Future.wait(
        providers.map((p) async {
          try {
            await precacheImage(p, context);
          } catch (_) {
            failed.add(p);
          }
        }),
      );
    }
    final waiting = providers.where((p) => !failed.contains(p)).toList();

    final deadline = DateTime.now().add(timeout);
    while (true) {
      final dataReady = readyWhen == null || readyWhen();
      final imagesReady = waiting.every((p) => imageCache.containsKey(p));
      if (dataReady && imagesReady) break;
      if (DateTime.now().isAfter(deadline)) {
        Log.error('图片导出', '等待内容就绪超时，按当前已渲染结果抓帧');
        break;
      }
      await WidgetsBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 50));
    }

    // 预热完成会让图片组件 setState，再等一帧让新图真正落到图层上
    await WidgetsBinding.instance.endOfFrame;
  }

  /// 遍历子树收集所有 [ImageProvider]，抓帧前用于预热，避免截图出现占位图。
  static Set<ImageProvider> collectImageProviders(BuildContext? context) {
    if (context == null) return const {};
    final result = <ImageProvider>{};
    void visit(Element element) {
      final widget = element.widget;
      if (widget is Image) {
        result.add(widget.image);
      } else if (widget is AnimatedImage) {
        result.add(widget.image);
      }
      element.visitChildren(visit);
    }

    visit(context as Element);
    return result;
  }
}

/// 可访问内部 [OffsetLayer] 的 RepaintBoundary。
///
/// [RenderRepaintBoundary.layer] 是 protected 的，无法直接取到；
/// 通过子类暴露出来，才能用 [OffsetLayer.toImage] 按区域切片截图。
class TileableRepaintBoundary extends SingleChildRenderObjectWidget {
  const TileableRepaintBoundary({super.key, super.child});

  @override
  TileableRepaintBoundaryRenderObject createRenderObject(
    BuildContext context,
  ) => TileableRepaintBoundaryRenderObject();
}

class TileableRepaintBoundaryRenderObject extends RenderRepaintBoundary {
  OffsetLayer? get captureLayer => layer as OffsetLayer?;
}

/// 把 RepaintBoundary 按最大像素高纵向切成多张，逐张渲染 / 编码。
///
/// 逐片处理既绕开了单张纹理上限，也避免一次性把整张超长图放进内存。
/// [maxPixel] 传 [double.infinity] 可强制输出单张（用于 HTTP 直出整图），
/// 此时仍会由 [captureSafe] 在纹理不足时降低像素比重试。
Future<List<Uint8List>> captureBoundaryTiles(
  TileableRepaintBoundaryRenderObject boundary, {
  double pixelRatio = ImageExporter.targetPixelRatio,
  double maxPixel = ImageExporter.maxSinglePixel,
  void Function(int done, int total)? onProgress,
}) async {
  final size = boundary.size;
  final layer = boundary.captureLayer;

  final withinSingle =
      size.width * pixelRatio <= maxPixel &&
      size.height * pixelRatio <= maxPixel;

  if (layer == null || withinSingle) {
    final image = await captureSafe(
      (r) => boundary.toImage(pixelRatio: r),
      pixelRatio,
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data == null ? const [] : [data.buffer.asUint8List()];
  }

  final tileLogicalHeight = maxPixel / pixelRatio;
  final tileCount = (size.height / tileLogicalHeight).ceil();
  onProgress?.call(0, tileCount);

  final tiles = <Uint8List>[];
  for (var i = 0; i < tileCount; i++) {
    final top = i * tileLogicalHeight;
    final height = math.min(tileLogicalHeight, size.height - top);
    if (height <= 0) break;
    final bounds = Rect.fromLTWH(0, top, size.width, height);
    final image = await captureSafe(
      (r) => layer.toImage(bounds, pixelRatio: r),
      pixelRatio,
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data != null) tiles.add(data.buffer.asUint8List());
    onProgress?.call(i + 1, tileCount);
  }
  return tiles;
}

/// 按目标像素比截图；部分低端设备纹理上限较低时，失败则逐步降比重试。
Future<ui.Image> captureSafe(
  Future<ui.Image> Function(double pixelRatio) capture,
  double targetPixelRatio,
) async {
  var ratio = targetPixelRatio;
  while (true) {
    try {
      return await capture(ratio);
    } catch (e) {
      if (ratio <= 0.5) rethrow;
      ratio /= 2;
      Log.error('截图失败', 'toImage 失败，降低像素比至 $ratio 后重试: $e');
    }
  }
}
