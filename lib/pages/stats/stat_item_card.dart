part of 'stats_page.dart';

/// 统计里展示收藏分组：未分类伪组(_default/default/默认)显示为“未分类”
/// 来源·观看/点击 记录的胶囊样式（不再用中括号拼文本）
Widget _statsSourceChip(BuildContext context, String text) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: Theme.of(
        context,
      ).colorScheme.secondaryContainer.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: Theme.of(context).colorScheme.onSecondaryContainer,
      ),
    ),
  );
}

String _statFolderLabel(String? folder) {
  if (folder == null || folder.isEmpty) return t.unknownFolder;
  if (folder == '_default' || folder == 'default' || folder == '默认') {
    return t.kDefault;
  }
  return folder;
}

class StatItemWidget extends StatefulWidget {
  final List<StatsDataImpl> statsGroup;
  final DateTime selectedDay;

  const StatItemWidget({
    super.key,
    required this.statsGroup,
    required this.selectedDay,
  });

  @override
  State<StatItemWidget> createState() => _StatItemWidgetState();
}

class _StatItemWidgetState extends State<StatItemWidget> {
  bool _liked = false;
  BangumiItem? _bangumiItem;

  List<StatsDataImpl> get statsGroup => widget.statsGroup;

  DateTime get selectedDay => widget.selectedDay;

  StatsDataImpl get _primaryStat {
    final masterItems = statsGroup.where((s) => s.isBangumi).toList();
    return masterItems.isNotEmpty ? masterItems.first : statsGroup.first;
  }

  @override
  void initState() {
    super.initState();
    _loadLiked();
    _loadBangumiItem();
  }

  Future<void> _loadLiked() async {
    final liked = await StatsManager().getGroupLikedStatus(
      id: _primaryStat.id,
      type: _primaryStat.type,
    );
    if (mounted) setState(() => _liked = liked);
  }

  Future<void> _loadBangumiItem() async {
    final primary = _primaryStat;
    if (primary.bangumiId != null) {
      final item = await resolveStatDisplay(primary);
      // bangumi.db 缺失时 resolveStatDisplay 会用统计自带字段兜底
      if (mounted) setState(() => _bangumiItem = item ?? primary.toBangumiItem());
    }
  }

  final double height =
      (App.isAndroid || MediaQuery.of(App.rootContext).size.width <= 700)
      ? 210.0
      : 300.0;

  String formatHMSForRating({int? seconds}) {
    seconds ??= 0;
    if (seconds <= 0) return '';
    return t.statsRatedAt(duration: Utils.formatHMS(seconds));
  }

  Widget _buildFavoriteTile(PlatformEventRecord record) {
    String actionText;
    switch (record.favoriteAction) {
      case FavoriteAction.add:
        actionText = t.addToFolder(folder: _statFolderLabel(record.favorite));
        break;
      case FavoriteAction.remove:
        actionText = t.removeFromFolder(
          folder: _statFolderLabel(record.favorite),
        );
        break;
      case FavoriteAction.move:
        if (record.favorite != null && record.favorite!.contains(',')) {
          final parts = record.favorite!.split(',');
          actionText = t.movedFromTo(
            from: _statFolderLabel(parts[0]),
            to: _statFolderLabel(parts[1]),
          );
        } else {
          actionText = t.moveOperationTargetUnknown;
        }
        break;
      default:
        actionText = t.operationUnknown;
        break;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${record.date!.hhmmss} $actionText',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildCommentTile({
    required int dailyIndex,
    required int recordIndex,
    required List<DailyEvent> dailyList,
    required PlatformEventRecord record,
  }) {
    if (dailyList.length == 1 || dailyIndex == 0) {
      final text = recordIndex == 0
          ? t.statsCreatedComment(
              time: record.date!.hhmmss,
              duration: formatHMSForRating(seconds: record.watchDuration),
            )
          : t.statsModifiedComment(
              time: record.date!.hhmmss,
              n: record.value - 1,
              duration: formatHMSForRating(seconds: record.watchDuration),
            );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(text, style: const TextStyle(fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  record.comment ?? '',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      );
    } else {
      int sum = 0;
      for (int i = 0; i < dailyIndex; i++) {
        final rList = dailyList[i].platformEventRecords;
        if (rList.isNotEmpty) sum += rList.last.value;
      }
      final text = t.statsModifiedComment(
        time: record.date!.hhmmss,
        n: sum + record.value - 1,
        duration: formatHMSForRating(seconds: record.watchDuration),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(text, style: const TextStyle(fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  record.comment ?? '',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      );
    }
  }

  Widget _buildRatingTile({
    required int dailyIndex,
    required int recordIndex,
    required List<DailyEvent> dailyList,
    required PlatformEventRecord record,
  }) {
    final String text;
    if (dailyList.length == 1 || dailyIndex == 0) {
      text = recordIndex == 0
          ? t.statsCreatedRating(
              time: record.date!.hhmmss,
              duration: formatHMSForRating(seconds: record.watchDuration),
            )
          : t.statsModifiedRating(
              time: record.date!.hhmmss,
              n: record.value - 1,
              duration: formatHMSForRating(seconds: record.watchDuration),
            );
    } else {
      int sum = 0;
      for (int i = 0; i < dailyIndex; i++) {
        final rList = dailyList[i].platformEventRecords;
        if (rList.isNotEmpty) sum += rList.last.value;
      }
      text = t.statsModifiedRating(
        time: record.date!.hhmmss,
        n: sum + record.value - 1,
        duration: formatHMSForRating(seconds: record.watchDuration),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(text, style: const TextStyle(fontSize: 14)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              record.rating.toString(),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(width: 4),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(Utils.getRatingLabel(record.rating!)),
            ),
            const SizedBox(width: 4),
            RatingBarIndicator(
              itemCount: 5,
              rating: record.rating! / 2,
              itemBuilder: (context, index) => const Icon(Icons.star_rounded),
              itemSize: 20.0,
            ),
          ],
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  /// 同一时刻“创建评分 + 创建评论”合并展示：
  /// 标题 = 时间 + “评分并评论”；下面是原有评分区，再是评论内容
  Widget _buildMergedRatingComment(
    Map<String, dynamic> ratingEntry,
    Map<String, dynamic> commentEntry,
  ) {
    final rating = ratingEntry['record'] as PlatformEventRecord;
    final comment = commentEntry['record'] as PlatformEventRecord;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${rating.date!.hhmmss} ${t.statsRateAndComment}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              rating.rating.toString(),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(width: 4),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(Utils.getRatingLabel(rating.rating!)),
            ),
            const SizedBox(width: 4),
            RatingBarIndicator(
              itemCount: 5,
              rating: rating.rating! / 2,
              itemBuilder: (context, index) => const Icon(Icons.star_rounded),
              itemSize: 20.0,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                comment.comment ?? '',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget buildAllEventsWidget(BuildContext context) {
    final allRecords = <Map<String, dynamic>>[];

    for (final stats in statsGroup) {
      final commentEvent = _getDailyEvent(stats.comment, selectedDay);
      final ratingEvent = _getDailyEvent(stats.rating, selectedDay);
      final favoriteEvent = _getDailyEvent(stats.favorite, selectedDay);

      void addEventRecords(
        DailyEvent? event,
        DailyEventType type,
        List<DailyEvent> list,
        StatsDataImpl sourceStats,
      ) {
        if (event == null) return;
        final dailyIndex = list.indexOf(event);

        for (int ri = 0; ri < event.platformEventRecords.length; ri++) {
          final record = event.platformEventRecords[ri];

          if (record.value == 0 && type != DailyEventType.favorite) continue;

          allRecords.add({
            'type': type,
            'dailyIndex': dailyIndex,
            'recordIndex': ri,
            'dailyList': list,
            'record': record,
            'sourceType': _getSourceType(sourceStats.type),
            'sourceStats': sourceStats,
          });
        }
      }

      addEventRecords(
        commentEvent,
        DailyEventType.comment,
        stats.comment,
        stats,
      );
      addEventRecords(ratingEvent, DailyEventType.rating, stats.rating, stats);
      addEventRecords(
        favoriteEvent,
        DailyEventType.favorite,
        stats.favorite,
        stats,
      );
    }

    if (allRecords.isEmpty) {
      return const SizedBox.shrink();
    }

    allRecords.sort(
      (a, b) => (a['record'] as PlatformEventRecord).date!.compareTo(
        (b['record'] as PlatformEventRecord).date!,
      ),
    );

    Widget rowOf(Color dotColor, Widget content) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 18,
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(child: content),
        ],
      );
    }

    bool isCreated(Map<String, dynamic> e) {
      final ri = e['recordIndex'] as int;
      final di = e['dailyIndex'] as int;
      final len = (e['dailyList'] as List).length;
      return ri == 0 && (len == 1 || di == 0);
    }

    bool sameTime(Map<String, dynamic> a, Map<String, dynamic> b) =>
        (a['record'] as PlatformEventRecord).date ==
        (b['record'] as PlatformEventRecord).date;

    Widget tileFor(Map<String, dynamic> e) {
      final type = e['type'] as DailyEventType;
      final dailyIndex = e['dailyIndex'] as int;
      final recordIndex = e['recordIndex'] as int;
      final dailyList = e['dailyList'] as List<DailyEvent>;
      final record = e['record'] as PlatformEventRecord;
      return switch (type) {
        DailyEventType.comment => _buildCommentTile(
          dailyIndex: dailyIndex,
          recordIndex: recordIndex,
          dailyList: dailyList,
          record: record,
        ),
        DailyEventType.rating => _buildRatingTile(
          dailyIndex: dailyIndex,
          recordIndex: recordIndex,
          dailyList: dailyList,
          record: record,
        ),
        DailyEventType.favorite => _buildFavoriteTile(record),
        _ => const SizedBox.shrink(),
      };
    }

    Color dotFor(DailyEventType type) => switch (type) {
      DailyEventType.rating => Theme.of(context).colorScheme.primary,
      DailyEventType.favorite => Theme.of(
        context,
      ).colorScheme.tertiary,
      _ => Theme.of(context).colorScheme.secondary,
    };

    final rows = <Widget>[];
    for (var i = 0; i < allRecords.length; i++) {
      final entry = allRecords[i];
      final type = entry['type'] as DailyEventType;

      final canMergeRatingComment =
          type == DailyEventType.rating || type == DailyEventType.comment;
      if (canMergeRatingComment && i + 1 < allRecords.length) {
        final next = allRecords[i + 1];
        final nextType = next['type'] as DailyEventType;
        final pair = (type == DailyEventType.rating &&
                nextType == DailyEventType.comment) ||
            (type == DailyEventType.comment &&
                nextType == DailyEventType.rating);
        if (pair &&
            sameTime(entry, next) &&
            isCreated(entry) &&
            isCreated(next)) {
          final ratingE = type == DailyEventType.rating ? entry : next;
          final commentE = type == DailyEventType.comment ? entry : next;
          rows.add(
            rowOf(
              Theme.of(context).colorScheme.primary,
              _buildMergedRatingComment(ratingE, commentE),
            ),
          );
          i++; // 两条已合并，跳过下一条
          continue;
        }
      }

      rows.add(rowOf(dotFor(type), tileFor(entry)));
    }

    // 左侧贯穿时间轴
    final railColor = Theme.of(
      context,
    ).colorScheme.outlineVariant.withValues(alpha: 0.7);
    return buildMaterialWidget(
      context: context,
      widget: Stack(
        children: [
          Positioned(
            left: 8,
            top: 6,
            bottom: 6,
            child: Container(width: 1.5, color: railColor),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: rows,
          ),
        ],
      ),
    );
  }

  // 合并组内的点击次数
  Widget buildClickWidget(BuildContext context) {
    int totalClicks = 0;
    final recordStrings = <String>[];

    for (final stats in statsGroup) {
      final clickEvent = _getDailyEvent(stats.totalClickCount, selectedDay);
      if (clickEvent != null) {
        for (final record in clickEvent.platformEventRecords) {
          final sourceType = _getSourceType(stats.type);
          recordStrings.add(
            t.statsClickAt(
              source: sourceType,
              platform: record.platform?.value ?? t.statsUnknown,
              value: record.value,
            ),
          );
          totalClicks += record.value;
        }
      }
    }

    if (totalClicks == 0) {
      return const SizedBox.shrink();
    }

    final children = <Widget>[
      Text(
        t.statsDailyClicks(total: totalClicks),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 4),
      Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: recordStrings.map((text) {
                return _statsSourceChip(context, text);
              }).toList(),
            ),
          ),
        ],
      ),
    ];

    return buildMaterialWidget(
      context: context,
      widget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  // 合并组内的观看时间
  Widget buildWatchWidget(BuildContext context) {
    int totalSeconds = 0;
    final recordStrings = <String>[];

    for (final stats in statsGroup) {
      final watchEvent = _getDailyEvent(stats.totalWatchDurations, selectedDay);
      if (watchEvent != null) {
        for (final record in watchEvent.platformEventRecords) {
          final sourceType = _getSourceType(stats.type);
          recordStrings.add(
            t.statsWatchAt(
              source: sourceType,
              platform: record.platform?.value ?? t.statsUnknown,
              duration: Utils.formatHMS(record.value),
            ),
          );
          totalSeconds += record.value;
        }
      }
    }

    if (totalSeconds == 0) {
      return const SizedBox.shrink();
    }

    final children = [
      Text(
        t.statsDailyWatch(duration: Utils.formatHMS(totalSeconds)),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 4),
      Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: recordStrings.map((text) {
                return _statsSourceChip(context, text);
              }).toList(),
            ),
          ),
        ],
      ),
    ];

    return buildMaterialWidget(
      context: context,
      widget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget buildMaterialWidget({
    required BuildContext context,
    required Widget widget,
  }) {
    return Material(
      elevation: 2,
      color: Theme.of(context).colorScheme.secondaryContainer.toOpacity(0.72),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: widget,
      ),
    );
  }

  Widget buildInfoWidget(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.statsRecords,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        buildClickWidget(context),
        const SizedBox(height: 6),
        buildWatchWidget(context),
        const SizedBox(height: 6),
        buildAllEventsWidget(context),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget buildTitleWidget(BuildContext context, BangumiItem? bangumiItem) {
    final stats = _primaryStat;

    PlatformEventRecord? latestGroupClickRecord;
    PlatformEventRecord? latestGroupWatchRecord;

    for (final stat in statsGroup) {
      final clickEvent = _getDailyEvent(stat.totalClickCount, selectedDay);
      if (clickEvent != null) {
        final nonNullRecords = clickEvent.platformEventRecords
            .where((r) => r.date != null)
            .toList();
        if (nonNullRecords.isNotEmpty) {
          final latestInStat = nonNullRecords.reduce((a, b) {
            return a.date!.isAfter(b.date!) ? a : b;
          });
          if (latestGroupClickRecord == null ||
              latestInStat.date!.isAfter(latestGroupClickRecord.date!)) {
            latestGroupClickRecord = latestInStat;
          }
        }
      }

      final watchEvent = _getDailyEvent(stat.totalWatchDurations, selectedDay);
      if (watchEvent != null) {
        final nonNullRecords = watchEvent.platformEventRecords
            .where((r) => r.date != null)
            .toList();
        if (nonNullRecords.isNotEmpty) {
          final latestInStat = nonNullRecords.reduce((a, b) {
            return a.date!.isAfter(b.date!) ? a : b;
          });
          if (latestGroupWatchRecord == null ||
              latestInStat.date!.isAfter(latestGroupWatchRecord.date!)) {
            latestGroupWatchRecord = latestInStat;
          }
        }
      }
    }

    Widget buildCoverWidget() {
      String cover;
      if (bangumiItem != null) {
        cover = bangumiItem.images['large']!;
      } else {
        cover = stats.cover ?? '';
      }

      if (stats.cover == null && bangumiItem == null) {
        return const SizedBox.shrink();
      }

      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Hero(
          tag: stats.id,
          child: BangumiWidget.kostoriImage(
            context,
            cover,
            width: height * 0.72,
            height: height,
          ),
        ),
      );
    }

    Widget buildTypeWidget() {
      String type;
      if (stats.isBangumi) {
        type = 'bangumi';
      } else {
        type = _getSourceType(stats.type);
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pix, size: 16),
            const SizedBox(width: 4),
            Text(type, style: const TextStyle(fontSize: 14)),
          ],
        ),
      );
    }

    Widget titleBuild() {
      return bangumiItem != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bangumiItem.nameCn,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  bangumiItem.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            )
          : stats.title != null
          ? Text(
              stats.title!,
              style: const TextStyle(fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            )
          : const SizedBox.shrink();
    }

    final bool liked = _liked;

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildCoverWidget(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleBuild(),
                const Spacer(),
                Row(
                  children: [
                    Icon(
                      liked ? Icons.favorite : Icons.favorite_border,
                      color: Colors.redAccent,
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    buildTypeWidget(),
                  ],
                ),
                if (latestGroupClickRecord?.date != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.event, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          t.statsLastClickAt(
                            time: latestGroupClickRecord?.date!.hhmmss ?? '',
                          ),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
                if (latestGroupWatchRecord?.date != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          t.statsLastWatchAt(
                            time: latestGroupWatchRecord?.date!.hhmmss ?? '',
                          ),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryStat = _primaryStat;
    BangumiItem? bangumiItem;
    if (primaryStat.bangumiId != null) {
      bangumiItem = _bangumiItem;
    }

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: MediaQuery.of(context).size.width >= 850
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: buildTitleWidget(context, bangumiItem),
                ),
                Flexible(flex: 2, child: buildInfoWidget(context)),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: buildTitleWidget(context, bangumiItem)),
                  ],
                ),
                const SizedBox(height: 10),
                buildInfoWidget(context),
              ],
            ),
    );
  }
}



// 点击统计记录卡片后展示的条目历史（弹层界面）
class StatsTimelineView extends StatefulWidget {
  const StatsTimelineView({super.key, required this.group});

  final List<StatsDataImpl> group;

  @override
  State<StatsTimelineView> createState() => _StatsTimelineViewState();
}

class _TimelineEntry {
  final DateTime time;
  final Widget child;
  _TimelineEntry(this.time, this.child);
}

class _StatsTimelineViewState extends State<StatsTimelineView> {
  List<StatsDataImpl> _stats = const [];

  List<StatsDataImpl> get _group => _stats;

  StatsDataImpl get _primaryStat {
    final masterItems = _group.where((s) => s.isBangumi).toList();
    return masterItems.isNotEmpty ? masterItems.first : _group.first;
  }

  @override
  void initState() {
    super.initState();
    _stats = widget.group;
    _loadRelatedStats();
  }

  /// 统计按 bangumi id 统一：无论多少不同来源/平台，同一 bangumi 视为一个条目，
  /// 时间线应包含该 bangumi 在全部统计里的历史，而非只取当天有记录的几条
  Future<void> _loadRelatedStats() async {
    final primary = _primaryStat;
    if (primary.bangumiId == null) return;
    try {
      final all = await StatsManager().getStatsAll();
      final related = all
          .where((s) => s.bangumiId == primary.bangumiId)
          .toList();
      if (related.isEmpty) return;
      if (!mounted) return;
      setState(() => _stats = related);
    } catch (e) {
      StatsLog.error('StatsTimelineView._loadRelatedStats', e.toString());
    }
  }


  String _durationSuffix(int? seconds) {
    seconds ??= 0;
    if (seconds <= 0) return '';
    return t.statsRatedAt(duration: Utils.formatHMS(seconds));
  }

  String _favoriteActionText(PlatformEventRecord record) {
    switch (record.favoriteAction) {
      case FavoriteAction.add:
        return t.addToFolder(folder: _statFolderLabel(record.favorite));
      case FavoriteAction.remove:
        return t.removeFromFolder(folder: _statFolderLabel(record.favorite));
      case FavoriteAction.move:
        final folder = record.favorite;
        if (folder != null && folder.contains(',')) {
          final parts = folder.split(',');
          return t.movedFromTo(
            from: _statFolderLabel(parts[0]),
            to: _statFolderLabel(parts[1]),
          );
        }
        return t.moveOperationTargetUnknown;
      default:
        return t.operationUnknown;
    }
  }

  List<_TimelineEntry> _collectEntries() {
    final entries = <_TimelineEntry>[];

    void addCommentOrRating({
      required DailyEventType type,
      required List<DailyEvent> dailyList,
    }) {
      if (dailyList.isEmpty) return;
      final isComment = type == DailyEventType.comment;
      for (int dailyIndex = 0; dailyIndex < dailyList.length; dailyIndex++) {
        final records = dailyList[dailyIndex].platformEventRecords;
        for (int recordIndex = 0;
            recordIndex < records.length;
            recordIndex++) {
          final record = records[recordIndex];
          final time = record.date ??
              dailyList[dailyIndex].date.add(const Duration(hours: 12));
          String text;
          if (dailyIndex == 0 && recordIndex == 0) {
            text = isComment
                ? t.statsCreatedComment(
                    time: time.hhmmss,
                    duration: _durationSuffix(record.watchDuration),
                  )
                : t.statsCreatedRating(
                    time: time.hhmmss,
                    duration: _durationSuffix(record.watchDuration),
                  );
          } else {
            int n;
            if (dailyIndex == 0) {
              n = record.value - 1;
            } else {
              int sum = 0;
              for (int i = 0; i < dailyIndex; i++) {
                final rl = dailyList[i].platformEventRecords;
                if (rl.isNotEmpty) sum += rl.last.value;
              }
              n = sum + record.value - 1;
            }
            text = isComment
                ? t.statsModifiedComment(
                    time: time.hhmmss,
                    n: n,
                    duration: _durationSuffix(record.watchDuration),
                  )
                : t.statsModifiedRating(
                    time: time.hhmmss,
                    n: n,
                    duration: _durationSuffix(record.watchDuration),
                  );
          }
          final String? content = record.comment?.isNotEmpty == true
              ? record.comment
              : record.rating != null
              ? '${record.rating}'
              : null;
          entries.add(
            _TimelineEntry(
              time,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(text, style: const TextStyle(fontSize: 14)),
                  if (content != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      content,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
      }
    }

    for (final stat in _group) {
      addCommentOrRating(
        type: DailyEventType.comment,
        dailyList: stat.comment,
      );
      addCommentOrRating(
        type: DailyEventType.rating,
        dailyList: stat.rating,
      );
      for (final daily in stat.favorite) {
        for (final record in daily.platformEventRecords) {
          if (record.favoriteAction == null && record.favorite == null) {
            continue;
          }
          final time = record.date ?? daily.date.add(const Duration(hours: 12));
          entries.add(
            _TimelineEntry(
              time,
              Text(
                '${time.hhmmss} ${_favoriteActionText(record)}',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          );
        }
      }

      // 观看 / 点击（按天汇总，一天一条，避免空白）
      void addDailyTotal(
        List<DailyEvent> list, {
        required int Function(PlatformEventRecord) totalOf,
        required String Function(int) labelOf,
      }) {
        for (final daily in list) {
          final records =
              daily.platformEventRecords
                  .where((r) => totalOf(r) > 0)
                  .toList();
          if (records.isEmpty) continue;
          int total = 0;
          DateTime? last;
          for (final r in records) {
            total += totalOf(r);
            if (r.date != null &&
                (last == null || r.date!.isAfter(last))) {
              last = r.date;
            }
          }
          final time = last ?? daily.date.add(const Duration(hours: 12));
          entries.add(
            _TimelineEntry(
              time,
              Text(
                '${time.hhmmss} ${labelOf(total)}',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          );
        }
      }

      addDailyTotal(
        stat.totalWatchDurations,
        totalOf: (r) => r.value,
        labelOf: (v) =>
            t.statsTimelineWatch(duration: Utils.formatHMS(v)),
      );
      addDailyTotal(
        stat.totalClickCount,
        totalOf: (r) => r.value,
        labelOf: (v) => t.statsTimelineClick(value: v),
      );
    }
    entries.sort((a, b) => a.time.compareTo(b.time));
    return entries;
  }

  Widget _header(BuildContext context) {
    final primary = _primaryStat;
    final colorScheme = Theme.of(context).colorScheme;
    final cover = primary.cover;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: cover?.isNotEmpty == true
                ? BangumiWidget.kostoriImage(
                    context,
                    cover!,
                    width: 84,
                    height: 118,
                  )
                : Container(
                    width: 84,
                    height: 118,
                    color: colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.image_outlined),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _title(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _title() {
    final title = _primaryStat.title;
    return (title?.isNotEmpty == true) ? title! : _primaryStat.id;
  }

  @override
  @override
  @override
  Widget build(BuildContext context) {
    final entries = _collectEntries();
    final colorScheme = Theme.of(context).colorScheme;
    final lineColor = colorScheme.outlineVariant;

    Widget body;
    if (entries.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Text(
            t.statsTimelineNoRecords,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ),
      );
    } else {
      // 同一天内按时间升序
      final byDate = <DateTime, List<_TimelineEntry>>{};
      for (final e in entries) {
        final day = DateTime(e.time.year, e.time.month, e.time.day);
        byDate.putIfAbsent(day, () => []).add(e);
      }
      for (final l in byDate.values) {
        l.sort((a, b) => a.time.compareTo(b.time));
      }
      final dates = byDate.keys.toList()..sort((a, b) => b.compareTo(a));
      final years = dates.map((d) => d.year).toSet().toList()
        ..sort((a, b) => b.compareTo(a));
      final monthsOf = <int, List<int>>{};
      final daysOf = <String, List<DateTime>>{};
      for (final d in dates) {
        final ys = monthsOf.putIfAbsent(d.year, () => []);
        if (!ys.contains(d.month)) {
          ys.add(d.month);
        }
        daysOf.putIfAbsent('${d.year}-${d.month}', () => []).add(d);
      }
      for (final l in monthsOf.values) {
        l.sort((a, b) => b.compareTo(a));
      }
      for (final l in daysOf.values) {
        l.sort((a, b) => b.compareTo(a));
      }

      Widget recordTile(
        _TimelineEntry e, {
        required bool isFirst,
        required bool isLast,
      }) {
        return TimelineTile(
          alignment: TimelineAlign.start,
          isFirst: isFirst,
          isLast: isLast,
          indicatorStyle: IndicatorStyle(
            color: colorScheme.primary.withValues(alpha: 0.85),
            width: 8,
          ),
          beforeLineStyle: LineStyle(color: lineColor, thickness: 1.4),
          afterLineStyle: LineStyle(color: lineColor, thickness: 1.4),
          endChild: Padding(
            padding: const EdgeInsets.only(right: 12, top: 2, bottom: 2),
            child: e.child,
          ),
        );
      }

      Widget recordsSpine(List<_TimelineEntry> dayRecords) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < dayRecords.length; i++)
              recordTile(
                dayRecords[i],
                isFirst: i == 0,
                isLast: i == dayRecords.length - 1,
              ),
          ],
        );
      }

      // 日节点：日标签 + 日内记录子线
      Widget dayNode(
        DateTime day, {
        bool isFirst = false,
        bool isLast = false,
      }) {
        final dayRecords = byDate[day]!;
        return TimelineTile(
          alignment: TimelineAlign.start,
          isFirst: isFirst,
          isLast: isLast,
          indicatorStyle: IndicatorStyle(
            color: colorScheme.tertiary,
            width: 11,
          ),
          beforeLineStyle: LineStyle(color: lineColor, thickness: 1.4),
          afterLineStyle: LineStyle(color: lineColor, thickness: 1.4),
          endChild: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.statsTimelineDay(month: day.month, day: day.day),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (dayRecords.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 22, top: 6),
                  child: recordsSpine(dayRecords),
                ),
            ],
          ),
        );
      }

      // 月节点：月标签 + 该月各日节点子线
      Widget monthNode(
        int year,
        int month, {
        bool isFirst = false,
        bool isLast = false,
      }) {
        final monthDays = daysOf['$year-$month']!;
        return TimelineTile(
          alignment: TimelineAlign.start,
          isFirst: isFirst,
          isLast: isLast,
          indicatorStyle: IndicatorStyle(
            color: colorScheme.secondary,
            width: 12,
          ),
          beforeLineStyle: LineStyle(color: lineColor, thickness: 1.4),
          afterLineStyle: LineStyle(color: lineColor, thickness: 1.4),
          endChild: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$year-${month.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              if (monthDays.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 24, top: 8, bottom: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < monthDays.length; i++)
                        dayNode(
                          monthDays[i],
                          isFirst: i == 0,
                          isLast: i == monthDays.length - 1,
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      }

      // 年节点：年标签 + 该年各月节点子线
      Widget yearNode(
        int year, {
        bool isFirst = false,
        bool isLast = false,
      }) {
        final yearMonths = monthsOf[year]!;
        return TimelineTile(
          alignment: TimelineAlign.start,
          isFirst: isFirst,
          isLast: isLast,
          indicatorStyle: IndicatorStyle(
            color: colorScheme.primary,
            width: 16,
          ),
          beforeLineStyle: LineStyle(color: lineColor, thickness: 1.8),
          afterLineStyle: LineStyle(color: lineColor, thickness: 1.8),
          endChild: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.statsYearSuffix(year: year),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 26, top: 8, bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < yearMonths.length; i++)
                      monthNode(
                        year,
                        yearMonths[i],
                        isFirst: i == 0,
                        isLast: i == yearMonths.length - 1,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      }

      final yearTiles = <Widget>[];
      for (var i = 0; i < years.length; i++) {
        yearTiles.add(
          yearNode(years[i], isFirst: i == 0, isLast: i == years.length - 1),
        );
      }
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: yearTiles,
      );
    }

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: [
        _header(context),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Text(
            t.statsRecords,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        body,
      ],
    );
  }
}
