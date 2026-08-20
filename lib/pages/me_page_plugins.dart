import 'package:kostori/components/animated.dart';
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
      case 'button':
        return _PluginCard(child: _Button(m));
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
      case 'button':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: _Button(m),
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
        App.rootContext.showMessage(
          message: successText ?? (body.isEmpty ? t.success : body),
        );
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

/// 通用按钮：onTap 为 JS 回调
class _Button extends StatelessWidget {
  final Map<String, dynamic> m;

  const _Button(this.m);

  @override
  Widget build(BuildContext context) {
    final onTap = m['onTap'];
    return FilledButton.tonal(
      onPressed: onTap is JSInvokable
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

