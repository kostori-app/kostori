part of 'stats_page.dart';

class StatItemWidget extends StatelessWidget {
  final List<StatsDataImpl> statsGroup;
  final DateTime selectedDay;

  StatItemWidget({
    super.key,
    required this.statsGroup,
    required this.selectedDay,
  });

  StatsDataImpl get _primaryStat {
    final masterItems = statsGroup.where((stat) => stat.isBangumi).toList();
    if (masterItems.isNotEmpty) {
      return masterItems.first;
    }
    return statsGroup.first;
  }

  final height =
      (App.isAndroid || MediaQuery.of(App.rootContext).size.width <= 700)
      ? 210.0
      : 300.0;

  String formatHMSForRating({int? seconds}) {
    seconds ??= 0;
    if (seconds <= 0) return '';
    return '(评价时 ${_formatHMS(seconds)})';
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
                    ? '${record.date!.hhmmss} 创建了评论 ${formatHMSForRating(seconds: record.watchDuration)}:'
                    : '${record.date!.hhmmss} 第${record.value - 1}次修改了评论 ${formatHMSForRating(seconds: record.watchDuration)}:';
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
                          record.comment ?? '',
                          style: const TextStyle(fontSize: 14),
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
                final text =
                    '${record.date!.hhmmss} 第${sum + record.value - 1}次修改了评论 ${formatHMSForRating(seconds: record.watchDuration)}:';
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
                          record.comment ?? '',
                          style: const TextStyle(fontSize: 14),
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
                    ? '${record.date!.hhmmss} 创建了评级 ${formatHMSForRating(seconds: record.watchDuration)}:'
                    : '${record.date!.hhmmss} 第${record.value - 1}次修改了评级 ${formatHMSForRating(seconds: record.watchDuration)}:';
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
                final text =
                    '${record.date!.hhmmss} 第${sum + record.value - 1}次修改了评级 ${formatHMSForRating(seconds: record.watchDuration)}:';
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
              String actionText;
              switch (record.favoriteAction) {
                case FavoriteAction.add:
                  actionText = "添加到 ${record.favorite?.tl ?? '未知文件夹'}";
                  break;
                case FavoriteAction.remove:
                  actionText = "从 ${record.favorite?.tl ?? '未知文件夹'} 删除";
                  break;
                case FavoriteAction.move:
                  if (record.favorite != null &&
                      record.favorite!.contains(',')) {
                    final parts = record.favorite!.split(',');
                    actionText = "从 ${parts[0].tl} 移动到 ${parts[1].tl}";
                  } else {
                    actionText = "移动操作，目标未知".tl;
                  }
                  break;
                default:
                  actionText = "操作未知".tl;
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
            '[$sourceType] ${record.platform?.value ?? '未知'}点击${record.value}次',
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
        '本日点击次数: $totalClicks',
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
          final sourceType = _getSourceType(stats.type); // 使用处理过的sourceType
          recordStrings.add(
            '[$sourceType] ${record.platform?.value ?? '未知'}观看: ${_formatHMS(record.value)}',
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
        '本日观看时长: ${_formatHMS(totalSeconds)}',
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
          '记录',
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
        cover = stats.cover!;
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
            showPlaceholder: true,
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

    final bool liked = StatsManager().getGroupLikedStatus(
      id: stats.id,
      type: stats.type,
    );

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
                          '当日最后点击: \n${latestGroupClickRecord?.date!.hhmmss}',
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
                          '当日最后观看: \n${latestGroupWatchRecord?.date!.hhmmss}',
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
      bangumiItem = BangumiManager().getBangumiItem(primaryStat.bangumiId!);
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
