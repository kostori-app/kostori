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

Anime _anime(int i) => Anime(
  '标题$i',
  'https://example.invalid/$i.jpg',
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
  });
}
