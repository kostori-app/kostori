import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:path_provider/path_provider.dart';
import 'package:zip_flutter/zip_flutter.dart';

import '../../base.dart';
import '../../foundation/app.dart';
import '../../foundation/log.dart';
import '../components/components.dart';
import '../foundation/cache_manager.dart';
import '../network/download.dart';

Future<double> getFolderSize(Directory path) async {
  double total = 0;
  for (var f in path.listSync(recursive: true)) {
    if (FileSystemEntity.typeSync(f.path) == FileSystemEntityType.file) {
      total += File(f.path).lengthSync() / 1024 / 1024;
    }
  }
  return total;
}

// Future<bool> exportComic(String id, String name,
//     [List<String>? epNames]) async {
//   try {
//     name = sanitizeFileName(name);
//     var data = ExportComicData(
//       id,
//       downloadManager.path!,
//       name,
//       epNames,
//       downloadManager.getDirectory(id),
//     );
//     var res = await compute(runningExportComic, data);
//     if (!res) {
//       return false;
//     }
//
//     if (App.isMobile) {
//       var params = SaveFileDialogParams(
//           sourceFilePath: '${data.path}$pathSep$name.zip');
//       await FlutterFileDialog.saveFile(params: params);
//     } else {
//       final FileSaveLocation? result =
//       await getSaveLocation(suggestedName: '$name.zip');
//
//       if (result != null) {
//         const String mimeType = 'application/zip';
//         final XFile textFile =
//         XFile('${data.path}$pathSep$name.zip', mimeType: mimeType);
//         await textFile.saveTo(result.path);
//       }
//     }
//
//     var file = File('${data.path}$pathSep$name.zip');
//     file.delete();
//     return true;
//   } catch (e) {
//     return false;
//   }
// }

// Future<bool> exportComics(List<DownloadedItem> comics) async {
//   try {
//     var exportDatas = <ExportComicData>[];
//     for (var comic in comics) {
//       var id = comic.id;
//       var name = sanitizeFileName(comic.name);
//       var path = downloadManager.path;
//       var epNames = comic.eps;
//       exportDatas.add(ExportComicData(
//         id,
//         path!,
//         name,
//         epNames,
//         downloadManager.getDirectory(id),
//       ));
//     }
//     await Isolate.run(() => runningExportComics(exportDatas));
//     if (App.isMobile) {
//       var params = SaveFileDialogParams(
//           sourceFilePath: '${downloadManager.path}/comics.zip');
//       await FlutterFileDialog.saveFile(params: params);
//     } else {
//       final FileSaveLocation? result =
//       await getSaveLocation(suggestedName: 'comics.zip');
//
//       if (result != null) {
//         const String mimeType = 'application/zip';
//         final XFile textFile =
//         XFile('${downloadManager.path}/comics.zip', mimeType: mimeType);
//         await textFile.saveTo(result.path);
//       }
//     }
//     var file = File('${downloadManager.path}/comics.zip');
//     if (file.existsSync()) {
//       file.delete();
//     }
//     return true;
//   } catch (e) {
//     return false;
//   }
// }

Future<bool> exportPdf(String pdfPath) async {
  try {
    if (App.isMobile) {
      var params = SaveFileDialogParams(sourceFilePath: pdfPath);
      await FlutterFileDialog.saveFile(params: params);
    } else {
      final FileSaveLocation? result =
          await getSaveLocation(suggestedName: pdfPath.split(pathSep).last);

      if (result != null) {
        const String mimeType = 'application/pdf';
        final XFile textFile = XFile(pdfPath, mimeType: mimeType);
        await textFile.saveTo(result.path);
      }
    }
    if (File(pdfPath).existsSync()) {
      File(pdfPath).delete();
    }
    return true;
  } catch (e) {
    return false;
  }
}

class ExportAnimeData {
  String id;
  String path;
  String name;
  String directory;
  List<String>? epNames;

  ExportAnimeData(this.id, this.path, this.name, this.epNames, this.directory);
}

// Future<bool> runningExportComic(ExportComicData data) async {
//   final fileName = '${data.path}/${data.name}.zip';
//   try {
//     final path = Directory("${data.path}/${data.directory}");
//     var zipFile = ZipFile.open(fileName);
//     String? currentDirName;
//
//     void walk(String path) {
//       for (var entry in Directory(path).listSync()) {
//         if (entry is Directory) {
//           var index = int.parse(entry.name) - 1;
//           currentDirName = sanitizeFileName(
//               data.epNames?.elementAtOrNull(index) ?? "Chapter ${index + 1}");
//           walk(entry.path);
//         } else {
//           var filePathInZip = sanitizeFileName(data.name);
//           if (currentDirName != null) {
//             filePathInZip += "/$currentDirName";
//           }
//           filePathInZip += "/${entry.name}";
//           zipFile.addFile(filePathInZip, entry.path);
//         }
//       }
//     }
//
//     walk(path.path);
//     zipFile.close();
//     return true;
//   } catch (e, s) {
//     LogManager.addLog(LogLevel.error, "IO", "$e\n$s");
//     return false;
//   }
// }

// Future<bool> runningExportComics(List<ExportComicData> datas) async {
//   try {
//     var result = "${datas.first.path}/comics.zip";
//     if (File(result).existsSync()) {
//       File(result).deleteSync();
//     }
//     var zipFile = ZipFile.open(result);
//     for (var data in datas) {
//       final directory = Directory('${data.path}/${data.directory}');
//
//       String? currentDirName;
//
//       void walk(String path) {
//         for (var entry in Directory(path).listSync()) {
//           if (entry is Directory) {
//             var index = int.parse(entry.name) - 1;
//             currentDirName = sanitizeFileName(
//                 data.epNames?.elementAtOrNull(index) ?? "Chapter ${index + 1}");
//             walk(entry.path);
//           } else {
//             var filePathInZip = sanitizeFileName(data.name);
//             if (currentDirName != null) {
//               filePathInZip += "/$currentDirName";
//             }
//             filePathInZip += "/${entry.name}";
//             zipFile.addFile(filePathInZip, entry.path);
//           }
//         }
//       }
//
//       walk(directory.path);
//     }
//     zipFile.close();
//     return true;
//   } catch (e, s) {
//     LogManager.addLog(LogLevel.error, "IO", "$e\n$s");
//     return false;
//   }
// }

// Future<double> calculateCacheSize() async {
//   if (App.isAndroid || App.isIOS) {
//     var path = await getTemporaryDirectory();
//     return compute(getFolderSize, path);
//   } else if (App.isDesktop) {
//     var path = "${(await getTemporaryDirectory()).path}${pathSep}imageCache";
//     var directory = Directory(path);
//     if (directory.existsSync()) {
//       return directory.getMBSizeSync();
//     } else {
//       return 0;
//     }
//   } else {
//     return double.infinity;
//   }
// }

Future<void> eraseCache() async {
  return CacheManager().clear();
}

Future<void> copyDirectory(Directory source, Directory destination) async {
  try {
    // 获取源文件夹中的内容（包括文件和子文件夹）
    List<FileSystemEntity> contents = source.listSync();

    // 遍历源文件夹中的每个文件和子文件夹
    for (FileSystemEntity content in contents) {
      String newPath = destination.path +
          Platform.pathSeparator +
          content.path.split(Platform.pathSeparator).last;

      if (content is File) {
        // 如果是文件，则复制文件到目标文件夹中
        content.copySync(newPath);
      } else if (content is Directory) {
        // 如果是子文件夹，则递归地调用该函数，复制子文件夹到目标文件夹中
        Directory newDirectory = Directory(newPath);
        newDirectory.createSync();
        copyDirectory(content.absolute, newDirectory.absolute);
      }
    }
  } catch (e, s) {
    LogManager.addLog(LogLevel.error, "IO", "$e\n$s");
    rethrow;
  }
}

///检查下载目录是否可用, 不可用则重置
Future<void> checkDownloadPath() async {
  var path = appdata.settings[22];
  if (path != "") {
    var directory = Directory(path);
    if (!directory.existsSync()) {
      appdata.settings[22] = "";
      appdata.updateSettings();
    }
  }
}

Future<String?> _exportData(
    String path, String appdataString, String? downloadPath) async {
  var encode = ZipFile.open("$path/userData.picadata");
  try {
    var filePath = "$path${pathSep}appdata";
    var file = File(filePath);
    if (file.existsSync()) {
      file.deleteSync();
    }
    file.createSync();
    file.writeAsStringSync(appdataString);
    encode.addFile(file.uri.pathSegments.last, file.path);
    var localFavorite = File("$path${pathSep}local_favorite.db");
    var history = File("$path${pathSep}history.db");
    if (!localFavorite.existsSync()) {
      localFavorite.createSync();
    }
    if (!history.existsSync()) {
      history.createSync();
    }
    encode.addFile(
        localFavorite.name, localFavorite.path.replaceAll("\\", "/"));
    encode.addFile(history.name, history.path);
    if (downloadPath != null) {
      downloadPath = downloadPath.replaceAll('\\', '/');
      var sourceFolder =
          downloadPath.substring(0, downloadPath.lastIndexOf('/'));
      void walk(String path) {
        for (var entry in Directory(path).listSync()) {
          if (entry is Directory) {
            walk(entry.path);
          } else {
            var filePathInZip = entry.path.replaceFirst(sourceFolder, "");
            if (filePathInZip.startsWith('/') ||
                filePathInZip.startsWith('\\')) {
              filePathInZip = filePathInZip.substring(1);
            }
            encode.addFile(filePathInZip, entry.path);
          }
        }
      }

      walk(downloadPath);
    }
    return null;
  } catch (e) {
    return e.toString();
  } finally {
    encode.close();
  }
}

Future<String> exportDataToFile(bool includeDownload) async {
  var path = (await getApplicationSupportDirectory()).path;
  try {
    var appdataString = const JsonEncoder().convert(appdata.toJson());
    var downloadPath = includeDownload ? DownloadManager().path : null;
    var res = await compute<List<String?>, String?>(
        (message) => _exportData(message[0]!, message[1]!, message[2]),
        [path, appdataString, downloadPath]);

    if (res != null) {
      throw Exception(res);
    }
  } catch (e, s) {
    LogManager.addLog(LogLevel.error, "IO", "$e\n$s");
    rethrow;
  }
  return "$path${pathSep}userData.picadata";
}

Future<bool> runExportData(bool includeDownload) async {
  try {
    var path = (await getApplicationSupportDirectory()).path;
    await exportDataToFile(includeDownload);

    var dialog = showLoadingDialog(
      App.globalContext!,
      barrierDismissible: false,
      allowCancel: false,
    );

    if (App.isMobile) {
      var params = SaveFileDialogParams(
          sourceFilePath: "$path${pathSep}userData.picadata");
      await FlutterFileDialog.saveFile(params: params);
    } else {
      final FileSaveLocation? result =
          await getSaveLocation(suggestedName: 'userData.picadata');

      if (result != null) {
        const String mimeType = 'application/octet-stream';
        final XFile textFile =
            XFile("$path${pathSep}userData.picadata", mimeType: mimeType);
        await textFile.saveTo(result.path);
      }
    }

    dialog.close();

    var file = File("$path${pathSep}userData.picadata");
    file.delete();
  } catch (e, s) {
    LogManager.addLog(LogLevel.error, "IO", "$e\n$s");
    return false;
  }
  return true;
}

/// import data, filePath is used for webdav
Future<bool> importData([String? filePath]) async {
  final enableCheck = filePath != null;
  var path = (await getApplicationSupportDirectory()).path;
  if (filePath == null) {
    if (App.isMobile) {
      var params = const OpenFileDialogParams();
      filePath = await FlutterFileDialog.pickFile(params: params);
    } else {
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'data',
      );
      final XFile? file =
          await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
      filePath = file?.path;
    }
    if (filePath == null) {
      LogManager.addLog(LogLevel.error, "importData", "filePath is null");
      return false;
    }
  }
  var data = await compute<List<String>, String>((data) async {
    try {
      ZipFile.openAndExtract(data[1], "$path${pathSep}dataTemp");
      var downloadPath = Directory(data[2]);
      List<FileSystemEntity> contents =
          Directory("$path${pathSep}dataTemp").listSync();
      for (FileSystemEntity item in contents) {
        if (item is Directory) {
          item.renameSync('$path${pathSep}dataTemp${pathSep}download');
        }
      }
      final json =
          File("$path${pathSep}dataTemp${pathSep}appdata").readAsStringSync();
      int fileVersion = int.parse(
          ((const JsonDecoder().convert(json))["settings"] as List)
                  .elementAtOrNull(46) ??
              "1");
      if (fileVersion <= int.parse(data[3]) && data[4] == "1") {
        return json;
      }
      var downloadData = Directory("$path${pathSep}dataTemp${pathSep}download");
      if (downloadData.existsSync()) {
        downloadPath.deleteSync(recursive: true);
        downloadPath.createSync();
      }
      var localFavorite =
          File('$path${pathSep}dataTemp${pathSep}localFavorite');
      if (localFavorite.existsSync()) {
        localFavorite.copySync('$path${pathSep}localFavorite');
      } else {
        var localFavorite2 =
            File('$path${pathSep}dataTemp${pathSep}local_favorite.db');
        localFavorite2.copySync('$path${pathSep}local_favorite_temp.db');
      }
      var history = File('$path${pathSep}dataTemp${pathSep}history.db');
      if (history.existsSync()) {
        history.copySync('$path${pathSep}history_temp.db');
      }
      if (downloadData.existsSync()) {
        await copyDirectory(
            Directory("$path${pathSep}dataTemp${pathSep}download"),
            downloadPath);
      }
      try {
        Directory("$path${pathSep}dataTemp").deleteSync(recursive: true);
      } catch (e) {
        //忽略
      }
      return json;
    } catch (e, s) {
      return "failed to compute data\n$e\n$s";
    }
  }, [
    path,
    filePath,
    // DownloadManager().path!,
    appdata.settings[46],
    (enableCheck ? "1" : "0")
  ]);
  if (data.startsWith("failed to compute data")) {
    LogManager.addLog(LogLevel.error, "importData", data);
    return false;
  }
  var json = const JsonDecoder().convert(data);
  int fileVersion =
      int.parse((json["settings"] as List).elementAtOrNull(46) ?? "1");
  int appVersion = int.parse(appdata.settings[46]);
  if (fileVersion <= appVersion && enableCheck) {
    LogManager.addLog(
        LogLevel.info,
        "Appdata",
        "The data file version is $fileVersion, while the app data version is "
            "$appVersion\nStop importing data");
  }
  var dataReadRes = appdata.readDataFromJson(json);
  if (!dataReadRes) {
    LogManager.addLog(
        LogLevel.error, "Appdata", "appdata.readDataFromJson(json) failed");
    return false;
  }
  // await LocalFavoritesManager().readData();
  // LocalFavoritesManager().updateUI();
  // await HistoryManager().tryUpdateDb();
  return true;
}

void saveLog(String log) async {
  var path = (await getTemporaryDirectory()).path;
  var file = File("$path${pathSep}logs.txt");
  file.writeAsStringSync(log);
  if (App.isMobile) {
    var params =
        SaveFileDialogParams(sourceFilePath: "$path${pathSep}logs.txt");
    await FlutterFileDialog.saveFile(params: params);
  } else {
    final String? directoryPath = await getDirectoryPath();
    if (directoryPath != null) {
      await file.copy("$directoryPath${pathSep}logs.txt");
    }
  }
}

Future<void> exportStringDataAsFile(String data, String fileName) async {
  if (App.isMobile) {
    var cachePath = (await getApplicationCacheDirectory()).path;
    var file = File("$cachePath$pathSep$fileName");
    if (!file.existsSync()) {
      file.createSync();
    }
    file.writeAsStringSync(data);
    var params = SaveFileDialogParams(sourceFilePath: file.path);
    await FlutterFileDialog.saveFile(params: params);
  } else {
    final FileSaveLocation? result =
        await getSaveLocation(suggestedName: fileName);
    if (result == null) {
      return;
    }

    final Uint8List fileData =
        Uint8List.fromList(const Utf8Encoder().convert(data));
    const String mimeType = 'text/plain';
    final XFile textFile =
        XFile.fromData(fileData, mimeType: mimeType, name: fileName);
    await textFile.saveTo(result.path);
  }
}

Future<String?> getDataFromUserSelectedFile(List<String> extensions) async {
  String? filePath;
  if (App.isMobile) {
    var params = const OpenFileDialogParams();
    filePath = await FlutterFileDialog.pickFile(params: params);
  } else {
    XTypeGroup typeGroup = XTypeGroup(
      label: 'data',
      extensions: extensions,
    );
    final XFile? file =
        await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
    filePath = file?.path;
  }
  if (filePath == null) {
    return null;
  }
  return File(filePath).readAsStringSync();
}

extension FileExtension on File {
  String get name => uri.pathSegments.last;
}

String bytesLengthToReadableSize(int size) {
  if (size < 1024) {
    return "$size B";
  } else if (size < 1024 * 1024) {
    return "${(size / 1024).toStringAsFixed(2)} KB";
  } else if (size < 1024 * 1024 * 1024) {
    return "${(size / 1024 / 1024).toStringAsFixed(2)} MB";
  } else {
    return "${(size / 1024 / 1024 / 1024).toStringAsFixed(2)} GB";
  }
}
