import 'dart:io';

import 'package:dtorrent_task_v2/dtorrent_task_v2.dart' show TaskState;
import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/pages/download/local_player_controller.dart';
import 'package:kostori/services/torrent/indexer/bt_indexer.dart';
import 'package:kostori/services/torrent/torrent_job.dart';
import 'package:kostori/services/torrent/torrent_manager.dart';
import 'package:kostori/services/torrent/torrent_network.dart';
import 'package:kostori/services/torrent/torrent_stream_server.dart';

TorrentFileEntry _file(int i, int size, int done) => TorrentFileEntry(
  index: i,
  name: 'ep$i.mkv',
  path: 'pack/ep$i.mkv',
  size: size,
  downloaded: done,
  isStreamable: true,
);

void main() {
  test(
    'torrent socket override does not recurse through its loopback path',
    () async {
      if (Platform.isAndroid) return;
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final accepted = server.first.then((socket) {
        socket.destroy();
      });
      try {
        final socket = await TorrentNetwork.run(
          () => Socket.connect(InternetAddress.loopbackIPv4, server.port),
        ).timeout(const Duration(seconds: 3));
        socket.destroy();
        await accepted;
      } finally {
        await server.close();
      }
    },
  );

  test(
    'torrent stream URLs encode file names while preserving path segments',
    () {
      expect(
        TorrentStreamServer.urlForPath(
          37471,
          'FC2-OPV/4k688.com@episode.mp4',
        ).toString(),
        'http://127.0.0.1:37471/FC2-OPV/4k688.com@episode.mp4',
      );
    },
  );

  test('torrent stream paths still resolve after a local rename', () {
    expect(
      TorrentStreamServer.pathMatches(
        'FC2-PPV-4981932/4k688.com@FC2-PPV-4981932.mp4',
        '4k688.com@FC2-PPV-4981932.mp4',
      ),
      isTrue,
    );
    expect(
      TorrentStreamServer.pathMatches(
        'FC2-PPV-4981932/FC2-PPV-4981932.mp4',
        r'D:\Downloads\FC2-PPV-4981932\FC2-PPV-4981932.mp4',
      ),
      isTrue,
    );
  });

  test('torrent file priorities survive job persistence', () {
    final job = TorrentJob(
      id: 'priority-test',
      magnet: '',
      torrentPath: '',
      savePath: '',
      createdAt: 0,
      filePriorities: {1: 3, 4: 0},
    );
    final restored = TorrentJob.fromJson(job.toJson());
    expect(restored.filePriorities, {1: 3, 4: 0});
  });

  group('种子下载通知', () {
    TorrentJob job(TorrentJobStatus status, {bool hasMetadata = true}) =>
        TorrentJob(
          id: 'notification-test',
          magnet: '',
          torrentPath: '',
          savePath: '',
          createdAt: 0,
          status: status,
          hasMetadata: hasMetadata,
        );

    test('获取元数据不显示下载通知', () {
      for (final engineState in [null, ...TaskState.values]) {
        expect(
          TorrentManager.needsKeepAlive(
            job(TorrentJobStatus.metadata, hasMetadata: false),
            engineState,
          ),
          isFalse,
        );
        expect(
          TorrentManager.needsKeepAlive(
            job(TorrentJobStatus.metadata),
            engineState,
          ),
          isFalse,
        );
      }
    });

    test('文件下载和做种只有引擎实际运行时才保留通知', () {
      for (final status in [
        TorrentJobStatus.downloading,
        TorrentJobStatus.completed,
      ]) {
        expect(
          TorrentManager.needsKeepAlive(job(status), TaskState.running),
          isTrue,
        );
        for (final engineState in [null, TaskState.paused, TaskState.stopped]) {
          expect(
            TorrentManager.needsKeepAlive(job(status), engineState),
            isFalse,
          );
        }
        expect(
          TorrentManager.needsKeepAlive(
            job(status, hasMetadata: false),
            TaskState.running,
          ),
          isFalse,
        );
      }
    });

    test('暂停和失败任务不保留下载通知', () {
      for (final status in [TorrentJobStatus.paused, TorrentJobStatus.failed]) {
        expect(
          TorrentManager.needsKeepAlive(job(status), TaskState.running),
          isFalse,
        );
      }
    });
  });

  group('normalizeMagnet', () {
    test('40 位 hex 磁力链接原样返回，不被误判成 base32', () {
      // 前 32 位全部落在 base32 字符集 [A-Za-z2-7] 内，且第 33 位是 base32
      // 不含的 '0' —— 旧实现的 32 位正则会匹配上并改写成错误 infohash
      const hash = 'abcdefabcdefabcdefabcdefabcdefabcdefab0';
      final magnet =
          'magnet:?xt=urn:btih:$hash&dn=Test&tr=udp%3A%2F%2Ftracker.example';
      expect(normalizeMagnet(magnet), magnet);
    });

    test('32 位 base32 会被转成 hex', () {
      // "abcdefghijklmnopqrst" 的 base32 表示，标准 32 字符 infohash
      const base32 = 'MFRGGZDFMZTWQ2LKNNWG23TPOBYXE43U';
      final magnet = 'magnet:?xt=urn:btih:$base32&dn=Test';
      final out = normalizeMagnet(magnet);
      expect(out, isNot(contains(base32)));
      expect(
        out,
        matches(RegExp(r'xt=urn:btih:[0-9a-f]{40}\b')),
        reason: 'base32 infohash 应被规范化为 40 位 hex',
      );
      expect(out, contains('&dn=Test'), reason: '其余参数必须保留');
    });

    test('40 位 hex 磁力链接里的 dn / tr 不受影响', () {
      const hash = '0123456789abcdef0123456789abcdef01234567';
      final magnet = 'magnet:?xt=urn:btih:$hash&dn=%E8%8A%82%E7%89%87';
      expect(normalizeMagnet(magnet), magnet);
    });

    test('无 xt 的磁力链接原样返回', () {
      expect(normalizeMagnet('magnet:?dn=only'), 'magnet:?dn=only');
    });
  });

  group('tracker fan-out limit', () {
    test('keeps protocol diversity while removing duplicates', () {
      final trackers = [
        Uri.parse('https://private.example/announce'),
        Uri.parse('https://private.example/announce'),
        Uri.parse('http://public.example/announce'),
        Uri.parse('udp://udp.example:6969/announce'),
        Uri.parse('ws://web.example/announce'),
        Uri.parse('https://later.example/announce'),
      ];

      final selected = TorrentManager.limitActiveTrackerUris(
        trackers,
        limit: 4,
      );

      expect(selected, hasLength(4));
      expect(selected.map((uri) => uri.scheme).toSet(), {
        'https',
        'http',
        'udp',
        'ws',
      });
      expect(selected.toSet(), hasLength(selected.length));
    });

    test('returns all unique trackers below the limit', () {
      final selected = TorrentManager.limitActiveTrackerUris([
        Uri.parse('udp://one.example:1/announce'),
        Uri.parse('udp://one.example:1/announce'),
        Uri.parse('udp://two.example:2/announce'),
      ], limit: 8);
      expect(selected.map((uri) => uri.toString()), [
        'udp://one.example:1/announce',
        'udp://two.example:2/announce',
      ]);
    });
  });

  group('进度按已选文件统计', () {
    // 12 集的整季包，只勾了第 1 集 —— 默认选择就是这个场景
    late List<TorrentFileEntry> files;
    setUp(() {
      files = [for (var i = 0; i < 12; i++) _file(i, 700 << 20, 0)];
    });

    test('只勾选部分文件时，统计范围不含未选文件', () {
      // 第 0 集下满，其余未下载
      files[0] = _file(0, 700 << 20, 700 << 20);
      final done = TorrentManager.selectedDoneBytes(files, [0]);
      expect(done, 700 << 20);
    });

    test('未选中的文件即使有数据也不计入（引擎下满也会被跳过）', () {
      files[5] = _file(5, 700 << 20, 700 << 20);
      final done = TorrentManager.selectedDoneBytes(files, [0, 1]);
      expect(done, 0, reason: '未勾选的文件不参与统计');
    });

    test('多个选中文件求和', () {
      files[2] = _file(2, 700 << 20, 700 << 20);
      files[4] = _file(4, 700 << 20, 350 << 20);
      final done = TorrentManager.selectedDoneBytes(files, [2, 4]);
      expect(done, (700 << 20) + (350 << 20));
    });

    test('空选择 = 全部选中', () {
      files[3] = _file(3, 700 << 20, 700 << 20);
      files[7] = _file(7, 700 << 20, 100 << 20);
      expect(
        TorrentManager.selectedDoneBytes(files, const []),
        (700 << 20) + (100 << 20),
      );
    });

    test('全不选时恒为 0，不会退回整包大小', () {
      files[0] = _file(0, 700 << 20, 700 << 20);
      expect(TorrentManager.selectedDoneBytes(files, [kTorrentNoFile]), 0);
    });

    test('部分选择下进度能到 100%（旧实现卡在 1/12，永不完成）', () {
      // 模拟「只勾了第 0 集且已下满」
      files[0] = _file(0, 700 << 20, 700 << 20);
      final done = TorrentManager.selectedDoneBytes(files, [0]);
      final wanted = 700 << 20; // _wantedBytes：只累加已选文件
      expect(done / wanted, 1.0);

      // 旧口径：引擎 progress = downloaded / totalSize = 1 / 12，永远到不了 1.0
      final totalSize = files.fold<int>(0, (s, f) => s + f.size);
      expect(done / totalSize, lessThan(0.1));
    });
  });

  group('元数据抓取', () {
    test('infohash 能从 40 位 hex 磁力里解出 20 字节', () {
      const hex = '0123456789abcdef0123456789abcdef01234567';
      final magnet = 'magnet:?xt=urn:btih:$hex&dn=Test';
      final bytes = TorrentManager.infoHashBytesOf(magnet);
      expect(bytes, isNotNull);
      expect(bytes, hasLength(20));
      expect(
        bytes!.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
        hex,
      );
    });

    test('infohash 解析失败时退回从磁力串自行提取', () {
      // 大写 hex 也应识别
      const hex = '0123456789ABCDEF0123456789ABCDEF01234567';
      final bytes = TorrentManager.infoHashBytesOf('magnet:?xt=urn:btih:$hex');
      expect(bytes, hasLength(20));
    });

    test('非 hex / 长度不对时返回 null（跳过 DHT 而不是硬跑）', () {
      expect(TorrentManager.infoHashBytesOf('magnet:?dn=only'), isNull);
      expect(
        TorrentManager.infoHashBytesOf('magnet:?xt=urn:btih:zzzz'),
        isNull,
      );
      // v2 磁力（urn:btmh:）是 32 字节 SHA-256，自定义 DHT 是 BEP5 实现
      expect(
        TorrentManager.infoHashBytesOf('magnet:?xt=urn:btmh:1220${'a' * 64}'),
        isNull,
      );
    });

    test('超时有独立异常类型，不会把 TimeoutException 原文抛给界面', () {
      const e = TorrentMetadataTimeout();
      expect(e.toString(), isNot(contains('TimeoutException')));
      expect(e.toString(), isNot(contains('0:00')));
    });

    test('元数据发现重试间隔封顶为 60 秒', () {
      expect(TorrentManager.metadataRetryCeilingSeconds, 60);
      expect(
        TorrentManager.maxMetadataAttempts,
        inInclusiveRange(1, 5),
        reason: '必须有重试预算，否则解析失败会形成无限循环',
      );
    });
  });

  group('种子识别码 / 裸 info hash', () {
    // 合成的 info hash，不对应任何真实资源
    const bare = '0123456789ABCDEF0123456789ABCDEF01234567';

    test('裸 40 位 hex 被包成磁力链', () {
      expect(normalizeMagnet(bare), 'magnet:?xt=urn:btih:$bare');
    });

    test('裸 hash 忽略大小写与首尾空白', () {
      expect(
        normalizeMagnet('  ${bare.toLowerCase()}  '),
        'magnet:?xt=urn:btih:$bare',
      );
    });

    test('裸 32 位 base32 也能识别', () {
      // "abcdefghijklmnopqrst" 的 base32 表示
      const base32 = 'MFRGGZDFMZTWQ2LKNNWG23TPOBYXE43U';
      final out = normalizeMagnet(base32);
      expect(out, startsWith('magnet:?xt=urn:btih:'));
      expect(out, isNot(contains(base32)));
    });

    test('普通文本不会被误包成磁力', () {
      expect(normalizeMagnet('hello world'), 'hello world');
      expect(
        normalizeMagnet('https://example.com/a.torrent'),
        isNot(startsWith('magnet:')),
      );
      // 长度不对的 hex 串不当成 info hash
      const tooShort = '0123456789ABCDEF0123456789ABCDEF0123456';
      expect(normalizeMagnet(tooShort), tooShort);
    });

    test('从磁力解析出大写识别码', () {
      expect(parseInfoHash('magnet:?xt=urn:btih:${bare.toLowerCase()}'), bare);
      expect(parseInfoHash(bare), bare);
      expect(parseInfoHash('magnet:?dn=x'), isNull);
    });

    test('磁力参数大小写和 URL 编码不影响识别码解析', () {
      expect(parseInfoHash('magnet:?XT=URN%3ABTIH%3A$bare&dn=Test'), bare);
      expect(
        parseInfoHash(
          'magnet:?xt=urn:btih:MFRGGZDFMZTWQ2LKNNWG23TPOBYXE43U&dn=Test',
        ),
        '6162636465666768696A6B6C6D6E6F7071727374',
      );
    });

    test('识别码能还原成磁力链', () {
      expect(
        magnetFromInfoHash(bare.toLowerCase()),
        'magnet:?xt=urn:btih:$bare',
      );
    });

    test('TorrentJob.infoHash 裸 hash / base32 都能取到', () {
      TorrentJob job(String magnet) => TorrentJob(
        id: 'j',
        magnet: magnet,
        torrentPath: 'a',
        savePath: 'b',
        createdAt: 0,
      );
      expect(job(bare).infoHash, bare);
      expect(
        job('magnet:?xt=urn:btih:${bare.toLowerCase()}&dn=x').infoHash,
        bare,
      );
      expect(
        job('magnet:?xt=urn:btih:MFRGGZDFMZTWQ2LKNNWG23TPOBYXE43U').infoHash,
        '6162636465666768696A6B6C6D6E6F7071727374',
        reason: 'base32 应转成 hex，复制出去别的客户端才认',
      );
    });

    test('infoHashBytesOf 能吃裸 hash', () {
      expect(TorrentManager.infoHashBytesOf(bare), hasLength(20));
    });

    test('选中文本里的裸 info hash 也能识别为磁力', () {
      expect(firstMagnetInSelection(bare), 'magnet:?xt=urn:btih:$bare');
      expect(
        firstMagnetInSelection('哈希 $bare 谢谢'),
        'magnet:?xt=urn:btih:$bare',
      );
    });

    test('选中文本里的磁力链仍按原样取出', () {
      const magnet = 'magnet:?xt=urn:btih:$bare&dn=Test';
      expect(firstMagnetInSelection('链接 $magnet。'), magnet);
    });

    test('无关文本不会被当成种子', () {
      expect(firstMagnetInSelection('just some text'), isNull);
    });

    test('带 dn / xl / 多个 tracker 的长磁力能识别', () {
      const magnet =
          'magnet:?xt=urn:btih:fedcba9876543210fedcba9876543210fedcba98'
          '&dn=Sample-001&xl=6539508267'
          '&tr=http://tracker1.example.com:8888/announce'
          '&tr=udp://tracker2.example.com:1337/announce'
          '&tr=udp://tracker3.example.com:80/announce';

      // 已经是 hex 磁力，不应被改写（改了 hash 就对不上了）
      expect(normalizeMagnet(magnet), magnet);
      expect(parseInfoHash(magnet), 'FEDCBA9876543210FEDCBA9876543210FEDCBA98');
      expect(TorrentManager.infoHashBytesOf(magnet), hasLength(20));
      expect(
        Uri.parse(magnet).queryParametersAll['tr']!.length,
        3,
        reason: '磁力自带的 announce 必须能解析出来（后面会与内置 tracker 合并）',
      );
    });
  });

  group('DHT 引导节点', () {
    test('host:port 写法补上 udp:// 前缀', () {
      // 设置页提示的就是「host:port」格式，不补前缀会被当成无效条目丢掉
      expect(
        TorrentManager.normalizeDhtNode('router.example.com:6881'),
        'udp://router.example.com:6881',
      );
    });

    test('已有前缀时保持不变', () {
      expect(
        TorrentManager.normalizeDhtNode('udp://router.example.com:6881'),
        'udp://router.example.com:6881',
      );
    });

    test('缺省端口补 6881', () {
      expect(
        TorrentManager.normalizeDhtNode('router.example.com'),
        'udp://router.example.com:6881',
      );
    });

    test('空串与无法解析的输入返回空串', () {
      expect(TorrentManager.normalizeDhtNode(''), '');
      expect(TorrentManager.normalizeDhtNode('   '), '');
      expect(TorrentManager.normalizeDhtNode('udp://'), '');
    });

    test('内置列表里没有已失效的引导节点', () {
      // router.bitcomet.com / dht.bitcomet.com 已 NXDOMAIN，
      // router.silotis.us 只剩 AAAA 记录，留着只会拖慢 bootstrap 解析
      for (final dead in const [
        'router.bitcomet.com',
        'dht.bitcomet.com',
        'router.silotis.us',
      ]) {
        expect(
          kDefaultDhtNodes.any((e) => e.contains(dead)),
          isFalse,
          reason: '$dead 已不可用，不应再作为引导节点',
        );
      }
      expect(kDefaultDhtNodes, isNotEmpty);
    });
  });

  group('进度条不确定动画', () {
    TorrentJob makeJob(TorrentJobStatus status) => TorrentJob(
      id: 'j1',
      magnet: 'magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567',
      torrentPath: 'a.torrent',
      savePath: 'D:\\dl',
      createdAt: 1,
      status: status,
    );

    test('只有真在抓元数据时才转圈', () {
      expect(makeJob(TorrentJobStatus.metadata).isFetchingMeta, isTrue);
    });

    test('失败 / 暂停 / 完成都不转圈', () {
      // 这三种都没有元数据，用 value: null 会让进度条永远在动，
      // 用户看到的是「停不下来的条目」
      for (final s in [
        TorrentJobStatus.failed,
        TorrentJobStatus.paused,
        TorrentJobStatus.completed,
        TorrentJobStatus.downloading,
      ]) {
        expect(makeJob(s).isFetchingMeta, isFalse, reason: '$s 不应转圈');
      }
    });

    test('已有元数据时永远不转圈', () {
      final job = makeJob(TorrentJobStatus.metadata)..hasMetadata = true;
      expect(job.isFetchingMeta, isFalse);
    });
  });

  group('播放进度 key 稳定性', () {
    test('回环端口不同但路径相同时得到同一个 key', () {
      final a = localPlayerPosKey('http://127.0.0.1:41234/Anime/ep01.mkv');
      final b = localPlayerPosKey('http://127.0.0.1:52001/Anime/ep01.mkv');
      expect(a, b, reason: '随机端口变化后仍应命中同一条进度记录');
    });

    test('localhost 与 127.0.0.1 视为同一 host', () {
      expect(
        localPlayerPosKey('http://localhost:1234/a.mkv'),
        localPlayerPosKey('http://127.0.0.1:9999/a.mkv'),
      );
    });

    test('不同文件仍是不同的 key', () {
      expect(
        localPlayerPosKey('http://127.0.0.1:1/a.mkv'),
        isNot(localPlayerPosKey('http://127.0.0.1:1/b.mkv')),
      );
    });

    test('普通本地文件路径原样保留（含中文 / 空格）', () {
      const p = r'D:\ Videos\测试 动画\EP01.mkv';
      expect(localPlayerPosKey(p), 'localPlayerPos:$p');
    });

    test('http 非回环地址保留原端口', () {
      expect(
        localPlayerPosKey('http://example.com:8080/a.mkv'),
        'localPlayerPos:http://example.com:8080/a.mkv',
      );
    });
  });

  group('TorrentJob 运行期统计', () {
    TorrentJob makeJob() => TorrentJob(
      id: 'j1',
      magnet: 'magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567',
      torrentPath: 'a.torrent',
      savePath: 'D:\\dl',
      createdAt: 1,
    );

    test('numDownloaders 属于运行期字段，不写进持久化数据', () {
      final job = makeJob()..numDownloaders = 42;
      expect(job.numDownloaders, 42);
      expect(job.toJson().containsKey('numDownloaders'), isFalse);
      // 做种比例依赖它，持久化会把过期数字带到下次启动
      expect(job.toJson().containsKey('numSeeds'), isFalse);
    });

    test('旧版本存档缺少 numDownloaders 时回退为 0', () {
      final job = TorrentJob.fromJson(makeJob().toJson());
      expect(job.numDownloaders, 0);
    });
  });
}
