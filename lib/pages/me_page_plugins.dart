import 'package:kostori/components/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_qjs/flutter_qjs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/foundation/app.dart';
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
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题 + 插件管理入口
            Row(
              children: [
                Expanded(
                  child: Text(
                    t.mePagePlugin,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _openManage,
                  icon: const Icon(Icons.settings_outlined, size: 16),
                  label: Text(t.manage),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (_cards.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  t.noMePagePlugin,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant.toOpacity(0.7),
                  ),
                ),
              )
            else
              ..._cards,
          ],
        ),
      ),
    );
  }

  /// 打开插件管理页
  void _openManage() {
    App.mainNavigatorKey?.currentContext?.to(
      () => Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(title: Text(t.mePagePlugin)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: const [PluginSettings()],
          ),
        ),
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
        final body = res['body']?.toString().trim() ?? '';
        final show = (successText == null || successText.isEmpty)
            ? (body.isEmpty ? t.success : body)
            : successText;
        App.rootContext.showMessage(message: show);
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
      builder: (_) => PluginSubPage(plugin: plugin, name: name, params: params),
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
      appBar: AppBar(title: Text(widget.plugin.titleOf(widget.name))),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              child: PolygonRefreshIndicator(),
            );
          }
          final modules = snap.data ?? const [];
          return _PluginModulesList(plugin: widget.plugin, modules: modules);
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
      appBar: AppBar(title: Text(widget.plugin.name)),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _navFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: PolygonRefreshIndicator());
          }
          if (_nav.isEmpty) {
            return const Center(child: Text(''));
          }
          return Column(
            children: [
              // 顶部导航（横向滚动）
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    for (var i = 0; i < _nav.length; i++) ...[
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _select(i),
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _index == i
                                ? cs.secondaryContainer
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _navIcon(_nav[i]['icon'] ?? ''),
                                size: 15,
                                color: _index == i
                                    ? cs.onSecondaryContainer
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
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<dynamic>>(
                  future: _index < _pageFutures.length
                      ? _pageFutures[_index]
                      : null,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: PolygonRefreshIndicator());
                    }
                    final modules = snap.data ?? const [];
                    return _PluginModulesList(
                      plugin: widget.plugin,
                      modules: modules,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: SizedBox(
        height: 44,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _nav.isEmpty
                  ? ''
                  : '${_index + 1}/${_nav.length} · ${_nav[_index < _nav.length ? _index : 0]['key'] ?? ''}',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
        ),
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
