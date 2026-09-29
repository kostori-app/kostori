import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:kostori/foundation/app.dart';
import 'package:path/path.dart' as p;
import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/cbc.dart';
import 'package:pointycastle/padded_block_cipher/padded_block_cipher_impl.dart';
import 'package:pointycastle/paddings/pkcs7.dart';

/// 本地静态数据加密（AES-256-CBC，随机 IV 前置）。
/// 用于在磁盘上保护 API Key、OSS Secret、Hub Token、房间密码等敏感字段。
/// 密钥为每台设备独立的随机文件，因此加密数据无法跨设备直接移植，
/// 需要导出的场景（如房间配置导出）会由调用方显式使用明文。
class SecretVault {
  SecretVault._();

  static Uint8List? _key;

  static String get _keyPath => p.join(App.dataPath, 'hub_secret.key');

  static Uint8List _getKey() {
    final cached = _key;
    if (cached != null) return cached;
    try {
      final file = File(_keyPath);
      if (file.existsSync()) {
        final decoded = base64Decode(file.readAsStringSync().trim());
        if (decoded.length == 32) {
          _key = decoded;
          return decoded;
        }
      }
      final generated = _randomBytes(32);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(base64Encode(generated));
      _key = generated;
      return generated;
    } catch (_) {
      final fallback = sha256
          .convert(utf8.encode('kostori-hub-secret-fallback'))
          .bytes;
      _key = Uint8List.fromList(fallback);
      return _key!;
    }
  }

  static Uint8List _randomBytes(int length) {
    final rand = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => rand.nextInt(256)));
  }

  static const _prefix = 'enc:';

  static bool isEncrypted(String value) => value.startsWith(_prefix);

  /// 加密明文。空串直接返回（保持空语义）。
  static String encrypt(String plain) {
    if (plain.isEmpty) return plain;
    try {
      final key = _getKey();
      final iv = _randomBytes(16);
      final cipher = PaddedBlockCipherImpl(
        PKCS7Padding(),
        CBCBlockCipher(AESEngine()),
      );
      cipher.init(
        true,
        PaddedBlockCipherParameters(
          ParametersWithIV(KeyParameter(key), iv),
          null,
        ),
      );
      final out = cipher.process(Uint8List.fromList(utf8.encode(plain)));
      return '$_prefix${base64Encode([...iv, ...out])}';
    } catch (_) {
      return plain;
    }
  }

  /// 解密已加密串。若未加密（旧数据 / 明文导入）则原样返回。
  static String decrypt(String stored) {
    if (!stored.startsWith(_prefix)) return stored;
    try {
      final raw = base64Decode(stored.substring(_prefix.length));
      if (raw.length <= 16) return stored;
      final iv = Uint8List.sublistView(raw, 0, 16);
      final data = Uint8List.sublistView(raw, 16);
      final cipher = PaddedBlockCipherImpl(
        PKCS7Padding(),
        CBCBlockCipher(AESEngine()),
      );
      cipher.init(
        false,
        PaddedBlockCipherParameters(
          ParametersWithIV(KeyParameter(_getKey()), iv),
          null,
        ),
      );
      return utf8.decode(cipher.process(Uint8List.fromList(data)));
    } catch (_) {
      return stored;
    }
  }

  /// 仅保留少量前缀，其余打码，用于日志输出。
  static String mask(String value) {
    if (value.isEmpty) return '(empty)';
    if (value.length <= 4) return '***';
    return '${value.substring(0, 2)}****${value.substring(value.length - 2)}';
  }
}
