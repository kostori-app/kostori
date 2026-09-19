import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/components/anime_list.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/res.dart';
import 'package:kostori/i18n/strings.g.dart';

/// 1x1 透明 PNG 的 data URL：测试里不放真实的网络图片请求
const String _kTestCover =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
    'AAAADUlEQVR42mP8z8DwHwAFAAH/q842iQAAAABJRU5ErkJggg==';

Anime _anime(int i) => Anime(
  '标题$i',
  _kTestCover,
  'id$i',
  '',
  const [],
  '',
  'paging_test_source',
  null,
  null,
);

void main() {
  testWidgets('空页/重复页后停止继续翻页（不再无限请求）', (tester) async {
    // 视口放大，让每页条目都被构建，触发底部自动加载
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // 封面图加载依赖 App 路径，测试里给个临时目录
    final tempPath = Directory.systemTemp.createTempSync('kostori_test_').path;
    App.dataPath = tempPath;
    App.cachePath = tempPath;
    appdata.settings['animeListDisplayMode'] = 'continuous';

    final requested = <int>[];
    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: AnimeList(
                loadPage: (page) async {
                  requested.add(page);
                  if (page <= 2) {
                    // 源谎报还有 99 页
                    return Res(<Anime>[_anime(page)], subData: 99);
                  }
                  return const Res(<Anime>[]);
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 第 3 页是空页 → 立即停止，不再请求第 4 页
    expect(requested, [1, 2, 3]);
    await tester.pump(const Duration(milliseconds: 300));
  });

  for (final mode in ['brief', 'masonry']) {
    testWidgets('加载下一页后不会跳回顶部（$mode）', (tester) async {
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final tempPath = Directory.systemTemp.createTempSync('kostori_test_').path;
      App.dataPath = tempPath;
      App.cachePath = tempPath;
      appdata.settings['animeListDisplayMode'] = 'continuous';
      appdata.settings['animeDisplayMode'] = mode;

      final requested = <int>[];
      await tester.pumpWidget(
        ProviderScope(
          child: TranslationProvider(
            child: MaterialApp(
              home: Scaffold(
                body: AnimeList(
                  loadPage: (page) async {
                    requested.add(page);
                    // 每页 12 条，共 2 页
                    return Res(
                      List<Anime>.generate(12, (i) => _anime(page * 100 + i)),
                      subData: 2,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollable = find.byType(Scrollable).first;
      final s1 = tester.state<ScrollableState>(scrollable);
      // 先离开顶部，再滚到底部触发下一页
      s1.position.jumpTo(200);
      await tester.pump();
      s1.position.jumpTo(s1.position.maxScrollExtent);
      await tester.pumpAndSettle();

      // 下一页已加载，且滚动位置保持在底部而不是被拉回顶部
      expect(requested, [1, 2]);
      expect(
        tester.state<ScrollableState>(scrollable).position.pixels,
        greaterThan(200),
        reason: '加载下一页后应保持滚动位置',
      );
      await tester.pump(const Duration(milliseconds: 300));
    });
  }
}
