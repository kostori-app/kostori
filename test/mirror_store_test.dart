import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/network/mirror_store.dart';

// 输入主机必须是 lain.bgm.tv（_bangumiImageMirrorableHosts 只认它），
// 否则这条用例会退化成「原样返回」；镜像地址本身用保留域名。
const _img = 'https://lain.bgm.tv/pic/cover/l/ab/4f/639938_2JKQ7.jpg';
const _host = 'mirror.bgm.example';
const _expected = 'https://$_host/bgm-img/pic/cover/l/ab/4f/639938_2JKQ7.jpg';

void main() {
  group('normalizeMirrorUrl', () {
    final cases = <String, ({String input, String want})>{
      '裸域名': (input: '$_host/bgm-img', want: 'https://$_host/bgm-img'),
      '带 https': (
        input: 'https://$_host/bgm-img',
        want: 'https://$_host/bgm-img',
      ),
      '带 http': (input: 'http://$_host/bgm-img', want: 'http://$_host/bgm-img'),
      '重复 scheme': (
        input: 'https://https://$_host/bgm-img',
        want: 'https://$_host/bgm-img',
      ),
      'http + 重复': (
        input: 'http://https://$_host/bgm-img',
        want: 'http://$_host/bgm-img',
      ),
      '协议相对': (input: '//$_host/bgm-img', want: 'https://$_host/bgm-img'),
      '首尾空白': (
        input: '  https://$_host/bgm-img  ',
        want: 'https://$_host/bgm-img',
      ),
      '空串': (input: '', want: ''),
      '只有斜杠': (input: '//', want: ''),
    };

    cases.forEach((label, c) {
      test(label, () => expect(normalizeMirrorUrl(c.input), c.want));
    });
  });

  group('applyBangumiImageMirror', () {
    setUp(() => appdata.implicitData.clear());

    void selectImg(String url) =>
        appdata.implicitData['bangumiImageMirror'] = url;

    test('前缀镜像拼接正确', () {
      selectImg('https://$_host/bgm-img');
      expect(applyBangumiImageMirror(_img), _expected);
    });

    test('已存的值带重复 scheme 也能修正', () {
      selectImg('https://https://$_host/bgm-img');
      expect(applyBangumiImageMirror(_img), _expected);
    });

    test('末尾斜杠不产生双斜杠', () {
      selectImg('https://$_host/bgm-img/');
      expect(applyBangumiImageMirror(_img), _expected);
    });

    test('未开镜像时原样返回', () {
      selectImg('');
      expect(applyBangumiImageMirror(_img), _img);
    });

    test('非镜像主机原样返回', () {
      selectImg('https://$_host/bgm-img');
      const other = 'https://example.com/pic/a.jpg';
      expect(applyBangumiImageMirror(other), other);
    });
  });
}
