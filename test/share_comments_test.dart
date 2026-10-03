import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/components/bean/card/comments_card.dart';
import 'package:kostori/components/share_widget.dart';
import 'package:kostori/foundation/bangumi/avatar_item.dart';
import 'package:kostori/foundation/bangumi/comment/comment_item.dart';
import 'package:kostori/foundation/bangumi/user_item.dart';

CommentItem _comment(int i) => CommentItem(
  user: InfoUser(
    avatar: Avatar.fromJson(const {}),
    group: 0,
    id: i,
    joinedAt: 0,
    nickname: 'user$i',
    sign: '',
    username: 'user$i',
  ),
  comment: Comment(rate: 0, comment: 'comment $i', updatedAt: 1700000000000),
);

List<CommentItem> _list(int n) => [for (var i = 0; i < n; i++) _comment(i)];

void main() {
  group('分享卡片评论条数裁剪', () {
    test('上限为 10', () {
      expect(ShareWidget.kShareCommentLimit, 10);
    });

    test('不足 10 条时按实际条数截断', () {
      // 原 bug：itemCount 写死 10，这里少一条就越界
      for (final n in [1, 3, 5, 9]) {
        expect(
          ShareWidget.shareCommentsOf(_list(n)),
          hasLength(n),
          reason: '$n 条评论应渲染 $n 条',
        );
      }
    });

    test('超过 10 条时截断到 10', () {
      expect(ShareWidget.shareCommentsOf(_list(25)), hasLength(10));
    });

    test('空列表返回空', () {
      expect(ShareWidget.shareCommentsOf(const []), isEmpty);
    });

    test('恰好 10 条时全渲染', () {
      expect(ShareWidget.shareCommentsOf(_list(10)), hasLength(10));
    });

    test('裁剪后的列表可按 itemCount 完整遍历（下标不越界）', () {
      for (final n in [1, 5, 9, 10, 25]) {
        final source = _list(n);
        final shown = ShareWidget.shareCommentsOf(source);
        expect(
          () {
            for (var i = 0; i < shown.length; i++) {
              shown[i];
            }
          },
          returnsNormally,
          reason: '$n 条时遍历越界',
        );
        expect(shown.length, lessThanOrEqualTo(source.length));
      }
    });
  });

  group('分享卡片评论渲染', () {
    testWidgets('评论不足 10 条时不出现「加载失败」占位', (tester) async {
      final shown = ShareWidget.shareCommentsOf(_list(5));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              // 关键：itemCount 取裁剪后的长度，而不是写死 10
              itemCount: shown.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => CommentsCard(commentItem: shown[i]),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(CommentsCard), findsNWidgets(5));
      // release 下 ErrorWidget 会渲染成这段文案（main.dart 的 ErrorWidget.builder）
      expect(find.textContaining('加载失败'), findsNothing);
    });

    testWidgets('itemCount 写死时确实会越界（复现原 bug）', (tester) async {
      final source = _list(5);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 10, // 旧代码
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => CommentsCard(commentItem: source[i]),
            ),
          ),
        ),
      );
      await tester.pump();

      // 证明这个测试确实能捕捉到原 bug
      expect(tester.takeException(), isA<RangeError>());
    });
  });
}
