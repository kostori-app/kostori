import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/database/favorites.dart';
import 'package:kostori/database/history.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/anime_type.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/services/download/download_manager.dart';

/// 单个筛选条件的状态：不筛 / 必须有 / 必须没有。
enum AnimeFilterMode { any, only, exclude }

/// 探索页 / AnimeList 的卡片筛选条件。
///
/// 关键词匹配卡片上展示的全部文本；收藏/历史/下载/副标题/标签/简介条件各为
/// 三态（不筛 / 有 / 无），多个条件之间是「与」关系（全部满足才显示）。
class AnimeFilter {
  const AnimeFilter({
    this.keyword = '',
    this.favorite = AnimeFilterMode.any,
    this.history = AnimeFilterMode.any,
    this.download = AnimeFilterMode.any,
    this.subtitle = AnimeFilterMode.any,
    this.tags = AnimeFilterMode.any,
    this.description = AnimeFilterMode.any,
  });

  final String keyword;

  final AnimeFilterMode favorite;
  final AnimeFilterMode history;
  final AnimeFilterMode download;
  final AnimeFilterMode subtitle;
  final AnimeFilterMode tags;
  final AnimeFilterMode description;

  static const AnimeFilter none = AnimeFilter();

  /// 是否有任何生效条件（决定是否真正过滤）
  bool get isActive =>
      keyword.trim().isNotEmpty ||
      favorite != AnimeFilterMode.any ||
      history != AnimeFilterMode.any ||
      download != AnimeFilterMode.any ||
      subtitle != AnimeFilterMode.any ||
      tags != AnimeFilterMode.any ||
      description != AnimeFilterMode.any;

  AnimeFilter copyWith({
    String? keyword,
    AnimeFilterMode? favorite,
    AnimeFilterMode? history,
    AnimeFilterMode? download,
    AnimeFilterMode? subtitle,
    AnimeFilterMode? tags,
    AnimeFilterMode? description,
  }) => AnimeFilter(
    keyword: keyword ?? this.keyword,
    favorite: favorite ?? this.favorite,
    history: history ?? this.history,
    download: download ?? this.download,
    subtitle: subtitle ?? this.subtitle,
    tags: tags ?? this.tags,
    description: description ?? this.description,
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

  /// 三态判定：any 恒通过；only 要求有；exclude 要求没有。
  static bool _pass(AnimeFilterMode mode, bool has) => switch (mode) {
    AnimeFilterMode.any => true,
    AnimeFilterMode.only => has,
    AnimeFilterMode.exclude => !has,
  };

  bool matches(Anime anime) {
    final k = keyword.trim().toLowerCase();
    if (k.isNotEmpty && !_textMatches(anime, k)) return false;
    if (favorite != AnimeFilterMode.any || history != AnimeFilterMode.any) {
      final type = AnimeType(anime.sourceKey.hashCode);
      if (!_pass(favorite, LocalFavoritesManager().isExist(anime.id, type))) {
        return false;
      }
      if (!_pass(history, HistoryManager().find(anime.id, type) != null)) {
        return false;
      }
    }
    if (download != AnimeFilterMode.any &&
        !_pass(
          download,
          DownloadManager.instance.isDownloaded(anime.id, anime.sourceKey),
        )) {
      return false;
    }
    if (!_pass(subtitle, anime.subtitle?.isNotEmpty ?? false)) return false;
    if (!_pass(tags, anime.tags?.isNotEmpty ?? false)) return false;
    if (!_pass(description, anime.description.isNotEmpty)) return false;
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
      other.favorite == favorite &&
      other.history == history &&
      other.download == download &&
      other.subtitle == subtitle &&
      other.tags == tags &&
      other.description == description;

  @override
  int get hashCode => Object.hash(
    keyword,
    favorite,
    history,
    download,
    subtitle,
    tags,
    description,
  );
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

/// 筛选条：关键词输入框（右侧退出按钮）+ 下方条件胶囊。
/// 探索页顶部（替换一二级 tab）与 AnimeList 内嵌共用。
class AnimeFilterBar extends StatefulWidget {
  const AnimeFilterBar({
    super.key,
    required this.filter,
    required this.onChanged,
    this.onExit,
    this.contextLabel,
    this.padding = const EdgeInsets.fromLTRB(12, 4, 12, 6),
  });

  final AnimeFilter filter;
  final ValueChanged<AnimeFilter> onChanged;

  /// 退出筛选（关闭整个筛选态）：输入框右侧的按钮
  final VoidCallback? onExit;

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

  static AnimeFilterMode _next(AnimeFilterMode mode) => switch (mode) {
    AnimeFilterMode.any => AnimeFilterMode.only,
    AnimeFilterMode.only => AnimeFilterMode.exclude,
    AnimeFilterMode.exclude => AnimeFilterMode.any,
  };

  Widget _chip({
    required ColorScheme cs,
    required String neutral,
    required String only,
    required String exclude,
    required AnimeFilterMode mode,
    required ValueChanged<AnimeFilterMode> onChanged,
  }) {
    final label = switch (mode) {
      AnimeFilterMode.any => neutral,
      AnimeFilterMode.only => only,
      AnimeFilterMode.exclude => exclude,
    };
    return CapsuleChip(
      text: label,
      isSelected: mode != AnimeFilterMode.any,
      selectedColor: mode == AnimeFilterMode.exclude ? cs.error : null,
      onTap: () => onChanged(_next(mode)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final f = widget.filter;
    return Padding(
      padding: widget.padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
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
              ),
              if (widget.onExit != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  tooltip: t.exploreFilterExit,
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  onPressed: widget.onExit,
                ),
              ],
            ],
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
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
            ),
          ],
          const SizedBox(height: 6),
          // 多选条件：用独立高亮的胶囊 chip（CapsuleOptions 是单选语义，
          // 只会高亮其中一项）。每个条件点按在 不筛→有→无 之间循环。
          CapsuleChipGroup(
            alignment: WrapAlignment.center,
            children: [
              _chip(
                cs: cs,
                neutral: t.favorite,
                only: t.exploreFilterFavorite,
                exclude: t.exploreFilterNoFavorite,
                mode: f.favorite,
                onChanged: (m) => widget.onChanged(f.copyWith(favorite: m)),
              ),
              _chip(
                cs: cs,
                neutral: t.history,
                only: t.exploreFilterHistory,
                exclude: t.exploreFilterNoHistory,
                mode: f.history,
                onChanged: (m) => widget.onChanged(f.copyWith(history: m)),
              ),
              _chip(
                cs: cs,
                neutral: t.download,
                only: t.exploreFilterDownload,
                exclude: t.exploreFilterNoDownload,
                mode: f.download,
                onChanged: (m) => widget.onChanged(f.copyWith(download: m)),
              ),
              _chip(
                cs: cs,
                neutral: t.exploreFilterSubtitle,
                only: t.exploreFilterHasSubtitle,
                exclude: t.exploreFilterNoSubtitle,
                mode: f.subtitle,
                onChanged: (m) => widget.onChanged(f.copyWith(subtitle: m)),
              ),
              _chip(
                cs: cs,
                neutral: t.exploreFilterTags,
                only: t.exploreFilterHasTags,
                exclude: t.exploreFilterNoTags,
                mode: f.tags,
                onChanged: (m) => widget.onChanged(f.copyWith(tags: m)),
              ),
              _chip(
                cs: cs,
                neutral: t.exploreFilterDescription,
                only: t.exploreFilterHasDescription,
                exclude: t.exploreFilterNoDescription,
                mode: f.description,
                onChanged: (m) => widget.onChanged(f.copyWith(description: m)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
