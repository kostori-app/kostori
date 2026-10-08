import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/pages/download/local_player_controller.dart';
import 'package:kostori/pages/download/local_player_page.dart';

class _TestPlayer extends LocalPlayerController {
  _TestPlayer(super.filePath);

  @override
  LocalPlayerState build() => const LocalPlayerState(error: 'initial');

  void fail(String message) => state = state.copyWith(error: message);
}

void main() {
  testWidgets(
    'failed loopback playback retries the disk path and disposes once',
    (tester) async {
      const streamUrl = 'http://127.0.0.1:37473/stream?fileIndex=1';
      const localPath = '/storage/emulated/0/bt/renamed.mp4';
      late _TestPlayer source;
      late _TestPlayer local;
      var disposeCount = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localPlayerControllerProvider(streamUrl)
                .overrideWith(() => source = _TestPlayer(streamUrl)),
            localPlayerControllerProvider(localPath)
                .overrideWith(() => local = _TestPlayer(localPath)),
          ],
          child: MaterialApp(
            home: LocalPlayerPage(
              filePath: streamUrl,
              fallbackFilePath: localPath,
              onDispose: () => disposeCount++,
            ),
          ),
        ),
      );
      source.fail('Failed to open $streamUrl.');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(
        tester.widget<LocalPlayerView>(find.byType(LocalPlayerView)).filePath,
        localPath,
      );
      expect(disposeCount, 0);
      local.fail('Failed to open $localPath.');
      await tester.pump();
      expect(
        tester.widget<LocalPlayerView>(find.byType(LocalPlayerView)).filePath,
        localPath,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(disposeCount, 1);
    },
  );
}
