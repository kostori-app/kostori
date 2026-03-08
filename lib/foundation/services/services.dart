library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/utils/ext.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/cbc.dart';
import 'package:pointycastle/padded_block_cipher/padded_block_cipher_impl.dart';
import 'package:pointycastle/paddings/pkcs7.dart';

part 'app_service.dart';

part 'base/api_key_manager.dart';

part 'base/base_http_service.dart';

part 'base/base_service.dart';

part 'base/middleware.dart';

part 'base/route_registry.dart';

part 'base/server_binder.dart';

part 'headless_service.dart';

part 'hub_client.dart';

part 'hub_service.dart';

class HubCrypto {
  static Uint8List? _key;
  static Uint8List? _iv;

  static void init(String token) {
    // 用 SHA-256 派生 32 字节密钥
    final keyBytes = sha256.convert(utf8.encode(token)).bytes;
    // 用 MD5 派生 16 字节 IV
    final ivBytes = md5.convert(utf8.encode(token)).bytes;
    _key = Uint8List.fromList(keyBytes);
    _iv = Uint8List.fromList(ivBytes);
  }

  static bool get isInitialized => _key != null && _iv != null;

  static String encrypt(String plainText) {
    if (!isInitialized) return plainText;
    try {
      final cipher = PaddedBlockCipherImpl(
        PKCS7Padding(),
        CBCBlockCipher(AESEngine()),
      );
      cipher.init(
        true,
        PaddedBlockCipherParameters(
          ParametersWithIV(KeyParameter(_key!), _iv!),
          null,
        ),
      );
      // ← 不手动 pad，直接传原始数据
      final input = Uint8List.fromList(utf8.encode(plainText));
      final output = cipher.process(input);
      return base64Encode(output);
    } catch (e) {
      Log.warning('HubCrypto', '加密失败：$e');
      return plainText;
    }
  }

  static String decrypt(String encrypted) {
    if (!isInitialized) return encrypted;
    try {
      final cipher = PaddedBlockCipherImpl(
        PKCS7Padding(),
        CBCBlockCipher(AESEngine()),
      );
      cipher.init(
        false,
        PaddedBlockCipherParameters(
          ParametersWithIV(KeyParameter(_key!), _iv!),
          null,
        ),
      );
      final input = base64Decode(encrypted);
      final output = cipher.process(Uint8List.fromList(input));
      return utf8.decode(output);
    } catch (e) {
      Log.warning('HubCrypto', '解密失败：$e');
      return encrypted;
    }
  }

  static void clear() {
    _key = null;
    _iv = null;
  }
}
