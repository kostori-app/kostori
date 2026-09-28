# 共享组件清单（`lib/components/`）

写任何 UI 之前先看这里，**优先复用项目已有组件，不要直接写 Flutter/Material 默认控件**。

## 导入方式

- 大多数组件从 barrel 导入：`import 'package:kostori/components/components.dart';`
  （其中 `part` 的文件：appbar、button、message、sheet、menu、flyout、select、select_card、scroll、image、layout、loading、effects、navigation_bar、pop_up_widget、side_bar、selection_menu、favorite_dialog、anime、anime_rating、gesture、code、assistant_avatar、consts；并再导出 `animated.dart`、`qr_code.dart`）
- 以下为独立文件，**需单独 import**：`anime_list.dart`、`anime_filter.dart`（`AnimeFilter`/`AnimeFilterScope`/`AnimeFilterBar`，卡片筛选）、`bangumi_widget.dart`(+`bangumi_cards.dart`)、`translation_widget.dart`、`ui_components.dart`、`empty_state.dart`、`watermark.dart`、`custom_markdown_widget.dart`、`grid_speed_dial.dart`、`image_preview_widget.dart`、`character_card_editor.dart`、`qr_clipboard_widget.dart`、`system_status_widget.dart`、`timeline_tree.dart`、`window_frame.dart`、`calendar_screenshot_widget.dart`、`color_pick_page.dart`、`ai_model_card.dart`、`js_ui.dart`、`word_cloud_widget.dart`、`share_widget.dart`、`bean/card/*.dart`

## Material 默认 → 项目组件（重点）

| 不要用 | 用项目里的 | 位置 |
| --- | --- | --- |
| `SnackBar` | `context.showMessage(...)` / `ToastManager.show` / `showCenter` | `foundation/context.dart`、`components/message.dart` |
| `AlertDialog` / `showDialog` | `ContentDialog.show` / `showConfirmDialog` / `showInfoDialog` / `showInputDialog` / `showSelectDialog` / `showCaptchaDialog` | `components/message.dart` |
| `showModalBottomSheet` | `Sheet` | `components/sheet.dart` |
| `AppBar` / `SliverAppBar` | `Appbar` / `SliverAppbar`（`AppBackButton`） | `components/appbar.dart` |
| `ElevatedButton`/`OutlinedButton`/`TextButton` | `Button`(+`.filled/.outlined/.text/.normal`) / `CapsuleButton` / `IconTileButton` | `components/button.dart` |
| `TabBar` / `TabBarView` | `AppTabBar` / `TabViewBody` / `CapsuleTabBar` | `components/appbar.dart`、`components/select.dart` |
| `SearchBar` | `AppSearchBar` / `SliverSearchBar`（`SearchBarController`） | `components/appbar.dart` |
| `DropdownButton` | `Select` | `components/select.dart` |
| `SegmentedButton` / `ChoiceChip`/`FilterChip` | `SlidingSegmentedBar` / `CapsuleChipGroup` / `OptionChip` / `FilterChipFixedWidth` | `components/select.dart` |
| `RadioListTile` / `CheckboxListTile` | `SelectCard` | `components/select_card.dart` |
| `Switch` | `CustomSwitch` | `components/animated.dart` |
| `PopupMenuButton` / `showMenu` | `showMenuX`+`MenuEntry` / `Flyout`（`FlyoutTextButton` 等） | `components/menu.dart`、`components/flyout.dart` |
| `RefreshIndicator` / `CircularProgressIndicator` | `PolygonRefreshIndicator` / `ListLoadingIndicator` / `FiveDotLoadingAnimation` | `components/animated.dart`、`components/loading.dart` |
| `CustomScrollView` / `Scrollbar` | `SmoothCustomScrollView` / `AppScrollBar` | `components/scroll.dart` |
| `Image` / `Hero` | `AnimatedImage` / `KostoriHero`（gallery：`ImagePreviewWidget`） | `components/image.dart`、`components/image_preview_widget.dart` |
| 手写空态/错误页 | `EmptyState` / `ErrorState` / `NetworkError` | `components/empty_state.dart`、`components/loading.dart` |
| `NavigationBar` / `NavigationRail` / `Drawer` | `NaviPane` / `SidebarBody`（`showSideBar`、`openQuickDrawer`） | `components/navigation_bar.dart`、`components/side_bar.dart` |
| `SelectionArea` / `SelectableText` | `AppSelectionArea` / `AppSelectableText`（含翻译/搜索菜单） | `components/selection_menu.dart` |
| `Markdown` | `CustomMarkdownWidget` | `components/custom_markdown_widget.dart` |
| `CircleAvatar`（AI 头像） | `AssistantAvatar` | `components/assistant_avatar.dart` |

## 常用对话框 / Toast / Sheet / 路由 helpers

- Toast：`context.showMessage(message: ..., level: ...)`（最常用）；居中：`showCenter(...)`。
- 对话框：`ContentDialog.show(...)`；快捷：`showConfirmDialog` / `showInfoDialog` / `showInputDialog` / `showSelectDialog` / `showCaptchaDialog` / `showDialogMessage`；阻塞进度：`showLoadingDialog(...)`（返回 `LoadingDialogController`）。
- 全屏弹层路由：`showPopUpWidget<T>(context, widget)`；底部 sheet：`Sheet`、`showQrShareSheet`；侧栏：`showSideBar`。
- 页面跳转（`lib/foundation/context.dart` 的 `extension Navigation on BuildContext`）：
  `context.to(builder)`、`context.pop()`、`context.toReplacement`、`context.toSheet`、`context.toBlurFade`、`context.toFadeScale`。**别用 `Navigator.push` + `MaterialPageRoute`。**
- i18n：`context.t.xxx`（`extension ContextI18n`）；宽高/暗色：`context.width` / `.height` / `.isDarkMode` / `.colorScheme`。

## 全部组件（按区域）

**应用栏/导航**：`Appbar`、`SliverAppbar`、`AppBackButton`、`openQuickDrawer`（appbar.dart）；`AppTabBar`、`TabViewBody`、`TabActionButton`、`SearchBarController`、`SliverSearchBar`、`AppSearchBar`；`NaviPane`/`NavigationBar`/`PaneItemEntry`/`PaneActionEntry`（navigation_bar.dart）；`SideBarRoute`/`SidebarBody`/`showSideBar`（side_bar.dart）。

**按钮**：`Button`、`CapsuleButton`、`CapsuleButtonBar`、`HoverBox`、`MenuButton`、`IconTileButton`、`FlyoutTextButton`、`FlyoutIconButton`、`FlyoutFilledButton`（button.dart）。

**对话框/消息/弹层**：`ContentDialog`、`ToastManager`、`ToastStyle`、`showDialogMessage`、`showConfirmDialog`、`showInfoDialog`、`showInputDialog`、`showSelectDialog`、`showCaptchaDialog`、`showCenter`、`LoadingDialogController`、`showLoadingDialog`、`LoadingOverlay`（message.dart）；`Sheet`、`showQrShareSheet`（sheet.dart）；`PopUpWidget`、`PopUpWidgetScaffold`、`PopupIndicatorWidget`、`showPopUpWidget`（pop_up_widget.dart）；`FlyoutController`、`Flyout`、`FlyoutContent`（flyout.dart）。

**选择/表单**：`Select`、`SlidingSegmentedBar`、`CapsuleOptions`、`CapsuleOption`、`CapsuleTabBar`、`CapsuleChipGroup`、`CapsuleChip`、`OptionChip`、`FilterChipFixedWidth`、`AnimatedCheckIcon`（select.dart）；`SelectCard`（select_card.dart）；`CustomSwitch`（animated.dart）；`CodeEditor`（code.dart）；`ColorPickPage`（color_pick_page.dart）。

**滚动/布局/图片**：`SmoothCustomScrollView`、`SmoothScrollProvider`、`AppScrollBar`（scroll.dart）；`SliverGridViewWithFixedItemHeight`、`SliverGridDelegateWithFixedHeight`、`SliverGridDelegateWithAnimes`、`SliverGridDelegateWithBangumiItems`、`SliverLazyToBoxAdapter`（layout.dart）；`AnimatedImage`、`KostoriHero`、`HeroShuttleScope`、`ImagePart`、`ImagePainter`（image.dart）；`ImagePreviewWidget`（image_preview_widget.dart）；`KostoriQrCode`、`KostoriQrCard`（qr_code.dart）；`KostoriWatermark`（watermark.dart）；`EmptyState`、`ErrorState`（empty_state.dart）。

**反馈/加载**：`PolygonRefreshIndicator`、`CustomSwitch`、`AnimatedPlayIconWave`（animated.dart）；`ListLoadingIndicator`、`SliverListLoadingIndicator`、`FiveDotLoadingAnimation`、`NetworkError`、`LoadingState<T,S>`、`MultiPageLoadingState<T,S>`（loading.dart）；`KostoriRefreshIndicator`、`FloatingMenu`、`tabPagePhysics`（ui_components.dart）。

**动画/手势/特效**：`MouseBackDetector`、`AnimatedTapRegion`（gesture.dart）；`BlurEffect`（effects.dart）；`GridSpeedDial`、`SpeedDialChild`、`AnimatedFloatingButton`（grid_speed_dial.dart）；`TimelineTreeNode`（timeline_tree.dart）。

**文本/选择/翻译**：`AppSelectionArea`、`AppSelectableText`、`appSelectionContextMenu`、`appEditableSelectionContextMenu`、`appSelectionLinkItems`、`firstUrlInSelection`、`showTranslationSheet`（selection_menu.dart）；`TranslatedContent`、`TranslationWidget`、`TranslateIconButton`、`TranslationOutput`（translation_widget.dart）；`ExpandableText`、`ExpandableTags`（bangumi_widget.dart）。

**番剧/内容卡片**：`AnimeDisplayModeScope`、`AnimeSourceLayoutBar`、`AnimeTile`、`SliverGridAnimes`、`SliverMasonryAnimes`（anime.dart）；`AnimeList`、`AnimeListState`（anime_list.dart）；`StarRating`、`RatingWidget`、`SimpleAnimeTile`（anime_rating.dart）；`BangumiWidget`、`BangumiBriefCard`、`BangumiDetailedCard`、`BangumiCharacterCard`、`BangumiCard`、`BangumiAvatar`、`StatItem`、`KeepAliveWrapper`（bangumi_widget.dart、bangumi_cards.dart）；`bean/card/` 下 `CommentsCard`、`EpisodeCommentsCard`、`EpisodeCommentsSheet`、`ReviewsCard`、`ReviewsCommentsCard`、`StaffCard`、`TopicsCard`、`TopicsInfoCommentsCard`、`CharacterCard`、`CharacterCommentsCard`（多数带 `.bone` 骨架态）。

**AI/分享/系统**：`AssistantAvatar`（assistant_avatar.dart）；`AiModelCard`（ai_model_card.dart）；`CharacterAvatar`、`AvatarPicker`、`CharacterCardEditor`、`CharacterCardView`、`showCharacterCardEditor`、`exportCharacterCardPng`（character_card_editor.dart）；`ShareWidget`、`captureAndSave`、`ShareQrCode`（share_widget.dart、share_cards.dart）；`CalendarScreenshotWidget`（calendar_screenshot_widget.dart）；`QrClipboardWidget`、`clipboardNotifierProvider`（qr_clipboard_widget.dart）；`BatteryWidget`、`SpeedMonitorWidget`、`NetworkStatusWidget`（system_status_widget.dart）；`WordCloudWidget`（word_cloud_widget.dart）；`WindowFrame`、`VirtualWindowFrame`、`WindowFrameController`（window_frame.dart）；`JsUiApi`（js_ui.dart）。

## 最高频组件（跨 `lib/pages/` 出现次数，优先掌握）

`context.showMessage`/`ToastManager`、`PolygonRefreshIndicator`、`ContentDialog`+`show*Dialog`、`Sheet`、`Appbar`、`showPopUpWidget`、`CustomSwitch`、`Button`/`CapsuleButton`、`IconTileButton`、`Select`、`AppSelectableText`/`CapsuleOptions`、`CharacterCard`、`SmoothCustomScrollView`、`KostoriRefreshIndicator`、`AnimatedImage`、`KostoriHero`。
