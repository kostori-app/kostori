import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:kostori/components/bangumi_widget.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/components/misc_components.dart';
import 'package:kostori/components/share_widget.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/network/bangumi.dart';
import 'package:kostori/pages/bangumi/bangumi_info_page.dart';
import 'package:kostori/utils/translations.dart';
import 'package:kostori/utils/utils.dart';

class BangumiSearchPage extends StatefulWidget {
  const BangumiSearchPage({super.key, this.tag});

  final String? tag;

  @override
  State<BangumiSearchPage> createState() => _BangumiSearchPageState();
}

class _BangumiSearchPageState extends State<BangumiSearchPage> {
  final ScrollController _scrollController = ScrollController();
  final maxWidth = 1250.0;
  List<String> tags = [];
  List<BangumiItem> bangumiItems = [];
  List<BangumiItem> searchSuggestions = [];
  Map<BangumiItem, bool> selectedBangumiItems = {};

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

  final TextEditingController _controller = TextEditingController();
  bool _showSearchHistory = false;
  bool _showSearchSuggestions = false;

  final List<String> options = [
    'Best Match'.tl,
    'Top Rank'.tl,
    'Most Favorited'.tl,
    'Highest Rating'.tl,
  ];

  String selectedOption = 'Top Rank'.tl; // 当前选中的选项
  final Map<String, String> optionToSortType = {
    'Best Match'.tl: 'match',
    'Top Rank'.tl: 'rank',
    'Most Favorited'.tl: 'heat',
    'Highest Rating'.tl: 'score',
  };

  final Map<String, String> sortTypeToOption = {
    'match': 'Best Match'.tl,
    'rank': 'Top Rank'.tl,
    'heat': 'Most Favorited'.tl,
    'score': 'Highest Rating'.tl,
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
    return Bangumi.bangumiPostSearch(
      keyword,
      tags: tags,
      sort: sort,
      airDate: airDate,
      endDate: endDate,
    );
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
    // 当滚动位置超过 200 像素时显示 FAB
    final bool showFab = _scrollController.offset > 200;
    if (showFab != _showFab) {
      setState(() {
        _showFab = showFab;
      });
    }
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        bangumiItems.length >= 20 &&
        !multiSelectMode) {
      setState(() {
        _isLoading = true;
      });
      final result = await Bangumi.bangumiPostSearch(
        keyword,
        tags: tags,
        offset: bangumiItems.length,
        sort: sort,
        airDate: airDate,
        endDate: endDate,
      );
      bangumiItems.addAll(result);
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
    TagCategory(title: 'Type'.tl, tags: type),
    TagCategory(title: 'Background'.tl, tags: background),
    TagCategory(title: 'Characters'.tl, tags: role),
    TagCategory(title: 'Emotion'.tl, tags: emotional),
    TagCategory(title: 'Source'.tl, tags: source),
    TagCategory(title: 'Audience'.tl, tags: audience),
    TagCategory(title: 'Categories'.tl, tags: classification),
  ];

  // 分类选择栏
  List<Widget> _buildTagCategories() {
    return [
      SliverToBoxAdapter(
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final selectedCount = selectedCountForCategory(category);

              return Padding(
                padding: EdgeInsets.only(left: index == 0 ? 16 : 0, right: 16),
                child: ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(category.title),
                      if (selectedCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$selectedCount',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  selected: selectedCount > 0,
                  onSelected: (_) => _showTagSelectionDialog(context, category),
                  selectedColor: Theme.of(
                    context,
                  ).colorScheme.primary.toOpacity(0.1),
                  labelStyle: TextStyle(
                    color: selectedCount > 0
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: selectedCount > 0
                          ? Theme.of(
                              context,
                            ).colorScheme.primary.toOpacity(0.72)
                          : Colors.grey.shade300,
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
            return ContentDialog(
              title: 'Select @c'.tlParams({"c": category.title}),
              displayButton: false,
              content: Container(
                constraints: BoxConstraints(maxWidth: 500, maxHeight: 600),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 标签区
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: category.tags.map((tag) {
                            final isSelected = currentSelected.contains(tag);
                            return InputChip(
                              backgroundColor: Colors.black.toOpacity(0.5),
                              shape: StadiumBorder(
                                side: BorderSide(
                                  color: isSelected
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.primary.toOpacity(0.72)
                                      : Theme.of(
                                          context,
                                        ).colorScheme.primary.withAlpha(4),
                                ),
                              ),
                              label: Text(tag),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    if (!currentSelected.contains(tag)) {
                                      currentSelected.add(tag);
                                    }
                                  } else {
                                    currentSelected.remove(tag);
                                  }
                                });
                              },
                              selectedColor: Theme.of(
                                context,
                              ).colorScheme.primary.toOpacity(0.22),
                              checkmarkColor: isSelected
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primary.toOpacity(0.72)
                                  : Theme.of(
                                      context,
                                    ).colorScheme.primary.withAlpha(4),
                              showCheckmark: true,
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    // 操作栏
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          OutlinedButton(
                            onPressed: () =>
                                setState(() => currentSelected.clear()),
                            child: Text('Clear'.tl),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('Cancel'.tl),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: () {
                              _updateSelectedTags(category, currentSelected);
                              Navigator.pop(context);
                            },
                            child: Text(
                              'Confirm (@c)'.tlParams({
                                "c": currentSelected.length,
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
      // 先把这个分类原来选中的标签从tags中移除
      tags.removeWhere((tag) => category.tags.contains(tag));
      // 再把最新选中的标签加进去
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
        return Dialog(
          backgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ClipRect(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.toOpacity(0.22),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                    // filled: true,
                    fillColor: Theme.of(context).cardColor,
                    hintText: 'Enter keywords...'.tl,
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
              ),
            ),
          ),
        );
      },
    );
  }

  void _checkExitSelectMode() {
    if (selectedBangumiItems.isEmpty) {
      setState(() {
        multiSelectMode = false;
      });
    }
  }

  // 内容列表（根据选中标签过滤）
  Widget _buildContentListSliver() {
    void onTap(a) {
      setState(() {
        if (selectedBangumiItems.containsKey(a)) {
          selectedBangumiItems.remove(a);
          _checkExitSelectMode();
        } else {
          selectedBangumiItems[a] = true;
        }
        lastSelectedIndex = bangumiItems.indexOf(a);
      });
    }

    void onLongPressed(a) {
      setState(() {
        if (!multiSelectMode) {
          multiSelectMode = true;
          if (!selectedBangumiItems.containsKey(a)) {
            selectedBangumiItems[a] = true;
          }
          lastSelectedIndex = bangumiItems.indexOf(a);
        } else {
          if (lastSelectedIndex != null) {
            int start = lastSelectedIndex!;
            int end = bangumiItems.indexOf(a);
            if (start > end) {
              int temp = start;
              start = end;
              end = temp;
            }

            for (int i = start; i <= end; i++) {
              if (i == lastSelectedIndex) continue;

              var bangumiItem = bangumiItems[i];
              if (selectedBangumiItems.containsKey(bangumiItem)) {
                selectedBangumiItems.remove(bangumiItem);
              } else {
                selectedBangumiItems[bangumiItem] = true;
              }
            }
          }
          lastSelectedIndex = bangumiItems.indexOf(a);
        }
        _checkExitSelectMode();
      });
    }

    return SliverGrid(
      delegate: SliverChildBuilderDelegate((context, index) {
        var isSelected = selectedBangumiItems == {}
            ? false
            : selectedBangumiItems[bangumiItems[index]] ?? false;
        var bangumi = useBriefMode
            ? BangumiWidget.buildBriefMode(
                context,
                bangumiItems[index],
                'search',
                showPlaceholder: false,
                onTap: multiSelectMode
                    ? (a) {
                        onTap(a);
                      }
                    : null,
                onLongPressed: (a) {
                  onLongPressed(a);
                },
              )
            : BangumiWidget.buildDetailedMode(
                context,
                bangumiItems[index],
                'search',
                onTap: multiSelectMode
                    ? (a) {
                        onTap(a);
                      }
                    : null,
                onLongPressed: (a) {
                  onLongPressed(a);
                },
              );

        if (selectedBangumiItems.isEmpty) {
          return bangumi;
        }
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
      }, childCount: bangumiItems.length),
      gridDelegate: SliverGridDelegateWithBangumiItems(useBriefMode),
    );
  }

  void _showAirEndDateDialog(BuildContext context) {
    DateTime now = DateTime.now();
    DateTime? air = Utils.safeParseDate(airDate);
    DateTime? end = Utils.safeParseDate(endDate);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStates) {
            Future<void> pickDate(bool isAirDate) async {
              DateTime initial = isAirDate ? (air ?? now) : (end ?? now);
              DateTime? picked = await showDatePicker(
                context: context,
                initialDate: initial,
                firstDate: DateTime(now.year - 50),
                lastDate: DateTime(now.year + 30),
              );
              if (picked != null) {
                setStates(() {
                  if (isAirDate) {
                    air = picked;
                  } else {
                    end = picked;
                  }
                });
              }
            }

            String formatDate(DateTime? date) {
              if (date == null) return "Unselected".tl;
              return "${date.year.toString().padLeft(4, '0')}-"
                  "${date.month.toString().padLeft(2, '0')}-"
                  "${date.day.toString().padLeft(2, '0')}";
            }

            return AlertDialog(
              title: Text("Select Date".tl),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              content: SizedBox(
                width: 350,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: Text("Start Date".tl),
                      subtitle: Text(formatDate(air)),
                      trailing: Icon(Icons.date_range),
                      onTap: () => pickDate(true),
                    ),
                    ListTile(
                      title: Text("End Date".tl),
                      subtitle: Text(formatDate(end)),
                      trailing: Icon(Icons.date_range),
                      onTap: () => pickDate(false),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setStates(() {
                      air = null;
                      end = null;
                    });
                  },
                  child: Text("Clear Date".tl),
                ),
                // const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancel".tl),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (air == null && end == null) {
                      App.rootContext.showMessage(
                        message: 'Please select a date'.tl,
                      );
                      return;
                    }

                    if (air != null && end != null && end!.isBefore(air!)) {
                      context.showMessage(
                        message:
                            'End date cannot be earlier than start date'.tl,
                      );
                      return;
                    }

                    airDate = air != null ? formatDate(air) : '';
                    endDate = end != null ? formatDate(end) : '';

                    Log.addLog(
                      LogLevel.info,
                      'pickDate',
                      "Air Date: $airDate, End Date: $endDate",
                    );

                    Navigator.pop(context);
                    setState(() {
                      _isLoading = true;
                      bangumiItems.clear();
                    });

                    final newItems = await bangumiSearch();
                    bangumiItems = newItems;

                    setState(() {
                      _isLoading = false;
                    });
                  },
                  child: Text("Apply".tl),
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
          if (bangumiItems.isNotEmpty)
            Text('Showing @l results'.tlParams({'l': bangumiItems.length})),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {
              bangumiItems.clear();
              tags.clear();
              airDate = '';
              endDate = '';
              setState(() {});
            },
            tooltip: "Clear Tags".tl,
            icon: const Icon(Icons.clear_all),
          ),
          IconButton(
            onPressed: () {
              _showAddTagDialog(context);
            },
            icon: const Icon(Icons.add),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              _showAirEndDateDialog(context);
            },
            tooltip: "Select Time".tl,
            icon: Icon(Icons.calendar_today),
          ),
          IconButton(
            onPressed: () {
              useBriefMode = !useBriefMode;
              setState(() {});
            },
            tooltip: "Switch Layout".tl,
            icon: useBriefMode ? Icon(Icons.apps) : Icon(Icons.view_agenda),
          ),
          PopupMenuButton<String>(
            icon: Row(
              children: [
                const Icon(Icons.sort, size: 20), // 排序图标
                const SizedBox(width: 4),
                Text(selectedOption), // 当前选中的文本
              ],
            ),
            onSelected: (String selected) async {
              setState(() {
                selectedOption = selected; // 更新选中的选项
              });
              // 这里可以添加排序逻辑
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
              "Selected @c animes".tlParams({"c": selectedBangumiItems.length}),
            ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {
              selectedBangumiItems.clear();
              multiSelectMode = false;
              setState(() {});
            },
            tooltip: "Clear Tags".tl,
            icon: const Icon(Icons.clear_all),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              setState(() {
                selectedBangumiItems = bangumiItems.asMap().map(
                  (k, v) => MapEntry(v, true),
                );
              });
            },
            tooltip: "Select All".tl,
            icon: Icon(Icons.select_all),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                selectedBangumiItems.clear();
                multiSelectMode = false;
              });
            },
            tooltip: "Deselect".tl,
            icon: Icon(Icons.deselect),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                for (var b in bangumiItems) {
                  if (selectedBangumiItems.containsKey(b)) {
                    selectedBangumiItems.remove(b);
                  } else {
                    selectedBangumiItems[b] = true;
                  }
                }
              });
            },
            tooltip: "Invert Selection".tl,
            icon: Icon(Icons.flip),
          ),
          IconButton(
            onPressed: () {
              useBriefMode = !useBriefMode;
              setState(() {});
            },
            tooltip: "Switch Layout".tl,
            icon: useBriefMode ? Icon(Icons.apps) : Icon(Icons.view_agenda),
          ),
        ],
      ),
    );
  }

  Future<void> _performSearch(String value) async {
    value = value.trim();
    if (value.isEmpty) return;

    if (RegExp(r'^\d+$').hasMatch(value)) {
      final res = await Bangumi.isBangumiExists(int.parse(value));
      if (res.keys.first) {
        App.rootContext.showMessage(message: '正在跳转...');
        context.to(() => BangumiInfoPage(bangumiItem: res.values.first!));
      } else {
        App.rootContext.showMessage(message: '查询失败');
      }
    } else {
      FocusScope.of(context).unfocus();
      _controller.text = value;
      keyword = value;

      // 保存历史，去重
      appdata.addSearchHistory(value);
      appdata.saveData();

      setState(() {
        _isLoading = true;
        _showSearchHistory = false;
        _showSearchSuggestions = false;
        searchSuggestions.clear();
      });

      final newItems = await bangumiSearch();
      bangumiItems = newItems;

      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _searchHistorySliver() {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final item = appdata.searchHistory[index];
        return ListTile(
          leading: const Icon(Icons.history),
          title: Text(item),
          onTap: () => _performSearch(item),
          trailing: IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              appdata.removeSearchHistory(item);
              appdata.saveData();
              setState(() {});
            },
          ),
        );
      }, childCount: appdata.searchHistory.length),
    );
  }

  Widget _searchSuggestionsSliver() {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final item = searchSuggestions[index];
        return ListTile(
          leading: const Icon(Icons.search),
          title: Text(item.nameCn.isNotEmpty ? item.nameCn : item.name),
          onTap: () =>
              _performSearch(item.nameCn.isNotEmpty ? item.nameCn : item.name),
        );
      }, childCount: searchSuggestions.length),
    );
  }

  Widget _sliverAppBar(BuildContext context) {
    return SliverAppbar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new),
        onPressed: () {
          if (_showSearchHistory) {
            setState(() {
              FocusScope.of(context).unfocus();
              keyword = '';
              _controller.clear();
              _showSearchHistory = false;
              _showSearchSuggestions = false;
              searchSuggestions.clear();
            });
          } else {
            Navigator.of(context).pop();
          }
        },
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
                searchSuggestions.clear();
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
                    return ShareWidget(
                      selectedBangumiItems: selectedBangumiItems,
                      useBriefMode: useBriefMode,
                      tag: tags,
                      sort: sortTypeToOption[sort],
                      airDate: airDate,
                      endDate: endDate,
                    );
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
                      : 'Enter keywords...'.tl,
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
                        searchSuggestions = [];
                      });
                      return;
                    }
                    final int token = ++_searchToken; // 每次搜索加一个标记

                    final results = await Bangumi.bangumiPostSearch(
                      value,
                      tags: tags,
                      sort: 'match',
                      airDate: airDate,
                      endDate: endDate,
                    );

                    // 只处理最新的一次搜索结果
                    if (token == _searchToken) {
                      setState(() {
                        searchSuggestions = results;
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
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 6.0,
        children: tags.map((tag) {
          return ActionChip(
            label: Text(tag),
            onPressed: () async {
              setState(() {
                tags.remove(tag);
                _isLoading = true;
                bangumiItems.clear();
                selectedBangumiItems.clear();
                multiSelectMode = false;
              });
              final newItems = await bangumiSearch();
              bangumiItems = newItems;
              setState(() {
                _isLoading = false;
              });
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: Theme.of(context).colorScheme.primary.toOpacity(0.72),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _dataTagsWidget(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Wrap(
          spacing: 4.0,
          // runSpacing: 8.0,
          children: [
            if (airDate.isNotEmpty)
              ActionChip(
                avatar: Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Colors.green,
                ),
                label: Text(airDate),
                onPressed: () async {
                  setState(() {
                    airDate = '';
                    _isLoading = true;
                    bangumiItems.clear();
                    selectedBangumiItems.clear();
                    multiSelectMode = false;
                  });
                  final newItems = await bangumiSearch();
                  bangumiItems = newItems;
                  setState(() {
                    _isLoading = false;
                  });
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.green.toOpacity(0.6)),
                ),
                backgroundColor: Colors.green.toOpacity(0.1),
                labelStyle: TextStyle(color: Colors.green),
              ),
            if (endDate.isNotEmpty)
              ActionChip(
                avatar: Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Colors.blue,
                ),
                label: Text(endDate),
                onPressed: () async {
                  setState(() {
                    endDate = '';
                    _isLoading = true;
                    bangumiItems.clear();
                    selectedBangumiItems.clear();
                    multiSelectMode = false;
                  });

                  final newItems = await bangumiSearch();
                  bangumiItems = newItems;
                  setState(() {
                    _isLoading = false;
                  });
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.blue.toOpacity(0.6)),
                ),
                backgroundColor: Colors.blue.toOpacity(0.1),
                labelStyle: TextStyle(color: Colors.blue),
              ),
          ],
        ),
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
              if (_showSearchSuggestions && searchSuggestions.isNotEmpty)
                _searchSuggestionsSliver(),
              if (_showSearchHistory &&
                  appdata.searchHistory.isNotEmpty &&
                  searchSuggestions.isEmpty)
                _searchHistorySliver(),
              if (!_showSearchHistory && !_showSearchSuggestions) ...[
                ..._buildTagCategories(),
                if (tags.isNotEmpty)
                  SliverToBoxAdapter(child: _tagsWidget(context)),
                if (airDate.isNotEmpty || endDate.isNotEmpty)
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
                    child: Center(
                      child: MiscComponents.placeholder(
                        context,
                        40,
                        40,
                        Colors.transparent,
                      ),
                    ),
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
  SliverGridDelegateWithBangumiItems(this.useBriefMode);

  final bool useBriefMode;

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
    int crossAxisCount = (constraints.crossAxisExtent / minCrossAxisExtent)
        .floor();
    crossAxisCount = math.min(3, math.max(1, crossAxisCount)); // 限制1-3列
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
    int crossAxisCount =
        (constraints.crossAxisExtent / (maxCrossAxisExtent + crossAxisSpacing))
            .ceil();
    // Ensure a minimum count of 1, can be zero and result in an infinite extent
    // below when the window size is 0.
    crossAxisCount = math.max(1, crossAxisCount);
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
        oldDelegate.useBriefMode != useBriefMode) {
      return true;
    }
    return false;
  }
}
