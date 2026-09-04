part of 'stats_page.dart';

/// 统计里展示收藏分组：未分类伪组(_default/default/默认)显示为“未分类”
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

    return buildMaterialWidget(
      context: context,
      widget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: allRecords.map((entry) {
          final type = entry['type'] as DailyEventType;
          final dailyIndex = entry['dailyIndex'] as int;
          final recordIndex = entry['recordIndex'] as int;
          final dailyList = entry['dailyList'] as List<DailyEvent>;
          final record = entry['record'] as PlatformEventRecord;

          switch (type) {
            case DailyEventType.comment:
              if (dailyList.length == 1 || dailyIndex == 0) {
                final text = recordIndex == 0
                    ? t.statsCreatedComment(
                        time: record.date!.hhmmss,
                        duration: formatHMSForRating(
                          seconds: record.watchDuration,
                        ),
                      )
                    : t.statsModifiedComment(
                        time: record.date!.hhmmss,
                        n: record.value - 1,
                        duration: formatHMSForRating(
                          seconds: record.watchDuration,
                        ),
                      );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            text,
                            style: const TextStyle(fontSize: 14),
                          ),
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
                          child: Text(
                            text,
                            style: const TextStyle(fontSize: 14),
                          ),
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

            case DailyEventType.rating:
              if (dailyList.length == 1 || dailyIndex == 0) {
                final text = recordIndex == 0
                    ? t.statsCreatedRating(
                        time: record.date!.hhmmss,
                        duration: formatHMSForRating(
                          seconds: record.watchDuration,
                        ),
                      )
                    : t.statsModifiedRating(
                        time: record.date!.hhmmss,
                        n: record.value - 1,
                        duration: formatHMSForRating(
                          seconds: record.watchDuration,
                        ),
                      );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            text,
                            style: const TextStyle(fontSize: 14),
                          ),
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
                          itemBuilder: (context, index) =>
                              const Icon(Icons.star_rounded),
                          itemSize: 20.0,
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
                final text = t.statsModifiedRating(
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
                          child: Text(
                            text,
                            style: const TextStyle(fontSize: 14),
                          ),
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
                          itemBuilder: (context, index) =>
                              const Icon(Icons.star_rounded),
                          itemSize: 20.0,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                );
              }

            case DailyEventType.favorite:
              return _buildFavoriteTile(record);

            default:
              return const SizedBox.shrink();
          }
        }).toList(),
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
                return Text(text, style: const TextStyle(fontSize: 14));
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
                return Text(text, style: const TextStyle(fontSize: 14));
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
