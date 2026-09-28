import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/database/favorites.dart';
import 'package:kostori/database/history.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/anime_type.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/services/download/download_manager.dart';

/// 探索页 / AnimeList 的卡片筛选条件。
///
/// 关键词匹配卡片上展示的全部文本（标题/副标题/标签/简介/描述行/语言）；
/// 收藏 / 历史 / 下载记录三个开关多选时为「与」关系（全部满足才显示）。
class AnimeFilter {
  const AnimeFilter({
    this.keyword = '',
    this.favoriteOnly = false,
    this.historyOnly = false,
    this.downloadOnly = false,
  });

  final String keyword;
  final bool favoriteOnly;
  final bool historyOnly;
  final bool downloadOnly;

  static const AnimeFilter none = AnimeFilter();

  /// 是否有任何生效条件（决定是否真正过滤）
  bool get isActive =>
      keyword.trim().isNotEmpty || favoriteOnly || historyOnly || downloadOnly;

  AnimeFilter copyWith({
    String? keyword,
    bool? favoriteOnly,
    bool? historyOnly,
    bool? downloadOnly,
  }) => AnimeFilter(
    keyword: keyword ?? this.keyword,
    favoriteOnly: favoriteOnly ?? this.favoriteOnly,
    historyOnly: historyOnly ?? this.historyOnly,
    downloadOnly: downloadOnly ?? this.downloadOnly,
  );

  /// 卡片文本是否命中关键词（不区分大小写）
  bool _textMatches(Anime anime, String k) {
    if (anime.title.toLowerCase().contains(k)) return true;
    final subtitle = anime.subtitle;
    if (subtitle != null &&
        subtitle.isNotEmpty &&
        subtitle.toLowerCase().contains(k)) {
      return true;
    }
    if (anime.description.toLowerCase().contains(k)) return true;
    for (final t in anime.tags ?? const <String>[]) {
      if (t.toLowerCase().contains(k)) return true;
    }
    for (final l in anime.descriptionLines ?? const <AnimeDescriptionLine>[]) {
      if (l.text.toLowerCase().contains(k)) return true;
    }
    final language = anime.language;
    if (language != null &&
        language.isNotEmpty &&
        language.toLowerCase().contains(k)) {
      return true;
    }
    return false;
  }

  bool matches(Anime anime) {
    final k = keyword.trim().toLowerCase();
    if (k.isNotEmpty && !_textMatches(anime, k)) return false;
    if (!favoriteOnly && !historyOnly && !downloadOnly) return true;
    final type = AnimeType(anime.sourceKey.hashCode);
    if (favoriteOnly && !LocalFavoritesManager().isExist(anime.id, type)) {
      return false;
    }
    if (historyOnly && HistoryManager().find(anime.id, type) == null) {
      return false;
    }
    if (downloadOnly &&
        !DownloadManager.instance.isDownloaded(anime.id, anime.sourceKey)) {
      return false;
    }
    return true;
  }

  /// 过滤一列卡片；[filter] 为空或不生效时原样返回（避免无谓分配）。
  static List<Anime> apply(List<Anime> list, AnimeFilter? filter) {
    if (filter == null || !filter.isActive) return list;
    return list.where(filter.matches).toList();
  }

  @override
  bool operator ==(Object other) =>
      other is AnimeFilter &&
      other.keyword == keyword &&
      other.favoriteOnly == favoriteOnly &&
      other.historyOnly == historyOnly &&
      other.downloadOnly == downloadOnly;

  @override
  int get hashCode =>
      Object.hash(keyword, favoriteOnly, historyOnly, downloadOnly);
}

/// 把当前筛选条件下发给子树里的 AnimeList / mixed / multipart。
/// [filter] 为 null 表示未启用筛选（不过滤）。
class AnimeFilterScope extends InheritedWidget {
  const AnimeFilterScope({
    super.key,
    required this.filter,
    required super.child,
  });

  final AnimeFilter? filter;

  static AnimeFilter? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AnimeFilterScope>()?.filter;

  @override
  bool updateShouldNotify(AnimeFilterScope oldWidget) =>
      filter != oldWidget.filter;
}

/// 筛选条：关键词输入框 + 下方收藏/历史/下载分段胶囊。
/// 探索页顶部（替换一二级 tab）与 AnimeList 内嵌共用。
class AnimeFilterBar extends StatefulWidget {
  const AnimeFilterBar({
    super.key,
    required this.filter,
    required this.onChanged,
    this.contextLabel,
    this.padding = const EdgeInsets.fromLTRB(12, 4, 12, 6),
  });

  final AnimeFilter filter;
  final ValueChanged<AnimeFilter> onChanged;

  /// 输入框下方的一行上下文说明（如「源 · 页」），用于开启筛选后替代被隐藏的 tab。
  final String? contextLabel;

  final EdgeInsetsGeometry padding;

  @override
  State<AnimeFilterBar> createState() => _AnimeFilterBarState();
}

class _AnimeFilterBarState extends State<AnimeFilterBar> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.filter.keyword,
  );

  /// 关键词防抖：避免每敲一个字都全量过滤所有已加载卡片（大列表卡顿）
  Timer? _debounce;

  @override
  void didUpdateWidget(covariant AnimeFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 仅在外部真的改了关键词时同步输入框（避免无关重建打断输入 / 防抖中的输入）
    if (widget.filter.keyword != oldWidget.filter.keyword &&
        widget.filter.keyword != _ctrl.text) {
      _ctrl.text = widget.filter.keyword;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onKeywordChanged(String value) {
    // 立即刷新清除按钮显隐
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 160), () {
      widget.onChanged(widget.filter.copyWith(keyword: value));
    });
  }

  void _clearKeyword() {
    _debounce?.cancel();
    _ctrl.clear();
    widget.onChanged(widget.filter.copyWith(keyword: ''));
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.filter;
    return Padding(
      padding: widget.padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _ctrl,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            onChanged: _onKeywordChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: t.exploreFilterHint,
              isDense: true,
              prefixIcon: const Icon(Icons.filter_alt_outlined, size: 20),
              suffixIcon: _ctrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: _clearKeyword,
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
          if (widget.contextLabel != null &&
              widget.contextLabel!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.contextLabel!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
          const SizedBox(height: 6),
          // 多选条件：用独立高亮的胶囊 chip（CapsuleOptions 是单选语义，
          // 只会高亮其中一项，会让人误以为三者互斥）。
          CapsuleChipGroup(
            alignment: WrapAlignment.center,
            children: [
              CapsuleChip(
                text: t.exploreFilterFavorite,
                isSelected: f.favoriteOnly,
                onTap: () =>
                    widget.onChanged(f.copyWith(favoriteOnly: !f.favoriteOnly)),
              ),
              CapsuleChip(
                text: t.exploreFilterHistory,
                isSelected: f.historyOnly,
                onTap: () =>
                    widget.onChanged(f.copyWith(historyOnly: !f.historyOnly)),
              ),
              CapsuleChip(
                text: t.exploreFilterDownload,
                isSelected: f.downloadOnly,
                onTap: () =>
                    widget.onChanged(f.copyWith(downloadOnly: !f.downloadOnly)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
