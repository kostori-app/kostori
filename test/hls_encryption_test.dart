import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/services/download/download_manager.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/cbc.dart';
import 'package:pointycastle/padded_block_cipher/padded_block_cipher_impl.dart';
import 'package:pointycastle/paddings/pkcs7.dart';

void main() {
  test('AES-128 key tags select FFmpeg HLS decryption', () {
    const playlist = '''
#EXTM3U
#EXT-X-KEY:METHOD=AES-128,URI="key.bin"
#EXTINF:5,
seg_000001.ts
#EXT-X-ENDLIST
''';

    expect(hasEncryptedHlsKey(playlist), isTrue);
  });

  test('only encrypted media segments select the encrypted fallback', () {
    const encryptedPlaylist = '''
#EXTM3U
#EXT-X-KEY:METHOD=AES-128,URI="key.bin"
#EXTINF:5,
encrypted.ts
#EXT-X-KEY:METHOD=NONE
#EXT-X-MAP:URI="init.mp4"
#EXTINF:5,
clear.ts
#EXT-X-ENDLIST
''';

    expect(hasEncryptedHlsKey(encryptedPlaylist), isTrue);
    expect(
      hasEncryptedHlsKey(
        '#EXT-X-KEY:METHOD=AES-128,URI="key.bin"\n'
        '#EXT-X-KEY:METHOD=NONE\nclear.ts',
      ),
      isFalse,
    );
    expect(hasEncryptedHlsKey('#EXT-X-KEY:METHOD=NONE,URI=""'), isFalse);
    expect(hasEncryptedHlsKey('#EXT-X-MAP:URI="init.mp4"'), isFalse);
  });

  test('session key encryption in a master playlist is detected', () {
    const playlist =
        '#EXT-X-SESSION-KEY:METHOD=AES-128,URI="key.bin"\n'
        '#EXT-X-STREAM-INF:BANDWIDTH=100000\n'
        'variant.m3u8';

    expect(hasEncryptedHlsKey(playlist), isTrue);
  });

  test('AES-128 segment decrypts with explicit IV', () {
    final key = Uint8List.fromList(List.generate(16, (i) => i));
    final iv = Uint8List.fromList(List.generate(16, (i) => 15 - i));
    final plaintext = utf8.encode('segment payload');
    final cipher =
        PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
          ..init(
            true,
            PaddedBlockCipherParameters(
              ParametersWithIV(KeyParameter(key), iv),
              null,
            ),
          );
    final encrypted = cipher.process(Uint8List.fromList(plaintext));
    final explicitIv =
        '0x${iv.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()}';

    final decrypted = decryptHlsAes128Segment(
      encryptedBytes: encrypted,
      key: key,
      sequence: 0,
      explicitIv: explicitIv,
    );

    expect(decrypted, orderedEquals(plaintext));
  });

  test('AES-128 segment uses media sequence as the default IV', () {
    final key = Uint8List.fromList(List.generate(16, (i) => 15 - i));
    final iv = Uint8List(16)..[15] = 9;
    final plaintext = utf8.encode('resumable segment');
    final cipher =
        PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
          ..init(
            true,
            PaddedBlockCipherParameters(
              ParametersWithIV(KeyParameter(key), iv),
              null,
            ),
          );
    final encrypted = cipher.process(Uint8List.fromList(plaintext));

    final decrypted = decryptHlsAes128Segment(
      encryptedBytes: encrypted,
      key: key,
      sequence: 9,
    );

    expect(decrypted, orderedEquals(plaintext));
  });
}
