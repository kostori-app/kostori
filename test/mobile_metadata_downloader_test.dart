import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dtorrent_task_v2/dtorrent_task_v2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/services/torrent/mobile_metadata_downloader.dart';

final _metadata = Uint8List.fromList(ascii.encode('d4:name8:test.bine'));
final _hash = sha1.convert(_metadata);

/// 禁止依赖构造函数里的公网 IP 探测；所有 peer 都由本地服务器提供。
class _NoExternalHttp implements HttpClient {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw const SocketException('external HTTP disabled in test');
}

MobileMetadataDownloader _downloader({Duration? peerTimeout}) =>
    HttpOverrides.runZoned(
      () => MobileMetadataDownloader(
        _hash.toString(),
        trackers: const [],
        maxConnections: 1,
        connectTimeout: const Duration(milliseconds: 500),
        peerTimeout: peerTimeout ?? const Duration(seconds: 2),
      ),
      createHttpClient: (_) => _NoExternalHttp(),
    );

class _LocalPeer {
  _LocalPeer(this.server, this.provideMetadata) {
    server.listen(_accept);
  }

  static Future<_LocalPeer> start({bool provideMetadata = false}) async =>
      _LocalPeer(
        await ServerSocket.bind(InternetAddress.loopbackIPv4, 0),
        provideMetadata,
      );

  final ServerSocket server;
  final bool provideMetadata;
  final connected = Completer<void>();
  final disconnected = Completer<void>();
  final sockets = <Socket>[];

  CompactAddress get address =>
      CompactAddress(InternetAddress.loopbackIPv4, server.port);

  void _accept(Socket socket) {
    sockets.add(socket);
    if (!connected.isCompleted) connected.complete();
    var buffer = <int>[];
    var handshaken = false;
    var metadataId = 1;
    socket.listen(
      (bytes) {
        if (!provideMetadata) return;
        buffer.addAll(bytes);
        if (!handshaken) {
          if (buffer.length < 68) return;
          buffer = buffer.sublist(68);
          handshaken = true;
          socket.add([
            19,
            ...ascii.encode('BitTorrent protocol'),
            0,
            0,
            0,
            0,
            0,
            0x10,
            0,
            0,
            ..._hash.bytes,
            ...ascii.encode('-TEST00-000000000000'),
          ]);
          _sendExtended(
            socket,
            0,
            ascii.encode(
              'd1:md11:ut_metadatai1ee13:metadata_sizei${_metadata.length}ee',
            ),
          );
        }
        while (buffer.length >= 4) {
          final size = ByteData.sublistView(
            Uint8List.fromList(buffer.sublist(0, 4)),
          ).getUint32(0);
          if (buffer.length < size + 4) break;
          final message = buffer.sublist(4, size + 4);
          buffer = buffer.sublist(size + 4);
          if (message.length < 2 || message[0] != 20) continue;
          if (message[1] == 0) {
            final match = RegExp(r'11:ut_metadatai(\d+)e')
                .firstMatch(String.fromCharCodes(message.sublist(2)));
            if (match != null) metadataId = int.parse(match[1]!);
          } else if (message[1] == 1) {
            _sendExtended(socket, metadataId, [
              ...ascii.encode(
                'd8:msg_typei1e5:piecei0e10:total_sizei${_metadata.length}ee',
              ),
              ..._metadata,
            ]);
          }
        }
      },
      onDone: () {
        if (!disconnected.isCompleted) disconnected.complete();
      },
      onError: (Object _) {
        if (!disconnected.isCompleted) disconnected.complete();
      },
    );
  }

  void _sendExtended(Socket socket, int extension, List<int> payload) {
    final size = ByteData(4)..setUint32(0, payload.length + 2);
    socket.add([...size.buffer.asUint8List(), 20, extension, ...payload]);
  }

  Future<void> close() async {
    for (final socket in sockets) {
      socket.destroy();
    }
    await server.close();
  }
}

void main() {
  setUp(() async {
    final cache = await Directory.systemTemp.createTemp('kostori_metadata_');
    MetadataDownloader.setCacheDirectory(cache.path);
    addTearDown(() async {
      MetadataDownloader.setCacheDirectory(null);
      await cache.delete(recursive: true);
    });
  });

  test(
    'failed first peer releases its slot and next peer supplies metadata',
    () async {
      final unused = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final dead = CompactAddress(InternetAddress.loopbackIPv4, unused.port);
      await unused.close();
      final live = await _LocalPeer.start(provideMetadata: true);
      addTearDown(live.close);
      final downloader = _downloader();
      addTearDown(downloader.stop);
      final result = Completer<List<int>>();
      downloader.createListener().on<MetaDataDownloadComplete>((event) {
        if (!result.isCompleted) result.complete(event.data);
      });
      downloader.addNewPeerAddress(dead, PeerSource.tracker);
      downloader.addNewPeerAddress(live.address, PeerSource.tracker);
      await downloader.startDownload();
      expect(
        await result.future.timeout(const Duration(seconds: 5)),
        orderedEquals(_metadata),
      );
    },
  );

  test(
    'silent peer is recycled so a later tracker peer can be tried',
    () async {
      final silent = await _LocalPeer.start();
      final live = await _LocalPeer.start(provideMetadata: true);
      addTearDown(silent.close);
      addTearDown(live.close);
      final downloader = _downloader(
        peerTimeout: const Duration(milliseconds: 250),
      );
      addTearDown(downloader.stop);
      final result = Completer<List<int>>();
      downloader.createListener().on<MetaDataDownloadComplete>((event) {
        if (!result.isCompleted) result.complete(event.data);
      });
      downloader.addNewPeerAddress(silent.address, PeerSource.tracker);
      downloader.addNewPeerAddress(live.address, PeerSource.tracker);
      await downloader.startDownload();
      expect(
        await result.future.timeout(const Duration(seconds: 5)),
        orderedEquals(_metadata),
      );
      await silent.disconnected.future.timeout(const Duration(seconds: 2));
    },
  );

  test('cancel closes active sockets and never starts queued peers', () async {
    final first = await _LocalPeer.start();
    final queued = await _LocalPeer.start();
    addTearDown(first.close);
    addTearDown(queued.close);
    final downloader = _downloader();
    downloader.addNewPeerAddress(first.address, PeerSource.tracker);
    downloader.addNewPeerAddress(queued.address, PeerSource.tracker);
    await downloader.startDownload();
    await first.connected.future.timeout(const Duration(seconds: 2));
    final stopping = downloader.stop();
    expect(identical(stopping, downloader.stop()), isTrue);
    await stopping;
    await first.disconnected.future.timeout(const Duration(seconds: 2));
    expect(queued.connected.isCompleted, isFalse);
    expect(downloader.debugSummary, contains('queued=0 active=0'));
  });

  test('cancel during startup waits for final cleanup', () async {
    final peer = await _LocalPeer.start();
    addTearDown(peer.close);
    final downloader = _downloader();
    downloader.addNewPeerAddress(peer.address, PeerSource.tracker);
    final starting = downloader.startDownload();
    await downloader.stop();
    await starting;
    expect(peer.connected.isCompleted, isFalse);
    expect(downloader.debugSummary, contains('queued=0 active=0'));
  });
}
