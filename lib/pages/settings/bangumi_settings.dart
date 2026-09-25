part of 'settings_page.dart';

class BangumiSettings extends StatefulWidget {
  const BangumiSettings({super.key});

  @override
  State<BangumiSettings> createState() => _BangumiSettingsState();
}

class _BangumiSettingsState extends State<BangumiSettings> {
  bool get _loggedIn => bangumiLoggedIn;

  bool _loadingToken = false;

  Future<void> _refreshToken() async {
    setState(() => _loadingToken = true);
    final ok = await bangumiRefreshToken();
    if (!mounted) return;
    setState(() => _loadingToken = false);
    context.showMessage(
      message: ok ? t.bangumiTokenRefreshSuccess : t.bangumiTokenRefreshFailed,
    );
  }

  String _tokenInfoText(Map<String, dynamic>? info) {
    final parts = <String>[];
    final userId = info?['user_id']?.toString();
    if (userId != null && userId.isNotEmpty) {
      parts.add('${t.bangumiUserId}: $userId');
    }
    final exp = info?['expires'];
    final expires = exp is num
        ? DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000)
        : null;
    if (expires != null) {
      final left = expires.difference(DateTime.now());
      final text = left.isNegative
          ? t.bangumiTokenExpired
          : left.inDays > 0
          ? '${left.inDays}d ${left.inHours % 24}h'
          : left.inHours > 0
          ? '${left.inHours}h ${left.inMinutes % 60}m'
          : '${left.inMinutes}m';
      parts.add('${t.bangumiTokenExpires}: $text');
    }
    return parts.isEmpty ? t.bangumiOAuthHint : parts.join('  ·  ');
  }

  @override
  Widget build(BuildContext context) {
    return SmoothCustomScrollView(
      slivers: [
        SliverAppbar(title: Text(t.bangumi)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                _SettingCard(
                  children: [
                    _SettingPartTitle(
                      title: t.bangumi,
                      icon: Icons.radio_button_unchecked_outlined,
                    ),
                    _SwitchSetting(
                      title: t.showAnimeCardOverlay,
                      settingKey: "showAnimeCardOverlay",
                      dataSource: SwitchDataSource.implicit,
                      onChanged: () => setState(() {}),
                    ),
                    _IntSliderSetting(
                      title: t.bangumiCardPerRow,
                      settingsIndex: "bangumiCardPerRow",
                      options: [0, 2, 3],
                      dataSource: SwitchDataSource.implicit,
                    ),
                    _SettingRow(
                      title: t.displayModeOfAnimeTile,
                      // bangumi 只有简洁/瀑布流两种卡片，无详细卡片
                      trailing: _DisplayModeSelector(
                        value:
                            appdata.implicitData['bangumiDisplayMode'] ??
                            'brief',
                        options: [('brief', t.brief), ('masonry', t.masonry)],
                        onChanged: (v) {
                          appdata.implicitData['bangumiDisplayMode'] = v;
                          appdata.writeImplicitData();
                          if (mounted) setState(() {});
                          App.forceRebuild();
                        },
                      ),
                    ),
                    _SwitchSetting(
                      title: t.calendarFetchEpisodes,
                      settingKey: "calendarFetchEpisodes",
                    ),
                    _SwitchSetting(
                      title: t.enableSkipBangumiSchedule,
                      settingKey: "enableSkipUpdate",
                    ),
                    _SwitchSetting(
                      title: t.bangumiShowNsfw,
                      settingKey: "bangumiShowNsfw",
                      dataSource: SwitchDataSource.implicit,
                      defaultValue: true,
                      onChanged: () => setState(() {}),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // ── Bangumi OAuth2 登录（独立卡片，回调地址写死）──
                _SettingCard(
                  children: [
                    _SettingPartTitle(
                      title: 'Bangumi OAuth',
                      icon: Icons.key_outlined,
                    ),
                    ValueListenableBuilder<Map<String, dynamic>?>(
                      valueListenable: bangumiTokenStatusNotifier,
                      builder: (context, tokenStatus, _) => ListTile(
                        title: Text(
                          _loggedIn ? t.bangumiLoggedIn : t.bangumiNotLoggedIn,
                          style: const TextStyle(fontSize: 13),
                        ),
                        subtitle: Text(
                          _loggedIn
                              ? _tokenInfoText(tokenStatus)
                              : t.bangumiOAuthHint,
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: _loggedIn
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _loadingToken
                                      ? const SizedBox(
                                          width: 32,
                                          height: 32,
                                          child: Center(
                                            child: SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: PolygonRefreshIndicator(),
                                            ),
                                          ),
                                        )
                                      : IconButton(
                                          icon: const Icon(
                                            Icons.refresh,
                                            size: 20,
                                          ),
                                          tooltip: t.bangumiRefreshToken,
                                          onPressed: _refreshToken,
                                        ),
                                  OutlinedButton(
                                    onPressed: () {
                                      bangumiOAuthLogout();
                                      setState(() {});
                                    },
                                    child: Text(t.bangumiOAuthLogout),
                                  ),
                                ],
                              )
                            : FilledButton(
                                onPressed: () async {
                                  await bangumiOAuthLogin(context);
                                  if (!mounted) return;
                                  setState(() {});
                                  if (bangumiLoggedIn) {
                                    await refreshBangumiTokenStatus();
                                  }
                                },
                                child: Text(t.bangumiOAuthLogin),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
