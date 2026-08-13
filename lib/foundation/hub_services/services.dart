library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data' show BytesBuilder;

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:kostori/components/components.dart'
    show ToastStyle, ContentDialog;
import 'package:kostori/database/favorites.dart';
import 'package:kostori/database/history.dart';
import 'package:kostori/database/stats.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/foundation/hub_services/hub_keep_alive.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/network/app_dio.dart';
import 'package:kostori/foundation/ai_service/ai_base.dart';
import 'package:kostori/foundation/ai_service/openai_provider_registry.dart';
import 'package:kostori/pages/bangumi/bangumi_calendar_page.dart';
import 'package:kostori/utils/ext.dart';
import 'package:kostori/utils/protocol_parser.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/cbc.dart';
import 'package:pointycastle/padded_block_cipher/padded_block_cipher_impl.dart';
import 'package:pointycastle/paddings/pkcs7.dart';
import 'package:uuid/uuid.dart';

part 'app_service.dart';

part 'base/api_key_manager.dart';

part 'base/base_http_service.dart';

part 'base/base_service.dart';

part 'base/docs_html.dart';

part 'base/middleware.dart';

part 'base/route_registry.dart';

part 'base/server_binder.dart';

part 'headless_service.dart';

part 'hub_client/hub_client.dart';

part 'hub_client/hub_client_actions.dart';

part 'hub_client/hub_client_handler.dart';

part 'hub_client/hub_client_models.dart';

part 'hub_client/hub_client_state.dart';

part 'hub_client/hub_client_utils.dart';

part 'hub_client/hub_emoji_def.dart';

part 'hub_client/hub_sticker_manager.dart';

part 'hub_event.dart';

part 'hub_models.dart';

part 'hub_service/hub_service.dart';

part 'hub_service/hub_service_actions.dart';

part 'hub_service/hub_service_handler.dart';

part 'hub_service/hub_ai_bot.dart';

part 'hub_service/hub_service_models.dart';

part 'hub_service/hub_service_routes.dart';

part 'hub_service/hub_service_upload_handler.dart';

part 'image/hub_image_uploader.dart';

part 'image/upload_config.dart';

part 'lan_discovery/lan_control_handlers.dart';

part 'lan_discovery/lan_control_protocol.dart';

part 'lan_discovery/lan_control_service.dart';

part 'lan_discovery/lan_discovery_models.dart';

part 'lan_discovery/lan_discovery_service.dart';

part 'peer_sync/peer_sync.dart';

part 'satori/satori_adapter.dart';

part 'satori/satori_bot_profiles.dart';

part 'webhook/hub_webhook.dart';

part 'subscription/hub_subscription.dart';

part 'subscription/hub_subscription_runtime.dart';

part 'web_admin/hub_web_admin_service.dart';

class HubCrypto {
  static Uint8List? _key;
  static Uint8List? _iv;

  static void init(String token) {
    final keyBytes = sha256.convert(utf8.encode(token)).bytes;
    final ivBytes = md5.convert(utf8.encode(token)).bytes;
    _key = Uint8List.fromList(keyBytes);
    _iv = Uint8List.fromList(ivBytes);
  }

  static bool get isInitialized => _key != null && _iv != null;

  /// 由指定 token 派生密钥（供服务端按成员各自的 token 逐人加密）
  static (Uint8List key, Uint8List iv) _derive(String token) => (
    Uint8List.fromList(sha256.convert(utf8.encode(token)).bytes),
    Uint8List.fromList(md5.convert(utf8.encode(token)).bytes),
  );

  /// 用指定 token 加密（无副作用，不改变全局密钥）
  static String encryptWith(String token, String plainText) {
    if (token.isEmpty) return plainText;
    try {
      final (k, iv) = _derive(token);
      final cipher = PaddedBlockCipherImpl(
        PKCS7Padding(),
        CBCBlockCipher(AESEngine()),
      );
      cipher.init(
        true,
        PaddedBlockCipherParameters(
          ParametersWithIV(KeyParameter(k), iv),
          null,
        ),
      );
      final input = Uint8List.fromList(utf8.encode(plainText));
      final output = cipher.process(input);
      return base64Encode(output);
    } catch (e) {
      HubLog.warning('HubCrypto', '加密失败：$e');
      return plainText;
    }
  }

  /// 用指定 token 解密
  static String decryptWith(String token, String encrypted) {
    if (token.isEmpty) return encrypted;
    try {
      final (k, iv) = _derive(token);
      final cipher = PaddedBlockCipherImpl(
        PKCS7Padding(),
        CBCBlockCipher(AESEngine()),
      );
      cipher.init(
        false,
        PaddedBlockCipherParameters(
          ParametersWithIV(KeyParameter(k), iv),
          null,
        ),
      );
      final input = base64Decode(encrypted);
      final output = cipher.process(Uint8List.fromList(input));
      return utf8.decode(output);
    } catch (e) {
      HubLog.warning('HubCrypto', '解密失败：$e');
      return encrypted;
    }
  }

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
      final input = Uint8List.fromList(utf8.encode(plainText));
      final output = cipher.process(input);
      return base64Encode(output);
    } catch (e) {
      HubLog.warning('HubCrypto', '加密失败：$e');
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
      HubLog.warning('HubCrypto', '解密失败：$e');
      return encrypted;
    }
  }

  static void clear() {
    _key = null;
    _iv = null;
  }
}

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

/// 聊天消息的子类型，用于 [HubMessage.messageType]。
/// system 仅客户端渲染用，不通过 HubMessage 在网络上传输。
enum HubMessageType { chat, pin, reaction, recall }

/// 远程控制服务
final lanControlServiceProvider = Provider<LanControlService>(
  (ref) => LanControlService.instance,
);

enum UserStatus { online, away, busy, offline }

enum KickReason { kicked, banned, serverBanned, timeout }
