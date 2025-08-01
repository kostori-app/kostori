import 'dart:ui' as ui;

import 'package:antlr4/antlr4.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:kostori/bbcode/bbcode_base_listener.dart';
import 'package:kostori/bbcode/bbcode_elements.dart';
import 'package:kostori/bbcode/generated/BBCodeLexer.dart';
import 'package:kostori/bbcode/generated/BBCodeParser.dart';
import 'package:kostori/components/bangumi_widget.dart';
import 'package:kostori/foundation/log.dart';
import 'package:url_launcher/url_launcher.dart';

class BBCodeWidget extends StatefulWidget {
  const BBCodeWidget({super.key, required this.bbcode, this.showImg = true});

  final String bbcode;
  final bool showImg;

  @override
  State<BBCodeWidget> createState() => _BBCodeWidgetState();
}

class _BBCodeWidgetState extends State<BBCodeWidget> {
  bool _isVisible = false;
  final bool _isSaving = false;

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

  void _showSaveDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('图片操作'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                BangumiWidget.saveImageToGallery(context, imageUrl);
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
                    backgroundColor: (!_isVisible && e.masked)
                        ? Color(0xFF555555)
                        : null,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                );
              } else if (e is BBCodeImg) {
                if (!widget.showImg) return const WidgetSpan(child: SizedBox());
                String getFullImageUrl(
                  String url, {
                  String baseUrl = 'https://lain.bgm.tv/pic/photo/g/',
                }) {
                  if (url.startsWith('http')) {
                    return url;
                  } else {
                    return baseUrl + url;
                  }
                }

                String img = getFullImageUrl(e.imageUrl);

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
                            Log.addLog(LogLevel.info, 'imageUrl', img);
                            BangumiWidget.showImagePreview(
                              context,
                              img,
                              '',
                              img,
                            );
                          },
                          onLongPress: () => _showSaveDialog(img),
                          child: Hero(
                            tag: img,
                            child: BangumiWidget.kostoriImage(context, img),
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
                    onTap: () =>
                        BangumiWidget.showImagePreview(context, url, '', url),
                    child: BangumiWidget.kostoriImage(
                      context,
                      url,
                      width: 24,
                      height: 24,
                    ),
                  ),
                );
              } else if (e is BBCodeSticker) {
                return WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: GestureDetector(
                    onTap: () => BangumiWidget.showImagePreview(
                      context,
                      'https://bangumi.tv/img/smiles/${e.id}.gif',
                      '',
                      'https://bangumi.tv/img/smiles/${e.id}.gif',
                    ),
                    child: Hero(
                      tag: 'https://bangumi.tv/img/smiles/${e.id}.gif',
                      child: BangumiWidget.kostoriImage(
                        context,
                        'https://bangumi.tv/img/smiles/${e.id}.gif',
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
