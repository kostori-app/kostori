import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/services/torrent/http_metadata_tracker_client.dart';

void main() {
  final infoHash = Uint8List.fromList(List.generate(20, (i) => 128 + i));
  const peerId = '-KO0001-000000000000';

  test(
    'announces binary hash and 20-byte peer ID, parses IPv4/IPv6 peers',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final query = Completer<String>();
      server.listen((request) async {
        query.complete(request.uri.query);
        final ipv6 = InternetAddress('2001:db8::1').rawAddress;
        request.response.add([
          ...ascii.encode('d5:peers6:'),
          127,
          0,
          0,
          1,
          0x1a,
          0xe1,
          ...ascii.encode('6:peers618:'),
          ...ipv6,
          0x1a,
          0xe2,
          ...ascii.encode('e'),
        ]);
        await request.response.close();
      });
      final client = HttpMetadataTrackerClient();
      addTearDown(client.close);
      final peers = await client.announce(
        Uri.parse('http://127.0.0.1:${server.port}/announce?token=secret'),
        infoHash,
        peerId: peerId,
      );
      final sentQuery = await query.future;
      expect(sentQuery, contains('token=secret'));
      expect(
        sentQuery.toLowerCase(),
        contains(
          'info_hash=${infoHash.map((b) => '%${b.toRadixString(16)}').join()}',
        ),
      );
      final encodedPeerId = sentQuery
          .split('&')
          .firstWhere((entry) => entry.startsWith('peer_id='))
          .substring('peer_id='.length);
      expect(Uri.decodeComponent(encodedPeerId), peerId);
      expect(peers.map((peer) => peer.port), [6881, 6882]);
      expect(peers.last.address.type, InternetAddressType.IPv6);
    },
  );

  test('response body stalls time out and release the request', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.add(ascii.encode('d5:peers'));
      await request.response.flush();
    });
    final client = HttpMetadataTrackerClient(
      timeout: const Duration(milliseconds: 150),
    );
    addTearDown(client.close);
    final peers = await client
        .announce(
          Uri.parse('http://127.0.0.1:${server.port}/announce'),
          infoHash,
          peerId: peerId,
        )
        .timeout(const Duration(seconds: 2));
    expect(peers, isEmpty);
  });

  test(
    'closing during a request cancels it and rejects later requests',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final requested = Completer<void>();
      server.listen((request) {
        if (!requested.isCompleted) requested.complete();
      });
      final client = HttpMetadataTrackerClient();
      final tracker = Uri.parse('http://127.0.0.1:${server.port}/announce');
      final pending = client.announce(tracker, infoHash, peerId: peerId);
      await requested.future.timeout(const Duration(seconds: 2));
      client.close();
      expect(await pending.timeout(const Duration(seconds: 2)), isEmpty);
      expect(await client.announce(tracker, infoHash, peerId: peerId), isEmpty);
    },
  );
}
