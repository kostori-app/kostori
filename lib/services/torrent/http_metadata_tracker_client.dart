import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dtorrent_task_v2/dtorrent_task_v2.dart' show CompactAddress;
import 'package:kostori/services/torrent/torrent_network.dart';

/// 元数据发现的 HTTP(S) 通道：每个 tracker 独立超时，结束抓取时关闭所有请求。
class HttpMetadataTrackerClient {
  HttpMetadataTrackerClient({
    this.timeout = const Duration(seconds: 12),
    this.onLog,
  });

  final Duration timeout;
  final void Function(String message)? onLog;
  final Set<HttpClient> _clients = {};
  bool _closed = false;

  Future<List<CompactAddress>> announce(
    Uri tracker,
    Uint8List infoHash, {
    required String peerId,
  }) async {
    if (_closed) return const [];
    if (infoHash.length != 20 ||
        peerId.length != 20 ||
        peerId.codeUnits.any((byte) => byte > 255)) {
      throw ArgumentError('info_hash and peer_id must both be 20 bytes');
    }
    try {
      // 原始 20 字节分别转义，不能先转成 UTF-8 或再次编码百分号。
      String encodeBytes(Iterable<int> bytes) => bytes
          .map((byte) => '%${byte.toRadixString(16).padLeft(2, '0')}')
          .join();
      final uri = tracker.replace(
        query: [
          if (tracker.query.isNotEmpty) tracker.query,
          'info_hash=${encodeBytes(infoHash)}',
          'peer_id=${encodeBytes(peerId.codeUnits)}',
          'port=6881',
          'uploaded=0',
          'downloaded=0',
          'left=327680',
          'compact=1',
          'numwant=50',
          'event=started',
        ].join('&'),
      );
      // Android 的 VPN 会接管 Dart 的 DIRECT socket；让原生层把请求
      // 绑定到物理网络。其它平台继续使用不继承系统代理的 HttpClient。
      final nativeResponse = await TorrentNetwork.announceHttp(uri)
          .timeout(timeout);
      final peers = nativeResponse != null
          ? _decodeResponse(nativeResponse)
          : Platform.isAndroid && await TorrentNetwork.isVpnActive()
          ? const <CompactAddress>[]
          : await _announceDart(uri);
      if (_closed) {
        return const [];
      }
      if (peers.isNotEmpty) {
        onLog?.call('${tracker.host}: peers=${peers.length}');
      }
      return peers;
    } catch (_) {
      // Tracker 拒绝、连接重置和超时都是常见的单点失败，不逐条刷日志。
      return const [];
    }
  }

  Future<List<CompactAddress>> _announceDart(Uri uri) async {
    final dartClient = TorrentNetwork.createHttpClient()
      ..connectionTimeout = timeout;
    _clients.add(dartClient);
    try {
      // 覆盖 DNS、连接、响应头和整个响应体；只给响应头设超时会无限等正文。
      return await _readResponse(dartClient, uri).timeout(timeout);
    } finally {
      _clients.remove(dartClient);
      dartClient.close(force: true);
    }
  }

  Future<List<CompactAddress>> _readResponse(HttpClient client, Uri uri) async {
    final request = await client.getUrl(uri);
    request.headers.set(HttpHeaders.userAgentHeader, 'Kostori/1.0');
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('HTTP ${response.statusCode}');
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response) {
      builder.add(chunk);
      if (builder.length > 1024 * 1024) {
        throw const FormatException('tracker response too large');
      }
    }
    return _decodeResponse(builder.takeBytes());
  }

  List<CompactAddress> _decodeResponse(Uint8List bytes) {
    final value = _decodeTrackerBencode(_BencodeCursor(bytes));
    if (value is! Map) throw const FormatException('invalid tracker response');
    final failure = value['failure reason'];
    if (failure != null) {
      final reason = failure is Uint8List
          ? utf8.decode(failure, allowMalformed: true)
          : '$failure';
      throw FormatException('tracker rejected announce: $reason');
    }
    return [
      ..._trackerPeers(value['peers']),
      ..._trackerPeers(value['peers6'], ipv6: true),
    ];
  }

  void close() {
    _closed = true;
    for (final client in _clients) {
      client.close(force: true);
    }
    _clients.clear();
  }
}

class _BencodeCursor {
  _BencodeCursor(this.bytes);
  final Uint8List bytes;
  var offset = 0;
}

/// Tracker responses are small bencoded dictionaries. Decode only the value
/// shapes needed for `peers`/`peers6`, keeping this fallback independent of the
/// dependency's tracker event loop (which can stall on mobile networks).
Object? _decodeTrackerBencode(_BencodeCursor cursor, [int depth = 0]) {
  if (depth > 32) throw const FormatException('tracker nesting too deep');
  if (cursor.offset >= cursor.bytes.length) {
    throw const FormatException('truncated tracker response');
  }
  final marker = cursor.bytes[cursor.offset];
  if (marker == 0x64) {
    cursor.offset++;
    final map = <String, Object?>{};
    while (cursor.offset < cursor.bytes.length &&
        cursor.bytes[cursor.offset] != 0x65) {
      final key = _decodeTrackerBencode(cursor, depth + 1);
      if (key is! Uint8List) throw const FormatException('invalid tracker key');
      final value = _decodeTrackerBencode(cursor, depth + 1);
      map[String.fromCharCodes(key)] = value;
    }
    if (cursor.offset >= cursor.bytes.length) {
      throw const FormatException('unterminated tracker dictionary');
    }
    cursor.offset++;
    return map;
  }
  if (marker == 0x6c) {
    cursor.offset++;
    final list = <Object?>[];
    while (cursor.offset < cursor.bytes.length &&
        cursor.bytes[cursor.offset] != 0x65) {
      list.add(_decodeTrackerBencode(cursor, depth + 1));
    }
    if (cursor.offset >= cursor.bytes.length) {
      throw const FormatException('unterminated tracker list');
    }
    cursor.offset++;
    return list;
  }
  if (marker == 0x69) {
    cursor.offset++;
    final end = cursor.bytes.indexOf(0x65, cursor.offset);
    if (end < 0) throw const FormatException('unterminated tracker integer');
    final value = int.tryParse(
      String.fromCharCodes(cursor.bytes.sublist(cursor.offset, end)),
    );
    if (value == null) throw const FormatException('invalid tracker integer');
    cursor.offset = end + 1;
    return value;
  }
  final colon = cursor.bytes.indexOf(0x3a, cursor.offset);
  if (colon <= cursor.offset) {
    throw const FormatException('invalid tracker byte string');
  }
  final length = int.tryParse(
    String.fromCharCodes(cursor.bytes.sublist(cursor.offset, colon)),
  );
  if (length == null || length < 0) {
    throw const FormatException('invalid tracker byte string length');
  }
  final start = colon + 1;
  final end = start + length;
  if (end > cursor.bytes.length) {
    throw const FormatException('truncated tracker byte string');
  }
  cursor.offset = end;
  return Uint8List.sublistView(cursor.bytes, start, end);
}

List<CompactAddress> _trackerPeers(Object? value, {bool ipv6 = false}) {
  if (value is Uint8List || value is List<int>) {
    final bytes = value is Uint8List
        ? value
        : Uint8List.fromList(value as List<int>);
    final stride = ipv6 ? 18 : 6;
    final out = <CompactAddress>[];
    for (var offset = 0; offset + stride <= bytes.length; offset += stride) {
      final addressBytes = Uint8List.sublistView(
        bytes,
        offset,
        offset + stride - 2,
      );
      final ip = InternetAddress.fromRawAddress(
        addressBytes,
        type: ipv6 ? InternetAddressType.IPv6 : InternetAddressType.IPv4,
      );
      final port =
          (bytes[offset + stride - 2] << 8) | bytes[offset + stride - 1];
      if (port > 0) out.add(CompactAddress(ip, port));
    }
    return out;
  }
  if (value is List) {
    final out = <CompactAddress>[];
    for (final item in value) {
      if (item is! Map) continue;
      final rawIp = item['ip'];
      final ip = InternetAddress.tryParse(
        rawIp is Uint8List
            ? String.fromCharCodes(rawIp)
            : rawIp?.toString() ?? '',
      );
      final port = int.tryParse(item['port']?.toString() ?? '');
      if (ip != null && port != null && port > 0 && port <= 65535) {
        out.add(CompactAddress(ip, port));
      }
    }
    return out;
  }
  return const [];
}
