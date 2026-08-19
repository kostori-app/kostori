import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gif/gif.dart';
import 'package:kostori/components/bangumi_widget.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/components/grid_speed_dial.dart';
import 'package:kostori/components/ui_components.dart';
import 'package:kostori/database/bangumi.dart';
import 'package:kostori/database/favorites.dart';
import 'package:kostori/database/history.dart';
import 'package:kostori/database/stats.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/anime_type.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/init.dart';
import 'package:kostori/network/bangumi.dart';
import 'package:kostori/pages/anime_details_page/anime_page.dart';
import 'package:kostori/pages/favorites/favorites_controller.dart';
import 'package:kostori/pages/settings/settings_page.dart';
import 'package:kostori/utils/ext.dart';
import 'package:kostori/utils/io.dart';

part 'bangumi_favorites_page.dart';

part 'favorite_actions.dart';

part 'favorite_bangumi_page.dart';

part 'favorite_dialog.dart';

part 'local_favorites_page.dart';

const _kLeftBarWidth = 256.0;
const _kTwoPanelChangeWidth = 720.0;

abstract interface class FolderList {
  void update();

  void updateFolders();
}

class FavoritesPage extends ConsumerStatefulWidget {
  const FavoritesPage({super.key});

  @override
  ConsumerState<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends ConsumerState<FavoritesPage> {
  String? folder;
  bool isNetwork = false;
  int pageId = 0;

  FolderList? folderList;

  FavoritesController get favoritesController =>
      ref.read(favoritesControllerProvider.notifier);

  FavoritesState get favState => ref.watch(favoritesControllerProvider);

  void setFolder(bool isNetwork, String? folder) {
    setState(() {
      this.isNetwork = isNetwork;
      this.folder = folder;
    });
    appdata.implicitData['favoriteFolder'] = {
      'name': folder,
      'isNetwork': isNetwork,
    };
    appdata.writeImplicitData();
  }

  void setName(String name) {
    setState(
      () => ref
          .read(favoritesControllerProvider.notifier)
          .setBangumiUserName(name),
    );
    folderList?.update();
    appdata.settings.update((s) => s.copyWith(bangumiUserName: name));
    appdata.saveData();
  }

  void setPage(int id) {
    setState(() => pageId = id);
    folderList?.update();
    appdata.settings['favoritePageId'] = id;
    appdata.saveData();
  }

  void update() => setState(() {});

  @override
  void initState() {
    super.initState();
    pageId = appdata.settings['favoritePageId'] ?? 0;

    // 初始化收藏数据。Riverpod 不允许在 widget 生命周期内直接修改
    // provider，故延迟到首帧构建完成后执行。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initLocalFolder();
    });
  }

  /// 初始化当前选中分组（folders 已在 FavoritesController.build() 初始化）。
  /// 从持久化恢复上次打开的分组；无历史或已失效时回退第一个分组。
  void _initLocalFolder() {
    try {
      final mgr = LocalFavoritesManager();
      final data = appdata.implicitData['favoriteFolder'];
      Log.info(
        'FavoritesPage',
        '_initLocalFolder data=$data favFolder=${favState.folder} favFolders=${favState.folders}',
      );
      if (data != null) {
        folder = data['name'] as String?;
        isNetwork = (data['isNetwork'] as bool?) ?? false;
      }

      // 本地分组且不存在时失效
      if (folder != null && !isNetwork && !mgr.existsFolder(folder!)) {
        folder = null;
      }
      // 网络收藏分组但当前不是网络模式时，回退本地
      if (folder != null && isNetwork && pageId != 2) {
        folder = null;
      }
      if (folder == null) {
        // 优先用 provider 的分组；为空时从 manager 实时读取（过滤空 default）
        final list = favState.folders.isNotEmpty
            ? favState.folders
            : mgr.folderNames.where((name) {
                if (name == 'default') {
                  return mgr
                      .getAllAnimes('default', FavoriteSortType.nameAsc)
                      .isNotEmpty;
                }
                return true;
              }).toList();
        if (list.isNotEmpty) {
          setFolder(false, list.first);
          // 同步 provider，确保本地收藏 Tab 内容与选中分组一致
          favoritesController.setFolder(list.first);
        }
      } else {
        // 恢复持久化分组。用 setFolder 触发 setState 刷新 UI（仅改字段不会重建），
        // 同时保持持久化不变、同步 provider 的 folder。
        setFolder(false, folder);
        favoritesController.setFolder(folder!);
      }
    } catch (e) {
      Log.error('_initLocalFolder', '$e');
      // 兜底：确保至少选中一个分组
      if (folder == null) {
        final list = favState.folders;
        if (list.isNotEmpty) {
          setFolder(false, list.first);
          favoritesController.setFolder(list.first);
        }
      }
    }
  }

  void showFolderSelector() {
    Navigator.of(App.rootContext).push(
      PageRouteBuilder(
        barrierDismissible: true,
        fullscreenDialog: true,
        opaque: false,
        barrierColor: Colors.black.toOpacity(0.36),
        pageBuilder: (context, animation, _) => Align(
          alignment: Alignment.centerLeft,
          child: Material(
            child: SizedBox(
              width: min(300, context.width - 16),
              child: _LeftBar(
                withAppbar: true,
                favPage: this,
                onSelected: context.pop,
                favoritesController: favoritesController,
              ),
            ),
          ),
        ),
        transitionsBuilder: (context, animation, _, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.fastOutSlowIn),
              ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconTheme(
      data: IconThemeData(color: context.colorScheme.secondary),
      child: Stack(
        children: [
          AnimatedPositioned(
            left: context.width <= _kTwoPanelChangeWidth ? -_kLeftBarWidth : 0,
            top: 0,
            bottom: 0,
            duration: const Duration(milliseconds: 200),
            child: _LeftBar(
              favoritesController: favoritesController,
            ).fixWidth(_kLeftBarWidth),
          ),
          Positioned(
            top: 0,
            left: context.width <= _kTwoPanelChangeWidth ? 0 : _kLeftBarWidth,
            right: 0,
            bottom: 0,
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    // 本地收藏需要选中一个分组；其他页面（Bangumi 收藏等）不依赖 folder
    if (pageId == 0 && folder == null) {
      return CustomScrollView(
        slivers: [
          SliverAppbar(
            leading: context.width <= _kTwoPanelChangeWidth
                ? Tooltip(
                    message: t.folders,
                    child: IconButton(
                      icon: const Icon(Icons.menu),
                      color: context.colorScheme.primary,
                      onPressed: showFolderSelector,
                    ),
                  )
                : null,
            title: GestureDetector(
              onTap: context.width < _kTwoPanelChangeWidth
                  ? showFolderSelector
                  : null,
              child: Text(t.unselected),
            ),
          ),
        ],
      );
    }

    return switch (pageId) {
      0 => _LocalFavoritesPage(favoritesController: favoritesController),
      1 => BangumiFavoritesPage(favoritesController: favoritesController),
      2 => FavoriteBangumiPage(),
      _ => const SizedBox.shrink(),
    };
  }
}

class _LeftBar extends ConsumerStatefulWidget {
  const _LeftBar({
    this.favPage,
    this.onSelected,
    this.withAppbar = false,
    required this.favoritesController,
  });

  final _FavoritesPageState? favPage;
  final VoidCallback? onSelected;
  final bool withAppbar;
  final FavoritesController favoritesController;

  @override
  ConsumerState<_LeftBar> createState() => _LeftBarState();
}

class _LeftBarState extends ConsumerState<_LeftBar> implements FolderList {
  late _FavoritesPageState favPage;

  FavoritesController get favoritesController => widget.favoritesController;

  LocalFavoritesManager get manager => LocalFavoritesManager();

  String get bangumiName =>
      ref.watch(favoritesControllerProvider).bangumiUserName;

  var folders = <String>[];
  String nameAvatar = '';

  @override
  void initState() {
    super.initState();
    favPage =
        widget.favPage ??
        context.findAncestorStateOfType<_FavoritesPageState>()!;
    favPage.folderList = this;
    folders = manager.folderNames;
    _initAvatar();
  }

  void _initAvatar() {
    if (bangumiName.isEmpty) return;
    final cached = appdata.implicitData['nameAvatar'];
    if (cached != null && cached.isNotEmpty) {
      nameAvatar = cached as String;
    } else {
      _fetchAvatar();
    }
  }

  Future<void> _fetchAvatar() async {
    final url = await Bangumi.instance.getBangumiUserAvatarByName(bangumiName);
    appdata.implicitData['nameAvatar'] = url;
    appdata.writeImplicitData();
    if (mounted) setState(() => nameAvatar = url);
  }

  @override
  void update() {
    if (mounted) setState(() {});
  }

  @override
  void updateFolders() {
    if (mounted) setState(() => folders = manager.folderNames);
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: cs.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.withAppbar)
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  const CloseButton(),
                  const SizedBox(width: 8),
                  Text(t.folders, style: ts.s18),
                ],
              ),
            ).paddingTop(context.padding.top),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              widget.withAppbar ? 8 : context.padding.top + 8,
              20,
              8,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.star_rounded, color: cs.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.favorites,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${LocalFavoritesManager().totalAnimes} ${t.animes}',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 16),
          _buildNavTile(
            index: 0,
            icon: Icons.star_rounded,
            title: t.local,
            trailing: _buildLocalCountBadge(),
          ),
          _buildNavTile(
            index: 1,
            icon: Icons.cloud_outlined,
            title: t.bangumiPlan,
            trailing: nameAvatar.isNotEmpty
                ? BangumiAvatar(url: nameAvatar, radius: 14)
                : Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            actionIcon: Icons.edit_outlined,
            actionTooltip: t.switchFavoriteUser,
            onAction: _showSwitchUserDialog,
          ),
          _buildNavTile(
            index: 2,
            icon: Icons.folder_shared_outlined,
            title: t.localFavoriteBinding,
          ),
          const Spacer(),
          if (favPage.pageId == 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(
                        Icons.create_new_folder_outlined,
                        size: 18,
                      ),
                      label: Text(t.newFolder),
                      onPressed: () async {
                        await newFolder();
                        if (mounted) {
                          setState(
                            () => favoritesController.setIsRefreshEnabled(true),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: t.sort,
                    icon: const Icon(Icons.sort),
                    onPressed: () async {
                      await sortFolders();
                      if (mounted) {
                        setState(
                          () => favoritesController.setIsRefreshEnabled(true),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLocalCountBadge() {
    final count = LocalFavoritesManager().totalAnimes;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 12,
          color: context.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  /// 统一的现代导航项：图标容器 + 标题 + 可选操作/计数，选中态为胶囊高亮
  Widget _buildNavTile({
    required int index,
    required IconData icon,
    required String title,
    Widget? trailing,
    IconData? actionIcon,
    String? actionTooltip,
    VoidCallback? onAction,
  }) {
    final selected = favPage.pageId == index;
    final cs = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: selected
            ? cs.secondaryContainer.withValues(alpha: 0.65)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => favPage.setPage(index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: selected
                        ? cs.primary.withValues(alpha: 0.15)
                        : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: selected ? cs.primary : cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? cs.onSurface : cs.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (actionIcon != null && onAction != null) ...[
                  IconButton(
                    tooltip: actionTooltip,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      actionIcon,
                      size: 18,
                      color: cs.onSurfaceVariant,
                    ),
                    onPressed: onAction,
                  ),
                  if (trailing != null) const SizedBox(width: 4),
                ],
                if (trailing != null) trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSwitchUserDialog() {
    showInputDialog(
      context: App.rootContext,
      title: t.switchFavoriteUser,
      hintText: t.enterBangumiUserName,
      confirmText: t.confirm,
      cancelText: t.cancel,
      onConfirm: (value) {
        if (value.isEmpty) {
          favoritesController.setBangumiUserName('');
          appdata.implicitData['nameAvatar'] = '';
          appdata.writeImplicitData();
          favPage.setName('');
        } else {
          favPage.setName(value.toString());
          favoritesController.setBangumiUserName(value.toString());
          _fetchAvatar();
        }
        return null;
      },
    );
  }
}
