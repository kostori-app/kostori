part of 'me_page_plugins.dart';

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
      case 'status':
        // 轻量数据：只展示“标签 + 数字”，不套厚重外壳
        return _PluginCard(child: _Status(m['items']));
      case 'config':
        // 手动配置项（uid 等）：持久化到插件 .data['configs'] 并注入 JS
        return _PluginCard(
          title: m['title']?.toString(),
          child: _ConfigFields(plugin: plugin, m: m),
        );
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
      case 'status':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: _Status(m['items']),
        );
      case 'config':
        return _ConfigFields(plugin: plugin, m: m);
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

/// 轻量数据状态：一行 `标签 数字`，可多个并用 Wrap 排布
class _Status extends StatelessWidget {
  final dynamic items;

  const _Status(this.items);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final raw = items is List ? items as List : const [];
    final parsed = raw
        .map((e) {
          final m = e is Map ? e.map((k, v) => MapEntry(k.toString(), v)) : <String, dynamic>{};
          return (
            label: (m['label'] ?? m['key'] ?? m['name'] ?? '').toString(),
            value: (m['value'] ?? m['text'] ?? '').toString(),
          );
        })
        .where((r) => r.value.isNotEmpty)
        .toList();
    if (parsed.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 20,
      runSpacing: 6,
      children: [
        for (final r in parsed)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (r.label.isNotEmpty) ...[
                Text(
                  r.label,
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
                const SizedBox(width: 5),
              ],
              Text(
                r.value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// 手动配置表单：字段持久化到插件 `.data['configs']`，保存后注入 JS 供读取
class _ConfigFields extends StatefulWidget {
  final MePagePlugin plugin;
  final Map<String, dynamic> m;

  const _ConfigFields({required this.plugin, required this.m});

  @override
  State<_ConfigFields> createState() => _ConfigFieldsState();
}

class _ConfigFieldsState extends State<_ConfigFields> {
  final Map<String, TextEditingController> _ctrls = {};
  bool _saving = false;

  List<Map<String, dynamic>> get _fields {
    final raw = widget.m['fields'] ?? widget.m['items'];
    final list = <Map<String, dynamic>>[];
    if (raw is List) {
      for (final f in raw) {
        final fm = f is Map ? f.map((k, v) => MapEntry(k.toString(), v)) : <String, dynamic>{};
        if ((fm['key'] ?? '').toString().isNotEmpty) list.add(fm);
      }
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    for (final f in _fields) {
      final key = f['key'].toString();
      _ctrls[key] = TextEditingController(
        text: widget.plugin.configs[key]?.toString() ?? '',
      );
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      for (final f in _fields) {
        final key = f['key'].toString();
        widget.plugin.setConfigValue(key, _ctrls[key]?.text ?? '');
      }
      App.rootContext.showMessage(message: t.saved);
      // 通知插件壳刷新当前页（status 等读取新配置后重拉）
      MePagePluginManager().touch();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_fields.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final f in _fields) ...[
          TextField(
            controller: _ctrls[f['key'].toString()],
            keyboardType: (f['kind']?.toString() ?? '') == 'number'
                ? TextInputType.number
                : TextInputType.text,
            decoration: InputDecoration(
              isDense: true,
              labelText: f['label']?.toString() ?? '',
              hintText: f['hint']?.toString(),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: Button.filled(
            isLoading: _saving,
            onPressed: _save,
            child: Text(widget.m['saveText']?.toString() ?? t.apply),
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

