import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:libtorrent_flutter/libtorrent_flutter.dart';

const String _magnet =
    'magnet:?xt=urn:btih:8186293b553a83bc2b36453adaf90569a27b5a2b'
    '&dn=%2B%2B%2B%20%5BFHD%5D%20DAL-012'
    '&tr=http%3A%2F%2Fsukebei.tracker.wf%3A8888%2Fannounce'
    '&tr=udp%3A%2F%2Fopen.stealth.si%3A80%2Fannounce'
    '&tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337%2Fannounce'
    '&tr=udp%3A%2F%2Fexodus.desync.com%3A6969%2Fannounce'
    '&tr=udp%3A%2F%2Ftracker.torrent.eu.org%3A451%2Fannounce';

Future<String?> _fetchTrackers(String url) async {
  try {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    final req = await client.getUrl(Uri.parse(url));
    final res = await req.close();
    final body = await res.transform(const SystemEncoding().decoder).join();
    client.close(force: true);
    final list = body
        .split(RegExp(r'\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s.contains('://'))
        .toSet()
        .toList();
    return list.join('\n');
  } catch (e) {
    print('probe: fetchTrackers failed: $e');
    return null;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('probe: magnet metadata with trackers', (tester) async {
    final dir = Directory.systemTemp.createTempSync('torrent_probe');
    await LibtorrentFlutter.init(
      fetchTrackers: false,
      defaultSavePath: dir.path,
    );

    final trackers = await _fetchTrackers(
      'https://cf.trackerslist.com/all.txt',
    );
    var magnet = _magnet;
    if (trackers != null) {
      for (final tr in trackers.split('\n')) {
        final enc = Uri.encodeComponent(tr);
        if (!magnet.contains(enc) && !magnet.contains(tr)) {
          magnet += '&tr=$enc';
        }
      }
    }
    print('probe: trackers fetched=${trackers?.split('\n').length ?? 0}');

    final id = LibtorrentFlutter.instance.addMagnet(magnet, dir.path);
    print('probe: torrentId=$id');

    for (var i = 0; i < 30; i++) {
      await Future<void>.delayed(const Duration(seconds: 3));
      final info = LibtorrentFlutter.instance.torrents[id];
      if (info == null) {
        print('probe[$i]: no status');
        continue;
      }
      print(
        'probe[$i]: state=${info.state} peers=${info.numPeers} '
        'seeds=${info.numSeeds} meta=${info.hasMetadata} '
        'prog=${(info.progress * 100).toStringAsFixed(1)}% '
        'name=${info.name}',
      );
      if (info.hasMetadata) {
        final files = LibtorrentFlutter.instance.getFiles(id);
        print('probe: METADATA OK, files=${files.length}');
        for (final f in files.take(5)) {
          print('  [${f.index}] ${f.name} ${formatBytes(f.size)} streamable=${f.isStreamable}');
        }
        break;
      }
    }
    LibtorrentFlutter.instance.disposeTorrent(id);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
