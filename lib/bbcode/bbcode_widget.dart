import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:antlr4/antlr4.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:kostori/foundation/log.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:url_launcher/url_launcher.dart';

import 'bbcode_base_listener.dart';
import 'bbcode_elements.dart';
import 'generated/BBCodeParser.dart';
import 'generated/BBCodeLexer.dart';

class BBCodeWidget extends StatefulWidget {
  const BBCodeWidget({super.key, required this.bbcode});

  final String bbcode;

  @override
  State<BBCodeWidget> createState() => _BBCodeWidgetState();
}

class _BBCodeWidgetState extends State<BBCodeWidget> {
  bool _isVisible = false;
  bool _isSaving = false;

  Color? _parseColor(String hex) {
    if (hex.startsWith('#')) {
      hex = hex.replaceFirst('#', '');
      if (hex.length == 6) {
        hex = "FF$hex";
      }
      if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    }
    switch (hex) {
      case 'red':
        return Colors.red;
      case 'blue':
        return Colors.blue;
      case 'orange':
        return Colors.orange;
      case 'green':
        return Colors.green;
      case 'grey':
        return Colors.grey;
      default:
        return null;
    }
  }

  Future<void> _saveImageToGallery(String imageUrl) async {
    if (!mounted) return;

    setState(() => _isSaving = true);

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('正在保存图片...')),
      );

      final dio = Dio();
      final response = await dio.get<Uint8List>(
        imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      if (!mounted) return;

      if (Platform.isAndroid) {
        // Android平台：使用ImageGallerySaverPlus保存到相册
        final result = await ImageGallerySaverPlus.saveImage(
          response.data!,
          quality: 100,
          name: _generateFilename(imageUrl),
          isReturnImagePathOfIOS: true,
        );

        if (!mounted) return;

        if (result == null || !(result['isSuccess'] as bool? ?? false)) {
          throw Exception('保存到相册失败');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已保存到相册')),
        );
      } else {
        // 其他平台：保存到应用文档目录
        final directory = await getApplicationDocumentsDirectory();
        final folderPath = '${directory.path}/BangumiImages';
        final folder = Directory(folderPath);

        if (!await folder.exists()) {
          await folder.create(recursive: true);
        }

        final filePath = '$folderPath/${_generateFilename(imageUrl)}';
        await File(filePath).writeAsBytes(response.data!);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已保存到: $filePath'),
            duration: const Duration(seconds: 5),
            action: Platform.isWindows || Platform.isLinux || Platform.isMacOS
                ? SnackBarAction(
                    label: '打开',
                    onPressed: () => _openFile(filePath),
                  )
                : null,
          ),
        );
      }
    } catch (e, s) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败: ${e.toString()}')),
      );
      Log.addLog(LogLevel.error, 'saveImageToGallery', '$e\n$s');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // 新增的打开文件方法（用于桌面平台）
  Future<void> _openFile(String path) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      try {
        if (Platform.isWindows) {
          await Process.run('start', [path], runInShell: true);
        } else if (Platform.isLinux) {
          await Process.run('xdg-open', [path]);
        } else if (Platform.isMacOS) {
          await Process.run('open', [path]);
        }
      } catch (e) {
        debugPrint('打开文件失败: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法打开文件')),
          );
        }
      }
    }
  }

  String _generateFilename(String url) {
    final uri = Uri.parse(url);
    final filename = uri.pathSegments.last;
    return filename.isNotEmpty
        ? 'bangumi_$filename'
        : 'bangumi_${DateTime.now().millisecondsSinceEpoch}.jpg';
  }

  void _showImagePreview(String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text('图片预览'),
            actions: [
              IconButton(
                icon: const Icon(Icons.download),
                onPressed: () => _saveImageToGallery(imageUrl),
              ),
            ],
          ),
          body: PhotoView(
            imageProvider: NetworkImage(imageUrl),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 3,
          ),
        ),
      ),
    );
  }

  void _showSaveDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('图片操作'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // 只关闭对话框
              },
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                _saveImageToGallery(imageUrl); // 再执行保存
              },
              child: const Text('保存到相册'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    BBCodeParser.checkVersion();
    final input = InputStream.fromString(widget.bbcode);
    final lexer = BBCodeLexer(input);
    final tokens = CommonTokenStream(lexer);
    final parser = BBCodeParser(tokens);
    final tree = parser.document();
    final bbcodeBaseListener = BBCodeBaseListener();
    ParseTreeWalker.DEFAULT.walk(bbcodeBaseListener, tree);
    bbCodeTag.clear();

    return Wrap(
      children: [
        SelectableText.rich(
          TextSpan(
            children: bbcodeBaseListener.bbcode.map((e) {
              if (e is BBCodeText) {
                Color? textColor = (!_isVisible && e.masked)
                    ? Colors.transparent
                    : (e.link != null)
                        ? Colors.blue
                        : (e.quoted)
                            ? Theme.of(context).colorScheme.outline
                            : (e.color != null)
                                ? _parseColor(e.color!)
                                : null;
                return TextSpan(
                  text: e.text,
                  mouseCursor: (e.link != null || e.masked)
                      ? SystemMouseCursors.click
                      : SystemMouseCursors.text,
                  recognizer: TapGestureRecognizer()
                    ..onTap = (e.link != null || e.masked)
                        ? () {
                            if ((!e.masked || _isVisible) && e.link != null) {
                              launchUrl(Uri.parse(e.link!));
                            } else if (e.masked) {
                              setState(() {
                                _isVisible = !_isVisible;
                              });
                            }
                          }
                        : null,
                  style: TextStyle(
                    fontWeight: (e.bold) ? FontWeight.bold : null,
                    fontStyle: (e.italic) ? FontStyle.italic : null,
                    decoration: TextDecoration.combine([
                      if (e.underline || e.link != null)
                        TextDecoration.underline,
                      if (e.strikeThrough) TextDecoration.lineThrough,
                    ]),
                    decorationColor: textColor,
                    fontSize: e.size.toDouble(),
                    color: textColor,
                    backgroundColor:
                        (!_isVisible && e.masked) ? Color(0xFF555555) : null,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                );
              } else if (e is BBCodeImg) {
                return WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            debugPrint('点击图片: ${e.imageUrl}');
                            _showImagePreview(e.imageUrl);
                          },
                          onLongPress: () => _showSaveDialog(e.imageUrl),
                          child: CachedNetworkImage(
                            imageUrl: e.imageUrl,
                            placeholder: (_, __) => Container(
                              color: Colors.grey[200],
                              width: 100,
                              height: 100,
                            ),
                            errorWidget: (_, __, ___) =>
                                const Icon(Icons.broken_image),
                          ),
                        ),
                      ),
                      if (_isSaving) const CircularProgressIndicator(),
                    ],
                  ),
                );
              } else if (e is BBCodeBgm) {
                String url;
                if (e.id == 11 || e.id == 23) {
                  url = 'https://bangumi.tv/img/smiles/bgm/${e.id}.gif';
                } else if (e.id < 24) {
                  url = 'https://bangumi.tv/img/smiles/bgm/${e.id}.png';
                } else if (e.id < 33) {
                  url = 'https://bangumi.tv/img/smiles/tv/0${e.id - 23}.gif';
                } else {
                  url = 'https://bangumi.tv/img/smiles/tv/${e.id - 23}.gif';
                }
                return WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: GestureDetector(
                    onTap: () => _showImagePreview(url),
                    child: CachedNetworkImage(
                      imageUrl: url,
                      placeholder: (_, __) => Container(
                        width: 24,
                        height: 24,
                      ),
                    ),
                  ),
                );
              } else if (e is BBCodeSticker) {
                return WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: GestureDetector(
                    onTap: () => _showImagePreview(
                        'https://bangumi.tv/img/smiles/${e.id}.gif'),
                    child: CachedNetworkImage(
                      imageUrl: 'https://bangumi.tv/img/smiles/${e.id}.gif',
                      placeholder: (_, __) => Container(
                        width: 24,
                        height: 24,
                      ),
                    ),
                  ),
                );
              } else {
                return WidgetSpan(
                  child: Icon(
                    (e as Icon).icon,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  alignment: PlaceholderAlignment.top,
                );
              }
            }).toList(),
          ),
          selectionHeightStyle: ui.BoxHeightStyle.max,
        ),
      ],
    );
  }
}
