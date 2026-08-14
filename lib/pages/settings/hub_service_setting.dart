part of 'settings_page.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  公共组件
// ═══════════════════════════════════════════════════════════════════════════

/// 底部 Sheet 统一标题栏
class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title, this.icon});

  final String title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

/// 成员头像 + 名称 Tile
class _ClientTile extends StatelessWidget {
  const _ClientTile({required this.name, this.avatarUrl, this.trailing});

  final String name;
  final String? avatarUrl;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: avatarUrl != null && avatarUrl!.isNotEmpty
          ? CircleAvatar(
              backgroundColor: cs.primaryContainer,
              child: ClipOval(
                child: AnimatedImage(
                  image: CachedImageProvider(
                    hubFileUrlOf(avatarUrl),
                    sourceKey: 'hub',
                  ),
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              ),
            )
          : CircleAvatar(
              backgroundColor: cs.primaryContainer,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(color: cs.onPrimaryContainer),
              ),
            ),
      title: Text(name),
      trailing: trailing,
    );
  }
}

/// 空状态提示
class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.toOpacity(0.4),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  _HubManagementPage
// ═══════════════════════════════════════════════════════════════════════════

class _HubManagementPage extends ConsumerStatefulWidget {
  const _HubManagementPage();

  @override
  ConsumerState<_HubManagementPage> createState() => _HubManagementPageState();
}

class _HubManagementPageState extends ConsumerState<_HubManagementPage> {
  late final HubService _hub;
  HubAiBotConfig _aiBotConfig = HubAiBotConfig.load();

  List<SatoriBotProfile> get _satoriProfiles =>
      SatoriBotProfileStore.instance.load();

  bool get _webAdminEnabled =>
      appdata.implicitData['hub_web_admin_enabled'] as bool? ?? false;

  int get _webAdminPort =>
      appdata.implicitData['hub_web_admin_port'] as int? ?? 9200;

  @override
  void initState() {
    super.initState();
    _hub = ref.read(hubServiceProvider);
    _hub.onClientsChanged = () {
      if (mounted) setState(() {});
    };
  }

  @override
  void dispose() {
    _hub.onClientsChanged = null;
    super.dispose();
  }

  void _showWebAdminSettingsPage(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const _WebAdminSettingsPage()));
  }

  // ── 订阅管理 ──────────────────────────────────────────────────────────────

  List<Widget> _subscriptionSection() {
    final subs = HubSubscriptionManager.instance.load();
    final bots = _satoriProfiles;
    final total = subs.length + bots.length;
    final scheme = Theme.of(context).colorScheme;
    return [
      // ── 标题 + 数量 + 加号 ─────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
        child: Row(
          children: [
            const Icon(Icons.hub_outlined, size: 20),
            const SizedBox(width: 8),
            Text(
              t.subscriptionManagement,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(width: 6),
            Text(
              '$total',
              style: TextStyle(fontSize: 12, color: scheme.outline),
            ),
            const Spacer(),
            IconButton.filledTonal(
              icon: const Icon(Icons.add, size: 18),
              tooltip: t.addSubscription,
              visualDensity: VisualDensity.compact,
              onPressed: () => _showAddProtocolMenu(context),
            ),
          ],
        ),
      ),
      if (subs.isEmpty && bots.isEmpty)
        _EmptyHint(t.noSubscriptions)
      else ...[
        if (subs.isNotEmpty) ...[
          _protocolGroupHeader(
            context,
            'kostori',
            Icons.hub_outlined,
            subs.length,
          ),
          for (final s in subs) _subscriptionCard(context, s),
        ],
        if (bots.isNotEmpty) ...[
          _protocolGroupHeader(
            context,
            'Satori',
            Icons.smart_toy_outlined,
            bots.length,
          ),
          for (final p in bots) _satoriBotCard(context, p),
        ],
      ],
    ];
  }

  /// 协议分组小标题（kostori / satori）
  Widget _protocolGroupHeader(
    BuildContext context,
    String label,
    IconData icon,
    int count,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
      child: Row(
        children: [
          Icon(icon, size: 15, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 6),
          Text('$count', style: TextStyle(fontSize: 11, color: scheme.outline)),
        ],
      ),
    );
  }

  /// Satori 接入机器人卡片
  Widget _satoriBotCard(BuildContext context, SatoriBotProfile p) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        child: GestureDetector(
          onSecondaryTap: () => _showSatoriBotActions(context, p),
          child: ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 15,
              backgroundColor: hubAvatarColor(p.id),
              backgroundImage: p.avatarUrl != null && p.avatarUrl!.isNotEmpty
                  ? CachedImageProvider(
                      hubFileUrlOf(p.avatarUrl),
                      sourceKey: 'hub',
                    )
                  : null,
              child: p.avatarUrl == null || p.avatarUrl!.isEmpty
                  ? Text(
                      hubInitials(p.name),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
            title: Text(
              p.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              p.enabled ? t.hubAiBotStatus : t.hubAiBotStatusDisabled,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: (p.enabled ? Colors.green : scheme.outline)
                        .toOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    p.enabled ? t.running : t.stopped,
                    style: TextStyle(
                      fontSize: 10,
                      color: p.enabled ? Colors.green : scheme.outline,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
            onTap: () => _showSatoriBotEditSheet(context, p),
            onLongPress: () => _showSatoriBotActions(context, p),
          ),
        ),
      ),
    );
  }

  Future<void> _showSatoriBotActions(
    BuildContext context,
    SatoriBotProfile p,
  ) async {
    final scheme = Theme.of(context).colorScheme;
    showMenuX(context, const Offset(0, 0), [
      MenuEntry(
        icon: Icons.edit_outlined,
        text: t.edit,
        onClick: () => _showSatoriBotEditSheet(context, p),
      ),
      MenuEntry(
        icon: Icons.copy_outlined,
        text: t.satoriBotToken,
        onClick: () {
          Clipboard.setData(ClipboardData(text: p.token));
          App.rootContext.showMessage(message: t.satoriBotTokenCopied);
        },
      ),
      MenuEntry(
        icon: Icons.delete_outline,
        text: t.delete,
        color: scheme.error,
        onClick: () {
          showConfirmDialog(
            context: context,
            title: t.satoriBotDelete,
            content: t.satoriBotDeleteConfirm,
            onConfirm: () {
              SatoriBotProfileStore.instance.save(
                _satoriProfiles.where((x) => x.id != p.id).toList(),
              );
              _hub.unregisterBotMember(p.id);
              if (mounted) setState(() {});
            },
          );
        },
      ),
    ]);
  }

  String _subscriptionTypeLabel(HubSubscription s) => switch (s.type) {
    HubSubscriptionType.ws =>
      s.wsDirection == HubWsDirection.forward ? t.wsForward : t.wsReverse,
    HubSubscriptionType.webhook => t.webhookConnection,
    HubSubscriptionType.http => t.httpServer,
  };

  IconData _subscriptionTypeIcon(HubSubscription s) => switch (s.type) {
    HubSubscriptionType.ws => Icons.extension_outlined,
    HubSubscriptionType.webhook => Icons.webhook,
    HubSubscriptionType.http => Icons.dns_outlined,
  };

  Widget _subscriptionCard(BuildContext context, HubSubscription s) {
    final scheme = Theme.of(context).colorScheme;
    final status = HubSubscriptionService.instance.statusOf(s.id);
    final statusLabel = switch (status) {
      'running' => t.running,
      'error' => t.error,
      _ => t.stopped,
    };
    final statusColor = switch (status) {
      'running' => Colors.green,
      'error' => scheme.error,
      _ => scheme.outline,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        child: GestureDetector(
          onSecondaryTap: () => _showSubscriptionActions(context, s),
          child: ListTile(
            dense: true,
            leading: Icon(_subscriptionTypeIcon(s), size: 20),
            title: Text(
              s.note.trim().isEmpty ? _subscriptionTypeLabel(s) : s.note.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              '${_subscriptionTypeLabel(s)} · ${s.summary}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.toOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(fontSize: 10, color: statusColor),
                  ),
                ),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
            onTap: () => _showSubscriptionEditor(context, subscription: s),
            onLongPress: () => _showSubscriptionActions(context, s),
          ),
        ),
      ),
    );
  }

  Future<void> _showSubscriptionActions(
    BuildContext context,
    HubSubscription s,
  ) async {
    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final scheme = Theme.of(context).colorScheme;
    showMenuX(
      context,
      Offset(offset.dx + size.width / 2, offset.dy + size.height),
      [
        MenuEntry(
          icon: Icons.edit_outlined,
          text: t.edit,
          onClick: () => _showSubscriptionEditor(context, subscription: s),
        ),
        MenuEntry(
          icon: Icons.delete_outline,
          text: t.delete,
          color: scheme.error,
          onClick: () async {
            HubSubscriptionManager.instance.delete(s.id);
            await HubSubscriptionService.instance.stop(s.id);
            if (mounted) setState(() {});
          },
        ),
      ],
    );
  }

  /// 加号 → 协议选择（kostori / satori）
  Future<void> _showAddProtocolMenu(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (ctx) => ContentDialog(
        title: t.addSubscription,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              dense: true,
              leading: const Icon(Icons.hub_outlined, size: 20),
              title: Text('kostori'),
              subtitle: Text(
                '${t.wsForward} / ${t.wsReverse} / ${t.webhookConnection} / ${t.httpServer}',
                style: const TextStyle(fontSize: 11),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showAddSubscriptionMenu(context);
              },
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.smart_toy_outlined, size: 20),
              title: Text('Satori'),
              subtitle: Text(
                t.satoriBotManageDesc,
                style: const TextStyle(fontSize: 11),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showSatoriBotEditSheet(context, null);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// kostori 协议 → 二级菜单（三种连接方式选项卡）
  Future<void> _showAddSubscriptionMenu(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (ctx) => ContentDialog(
        title: t.addSubscription,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              dense: true,
              leading: const Icon(Icons.extension_outlined, size: 20),
              title: Text('WS'),
              subtitle: Text(
                '${t.wsForward} / ${t.wsReverse}',
                style: const TextStyle(fontSize: 11),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showWsDirectionChoice(context);
              },
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.webhook, size: 20),
              title: Text('Webhook'),
              subtitle: Text(
                t.webhookConnection,
                style: const TextStyle(fontSize: 11),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showSubscriptionEditor(
                  context,
                  type: HubSubscriptionType.webhook,
                );
              },
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.dns_outlined, size: 20),
              title: Text('HTTP'),
              subtitle: Text(
                t.httpServer,
                style: const TextStyle(fontSize: 11),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showSubscriptionEditor(
                  context,
                  type: HubSubscriptionType.http,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// WS → 正向 / 反向 选择
  Future<void> _showWsDirectionChoice(BuildContext context) async {
    final direction = await showDialog<HubWsDirection>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: 'WS',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              dense: true,
              leading: const Icon(Icons.settings_input_antenna, size: 20),
              title: Text(t.wsForward),
              trailing: const Icon(Icons.arrow_forward, size: 16),
              onTap: () => Navigator.pop(ctx, HubWsDirection.forward),
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.settings_ethernet, size: 20),
              title: Text(t.wsReverse),
              trailing: const Icon(Icons.arrow_back, size: 16),
              onTap: () => Navigator.pop(ctx, HubWsDirection.reverse),
            ),
          ],
        ),
      ),
    );
    if (direction == null) return;
    _showSubscriptionEditor(
      context,
      type: HubSubscriptionType.ws,
      wsDirection: direction,
    );
  }

  /// 订阅编辑/新增表单
  Future<void> _showSubscriptionEditor(
    BuildContext context, {
    HubSubscriptionType? type,
    HubWsDirection? wsDirection,
    HubSubscription? subscription,
  }) async {
    final isEdit = subscription != null;
    final noteCtrl = TextEditingController(text: subscription?.note ?? '');
    final hostCtrl = TextEditingController(
      text: subscription?.listenHost ?? '0.0.0.0',
    );
    final portCtrl = TextEditingController(
      text: (subscription?.listenPort ?? 9100).toString(),
    );
    final urlCtrl = TextEditingController(text: subscription?.url ?? '');
    final heartbeatCtrl = TextEditingController(
      text: subscription?.heartbeatMs == null
          ? ''
          : subscription!.heartbeatMs.toString(),
    );
    final tokenCtrl = TextEditingController(text: subscription?.token ?? '');

    final effectiveType = type ?? subscription?.type ?? HubSubscriptionType.ws;
    final effectiveDirection =
        wsDirection ?? subscription?.wsDirection ?? HubWsDirection.forward;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSS) => ContentDialog(
          title: isEdit ? t.edit : t.addSubscription,
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.6,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 连接方式
                  Text(
                    '${t.connectionType}: ${_subscriptionTypeLabel(HubSubscription(id: '', type: effectiveType, wsDirection: effectiveDirection, createdAt: ''))}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    decoration: InputDecoration(labelText: t.note),
                  ),
                  const SizedBox(height: 12),
                  if (effectiveType == HubSubscriptionType.ws &&
                      effectiveDirection == HubWsDirection.forward) ...[
                    TextField(
                      controller: hostCtrl,
                      decoration: InputDecoration(labelText: t.listenAddress),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: portCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: t.listenPort),
                    ),
                  ] else if (effectiveType == HubSubscriptionType.http) ...[
                    TextField(
                      controller: hostCtrl,
                      decoration: InputDecoration(labelText: t.listenAddress),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: portCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: t.listenPort),
                    ),
                  ] else ...[
                    TextField(
                      controller: urlCtrl,
                      decoration: InputDecoration(labelText: t.targetUrl),
                    ),
                  ],
                  if (effectiveType != HubSubscriptionType.http) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: heartbeatCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: t.heartbeat),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: tokenCtrl,
                          decoration: InputDecoration(labelText: t.token),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.auto_fix_high_outlined,
                          size: 18,
                        ),
                        tooltip: t.satoriBotTokenRegen,
                        onPressed: () {
                          tokenCtrl.text = SatoriBotProfileStore.instance
                              .generateToken();
                          setSS(() {});
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () async {
                final sub = HubSubscription(
                  id: subscription?.id ?? const Uuid().v4(),
                  type: effectiveType,
                  wsDirection: effectiveType == HubSubscriptionType.ws
                      ? effectiveDirection
                      : null,
                  listenHost:
                      (effectiveType == HubSubscriptionType.ws &&
                              effectiveDirection == HubWsDirection.forward) ||
                          effectiveType == HubSubscriptionType.http
                      ? hostCtrl.text.trim()
                      : null,
                  listenPort:
                      (effectiveType == HubSubscriptionType.ws &&
                              effectiveDirection == HubWsDirection.forward) ||
                          effectiveType == HubSubscriptionType.http
                      ? int.tryParse(portCtrl.text.trim())
                      : null,
                  url:
                      (effectiveType == HubSubscriptionType.ws &&
                              effectiveDirection == HubWsDirection.reverse) ||
                          effectiveType == HubSubscriptionType.webhook
                      ? urlCtrl.text.trim()
                      : null,
                  heartbeatMs: int.tryParse(heartbeatCtrl.text.trim()),
                  token: tokenCtrl.text.trim().isEmpty
                      ? null
                      : tokenCtrl.text.trim(),
                  note: noteCtrl.text.trim(),
                  createdAt:
                      subscription?.createdAt ??
                      DateTime.now().toIso8601String(),
                );
                if (isEdit) {
                  HubSubscriptionManager.instance.update(sub);
                } else {
                  HubSubscriptionManager.instance.add(sub);
                }
                await HubSubscriptionService.instance.start(sub);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) setState(() {});
              },
              child: Text(t.apply),
            ),
          ],
        ),
      ),
    );
    noteCtrl.dispose();
    hostCtrl.dispose();
    portCtrl.dispose();
    urlCtrl.dispose();
    heartbeatCtrl.dispose();
    tokenCtrl.dispose();
  }

  // ── 房间导入导出 ──────────────────────────────────────────────────────────

  Future<void> _exportRooms() async {
    try {
      await saveFile(
        data: utf8.encode(_hub.exportRoomsJson()),
        filename: 'hub_rooms.json',
      );
      App.rootContext.showMessage(message: t.saved);
    } catch (e) {
      App.rootContext.showMessage(
        message: '${t.savedFailed}: $e',
        level: LogLevel.warning,
      );
    }
  }

  Future<void> _importRooms() async {
    final result = await FilePicker.pickFiles(type: FileType.any);
    if (result == null || result.files.isEmpty) return;
    try {
      final bytes = await result.files.single.readAsBytes();
      _hub.importRoomsJson(utf8.decode(bytes));
      setState(() {});
      App.rootContext.showMessage(message: t.saved);
    } catch (e) {
      App.rootContext.showMessage(
        message: '${t.savedFailed}: $e',
        level: LogLevel.warning,
      );
    }
  }

  // ── AI 陪聊机器人配置 ─────────────────────────────────────────────────────

  Future<void> _showAiBotConfigSheet(BuildContext context) async {
    var provider =
        OpenAiProviderRegistry.allProviders.containsKey(_aiBotConfig.provider)
        ? _aiBotConfig.provider
        : 'deepseek';
    var model = _aiBotConfig.model;
    var models = await AiDatabase.instance.aiModelDao.getModelsByProvider(
      provider,
    );

    await showPopUpWidget(
      context,
      _AiBotConfigPage(
        initialName: _aiBotConfig.name,
        initialProvider: provider,
        initialModel: model,
        initialModels: models,
        initialMinInterval: _aiBotConfig.minIntervalSec,
        initialReplyDm: _aiBotConfig.replyDm,
        initialTriggerMode: _aiBotConfig.triggerMode,
        initialTriggerPattern: _aiBotConfig.triggerPattern,
        onSave:
            (
              name,
              provider,
              model,
              prompt,
              minInterval,
              replyDm,
              triggerMode,
              triggerPattern,
            ) {
              setState(() {
                _aiBotConfig = _aiBotConfig.copyWith(
                  name: name.trim().isEmpty
                      ? t.hubAiBotDefaultName
                      : name.trim(),
                  provider: provider,
                  model: model,
                  systemPrompt: prompt,
                  minIntervalSec: minInterval,
                  replyDm: replyDm,
                  triggerMode: triggerMode,
                  triggerPattern: triggerPattern,
                )..save();
              });
              _hub.syncAiBotMember();
            },
      ),
    );
  }

  Future<void> _showSatoriBotEditSheet(
    BuildContext context,
    SatoriBotProfile? existing,
  ) async {
    await showPopUpWidget(context, _SatoriBotEditPage(existing: existing));
    if (mounted) setState(() {});
  }

  /// 上传 bot 头像，返回访问 URL
  void _showBlacklistSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSS) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHeader(title: t.blacklist, icon: Icons.block_outlined),
            if (_hub.blacklist.isEmpty)
              _EmptyHint(t.noBannedUsers)
            else
              ..._hub.blacklist.map(
                (id) => _ClientTile(
                  name: id,
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                    tooltip: t.removeFromBlacklist,
                    onPressed: () {
                      _hub.removeFromBlacklist(id);
                      setSS(() {});
                      setState(() {});
                    },
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── 房间列表 ──────────────────────────────────────────────────────────────

  void _showRoomsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSS) => Sheet(
          title: t.rooms,
          icon: Icons.meeting_room_outlined,
          headerTrailing: TextButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: Text(t.create),
            onPressed: () async {
              await _showCreateRoomDialog(context);
              setSS(() {});
            },
          ),
          builder: (context, sc) => ListView.builder(
            controller: sc,
            itemCount: _hub.rooms.length,
            itemBuilder: (context, i) {
              final room = _hub.rooms[i];
              return ListTile(
                leading: Icon(
                  room.isLocked
                      ? Icons.lock_outlined
                      : Icons.meeting_room_outlined,
                ),
                title: Text(room.roomName),
                subtitle: Text(
                  '${room.participantCount} ${t.members}'
                  '${room.announcements.isNotEmpty ? "  ·  ${room.announcements.first}" : ""}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.manage_accounts_outlined,
                        size: 18,
                      ),
                      tooltip: t.roomAdmins,
                      onPressed: () =>
                          _showRoomAdminSheet(context, room, setSS),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      tooltip: t.deleteRoom,
                      onPressed: () async {
                        await _hub.deleteRoom(room.roomId);
                        setSS(() {});
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateRoomDialog(BuildContext context) async {
    final result = await showCreateRoomDialog();
    if (result == null) return;
    await _hub.createRoom(
      result.name,
      password: result.password,
      announcement: result.announcement,
      maxParticipants: result.maxParticipants,
    );
    setState(() {});
  }

  void _showRoomAdminSheet(
    BuildContext context,
    HubRoom room,
    StateSetter setParent,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSS) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHeader(
              title: "${t.roomAdmins} · ${room.roomName}",
              icon: Icons.manage_accounts_outlined,
            ),
            Expanded(
              child: ListView(
                children: _hub.clients.map((client) {
                  final isAdmin = room.isModerator(client.userId);
                  return _ClientTile(
                    name: client.displayName ?? client.userId,
                    avatarUrl: client.avatarUrl,
                    trailing: CustomSwitch(
                      value: isAdmin,
                      onChanged: (val) async {
                        await _hub.setClientRoomAdmin(
                          client.userId,
                          room.roomId,
                          val,
                        );
                        setSS(() {});
                        setParent(() {});
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopUpWidgetScaffold(
      title: t.hubManagement,
      body: CustomScrollView(
        slivers: [
          _BuildSectionPadding(
            _SettingCard(
              children: [
                _SettingPartTitle(
                  title: t.rooms,
                  icon: Icons.meeting_room_outlined,
                ),
                _SettingRow(
                  title: "${_hub.rooms.length} rooms",
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.file_download_outlined,
                          size: 18,
                        ),
                        tooltip: t.importRooms,
                        onPressed: _importRooms,
                      ),
                      IconButton(
                        icon: const Icon(Icons.file_upload_outlined, size: 18),
                        tooltip: t.exportRooms,
                        onPressed: _exportRooms,
                      ),
                      IconButton(
                        icon: const Icon(Icons.open_in_new, size: 18),
                        tooltip: t.view,
                        onPressed: () => _showRoomsSheet(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _BuildSectionPadding(_SettingCard(children: _subscriptionSection())),
          // ── AI 陪聊机器人 ─────────────────────────────────────────────
          _BuildSectionPadding(
            _SettingCard(
              children: [
                _SettingPartTitle(
                  title: t.hubAiBot,
                  icon: Icons.smart_toy_outlined,
                ),
                _SettingRow(
                  title: t.hubAiBotEnabled,
                  subtitle: _aiBotConfig.enabled
                      ? '${t.hubAiBotStatus} · ${_aiBotConfig.name}'
                      : t.hubAiBotStatusDisabled,
                  trailing: CustomSwitch(
                    value: _aiBotConfig.enabled,
                    onChanged: (v) {
                      setState(
                        () =>
                            _aiBotConfig = _aiBotConfig.copyWith(enabled: v)
                              ..save(),
                      );
                      // 启用/禁用时同步注册/注销 AI 机器人成员（@ 列表可见）
                      _hub.syncAiBotMember();
                    },
                  ),
                ),
                _SettingRow(
                  title: t.hubAiBotConfigure,
                  subtitle: t.hubAiBotConfigureDesc,
                  trailing: IconButton(
                    icon: const Icon(Icons.settings_outlined, size: 18),
                    tooltip: t.hubAiBotConfigure,
                    onPressed: () => _showAiBotConfigSheet(context),
                  ),
                ),
              ],
            ),
          ),
          // ── Web 管理后台（二级页面：说明 + 开关 + 端口） ────────────────
          _BuildSectionPadding(
            _SettingCard(
              children: [
                _SettingPartTitle(title: t.webAdminDashboard, icon: Icons.web),
                InkWell(
                  onTap: () => _showWebAdminSettingsPage(context),
                  child: _SettingRow(
                    title: t.webAdminSettings,
                    subtitle: _webAdminEnabled
                        ? '${t.enabled} · http://localhost:$_webAdminPort'
                        : t.disabled,
                    trailing: const Icon(Icons.chevron_right, size: 18),
                  ),
                ),
              ],
            ),
          ),
          if (_hub.eventLog.isNotEmpty)
            _BuildSectionPadding(
              _SettingCard(
                children: [
                  _SettingPartTitle(
                    title: t.eventLog,
                    icon: Icons.history_outlined,
                  ),
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      reverse: true,
                      itemCount: _hub.eventLog.length,
                      itemBuilder: (context, i) {
                        final log = _hub.eventLog[_hub.eventLog.length - 1 - i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 2,
                          ),
                          child: Text(
                            log,
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.toOpacity(0.6),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: Text(t.clear),
                      onPressed: () {
                        _hub.eventLog.clear();
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),
            ),
          _BuildSectionPadding(
            _SettingCard(
              children: [
                _SettingPartTitle(
                  title: t.blacklist,
                  icon: Icons.block_outlined,
                ),
                _SettingRow(
                  title: "${_hub.blacklistCount} banned",
                  trailing: IconButton(
                    icon: const Icon(Icons.open_in_new, size: 18),
                    onPressed: () => _showBlacklistSheet(context),
                  ),
                ),
              ],
            ),
          ),
          if (_hub.clientCount > 0)
            _BuildSectionPadding(
              _SettingCard(
                children: [
                  _SettingPartTitle(
                    title: t.onlineClients,
                    icon: Icons.people_outline,
                  ),
                  ..._hub.clients.map(
                    (client) => _OnlineClientTile(
                      client: client.toDto(),
                      myId: null,
                      isBlocked: false,
                      canManage: true,
                      isAdmin: client.isGlobalAdmin,
                      isBlacklisted: _hub.isBlacklisted(client.userId),
                      onBlock: () {},
                      onMute: (seconds) async {
                        if (seconds == 0 || client.isMuted) {
                          await _hub.unmuteClient(client.userId);
                        } else {
                          await _hub.muteClient(
                            client.userId,
                            seconds: seconds,
                          );
                        }
                        setState(() {});
                      },
                      onKick: () async {
                        await _hub.kickClient(client.userId);
                        setState(() {});
                      },
                      onSetAdmin: () async {
                        await _hub.setClientGlobalAdmin(
                          client.userId,
                          !client.isGlobalAdmin,
                        );
                        setState(() {});
                      },
                      onBlacklist: () {
                        _hub.isBlacklisted(client.userId)
                            ? _hub.removeFromBlacklist(client.userId)
                            : _hub.addToBlacklist(client.userId);
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── 小工具：带标签的输入框列 ──────────────────────────────────────────────────
class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurface.toOpacity(0.5),
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

class _OnlineClientTile extends StatelessWidget {
  const _OnlineClientTile({
    required this.client,
    required this.myId,
    required this.isBlocked,
    required this.canManage,
    required this.onBlock,
    required this.onMute,
    required this.onKick,
    this.onBlacklist,
    this.isBlacklisted,
    this.onSetAdmin,
    this.isAdmin,
  });

  final HubClientDto client;
  final String? myId;
  final bool isBlocked;
  final bool canManage;
  final VoidCallback onBlock;
  final ValueChanged<int> onMute;
  final VoidCallback onKick;
  final VoidCallback? onBlacklist;
  final bool? isBlacklisted;
  final VoidCallback? onSetAdmin;
  final bool? isAdmin;

  void _showMuteSheet(BuildContext context) {
    if (client.isMuted) {
      onMute(0);
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (_) => _MuteSheet(
        clientName: client.displayName,
        onMute: (seconds) {
          Navigator.pop(context);
          onMute(seconds);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMuted = client.isMuted;
    final isMe = client.userId == myId;
    final cs = Theme.of(context).colorScheme;

    return ListTile(
      leading: client.avatarUrl != null && client.avatarUrl!.isNotEmpty
          ? CircleAvatar(
              radius: 16,
              backgroundColor: cs.surfaceContainerHighest,
              child: ClipOval(
                child: AnimatedImage(
                  image: CachedImageProvider(
                    hubFileUrlOf(client.avatarUrl),
                    sourceKey: 'hub',
                  ),
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                ),
              ),
            )
          : CircleAvatar(
              radius: 16,
              child: Text(
                (client.displayName.isEmpty ? 'U' : client.displayName)[0]
                    .toUpperCase(),
              ),
            ),
      title: Text(
        '${client.displayName}'
        '${client.isGlobalAdmin ? "  👑" : ""}'
        '${isMuted ? "  🔇" : ""}',
      ),
      subtitle: Text(
        client.biography != null && client.biography!.isNotEmpty
            ? client.biography!
            : client.onlineStatus.name,
      ),
      trailing: isMe
          ? Text(t.me, style: TextStyle(color: cs.primary, fontSize: 12))
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (myId != null)
                  IconButton(
                    icon: Icon(
                      isBlocked ? Icons.volume_off : Icons.volume_off_outlined,
                      size: 18,
                      color: isBlocked ? cs.error : null,
                    ),
                    tooltip: isBlocked ? t.unblock : t.block,
                    onPressed: onBlock,
                  ),
                if (canManage && !client.isGlobalAdmin) ...[
                  IconButton(
                    icon: Icon(
                      isMuted ? Icons.mic : Icons.mic_off,
                      size: 18,
                      color: isMuted ? cs.error : null,
                    ),
                    tooltip: isMuted ? t.unmute : t.mute,
                    onPressed: () => _showMuteSheet(context),
                  ),
                  if (!client.isGlobalAdmin)
                    IconButton(
                      icon: const Icon(Icons.logout, size: 18),
                      tooltip: t.kick,
                      onPressed: onKick,
                    ),
                ],
                if (onSetAdmin != null)
                  IconButton(
                    icon: Icon(
                      isAdmin == true ? Icons.shield : Icons.shield_outlined,
                      size: 18,
                      color: isAdmin == true ? cs.primary : null,
                    ),
                    tooltip: isAdmin == true
                        ? t.removeGlobalAdmin
                        : t.setGlobalAdmin,
                    onPressed: onSetAdmin,
                  ),
                if (onBlacklist != null && !client.isGlobalAdmin)
                  IconButton(
                    icon: Icon(
                      isBlacklisted == true
                          ? Icons.block
                          : Icons.block_outlined,
                      size: 18,
                      color: isBlacklisted == true ? cs.error : null,
                    ),
                    tooltip: isBlacklisted == true
                        ? t.removeFromBlacklist
                        : t.addToBlacklist,
                    onPressed: onBlacklist,
                  ),
              ],
            ),
    );
  }
}

/// Satori 接入机器人编辑页（数据同步设置风格）
class _SatoriBotEditPage extends ConsumerStatefulWidget {
  final SatoriBotProfile? existing;
  const _SatoriBotEditPage({this.existing});

  @override
  ConsumerState<_SatoriBotEditPage> createState() => _SatoriBotEditPageState();
}

class _SatoriBotEditPageState extends ConsumerState<_SatoriBotEditPage> {
  late HubService _hub;
  late HubClient _hubClient;
  late SatoriBotProfile _profile;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _bioCtrl;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _hub = ref.read(hubServiceProvider);
    _hubClient = ref.read(hubClientProvider);
    final store = SatoriBotProfileStore.instance;
    _profile =
        widget.existing ??
        SatoriBotProfile(
          id: store.generateId(),
          name: '',
          token: store.generateToken(),
          enabled: true,
        );
    _nameCtrl = TextEditingController(text: _profile.name);
    _bioCtrl = TextEditingController(text: _profile.biography ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _uploadAvatar(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final savedAddress = _hubClient.savedAddress;
      if (savedAddress == null || savedAddress.isEmpty) return;
      final httpBase = HubImageUploader.httpUrlOf(
        savedAddress,
      ).replaceAll(RegExp(r'/hub/?$'), '');
      final token = _hubClient.savedToken;
      final resp = await AppDio().request(
        '$httpBase/hub/upload/config',
        options: Options(
          method: 'GET',
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
          headers: {
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          },
        ),
      );
      if (resp.statusCode != 200 || resp.data is! Map) return;
      final config = HubUploadConfig.fromJson(
        Map<String, dynamic>.from(resp.data as Map),
      );
      final url = await HubImageUploader(
        config: config,
        serverBaseUrl: httpBase,
        authToken: _hubClient.savedToken,
      ).upload(bytes, picked.name);
      if (mounted) {
        setState(() => _profile = _profile.copyWith(avatarUrl: url));
      }
    } catch (e) {
      App.rootContext.showMessage(
        message: '${t.uploadFailed}: $e',
        level: LogLevel.warning,
      );
    }
  }

  void _save() {
    final avatarResolved = hubFileUrlOf(_profile.avatarUrl);
    final finalProfile = SatoriBotProfile(
      id: _profile.id,
      name: _nameCtrl.text.trim().isEmpty
          ? _profile.name
          : _nameCtrl.text.trim(),
      avatarUrl: avatarResolved.isEmpty ? null : avatarResolved,
      biography: _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
      token: _profile.token,
      enabled: _profile.enabled,
    );
    final store = SatoriBotProfileStore.instance;
    store.save([
      ...store.load().where((x) => x.id != _profile.id),
      finalProfile,
    ]);
    if (finalProfile.enabled) {
      _hub.registerBotMember(
        userId: finalProfile.id,
        displayName: finalProfile.name,
        avatarUrl: finalProfile.avatarUrl,
      );
    } else {
      _hub.unregisterBotMember(finalProfile.id);
    }
    App.rootPop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopUpWidgetScaffold(
      title: _isEdit ? t.satoriBotEdit : t.satoriBotAdd,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FormCard(
              children: [
                _FormSectionTitle(
                  title: t.satoriBotName,
                  icon: Icons.badge_outlined,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameCtrl,
                  decoration: _formFieldDecoration(
                    labelText: t.satoriBotName,
                    hintText: t.satoriBotNameHint,
                  ),
                ),
                const Divider(height: 24),
                _FormSectionTitle(
                  title: t.satoriBotAvatar,
                  icon: Icons.account_circle_outlined,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: hubAvatarColor(_profile.id),
                      backgroundImage:
                          _profile.avatarUrl != null &&
                              _profile.avatarUrl!.isNotEmpty
                          ? CachedImageProvider(
                              hubFileUrlOf(_profile.avatarUrl),
                              sourceKey: 'hub',
                            )
                          : null,
                      child:
                          _profile.avatarUrl == null ||
                              _profile.avatarUrl!.isEmpty
                          ? Text(
                              hubInitials(_profile.name),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.upload_outlined, size: 16),
                        label: Text(t.upload),
                        onPressed: () => _uploadAvatar(context),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                _FormSectionTitle(
                  title: t.satoriBotBio,
                  icon: Icons.notes_outlined,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bioCtrl,
                  maxLines: 3,
                  decoration: _formFieldDecoration(labelText: t.satoriBotBio),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _FormCard(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    t.satoriBotEnabled,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    t.satoriBotEnabled,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                  trailing: CustomSwitch(
                    value: _profile.enabled,
                    onChanged: (v) => setState(
                      () => _profile = _profile.copyWith(enabled: v),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _FormCard(
              children: [
                _FormSectionTitle(
                  title: t.satoriBotToken,
                  icon: Icons.key_outlined,
                ),
                const SizedBox(height: 12),
                Text(
                  t.satoriBotTokenHint,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        _profile.token,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_outlined, size: 18),
                      tooltip: t.copy,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _profile.token));
                        App.rootContext.showMessage(
                          message: t.satoriBotTokenCopied,
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 18),
                      tooltip: t.satoriBotTokenRegen,
                      onPressed: () {
                        setState(
                          () => _profile = SatoriBotProfile(
                            id: _profile.id,
                            name: _profile.name,
                            avatarUrl: _profile.avatarUrl,
                            biography: _profile.biography,
                            token: SatoriBotProfileStore.instance
                                .generateToken(),
                            enabled: _profile.enabled,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            _FormSaveButton(onPressed: _save),
          ],
        ),
      ),
    );
  }
}

/// 数据同步风格的表单卡片（Kostori/Satori bot 设置页复用）
class _FormCard extends StatelessWidget {
  final List<Widget> children;
  const _FormCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
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
          children: children,
        ),
      ),
    );
  }
}

/// 表单卡片标题（icon + 粗体文字）
class _FormSectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _FormSectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// 表单输入框装饰（数据同步风格）
InputDecoration _formFieldDecoration({
  required String labelText,
  String? hintText,
  Widget? suffix,
}) {
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    suffixIcon: suffix,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
  );
}

/// 表单底部全宽保存按钮
class _FormSaveButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _FormSaveButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Button.filled(
        onPressed: onPressed,
        child: Text(t.save, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}

// ── _MuteSheet ────────────────────────────────────────────────────────────────

class _MuteSheet extends StatefulWidget {
  const _MuteSheet({required this.clientName, required this.onMute});

  final String clientName;
  final ValueChanged<int> onMute;

  @override
  State<_MuteSheet> createState() => _MuteSheetState();
}

class _MuteSheetState extends State<_MuteSheet> {
  static const _presets = [
    (label: '1 min', seconds: 60),
    (label: '5 min', seconds: 300),
    (label: '10 min', seconds: 600),
    (label: '30 min', seconds: 1800),
    (label: '1 hour', seconds: 3600),
    (label: '24 hour', seconds: 86400),
  ];

  final _controller = TextEditingController();
  bool _showCustom = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                Icon(Icons.mic_off_outlined, size: 18, color: cs.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${t.mute}  ${widget.clientName}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._presets.map(
                  (p) => ActionChip(
                    label: Text(p.label),
                    onPressed: () => widget.onMute(p.seconds),
                  ),
                ),
                ActionChip(
                  avatar: Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: cs.primary,
                  ),
                  label: Text(t.custom, style: TextStyle(color: cs.primary)),
                  onPressed: () => setState(() => _showCustom = !_showCustom),
                ),
              ],
            ),
          ),
          if (_showCustom)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: t.secondsLabel,
                        suffixText: "s",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      final s = int.tryParse(_controller.text);
                      if (s != null && s > 0) widget.onMute(s);
                    },
                    child: Text(t.confirm),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _NumberInput extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _NumberInput({
    required this.controller,
    required this.enabled,
    required this.onChanged,
    this.min = 1024,
    this.max = 65535,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 72,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.toOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: enabled
              ? colorScheme.onSurface
              : colorScheme.onSurface.toOpacity(0.35),
        ),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: colorScheme.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 10,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: colorScheme.primary.toOpacity(0.6),
              width: 1.5,
            ),
          ),
        ),
        onChanged: (v) {
          final val = int.tryParse(v);
          if (val != null && val >= min && val <= max) {
            onChanged(val);
          }
        },
      ),
    );
  }
}

class _ApiKeyTile extends StatefulWidget {
  const _ApiKeyTile({
    required this.keyManager,
    required this.onRegenerate,
    this.isAdmin = false,
  });

  final ApiKeyManager keyManager;
  final VoidCallback onRegenerate;
  final bool isAdmin;

  @override
  State<_ApiKeyTile> createState() => _ApiKeyTileState();
}

class _ApiKeyTileState extends State<_ApiKeyTile> {
  bool _obscured = true;

  String get _activeKey => widget.isAdmin
      ? widget.keyManager.adminActiveKey
      : widget.keyManager.activeKey;

  String get _label => widget.isAdmin ? t.adminKey : t.userKey;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(_label),
      subtitle: Text(
        _obscured ? '••••••••••••••••' : _activeKey,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              _obscured ? Icons.visibility_off : Icons.visibility,
              size: 18,
            ),
            tooltip: _obscured ? t.show : t.hide,
            onPressed: () => setState(() => _obscured = !_obscured),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            tooltip: t.copy,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _activeKey));
              App.rootContext.showMessage(message: t.copied);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            tooltip: t.regenerate,
            onPressed: widget.onRegenerate,
          ),
        ],
      ),
    );
  }
}

class _HubTokenInput extends StatefulWidget {
  const _HubTokenInput({
    required this.controller,
    required this.enabled,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool enabled;
  final void Function(String) onChanged;

  @override
  State<_HubTokenInput> createState() => _HubTokenInputState();
}

class _HubTokenInputState extends State<_HubTokenInput> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: TextField(
        controller: widget.controller,
        enabled: widget.enabled,
        decoration: InputDecoration(
          isDense: true,
          hintText: t.pasteHubServerToken,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          suffixIcon: widget.enabled
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.controller.text.isEmpty)
                      IconButton(
                        icon: const Icon(Icons.content_paste, size: 16),
                        tooltip: t.paste,
                        onPressed: () async {
                          final data = await Clipboard.getData(
                            Clipboard.kTextPlain,
                          );
                          final text = data?.text?.trim() ?? '';
                          if (text.isNotEmpty) {
                            widget.controller.text = text;
                            widget.onChanged(text);
                            setState(() {});
                          }
                        },
                      ),
                    if (widget.controller.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        tooltip: t.clear,
                        onPressed: () {
                          widget.controller.clear();
                          widget.onChanged('');
                          setState(() {});
                        },
                      ),
                  ],
                ),
        ),
        onChanged: (v) {
          widget.onChanged(v.trim());
          setState(() {});
        },
      ),
    );
  }
}

class _HostInput extends StatelessWidget {
  const _HostInput({
    required this.controller,
    required this.enabled,
    this.hintText,
    this.onChanged,
  });

  final TextEditingController controller;
  final bool enabled;
  final String? hintText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.url,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: enabled
            ? colorScheme.onSurface
            : colorScheme.onSurface.toOpacity(0.35),
      ),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: colorScheme.surface,
        hintText: hintText,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: colorScheme.primary.toOpacity(0.6),
            width: 1.5,
          ),
        ),
      ),
      onChanged: onChanged,
    );
  }
}

/// Web 管理后台设置二级页面：说明 + 开关 + 端口 + 打开
class _WebAdminSettingsPage extends ConsumerStatefulWidget {
  const _WebAdminSettingsPage();

  @override
  ConsumerState<_WebAdminSettingsPage> createState() =>
      _WebAdminSettingsPageState();
}

class _WebAdminSettingsPageState extends ConsumerState<_WebAdminSettingsPage> {
  late final TextEditingController _portCtrl;

  bool get _enabled =>
      appdata.implicitData['hub_web_admin_enabled'] as bool? ?? false;

  int get _port => appdata.implicitData['hub_web_admin_port'] as int? ?? 9200;

  HubService get _hub => ref.read(hubServiceProvider);

  @override
  void initState() {
    super.initState();
    _portCtrl = TextEditingController(text: '$_port');
  }

  @override
  void dispose() {
    _portCtrl.dispose();
    super.dispose();
  }

  void _savePort() {
    final port = int.tryParse(_portCtrl.text.trim());
    if (port == null || port <= 0 || port > 65535) {
      _portCtrl.text = '$_port';
      return;
    }
    appdata.implicitData['hub_web_admin_port'] = port;
    appdata.writeImplicitData();
    if (mounted) setState(() {});
    App.rootContext.showMessage(message: t.restartHubToApply);
  }

  void _open() {
    launchUrl(
      Uri.parse('http://localhost:$_port'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(t.webAdminDashboard)),
      body: CustomScrollView(
        slivers: [
          _BuildSectionPadding(
            _SettingCard(
              children: [
                _SettingPartTitle(
                  title: t.webAdminWhatIs,
                  icon: Icons.info_outline,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    t.webAdminDescription,
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.toOpacity(0.7),
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _BuildSectionPadding(
            _SettingCard(
              children: [
                _SettingPartTitle(
                  title: t.webAdminSettings,
                  icon: Icons.settings_outlined,
                ),
                _SwitchSetting(
                  title: t.webAdminEnabled,
                  settingKey: 'hub_web_admin_enabled',
                  dataSource: SwitchDataSource.implicit,
                  subtitle: _enabled ? 'http://localhost:$_port' : t.disabled,
                  onChanged: () {
                    // 持久化已由 _SwitchSetting 完成，这里处理服务启停
                    if (appdata.implicitData['hub_web_admin_enabled'] == true) {
                      App.rootContext.showMessage(message: t.restartHubToApply);
                      _hub.startWebAdmin();
                    } else {
                      _hub.stopWebAdmin();
                    }
                    if (mounted) setState(() {});
                  },
                ),
                if (_enabled) ...[
                  _SettingRow(
                    title: t.webAdminPort,
                    trailing: SizedBox(
                      width: 120,
                      child: TextField(
                        controller: _portCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _savePort(),
                      ),
                    ),
                  ),
                  _SettingRow(
                    title: t.webAdminUrl,
                    subtitle: 'http://localhost:$_port',
                    trailing: IconButton(
                      icon: const Icon(Icons.open_in_new, size: 18),
                      tooltip: t.view,
                      onPressed: _open,
                    ),
                  ),
                ],
              ],
            ),
          ),
          _BuildSectionPadding(
            _SettingCard(
              children: [
                _SettingPartTitle(
                  title: t.webAdminFeatures,
                  icon: Icons.web_asset_outlined,
                ),
                for (final (icon, text) in [
                  (Icons.dashboard_outlined, t.webAdminFeatureOverview),
                  (Icons.meeting_room_outlined, t.webAdminFeatureRooms),
                  (Icons.people_outline, t.webAdminFeatureClients),
                  (Icons.article_outlined, t.webAdminFeatureLogs),
                  (Icons.tune, t.webAdminFeatureConfig),
                  (Icons.smart_toy_outlined, t.webAdminFeatureAi),
                  (Icons.webhook, t.webAdminFeatureWebhooks),
                  (Icons.refresh, t.webAdminFeatureRestart),
                ])
                  _SettingRow(
                    title: text,
                    trailing: Icon(icon, size: 18, color: cs.primary),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// AI 陪聊机器人配置页（数据同步设置风格）
class _AiBotConfigPage extends ConsumerStatefulWidget {
  final String initialName;
  final String initialProvider;
  final String initialModel;
  final List<AiModel> initialModels;
  final int initialMinInterval;
  final bool initialReplyDm;
  final String initialTriggerMode;
  final String initialTriggerPattern;
  final void Function(
    String name,
    String provider,
    String model,
    String prompt,
    int minInterval,
    bool replyDm,
    String triggerMode,
    String triggerPattern,
  )
  onSave;

  const _AiBotConfigPage({
    required this.initialName,
    required this.initialProvider,
    required this.initialModel,
    required this.initialModels,
    required this.initialMinInterval,
    required this.initialReplyDm,
    required this.initialTriggerMode,
    required this.initialTriggerPattern,
    required this.onSave,
  });

  @override
  ConsumerState<_AiBotConfigPage> createState() => _AiBotConfigPageState();
}

class _AiBotConfigPageState extends ConsumerState<_AiBotConfigPage> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _promptCtrl;
  late final TextEditingController _triggerPatternCtrl;
  late String _provider;
  late String _model;
  late List<AiModel> _models;
  late int _minInterval;
  late bool _replyDm;
  late String _triggerMode;
  late final HubAiBotConfig _config;

  @override
  void initState() {
    super.initState();
    _config = HubAiBotConfig.load();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _promptCtrl = TextEditingController(text: _config.systemPrompt);
    _triggerPatternCtrl = TextEditingController(
      text: widget.initialTriggerPattern,
    );
    _provider = widget.initialProvider;
    _model = widget.initialModel;
    _models = widget.initialModels;
    _minInterval = widget.initialMinInterval;
    _replyDm = widget.initialReplyDm;
    _triggerMode = widget.initialTriggerMode;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _promptCtrl.dispose();
    _triggerPatternCtrl.dispose();
    super.dispose();
  }

  void _save() {
    widget.onSave(
      _nameCtrl.text,
      _provider,
      _model,
      _promptCtrl.text,
      _minInterval,
      _replyDm,
      _triggerMode,
      _triggerPatternCtrl.text,
    );
    App.rootPop();
  }

  @override
  Widget build(BuildContext context) {
    return PopUpWidgetScaffold(
      title: t.hubAiBotConfigTitle,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FormCard(
              children: [
                _FormSectionTitle(
                  title: t.hubAiBot,
                  icon: Icons.smart_toy_outlined,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameCtrl,
                  decoration: _formFieldDecoration(labelText: t.hubAiBotName),
                ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: t.hubAiBotProvider,
                    helperText: t.hubAiBotProviderHelper,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: DropdownButton<String>(
                    value: _provider,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final e
                          in OpenAiProviderRegistry.allProviders.entries)
                        DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value.name),
                        ),
                    ],
                    onChanged: (v) async {
                      if (v == null || v == _provider) return;
                      setState(() {
                        _provider = v;
                        _model = '';
                      });
                      final m = await AiDatabase.instance.aiModelDao
                          .getModelsByProvider(v);
                      if (mounted) setState(() => _models = m);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: t.hubAiBotModel,
                    helperText: t.hubAiBotModelHint,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: DropdownButton<String>(
                    value: _models.any((m) => m.modelId == _model)
                        ? _model
                        : null,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    hint: Text(t.hubAiBotModelHint),
                    items: [
                      DropdownMenuItem(
                        value: '',
                        child: Text(t.hubAiBotModelDefault),
                      ),
                      for (final m in _models)
                        DropdownMenuItem(
                          value: m.modelId,
                          child: Text(
                            m.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _model = v ?? ''),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _FormCard(
              children: [
                _FormSectionTitle(
                  title: t.hubAiBotSystemPrompt,
                  icon: Icons.notes_outlined,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _promptCtrl,
                  maxLines: 5,
                  decoration: _formFieldDecoration(
                    labelText: t.hubAiBotSystemPrompt,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _FormCard(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    t.hubAiBotTriggerMode,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  trailing: DropdownButton<String>(
                    value: _triggerMode,
                    underline: const SizedBox.shrink(),
                    items: [
                      DropdownMenuItem(
                        value: 'mention',
                        child: Text(t.hubAiBotTriggerMention),
                      ),
                      DropdownMenuItem(
                        value: 'prefix',
                        child: Text(t.hubAiBotTriggerPrefix),
                      ),
                      DropdownMenuItem(
                        value: 'keyword',
                        child: Text(t.hubAiBotTriggerKeyword),
                      ),
                      DropdownMenuItem(
                        value: 'all',
                        child: Text(t.hubAiBotTriggerAll),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _triggerMode = v ?? 'mention'),
                  ),
                ),
                if (_triggerMode == 'prefix' || _triggerMode == 'keyword') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _triggerPatternCtrl,
                    decoration: _formFieldDecoration(
                      labelText: t.hubAiBotTriggerPattern,
                      hintText: _triggerMode == 'prefix'
                          ? './'
                          : t.hubAiBotKeywordHint,
                    ),
                  ),
                ],
                const Divider(height: 24),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    t.hubAiBotMinInterval,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  trailing: DropdownButton<int>(
                    value: _minInterval.clamp(1, 30),
                    underline: const SizedBox.shrink(),
                    items: [
                      for (var s = 1; s <= 30; s++)
                        DropdownMenuItem(value: s, child: Text('$s s')),
                    ],
                    onChanged: (v) =>
                        setState(() => _minInterval = v ?? _minInterval),
                  ),
                ),
                const Divider(height: 24),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    t.hubAiBotReplyDm,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  trailing: CustomSwitch(
                    value: _replyDm,
                    onChanged: (v) => setState(() => _replyDm = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _FormSaveButton(onPressed: _save),
          ],
        ),
      ),
    );
  }
}
