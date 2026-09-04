import 'package:kostori/database/bangumi.dart';
import 'package:kostori/database/stats.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/init.dart';

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
