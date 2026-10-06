import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/services/torrent/torrent_file_selection.dart';
import 'package:kostori/services/torrent/torrent_manager.dart';

void main() {
  test('long press selects an inclusive range and repeats to deselect it', () {
    final selection = TorrentFileSelection();
    const order = [1, 2, 3, 4, 5, 6];
    selection.tap(1);
    selection.longPress(6, order);
    expect(selection.selected, {1, 2, 3, 4, 5, 6});
    selection.longPress(3, order);
    expect(selection.selected, {1, 2});
  });

  test('torrent file names reject path traversal and Windows device names', () {
    expect(TorrentManager.isValidFileName('episode 01.mkv'), isTrue);
    expect(TorrentManager.isValidFileName('../episode.mkv'), isFalse);
    expect(TorrentManager.isValidFileName('CON.txt'), isFalse);
    expect(TorrentManager.isValidFileName('episode/.mkv'), isFalse);
  });
}
