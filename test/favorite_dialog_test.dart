import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/database/favorites.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/anime_type.dart';
import 'package:kostori/i18n/strings.g.dart';

Anime _anime() => const Anime(
  '标题',
  'cover.jpg',
  'id-1',
  '作者',
  ['tag'],
  '简介',
  'test_source',
  null,
  null,
);

void main() {
  setUp(() {
    // 内存管理器，不初始化 DB（落盘为空操作）
    LocalFavoritesManager.cache = null;
  });

  test('favoriteItemOf 按卡片字段构造收藏项', () {
    final item = favoriteItemOf(_anime());
    expect(item.id, 'id-1');
    expect(item.name, '标题');
    expect(item.coverPath, 'cover.jpg');
    expect(item.author, '作者');
    expect(item.tags, ['tag']);
    expect(item.viewMore, isNull);
    // 与卡片判断收藏用的 type 保持一致（sourceKey.hashCode）
    expect(item.type, AnimeType('test_source'.hashCode));
  });

  testWidgets('收藏弹窗列出全部文件夹，勾选后才可确认', (tester) async {
    // 手机尺寸视口：弹窗内容高度依赖可用空间（默认 800x600 会挤压溢出）
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final manager = LocalFavoritesManager();
    manager.createFolder('在看');
    manager.createFolder('看完');

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => FavoriteDialog.show(
                  context,
                  items: [favoriteItemOf(_anime())],
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('在看'), findsOneWidget);
    expect(find.text('看完'), findsOneWidget);
    expect(find.text(t.newFolder), findsOneWidget);
    // 未勾选时不显示「新增 x / 移除 y」统计
    expect(find.text(t.aToAddBToRemove(a: '1', b: '0')), findsNothing);

    await tester.tap(find.text('在看'));
    await tester.pumpAndSettle();
    expect(find.text(t.aToAddBToRemove(a: '1', b: '0')), findsOneWidget);
    // 未点确认前不写入收藏
    expect(manager.find('id-1', AnimeType('test_source'.hashCode)), isEmpty);
  });
}
