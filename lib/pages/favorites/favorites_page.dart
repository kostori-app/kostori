import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gif/gif.dart';
import 'package:kostori/components/animated.dart';
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
import 'package:kostori/utils/ext.dart';
import 'package:kostori/utils/io.dart';
import 'package:mobx/mobx.dart';

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
  late final FavoritesController favoritesController;

  String? folder;
  bool isNetwork = false;
  int pageId = 0;

  FolderList? folderList;

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
    setState(() => favoritesController.bangumiUserName = name);
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
    favoritesController = FavoritesController();
    pageId = appdata.settings['favoritePageId'] ?? 0;
    favoritesController.bangumiUserName = appdata.settings.s.bangumiUserName;

    // Ensure 'default' folder exists.
    final mgr = LocalFavoritesManager();
    if (!mgr.folderNames.contains('default')) {
      mgr.createFolder('default');
    }

    favoritesController.folders = mgr.folderNames.where((name) {
      if (name == 'default') {
        return mgr.getAllAnimes('default', FavoriteSortType.nameAsc).isNotEmpty;
      }
      return true;
    }).toList();

    final data = appdata.implicitData['favoriteFolder'];
    if (data != null) {
      folder = data['name'] as String?;
      isNetwork = (data['isNetwork'] as bool?) ?? false;
    }

    if (folder != null && !isNetwork && !mgr.existsFolder(folder!)) {
      folder = null;
    }
    if (folder == null && favoritesController.folders.isNotEmpty) {
      setFolder(false, favoritesController.folders.first);
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
    if (folder == null) {
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

  String get bangumiName => widget.favoritesController.bangumiUserName;

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
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: context.colorScheme.outlineVariant,
            width: 0.6,
          ),
        ),
      ),
      child: Column(
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
            padding: widget.withAppbar
                ? EdgeInsets.zero
                : EdgeInsets.only(top: context.padding.top),
            child: _buildNavCard(index: 0, child: _buildLocalTitle()),
          ),
          _buildNavCard(index: 1, child: _buildBangumiTitle()),
          _buildNavCard(index: 2, child: _buildLocalBangumiTitle()),
        ],
      ),
    );
  }

  Widget _buildNavCard({required int index, required Widget child}) {
    final selected = favPage.pageId == index;
    return Card(
      color: selected
          ? context.colorScheme.primaryContainer.toOpacity(0.36)
          : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => favPage.setPage(index),
        child: child,
      ),
    );
  }

  Widget _buildLocalTitle() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(Icons.star, color: context.colorScheme.secondary),
          const SizedBox(width: 12),
          Text(t.local),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.add),
            color: context.colorScheme.primary,
            onPressed: () async {
              await newFolder();
              if (mounted) {
                setState(() => favoritesController.isRefreshEnabled = true);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.reorder),
            color: context.colorScheme.primary,
            onPressed: () async {
              await sortFolders();
              if (mounted) {
                setState(() => favoritesController.isRefreshEnabled = true);
              }
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  Widget _buildBangumiTitle() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: 16),
          if (nameAvatar.isNotEmpty) ...[
            CircleAvatar(
              radius: 18,
              backgroundImage: NetworkImage(nameAvatar),
              backgroundColor: Colors.transparent,
            ),
            const SizedBox(width: 12),
            Text(bangumiName),
          ] else ...[
            Icon(Icons.star, color: context.colorScheme.secondary),
            const SizedBox(width: 12),
            Text(t.bangumiPlan),
          ],
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.edit),
            color: context.colorScheme.primary,
            onPressed: _showSwitchUserDialog,
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  Widget _buildLocalBangumiTitle() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(Icons.star, color: context.colorScheme.secondary),
          const SizedBox(width: 12),
          Text(t.localFavoriteBinding),
          const Spacer(),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  void _showSwitchUserDialog() {
    showInputDialog(
      context: App.rootContext,
      title: t.switchFavoriteUser,
      hintText: t.newFolder,
      onConfirm: (value) {
        if (value.isEmpty) {
          favoritesController.bangumiUserName = '';
          appdata.implicitData['nameAvatar'] = '';
          appdata.writeImplicitData();
          favPage.setName('');
        } else {
          favPage.setName(value.toString());
          favoritesController.bangumiUserName = value.toString();
          _fetchAvatar();
        }
        return null;
      },
    );
  }

  Widget? buildLocalFolder(String name) {
    if (name == 'default') {
      if (manager.getAllAnimes('default', FavoriteSortType.nameAsc).isEmpty) {
        return const SizedBox.shrink();
      }
    }

    final isSelected = name == favPage.folder && !favPage.isNetwork;
    final count = manager.folderAnimes(name);

    return InkWell(
      onTap: isSelected
          ? null
          : () {
              favPage.setFolder(false, name);
              widget.onSelected?.call();
            },
      child: Container(
        height: 42,
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: isSelected
              ? context.colorScheme.primaryContainer.toOpacity(0.36)
              : null,
          border: Border(
            left: BorderSide(
              color: isSelected
                  ? context.colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        padding: const EdgeInsets.only(left: 16),
        child: Row(
          children: [
            Expanded(child: Text(name == 'default' ? t.kDefault : name)),
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: context.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(count.toString()),
            ),
          ],
        ),
      ),
    );
  }
}
