import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/i18n/strings.g.dart';

enum KostoriRouteType {
  anime('a', '番剧'),
  bangumi('b', 'Bangumi'),
  character('c', '角色'),
  person('d', '人物'),
  remote('r', '远程控制'),
  unknown('?', '未知');

  final String code;
  final String label;

  const KostoriRouteType(this.code, this.label);

  static KostoriRouteType fromCode(String code) {
    return KostoriRouteType.values.firstWhere(
      (t) => t.code == code.toLowerCase(),
      orElse: () => KostoriRouteType.unknown,
    );
  }
}

/// 远程控制协议解析结果
class RemoteControlProtocol {
  final String deviceId;
  final String deviceName;
  final String token;
  final int port;
  final String? ip;

  const RemoteControlProtocol({
    required this.deviceId,
    required this.deviceName,
    required this.token,
    required this.port,
    this.ip,
  });

  /// WebSocket 连接地址
  String get wsUrl => 'ws://${ip ?? 'auto'}:$port/hub';

  /// 是否有效（基于 token）
  bool get isValid => token.isNotEmpty;
}

class ParsedProtocol {
  final KostoriRouteType type;

  final String payload;

  final String rawInput;

  final String resolvedProtocol;

  final bool wasBase64;

  /// 远程控制协议的额外信息（仅当 type == KostoriRouteType.remote 时有效）
  final RemoteControlProtocol? remoteInfo;

  const ParsedProtocol({
    required this.type,
    required this.payload,
    required this.rawInput,
    required this.resolvedProtocol,
    this.wasBase64 = false,
    this.remoteInfo,
  });

  bool get isRoutable => type != KostoriRouteType.unknown;

  bool get isRemoteControl => type == KostoriRouteType.remote;

  @override
  String toString() =>
      'ParsedProtocol(type=${type.label}, payload=$payload, wasBase64=$wasBase64)';
}

void showKostoriShareSheet(
  BuildContext context,
  WidgetRef ref, {
  required KostoriRouteType type,
  required String payload,
  required String title,
  String? subtitle,
  String? backgroundImagePath,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => Sheet(
      title: t.share,
      icon: Icons.share_outlined,
      initialSize: 0.3,
      builder: (ctx, sc) => Column(
        children: [
          ListTile(
            leading: const Icon(Icons.text_fields_outlined),
            title: const Text('复制文本口令'),
            onTap: () {
              Navigator.pop(ctx);
              final token = ProtocolParser.encodeWithBase64Payload(
                type,
                payload,
              );
              Clipboard.setData(ClipboardData(text: token));
              App.rootContext.showMessage(message: t.tokenCopiedToClipboard);
            },
          ),
          ListTile(
            leading: const Icon(Icons.qr_code_outlined),
            title: Text(t.generateQrCodeShare),
            onTap: () {
              Navigator.pop(ctx);
              showQrShareSheet(
                context,
                ref,
                config: QrShareConfig(
                  content: ProtocolParser.encodeWithBase64Payload(
                    type,
                    payload,
                  ),
                  title: title,
                  subtitle: subtitle,
                  backgroundImagePath: backgroundImagePath,
                  exportWidth: 400,
                ),
              );
            },
          ),
        ],
      ),
    ),
  );
}

class ProtocolParser {
  ProtocolParser._();

  static final _protocolRegex = RegExp(
    r'^kostori:@#([a-zA-Z])(.+)$',
    dotAll: true,
  );

  static final _base64Regex = RegExp(r'^[A-Za-z0-9+/\-_]{8,}={0,2}$');

  static ParsedProtocol? parse(String input) {
    final text = input.trim();
    if (text.isEmpty) return null;

    // 1. 直接匹配协议
    final direct = _matchProtocol(text);
    if (direct != null) {
      // 检查是否是远程控制协议
      if (direct.$1 == KostoriRouteType.remote) {
        return _parseRemotePayload(direct.$2, text, false);
      }
      return ParsedProtocol(
        type: direct.$1,
        payload: direct.$2,
        rawInput: text,
        resolvedProtocol: text,
        wasBase64: false,
      );
    }

    // 2. 尝试 Base64 解码后再匹配
    if (_base64Regex.hasMatch(text)) {
      final decoded = _tryBase64Decode(text);
      if (decoded != null) {
        final inner = _matchProtocol(decoded.trim());
        if (inner != null) {
          // 检查是否是远程控制协议
          if (inner.$1 == KostoriRouteType.remote) {
            return _parseRemotePayload(inner.$2, text, true);
          }
          return ParsedProtocol(
            type: inner.$1,
            payload: inner.$2,
            rawInput: text,
            resolvedProtocol: decoded.trim(),
            wasBase64: true,
          );
        }
      }
    }

    return null;
  }

  /// 解析远程控制协议的有效载荷
  /// 格式: deviceId|name|token|port
  static ParsedProtocol? _parseRemotePayload(
    String payload,
    String rawInput,
    bool wasBase64,
  ) {
    try {
      final parts = payload.split('|');
      if (parts.length < 3) return null;

      final deviceId = parts[0];
      final deviceName = parts.length > 1 ? parts[1] : 'Unknown';
      final token = parts[2];
      final port = parts.length > 3 ? int.tryParse(parts[3]) ?? 42183 : 42183;

      final remoteInfo = RemoteControlProtocol(
        deviceId: deviceId,
        deviceName: deviceName,
        token: token,
        port: port,
      );

      return ParsedProtocol(
        type: KostoriRouteType.remote,
        payload: payload,
        rawInput: rawInput,
        resolvedProtocol: wasBase64 ? payload : rawInput,
        wasBase64: wasBase64,
        remoteInfo: remoteInfo,
      );
    } catch (e) {
      return null;
    }
  }

  static bool looksLikeProtocol(String text) {
    final t = text.trim();
    return t.startsWith('kostori:') || _base64Regex.hasMatch(t);
  }

  static String encode(KostoriRouteType type, String payload) {
    assert(type != KostoriRouteType.unknown, '不能编码 unknown 类型');
    return 'kostori:@#${type.code}$payload';
  }

  static String encodeBase64(KostoriRouteType type, String payload) {
    final raw = encode(type, payload);
    return base64UrlEncode(utf8.encode(raw)); // URL-safe Base64，无填充问题
  }

  static String? decodeBase64Token(String token) {
    return _tryBase64Decode(token);
  }

  static (KostoriRouteType, String)? _matchProtocol(String text) {
    final match = _protocolRegex.firstMatch(text);
    if (match == null) return null;
    final typeChar = match.group(1)!;
    final rawPayload = match.group(2)!;

    final payload = _tryBase64Decode(rawPayload) ?? rawPayload;

    return (KostoriRouteType.fromCode(typeChar), payload);
  }

  static String? _tryBase64Decode(String text) {
    final normalized = text.replaceAll('-', '+').replaceAll('_', '/');
    final padded = normalized.padRight((normalized.length + 3) ~/ 4 * 4, '=');
    try {
      return utf8.decode(base64Decode(padded));
    } catch (_) {
      return null;
    }
  }

  static String encodeWithBase64Payload(KostoriRouteType type, String payload) {
    final encodedPayload = base64UrlEncode(utf8.encode(payload));
    return 'kostori:@#${type.code}$encodedPayload';
  }
}
