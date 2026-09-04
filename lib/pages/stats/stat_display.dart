import 'package:flutter/material.dart';
import 'package:kostori/database/bangumi.dart';
import 'package:kostori/database/stats.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/init.dart';

/// 统计条目卡片的统一外壳（圆角材质 + 可选点击），
/// 供日历列表 / 全量记录 / 概览复用，样式与项目卡片一致。
class StatEntryCard extends StatelessWidget {
  const StatEntryCard({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).brightness == Brightness.light
        ? Colors.white.withValues(alpha: 0.72)
        : const Color(0xFF1E1E1E).withValues(alpha: 0.72);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Material(
        color: color,
        elevation: 4,
        shadowColor: Theme.of(context).colorScheme.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: onTap,
          child: child,
        ),
      ),
    );
  }
}

/// 统计条目的“显示载体”唯一解析入口：
/// 优先命中 bangumi.db 的真实条目；库中缺失时回落统计自带 title/cover
/// 构造的兜底条目（兼容展示，不参与任何持久化/加载源语义）。
Future<BangumiItem?> resolveStatDisplay(StatsDataImpl stat) async {
  final id = stat.bangumiId;
  if (id == null) return null;
  final item = await providerContainer
      .read(bangumiManagerProvider)
      .getBangumiItem(id);
  return item ?? stat.toBangumiItem();
}
