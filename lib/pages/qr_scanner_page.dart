import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kostori/components/animated.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/utils/protocol_parser.dart';
import 'package:kostori/utils/qr_analysis_service.dart';

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

class _QrScannerPageState extends State<QrScannerPage> {
  /// 桌面端无相机实现，走“选图识别”
  final bool _isDesktop = !App.isMobile;
  bool _isScanning = true;
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    // 桌面端打开即弹出图片选择（等同移动端打开即启动相机）
    if (_isDesktop) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pickFromGallery();
      });
    }
  }

  void _returnResult(String raw) {
    if (!mounted) return;
    final parsed = ProtocolParser.parse(raw);
    Navigator.pop(context, QrScanResult(rawValue: raw, parsed: parsed));
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

  /// 桌面端：没有相机插件，改为选图（文件选择器）识别二维码
  Widget _desktopBody(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                color: Colors.white,
                icon: const Icon(Icons.arrow_back_ios_new_outlined),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.qr_code_scanner,
                      size: 72,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                    const SizedBox(height: 20),
                    if (_isAnalyzing) ...[
                      const PolygonRefreshIndicator(),
                      const SizedBox(height: 12),
                      Text(
                        t.qrRecognizing,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ] else
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          foregroundColor: Colors.black87,
                          backgroundColor: Colors.white,
                        ),
                        onPressed: _pickFromGallery,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(t.chooseImage),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mobileBody(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          ReaderWidget(
            onScan: (code) {
              if (!_isScanning) return;
              final text = code.text;
              if (text == null || text.isEmpty) return;
              _isScanning = false;
              _returnResult(text);
            },
            showFlashlight: true,
            showToggleCamera: true,
            showGallery: true,
            allowPinchZoom: true,
            showScannerOverlay: true,
            tryHarder: true,
            actionButtonsBackgroundColor: Colors.black45,
          ),
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _CircleBtn(
                  icon: Icons.arrow_back_ios_new_outlined,
                  onTap: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isDesktop) return _desktopBody(context);
    return _mobileBody(context);
  }
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
