import 'dart:async';

import 'package:kostori/components/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_qjs/flutter_qjs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
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
              child: Image.network(
                image,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.image_outlined, size: 18),
              ),
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
  Map<String, dynamic> params,
) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => name == 'thread'
          ? PluginThreadPage(plugin: plugin, params: params)
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
  final List<Future<List<dynamic>>> _pageFutures = [];
  List<Map<String, dynamic>> _nav = const [];

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
      if (_nav.isNotEmpty) _pageFutures.add(widget.plugin.page(_nav[_index]['key']));
      return nav;
    });
  }

  void _select(int index) {
    setState(() {
      _index = index;
      if (index >= _pageFutures.length) {
        _pageFutures.add(widget.plugin.page(_nav[index]['key'] ?? ''));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: Appbar(title: Text(widget.plugin.name)),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _navFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: PolygonRefreshIndicator());
          }
          if (_nav.isEmpty) {
            return const Center(child: Text(''));
          }
          // 单导航（如 xsijishe：只有一个板块）不再显示导航条，
          // 内容直接内联；多导航才显示项目分段风格切换条
          if (_nav.length == 1) {
            return FutureBuilder<List<dynamic>>(
              future: _index < _pageFutures.length
                  ? _pageFutures[_index]
                  : null,
              builder: (context, snap2) {
                if (snap2.connectionState != ConnectionState.done) {
                  return const Center(child: PolygonRefreshIndicator());
                }
                final modules = snap2.data ?? const [];
                return _contentOrBoard(widget.plugin, modules);
              },
            );
          }
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var i = 0; i < _nav.length; i++)
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _select(i),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: _index == i
                                ? cs.primaryContainer
                                : cs.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _navIcon(_nav[i]['icon'] ?? ''),
                                size: 15,
                                color: _index == i
                                    ? cs.onPrimaryContainer
                                    : cs.onSurfaceVariant,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _nav[i]['title'] ?? _nav[i]['key'] ?? '',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: _index == i
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: _index == i
                                      ? cs.onPrimaryContainer
                                      : cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<dynamic>>(
                  future: _index < _pageFutures.length
                      ? _pageFutures[_index]
                      : null,
                  builder: (context, snap2) {
                    if (snap2.connectionState != ConnectionState.done) {
                      return const Center(child: PolygonRefreshIndicator());
                    }
                    final modules = snap2.data ?? const [];
                    return _contentOrBoard(widget.plugin, modules);
                  },
                ),
              ),
            ],
          );
        },
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
                        child: busy
                            ? const SizedBox.square(
                                dimension: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(t.signAll),
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

/// 若页面内容本身就是 board 模块，则直接内联板块浏览（不再要求二次点击）
Widget _contentOrBoard(MePagePlugin plugin, List<dynamic> modules) {
  for (final m in modules) {
    if (_asMap2(m)['type'] == 'board') {
      return PluginBoardContent(plugin: plugin);
    }
  }
  return _PluginModulesList(plugin: plugin, modules: modules);
}

/// 论坛列表行卡片（封面/标题/标签/摘要/作者时间/浏览回复）
class _ForumBoardRow extends StatelessWidget {
  final MePagePlugin plugin;
  final Map<String, dynamic> item;

  const _ForumBoardRow({required this.plugin, required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = item['title']?.toString() ?? '';
    final summary =
        item['summary']?.toString() ?? item['subtitle']?.toString() ?? '';
    final tag = item['tag']?.toString() ?? '';
    final author = item['author']?.toString() ?? '';
    final time = item['time']?.toString() ?? '';
    final views = item['views']?.toString() ?? '';
    final replies = item['replies']?.toString() ?? '';
    final cover =
        item['cover']?.toString() ?? item['image']?.toString() ?? '';

    Widget thumb;
    if (cover.isNotEmpty) {
      thumb = ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          cover,
          width: 92,
          height: 92,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            width: 92,
            height: 92,
            color: cs.surfaceContainerHighest,
            child: const Icon(Icons.image_outlined),
          ),
        ),
      );
    } else {
      thumb = Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.article_outlined),
      );
    }

    Widget metaLine() {
      final parts = <String>[];
      if (tag.isNotEmpty) parts.add('[$tag]');
      if (author.isNotEmpty) parts.add(author);
      if (time.isNotEmpty) parts.add(time);
      return Text(
        parts.join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
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
          if (page == 'thread') {
            params['tid'] ??= item['tid'];
          }
          _pushPluginPage(context, plugin, page, params);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              thumb,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (summary.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    metaLine(),
                    if (views.isNotEmpty || replies.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
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
                      ),
                    ],
                  ],
                ),
              ),
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
  bool _loading = false;
  int _page = 1;
  int _totalPages = 1;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  @override
  void dispose() {
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
    if (_tabs.isNotEmpty) await _load(1);
  }

  Future<void> _load(int page) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _page = page;
    });
    final modules = await widget.plugin.page(
      _listPage,
      {'tab': _index < _tabs.length ? (_tabs[_index]['key'] ?? '') : '', 'page': page},
    );
    if (!mounted) return;
    var rows = <Map<String, dynamic>>[];
    var total = 1;
    var current = page;
    for (final m in modules) {
      final mm = _asMap2(m);
      if (mm['type'] != 'boardPage') continue;
      total = _asInt(mm['totalPages'], 1);
      current = _asInt(mm['page'], page);
      final raw = mm['items'];
      if (raw is List) {
        rows = raw.map((e) => _asMap2(e)).toList();
      }
    }
    setState(() {
      _rows = rows;
      _page = current;
      _totalPages = total < 1 ? 1 : total;
      _loading = false;
    });
  }

  static int _asInt(dynamic v, int fallback) {
    final n = int.tryParse('$v');
    return n == null || n < 1 ? fallback : n;
  }

  void _go(int page) {
    if (page < 1) return;
    _load(page);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_metaLoaded)
          const Expanded(child: Center(child: PolygonRefreshIndicator()))
        else ...[
          if (_tabs.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  for (var i = 0; i < _tabs.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          if (_index == i) return;
                          setState(() => _index = i);
                          _go(1);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _index == i
                                ? cs.secondaryContainer
                                : cs.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _tabs[i]['title']?.toString() ?? '',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _index == i
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: _index == i
                                  ? cs.onSecondaryContainer
                                  : cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: _loading && _rows.isEmpty
                ? const Center(child: PolygonRefreshIndicator())
                : _rows.isEmpty
                ? Center(
                    child: Text(
                      t.noPluginToSign,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: _rows.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) =>
                        _ForumBoardRow(plugin: widget.plugin, item: _rows[i]),
                  ),
          ),
          if (_metaLoaded)
            _ForumPager(
              page: _page,
              totalPages: _totalPages,
              busy: _loading,
              onJump: _go,
            ),
        ],
      ],
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
  final String author;
  final String time;
  final String content;
  final List<String> images;
  _ThreadPost(this.author, this.time, this.content, this.images);
}

/// 帖子详情页：主楼 + 楼层，可加载更多楼层
class PluginThreadPage extends StatefulWidget {
  final MePagePlugin plugin;
  final Map<String, dynamic> params;

  const PluginThreadPage({
    super.key,
    required this.plugin,
    required this.params,
  });

  @override
  State<PluginThreadPage> createState() => _PluginThreadPageState();
}

class _PluginThreadPageState extends State<PluginThreadPage> {
  String _title = '';
  final List<_ThreadPost> _posts = [];
  bool _loading = false;
  bool _hasMore = true;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() => _loading = true);
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
          final content = bm['content']?.toString() ?? '';
          final images = <String>[];
          final imgs = bm['images'];
          if (imgs is List) images.addAll(imgs.map((e) => e.toString()));
          parsed.add(
            _ThreadPost(
              bm['author']?.toString() ?? '',
              bm['time']?.toString() ?? '',
              content,
              images,
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
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: Appbar(title: Text(_title.isEmpty ? widget.plugin.name : _title)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (var i = 0; i < _posts.length; i++) ...[
            Material(
              color: cs.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: cs.outlineVariant, width: 0.6),
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _posts[i].author,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (_posts[i].time.isNotEmpty)
                          Text(
                            _posts[i].time,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    if (_posts[i].content.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(_posts[i].content),
                    ],
                    for (final url in _posts[i].images)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            url,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (_hasMore)
            Center(
              child: TextButton.icon(
                onPressed: _loading ? null : _load,
                icon: _loading
                    ? const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more),
                label: Text(t.more),
              ),
            ),
        ],
      ),
    );
  }
}

/// anime 风格分页器：首页 / 上一页(长按连续) / 页码胶囊(点跳页) / 下一页(长按连续) / 末页
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
              _PagerIcon(
                icon: Icons.chevron_left,
                label: t.back,
                enabled: page > 1 && !busy,
                onTap: () => onJump(page - 1),
                onRepeat: () {
                  if (page > 1 && !busy) onJump(page - 1);
                },
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: t.jumpToPage,
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _jump(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.toOpacity(
                          0.3,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(t.pagePM(p: '$page', m: '$totalPages')),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _PagerIcon(
                icon: Icons.chevron_right,
                label: t.next,
                enabled: page < totalPages && !busy,
                onTap: () => onJump(page + 1),
                onRepeat: () {
                  if (page < totalPages && !busy) onJump(page + 1);
                },
              ),
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