import 'package:antlr4/antlr4.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:kostori/bbcode/bbcode_base_listener.dart';
import 'package:kostori/bbcode/bbcode_elements.dart';
import 'package:kostori/bbcode/generated/BBCodeLexer.dart';
import 'package:kostori/bbcode/generated/BBCodeParser.dart';
import 'package:kostori/components/bangumi_widget.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/utils/io.dart';
import 'package:kostori/utils/translations.dart';
import 'package:url_launcher/url_launcher.dart';

class _QuoteBlock {
  final List<dynamic> items;
  _QuoteBlock(this.items);
}

class BBCodeWidget extends StatefulWidget {
  const BBCodeWidget({
    super.key,
    required this.bbcode,
    this.showImg = true,
    this.onQuoteTap,
  });

  final String bbcode;
  final bool showImg;
  final void Function(String authorName)? onQuoteTap;

  @override
  State<BBCodeWidget> createState() => _BBCodeWidgetState();
}

class _BBCodeWidgetState extends State<BBCodeWidget> {
  bool _isVisible = false;
  final bool _isSaving = false;

  String _normalizeText(String raw) {
    final lines = raw.split('\n');
    final contentLines = lines
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (contentLines.length <= 1) return raw.trim();

    bool justExitedQuote = false;

    final withSpacing = lines
        .map((l) => l.trim())
        .fold<List<String>>([], (acc, line) {
          if (RegExp(r'^\[/quote\]', caseSensitive: false).hasMatch(line)) {
            justExitedQuote = true;
            acc.add(line);
            return acc;
          }
          if (justExitedQuote && line.isEmpty) {
            return acc;
          }
          justExitedQuote = false;
          acc.add(line);
          if (line.isNotEmpty) acc.add('');
          return acc;
        })
        .join('\n');

    return withSpacing.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  List<dynamic> _groupQuotes(List<dynamic> raw) {
    final result = <dynamic>[];
    List<dynamic>? quoteBuffer;

    for (final e in raw) {
      final isQuoted = e is BBCodeText && e.quoted;
      final isQuoteIcon = e is Icon && e.icon == Icons.format_quote;

      if (isQuoted) {
        quoteBuffer ??= [];
        quoteBuffer.add(e);
      } else if (isQuoteIcon && quoteBuffer != null) {
        result.add(_QuoteBlock(List.from(quoteBuffer)));
        quoteBuffer = null;
      } else {
        if (quoteBuffer != null) {
          result.add(_QuoteBlock(List.from(quoteBuffer)));
          quoteBuffer = null;
        }
        result.add(e);
      }
    }

    if (quoteBuffer != null) {
      result.add(_QuoteBlock(List.from(quoteBuffer)));
    }

    return result;
  }

  Widget _buildQuoteCard(BuildContext context, _QuoteBlock block) {
    String? authorName;
    final contentItems = <BBCodeText>[];

    for (final item in block.items) {
      if (item is BBCodeText) {
        if (authorName == null && item.bold) {
          authorName = item.text.trim();
        } else {
          final text = item.text.replaceAll(RegExp(r'\n+'), ' ').trim();
          if (text.isNotEmpty) {
            final cleaned = BBCodeText(text: text);
            cleaned.bold = item.bold;
            cleaned.italic = item.italic;
            cleaned.underline = item.underline;
            cleaned.strikeThrough = item.strikeThrough;
            cleaned.color = item.color;
            cleaned.size = item.size;
            contentItems.add(cleaned);
          }
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: GestureDetector(
        onTap: authorName != null && widget.onQuoteTap != null
            ? () => widget.onQuoteTap!(authorName!)
            : null,
        child: SelectionContainer.disabled(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                border: Border(
                  left: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 4,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Text.rich(
                  TextSpan(
                    children: [
                      if (authorName != null)
                        TextSpan(
                          text: '$authorName ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ...contentItems.map((item) {
                        return TextSpan(
                          text: item.text,
                          style: TextStyle(
                            fontWeight: item.bold ? FontWeight.bold : null,
                            fontStyle: item.italic ? FontStyle.italic : null,
                            fontSize: item.size.toDouble(),
                            color: item.color != null
                                ? _parseColor(item.color!)
                                : Theme.of(context).colorScheme.outline,
                            decoration: TextDecoration.combine([
                              if (item.underline) TextDecoration.underline,
                              if (item.strikeThrough)
                                TextDecoration.lineThrough,
                            ]),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color? _parseColor(String hex) {
    if (hex.startsWith('#')) {
      hex = hex.replaceFirst('#', '');
      if (hex.length == 6) hex = "FF$hex";
      if (hex.length == 8) return Color(int.parse(hex, radix: 16));
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
          title: Text('Image Operations'.tl),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'.tl),
            ),
            TextButton(
              onPressed: () => ImageSaver.saveImageToGallery(imageUrl),
              child: Text('Save to Album'.tl),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    BBCodeParser.checkVersion();
    final input = InputStream.fromString(_normalizeText(widget.bbcode));
    final lexer = BBCodeLexer(input);
    final tokens = CommonTokenStream(lexer);
    final parser = BBCodeParser(tokens);
    final tree = parser.document();
    final bbcodeBaseListener = BBCodeBaseListener();
    ParseTreeWalker.DEFAULT.walk(bbcodeBaseListener, tree);
    bbCodeTag.clear();

    final grouped = _groupQuotes(bbcodeBaseListener.bbcode);
    final List<Widget> children = [];
    final List<dynamic> inlineBuffer = [];
    bool trimNextText = false;

    void flushInline() {
      if (inlineBuffer.isEmpty) return;
      children.add(
        Text.rich(
          TextSpan(
            children: inlineBuffer.map((e) {
              if (e is BBCodeText) {
                Color? textColor = (!_isVisible && e.masked)
                    ? Colors.transparent
                    : (e.link != null)
                    ? Colors.blue
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
                              setState(() => _isVisible = !_isVisible);
                            }
                          }
                        : null,
                  style: TextStyle(
                    fontWeight: e.bold ? FontWeight.bold : null,
                    fontStyle: e.italic ? FontStyle.italic : null,
                    decoration: TextDecoration.combine([
                      if (e.underline || e.link != null)
                        TextDecoration.underline,
                      if (e.strikeThrough) TextDecoration.lineThrough,
                    ]),
                    decorationColor: textColor,
                    fontSize: e.size.toDouble(),
                    color: textColor,
                    backgroundColor: (!_isVisible && e.masked)
                        ? const Color(0xFF555555)
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
                  return url.startsWith('http') ? url : baseUrl + url;
                }

                final img = getFullImageUrl(e.imageUrl);
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
                              context: context,
                              url: img,
                              title: '',
                              heroTag: img,
                            );
                          },
                          onLongPress: () => _showSaveDialog(img),
                          child: Hero(
                            tag: img,
                            flightShuttleBuilder:
                                (
                                  flightContext,
                                  animation,
                                  direction,
                                  fromContext,
                                  toContext,
                                ) {
                                  return direction == HeroFlightDirection.pop
                                      ? (fromContext.widget as Hero).child
                                      : (toContext.widget as Hero).child;
                                },
                            child: Image.network(
                              img,
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: SizedBox(
                                    width: 40,
                                    height: 40,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (_, _, _) =>
                                  const Icon(Icons.broken_image),
                            ),
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
                    onTap: () => BangumiWidget.showImagePreview(
                      context: context,
                      url: url,
                      title: '',
                      heroTag: url,
                    ),
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                      errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
                    ),
                  ),
                );
              } else if (e is BBCodeSticker) {
                return WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: GestureDetector(
                    onTap: () => BangumiWidget.showImagePreview(
                      context: context,
                      url: 'https://bangumi.tv/img/smiles/${e.id}.gif',
                      title: '',
                      heroTag: 'https://bangumi.tv/img/smiles/${e.id}.gif',
                    ),
                    child: Image.network(
                      'https://bangumi.tv/img/smiles/${e.id}.gif',
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                      errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
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
        ),
      );
      inlineBuffer.clear();
    }

    for (final e in grouped) {
      if (e is _QuoteBlock) {
        flushInline();
        children.add(_buildQuoteCard(context, e));
        trimNextText = true;
      } else {
        if (trimNextText && e is BBCodeText) {
          e.text = e.text.replaceAll(RegExp(r'^\n+'), '');
          trimNextText = false;
        }
        inlineBuffer.add(e);
      }
    }
    flushInline();

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
