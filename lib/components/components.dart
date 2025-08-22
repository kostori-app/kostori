library;

import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/anime_type.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/app_page_route.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/foundation/favorites.dart';
import 'package:kostori/foundation/history.dart';
import 'package:kostori/foundation/image_loader/cached_image.dart';
import 'package:kostori/foundation/image_loader/history_image_provider.dart';
import 'package:kostori/foundation/res.dart';
import 'package:kostori/network/cloudflare.dart';
import 'package:kostori/pages/anime_details_page/anime_page.dart';
import 'package:kostori/pages/favorites/favorites_page.dart';
import 'package:kostori/utils/ext.dart';
import 'package:kostori/utils/translations.dart';
import 'package:marquee/marquee.dart';
import 'package:syntax_highlight/syntax_highlight.dart';

import '../utils/utils.dart';
import 'bangumi_widget.dart';
import 'misc_components.dart';

part 'anime.dart';

part 'appbar.dart';

part 'button.dart';

part 'code.dart';

part 'consts.dart';

part 'effects.dart';

part 'flyout.dart';

part 'gesture.dart';

part 'image.dart';

part 'layout.dart';

part 'loading.dart';

part 'menu.dart';

part 'message.dart';

part 'navigation_bar.dart';

part 'pop_up_widget.dart';

part 'scroll.dart';

part 'select.dart';

part 'side_bar.dart';
