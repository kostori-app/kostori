import 'package:antlr4/antlr4.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/bbcode/bbcode_base_listener.dart';
import 'package:kostori/bbcode/bbcode_elements.dart';
import 'package:kostori/bbcode/generated/BBCodeLexer.dart';
import 'package:kostori/bbcode/generated/BBCodeParser.dart';

List<dynamic> _parse(String input) {
  final lexer = BBCodeLexer(InputStream.fromString(input));
  final parser = BBCodeParser(CommonTokenStream(lexer));
  final listener = BBCodeBaseListener();
  ParseTreeWalker.DEFAULT.walk(listener, parser.document());
  return listener.bbcode;
}

void main() {
  group('BBCode', () {
    test('musume 解析为 BBCodeMusume 并取到 id', () {
      final result = _parse('(musume_07)');
      final musume = result.whereType<BBCodeMusume>().single;
      expect(musume.id, 7);
    });

    test('sticker 序号不因 musume 规则插入而错位', () {
      final result = _parse('(=A=)(LOL)');
      final stickers = result.whereType<BBCodeSticker>().toList();
      expect(stickers.length, 2);
      expect(stickers[0].id, 1);
      expect(stickers[1].id, 16);
    });

    test('bgm 仍按数字 id 解析', () {
      final result = _parse('(bgm38)');
      final bgm = result.whereType<BBCodeBgm>().single;
      expect(bgm.id, 38);
    });
  });
}
