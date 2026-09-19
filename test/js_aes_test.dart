import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/foundation/js_engine.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/cbc.dart';

Uint8List _aesCbcEncrypt(Uint8List data, Uint8List key, Uint8List iv) {
  final cipher = CBCBlockCipher(AESEngine())
    ..init(true, ParametersWithIV(KeyParameter(key), iv));
  final out = Uint8List(data.length);
  var offset = 0;
  while (offset < data.length) {
    offset += cipher.processBlock(data, offset, out, offset);
  }
  return out;
}

void main() {
  final key = Uint8List.fromList(List.generate(16, (i) => i));
  final iv = Uint8List.fromList(List.generate(16, (i) => 15 - i));
  final plain = Uint8List.fromList(
    List.generate(64, (i) => (i * 7) & 0xff),
  );

  test('aesDecryptBytes 能解出原文（AES-128-CBC）', () {
    final cipherText = _aesCbcEncrypt(plain, key, iv);
    expect(cipherText, isNot(plain));
    expect(
      aesDecryptBytes(mode: 'aes-cbc', data: cipherText, key: key, iv: iv),
      plain,
    );
  });

  test('aesDecryptBytes 可在后台 isolate 里执行', () async {
    final cipherText = _aesCbcEncrypt(plain, key, iv);
    final out = await Isolate.run(
      () => aesDecryptBytes(mode: 'aes-cbc', data: cipherText, key: key, iv: iv),
    );
    expect(out, plain);
  });

  test('未知模式报错', () {
    expect(
      () => aesDecryptBytes(mode: 'aes-xxx', data: plain, key: key),
      throwsArgumentError,
    );
  });
}
