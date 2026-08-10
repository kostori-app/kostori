import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/utils/io.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/pages/image_manipulation_page/image_manipulation_page.dart';
import 'package:kostori/utils/volume.dart';
import 'package:marquee/marquee.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

final imageListProvider = StateProvider<List<File>>((ref) => []);
final currentIndexProvider = StateProvider<int>((ref) => 0);

class ImagePreviewWidget extends ConsumerStatefulWidget {
  final String url;
  final String heroTag;
  final bool isLocal;
  final ImageProvider img;
  final String title;
  final PageController pageController;

  const ImagePreviewWidget({
    super.key,
    required this.url,
    required this.heroTag,
    required this.isLocal,
    required this.img,
    required this.pageController,
    required this.title,
  });

  @override
  ConsumerState<ImagePreviewWidget> createState() => _ImagePreviewWidgetState();
}

class _ImagePreviewWidgetState extends ConsumerState<ImagePreviewWidget> {
  final _photoViewControllers = <int, PhotoViewController>{};
  final _scaleControllers = <int, PhotoViewScaleStateController>{};
  late final FocusNode _focusNode;
  Timer? _singleTapTimer;
  DateTime? _lastTapTime;
  StreamSubscription? _volumeSubscription;
  VolumeListener? volumeListener;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    handleVolumeEvent();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _singleTapTimer?.cancel();
    _volumeSubscription?.cancel();
    _focusNode.dispose();
    stopVolumeEvent();
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    for (final c in _photoViewControllers.values) {
      c.dispose();
    }
    for (final c in _scaleControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void handleVolumeEvent() {
    if (!App.isAndroid) {
      // Currently only support Android
      return;
    }
    if (volumeListener != null) {
      volumeListener?.cancel();
    }
    volumeListener = VolumeListener(onDown: _goNext, onUp: _goPrev)..listen();
  }

  void stopVolumeEvent() {
    if (volumeListener != null) {
      volumeListener?.cancel();
      volumeListener = null;
    }
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey == LogicalKeyboardKey.audioVolumeUp) {
      _goPrev();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.audioVolumeDown) {
      _goNext();
      return true;
    }
    // 桌面端左右方向键翻页
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _goPrev();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _goNext();
      return true;
    }
    return false;
  }

  PhotoViewController _controllerForIndex(int index) {
    return _photoViewControllers.putIfAbsent(
      index,
      () => PhotoViewController(),
    );
  }

  PhotoViewScaleStateController _scaleControllerForIndex(int index) {
    return _scaleControllers.putIfAbsent(
      index,
      () => PhotoViewScaleStateController(),
    );
  }

  void _goNext() {
    final list = ref.read(imageListProvider);
    if (list.isEmpty) return;
    final current = ref.read(currentIndexProvider);
    final next = (current + 1).clamp(0, list.length - 1);
    if (next != current) {
      widget.pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _goPrev() {
    final list = ref.read(imageListProvider);
    if (list.isEmpty) return;
    final current = ref.read(currentIndexProvider);
    final prev = (current - 1).clamp(0, list.length - 1);
    if (prev != current) {
      widget.pageController.animateToPage(
        prev,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _toggleZoom(int index) {
    if (!widget.isLocal) {
      final controller = _controllerForIndex(index);
      final currentScale = controller.scale ?? 1.0;
      double targetScale;
      if (currentScale <= 1.0) {
        targetScale = 1.5;
      } else if (currentScale <= 1.8) {
        targetScale = 3.0;
      } else {
        targetScale = 1.0;
      }
      controller.animateScale?.call(targetScale);
    } else {
      final scaleController = _scaleControllerForIndex(index);
      switch (scaleController.scaleState) {
        case PhotoViewScaleState.initial:
          scaleController.scaleState = PhotoViewScaleState.covering;
          break;
        case PhotoViewScaleState.covering:
          scaleController.scaleState = PhotoViewScaleState.originalSize;
          break;
        case PhotoViewScaleState.originalSize:
        default:
          scaleController.scaleState = PhotoViewScaleState.initial;
          break;
      }
    }
  }

  void _handleTap(int index, TapUpDetails details) {
    final now = DateTime.now();
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!) < const Duration(milliseconds: 200)) {
      _singleTapTimer?.cancel();
      _singleTapTimer = null;
      _lastTapTime = null;
      _toggleZoom(index);
    } else {
      _lastTapTime = now;
      _singleTapTimer?.cancel();
      _singleTapTimer = Timer(const Duration(milliseconds: 200), () {
        final x = details.localPosition.dx;
        final width = MediaQuery.of(context).size.width;
        if (!widget.isLocal) {
          context.pop();
        } else {
          if (x < width * 0.25) {
            _goPrev();
          } else if (x > width * 0.75) {
            _goNext();
          } else {
            context.pop();
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          final controller = _controllerForIndex(
            ref.read(currentIndexProvider),
          );
          // 当前偏移加上滚轮delta
          final currentPosition = controller.position;
          controller.animatePosition?.call(
            currentPosition,
            Offset(
              currentPosition.dx,
              currentPosition.dy - event.scrollDelta.dy * 1.5,
            ),
          );
        }
      },
      child: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: (event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.audioVolumeUp) {
              _goPrev();
            } else if (event.logicalKey == LogicalKeyboardKey.audioVolumeDown) {
              _goNext();
            }
          }
        },
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Material(
            type: MaterialType.transparency,
            child: Stack(
              children: [
                Center(child: _buildImageArea()),
                Positioned(
                  top: context.padding.top,
                  left: 16,
                  right: 16,
                  child: _TopBar(
                    url: widget.url,
                    heroTag: widget.heroTag,
                    isLocal: widget.isLocal,
                    pageController: widget.pageController,
                    title: widget.title,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageArea() {
    final imageList = ref.watch(imageListProvider);

    if (imageList.length > 1) {
      return PhotoViewGallery.builder(
        itemCount: imageList.length,
        pageController: widget.pageController,
        backgroundDecoration: const BoxDecoration(color: Colors.transparent),
        onPageChanged: (i) => ref.read(currentIndexProvider.notifier).state = i,
        builder: (context, i) {
          final file = imageList[i];
          return PhotoViewGalleryPageOptions(
            controller: _controllerForIndex(i),
            scaleStateController: _scaleControllerForIndex(i),
            imageProvider: FileImage(file),
            heroAttributes: PhotoViewHeroAttributes(
              tag: file.path.split(Platform.pathSeparator).last,
            ),
            initialScale: PhotoViewComputedScale.contained,
            minScale: PhotoViewComputedScale.contained / 3,
            maxScale: PhotoViewComputedScale.covered * 100,
            onTapUp: (ctx, details, _) => _handleTap(i, details),
          );
        },
      );
    }

    return PhotoView.customChild(
      controller: _controllerForIndex(0),
      scaleStateController: _scaleControllerForIndex(0),
      initialScale: PhotoViewComputedScale.contained,
      minScale: PhotoViewComputedScale.contained / 3,
      maxScale: PhotoViewComputedScale.covered * 100,
      heroAttributes: PhotoViewHeroAttributes(tag: widget.heroTag),
      backgroundDecoration: const BoxDecoration(color: Colors.transparent),
      onTapUp: (ctx, details, _) => _handleTap(0, details),
      // SizedBox.expand 保证图片加载完成前 hero 目标也有固定尺寸，
      // 否则首次进入（图片未缓存）时 target hero 尺寸为 0，hero flight 不触发
      child: SizedBox.expand(
        child: AnimatedImage(image: widget.img, fit: BoxFit.contain),
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  final String url;
  final String heroTag;
  final bool isLocal;
  final String title;
  final PageController pageController;

  const _TopBar({
    required this.url,
    required this.heroTag,
    required this.isLocal,
    required this.pageController,
    required this.title,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          _iconBackground(icon: Icons.close, onPressed: () => context.pop()),
          const SizedBox(width: 8),
          Expanded(child: _buildTitle(ref)),
          const SizedBox(width: 8),
          isLocal
              ? _buildLocalActions(context, ref)
              : _buildDownloadMenuItems(context),
        ],
      ),
    );
  }

  Widget _buildTitle(WidgetRef ref) {
    final index = ref.watch(currentIndexProvider);
    final urls = ref.watch(imageListProvider);
    final file = urls.isNotEmpty ? urls[index] : File(url);
    final filename = file.path.split(Platform.pathSeparator).last;
    return _textBackground(isLocal ? filename : title);
  }

  MenuButton _buildMenuItems(BuildContext context, WidgetRef ref) {
    final index = ref.watch(currentIndexProvider);
    final urls = ref.watch(imageListProvider);
    final currentFile = urls.isNotEmpty ? urls[index] : File(url);
    final localExists = currentFile.existsSync();

    return MenuButton(
      message: t.more,
      entries: [
        MenuEntry(
          text: t.properties,
          icon: Icons.info_outline,
          onClick: () => _showImageProperties(context, currentFile),
        ),
        MenuEntry(
          text: t.copyPath,
          icon: Icons.copy,
          onClick: () => _copyPath(context, currentFile.path),
        ),
        MenuEntry(
          text: t.share,
          icon: Icons.share,
          onClick: () => _shareFile(currentFile),
        ),
        if (localExists)
          MenuEntry(
            text: t.delete,
            icon: Icons.delete,
            color: Colors.red,
            onClick: () => _confirmDelete(context, ref, currentFile, index),
          ),
      ],
    );
  }

  Widget _buildLocalActions(BuildContext context, WidgetRef ref) {
    final index = ref.watch(currentIndexProvider);
    final urls = ref.watch(imageListProvider);

    return Row(
      children: [
        _buildMenuItems(context, ref),
        if (urls.length > 1) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.toOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${index + 1} / ${urls.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _copyPath(BuildContext context, String path) {
    Clipboard.setData(ClipboardData(text: path));
    context.showMessage(message: t.copied);
  }

  Widget _iconBackground({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.black.toOpacity(0.3)),
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }

  Widget _textBackground(String title) {
    const style = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: Colors.white,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 32),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final textPainter = TextPainter(
              text: TextSpan(text: title, style: style),
              maxLines: 1,
              textDirection: ui.TextDirection.ltr,
            )..layout(maxWidth: constraints.maxWidth);

            final shouldScroll =
                textPainter.width >= constraints.maxWidth * 0.7;

            return ClipRect(
              child: shouldScroll
                  ? Marquee(
                      text: title,
                      style: style,
                      scrollAxis: Axis.horizontal,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      blankSpace: 10.0,
                      velocity: 40.0,
                      pauseAfterRound: Duration.zero,
                      accelerationDuration: Duration.zero,
                      decelerationDuration: Duration.zero,
                    )
                  : SelectableText(title, style: style, maxLines: 1),
            );
          },
        ),
      ),
    );
  }

  MenuButton _buildDownloadMenuItems(BuildContext context) {
    return MenuButton(
      message: t.more,
      entries: [
        MenuEntry(
          text: t.copyPath,
          icon: Icons.copy,
          onClick: () => _copyPath(context, url),
        ),
        MenuEntry(
          text: t.download,
          icon: Icons.download,
          onClick: () => ImageSaver.saveImageToGallery(url),
        ),
      ],
    );
  }

  Future<void> _shareFile(File file) async {
    final filename = file.path.split(Platform.pathSeparator).last;
    final data = await file.readAsBytes();
    await Share.shareFile(data: data, filename: filename, mime: 'image/png');
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    File file,
    int index,
  ) {
    showConfirmDialog(
      context: context,
      title: t.confirmDeleteImage,
      content: t.confirmDeleteImageHint,
      btnColor: Theme.of(context).colorScheme.error,
      onConfirm: () => _deleteFile(context, ref, file, index),
    );
  }

  Future<void> _deleteFile(
    BuildContext context,
    WidgetRef ref,
    File file,
    int index,
  ) async {
    try {
      await file.delete();

      context.showMessage(message: t.deleteSuccessful);

      // 同步移除图片操作页列表里对应的图片（磁盘文件已删除）
      ref.read(imagesProvider.notifier).removeFile(file);

      final urls = ref.read(imageListProvider);
      if (urls.isEmpty) {
        Navigator.pop(context);
        return;
      }

      final newList = [...urls]..removeAt(index);
      if (newList.isEmpty) {
        Navigator.pop(context);
        return;
      }

      final newIndex = index >= newList.length ? newList.length - 1 : index;
      ref.read(currentIndexProvider.notifier).state = newIndex;
      ref.read(imageListProvider.notifier).state = newList;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (pageController.hasClients) {
          pageController.jumpToPage(newIndex);
        }
      });
    } catch (e) {
      Log.error('删除失败', e.toString());
      context.showMessage(message: t.deleteFailed, level: LogLevel.error);
    }
  }

  Future<void> _showImageProperties(BuildContext context, File file) async {
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final stat = await file.stat();
    final ext = file.path.split('.').last.toUpperCase();
    final size = _formatFileSize(stat.size);
    final width = image.width;
    final height = image.height;
    final modified = DateFormat('yyyy-MM-dd HH:mm').format(stat.modified);

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: t.imageProperties,
        displayButton: false,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _propertyRow(
              t.fileName,
              file.path.split(Platform.pathSeparator).last,
            ),
            _propertyRow(t.imageFormat, ext),
            _propertyRow(t.resolution, '$width × $height'),
            _propertyRow(t.fileSize, size),
            _propertyRow(t.modifiedTime, modified),
            _propertyRow(t.path, file.path),
          ],
        ),
      ),
    );
  }

  Widget _propertyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
