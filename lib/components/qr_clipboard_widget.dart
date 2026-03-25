import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kostori/components/bangumi_widget.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/network/app_dio.dart';
import 'package:kostori/network/bangumi.dart';
import 'package:kostori/pages/anime_details_page/anime_page.dart';
import 'package:kostori/pages/bangumi/bangumi_info_page.dart';
import 'package:kostori/pages/bangumi/character_page.dart';
import 'package:kostori/pages/bangumi/person_page.dart';
import 'package:kostori/pages/qr_scanner_page.dart';
import 'package:kostori/utils/clipboard_provider.dart';
import 'package:kostori/utils/protocol_parser.dart';
import 'package:zxing2/qrcode.dart';

final clipboardNotifierProvider = ChangeNotifierProvider<ClipboardProvider>(
  (ref) => ClipboardProvider(autoCheckOnInit: false),
);

class QrClipboardWidget extends ConsumerStatefulWidget {
  const QrClipboardWidget({super.key});

  @override
  ConsumerState<QrClipboardWidget> createState() => _QrClipboardWidgetState();
}

class _QrClipboardWidgetState extends ConsumerState<QrClipboardWidget> {
  bool _isAnalyzing = false;
  bool _isNavigating = false;
  bool _isDragging = false;

  Future<void> _navigate(BuildContext context, ParsedProtocol parsed) async {
    if (_isNavigating) return;
    _isNavigating = true;

    try {
      if (parsed.type == KostoriRouteType.anime) {
        // payload 格式：{id}|{sourceKey}
        final parts = parsed.payload.split('|');
        if (parts.length < 2) {
          App.rootContext.showMessage(message: t.linkFormatErrorCannotParseAnimeInfo);
          return;
        }
        final animeId = parts[0];
        final sourceKey = parts[1];

        final validKeys = AnimeSource.all().map((s) => s.key).toSet();
        if (!validKeys.contains(sourceKey)) {
          App.rootContext.showMessage(message: t.sourceNotFoundPleaseConfirmSourceInstalled);
          return;
        }

        context.to(() => AnimePage(id: animeId, sourceKey: sourceKey));
      } else if (parsed.type == KostoriRouteType.bangumi) {
        final id = int.tryParse(parsed.payload);
        if (id == null) {
          App.rootContext.showMessage(message: t.linkFormatErrorCannotParseBangumiId);
          return;
        }

        App.rootContext.showMessage(message: t.fetchingBangumiInfo);

        try {
          final item = await Bangumi.instance.getBangumiInfoByID(id);
          if (item == null) {
            App.rootContext.showMessage(message: t.bangumiEntryNotFound);
            return;
          }
          if (!mounted) return;
          context.to(() => BangumiInfoPage(bangumiItem: item));
        } catch (e) {
          App.rootContext.showMessage(message: t.failedToFetchBangumiInfo);
        }
      } else if (parsed.type == KostoriRouteType.character) {
        final id = int.tryParse(parsed.payload);
        if (id == null) {
          App.rootContext.showMessage(message: t.linkFormatErrorCannotParseCharacterId);
          return;
        }
        App.rootContext.showMessage(message: t.verifyingCharacterInfo);
        try {
          final result = await Bangumi.instance.getCharacterByCharacterID(id);
          if (result.id == 0) {
            App.rootContext.showMessage(message: t.characterNotFound);
            return;
          }
          if (!mounted) return;
          BangumiWidget.showBottomPage(context, CharacterPage(characterID: id));
        } catch (e) {
          App.rootContext.showMessage(message: t.failedToFetchCharacterInfo);
        }
      } else if (parsed.type == KostoriRouteType.person) {
        final id = int.tryParse(parsed.payload);
        if (id == null) {
          App.rootContext.showMessage(message: t.linkFormatErrorCannotParsePersonId);
          return;
        }
        App.rootContext.showMessage(message: t.verifyingPersonInfo);
        try {
          final result = await Bangumi.instance.getPersonByPersonID(id);
          if (result.id == 0) {
            App.rootContext.showMessage(message: t.personNotFound);
            return;
          }
          if (!mounted) return;
          BangumiWidget.showBottomPage(context, PersonPage(personID: id));
        } catch (e) {
          App.rootContext.showMessage(message: t.failedToFetchPersonInfo);
        }
      } else {
        App.rootContext.showMessage(message: t.unrecognizedLink);
      }
    } finally {
      _isNavigating = false;
    }
  }

  Future<void> _checkClipboard(BuildContext context) async {
    final cp = ref.read(clipboardNotifierProvider);
    await cp.checkClipboard();

    if (!mounted) return;

    if (cp.parsed == null) {
      App.rootContext.showMessage(message: t.noKostoriLinkFoundInClipboard);
    }
  }

  Future<void> _pickFromGallery(BuildContext context) async {
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
      await _decodeQrFromBytes(context, bytes);
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _scanWithCamera(BuildContext context) async {
    if (!App.isMobile) {
      App.rootContext.showMessage(message: t.qrCodeFeatureOnlyOnMobile);
      return;
    }
    final result = await QrScannerPage.push(context);
    if (result == null || !mounted) return;
    _handleRaw(result.rawValue);
  }

  void _handleRaw(String raw) {
    final parsed = ProtocolParser.parse(raw);
    if (parsed != null) {
      _showFoundDialog(context, parsed);
    } else {
      App.rootContext.showMessage(message: t.unrecognizedKostoriProtocol);
    }
  }

  void _showFoundDialog(BuildContext context, ParsedProtocol parsed) {
    final String detail;
    if (parsed.type == KostoriRouteType.anime) {
      final parts = parsed.payload.split('|');
      detail = parts.length >= 2
          ? '番剧 ID：${parts[0]}\n来源：${parts[1]}'
          : parsed.payload;
    } else if (parsed.type == KostoriRouteType.bangumi) {
      detail = 'Bangumi ID：${parsed.payload}';
    } else {
      detail = parsed.payload;
    }

    final navigator = Navigator.of(App.rootContext, rootNavigator: true);

    ContentDialog.show(
      context: App.rootContext,
      title: '检测到 ${parsed.type.label} 链接',
      content: Text(
        '${parsed.wasBase64 ? "（口令已解析）\n" : ""}$detail',
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        FilledButton(
          onPressed: () async {
            navigator.pop();
            ref.read(clipboardNotifierProvider).consume();
            await _navigate(context, parsed);
          },
          child: Text(t.go),
        ),
      ],
    );
  }

  Future<void> _handleDroppedFile(
    BuildContext context,
    DropDoneDetails details,
  ) async {
    final file = details.files.firstOrNull;
    if (file == null) return;

    final ext = file.name.split('.').last.toLowerCase();
    if (!['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext)) {
      App.rootContext.showMessage(message: t.pleaseDragImageFile);
      return;
    }

    setState(() => _isAnalyzing = true);
    try {
      final bytes = await file.readAsBytes();
      await _decodeQrFromBytes(context, bytes);
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _handleDroppedUrl(BuildContext context, String url) async {
    if (!url.startsWith('http')) return;

    setState(() => _isAnalyzing = true);
    try {
      final response = await AppDio().request<Uint8List>(
        url,
        options: Options(method: 'GET', responseType: ResponseType.bytes),
      );
      if (response.data == null) {
        App.rootContext.showMessage(message: t.imageDownloadFailed);
        return;
      }
      await _decodeQrFromBytes(context, response.data!);
    } catch (e) {
      App.rootContext.showMessage(message: t.failedToFetchNetworkImage);
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _decodeQrFromBytes(BuildContext context, Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final uiImage = frame.image;

    final byteData = await uiImage.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    if (byteData == null) {
      App.rootContext.showMessage(message: t.imageDecodeFailed);
      return;
    }

    final source = RGBLuminanceSource(
      uiImage.width,
      uiImage.height,
      byteData.buffer.asInt32List(),
    );
    final bitmap = BinaryBitmap(GlobalHistogramBinarizer(source));

    try {
      final result = QRCodeReader().decode(bitmap);
      if (!mounted) return;
      _handleRaw(result.text);
    } catch (_) {
      App.rootContext.showMessage(message: t.noQrCodeFoundInImage);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ClipboardProvider>(clipboardNotifierProvider, (_, cp) {
      if (cp.hasPendingProtocol && cp.parsed != null && mounted) {
        _showFoundDialog(context, cp.parsed!);
      }
    });

    final cs = Theme.of(context).colorScheme;
    final busy = _isAnalyzing || _isNavigating;

    return SliverToBoxAdapter(
      child: DropTarget(
        onDragEntered: (_) => setState(() => _isDragging = true),
        onDragExited: (_) => setState(() => _isDragging = false),
        onDragDone: (details) {
          setState(() => _isDragging = false);
          final url = details.files.firstOrNull?.path ?? '';
          if (url.startsWith('http')) {
            _handleDroppedUrl(context, url);
          } else {
            _handleDroppedFile(context, details);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: _isDragging ? cs.primary : cs.outlineVariant,
              width: _isDragging ? 2 : 0.6,
            ),
            borderRadius: BorderRadius.circular(16),
            color: _isDragging ? cs.primary.toOpacity(0.05) : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(Icons.qr_code_scanner, color: cs.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(t.qrAndClipboard, style: ts.s16),
                    const Spacer(),
                    if (busy)
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.primary,
                        ),
                      ),
                  ],
                ),
              ),

              const Divider(height: 1, indent: 16, endIndent: 16),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    _ActionTile(
                      icon: Icons.content_paste_search_outlined,
                      label: t.clipboard,
                      onTap: busy
                          ? null
                          : () {
                              _checkClipboard(context);
                            },
                    ),
                    const SizedBox(width: 8),
                    _ActionTile(
                      icon: Icons.photo_library_outlined,
                      label: t.recognizeFromGallery,
                      onTap: () {
                        _pickFromGallery(context);
                      },
                    ),
                    if (busy || App.isMobile) ...[
                      const SizedBox(width: 8),
                      _ActionTile(
                        icon: Icons.camera_alt_outlined,
                        label: t.scanQrCode,
                        onTap: (busy || !App.isMobile)
                            ? null
                            : () {
                                _scanWithCamera(context);
                              },
                      ),
                    ],
                  ],
                ),
              ),

              _HintRow(cs: cs),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.4 : 1.0,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: cs.secondaryContainer.toOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: cs.primary, size: 22),
                const SizedBox(height: 6),
                Text(label, style: ts.s12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HintRow extends StatelessWidget {
  const _HintRow({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 13, color: cs.outline),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              t.shareMethodDescription,
              style: ts.s12.copyWith(color: cs.outline),
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}
