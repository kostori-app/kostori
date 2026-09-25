import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/utils/io.dart';

/// 图片导出的进度回报器（生成阶段）。
class ImageExportReporter {
  ImageExportReporter(this._controller);

  final LoadingDialogController _controller;

  /// 更新提示文案。
  void message(String text) => _controller.setMessage(text);

  /// 生成阶段进度；[total] 为 1 时不显示进度条。
  void progress(int done, int total) {
    if (total <= 1) return;
    _controller.setProgress(done / total);
    _controller.setMessage(
      t.screenshotGeneratingProgress(current: done, total: total),
    );
  }
}

/// 图片生成器：接收进度回报，产出 1~N 张 PNG 字节。
typedef ImageExportGenerator = Future<List<Uint8List>> Function(
  ImageExportReporter reporter,
);

/// 图片导出 / 分享的统一框架。
///
/// 把「生成图片 → 保存 / 分享 → 结果提示」的重复逻辑收拢到一处：
/// 各页面只提供一个 [ImageExportGenerator]（见 [ImageExporter.offscreen]、
/// [ImageExporter.bytes]、[ImageExporter.repaintBoundary]），其余全部由框架处理：
/// 进度弹窗、超长内容纵向切分、多张命名、桌面存文件 + 复制首张、
/// 移动端存相册 + 一次分享全部、以及异常兜底。
abstract final class ImageExporter {
  /// 默认输出像素比。
  static const double targetPixelRatio = 2.0;

  /// 单张图片允许的最大像素边长；超过则切成多张。
  ///
  /// 超过这个尺寸不只是 GPU 最大纹理（约 4096~16384）的问题：
  /// 微信 / Twitter 等第三方 App 对超长图会压缩、缩放甚至拒绝。
  static const double maxSinglePixel = 4096.0;

  /// 生成并保存 / 分享图片，返回是否成功。
  static Future<bool> run(
    BuildContext context, {
    required String filename,
    required ImageExportGenerator generate,
    String? generatingMessage,
    String? savingMessage,
    String? desktopSuccessMessage,
    String? mobileSuccessMessage,
    String? failureMessage,
    String Function(Object error)? failureMessageBuilder,
  }) {
    String failMessage(Object e) =>
        failureMessageBuilder?.call(e) ?? failureMessage ?? t.screenshotFailed;

    Future<bool> task(LoadingDialogController loading) async {
      final reporter = ImageExportReporter(loading);
      loading.setMessage(generatingMessage ?? t.calGeneratingScreenshot);

      List<Uint8List> bytes;
      try {
        bytes = await generate(reporter);
      } catch (e, s) {
        Log.error('导出失败', '$e\n$s');
        loading.close();
        ImageSaver.showResult(success: false, message: failMessage(e));
        return false;
      }

      if (bytes.isEmpty) {
        loading.close();
        return false;
      }

      loading.setProgress(null);
      loading.setMessage(savingMessage ?? t.savingImage);

      final names = [
        for (var i = 0; i < bytes.length; i++)
          bytes.length == 1 ? '$filename.png' : '${filename}_${i + 1}.png',
      ];

      try {
        await ImageSaver.saveOrShareImages(
          bytes: bytes,
          filenames: names,
          desktopSuccessMessage: desktopSuccessMessage,
          mobileSuccessMessage: mobileSuccessMessage,
          onProgress: (done, total) {
            if (total > 1) {
              loading.setProgress(done / total);
              loading.setMessage(
                t.screenshotSavingProgress(current: done, total: total),
              );
            }
          },
          onSaved: loading.close,
        );
      } catch (e, s) {
        Log.error('保存失败', '$e\n$s');
        loading.close();
        ImageSaver.showResult(success: false, message: failMessage(e));
        return false;
      }
      return true;
    }

    return runWithLoadingDialog<bool>(
      context,
      message: generatingMessage ?? t.calGeneratingScreenshot,
      task: task,
    );
  }

  /// 离屏渲染任意 [Widget] 为一张 PNG。
  static ImageExportGenerator offscreen({
    required BuildContext context,
    required Widget child,
    double width = 800,
    double pixelRatio = 2.0,
    Duration delay = const Duration(milliseconds: 400),
  }) {
    return (_) async {
      final bytes = await ImageSaver.captureWidgetToImage(
        context: context,
        child: child,
        width: width,
        pixelRatio: pixelRatio,
        delay: delay,
      );
      if (bytes == null) {
        throw StateError('captureWidgetToImage returned null');
      }
      return [bytes];
    };
  }

  /// 直接产出字节（播放器截图、Painter 合成等）。
  static ImageExportGenerator bytes(Future<Uint8List?> Function() generate) {
    return (_) async {
      final data = await generate();
      return data == null ? const [] : [data];
    };
  }

  /// 截取屏幕上的 [TileableRepaintBoundary]；内容过长时自动纵向切成多张。
  static ImageExportGenerator repaintBoundary(GlobalKey key) {
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
      return captureBoundaryTiles(renderObject, onProgress: reporter.progress);
    };
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
Future<List<Uint8List>> captureBoundaryTiles(
  TileableRepaintBoundaryRenderObject boundary, {
  void Function(int done, int total)? onProgress,
}) async {
  final size = boundary.size;
  final layer = boundary.captureLayer;

  final withinSingle =
      size.width * ImageExporter.targetPixelRatio <=
          ImageExporter.maxSinglePixel &&
      size.height * ImageExporter.targetPixelRatio <=
          ImageExporter.maxSinglePixel;

  if (layer == null || withinSingle) {
    final image = await _captureSafe((r) => boundary.toImage(pixelRatio: r));
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data == null ? const [] : [data.buffer.asUint8List()];
  }

  final tileLogicalHeight =
      ImageExporter.maxSinglePixel / ImageExporter.targetPixelRatio;
  final tileCount = (size.height / tileLogicalHeight).ceil();
  onProgress?.call(0, tileCount);

  final tiles = <Uint8List>[];
  for (var i = 0; i < tileCount; i++) {
    final top = i * tileLogicalHeight;
    final height = math.min(tileLogicalHeight, size.height - top);
    if (height <= 0) break;
    final bounds = Rect.fromLTWH(0, top, size.width, height);
    final image = await _captureSafe(
      (r) => layer.toImage(bounds, pixelRatio: r),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data != null) tiles.add(data.buffer.asUint8List());
    onProgress?.call(i + 1, tileCount);
  }
  return tiles;
}

/// 按目标像素比截图；部分低端设备纹理上限较低时，失败则逐步降比重试。
Future<ui.Image> _captureSafe(
  Future<ui.Image> Function(double pixelRatio) capture,
) async {
  var ratio = ImageExporter.targetPixelRatio;
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
