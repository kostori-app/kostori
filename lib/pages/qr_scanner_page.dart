import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/utils/protocol_parser.dart';
import 'package:kostori/utils/qr_analysis_service.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScanResult {
  final String rawValue;
  final ParsedProtocol? parsed;

  const QrScanResult({required this.rawValue, this.parsed});

  bool get isKostoriProtocol => parsed != null;
}

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  static Future<QrScanResult?> push(BuildContext context) {
    return Navigator.push<QrScanResult>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerPage()),
    );
  }

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _controller;
  double _baseZoom = 0.0;
  double _currentZoom = 0.0;
  bool _isScanning = true;
  bool _isAnalyzing = false;
  String? _errorMessage;

  late final AnimationController _lineAnim;
  late final Animation<double> _linePosition;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      autoStart: true,
      detectionSpeed: DetectionSpeed.noDuplicates,
    );

    _lineAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _linePosition = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _lineAnim, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    _lineAnim.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_isScanning) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null) return;

    // 如果捕获到条码对象但无法解析内容，说明可能太小了
    if (barcode.rawValue == null || barcode.rawValue!.isEmpty) {
      _autoZoomIn();
      return;
    }

    _isScanning = false;
    _controller.stop();
    _returnResult(barcode.rawValue!);
  }

  void _autoZoomIn() {
    if (_currentZoom < 0.8) {
      setState(() {
        _currentZoom = (_currentZoom + 0.15).clamp(0.0, 1.0);
        _controller.setZoomScale(_currentZoom); // 使用正确的 setZoomScale 方法
      });
    }
  }

  // 2. 手势缩放逻辑
  void _handleScaleStart(ScaleStartDetails details) {
    _baseZoom = _currentZoom;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      // details.scale 是手指张开的比例，1.0 代表不发生变化
      _currentZoom = (_baseZoom + (details.scale - 1) * 0.5).clamp(0.0, 1.0);
      _controller.setZoomScale(_currentZoom);
    });
  }

  // 3. 双击切换缩放
  void _handleDoubleTap() {
    setState(() {
      _currentZoom = _currentZoom > 0 ? 0.0 : 0.5;
      _controller.setZoomScale(_currentZoom);
    });
  }

  Future<void> _pickFromGallery() async {
    setState(() => _isAnalyzing = true);
    try {
      Uint8List? bytes;

      if (App.isMobile) {
        final file = await ImagePicker().pickImage(source: ImageSource.gallery);
        if (file == null || !mounted) return;
        bytes = await file.readAsBytes();
      } else {
        final result = await openFile(
          acceptedTypeGroups: [
            XTypeGroup(
              label: 'Images',
              extensions: ['jpg', 'jpeg', 'png', 'webp'],
            ),
          ],
        );
        if (result == null || !mounted) return;
        bytes = await result.readAsBytes();
      }

      final result = await QrAnalysisService.decodeQrFromBytes(bytes);

      if (result != null && mounted) {
        _returnResult(result);
      } else {
        App.rootContext.showMessage(message: t.noQrCodeFoundInImage);
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  void _returnResult(String raw) {
    final parsed = ProtocolParser.parse(raw);
    Navigator.pop(context, QrScanResult(rawValue: raw, parsed: parsed));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: GestureDetector(
              onScaleStart: _handleScaleStart,
              onScaleUpdate: _handleScaleUpdate,
              onDoubleTap: _handleDoubleTap,
              child: MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
                fit: BoxFit.cover,
              ),
            ),
          ),

          Positioned.fill(
            child: IgnorePointer(child: _ScanOverlay(lineAnim: _linePosition)),
          ),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    _CircleBtn(
                      icon: Icons.arrow_back_ios_new_outlined,
                      onTap: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    ValueListenableBuilder(
                      valueListenable: _controller,
                      builder: (_, state, _) => _CircleBtn(
                        icon: state.torchState == TorchState.on
                            ? Icons.flash_on
                            : Icons.flash_off,
                        onTap: _controller.toggleTorch,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 翻转摄像头
                    _CircleBtn(
                      icon: Icons.flip_camera_ios_outlined,
                      onTap: _controller.switchCamera,
                    ),
                    const SizedBox(width: 8),
                    // 相册
                    _CircleBtn(
                      icon: Icons.photo_library_outlined,
                      onTap: _isAnalyzing ? null : _pickFromGallery,
                    ),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.toOpacity(0.85),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (_isAnalyzing) ...[
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 8),
                  const Text(
                    '正在识别图片中的二维码…',
                    style: TextStyle(color: Colors.white70),
                  ),
                ] else
                  const Text(
                    '将二维码放入框内自动识别',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanOverlay extends StatelessWidget {
  const _ScanOverlay({required this.lineAnim});

  final Animation<double> lineAnim;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final boxSize = size.width * 0.68;
    final top = (size.height - boxSize) / 2 - 40;

    return Stack(
      children: [
        CustomPaint(
          size: size,
          painter: _MaskPainter(
            cutout: Rect.fromLTWH(
              (size.width - boxSize) / 2,
              top,
              boxSize,
              boxSize,
            ),
          ),
        ),
        Positioned(
          left: (size.width - boxSize) / 2,
          top: top,
          width: boxSize,
          height: boxSize,
          child: Stack(
            children: [
              CustomPaint(
                size: Size(boxSize, boxSize),
                painter: _CornerPainter(),
              ),
              AnimatedBuilder(
                animation: lineAnim,
                builder: (_, _) => Positioned(
                  top: lineAnim.value * (boxSize - 2),
                  left: 12,
                  right: 12,
                  height: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.greenAccent.toOpacity(0.9),
                          Colors.transparent,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.greenAccent.toOpacity(0.6),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MaskPainter extends CustomPainter {
  const _MaskPainter({required this.cutout});

  final Rect cutout;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(cutout, const Radius.circular(12)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, Paint()..color = Colors.black.toOpacity(0.62));
  }

  @override
  bool shouldRepaint(covariant _MaskPainter old) => old.cutout != cutout;
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 3.5;
    const radius = 10.0;
    final paint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final corners = [
      // 左上
      [Offset(radius, 0), Offset(0, radius)],
      // 右上
      [Offset(size.width - radius, 0), Offset(size.width, radius)],
      // 左下
      [Offset(0, size.height - radius), Offset(radius, size.height)],
      // 右下
      [
        Offset(size.width - radius, size.height),
        Offset(size.width, size.height - radius),
      ],
    ];

    for (final pair in corners) {
      canvas.drawLine(pair[0], pair[1], paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.black45,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
