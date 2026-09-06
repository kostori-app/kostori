import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:kostori/components/bangumi_widget.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/components/grid_speed_dial.dart';
import 'package:kostori/components/ui_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_qjs/flutter_qjs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/image_loader/cached_image.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/foundation/me_plugin/me_plugin.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/pages/settings/settings_page.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// 打开插件管理页（项目风格 Scaffold + 内置 SliverAppbar）
Future<void> openMePagePluginManage(BuildContext context) {
  return context.to(
    () => Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: const SafeArea(child: PluginSettings()),
    ),
  );
}

/// 安全转 double：避免插件返回非数字时 as 强转崩溃
double _asDouble(dynamic v, [double fallback = 0]) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

/// 安全转 String
String _asStr(dynamic v, [String fallback = '']) {
  if (v == null) return fallback;
  return v.toString();
}

/// 安全转 int
int _asInt(dynamic v, [int fallback = 0]) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim()) ?? fallback;
  return fallback;
}

/// 个人页插件模块渲染：读取 data/me_plugins 下的插件，渲染其 render() 返回的模块。
class MePagePluginModules extends ConsumerStatefulWidget {
  const MePagePluginModules({super.key});

  @override
  ConsumerState<MePagePluginModules> createState() =>
      _MePagePluginModulesState();
}

class _MePagePluginModulesState extends ConsumerState<MePagePluginModules> {
  List<Widget> _cards = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await MePagePluginManager().ensureInit();
      final plugins = MePagePluginManager().all();
      final cards = <Widget>[];
      for (final p in plugins) {
        if (!MePagePluginManager().isEnabled(p.key)) continue;
        // 带导航的插件：进入“导航壳”浏览，不在 Me 页直接铺开 render()
        if (p.hasNav) {
          cards.add(_PluginShellEntry(plugin: p));
          continue;
        }
        final modules = await p.render();
        for (final m in modules) {
          final w = _ModuleView.build(context, p, m);
          if (w != null) cards.add(w);
        }
      }
      if (mounted) {
        setState(() {
          _cards = cards;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final cs = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant, width: 0.6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题 + 插件管理入口（与个人页其它模块头一致）
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.widgets_outlined, color: cs.primary, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t.mePagePlugin,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Tooltip(
                    message: t.oneKeySign,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _signAll,
                      onLongPress: _openSignDetail,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Icons.assignment_turned_in_outlined,
                          size: 20,
                          color: cs.primary,
                        ),
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _openManage,
                    icon: const Icon(Icons.settings_outlined, size: 16),
                    label: Text(t.manage),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: _cards.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        t.noMePagePlugin,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant.toOpacity(0.7),
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _cards,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 一键签到（自动跳过未登录/今日已签/不在名单）
  Future<void> _signAll() async {
    final results = await MePagePluginManager().runCollectiveSignin();
    if (!mounted) return;
    await _load();
    final ok = results.where((r) => r['ok'] == true).length;
    final fail = results.length - ok;
    if (results.isEmpty) {
      App.rootContext.showMessage(message: t.noPluginToSign);
    } else if (fail == 0) {
      App.rootContext.showMessage(message: t.signAllSuccess(success: ok));
    } else {
      App.rootContext.showMessage(
        message: t.signAllPartial(success: ok, fail: fail),
        level: LogLevel.warning,
      );
    }
  }

  void _openSignDetail() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PluginSignManagerPage(),
      ),
    );
  }

  /// 打开插件管理页
  void _openManage() {
    App.mainNavigatorKey?.currentContext?.to(
      () => Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: SafeArea(child: const PluginSettings()),
      ),
    );
  }
}

/// 单个模块的渲染器
class _ModuleView {
  static Map<String, dynamic> _map(dynamic raw) {
    if (raw is! Map) return {};
    return raw.map((k, v) => MapEntry(k.toString(), v));
  }

  static Widget? build(BuildContext context, MePagePlugin plugin, dynamic raw) {
    final m = _map(raw);
    final type = m['type']?.toString();
    switch (type) {
      case 'card':
        final children = m['children'] is List
            ? m['children'] as List
            : const [];
        return _PluginCard(
          title: m['title']?.toString(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children
                .map((c) => buildInline(context, plugin, c))
                .whereType<Widget>()
                .toList(),
          ),
        );
      case 'text':
        return _PluginCard(
          child: Text(
            m['text']?.toString() ?? '',
            style: const TextStyle(fontSize: 13),
          ),
        );
      case 'keyValue':
        return _PluginCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${m['key'] ?? ''}：',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Expanded(
                child: Text(
                  m['value']?.toString() ?? '',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        );
      case 'link':
        return _PluginCard(
          child: _Link(m['text']?.toString() ?? '', m['url']?.toString() ?? ''),
        );
      case 'progress':
        return _PluginCard(child: _Progress(m));
      case 'chips':
        return _PluginCard(child: _Chips(m['items']));
      case 'signIn':
        return _PluginCard(
          child: _SignInButton(plugin: plugin, m: m),
        );
      case 'list':
        return _PluginCard(
          title: m['title']?.toString(),
          child: _PluginList(plugin: plugin, m: m),
        );
      case 'board':
        return _PluginCard(
          title: m['title']?.toString(),
          child: Align(
            alignment: Alignment.centerLeft,
            child: IconTileButton(
              icon: const Icon(Icons.forum_outlined),
              label: m['title']?.toString() ?? '',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PluginBoardPage(
                      plugin: plugin,
                      meta: m,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      case 'form':
        return _PluginCard(
          title: m['title']?.toString(),
          child: _PluginForm(plugin: plugin, m: m),
        );
      case 'button':
        return _PluginCard(child: _Button(plugin: plugin, m: m));
      default:
        return null;
    }
  }

  /// 卡片内部的子模块（不再套卡片外壳）
  static Widget? buildInline(
    BuildContext context,
    MePagePlugin plugin,
    dynamic raw,
  ) {
    final m = _map(raw);
    final type = m['type']?.toString();
    switch (type) {
      case 'text':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            m['text']?.toString() ?? '',
            style: const TextStyle(fontSize: 13),
          ),
        );
      case 'keyValue':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${m['key'] ?? ''}：',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Expanded(
                child: Text(
                  m['value']?.toString() ?? '',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        );
      case 'link':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: _Link(m['text']?.toString() ?? '', m['url']?.toString() ?? ''),
        );
      case 'progress':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: _Progress(m),
        );
      case 'chips':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: _Chips(m['items']),
        );
      case 'signIn':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: _SignInButton(plugin: plugin, m: m),
        );
      case 'list':
        return _PluginList(plugin: plugin, m: m);
      case 'form':
        return _PluginForm(plugin: plugin, m: m);
      case 'button':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: _Button(plugin: plugin, m: m),
        );
      default:
        return null;
    }
  }
}

/// 项目风格卡片：surfaceContainerLow 底色 + outlineVariant 描边 + 圆角
class _PluginCard extends StatelessWidget {
  final String? title;
  final Widget child;

  const _PluginCard({this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: cs.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cs.outlineVariant, width: 0.6),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null && title!.isNotEmpty) ...[
                Text(
                  title!,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _Link extends StatelessWidget {
  final String text;
  final String url;

  const _Link(this.text, this.url);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: url.isEmpty
          ? null
          : () async {
              try {
                await launchUrlString(url);
              } catch (_) {}
            },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.open_in_new,
            size: 14,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text.isEmpty ? url : text,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.primary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  final Map<String, dynamic> m;

  const _Progress(this.m);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final value = _asDouble(m['value']).clamp(0.0, 1.0);
    final label = _asStr(m['label']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Row(
            children: [
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 12)),
              ),
              Text(
                '${(value * 100).round()}%',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 8,
            backgroundColor: cs.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}

class _Chips extends StatelessWidget {
  final dynamic items;

  const _Chips(this.items);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final list = (items is List ? items : const []).map((e) => e.toString());
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final text in list)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: cs.secondaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: cs.onSecondaryContainer),
            ),
          ),
      ],
    );
  }
}

/// 签到按钮：点击发送 GET/POST 并展示返回结果
class _SignInButton extends StatefulWidget {
  final MePagePlugin plugin;
  final Map<String, dynamic> m;

  const _SignInButton({required this.plugin, required this.m});

  @override
  State<_SignInButton> createState() => _SignInButtonState();
}

class _SignInButtonState extends State<_SignInButton> {
  bool _loading = false;

  Future<void> _onPressed() async {
    final url = widget.m['url']?.toString() ?? '';
    if (url.isEmpty) {
      App.rootContext.showMessage(message: t.missingUrl, level: LogLevel.warning);
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await MePagePlugin.request(
        url: url,
        method: (widget.m['method']?.toString() ?? 'GET').toUpperCase(),
        headers: _toMap(widget.m['headers']),
        body: _toMap(widget.m['body']),
      );
      final status = res['status'];
      final successText = widget.m['successText']?.toString();
      if (status == 200) {
        final rawBody = res['body']?.toString() ?? '';
        String body = rawBody;
        final cdStart = rawBody.indexOf('<![CDATA[');
        if (cdStart >= 0) {
          final cdEnd = rawBody.indexOf(']]>', cdStart);
          if (cdEnd > cdStart) {
            body = rawBody.substring(cdStart + 9, cdEnd);
          }
        }
        body = body
            .replaceAll(RegExp(r'<[^>]+>'), '')
            .trim();
        if (body.isEmpty) body = rawBody.trim();
        final needLogin = body.contains('未登录') ||
            body.contains('请登录') ||
            body.contains('需要登录') ||
            body.contains('登录后才能');
        final show = (successText == null || successText.isEmpty)
            ? (body.isEmpty ? t.success : body)
            : successText;
        if (needLogin) {
          App.rootContext.showMessage(
            message: show,
            level: LogLevel.error,
          );
        } else {
          widget.plugin.markSignedToday();
          App.rootContext.showMessage(message: show);
        }
      } else {
        App.rootContext.showMessage(
          message: t.failedWithStatus(status: status),
          level: LogLevel.error,
        );
      }
    } catch (e) {
      App.rootContext.showMessage(
          message: t.requestFailedDetail(error: e),
          level: LogLevel.error,
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static Map<String, dynamic> _toMap(dynamic v) {
    if (v is Map) {
      return v.map((k, val) => MapEntry(k.toString(), val));
    }
    return {};
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FilledButton.tonal(
      onPressed: _loading ? null : _onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: cs.primaryContainer,
        foregroundColor: cs.onPrimaryContainer,
      ),
      child: _loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: PolygonRefreshIndicator(),
            )
          : Text(widget.m['text']?.toString() ?? t.checkIn),
    );
  }
}

/// 通用按钮：onTap 为 JS 回调；也可携带 page/params 跳转插件子页面
class _Button extends StatelessWidget {
  final MePagePlugin plugin;
  final Map<String, dynamic> m;

  const _Button({required this.plugin, required this.m});

  @override
  Widget build(BuildContext context) {
    final page = m['page']?.toString();
    final onTap = m['onTap'];
    return FilledButton.tonal(
      onPressed: page != null && page.isNotEmpty
          ? () => _pushPluginPage(
                context,
                plugin,
                page,
                _paramsOf(m),
              )
          : onTap is JSInvokable
          ? () {
              try {
                onTap.invoke([]);
              } catch (_) {}
            }
          : null,
      child: Text(m['text']?.toString() ?? t.button),
    );
  }
}

/// 列表模块：爬取的条目，可跳转插件子页（详情）。
class _PluginList extends StatelessWidget {
  final MePagePlugin plugin;
  final Map<String, dynamic> m;

  const _PluginList({required this.plugin, required this.m});

  @override
  Widget build(BuildContext context) {
    final rawItems = m['items'];
    final items = rawItems is List ? rawItems : const [];

    // 数据由子页补全（source 形态）：提供“打开页面”入口
    final sourcePage = m['page']?.toString();
    if (items.isEmpty && sourcePage != null && sourcePage.isNotEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.tonal(
          onPressed: () =>
              _pushPluginPage(context, plugin, sourcePage, _paramsOf(m)),
          child: Text(m['moreText']?.toString() ?? t.more),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final raw in items)
          if (raw is Map) _PluginListRow(plugin: plugin, raw: raw),
      ],
    );
  }
}

class _PluginListRow extends StatelessWidget {
  final MePagePlugin plugin;
  final Map raw;

  const _PluginListRow({required this.plugin, required this.raw});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final m = raw.map((k, v) => MapEntry(k.toString(), v));
    final title = m['title']?.toString() ?? '';
    final subtitle = m['subtitle']?.toString();
    final image = m['image']?.toString();
    final page = m['page']?.toString();
    final params = m['params'] is Map
        ? (m['params'] as Map).map((k, v) => MapEntry(k.toString(), v.toString()))
        : const <String, dynamic>{};
    if (m['url'] != null) params['url'] = m['url'].toString();

    Widget leading = Container(
      width: 44,
      height: 62,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: image != null && image.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: _genericPluginImage(image),
            )
          : const Icon(Icons.image_outlined, size: 18),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: page != null && page.isNotEmpty
            ? () => _pushPluginPage(context, plugin, page, params)
            : null,
        child: Row(
          children: [
            leading,
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (page != null && page.isNotEmpty)
              Icon(Icons.chevron_right, size: 18, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// 表单模块：点击弹出字段表单，提交走 MePagePlugin.request（GET/POST）
class _PluginForm extends StatefulWidget {
  final MePagePlugin plugin;
  final Map<String, dynamic> m;

  const _PluginForm({required this.plugin, required this.m});

  @override
  State<_PluginForm> createState() => _PluginFormState();
}

class _PluginFormState extends State<_PluginForm> {
  bool _loading = false;

  List<Map<String, dynamic>> get _fields {
    final list = widget.m['fields'];
    return list is List
        ? list.map((e) {
            final map = e is Map
                ? e.map((k, v) => MapEntry(k.toString(), v))
                : const <String, dynamic>{};
            return map;
          }).toList()
        : const [];
  }

  Future<void> _open() async {
    if (_loading) return;
    final ctrls = <String, TextEditingController>{};
    for (final f in _fields) {
      ctrls[f['key']?.toString() ?? ''] = TextEditingController();
    }
    var submit = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlg) {
            return ContentDialog(
              title: widget.m['title']?.toString() ?? t.form,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final f in _fields)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: TextField(
                        controller:
                            ctrls[f['key']?.toString() ?? ''],
                        obscureText: f['kind'] == 'password',
                        keyboardType: f['kind'] == 'number'
                            ? TextInputType.number
                            : TextInputType.text,
                        decoration: InputDecoration(
                          labelText: f['label']?.toString() ?? '',
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                Button.filled(
                  onPressed: () async {
                    submit = true;
                    Navigator.pop(ctx);
                  },
                  child: Text(widget.m['submitText']?.toString() ?? t.confirm),
                ),
              ],
            );
          },
        );
      },
    );
    for (final c in ctrls.values) {
      c.dispose();
    }
    if (!submit) return;

    setState(() => _loading = true);
    try {
      final body = Map<String, dynamic>.from(_toMap(widget.m['body']));
      for (final f in _fields) {
        final key = f['key']?.toString() ?? '';
        final text = ctrls[key]?.text ?? '';
        if (f['kind'] == 'number') {
          body[key] = num.tryParse(text) ?? 0;
        } else {
          body[key] = text;
        }
      }
      final res = await MePagePlugin.request(
        url: widget.m['url']?.toString() ?? '',
        method: (widget.m['method']?.toString() ?? 'POST').toUpperCase(),
        headers: _toMap(widget.m['headers']),
        body: body,
      );
      final successText = widget.m['successText']?.toString();
      if ((res['status'] as num?) == 200) {
        final rbody = res['body']?.toString().trim() ?? '';
        App.rootContext.showMessage(
          message: successText ?? (rbody.isEmpty ? t.success : rbody),
        );
      } else {
        App.rootContext.showMessage(
          message: t.failedWithStatus(status: res['status']),
          level: LogLevel.error,
        );
      }
    } catch (e) {
      App.rootContext.showMessage(
        message: t.requestFailedDetail(error: e),
        level: LogLevel.error,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static Map<String, dynamic> _toMap(dynamic v) {
    if (v is Map) {
      return v.map((k, val) => MapEntry(k.toString(), val));
    }
    return {};
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FilledButton.tonal(
        onPressed: _loading ? null : _open,
        child: Text(widget.m['text']?.toString() ?? t.submit),
      ),
    );
  }
}

// ---------- 子页 / 导航壳 ----------

Map<String, dynamic> _paramsOf(Map<String, dynamic> m) {
  final p = <String, dynamic>{};
  if (m['params'] is Map) {
    (m['params'] as Map).forEach((k, v) => p[k.toString()] = v.toString());
  }
  return p;
}

Future<void> _pushPluginPage(
  BuildContext context,
  MePagePlugin plugin,
  String name,
  Map<String, dynamic> params, {
  Map<String, dynamic>? item,
}) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => name == 'thread'
          ? PluginThreadPage(plugin: plugin, params: params, row: item)
          : PluginSubPage(plugin: plugin, name: name, params: params),
    ),
  );
}

/// 单层插件子页（详情等）：调用 plugin.page(name, params) 渲染模块
class PluginSubPage extends StatefulWidget {
  final MePagePlugin plugin;
  final String name;
  final Map<String, dynamic> params;

  const PluginSubPage({
    super.key,
    required this.plugin,
    required this.name,
    this.params = const {},
  });

  @override
  State<PluginSubPage> createState() => _PluginSubPageState();
}

class _PluginSubPageState extends State<PluginSubPage> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.plugin.page(widget.name, widget.params);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbar(title: Text(widget.plugin.titleOf(widget.name))),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              child: PolygonRefreshIndicator(),
            );
          }
          final modules = snap.data ?? const [];
          return _contentOrBoard(widget.plugin, modules);
        },
      ),
    );
  }
}

/// 通用模块列表（子页 / 详情页内容）
class _PluginModulesList extends StatelessWidget {
  final MePagePlugin plugin;
  final List<dynamic> modules;

  const _PluginModulesList({required this.plugin, required this.modules});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        for (final m in modules)
          if (_ModuleView.build(context, plugin, m) != null)
            _ModuleView.build(context, plugin, m)!,
      ],
    );
  }
}

/// 个人页上“打开插件导航”的入口卡片
class _PluginShellEntry extends StatelessWidget {
  final MePagePlugin plugin;

  const _PluginShellEntry({required this.plugin});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PluginShellPage(plugin: plugin),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.widgets_outlined, size: 20, color: cs.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    plugin.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  t.open,
                  style: TextStyle(fontSize: 13, color: cs.primary),
                ),
                Icon(Icons.chevron_right, size: 18, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 插件导航壳：顶部/底部导航 + 各导航页内容（每页各自调用 plugin.page）
class PluginShellPage extends StatefulWidget {
  final MePagePlugin plugin;

  /// 打开时定位的初始页 key（如 'login'），null 时取第一个导航页
  final String? initialPageKey;

  const PluginShellPage({
    super.key,
    required this.plugin,
    this.initialPageKey,
  });

  @override
  State<PluginShellPage> createState() => _PluginShellPageState();
}

class _PluginShellPageState extends State<PluginShellPage> {
  late Future<List<Map<String, dynamic>>> _navFuture;
  int _index = 0;
  List<Map<String, dynamic>> _nav = const [];

  // 每个导航子页独立缓存/加载态（对齐 anime_list：目标页未就绪时整块替换，不残留旧内容）
  List<List<dynamic>?> _pages = const [];
  List<bool> _loading = const [];
  List<String?> _errors = const [];
  int _reqToken = 0;

  @override
  void initState() {
    super.initState();
    _navFuture = widget.plugin.nav().then((nav) {
      _nav = nav;
      int start = 0;
      if (widget.initialPageKey != null) {
        final found = nav.indexWhere(
          (n) => n['key'] == widget.initialPageKey,
        );
        if (found >= 0) start = found;
      }
      _index = start;
      _pages = List<List<dynamic>?>.filled(nav.length, null);
      _loading = List<bool>.filled(nav.length, false);
      _errors = List<String?>.filled(nav.length, null);
      if (_nav.isNotEmpty) _loadIndex(start);
      return nav;
    });
  }

  Future<void> _loadIndex(int index) async {
    if (index < 0 || index >= _nav.length) return;
    if (_pages[index] != null || _loading[index]) return;
    final token = ++_reqToken;
    setState(() {
      _loading[index] = true;
      _errors[index] = null;
    });
    try {
      final modules =
          await widget.plugin.page(_nav[index]['key']?.toString() ?? '');
      if (!mounted || token != _reqToken) return;
      setState(() {
        _pages[index] = modules;
        _loading[index] = false;
      });
    } catch (e) {
      if (!mounted || token != _reqToken) return;
      setState(() {
        _loading[index] = false;
        _errors[index] = '$e';
      });
    }
  }

  void _select(int index) {
    if (index < 0 || index >= _nav.length || index == _index) return;
    setState(() {
      _index = index;
      _errors[index] = null;
    });
    _loadIndex(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbar(title: Text(widget.plugin.name)),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _navFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: PolygonRefreshIndicator(size: 24));
          }
          if (_nav.isEmpty) {
            return const SizedBox.shrink();
          }
          return Column(
            children: [
              if (_nav.length > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _CapsuleBar(
                      keys: _nav
                          .map((n) => n['key']?.toString() ?? '')
                          .toList(),
                      titles: _nav
                          .map((n) => n['title']?.toString() ?? '')
                          .toList(),
                      icons: _nav
                          .map((n) => n['icon']?.toString() ?? '')
                          .toList(),
                      selected: _index < _nav.length
                          ? (_nav[_index]['key']?.toString() ?? '')
                          : '',
                      onChanged: _select,
                    ),
                  ),
                ),
              Expanded(child: _buildContent()),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    final nav = _nav[_index];
    final key = nav['key']?.toString() ?? '';
    final error = _index < _errors.length ? _errors[_index] : null;
    final data = _index < _pages.length ? _pages[_index] : null;
    if (error != null) {
      return _PluginRetry(
        message: error,
        onRetry: () => _loadIndex(_index),
      );
    }
    if (data == null) {
      return const Center(child: PolygonRefreshIndicator(size: 24));
    }
    // 同一插件的多个导航页即使渲染相同类型（如多个板块）也要按 key 重建状态
    return KeyedSubtree(
      key: ValueKey(key),
      child: _contentOrBoard(widget.plugin, data),
    );
  }
}

/// 内容加载失败占位（可重试，对齐 anime_list 的错误态）
class _PluginRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _PluginRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_outlined, size: 40, color: cs.onSurfaceVariant),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 12),
          Button.filled(onPressed: onRetry, child: Text(t.retry)),
        ],
      ),
    );
  }
}

IconData _navIcon(String name) => switch (name) {
  'home' => Icons.home_outlined,
  'star' => Icons.star_outline,
  'person' => Icons.person_outline,
  'settings' => Icons.settings_outlined,
  'search' => Icons.search,
  'check' => Icons.check_circle_outline,
  'list' => Icons.list_alt_outlined,
  'rank' => Icons.leaderboard_outlined,
  'folder' => Icons.folder_outlined,
  'cloud' => Icons.cloud_outlined,
  'heart' => Icons.favorite_outline,
  'more' => Icons.more_horiz,
  _ => Icons.widgets_outlined,
};

/// 签到管理详情页：总开关 + 各插件签到卡（一键签到在此也可触发）
class PluginSignManagerPage extends StatefulWidget {
  const PluginSignManagerPage({super.key});

  @override
  State<PluginSignManagerPage> createState() => _PluginSignManagerPageState();
}

class _PluginSignManagerPageState extends State<PluginSignManagerPage> {
  final Set<String> _busy = {};

  List<MePagePlugin> _signable() {
    final manager = MePagePluginManager();
    return manager
        .all()
        .where(
          (p) =>
              manager.isEnabled(p.key) &&
              p.signinAvailable,
        )
        .toList();
  }

  Future<void> _runOne(MePagePlugin p) async {
    setState(() => _busy.add(p.key));
    await MePagePluginManager().runSignin(p);
    if (mounted) setState(() => _busy.remove(p.key));
  }

  Future<void> _runAll() async {
    await MePagePluginManager().runCollectiveSignin();
    if (mounted) setState(() {});
    final all = _signable();
    final done = all.where((p) => p.signedToday.isNotEmpty).length;
    App.rootContext.showMessage(
      message: done >= all.length
          ? t.signAllSuccess(success: done)
          : t.noPluginToSign,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final manager = MePagePluginManager();
    final plugins = _signable();
    return PopUpWidgetScaffold(
      title: t.signInManager,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Material(
            color: cs.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: cs.outlineVariant, width: 0.6),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          t.signInManager,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 34,
                        child: Button.filled(
                          onPressed: _runAll,
                          child: Text(t.signAll),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          t.autoSignAtStart,
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      CustomSwitch(
                        value: manager.autoSigninMaster,
                        onChanged: (v) {
                          appdata.implicitData['meAutoSignin'] = v;
                          appdata.writeImplicitData();
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (plugins.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  t.noMePagePlugin,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            )
          else
            for (final p in plugins)
              _SignCard(
                plugin: p,
                busy: _busy.contains(p.key),
                onSign: () => _runOne(p),
                onAutoChanged: () {
                  if (mounted) setState(() {});
                },
              ),
        ],
      ),
    );
  }
}

class _SignCard extends StatelessWidget {
  const _SignCard({
    required this.plugin,
    required this.busy,
    required this.onSign,
    required this.onAutoChanged,
  });

  final MePagePlugin plugin;
  final bool busy;
  final VoidCallback onSign;
  final VoidCallback onAutoChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final signed = plugin.signedToday.isNotEmpty;
    final logged = plugin.isLogged;
    final lastSign = plugin.data['lastSign'];
    final lastError = lastSign is Map && lastSign['ok'] != true
        ? (lastSign['message']?.toString() ?? '')
        : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: cs.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cs.outlineVariant, width: 0.6),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.extension_outlined, color: cs.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      plugin.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (signed)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 18, color: cs.primary),
                        const SizedBox(width: 4),
                        Text(
                          t.signedAlready,
                          style: TextStyle(fontSize: 12, color: cs.primary),
                        ),
                      ],
                    )
                  else
                    SizedBox(
                      height: 32,
                      child: Button.filled(
                        isLoading: busy,
                        onPressed: logged ? onSign : () {},
                        child: Text(t.signAll),
                      ),
                    ),
                ],
              ),
              if (!logged)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    t.needLoginFirst,
                    style: TextStyle(fontSize: 12, color: cs.error),
                  ),
                ),
              if (lastError.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    lastError,
                    style: TextStyle(fontSize: 12, color: cs.error),
                  ),
                ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'v${plugin.version}',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  CustomSwitch(
                    value: plugin.isAutoSign,
                    onChanged: (v) {
                      plugin.setAutoSign(v);
                      onAutoChanged();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
Map<String, dynamic> _asMap2(dynamic v) {
  if (v is Map) {
    return v.map((k, val) => MapEntry(k.toString(), val));
  }
  return <String, dynamic>{};
}

Widget _genericPluginImage(
  String url, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
}) {
  return AnimatedImage(
    image: CachedImageProvider(url, sourceKey: 'me_plugin'),
    width: width,
    height: height,
    fit: fit,
  );
}

/// 站点图片 provider：headers/sourceKey 取插件声明，与预览/列表同一缓存 key
CachedImageProvider _siteProvider(String url, {required MePagePlugin plugin}) {
  final referer = plugin.referer;
  return CachedImageProvider(
    url,
    headers: referer == null || referer.isEmpty ? null : {'referer': referer},
    sourceKey: plugin.key,
  );
}

/// 站点图片：走项目缓存图片组件
Widget _siteImage(
  String url, {
  required MePagePlugin plugin,
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
}) {
  return AnimatedImage(
    image: _siteProvider(url, plugin: plugin),
    width: width,
    height: height,
    fit: fit,
  );
}

/// 若页面内容本身就是 board 模块则直接渲染板块内容
Widget _contentOrBoard(MePagePlugin plugin, List<dynamic> modules) {
  for (final m in modules) {
    if (_asMap2(m)['type'] == 'board') {
      return PluginBoardContent(plugin: plugin);
    }
  }
  return _PluginModulesList(plugin: plugin, modules: modules);
}

/// 磨砂玻璃条（样式对齐 anime_list 分页条：BlurEffect + 半透明 surface，直边无圆角）
class _GlassBar extends StatelessWidget {
  final Widget child;

  const _GlassBar({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return BlurEffect(
      blur: 10,
      child: Container(
        decoration: BoxDecoration(color: cs.surface.toOpacity(0.85)),
        child: child,
      ),
    );
  }
}

/// 论坛列表条目卡片：作者行 + 标题 + 条目信息 + 图片(可点击预览) + 辅助信息
class _ForumBoardRow extends StatelessWidget {
  final MePagePlugin plugin;
  final Map<String, dynamic> item;

  const _ForumBoardRow({required this.plugin, required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = item['title']?.toString() ?? '';
    final name = item['name']?.toString() ?? item['author']?.toString() ?? '';
    final infoLine =
        item['infoLine']?.toString() ?? item['meta']?.toString() ?? '';
    final summary =
        item['summary']?.toString() ?? item['subtitle']?.toString() ?? '';
    final avatar =
        item['avatarUrl']?.toString() ?? item['avatar']?.toString() ?? '';
    final views = item['views']?.toString() ?? '';
    final replies = item['replies']?.toString() ?? '';
    final images = <String>[];
    final imgs = item['images'];
    if (imgs is List) images.addAll(imgs.map((e) => e.toString()));

    // Hero tag 必须用稳定值：优先顶层 tid，其次 params.tid，最后条目对象身份
    final tidObj = item['tid'] ?? _asMap2(item['params'])['tid'];
    final heroBase =
        'forum_${plugin.key}_${(tidObj?.toString().isNotEmpty ?? false) ? tidObj.toString() : identityHashCode(item)}';
    String heroTagFor(int i) => '${heroBase}_$i';


    Widget avatarWidget;
    if (avatar.isNotEmpty) {
      avatarWidget = ClipOval(
        child: _siteImage(avatar, width: 40, height: 40, plugin: plugin),
      );
    } else {
      avatarWidget = CircleAvatar(
        radius: 20,
        backgroundColor: cs.surfaceContainerHighest,
        child: Icon(
          Icons.person_outline,
          size: 20,
          color: cs.onSurfaceVariant,
        ),
      );
    }

    // 图片预览：复用被点击的 provider（同 headers/sourceKey，缓存命中），Hero 与列表 tile 同 tag
    void preview(int index) {
      if (images.isEmpty) return;
      final url = images[index];
      BangumiWidget.showImagePreview(
        context: context,
        url: url,
        title: title.isEmpty ? plugin.name : title,
        imageProvider: _siteProvider(url, plugin: plugin),
        heroTag: heroTagFor(index),
      );
    }

    return Material(
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant, width: 0.6),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          final page = item['page']?.toString() ?? 'thread';
          final params = item['params'] is Map
              ? _asMap2(item['params'])
              : <String, dynamic>{};
          if (item['url'] != null) params['url'] = item['url'].toString();
          if (page == 'thread') params['tid'] ??= item['tid'];
          _pushPluginPage(context, plugin, page, params, item: item);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  avatarWidget,
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (infoLine.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            infoLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (summary.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  summary,
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
              ],
              if (images.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: images.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (context, i) {
                      final heroTag = heroTagFor(i);
                      return GestureDetector(
                        onTap: () => preview(i),
                        child: Hero(
                          tag: heroTag,
                          flightShuttleBuilder: (flightContext, animation,
                              direction, fromContext, toContext) {
                            return direction == HeroFlightDirection.pop
                                ? (fromContext.widget as Hero).child
                                : (toContext.widget as Hero).child;
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _siteImage(
                              images[i],
                              width: 130,
                              height: 100,
                              plugin: plugin,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              if (views.isNotEmpty || replies.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (views.isNotEmpty) ...[
                      Icon(Icons.visibility_outlined,
                          size: 13, color: cs.onSurfaceVariant),
                      const SizedBox(width: 3),
                      Text(
                        views,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (replies.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.mode_comment_outlined,
                          size: 13, color: cs.onSurfaceVariant),
                      const SizedBox(width: 3),
                      Text(
                        replies,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
/// 板块内容（可内联进插件页，也可放进弹层页）：
/// 分类 Tab + 列表 + 页码跳转
class PluginBoardContent extends StatefulWidget {
  final MePagePlugin plugin;

  const PluginBoardContent({super.key, required this.plugin});

  @override
  State<PluginBoardContent> createState() => _PluginBoardContentState();
}

class _PluginBoardContentState extends State<PluginBoardContent> {
  List<Map<String, dynamic>> _tabs = [];
  String _listPage = 'boardList';
  int _index = 0;
  bool _metaLoaded = false;
  int _page = 1;
  int _totalPages = 1;
  List<Map<String, dynamic>> _rows = const [];
  String? _error;
  int _reqToken = 0;

  // 分类缓存：tabKey -> (page -> rows)，页码/总数按分类记住（对齐 anime_list）
  final Map<String, Map<int, List<Map<String, dynamic>>>> _cache = {};
  final Map<String, int> _tabPage = {};
  final Map<String, int> _tabTotal = {};

  final ScrollController _scroll = ScrollController();

  // 分页 / 连续滑动两种模式（连续 = 滚动到末尾自动加载下一页，对齐 anime_list 双模式）
  bool _continuous = false;
  bool _appending = false;
  List<Map<String, dynamic>> _merged = const [];

  String get _tabKey => _index < _tabs.length
      ? (_tabs[_index]['key']?.toString() ?? '')
      : '';

  String get _modeSettingKey => 'mePluginListMode_${widget.plugin.key}';

  @override
  void initState() {
    super.initState();
    _continuous = appdata.settings[_modeSettingKey] == true;
    _loadMeta();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadMeta() async {
    final modules = await widget.plugin.page('board');
    if (!mounted) return;
    for (final m in modules) {
      final mm = _asMap2(m);
      if (mm['type'] != 'board') continue;
      final raw = mm['tabs'];
      if (raw is List) _tabs = raw.map((e) => _asMap2(e)).toList();
      _listPage = mm['page']?.toString() ?? 'boardList';
    }
    setState(() {
      _metaLoaded = true;
      _index = 0;
    });
    if (_tabs.isNotEmpty) _go(_tabPage[_tabKey] ?? 1);
  }

  Future<void> _fetch(String tabKey, int page) async {
    final token = ++_reqToken;
    // 立即清空旧内容并进入加载态（anime_list 行为：目标页未就绪时不留旧页）
    setState(() {
      _error = null;
      _page = page;
      _rows = const [];
      _merged = const [];
    });
    try {
      final parsed = _parseBoard(
        await widget.plugin.page(
          _listPage,
          {'tab': tabKey, 'page': page},
        ),
        page,
      );
      if (!mounted || token != _reqToken) return;
      (_cache[tabKey] ??= {})[parsed.current] = parsed.rows;
      _tabPage[tabKey] = parsed.current;
      _tabTotal[tabKey] = parsed.total;
      if (_tabKey != tabKey) return;
      setState(() {
        _page = parsed.current;
        _totalPages = parsed.total;
        if (_continuous) {
          _merged = _mergedOf(tabKey);
        } else {
          _rows = parsed.rows;
        }
      });
      if (_continuous) _scheduleFetchMore();
    } catch (e) {
      if (!mounted || token != _reqToken) return;
      if (_tabKey == tabKey) {
        setState(() => _error = '$e');
      }
    }
  }

  ({List<Map<String, dynamic>> rows, int total, int current}) _parseBoard(
    List<dynamic> modules,
    int page,
  ) {
    var rows = <Map<String, dynamic>>[];
    var total = 1;
    var current = page;
    for (final m in modules) {
      final mm = _asMap2(m);
      if (mm['type'] != 'boardPage') continue;
      total = _asInt(mm['totalPages'], total);
      current = _asInt(mm['page'], page);
      final raw = mm['items'];
      if (raw is List) {
        rows = raw.map((e) => _asMap2(e)).toList();
      }
    }
    if (total < 1) total = 1;
    return (rows: rows, total: total, current: current);
  }

  static int _asInt(dynamic v, int fallback) {
    final n = int.tryParse('$v');
    return n == null || n < 1 ? fallback : n;
  }

  /// 切到某页：命中缓存直接显示，否则清空并重新拉取（分页模式）
  void _go(int page) {
    if (page < 1) return;
    final key = _tabKey;
    if (_continuous) {
      // 连续模式只从第 1 页顺序累积
      if (page == 1 && (_cache[key]?[1] == null)) {
        _cache.remove(key);
        _fetch(key, 1);
      }
      return;
    }
    final cached = _cache[key]?[page];
    if (cached != null) {
      setState(() {
        _rows = cached;
        _page = page;
        _error = null;
        _totalPages = _tabTotal[key] ?? _totalPages;
      });
      return;
    }
    _fetch(key, page);
  }

  void _switchTab(int i) {
    if (_index == i) return;
    setState(() {
      _index = i;
      _error = null;
    });
    _enterCurrentTab();
  }

  void _enterCurrentTab() {
    if (!_continuous) {
      final p = _tabPage[_tabKey] ?? 1;
      _go(p);
      return;
    }
    final pages = _cache[_tabKey];
    if (pages == null || pages.isEmpty || pages[1] == null) {
      _fetch(_tabKey, 1);
    } else {
      setState(() {
        _merged = _mergedOf(_tabKey);
        _page = _nextMissing(_tabKey) - 1;
        _totalPages = _tabTotal[_tabKey] ?? _totalPages;
      });
      _scheduleFetchMore();
    }
  }

  List<Map<String, dynamic>> _mergedOf(String tabKey) {
    final pages = _cache[tabKey];
    final out = <Map<String, dynamic>>[];
    var i = 1;
    while (pages != null) {
      final pageRows = pages[i];
      if (pageRows == null) break;
      out.addAll(pageRows);
      i++;
    }
    return out;
  }

  int _nextMissing(String tabKey) {
    final pages = _cache[tabKey];
    var i = 1;
    while (pages?[i] != null) {
      i++;
    }
    return i;
  }

  bool get _hasMore {
    final total = _tabTotal[_tabKey];
    final next = _nextMissing(_tabKey);
    return total == null || next <= total;
  }

  void _scheduleFetchMore() {
    Future.microtask(() {
      if (mounted) _fetchMore();
    });
  }

  /// 连续模式：滚动到末尾时顺序加载下一页并累积
  Future<void> _fetchMore() async {
    if (!_continuous || _appending || _error != null) return;
    final key = _tabKey;
    final pages = _cache[key];
    if (pages == null || pages.isEmpty || pages[1] == null) {
      await _fetch(key, 1);
      return;
    }
    final next = _nextMissing(key);
    if (!_hasMore) return;
    if (pages[next] != null) return;
    final token = _reqToken;
    _appending = true;
    setState(() {});
    try {
      final parsed = _parseBoard(
        await widget.plugin.page(
          _listPage,
          {'tab': key, 'page': next},
        ),
        next,
      );
      if (!mounted || token != _reqToken) {
        _appending = false;
        return;
      }
      (_cache[key] ??= {})[parsed.current] = parsed.rows;
      _tabTotal[key] = parsed.total;
      if (_tabKey == key) {
        setState(() {
          _totalPages = parsed.total;
          _merged = _mergedOf(key);
        });
      }
    } catch (e) {
      if (!mounted || token != _reqToken) {
        _appending = false;
        return;
      }
      if (_tabKey == key) {
        setState(() => _error = '$e');
      }
    } finally {
      if (mounted) {
        if (token == _reqToken) {
          setState(() => _appending = false);
        } else {
          _appending = false;
        }
      }
    }
  }

  void _retryContinuous() {
    setState(() => _error = null);
    _scheduleFetchMore();
  }

  void _toggleMode() {
    setState(() => _continuous = !_continuous);
    appdata.settings[_modeSettingKey] = _continuous;
    appdata.saveData();
    if (_scroll.hasClients) _scroll.jumpTo(0);
    if (!_continuous) {
      // 回到分页：从该分类上次停留页展示
      final p = _tabPage[_tabKey] ?? 1;
      _go(p);
    } else {
      _enterCurrentTab();
    }
  }

  void _refreshList() {
    final key = _tabKey;
    _cache.remove(key);
    _tabPage.remove(key);
    if (_scroll.hasClients) _scroll.jumpTo(0);
    if (_continuous) {
      _fetch(key, 1);
    } else {
      _page = 1;
      _go(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_metaLoaded) {
      return const Center(child: PolygonRefreshIndicator(size: 24));
    }
    final cs = Theme.of(context).colorScheme;
    // 留白放在滚动内容自身（anime_list 同款）：网格铺满，行可滚到玻璃条下方产生磨砂
    return Stack(
      children: [
        Positioned.fill(child: _buildList()),
        if (_tabs.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: _GlassBar(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _CapsuleBar(
                    keys: _tabs
                        .map((t) => t['key']?.toString() ?? '')
                        .toList(),
                    titles: _tabs
                        .map((t) => t['title']?.toString() ?? '')
                        .toList(),
                    selected: _index < _tabs.length
                        ? (_tabs[_index]['key']?.toString() ?? '')
                        : '',
                    onChanged: _switchTab,
                  ),
                ),
              ),
            ),
          ),
        if (!_continuous)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _GlassBar(
              child: _ForumPager(
                page: _page,
                totalPages: _totalPages,
                busy: _isBusy,
                onJump: _go,
              ),
            ),
          ),
        Positioned(
          right: 8,
          bottom: _continuous ? 16 : 80,
          child: FloatingMenu(
            controller: _scroll,
            child: [
              [
                SpeedDialChild(
                  child: const Icon(Icons.refresh),
                  backgroundColor: cs.primaryContainer,
                  foregroundColor: cs.onPrimaryContainer,
                  onTap: _refreshList,
                ),
              ],
              [
                SpeedDialChild(
                  child: Icon(
                    _continuous
                        ? Icons.view_cozy_outlined
                        : Icons.menu,
                  ),
                  backgroundColor: cs.primaryContainer,
                  foregroundColor: cs.onPrimaryContainer,
                  onTap: _toggleMode,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  bool get _isBusy {
    if (_error != null) return false;
    if (_continuous) {
      // 连续模式：只要还没拿到第 1 页即为加载中
      return _cache[_tabKey]?[1] == null;
    }
    // 分页：当前页无缓存即视为加载中（清空后第一次 build 进入 loader）
    return _cache[_tabKey]?[_page] == null;
  }

  Widget _buildList() {
    final cs = Theme.of(context).colorScheme;
    final edge = EdgeInsets.fromLTRB(
      8,
      _tabs.isNotEmpty ? 62 : 8,
      8,
      _continuous ? 24 : 66,
    );
    if (_error != null) {
      return Padding(
        padding: edge,
        child: _PluginRetry(
          message: _error!,
          onRetry: _continuous ? _retryContinuous : () => _go(_page),
        ),
      );
    }
    if (_isBusy) {
      return Padding(
        padding: edge,
        child: const Center(child: PolygonRefreshIndicator(size: 24)),
      );
    }
    final visible = _continuous ? _merged : _rows;
    if (visible.isEmpty) {
      return Padding(
        padding: edge,
        child: Center(
          child: Text(
            t.noPluginToSign,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ),
      );
    }
    // 连续模式底部追加载器行
    final showTail = _continuous && _appending;
    return ListView.separated(
      controller: _scroll,
      padding: edge,
      itemCount: visible.length + (showTail ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        if (i >= visible.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: PolygonRefreshIndicator(size: 22),
            ),
          );
        }
        // 滑到末尾触发下一页加载（anime_list 连续模式同款）
        if (_continuous && i == visible.length - 1 && _hasMore) {
          _scheduleFetchMore();
        }
        return _ForumBoardRow(plugin: widget.plugin, item: visible[i]);
      },
    );
  }
}

/// 板块弹层页（供 board 模块入口使用）
class PluginBoardPage extends StatelessWidget {
  final MePagePlugin plugin;
  final Map<String, dynamic> meta;

  const PluginBoardPage({super.key, required this.plugin, required this.meta});

  @override
  Widget build(BuildContext context) {
    return PopUpWidgetScaffold(
      title: meta['title']?.toString() ?? '',
      body: PluginBoardContent(plugin: plugin),
    );
  }
}

class _ThreadPost {
  final int pid;
  final int floor;
  final String author;
  final String avatarUrl;
  final String time;
  final String content;
  final List<Map<String, dynamic>> blocks;
  final List<String> images;

  _ThreadPost({
    this.pid = 0,
    this.floor = 0,
    this.author = '',
    this.avatarUrl = '',
    this.time = '',
    this.content = '',
    List<Map<String, dynamic>>? blocks,
    this.images = const [],
  }) : blocks = blocks ?? const [];
}

/// 帖子详情页：帖子头部 + 楼层卡片（可加载更多楼层/分页）
class PluginThreadPage extends StatefulWidget {
  final MePagePlugin plugin;
  final Map<String, dynamic> params;

  /// 来源列表行的元信息（标题/作者/时间/浏览/回复/头像），用于头部展示
  final Map<String, dynamic>? row;

  const PluginThreadPage({
    super.key,
    required this.plugin,
    required this.params,
    this.row,
  });

  @override
  State<PluginThreadPage> createState() => _PluginThreadPageState();
}

class _PluginThreadPageState extends State<PluginThreadPage> {
  String _title = '';
  final List<_ThreadPost> _posts = [];
  bool _loading = false;
  bool _hasMore = true;
  String? _error;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _title = widget.row?['title']?.toString() ?? '';
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = Map<String, dynamic>.from(widget.params)..['page'] = _page;
      final modules = await widget.plugin.page('thread', p);
      if (!mounted) return;
      var hasMore = false;
      final parsed = <_ThreadPost>[];
      for (final m in modules) {
        final map = _asMap2(m);
        if (map['type'] != 'threadPage') continue;
        if (_title.isEmpty) _title = map['title']?.toString() ?? '';
        hasMore = map['hasMore'] == true;
        final posts = map['posts'];
        if (posts is List) {
          for (final b in posts) {
            final bm = _asMap2(b);
            final images = <String>[];
            final imgs = bm['images'];
            if (imgs is List) images.addAll(imgs.map((e) => e.toString()));
            final blocks = <Map<String, dynamic>>[];
            final rawBlocks = bm['blocks'];
            if (rawBlocks is List) {
              for (final rb in rawBlocks) {
                final rbm = _asMap2(rb);
                if (rbm.isEmpty) continue;
                blocks.add(rbm);
              }
            }
            parsed.add(
              _ThreadPost(
                pid: _asInt(bm['pid'], 0),
                floor: _asInt(bm['floor'], 0),
                author: bm['author']?.toString() ?? '',
                avatarUrl: bm['avatarUrl']?.toString() ?? '',
                time: bm['time']?.toString() ?? '',
                content: bm['content']?.toString() ?? '',
                blocks: blocks,
                images: images,
              ),
            );
          }
        }
      }
      setState(() {
        _posts.addAll(parsed);
        _page++;
        _hasMore = hasMore && parsed.isNotEmpty;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  double get _topInset => MediaQuery.paddingOf(context).top + 56;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(top: _topInset + 4, bottom: 8),
              child: _body(cs),
            ),
          ),
          Positioned(top: 0, left: 0, right: 0, child: _topBar(cs)),
        ],
      ),
    );
  }

  Widget _topBar(ColorScheme cs) {
    return Appbar(
      title: Text(
        _title.isEmpty ? widget.plugin.name : _title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _body(ColorScheme cs) {
    if (_error != null && _posts.isEmpty) {
      return _PluginRetry(message: _error!, onRetry: _load);
    }
    if (_loading && _posts.isEmpty) {
      return const Center(child: PolygonRefreshIndicator(size: 24));
    }
    final children = <Widget>[
      _header(cs),
      if (_posts.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Center(
            child: Text(
              t.noPluginToSign,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ),
        )
      else
        for (var i = 0; i < _posts.length; i++) ...[
          _floorCard(context, cs, _posts[i]),
          const SizedBox(height: 10),
        ],
    ];
    if (_hasMore) {
      children.add(
        Center(
          child: TextButton.icon(
            onPressed: _loading ? null : _load,
            icon: _loading
                ? const PolygonRefreshIndicator(size: 14)
                : const Icon(Icons.expand_more),
            label: Text(t.more),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      children: children,
    );
  }

  /// 帖子头部：标题 + 标签 + 作者/浏览/回复元信息
  Widget _header(ColorScheme cs) {
    final row = widget.row;
    final tag = row?['tag']?.toString() ?? '';
    final name = row?['name']?.toString() ?? row?['author']?.toString() ?? '';
    final avatar = row?['avatarUrl']?.toString() ?? '';
    final time = row?['time']?.toString() ?? '';
    final infoLine = row?['infoLine']?.toString() ?? '';
    final views = row?['views']?.toString() ?? '';
    final replies = row?['replies']?.toString() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _title.isEmpty ? (row?['title']?.toString() ?? '') : _title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1.3,
            color: cs.onSurface,
          ),
        ),
        if (tag.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: cs.secondaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              tag,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSecondaryContainer,
              ),
            ),
          ),
        ],
        if (name.isNotEmpty || views.isNotEmpty || replies.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              if (avatar.isNotEmpty)
                ClipOval(
                  child: _siteImage(
                    avatar,
                    width: 36,
                    height: 36,
                    plugin: widget.plugin,
                  ),
                )
              else
                CircleAvatar(
                  radius: 18,
                  backgroundColor: cs.surfaceContainerHighest,
                  child: Icon(
                    Icons.person_outline,
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (name.isNotEmpty)
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (time.isNotEmpty || infoLine.isNotEmpty)
                      Text(
                        infoLine.isNotEmpty ? infoLine : time,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (views.isNotEmpty)
                _stat(cs, Icons.remove_red_eye_outlined, views),
              if (replies.isNotEmpty) ...[
                const SizedBox(width: 14),
                _stat(cs, Icons.chat_bubble_outline, replies),
              ],
            ],
          ),
        ],
        const SizedBox(height: 12),
        Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _stat(ColorScheme cs, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: cs.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  /// 单楼层卡片：头像/作者/时间/楼层 + 富文本内容 + 图片预览
  Widget _floorCard(BuildContext context, ColorScheme cs, _ThreadPost post) {
    final isFirst = _posts.indexOf(post) == 0;
    return Material(
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant, width: 0.6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _floorHeader(context, cs, post, isFirst),
            const SizedBox(height: 10),
            _postContent(context, cs, post),
            if (post.images.isNotEmpty) ...[
              const SizedBox(height: 10),
              _postImages(context, cs, post),
            ],
          ],
        ),
      ),
    );
  }

  Widget _floorHeader(
    BuildContext context,
    ColorScheme cs,
    _ThreadPost post,
    bool isFirst,
  ) {
    return Row(
      children: [
        if (post.avatarUrl.isNotEmpty)
          ClipOval(
            child: _siteImage(
              post.avatarUrl,
              width: 38,
              height: 38,
              plugin: widget.plugin,
            ),
          )
        else
          CircleAvatar(
            radius: 19,
            backgroundColor: cs.surfaceContainerHighest,
            child: Icon(
              Icons.person_outline,
              size: 19,
              color: cs.onSurfaceVariant,
            ),
          ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      post.author.isEmpty ? t.unknown : post.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (isFirst)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: cs.tertiaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '楼主',
                        style: TextStyle(
                          fontSize: 10,
                          color: cs.onTertiaryContainer,
                        ),
                      ),
                    ),
                ],
              ),
              if (post.time.isNotEmpty)
                Text(
                  post.time,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        if (post.floor > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '#${post.floor}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.onPrimaryContainer,
              ),
            ),
          ),
      ],
    );
  }

  Widget _postContent(
    BuildContext context,
    ColorScheme cs,
    _ThreadPost post,
  ) {
    if (post.blocks.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final b in post.blocks) ...[
            if (b['type'] == 'quote')
              _quoteBlock(cs, b['text']?.toString() ?? '')
            else if (b['text']?.toString().trim().isNotEmpty ?? false)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _plainText(b['text'].toString()),
              ),
          ],
        ],
      );
    }
    if (post.content.trim().isNotEmpty) {
      return _plainText(post.content);
    }
    return const SizedBox.shrink();
  }

  Widget _plainText(String text) {
    return _richText(
      text,
      fontSize: 14.5,
      height: 1.55,
      color: Theme.of(context).colorScheme.onSurface,
    );
  }

  /// 正文富文本：把 URL 变成可点击链接（原地址等），其余保留可选文本样式
  Widget _richText(
    String text, {
    double fontSize = 14.5,
    double height = 1.55,
    required Color color,
  }) {
    final cs = Theme.of(context).colorScheme;
    final urlRe = RegExp(r"https?://[^\s<>']+");
    final spans = <TextSpan>[];
    var pos = 0;
    for (final m in urlRe.allMatches(text)) {
      if (m.start > pos) {
        spans.add(TextSpan(text: text.substring(pos, m.start)));
      }
      var url = m.group(0)!;
      while (url.isNotEmpty &&
          RegExp(r'[.,;:)\]}]$').hasMatch(url) &&
          !url.endsWith('://')) {
        url = url.substring(0, url.length - 1);
      }
      spans.add(
        TextSpan(
          text: url,
          style: TextStyle(color: cs.primary),
          recognizer: TapGestureRecognizer()
            ..onTap = () => launchUrlString(url),
        ),
      );
      pos = m.start + m.group(0)!.length;
    }
    if (pos < text.length) {
      spans.add(TextSpan(text: text.substring(pos)));
    }
    return Text.rich(
      TextSpan(
        style: TextStyle(fontSize: fontSize, height: height, color: color),
        children: spans,
      ),
    );
  }

  Widget _quoteBlock(ColorScheme cs, String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: cs.primary.withValues(alpha: 0.7), width: 3),
        ),
      ),
        child: _richText(
          text,
          fontSize: 13,
          height: 1.5,
          color: cs.onSurfaceVariant,
        ),
    );
  }

  Widget _postImages(
    BuildContext context,
    ColorScheme cs,
    _ThreadPost post,
  ) {
    final pid = post.pid == 0 ? post.floor : post.pid;
    void preview(int i) {
      final url = post.images[i];
      BangumiWidget.showImagePreview(
        context: context,
        url: url,
        title: _title,
        imageProvider: _siteProvider(url, plugin: widget.plugin),
        heroTag: 'thread_${widget.plugin.key}_${pid}_$i',
      );
    }

    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: post.images.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final heroTag = 'thread_${widget.plugin.key}_${pid}_$i';
          return GestureDetector(
            onTap: () => preview(i),
            child: Hero(
              tag: heroTag,
              flightShuttleBuilder: (flightContext, animation, direction,
                  fromContext, toContext) {
                return direction == HeroFlightDirection.pop
                    ? (fromContext.widget as Hero).child
                    : (toContext.widget as Hero).child;
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _siteImage(
                  post.images[i],
                  width: 150,
                  height: 110,
                  plugin: widget.plugin,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// anime 风格分页器（宽/窄屏两套，与番源列表一致）
class _ForumPager extends StatelessWidget {
  final int page;
  final int totalPages;
  final bool busy;
  final ValueChanged<int> onJump;

  const _ForumPager({
    required this.page,
    required this.totalPages,
    required this.busy,
    required this.onJump,
  });

  void _jump(BuildContext context) {
    String value = '';
    showDialog(
      context: App.rootContext,
      builder: (context) {
        return ContentDialog(
          title: t.jumpToPage,
          content: TextField(
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(labelText: t.page),
            onChanged: (v) => value = v,
          ).paddingHorizontal(16),
          actions: [
            Button.filled(
              onPressed: () {
                Navigator.of(context).pop();
                final p = int.tryParse(value);
                if (p == null || p <= 0 || p > totalPages) {
                  App.rootContext.showMessage(message: t.invalidPage);
                  return;
                }
                onJump(p);
              },
              child: Text(t.apply),
            ),
          ],
        );
      },
    );
  }

  Widget _pagePill(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: t.jumpToPage,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _jump(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.toOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(t.pagePM(p: '$page', m: '$totalPages')),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width <= 600;
    final prevBtn = _PagerIcon(
      icon: Icons.chevron_left,
      label: t.back,
      enabled: page > 1 && !busy,
      onTap: () => onJump(page - 1),
      onRepeat: () {
        if (page > 1 && !busy) onJump(page - 1);
      },
    );
    final nextBtn = _PagerIcon(
      icon: Icons.chevron_right,
      label: t.next,
      enabled: page < totalPages && !busy,
      onTap: () => onJump(page + 1),
      onRepeat: () {
        if (page < totalPages && !busy) onJump(page + 1);
      },
    );

    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _pagePill(context),
            Row(
              children: [
                prevBtn,
                const SizedBox(width: 12),
                nextBtn,
              ],
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(),
          Row(
            children: [
              _PagerIcon(
                icon: Icons.first_page,
                label: t.first,
                enabled: page > 1 && !busy,
                onTap: () => onJump(1),
              ),
              const SizedBox(width: 4),
              prevBtn,
              const SizedBox(width: 8),
              _pagePill(context),
              const SizedBox(width: 8),
              nextBtn,
              const SizedBox(width: 4),
              _PagerIcon(
                icon: Icons.last_page,
                label: t.last,
                enabled: page < totalPages && !busy,
                onTap: () => onJump(totalPages),
              ),
            ],
          ),
          const SizedBox(),
        ],
      ),
    );
  }
}

/// 分页图标按钮（支持长按连续触发）
class _PagerIcon extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback? onRepeat;

  const _PagerIcon({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.onRepeat,
  });

  @override
  State<_PagerIcon> createState() => _PagerIconState();
}

class _PagerIconState extends State<_PagerIcon> {
  Timer? _timer;

  void _start() {
    if (!widget.enabled) return;
    widget.onTap();
    _timer?.cancel();
    if (widget.onRepeat != null) {
      _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!widget.enabled || !mounted) {
          _timer?.cancel();
          return;
        }
        widget.onRepeat!();
      });
    }
  }

  void _end() {
    _timer?.cancel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: widget.label,
      child: GestureDetector(
        onLongPressStart: (_) => _start(),
        onLongPressEnd: (_) => _end(),
        onLongPressCancel: _end,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            width: 48,
            height: 48,
            child: InkWell(
              onTap: widget.enabled ? widget.onTap : null,
              borderRadius: BorderRadius.circular(16),
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed)) {
                  return colorScheme.primary.toOpacity(0.2);
                }
                if (states.contains(WidgetState.hovered)) {
                  return colorScheme.secondary.toOpacity(0.1);
                }
                return null;
              }),
              child: Center(
                child: Icon(
                  widget.icon,
                  color: widget.enabled
                      ? colorScheme.primary
                      : colorScheme.onSurface.toOpacity(0.3),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 项目风格分段胶囊切换条（settings/favorites 同款，可横向滚动）
class _CapsuleBar extends StatelessWidget {
  final List<String> keys;
  final List<String> titles;
  final List<String>? icons;
  final String selected;
  final ValueChanged<int> onChanged;

  const _CapsuleBar({
    required this.keys,
    required this.titles,
    required this.selected,
    required this.onChanged,
    this.icons,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.toOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < keys.length; i++)
              GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: selected == keys[i]
                        ? cs.surface
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: selected == keys[i]
                        ? [
                            BoxShadow(
                              color: Colors.black.toOpacity(0.08),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icons != null && icons![i].isNotEmpty) ...[
                        Icon(
                          _navIcon(icons![i]),
                          size: 13,
                          color: selected == keys[i]
                              ? cs.primary
                              : cs.onSurface.toOpacity(0.45),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        titles[i],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: selected == keys[i]
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: selected == keys[i]
                              ? cs.primary
                              : cs.onSurface.toOpacity(0.45),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
