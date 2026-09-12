part of 'ai_hub_page.dart';

// ═════════════════════════════════════════════
// 模块：AI 扮演（复用助手档案 + AI 聊天 + 世界书）
// ═════════════════════════════════════════════

class CharacterPage extends ConsumerStatefulWidget {
  const CharacterPage({super.key});

  @override
  ConsumerState<CharacterPage> createState() => _CharacterPageState();
}

class _CharacterPageState extends ConsumerState<CharacterPage> {
  @override
  void initState() {
    super.initState();
    AssistantProfileStore.instance.init();
  }

  Future<void> _add() async {
    await openAssistantProfileEditor();
    if (mounted) setState(() {});
  }

  Future<void> _edit(AssistantProfile p) async {
    await openAssistantProfileEditor(profile: p);
    if (mounted) setState(() {});
  }

  Future<void> _delete(AssistantProfile p) async {
    final ok = await AssistantProfileStore.instance.remove(p.id);
    if (!ok && mounted) {
      App.rootContext.showMessage(
        message: t.cannotDeletePreset,
        level: LogLevel.warning,
      );
    }
    if (mounted) setState(() {});
  }

  Future<void> _copy(AssistantProfile p) async {
    await AssistantProfileStore.instance.copy(p.id);
    if (mounted) setState(() {});
  }

  /// 导入角色卡：支持 SillyTavern 的 JSON 或 PNG（tEXt:chara）
  Future<void> _import() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'png'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    try {
      final bytes = await file.readAsBytes();
      final ext = (file.extension ?? '').toLowerCase();
      final jsonText = ext == 'png' ? _extractPngChara(bytes) : utf8.decode(bytes);
      if (jsonText == null || jsonText.trim().isEmpty) {
        throw 'no character data';
      }
      final profile = _profileFromCard(jsonDecode(jsonText));
      await AssistantProfileStore.instance.upsert(profile);
      if (mounted) {
        App.rootContext.showMessage(message: t.saved);
        setState(() {});
      }
    } catch (e) {
      Log.error('importCharacter', e.toString());
      if (mounted) {
        App.rootContext.showMessage(
          message: t.characterImportFailed,
          level: LogLevel.error,
        );
      }
    }
  }

  AssistantProfile _profileFromCard(dynamic decoded) {
    final Map<String, dynamic> data;
    if (decoded is Map && decoded['data'] is Map) {
      data = (decoded['data'] as Map).cast<String, dynamic>();
    } else if (decoded is Map) {
      data = decoded.cast<String, dynamic>();
    } else {
      throw 'invalid card';
    }
    final name =
        data['name']?.toString() ??
        data['char_name']?.toString() ??
        'Character';
    final parts = <String>[
      if ((data['description'] ?? '').toString().trim().isNotEmpty)
        data['description'].toString().trim(),
      if ((data['personality'] ?? '').toString().trim().isNotEmpty)
        '性格：${data['personality']}',
      if ((data['scenario'] ?? '').toString().trim().isNotEmpty)
        '场景：${data['scenario']}',
    ];
    return AssistantProfile(
      id: 'char_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      icon: '🎭',
      persona: parts.join('\n\n'),
      systemPrompt: data['system_prompt']?.toString() ?? '',
      isBuiltin: false,
    );
  }

  /// 从 PNG 的 tEXt 块中提取 `chara`（base64 编码的角色卡 JSON）
  String? _extractPngChara(Uint8List bytes) {
    var i = 8; // 跳过 PNG 签名
    while (i + 8 <= bytes.length) {
      final len =
          (bytes[i] << 24) |
          (bytes[i + 1] << 16) |
          (bytes[i + 2] << 8) |
          bytes[i + 3];
      final type = String.fromCharCodes(bytes.sublist(i + 4, i + 8));
      final dataStart = i + 8;
      final dataEnd = dataStart + len;
      if (dataEnd > bytes.length) break;
      if (type == 'tEXt') {
        final data = bytes.sublist(dataStart, dataEnd);
        final nul = data.indexOf(0);
        if (nul > 0) {
          final keyword = String.fromCharCodes(data.sublist(0, nul));
          if (keyword == 'chara') {
            final b64 = String.fromCharCodes(data.sublist(nul + 1));
            return utf8.decode(base64Decode(b64.trim()));
          }
        }
      }
      i = dataEnd + 4; // 跳过 CRC
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbar(
        title: Text(t.rolePlay),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_open_outlined),
            tooltip: t.importCharacter,
            onPressed: _import,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: Text(t.add),
      ),
      body: ListenableBuilder(
        listenable: AssistantProfileStore.instance,
        builder: (context, _) {
          final profiles = AssistantProfileStore.instance.profiles;
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            children: [
              _worldBookEntry(context),
              const SizedBox(height: 8),
              for (final p in profiles)
                _CharacterCard(
                  profile: p,
                  onTap: () => context.to(
                    () => AiChatPage(initialProfileId: p.id, fresh: true),
                  ),
                  onEdit: () => _edit(p),
                  onCopy: () => _copy(p),
                  onDelete: p.isPreset ? null : () => _delete(p),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _worldBookEntry(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant, width: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Icon(Icons.menu_book_outlined, color: scheme.primary),
        title: Text(t.promptManagement),
        subtitle: Text(
          '${t.promptInjection} / ${t.worldBook}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.to(() => const PromptManagementSettingsPage()),
      ),
    );
  }
}

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({
    required this.profile,
    required this.onTap,
    required this.onEdit,
    required this.onCopy,
    this.onDelete,
  });

  final AssistantProfile profile;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onCopy;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final preview = profile.persona.trim().isNotEmpty
        ? profile.persona
        : profile.systemPrompt;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant, width: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Text(profile.icon, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            profile.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (profile.isPreset) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              t.builtin,
                              style: TextStyle(
                                fontSize: 9,
                                color: scheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (preview.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        preview.replaceAll('\n', ' '),
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                tooltip: t.more,
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'copy') onCopy();
                  if (v == 'delete') onDelete?.call();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text(t.edit)),
                  PopupMenuItem(value: 'copy', child: Text(t.copy)),
                  if (onDelete != null)
                    PopupMenuItem(value: 'delete', child: Text(t.delete)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
