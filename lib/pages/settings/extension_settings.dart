// 扩展管理设置（改造点 7 修订）：
// AI 设置一级页 → 扩展管理设置二级页，容纳 4 个可编辑区块：
// ① 辅助任务模型 ② 角色管理（提示词注入 + 世界书）③ MCP 服务器 ④ 技能。
// 本文件为二级页 + MCP/技能区块；角色管理页见 role_management_settings.dart。

part of 'settings_page.dart';

class ExtensionSettingsPage extends StatelessWidget {
  const ExtensionSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SmoothCustomScrollView(
      slivers: [
        SliverAppbar(
          title: Text(t.extensionManagement),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            tooltip: t.back,
            onPressed: () => context.canPop() ? context.pop() : App.pop(),
          ),
        ),

        // ── 提示词（提示词注入 + 世界书）────────
        _BuildSectionPadding(
          _SettingCard(
            children: [
              _SettingPartTitle(
                title: t.promptManagement,
                icon: Icons.style_outlined,
              ),
              ListTile(
                leading: const Icon(Icons.auto_awesome_outlined),
                title: Text(t.promptManagement),
                subtitle: Text(
                  '${t.promptInjection} / ${t.worldBook}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.arrow_right, size: 20),
                onTap: () => App.rootContext.to(
                  () => const PromptManagementSettingsPage(),
                ),
              ),
            ],
          ),
        ),

        // ── 辅助任务模型 ─────────────────────────
        _BuildSectionPadding(
          _SettingCard(
            children: [
              _SettingPartTitle(
                title: t.auxModelSettings,
                icon: Icons.auto_awesome_mosaic_outlined,
              ),
              _AuxTaskTile(
                taskKey: 'compress',
                icon: Icons.compress,
                title: t.contextCompression,
              ),
              _AuxTaskTile(
                taskKey: 'followUps',
                icon: Icons.tips_and_updates_outlined,
                title: t.followUpSuggestions,
              ),
              _AuxTaskTile(
                taskKey: 'title',
                icon: Icons.title,
                title: t.autoTitle,
              ),
            ],
          ),
        ),

        // ── MCP 服务器 ───────────────────────────
        _BuildSectionPadding(_McpServersBlock()),

        // ── 技能 ──────────────────────────────────
        _BuildSectionPadding(_SkillsBlock()),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// 技能 导入（自文件/文件夹解析 SKILL.md）
// ─────────────────────────────────────────────

Future<void> _importSkills(BuildContext context) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (_) => Sheet(
      title: t.importSkills,
      icon: Icons.file_open_outlined,
      initialSize: 0.38,
      builder: (ctx, sc) => ListView(
        controller: sc,
        shrinkWrap: true,
        children: [
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(t.importSkillsFromFiles),
            subtitle: Text(
              t.importSkillsFromFilesHint,
              style: const TextStyle(fontSize: 12),
            ),
            onTap: () => Navigator.pop(ctx, 'files'),
          ),
          if (App.isDesktop)
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(t.importSkillsFromFolder),
              subtitle: Text(
                t.importSkillsFromFolderHint,
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () => Navigator.pop(ctx, 'folder'),
            ),
        ],
      ),
    ),
  );
  if (action == null) return;

  final entries = <({String name, String content})>[];
  if (action == 'files') {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['md'],
    );
    if (result == null || result.files.isEmpty) return;
    for (final f in result.files) {
      try {
        final content = f.path != null
            ? await io.File(f.path!).readAsString()
            : utf8.decode(await f.readAsBytes());
        entries.add((name: f.name, content: content));
      } catch (_) {
        continue;
      }
    }
  } else {
    final dir = await selectDirectory();
    if (dir == null) return;
    final skillMd = io.File(path.join(dir, 'SKILL.md'));
    if (!skillMd.existsSync()) {
      App.rootContext.showMessage(
        message: t.noSkillFileFound,
        level: LogLevel.warning,
      );
      return;
    }
    entries.add((name: 'SKILL.md', content: await skillMd.readAsString()));
  }
  if (entries.isEmpty) return;

  App.rootContext.showMessage(message: t.importingSkills);

  var imported = 0;
  var skipped = 0;
  var seq = 0;
  final now = DateTime.now().millisecondsSinceEpoch;
  final usedKeys = <String>{};
  final companions = <AiSkillsCompanion>[];
  for (final entry in entries) {
    final parsed = _parseSkillMarkdown(entry.content, entry.name);
    if (parsed == null) {
      skipped++;
      continue;
    }
    var key = _slugifySkillKey(parsed.name);
    if (key.isEmpty) key = 'skill_$now';
    while (!usedKeys.add(key)) {
      key = '${key}_${++seq}';
    }
    companions.add(
      AiSkillsCompanion.insert(
        key: key,
        name: parsed.name,
        description: Value(parsed.description),
        systemPrompt: parsed.body,
        isBuiltin: const Value(false),
        isEnabled: const Value(true),
      ),
    );
    imported++;
  }
  if (companions.isNotEmpty) {
    await AiDatabase.instance.aiSkillDao.upsertAll(companions);
  }
  App.rootContext.showMessage(
    message: skipped == 0
        ? t.importedSkillCount(count: imported)
        : t.importedSkillCountSkipped(imported: imported, skipped: skipped),
    level: imported == 0 ? LogLevel.warning : LogLevel.info,
  );
}

// ─────────────────────────────────────────────
// MCP 服务器 区块（含连接探测）
// ─────────────────────────────────────────────

class _McpServersBlock extends StatefulWidget {
  const _McpServersBlock();

  @override
  State<_McpServersBlock> createState() => _McpServersBlockState();
}

class _McpServersBlockState extends State<_McpServersBlock> {
  final Map<int, ({bool ok, int toolCount, String error})> _probes = {};
  final Set<int> _probing = {};
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _kick();
  }

  Future<void> _kick() async {
    final servers = await AiDatabase.instance.aiMcpServerDao.getAll();
    if (!mounted) return;
    for (final s in servers) {
      if (!_probes.containsKey(s.id)) {
        await _probe(s);
      }
    }
  }

  Future<void> _probe(AiMcpServer server) async {
    setState(() => _probing.add(server.id));
    final result = await McpManager.probeServer(server);
    if (!mounted) return;
    setState(() {
      _probes[server.id] = result;
      _probing.remove(server.id);
    });
  }

  Future<void> _refresh() async {
    setState(() => _syncing = true);
    McpManager.invalidateCache();
    await SkillRegistry.instance.syncMcp();
    final servers = await AiDatabase.instance.aiMcpServerDao.getAll();
    for (final s in servers) {
      await _probe(s);
    }
    if (!mounted) return;
    setState(() => _syncing = false);
    App.rootContext.showMessage(message: t.saved);
  }

  @override
  Widget build(BuildContext context) {
    return _SettingCard(
      children: [
        _SettingPartTitle(
          title: t.mcpServers,
          icon: Icons.dns_outlined,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: _syncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: PolygonRefreshIndicator(),
                      )
                    : const Icon(Icons.refresh),
                tooltip: t.mcpReconnect,
                onPressed: _syncing ? null : _refresh,
              ),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: t.newMcpServer,
                onPressed: () async {
                  await showPopUpWidget(
                    App.rootContext,
                    const _McpServerEditor(),
                  );
                  if (mounted) _kick();
                },
              ),
            ],
          ),
        ),
        StreamBuilder<List<AiMcpServer>>(
          stream: AiDatabase.instance.aiMcpServerDao.watchAll(),
          builder: (context, snapshot) {
            final servers = snapshot.data ?? [];
            if (servers.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(t.noMcpServers, style: ts.s12),
              );
            }
            return Column(
              children: servers
                  .map(
                    (s) => _McpServerExtensionTile(
                      server: s,
                      probing: _probing.contains(s.id),
                      probe: _probes[s.id],
                      onProbe: () => _probe(s),
                      onEdit: () async {
                        await showPopUpWidget(
                          App.rootContext,
                          _McpServerEditor(server: s),
                        );
                        McpManager.invalidateCache();
                        if (mounted) {
                          _probes.remove(s.id);
                          await _probe(s);
                        }
                      },
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _McpServerExtensionTile extends StatelessWidget {
  const _McpServerExtensionTile({
    required this.server,
    required this.probing,
    required this.probe,
    required this.onProbe,
    required this.onEdit,
  });

  final AiMcpServer server;
  final bool probing;
  final ({bool ok, int toolCount, String error})? probe;
  final VoidCallback onProbe;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final endpoint = server.transport == 'stdio'
        ? (server.command ?? '-')
        : (server.url ?? '-');
    final transportLabel = switch (server.transport) {
      'stdio' => t.stdio,
      'sse' => t.sse,
      _ => t.http,
    };

    final (statusText, statusColor) = probing
        ? (t.mcpConnecting, scheme.outline)
        : probe == null
        ? (t.mcpTestConnection, scheme.outline)
        : probe!.ok
        ? (t.mcpConnected, Colors.green)
        : (t.mcpConnectionFailed, Colors.orange);

    return ListTile(
      title: Text(
        server.name,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$transportLabel · $endpoint',
            style: TextStyle(color: scheme.outline, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(
                probe == null
                    ? Icons.help_outline
                    : (probe!.ok
                          ? Icons.check_circle_outline
                          : Icons.error_outline),
                size: 12,
                color: statusColor,
              ),
              const SizedBox(width: 4),
              Text(
                statusText,
                style: TextStyle(fontSize: 11, color: statusColor),
              ),
              if (probe != null && probe!.ok) ...[
                const SizedBox(width: 8),
                Text(
                  '${probe!.toolCount} ${t.mcpToolsImported}',
                  style: TextStyle(fontSize: 11, color: scheme.outline),
                ),
              ],
              if (probe != null && !probe!.ok) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    probe!.error,
                    style: TextStyle(fontSize: 11, color: scheme.outline),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            server.isEnabled ? t.enabled : t.disabled,
            style: TextStyle(
              fontSize: 12,
              color: server.isEnabled ? Colors.green : Colors.orange,
            ),
          ),
          IconButton(
            icon: Icon(probing ? Icons.sync : Icons.wifi_tethering, size: 18),
            tooltip: t.mcpTestConnection,
            onPressed: probing ? null : onProbe,
          ),
          const Icon(Icons.arrow_right, size: 20),
        ],
      ),
      onTap: onEdit,
    );
  }
}

// ─────────────────────────────────────────────
// 技能 区块（含启用开关）
// ─────────────────────────────────────────────

class _SkillsBlock extends StatefulWidget {
  const _SkillsBlock();

  @override
  State<_SkillsBlock> createState() => _SkillsBlockState();
}

class _SkillsBlockState extends State<_SkillsBlock> {
  @override
  Widget build(BuildContext context) {
    return _SettingCard(
      children: [
        _SettingPartTitle(
          title: t.skills,
          icon: Icons.auto_awesome_outlined,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.file_open_outlined),
                tooltip: t.importSkills,
                onPressed: () => _importSkills(context),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: t.newSkill,
                onPressed: () =>
                    showPopUpWidget(App.rootContext, const _SkillEditor()),
              ),
            ],
          ),
        ),
        StreamBuilder<List<AiSkill>>(
          stream: AiDatabase.instance.aiSkillDao.watchAll(),
          builder: (context, snapshot) {
            final skills = snapshot.data ?? [];
            if (skills.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(t.noSkillsYet, style: ts.s12),
              );
            }
            return Column(
              children: skills
                  .map((s) => _SkillExtensionTile(skill: s))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _SkillExtensionTile extends StatelessWidget {
  const _SkillExtensionTile({required this.skill});

  final AiSkill skill;

  @override
  Widget build(BuildContext context) {
    final description = skill.description?.isNotEmpty == true
        ? skill.description!
        : skill.key;

    return ListTile(
      title: Row(
        children: [
          Expanded(
            child: Text(
              skill.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          if (skill.isBuiltin)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: context.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                t.builtin,
                style: TextStyle(
                  fontSize: 10,
                  color: context.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(
        description,
        style: TextStyle(color: context.colorScheme.outline, fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomSwitch(
            value: skill.isEnabled,
            onChanged: (v) =>
                AiDatabase.instance.aiSkillDao.setEnabled(skill.id, enabled: v),
          ),
          const Icon(Icons.arrow_right, size: 20),
        ],
      ),
      onTap: () => showPopUpWidget(App.rootContext, _SkillEditor(skill: skill)),
    );
  }
}
