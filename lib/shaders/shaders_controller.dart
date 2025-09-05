// ignore_for_file: library_private_types_in_public_api

import 'dart:io';

import 'package:flutter/services.dart' show rootBundle, AssetManifest;
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/log.dart';
import 'package:mobx/mobx.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

part 'shaders_controller.g.dart';

class ShadersController = _ShadersController with _$ShadersController;

abstract class _ShadersController with Store {
  late Directory shadersDirectory;

  Future<void> copyShadersToExternalDirectory() async {
    final assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = assetManifest.listAssets();
    final directory = await getApplicationSupportDirectory();
    shadersDirectory = Directory(path.join(directory.path, 'anime_shaders'));

    if (!await shadersDirectory.exists()) {
      await shadersDirectory.create(recursive: true);
      if (appdata.settings['debugInfo']) {
        Log.addLog(
          LogLevel.info,
          "shadersDirectory create",
          'Create GLSL Shader: ${shadersDirectory.path}',
        );
      }
    }

    final shaderFiles = assets.where(
      (String asset) =>
          asset.startsWith('assets/shaders/') && asset.endsWith('.glsl'),
    );

    int copiedFilesCount = 0;

    for (var filePath in shaderFiles) {
      final fileName = filePath.split('/').last;
      final targetFile = File(path.join(shadersDirectory.path, fileName));
      if (await targetFile.exists()) {
        if (appdata.settings['debugInfo']) {
          Log.addLog(
            LogLevel.info,
            "targetFile exists",
            'GLSL Shader exists, skip: ${targetFile.path}',
          );
        }
        continue;
      }

      try {
        final data = await rootBundle.load(filePath);
        final List<int> bytes = data.buffer.asUint8List();
        await targetFile.writeAsBytes(bytes);
        copiedFilesCount++;
        if (appdata.settings['debugInfo']) {
          Log.addLog(
            LogLevel.info,
            "targetFile writeAsBytes",
            'Copy: ${targetFile.path}',
          );
        }
      } catch (e) {
        Log.addLog(
          LogLevel.warning,
          "targetFile writeAsBytes",
          'Copy: ($filePath): $e',
        );
      }
    }
    if (appdata.settings['debugInfo']) {
      Log.addLog(
        LogLevel.info,
        "copyShadersToExternalDirectory",
        '$copiedFilesCount GLSL files copied to ${shadersDirectory.path}',
      );
    }
  }
}
