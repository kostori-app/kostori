import 'package:flutter/material.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/pages/download/local_player_page.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// 下载记录弹窗：展示某番剧已下载的集，支持本地播放 / 外部播放
class DownloadRecordsSheet extends StatelessWidget {
  final List<Map<String, dynamic>> records;

  const DownloadRecordsSheet({super.key, required this.records});

  void _play(BuildContext context, Map<String, dynamic> record) {
    final path = record['filePath'] as String?;
    if (path == null || path.isEmpty) return;
    Navigator.pop(context);
    App.mainNavigatorKey?.currentContext?.to(
      () => LocalPlayerPage(filePath: path),
    );
  }

  Future<void> _openExternal(Map<String, dynamic> record) async {
    final path = record['filePath'] as String?;
    if (path == null || path.isEmpty) return;
    try {
      await launchUrlString('file://$path');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              t.downloadRecords,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: records.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                final r = records[index];
                final title = r['title'] as String? ?? '';
                final episode = r['episode'] as String? ?? '';
                final resolution = r['resolution'] as String? ?? '';
                return ListTile(
                  leading: const Icon(Icons.download_done, color: Colors.green),
                  title: Text(
                    episode.isNotEmpty
                        ? '$title · $episode'
                              '${resolution.isNotEmpty ? ' · $resolution' : ''}'
                        : title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    (r['time'] as String? ?? '').replaceAll('T', ' ').substring(0, 16),
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: IconButton(
                    tooltip: t.openWithOtherPlayer,
                    icon: Icon(Icons.open_in_new, color: colorScheme.primary),
                    onPressed: () => _openExternal(r),
                  ),
                  onTap: () => _play(context, r),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
