import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/pages/download/local_player_controller.dart';
import 'package:kostori/services/torrent/indexer/bt_indexer.dart';
import 'package:kostori/services/torrent/torrent_job.dart';
import 'package:kostori/services/torrent/torrent_manager.dart';

TorrentFileEntry _file(int i, int size, int done) => TorrentFileEntry(
  index: i,
  name: 'ep$i.mkv',
  path: 'pack/ep$i.mkv',
  size: size,
  downloaded: done,
  isStreamable: true,
);

void main() {
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
      // SHA-1("abc") 的 base32 表示，标准 32 字符 infohash
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

    test('元数据超时从 180 秒收敛到 45 秒量级', () {
      // 有 peer 时通常 1~10 秒拿到；180 秒的等待体感就是「卡住」
      expect(TorrentManager.metadataTimeoutSeconds, lessThanOrEqualTo(60));
      expect(
        TorrentManager.maxMetadataAttempts,
        inInclusiveRange(1, 5),
        reason: '必须有重试预算，否则解析失败会形成无限循环',
      );
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
