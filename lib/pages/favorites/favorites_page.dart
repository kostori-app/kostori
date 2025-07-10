import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:gif/gif.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/components/misc_components.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/anime_type.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/foundation/favorites.dart';
import 'package:kostori/pages/anime_details_page/anime_page.dart';
import 'package:kostori/utils/ext.dart';
import 'package:kostori/utils/io.dart';
import 'package:kostori/utils/translations.dart';

import 'favorites_controller.dart';

part 'favorite_actions.dart';

part 'favorite_dialog.dart';

part 'local_favorites_page.dart';

part 'side_bar.dart';

const _kLeftBarWidth = 256.0;

const _kTwoPanelChangeWidth = 720.0;

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  late final FavoritesController favoritesController;

  String? folder;

  bool isNetwork = false;

  FolderList? folderList;

  void setFolder(bool isNetwork, String? folder) {
    setState(() {
      this.isNetwork = isNetwork;
      this.folder = folder;
    });
    // folderList?.update();
    appdata.implicitData['favoriteFolder'] = {
      'name': folder,
      'isNetwork': isNetwork,
    };
    appdata.writeImplicitData();
  }

  bool hasSpecificFolder(String targetFolderName) {
    // 调用 _getFolderNamesWithDB 获取所有表名
    final folders = LocalFavoritesManager().folderNames;

    // 检查是否有完全匹配的表名
    return folders.any((folder) => folder == targetFolderName);
  }

  void update() {
    setState(() {});
  }

  @override
  void initState() {
    favoritesController = FavoritesController();
    var data = appdata.implicitData['favoriteFolder'];

    favoritesController.folders = LocalFavoritesManager().folderNames.where((
      name,
    ) {
      if (name == 'default') {
        return LocalFavoritesManager()
            .getAllAnimes('default', FavoriteSortType.nameAsc)
            .isNotEmpty;
      }
      return true;
    }).toList();
    if (data != null) {
      folder = data['name'];
      isNetwork = data['isNetwork'] ?? false;
    } else {
      if (favoritesController.folders.isNotEmpty) {
        setFolder(false, favoritesController.folders[0]);
      }
    }
    if (!hasSpecificFolder("default")) {
      LocalFavoritesManager().createFolder('default');
    }
    if (folder != null &&
        !isNetwork &&
        !LocalFavoritesManager().existsFolder(folder!)) {
      folder = null;
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return IconTheme(
      data: IconThemeData(color: Theme.of(context).colorScheme.secondary),
      child: Stack(
        children: [
          AnimatedPositioned(
            left: context.width <= _kTwoPanelChangeWidth ? -_kLeftBarWidth : 0,
            top: 0,
            bottom: 0,
            duration: const Duration(milliseconds: 200),
            child: (_LeftBar(
              favoritesController: favoritesController,
            )).fixWidth(_kLeftBarWidth),
          ),
          Positioned(
            top: 0,
            left: context.width <= _kTwoPanelChangeWidth ? 0 : _kLeftBarWidth,
            right: 0,
            bottom: 0,
            child: buildBody(),
          ),
        ],
      ),
    );
  }

  void showFolderSelector() {
    Navigator.of(App.rootContext).push(
      PageRouteBuilder(
        barrierDismissible: true,
        fullscreenDialog: true,
        opaque: false,
        barrierColor: Colors.black.toOpacity(0.36),
        pageBuilder: (context, animation, secondary) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Material(
              child: SizedBox(
                width: min(300, context.width - 16),
                child: _LeftBar(
                  withAppbar: true,
                  favPage: this,
                  onSelected: () {
                    context.pop();
                  },
                  favoritesController: favoritesController,
                ),
              ),
            ),
          );
        },
        transitionsBuilder: (context, animation, secondary, child) {
          var offset = Tween<Offset>(
            begin: const Offset(-1, 0),
            end: const Offset(0, 0),
          );
          return SlideTransition(
            position: offset.animate(
              CurvedAnimation(parent: animation, curve: Curves.fastOutSlowIn),
            ),
            child: child,
          );
        },
      ),
    );
  }

  Widget buildBody() {
    if (folder == null) {
      return CustomScrollView(
        slivers: [
          SliverAppbar(
            leading: Tooltip(
              message: "Folders".tl,
              child: context.width <= _kTwoPanelChangeWidth
                  ? IconButton(
                      icon: const Icon(Icons.menu),
                      color: context.colorScheme.primary,
                      onPressed: showFolderSelector,
                    )
                  : null,
            ),
            title: GestureDetector(
              onTap: context.width < _kTwoPanelChangeWidth
                  ? showFolderSelector
                  : null,
              child: Text("Unselected".tl),
            ),
          ),
        ],
      );
    }
    return _LocalFavoritesPage(
      favoritesController: favoritesController,
      // folder: folder!,
      // key: PageStorageKey("local_$folder"),
    );
  }
}

abstract interface class FolderList {
  void update();

  void updateFolders();
}
