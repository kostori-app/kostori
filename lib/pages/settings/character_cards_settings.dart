// 角色卡库（扩展管理）：导入 / 查看 / 编辑 / 导出，酒馆兼容。
// 故事内角色与该库共用 CharacterCard 模型。

part of 'settings_page.dart';

class CharacterCardsSettingsPage extends StatefulWidget {
  const CharacterCardsSettingsPage({super.key});

  @override
  State<CharacterCardsSettingsPage> createState() =>
      _CharacterCardsSettingsPageState();
}

class _CharacterCardsSettingsPageState
    extends State<CharacterCardsSettingsPage> {
  @override
  void initState() {
    super.initState();
    CharacterCardStore.instance.init();
  }

  Future<void> _import() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'png'],
    );
    if (result == null || result.files.isEmpty) return;
    try {
      final bytes = await result.files.first.readAsBytes();
      final card = CharacterCard.fromBytes(bytes);
      if (card == null) {
        App.rootContext.showMessage(
          message: t.characterImportFailed,
          level: LogLevel.error,
        );
        return;
      }
      await CharacterCardStore.instance.upsert(card);
      if (mounted) setState(() {});
      App.rootContext.showMessage(message: t.storyImported);
    } catch (e) {
      App.rootContext.showMessage(
        message: t.characterImportFailed,
        level: LogLevel.error,
      );
    }
  }

  Future<void> _edit(CharacterCard? card) async {
    final result = await showCharacterCardEditor(App.rootContext, card);
    if (result == null) return;
    await CharacterCardStore.instance.upsert(result);
    if (mounted) setState(() {});
  }

  Future<void> _export(CharacterCard card, int spec) async {
    await exportCharacterCardPng(card, spec: spec);
  }

  @override
  Widget build(BuildContext context) {
    final store = CharacterCardStore.instance;
    return Column(
      children: [
        Appbar(
          title: Text(t.characterCards),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            tooltip: t.back,
            onPressed: () => context.canPop() ? context.pop() : App.pop(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.file_open_outlined),
              tooltip: t.importEntries,
              onPressed: _import,
            ),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: t.storyAddCharacter,
              onPressed: () => _edit(null),
            ),
          ],
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: store,
            builder: (context, _) {
              final cards = store.cards;
              if (cards.isEmpty) {
                return Center(
                  child: Text(
                    t.characterCardsEmpty,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final c in cards)
                    _SettingCard(
                      padding: EdgeInsets.zero,
                      children: [
                        ListTile(
                          leading: CharacterAvatar(
                            name: c.name,
                            avatar: c.avatar,
                            radius: 20,
                          ),
                          title: Text(c.name),
                          subtitle: c.tags.isNotEmpty
                              ? Text(
                                  c.tags.join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : (c.description.isEmpty
                                    ? null
                                    : Text(
                                        c.description,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      )),
                          onTap: () => showCharacterCardView(context, c),
                          trailing: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 20),
                            onSelected: (v) {
                              if (v == 'edit') _edit(c);
                              if (v == 'export_v3') _export(c, 3);
                              if (v == 'export_v2') _export(c, 2);
                              if (v == 'delete') store.remove(c.id);
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(value: 'edit', child: Text(t.edit)),
                              PopupMenuItem(
                                value: 'export_v3',
                                child: Text(t.characterExportV3),
                              ),
                              PopupMenuItem(
                                value: 'export_v2',
                                child: Text(t.characterExportV2),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(t.delete),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
