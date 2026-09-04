part of 'components.dart';

class AnimatedImage extends StatefulWidget {
  /// show animation when loading is complete.
  AnimatedImage({
    required ImageProvider image,
    super.key,
    double scale = 1.0,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.width,
    this.height,
    this.color,
    this.opacity,
    this.colorBlendMode,
    this.fit,
    this.alignment = Alignment.center,
    this.repeat = ImageRepeat.noRepeat,
    this.centerSlice,
    this.matchTextDirection = false,
    this.gaplessPlayback = false,
    this.filterQuality = FilterQuality.medium,
    this.isAntiAlias = false,
    this.part,
    this.ink = false,
    Map<String, String>? headers,
    int? cacheWidth,
    int? cacheHeight,
  }) : image = ResizeImage.resizeIfNeeded(cacheWidth, cacheHeight, image),
       assert(cacheWidth == null || cacheWidth > 0),
       assert(cacheHeight == null || cacheHeight > 0);

  final ImageProvider image;

  /// 是否以 [Ink.image] 方式渲染（外层为 InkWell 时启用，
  /// 使点击波纹能显示在图片之上）。
  /// 启用后图片加载完成用 Ink.image 绘制；加载/错误态仍走骨架屏/错误图标。
  final bool ink;

  final String? semanticLabel;

  final bool excludeFromSemantics;

  final double? width;

  final double? height;

  final bool gaplessPlayback;

  final bool matchTextDirection;

  final Rect? centerSlice;

  final ImageRepeat repeat;

  final AlignmentGeometry alignment;

  final BoxFit? fit;

  final BlendMode? colorBlendMode;

  final FilterQuality filterQuality;

  final Animation<double>? opacity;

  final Color? color;

  final bool isAntiAlias;

  final ImagePart? part;

  /// 保留的兼容 API：历史上用于清空内部缓存，现缓存由 Flutter ImageCache 管理。
  static void clear() {}

  @override
  State<AnimatedImage> createState() => _AnimatedImageState();
}

class _AnimatedImageState extends State<AnimatedImage>
    with WidgetsBindingObserver {
  ImageStream? _imageStream;
  ImageInfo? _imageInfo;
  ImageChunkEvent? _loadingProgress;
  bool _isListeningToStream = false;
  late bool _invertColors;
  int? _frameNumber;
  bool _wasSynchronouslyLoaded = false;
  late DisposableBuildContext<State<AnimatedImage>> _scrollAwareContext;
  Object? _lastException;
  ImageStreamCompleterHandle? _completerHandle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollAwareContext = DisposableBuildContext<State<AnimatedImage>>(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopListeningToStream();
    _completerHandle?.dispose();
    _scrollAwareContext.dispose();
    _replaceImage(info: null);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    _updateInvertColors();
    _resolveImage();

    if (TickerMode.valuesOf(context).enabled) {
      _listenToStream();
    } else {
      _stopListeningToStream(keepStreamAlive: true);
    }

    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(AnimatedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.image != oldWidget.image) {
      _resolveImage();
    }
  }

  @override
  void didChangeAccessibilityFeatures() {
    super.didChangeAccessibilityFeatures();
    setState(() {
      _updateInvertColors();
    });
  }

  @override
  void reassemble() {
    // 热重载会清空 ImageCache 并 dispose 已解码的 ui.Image，
    // 必须先清空本地引用再重新解析，否则 RawImage 在 rebuild 时
    // 会 clone 已 dispose 的图片而抛 "Cannot clone a disposed image"。
    _imageInfo = null;
    _resolveImage();
    super.reassemble();
  }

  void _updateInvertColors() {
    _invertColors =
        MediaQuery.maybeInvertColorsOf(context) ??
        SemanticsBinding.instance.accessibilityFeatures.invertColors;
  }

  void _resolveImage() {
    final ScrollAwareImageProvider provider = ScrollAwareImageProvider<Object>(
      context: _scrollAwareContext,
      imageProvider: widget.image,
    );
    final ImageStream newStream = provider.resolve(
      createLocalImageConfiguration(
        context,
        size: widget.width != null && widget.height != null
            ? Size(widget.width!, widget.height!)
            : null,
      ),
    );
    _updateSourceStream(newStream);
  }

  ImageStreamListener? _imageStreamListener;

  ImageStreamListener _getListener({bool recreateListener = false}) {
    if (_imageStreamListener == null || recreateListener) {
      _lastException = null;
      _imageStreamListener = ImageStreamListener(
        _handleImageFrame,
        onChunk: _handleImageChunk,
        onError: (Object error, StackTrace? stackTrace) {
          setState(() {
            _lastException = error;
          });
        },
      );
    }
    return _imageStreamListener!;
  }

  void _handleImageFrame(ImageInfo imageInfo, bool synchronousCall) {
    setState(() {
      _replaceImage(info: imageInfo);
      _loadingProgress = null;
      _lastException = null;
      _frameNumber = _frameNumber == null ? 0 : _frameNumber! + 1;
      _wasSynchronouslyLoaded = _wasSynchronouslyLoaded | synchronousCall;
    });
  }

  void _handleImageChunk(ImageChunkEvent event) {
    // 仅记录进度供调试，不触发重建（UI 不显示加载进度）
    _loadingProgress = event;
    _lastException = null;
  }

  void _replaceImage({required ImageInfo? info}) {
    final ImageInfo? oldImageInfo = _imageInfo;
    SchedulerBinding.instance.addPostFrameCallback(
      (_) => oldImageInfo?.dispose(),
    );
    _imageInfo = info;
  }

  // Updates _imageStream to newStream, and moves the stream listener
  // registration from the old stream to the new stream (if a listener was
  // registered).
  void _updateSourceStream(ImageStream newStream) {
    if (_imageStream?.key == newStream.key) {
      return;
    }

    if (_isListeningToStream) {
      _imageStream!.removeListener(_getListener());
    }

    if (!widget.gaplessPlayback) {
      setState(() {
        _replaceImage(info: null);
      });
    }

    setState(() {
      _loadingProgress = null;
      _frameNumber = null;
      _wasSynchronouslyLoaded = false;
    });

    _imageStream = newStream;
    if (_isListeningToStream) {
      _imageStream!.addListener(_getListener());
    }
  }

  void _listenToStream() {
    if (_isListeningToStream) {
      return;
    }

    _imageStream!.addListener(_getListener());
    _completerHandle?.dispose();
    _completerHandle = null;

    _isListeningToStream = true;
  }

  /// Stops listening to the image stream, if this state object has attached a
  /// listener.
  ///
  /// If the listener from this state is the last listener on the stream, the
  /// stream will be disposed. To keep the stream alive, set `keepStreamAlive`
  /// to true, which create [ImageStreamCompleterHandle] to keep the completer
  /// alive and is compatible with the [TickerMode] being off.
  void _stopListeningToStream({bool keepStreamAlive = false}) {
    if (!_isListeningToStream) {
      return;
    }

    if (keepStreamAlive &&
        _completerHandle == null &&
        _imageStream?.completer != null) {
      _completerHandle = _imageStream!.completer!.keepAlive();
    }

    _imageStream!.removeListener(_getListener());
    _isListeningToStream = false;
  }

  @override
  Widget build(BuildContext context) {
    Widget result;

    if (_imageInfo != null) {
      if (widget.part != null) {
        result = CustomPaint(
          painter: ImagePainter(image: _imageInfo!.image, part: widget.part!),
          child: SizedBox(width: widget.width, height: widget.height),
        );
      } else if (widget.ink) {
        // Ink.image 把图片作为 Material 的 decoration 绘制，
        // 外层 InkWell 的波纹才能显示在图片之上。
        // 用透明 Material 兜底，确保 Ink 始终有父级 Material。
        result = Material(
          type: MaterialType.transparency,
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: Ink.image(
              image: widget.image,
              fit: widget.fit ?? BoxFit.cover,
              alignment: widget.alignment,
              repeat: widget.repeat,
              centerSlice: widget.centerSlice,
              matchTextDirection: widget.matchTextDirection,
              colorFilter: widget.color != null
                  ? ColorFilter.mode(
                      widget.color!,
                      widget.colorBlendMode ?? BlendMode.srcIn,
                    )
                  : null,
            ),
          ),
        );
      } else {
        result = RawImage(
          image: _imageInfo?.image,
          width: widget.width,
          height: widget.height,
          debugImageLabel: _imageInfo?.debugLabel,
          scale: _imageInfo?.scale ?? 1.0,
          color: widget.color,
          opacity: widget.opacity,
          colorBlendMode: widget.colorBlendMode,
          fit: widget.fit ?? BoxFit.cover,
          alignment: widget.alignment,
          repeat: widget.repeat,
          centerSlice: widget.centerSlice,
          matchTextDirection: widget.matchTextDirection,
          invertColors: _invertColors,
          isAntiAlias: widget.isAntiAlias,
          filterQuality: widget.filterQuality,
        );
      }
    } else if (_lastException != null) {
      final is404 = _lastException.toString().contains('404');
      // 中性底色覆盖卡片容器背景色（如蓝调 secondaryContainer），避免刺眼
      final cs = Theme.of(context).colorScheme;
      result = ColoredBox(
        color: cs.surfaceContainerHighest,
        child: Center(
          child: Icon(
            is404
                ? Icons.image_not_supported_outlined
                : Icons.broken_image_outlined,
            color: cs.onSurfaceVariant,
          ),
        ),
      );

      if (!widget.excludeFromSemantics) {
        result = Semantics(
          container: widget.semanticLabel != null,
          image: true,
          label: widget.semanticLabel ?? '',
          child: result,
        );
      }
    } else {
      // 加载中骨架屏：用无动画 SolidColorEffect（滚动时大量 loading 卡各自
      // shimmer 是掉帧来源），就绪后仍由 AnimatedSwitcher 淡入
      final cs = Theme.of(context).colorScheme;
      result = Skeletonizer.zone(
        effect: SolidColorEffect(color: cs.surfaceContainerHighest),
        child: Bone(height: widget.height, width: widget.width ?? 100),
      );
    }

    final Widget animated = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 200),
      child: KeyedSubtree(
        // 以加载状态为 key，保证 骨架屏/错误/成图 之间有切换动画。
        // loading 态带 provider 标识：AnimatedSwitcher 会同时保留旧/新 child，
        // 若固定 'loading' 会在切换图片时出现两个同 key 的 loading（Duplicate keys）
        key: ValueKey<String>(
          _imageInfo != null
              // ResizeImage 的 toString 是通用 ResizeImage()，不同尺寸/来源会撞 key；
              // 用 provider hashCode（含 url 与解码尺寸）保证新旧帧唯一
              ? 'image:${widget.image.hashCode}'
              : (_lastException != null
                    ? 'error:${_lastException.toString().contains('404')}'
                    : 'loading:${widget.image.hashCode}'),
        ),
        child: result,
      ),
    );
    return animated;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description.add(DiagnosticsProperty<ImageStream>('stream', _imageStream));
    description.add(DiagnosticsProperty<ImageInfo>('pixels', _imageInfo));
    description.add(
      DiagnosticsProperty<ImageChunkEvent>('loadingProgress', _loadingProgress),
    );
    description.add(DiagnosticsProperty<int>('frameNumber', _frameNumber));
    description.add(
      DiagnosticsProperty<bool>(
        'wasSynchronouslyLoaded',
        _wasSynchronouslyLoaded,
      ),
    );
  }
}

class ImagePart {
  final double? x1;
  final double? y1;
  final double? x2;
  final double? y2;

  const ImagePart({this.x1, this.y1, this.x2, this.y2});
}

class ImagePainter extends CustomPainter {
  final ui.Image image;

  final ImagePart part;

  /// Render a part of the image.
  const ImagePainter({required this.image, this.part = const ImagePart()});

  @override
  void paint(Canvas canvas, Size size) {
    final Rect src = Rect.fromPoints(
      Offset(part.x1 ?? 0, part.y1 ?? 0),
      Offset(
        part.x2 ?? image.width.toDouble(),
        part.y2 ?? image.height.toDouble(),
      ),
    );
    final Rect dst = Offset.zero & size;
    canvas.drawImageRect(image, src, dst, Paint());
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is! ImagePainter ||
        oldDelegate.image != image ||
        oldDelegate.part.x1 != part.x1 ||
        oldDelegate.part.y1 != part.y1 ||
        oldDelegate.part.x2 != part.x2 ||
        oldDelegate.part.y2 != part.y2;
  }
}
