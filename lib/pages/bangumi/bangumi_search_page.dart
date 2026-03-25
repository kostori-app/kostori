import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/components/animated.dart';
import 'package:kostori/components/bangumi_widget.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/components/share_widget.dart';
import 'package:kostori/database/search_history.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/foundation/bangumi/character/character_casts_item.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/network/bangumi.dart';
import 'package:kostori/pages/bangumi/bangumi_info_page.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/utils/utils.dart';

class BangumiSearchPage extends ConsumerStatefulWidget {
  const BangumiSearchPage({super.key, this.tag});

  final String? tag;

  @override
  ConsumerState<BangumiSearchPage> createState() => _BangumiSearchPageState();
}

class _BangumiSearchPageState extends ConsumerState<BangumiSearchPage> {
  final ScrollController _scrollController = ScrollController();
  final maxWidth = 1250.0;
  List<String> tags = [];
  List<BangumiItem> bangumiItems = [];
  List<CharacterActor> characterItmes = [];
  List<BangumiItem> subjectSearchSuggestions = [];
  List<CharacterActor> characterSearchSuggestions = [];
  Map<BangumiItem, bool> selectedBangumiItems = {};
  Map<CharacterActor, bool> selectedCharacterItems = {};

  bool useBriefMode = false;
  bool displayLabels = false;
  bool multiSelectMode = false;

  int? lastSelectedIndex;

  String keyword = '';

  String sort = 'rank';

  bool _isLoading = false;
  bool _showFab = false;

  String airDate = '';
  String endDate = '';

  Timer? _debounce;
  int _searchToken = 0;

  String defaultCategory = 'subject';
  bool subjectSearch = true;

  final TextEditingController _controller = TextEditingController();
  bool _showSearchHistory = false;
  bool _showSearchSuggestions = false;

  final List<String> options = [
    t.bestMatch,
    t.topRank,
    t.mostFavorited,
    t.highestRating,
  ];

  String selectedOption = t.topRank;
  final Map<String, String> optionToSortType = {
    t.bestMatch: 'match',
    t.topRank: 'rank',
    t.mostFavorited: 'heat',
    t.highestRating: 'score',
  };

  final Map<String, String> sortTypeToOption = {
    'match': t.bestMatch,
    'rank': t.topRank,
    'heat': t.mostFavorited,
    'score': t.highestRating,
  };

  final Map<String, String> searchCategory = {
    'subject': t.subject,
    'character': t.character,
    'person': t.person,
  };

  @override
  void initState() {
    super.initState();
    if (widget.tag != null) {
      tags.add(widget.tag!);
      displayLabels = true;
      _loadinitial();
    }
    _scrollController.addListener(_loadMoreData);
  }

  @override
  void dispose() {
    bangumiItems.clear();
    _scrollController.removeListener(_loadMoreData);
    _debounce?.cancel();
    super.dispose();
  }

  Future<List<BangumiItem>> bangumiSearch() async {
    return Bangumi.instance.bangumiPostSearch(
      keyword,
      tags: tags,
      sort: sort,
      airDate: airDate,
      endDate: endDate,
    );
  }

  Future<List<CharacterActor>> bangumiCharacterSearch(String keyword) async {
    return Bangumi.instance.postCharactersSearchByStringNext(keyword: keyword);
  }

  Future<List<CharacterActor>> bangumiPersonSearch(String keyword) async {
    return Bangumi.instance.postPersonsSearchByStringNext(keyword: keyword);
  }

  Future<void> _loadinitial() async {
    setState(() {
      _isLoading = true;
    });
    final newItems = await bangumiSearch();
    bangumiItems = newItems;
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreData() async {
    final bool showFab = _scrollController.offset > 200;
    if (showFab != _showFab) {
      setState(() {
        _showFab = showFab;
      });
    }
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        (bangumiItems.length >= 20 || characterItmes.length >= 20) &&
        !multiSelectMode) {
      setState(() {
        _isLoading = true;
      });
      if (subjectSearch) {
        final result = await Bangumi.instance.bangumiPostSearch(
          keyword,
          tags: tags,
          offset: bangumiItems.length,
          sort: sort,
          airDate: airDate,
          endDate: endDate,
        );
        bangumiItems.addAll(result);
      } else if (defaultCategory == 'character') {
        final result = await Bangumi.instance.postCharactersSearchByStringNext(
          keyword: keyword,
          offset: characterItmes.length,
        );
        characterItmes.addAll(result);
      } else if (defaultCategory == 'person') {
        final result = await Bangumi.instance.postPersonsSearchByStringNext(
          keyword: keyword,
          offset: characterItmes.length,
        );
        characterItmes.addAll(result);
      }

      setState(() {
        _isLoading = false;
      });
    }
  }

  // 构建所有标签分类
  // 在State类中添加以下变量
  int selectedCountForCategory(TagCategory category) {
    return tags.where((tag) => category.tags.contains(tag)).length;
  }

  final categories = [
    TagCategory(title: t.type, tags: type),
    TagCategory(title: t.background, tags: background),
    TagCategory(title: t.characters, tags: role),
    TagCategory(title: t.emotion, tags: emotional),
    TagCategory(title: t.source, tags: source),
    TagCategory(title: t.audience, tags: audience),
    TagCategory(title: t.categories, tags: classification),
  ];

  // 分类选择栏
  List<Widget> _buildTagCategories() {
    return [
      SliverToBoxAdapter(
        child: SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final selectedCount = selectedCountForCategory(category);
              final isSelected = selectedCount > 0;
              final colorScheme = Theme.of(context).colorScheme;

              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  onTap: () => _showTagSelectionDialog(context, category),
                  borderRadius: BorderRadius.circular(6),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colorScheme.primary.toOpacity(0.08)
                          : colorScheme.surfaceContainerHighest.toOpacity(0.6),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        width: 0.5,
                        color: isSelected
                            ? colorScheme.primary.toOpacity(0.5)
                            : colorScheme.outline.toOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          category.title,
                          style: TextStyle(
                            fontSize: 13,
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.onSurface,
                            fontWeight: isSelected
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '$selectedCount',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ];
  }

  // 标签选择对话框
  void _showTagSelectionDialog(BuildContext context, TagCategory category) {
    final currentSelected = List<String>.from(
      tags.where((tag) => category.tags.contains(tag)),
    );

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final color = Theme.of(context).colorScheme.primary;

            return ContentDialog(
              title: t.selectC(c: category.title),
              displayButton: false,
              content: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 480,
                  maxHeight: 520,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 标签区
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: category.tags.map((tag) {
                              final isSelected = currentSelected.contains(tag);
                              return InkWell(
                                onTap: () => setState(() {
                                  isSelected
                                      ? currentSelected.remove(tag)
                                      : currentSelected.add(tag);
                                }),
                                borderRadius: BorderRadius.circular(6),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 120),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? color.toOpacity(0.1)
                                        : Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest
                                              .toOpacity(0.5),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      width: 0.5,
                                      color: isSelected
                                          ? color.toOpacity(0.5)
                                          : Theme.of(context)
                                                .colorScheme
                                                .outline
                                                .toOpacity(0.25),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isSelected) ...[
                                        Icon(
                                          Icons.check,
                                          size: 12,
                                          color: color,
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                      Text(
                                        tag,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isSelected
                                              ? color
                                              : Theme.of(
                                                  context,
                                                ).colorScheme.onSurface,
                                          fontWeight: isSelected
                                              ? FontWeight.w500
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      // 操作栏
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: Row(
                          children: [
                            if (currentSelected.isNotEmpty)
                              TextButton.icon(
                                onPressed: () =>
                                    setState(() => currentSelected.clear()),
                                icon: const Icon(Icons.clear_all, size: 16),
                                label: Text(t.clear),
                                style: TextButton.styleFrom(
                                  foregroundColor: Theme.of(
                                    context,
                                  ).colorScheme.error,
                                ),
                              ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(t.cancel),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: () {
                                _updateSelectedTags(category, currentSelected);
                                Navigator.pop(context);
                              },
                              child: Text(
                                currentSelected.isEmpty
                                    ? t.confirm
                                    : t.confirmC(c: currentSelected.length),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _updateSelectedTags(
    TagCategory category,
    List<String> selectedTagsInCategory,
  ) async {
    setState(() {
      tags.removeWhere((tag) => category.tags.contains(tag));
      tags.addAll(selectedTagsInCategory);
    });
    setState(() {
      _isLoading = true;
      bangumiItems.clear();
    });
    final newItems = await bangumiSearch();
    bangumiItems = newItems;
    setState(() {
      _isLoading = false;
    });
  }

  void _showAddTagDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return ContentDialog(
          displayButton: false,
          title: '增加标签',
          content: TextField(
            autofocus: true,
            decoration: InputDecoration(
              // filled: true,
              fillColor: Theme.of(context).cardColor,
              hintText: t.enterKeywords,
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onSubmitted: (value) async {
              setState(() {
                tags.add(value);
                _isLoading = true;
                bangumiItems.clear();
              });
              context.pop();
              final newItems = await bangumiSearch();
              bangumiItems = newItems;
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
            },
          ),
        );
      },
    );
  }

  void _checkExitSelectMode() {
    if (selectedBangumiItems.isEmpty && selectedCharacterItems.isEmpty) {
      setState(() {
        multiSelectMode = false;
      });
    }
  }

  // 内容列表（根据选中标签过滤）
  Widget _buildContentListSliver() {
    void toggleSelect<T>(T item, Map<T, bool> selectedMap, List<T> list) {
      if (selectedMap.containsKey(item)) {
        selectedMap.remove(item);
        _checkExitSelectMode();
      } else {
        selectedMap[item] = true;
      }
      lastSelectedIndex = list.indexOf(item);
    }

    void rangeSelect<T>(T item, Map<T, bool> selectedMap, List<T> list) {
      if (lastSelectedIndex == null) return;
      int start = lastSelectedIndex!;
      int end = list.indexOf(item);
      if (start > end) {
        final temp = start;
        start = end;
        end = temp;
      }
      for (int i = start; i <= end; i++) {
        if (i == lastSelectedIndex) continue;
        final e = list[i];
        if (selectedMap.containsKey(e)) {
          selectedMap.remove(e);
        } else {
          selectedMap[e] = true;
        }
      }
      lastSelectedIndex = list.indexOf(item);
    }

    void onTap(Object a) {
      if (!multiSelectMode) return;
      setState(() {
        if (subjectSearch) {
          toggleSelect(a as BangumiItem, selectedBangumiItems, bangumiItems);
        } else {
          toggleSelect(
            a as CharacterActor,
            selectedCharacterItems,
            characterItmes,
          );
        }
      });
    }

    void onLongPressed(Object a) {
      setState(() {
        if (!multiSelectMode) {
          multiSelectMode = true;
          if (subjectSearch) {
            toggleSelect(a as BangumiItem, selectedBangumiItems, bangumiItems);
          } else {
            toggleSelect(
              a as CharacterActor,
              selectedCharacterItems,
              characterItmes,
            );
          }
        } else {
          if (subjectSearch) {
            rangeSelect(a as BangumiItem, selectedBangumiItems, bangumiItems);
          } else {
            rangeSelect(
              a as CharacterActor,
              selectedCharacterItems,
              characterItmes,
            );
          }
          _checkExitSelectMode();
        }
      });
    }

    return SliverGrid(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (subjectSearch) {
            final item = bangumiItems[index];
            final isSelected = selectedBangumiItems[item] ?? false;
            final bangumi = useBriefMode
                ? BangumiBriefCard(
                    bangumiItem: item,
                    heroTag: 'search',
                    onTap: multiSelectMode ? (a) => onTap(a) : null,
                    onLongPressed: (a) => onLongPressed(a),
                  )
                : BangumiDetailedCard(
                    bangumiItem: item,
                    heroTag: 'search',
                    onTap: multiSelectMode ? (a) => onTap(a) : null,
                    onLongPressed: (a) => onLongPressed(a),
                  );

            if (selectedBangumiItems.isEmpty) return bangumi;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(
                        context,
                      ).colorScheme.secondaryContainer.toOpacity(0.72)
                    : null,
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(4),
              child: bangumi,
            );
          } else {
            final item = characterItmes[index];
            final isSelected = selectedCharacterItems[item] ?? false;
            final character = BangumiCharacterCard(
              character: item,
              heroTag: 'search',
              isCharacter: defaultCategory != 'person',
              onTap: multiSelectMode ? (a) => onTap(a) : null,
              onLongPressed: (a) => onLongPressed(a),
            );

            if (selectedCharacterItems.isEmpty) return character;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(
                        context,
                      ).colorScheme.secondaryContainer.toOpacity(0.72)
                    : null,
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(4),
              child: character,
            );
          }
        },
        childCount: subjectSearch ? bangumiItems.length : characterItmes.length,
      ),
      gridDelegate: SliverGridDelegateWithBangumiItems(
        subjectSearch ? useBriefMode : true,
      ),
    );
  }

  // 时间选择对话框
  void _showAirEndDateDialog(BuildContext context) {
    DateTime now = DateTime.now();
    DateTime? air = Utils.safeParseDate(airDate);
    DateTime? end = Utils.safeParseDate(endDate);
    int quickYear = now.year;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStates) {
            String formatDate(DateTime? date) {
              if (date == null) return t.unselected;
              return "${date.year.toString().padLeft(4, '0')}-"
                  "${date.month.toString().padLeft(2, '0')}-"
                  "${date.day.toString().padLeft(2, '0')}";
            }

            // 自定义日期选择器（年月日）
            Future<DateTime?> pickDate(DateTime? initial) async {
              DateTime temp = initial ?? now;
              int selYear = temp.year;
              int selMonth = temp.month;
              int selDay = temp.day;
              int step = 0;

              return await showDialog<DateTime>(
                context: context,
                builder: (ctx) => StatefulBuilder(
                  builder: (ctx, setInner) {
                    int daysInMonth = DateUtils.getDaysInMonth(
                      selYear,
                      selMonth,
                    );
                    if (selDay > daysInMonth) selDay = daysInMonth;

                    Widget yearMonthPicker() => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: () => setInner(() => selYear--),
                            ),
                            GestureDetector(
                              onTap: () async {
                                final ctrl = TextEditingController(
                                  text: selYear.toString(),
                                );
                                final result = await showDialog<int>(
                                  context: ctx,
                                  builder: (_) => ContentDialog(
                                    title: t.enterYear,
                                    content: TextField(
                                      controller: ctrl,
                                      keyboardType: TextInputType.number,
                                      autofocus: true,
                                    ),
                                    actions: [
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(
                                          ctx,
                                          int.tryParse(ctrl.text),
                                        ),
                                        child: Text(t.ok),
                                      ),
                                    ],
                                  ),
                                );
                                if (result != null) {
                                  setInner(() => selYear = result);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$selYear',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: () => setInner(() => selYear++),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // 月份网格
                        GridView.count(
                          crossAxisCount: 4,
                          shrinkWrap: true,
                          mainAxisSpacing: 6,
                          crossAxisSpacing: 6,
                          childAspectRatio: 2.0,
                          children: List.generate(12, (i) {
                            final month = i + 1;
                            final isSelected = selMonth == month;
                            return InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => setInner(() {
                                selMonth = month;
                                step = 1;
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '$month月',
                                  style: TextStyle(
                                    color: isSelected
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.onPrimary
                                        : null,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    );

                    Widget dayPicker() => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => setInner(() => step = 0),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.arrow_back_ios, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  '$selYear年 $selMonth月',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // 星期标题
                        Row(
                          children: ['日', '一', '二', '三', '四', '五', '六']
                              .map(
                                (d) => Expanded(
                                  child: Center(
                                    child: Text(
                                      d,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.outline,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 4),
                        // 日历网格
                        Builder(
                          builder: (_) {
                            final firstDay =
                                DateTime(selYear, selMonth, 1).weekday % 7;
                            final totalCells = firstDay + daysInMonth;
                            final rows = (totalCells / 7).ceil();
                            return GridView.count(
                              crossAxisCount: 7,
                              shrinkWrap: true,
                              mainAxisSpacing: 4,
                              crossAxisSpacing: 2,
                              childAspectRatio: 1.2,
                              children: List.generate(rows * 7, (i) {
                                final day = i - firstDay + 1;
                                if (day < 1 || day > daysInMonth) {
                                  return const SizedBox.shrink();
                                }
                                final isSelected = selDay == day;
                                return InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () => setInner(() => selDay = day),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                          : null,
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '$day',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isSelected
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.onPrimary
                                            : null,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            );
                          },
                        ),
                      ],
                    );

                    return ContentDialog(
                      title: step == 0
                          ? t.selectYearAndMonth
                          : t.selectDay,
                      content: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: step == 0
                            ? KeyedSubtree(
                                key: const ValueKey(0),
                                child: yearMonthPicker(),
                              )
                            : KeyedSubtree(
                                key: const ValueKey(1),
                                child: dayPicker(),
                              ),
                      ),
                      actions: [
                        ElevatedButton(
                          onPressed: () => Navigator.pop(
                            ctx,
                            DateTime(selYear, selMonth, selDay),
                          ),
                          child: Text(t.confirm),
                        ),
                      ],
                    );
                  },
                ),
              );
            }

            // 快捷选择：设置区间
            void applyQuick(DateTime start, DateTime end_) {
              setStates(() {
                air = start;
                end = end_;
              });
            }

            // 季度信息
            final quarters = [
              {
                'label': t.fullYear,
                'start': 1,
                'startDay': 1,
                'end': 12,
                'endDay': 31,
              },
              {
                'label': 'Q1',
                'start': 1,
                'startDay': 1,
                'end': 3,
                'endDay': 31,
              },
              {
                'label': 'Q2',
                'start': 4,
                'startDay': 1,
                'end': 6,
                'endDay': 30,
              },
              {
                'label': 'Q3',
                'start': 7,
                'startDay': 1,
                'end': 9,
                'endDay': 30,
              },
              {
                'label': 'Q4',
                'start': 10,
                'startDay': 1,
                'end': 12,
                'endDay': 31,
              },
            ];

            return ContentDialog(
              title: t.selectDateRange,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 快捷选择 ──
                  Text(
                    t.quickSelect,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  // 年份导航
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard_double_arrow_left),
                        onPressed: () => setStates(() => quickYear -= 10),
                        tooltip: '-10',
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => setStates(() => quickYear--),
                      ),
                      GestureDetector(
                        onTap: () async {
                          final ctrl = TextEditingController(
                            text: quickYear.toString(),
                          );
                          final result = await showDialog<int>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: Text(t.enterYear),
                              content: TextField(
                                controller: ctrl,
                                keyboardType: TextInputType.number,
                                autofocus: true,
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(t.cancel),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(
                                    context,
                                    int.tryParse(ctrl.text),
                                  ),
                                  child: Text(t.ok),
                                ),
                              ],
                            ),
                          );
                          if (result != null) {
                            setStates(() => quickYear = result);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$quickYear',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () => setStates(() => quickYear++),
                      ),
                      IconButton(
                        icon: const Icon(Icons.keyboard_double_arrow_right),
                        onPressed: () => setStates(() => quickYear += 10),
                        tooltip: '+10',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 快捷按钮行
                  Row(
                    children: quarters.map((q) {
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              minimumSize: const Size(0, 34),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                            onPressed: () => applyQuick(
                              DateTime(
                                quickYear,
                                q['start'] as int,
                                q['startDay'] as int,
                              ),
                              DateTime(
                                quickYear,
                                q['end'] as int,
                                q['endDay'] as int,
                              ),
                            ),
                            child: Text(q['label'] as String),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const Divider(height: 24),
                  // ── 手动选择 ──
                  Text(
                    t.manualSelect,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.play_arrow_outlined),
                    title: Text(t.startDate),
                    subtitle: Text(
                      formatDate(air),
                      style: TextStyle(
                        color: air != null
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                    trailing: air != null
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setStates(() => air = null),
                          )
                        : const Icon(Icons.date_range),
                    onTap: () async {
                      final picked = await pickDate(air);
                      if (picked != null) setStates(() => air = picked);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.stop_outlined),
                    title: Text(t.endDate),
                    subtitle: Text(
                      formatDate(end),
                      style: TextStyle(
                        color: end != null
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                    trailing: end != null
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setStates(() => end = null),
                          )
                        : const Icon(Icons.date_range),
                    onTap: () async {
                      final picked = await pickDate(end);
                      if (picked != null) setStates(() => end = picked);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => setStates(() {
                    air = null;
                    end = null;
                  }),
                  child: Text(t.clear),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (air == null && end == null) {
                      App.rootContext.showMessage(
                        message: t.pleaseSelectADate,
                      );
                      return;
                    }
                    if (air != null && end != null && end!.isBefore(air!)) {
                      context.showMessage(
                        message:
                            t.endDateCannotBeEarlierThanStartDate,
                      );
                      return;
                    }
                    airDate = air != null ? formatDate(air) : '';
                    endDate = end != null ? formatDate(end) : '';
                    Navigator.pop(context);
                    setState(() {
                      _isLoading = true;
                      bangumiItems.clear();
                    });
                    final newItems = await bangumiSearch();
                    bangumiItems = newItems;
                    setState(() => _isLoading = false);
                  },
                  child: Text(t.apply),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _toolBoxWidget(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      width: MediaQuery.of(context).size.width - 30,
      color: Colors.transparent,
      child: Row(
        children: [
          if (bangumiItems.isNotEmpty || characterItmes.isNotEmpty) ...[
            Text(
              t.showingLResults(
                l: subjectSearch
                    ? bangumiItems.length
                    : characterItmes.length,
              ),
            ),
            const SizedBox(width: 8),
          ],
          IconButton(
            onPressed: () {
              bangumiItems.clear();
              characterItmes.clear();
              tags.clear();
              airDate = '';
              endDate = '';
              setState(() {});
            },
            tooltip: t.clearTags,
            icon: const Icon(Icons.clear_all),
          ),
          if (subjectSearch)
            IconButton(
              onPressed: () {
                _showAddTagDialog(context);
              },
              icon: const Icon(Icons.add),
            ),
          const Spacer(),
          if (subjectSearch)
            IconButton(
              onPressed: () {
                _showAirEndDateDialog(context);
              },
              tooltip: t.selectTime,
              icon: Icon(Icons.calendar_today),
            ),
          if (subjectSearch)
            IconButton(
              onPressed: () {
                useBriefMode = !useBriefMode;
                setState(() {});
              },
              tooltip: t.switchLayout,
              icon: useBriefMode ? Icon(Icons.apps) : Icon(Icons.view_agenda),
            ),
          if (subjectSearch)
            PopupMenuButton<String>(
              icon: Row(
                children: [
                  const Icon(Icons.sort, size: 20),
                  const SizedBox(width: 4),
                  Text(selectedOption),
                ],
              ),
              onSelected: (String selected) async {
                setState(() {
                  selectedOption = selected;
                });
                final sortType = optionToSortType[selected]!;
                sort = sortType;
                bangumiItems.clear();
                setState(() {
                  _isLoading = true;
                });
                bangumiItems = await bangumiSearch();
                setState(() {
                  _isLoading = false;
                });
              },
              itemBuilder: (BuildContext context) {
                return options.map((String option) {
                  return PopupMenuItem<String>(
                    value: option,
                    child: Text(option),
                  );
                }).toList();
              },
            ),
        ],
      ),
    );
  }

  Widget _multiSelectBoxWidget(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      width: MediaQuery.of(context).size.width - 30,
      color: Colors.transparent,
      child: Row(
        children: [
          if (bangumiItems.isNotEmpty)
            Text(
              t.selectedAAnimes(a: selectedBangumiItems.length),
            ),
          if (characterItmes.isNotEmpty)
            Text(
              t.selectedACharacter(
                a: selectedCharacterItems.length,
              ),
            ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {
              selectedBangumiItems.clear();
              selectedCharacterItems.clear();
              multiSelectMode = false;
              setState(() {});
            },
            tooltip: t.clearTags,
            icon: const Icon(Icons.clear_all),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              setState(() {
                if (subjectSearch) {
                  selectedBangumiItems = bangumiItems.asMap().map(
                    (k, v) => MapEntry(v, true),
                  );
                } else {
                  selectedCharacterItems = characterItmes.asMap().map(
                    (k, v) => MapEntry(v, true),
                  );
                }
              });
            },
            tooltip: t.selectAll,
            icon: Icon(Icons.select_all),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                selectedBangumiItems.clear();
                selectedCharacterItems.clear();
                multiSelectMode = false;
              });
            },
            tooltip: t.deselect,
            icon: Icon(Icons.deselect),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                if (subjectSearch) {
                  for (var b in bangumiItems) {
                    if (selectedBangumiItems.containsKey(b)) {
                      selectedBangumiItems.remove(b);
                    } else {
                      selectedBangumiItems[b] = true;
                    }
                  }
                  _checkExitSelectMode();
                } else {
                  for (var b in characterItmes) {
                    if (selectedCharacterItems.containsKey(b)) {
                      selectedCharacterItems.remove(b);
                    } else {
                      selectedCharacterItems[b] = true;
                    }
                  }
                  _checkExitSelectMode();
                }
              });
            },
            tooltip: t.invertSelection,
            icon: Icon(Icons.flip),
          ),
          if (subjectSearch)
            IconButton(
              onPressed: () {
                useBriefMode = !useBriefMode;
                setState(() {});
              },
              tooltip: t.switchLayout,
              icon: useBriefMode ? Icon(Icons.apps) : Icon(Icons.view_agenda),
            ),
        ],
      ),
    );
  }

  Future<void> _performSearch(String value) async {
    value = value.trim();
    if (subjectSearch) {
      if (value.isEmpty) {
        return;
      }
    }

    if (RegExp(r'^\d+$').hasMatch(value)) {
      final res = await Bangumi.instance.isBangumiExists(int.parse(value));
      if (res.keys.first) {
        App.rootContext.showMessage(message: t.jumping);
        context.to(() => BangumiInfoPage(bangumiItem: res.values.first!));
      } else {
        App.rootContext.showMessage(message: t.queryFailed);
      }
    } else {
      FocusScope.of(context).unfocus();
      _controller.text = value;
      keyword = value;
      if (value.isNotEmpty) {
        SearchHistoryManager().addSearch(keyword);
      }

      setState(() {
        _isLoading = true;
        _showSearchHistory = false;
        _showSearchSuggestions = false;
        subjectSearchSuggestions.clear();
        characterSearchSuggestions.clear();
      });

      if (subjectSearch) {
        final newItems = await bangumiSearch();
        bangumiItems = newItems;
      } else if (defaultCategory == 'character') {
        final newItems = await bangumiCharacterSearch(keyword);
        characterItmes = newItems;
      } else if (defaultCategory == 'person') {
        final newItems = await bangumiPersonSearch(keyword);
        characterItmes = newItems;
      }

      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _searchHistorySliver() {
    final history = ref
        .watch(searchHistoryProvider)
        .when(
          data: (data) => data,
          loading: () => <SearchHistoryItem>[],
          error: (_, _) => <SearchHistoryItem>[],
        );

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final item = history[index];
        return ListTile(
          leading: const Icon(Icons.history),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.keyword,
                style: ts.s14.copyWith(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.repeat,
                    size: 14,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${item.useCount} 次',
                    style: ts.s12.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.schedule,
                    size: 14,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    Utils.formatTime(item.lastUsedAt),
                    style: ts.s12.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          onTap: () => _performSearch(item.keyword),
          trailing: IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () =>
                ref.read(searchHistoryProvider.notifier).delete(item.keyword),
          ),
        );
      }, childCount: history.length),
    );
  }

  Widget _searchSuggestionsSliver() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final String name;

          if (subjectSearch) {
            final item = subjectSearchSuggestions[index];
            name = item.nameCn.isNotEmpty ? item.nameCn : item.name;
          } else {
            final item = characterSearchSuggestions[index];
            name = item.nameCN.isNotEmpty ? item.nameCN : item.name;
          }

          return ListTile(
            leading: const Icon(Icons.search),
            title: Text(name),
            onTap: () => _performSearch(name),
          );
        },
        childCount: subjectSearch
            ? subjectSearchSuggestions.length
            : characterSearchSuggestions.length,
      ),
    );
  }

  Widget _sliverAppBar(BuildContext context) {
    return SliverAppbar(
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () {
              if (_showSearchHistory) {
                setState(() {
                  FocusScope.of(context).unfocus();
                  keyword = '';
                  _controller.clear();
                  _showSearchHistory = false;
                  _showSearchSuggestions = false;
                  subjectSearchSuggestions.clear();
                  characterSearchSuggestions.clear();
                });
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          MenuAnchor(
            builder: (context, controller, child) {
              return TextButton.icon(
                label: Text(searchCategory[defaultCategory] ?? ''),
                onPressed: () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                },
              );
            },
            menuChildren: [
              MenuItemButton(
                onPressed: () {
                  defaultCategory = 'subject';
                  subjectSearch = true;
                  multiSelectMode = false;
                  selectedCharacterItems.clear();
                  selectedBangumiItems.clear();
                  characterItmes.clear();
                  setState(() {});
                },
                child: Text(t.subject),
              ),
              MenuItemButton(
                onPressed: () {
                  defaultCategory = 'character';
                  subjectSearch = false;
                  multiSelectMode = false;
                  selectedCharacterItems.clear();
                  selectedBangumiItems.clear();
                  characterItmes.clear();
                  bangumiItems.clear();
                  setState(() {});
                },
                child: Text(t.character),
              ),
              MenuItemButton(
                onPressed: () {
                  defaultCategory = 'person';
                  subjectSearch = false;
                  multiSelectMode = false;
                  selectedCharacterItems.clear();
                  selectedBangumiItems.clear();
                  characterItmes.clear();
                  bangumiItems.clear();
                  setState(() {});
                },
                child: Text(t.person),
              ),
            ],
          ),
        ],
      ),
      actions: [
        if (_showSearchHistory)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              setState(() {
                FocusScope.of(context).unfocus();
                keyword = '';
                _controller.clear();
                _showSearchHistory = false;
                _showSearchSuggestions = false;
                subjectSearchSuggestions.clear();
                characterSearchSuggestions.cast();
              });
            },
          ),
        if (multiSelectMode)
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              showPopUpWidget(
                App.rootContext,
                StatefulBuilder(
                  builder: (context, setState) {
                    Widget widget = subjectSearch
                        ? ShareWidget(
                            selectedBangumiItems: selectedBangumiItems,
                            tag: tags,
                            sort: sortTypeToOption[sort],
                            airDate: airDate,
                            endDate: endDate,
                          )
                        : ShareWidget(
                            selectedCharacterItems: selectedCharacterItems,
                          );

                    return widget;
                  },
                ),
              );
            },
          ),
      ],
      title: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: ClipRect(
          child: SizedBox(
            height: 52,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: TextField(
                controller: _controller,
                autofocus: false,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.transparent,
                  hintText: keyword.isNotEmpty
                      ? keyword
                      : t.enterKeywords,
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onTap: () {
                  setState(() {
                    _showSearchHistory = true;
                  });
                },
                onChanged: (value) {
                  setState(() {
                    keyword = value;
                    _showSearchSuggestions = true;
                  });

                  // 取消之前的防抖定时器
                  _debounce?.cancel();

                  _debounce = Timer(const Duration(seconds: 2), () async {
                    if (value.trim().isEmpty) {
                      setState(() {
                        subjectSearchSuggestions = [];
                        characterSearchSuggestions = [];
                      });
                      return;
                    }
                    final int token = ++_searchToken;

                    List<Object> results = [];

                    if (subjectSearch) {
                      results = await Bangumi.instance.bangumiPostSearch(
                        value,
                        tags: tags,
                        sort: 'match',
                        airDate: airDate,
                        endDate: endDate,
                      );
                    } else if (defaultCategory == 'character') {
                      results = await Bangumi.instance
                          .postCharactersSearchByStringNext(keyword: value);
                    } else if (defaultCategory == 'person') {
                      results = await Bangumi.instance
                          .postPersonsSearchByStringNext(keyword: keyword);
                    }

                    // 只处理最新的一次搜索结果
                    if (token == _searchToken) {
                      setState(() {
                        if (subjectSearch) {
                          subjectSearchSuggestions =
                              results as List<BangumiItem>;
                        } else {
                          characterSearchSuggestions =
                              results as List<CharacterActor>;
                        }
                      });
                    }
                  });
                },
                onSubmitted: (value) async {
                  await _performSearch(value);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tagsWidget(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();

    final color = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: tags.map((tag) {
          return InkWell(
            onTap: () async {
              setState(() {
                tags.remove(tag);
                _isLoading = true;
                bangumiItems.clear();
                selectedBangumiItems.clear();
                multiSelectMode = false;
              });
              final newItems = await bangumiSearch();
              bangumiItems = newItems;
              setState(() => _isLoading = false);
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: color.toOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(width: 0.5, color: color.toOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tag,
                    style: TextStyle(
                      fontSize: 13,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Icon(Icons.close, size: 13, color: color.toOpacity(0.7)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _dataTagsWidget(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget buildTag({
      required String label,
      required IconData icon,
      required Color color,
      required VoidCallback onRemove,
    }) {
      return InkWell(
        onTap: onRemove,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: color.toOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(width: 0.5, color: color.toOpacity(0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 5),
              Icon(Icons.close, size: 13, color: color.toOpacity(0.7)),
            ],
          ),
        ),
      );
    }

    final tags = [
      if (airDate.isNotEmpty)
        buildTag(
          label: airDate,
          icon: Icons.calendar_today,
          color: colorScheme.primary,
          onRemove: () async {
            setState(() {
              airDate = '';
              _isLoading = true;
              bangumiItems.clear();
              selectedBangumiItems.clear();
              multiSelectMode = false;
            });
            final newItems = await bangumiSearch();
            bangumiItems = newItems;
            setState(() => _isLoading = false);
          },
        ),
      if (endDate.isNotEmpty)
        buildTag(
          label: endDate,
          icon: Icons.calendar_today,
          color: colorScheme.secondary,
          onRemove: () async {
            setState(() {
              endDate = '';
              _isLoading = true;
              bangumiItems.clear();
              selectedBangumiItems.clear();
              multiSelectMode = false;
            });
            final newItems = await bangumiSearch();
            bangumiItems = newItems;
            setState(() => _isLoading = false);
          },
        ),
    ];

    if (tags.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Wrap(spacing: 6, runSpacing: 6, children: tags),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget widget = Scaffold(
      floatingActionButton: _showFab
          ? FloatingActionButton(
              onPressed: () {
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              },
              child: const Icon(Icons.arrow_upward),
            )
          : null,
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              _sliverAppBar(context),
              if (_showSearchSuggestions &&
                  (subjectSearchSuggestions.isNotEmpty ||
                      characterSearchSuggestions.isNotEmpty))
                _searchSuggestionsSliver(),
              if (_showSearchHistory &&
                  (subjectSearchSuggestions.isEmpty ||
                      characterSearchSuggestions.isEmpty))
                _searchHistorySliver(),
              if (!_showSearchHistory && !_showSearchSuggestions) ...[
                if (subjectSearch) ..._buildTagCategories(),
                if (tags.isNotEmpty && subjectSearch && subjectSearch)
                  SliverToBoxAdapter(child: _tagsWidget(context)),
                if ((airDate.isNotEmpty || endDate.isNotEmpty) && subjectSearch)
                  _dataTagsWidget(context),
                if (!multiSelectMode)
                  SliverToBoxAdapter(child: _toolBoxWidget(context)),
                if (multiSelectMode)
                  SliverToBoxAdapter(child: _multiSelectBoxWidget(context)),
                _buildContentListSliver(),
              ],
              if (_isLoading)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(child: PolygonRefreshIndicator(size: 40)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    widget = AppScrollBar(
      topPadding: 82,
      controller: _scrollController,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: widget,
      ),
    );

    return PopScope(
      canPop: !multiSelectMode && !_showSearchHistory,
      onPopInvokedWithResult: (didPop, result) {
        if (multiSelectMode) {
          setState(() {
            multiSelectMode = false;
            selectedBangumiItems.clear();
          });
        } else if (_showSearchHistory) {
          setState(() {
            _showSearchHistory = false;
          });
        }
      },
      child: widget,
    );
  }
}

class TagCategory {
  final String title;
  final List<String> tags;

  TagCategory({required this.title, required this.tags});
}

class SliverGridDelegateWithBangumiItems extends SliverGridDelegate {
  SliverGridDelegateWithBangumiItems(
    this.useBriefMode, {
    this.fixedCrossAxisCount,
  });

  final bool useBriefMode;
  final int? fixedCrossAxisCount;
  final double scale = 1.toDouble();

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    if (useBriefMode) {
      return getBriefModeLayout(constraints, scale);
    } else {
      return getDetailedModeLayout(constraints, scale);
    }
  }

  SliverGridLayout getDetailedModeLayout(
    SliverConstraints constraints,
    double scale,
  ) {
    const minCrossAxisExtent = 360;
    final itemHeight = 192 * scale;

    int crossAxisCount;
    if (fixedCrossAxisCount != null) {
      crossAxisCount = fixedCrossAxisCount!;
    } else {
      crossAxisCount = (constraints.crossAxisExtent / minCrossAxisExtent)
          .floor();
      crossAxisCount = math.min(3, math.max(1, crossAxisCount));
    }

    return SliverGridRegularTileLayout(
      crossAxisCount: crossAxisCount,
      mainAxisStride: itemHeight,
      crossAxisStride: constraints.crossAxisExtent / crossAxisCount,
      childMainAxisExtent: itemHeight,
      childCrossAxisExtent: constraints.crossAxisExtent / crossAxisCount,
      reverseCrossAxis: false,
    );
  }

  SliverGridLayout getBriefModeLayout(
    SliverConstraints constraints,
    double scale,
  ) {
    final maxCrossAxisExtent = 192.0 * scale;
    const childAspectRatio = 0.68;
    const crossAxisSpacing = 0.0;

    int crossAxisCount;
    if (fixedCrossAxisCount != null) {
      crossAxisCount = fixedCrossAxisCount!;
    } else {
      crossAxisCount =
          (constraints.crossAxisExtent /
                  (maxCrossAxisExtent + crossAxisSpacing))
              .ceil();
      crossAxisCount = math.max(1, crossAxisCount);
    }

    final double usableCrossAxisExtent = math.max(
      0.0,
      constraints.crossAxisExtent - crossAxisSpacing * (crossAxisCount - 1),
    );
    final double childCrossAxisExtent = usableCrossAxisExtent / crossAxisCount;
    final double childMainAxisExtent = childCrossAxisExtent / childAspectRatio;

    return SliverGridRegularTileLayout(
      crossAxisCount: crossAxisCount,
      mainAxisStride: childMainAxisExtent,
      crossAxisStride: childCrossAxisExtent + crossAxisSpacing,
      childMainAxisExtent: childMainAxisExtent,
      childCrossAxisExtent: childCrossAxisExtent,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(covariant SliverGridDelegate oldDelegate) {
    if (oldDelegate is! SliverGridDelegateWithBangumiItems) return true;
    if (oldDelegate.scale != scale ||
        oldDelegate.useBriefMode != useBriefMode ||
        oldDelegate.fixedCrossAxisCount != fixedCrossAxisCount) {
      // 新增：检查固定列数变化
      return true;
    }
    return false;
  }
}
