// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart' as file_selector;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_absolute_path_provider/flutter_absolute_path_provider.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_saf/flutter_saf.dart';
import 'package:gif/gif.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/network/app_dio.dart';
import 'package:kostori/pages/image_manipulation_page/image_manipulation_page.dart';
import 'package:kostori/utils/ext.dart';
import 'package:kostori/utils/file_type.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart' as s;

export 'dart:io';
export 'dart:typed_data';

class IO {
  /// A global flag used to indicate whether the app is selecting files.
  ///
  /// Select file and other similar file operations will launch external programs,
  /// causing the app to lose focus. AppLifecycleState will be set to paused.
  static bool get isSelectingFiles => _isSelectingFiles;

  static bool _isSelectingFiles = false;
}

class FilePath {
  const FilePath._();

  static String join(
    String path1,
    String path2, [
    String? path3,
    String? path4,
    String? path5,
  ]) {
    return p.join(path1, path2, path3, path4, path5);
  }
}

extension FileSystemEntityExt on FileSystemEntity {
  String get name {
    return p.basename(path);
  }

  /// Delete the file or directory and ignore errors.
  Future<void> deleteIgnoreError({bool recursive = false}) async {
    try {
      await delete(recursive: recursive);
    } catch (e) {
      // ignore
    }
  }

  /// Delete the file or directory if it exists.
  Future<void> deleteIfExists({bool recursive = false}) async {
    if (existsSync()) {
      await delete(recursive: recursive);
    }
  }

  /// Delete the file or directory if it exists.
  void deleteIfExistsSync({bool recursive = false}) {
    if (existsSync()) {
      deleteSync(recursive: recursive);
    }
  }
}

extension FileExtension on File {
  /// Get the file extension, not including the dot.
  String get extension => path.split('.').last;

  /// Copy the file to the specified path using memory.
  ///
  /// This method prevents errors caused by files from different file systems.
  Future<void> copyMem(String newPath) async {
    var newFile = File(newPath);
    // Stream is not usable since [AndroidFile] does not support [openRead].
    await newFile.writeAsBytes(await readAsBytes());
  }

  /// Get the base name of the file without the extension.
  String get basenameWithoutExt {
    return p.basenameWithoutExtension(path);
  }
}

extension DirectoryExtension on Directory {
  /// Calculate the size of the directory.
  Future<int> get size async {
    if (!existsSync()) return 0;
    int total = 0;
    for (var f in listSync(recursive: true)) {
      if (FileSystemEntity.typeSync(f.path) == FileSystemEntityType.file) {
        total += await File(f.path).length();
      }
    }
    return total;
  }

  /// Change the base name of the directory.
  Directory renameX(String newName) {
    newName = sanitizeFileName(newName);
    return renameSync(path.replaceLast(name, newName));
  }

  File joinFile(String name) {
    return File(FilePath.join(path, name));
  }

  /// Delete the contents of the directory.
  void deleteContentsSync({dynamic recursive = true}) {
    if (!existsSync()) return;
    for (var f in listSync()) {
      f.deleteIfExistsSync(recursive: recursive);
    }
  }

  /// Delete the contents of the directory.
  Future<void> deleteContents({dynamic recursive = true}) async {
    if (!existsSync()) return;
    for (var f in listSync()) {
      await f.deleteIfExists(recursive: recursive);
    }
  }

  /// Create the directory. If the directory already exists, delete it first.
  void forceCreateSync() {
    if (existsSync()) {
      deleteSync(recursive: true);
    }
    createSync(recursive: true);
  }
}

/// Sanitize the file name. Remove invalid characters and trim the file name.
String sanitizeFileName(String fileName, {String? dir, int? maxLength}) {
  while (fileName.endsWith('.')) {
    fileName = fileName.substring(0, fileName.length - 1);
  }
  var length = maxLength ?? 255;
  if (dir != null) {
    if (!dir.endsWith('/') && !dir.endsWith('\\')) {
      dir = "$dir/";
    }
    length -= dir.length;
  }
  final invalidChars = RegExp(r'[<>:"/\\|?*]');
  final sanitizedFileName = fileName.replaceAll(invalidChars, ' ');
  var trimmedFileName = sanitizedFileName.trim();
  if (trimmedFileName.isEmpty) {
    throw Exception('Invalid File Name: Empty length.');
  }
  if (length <= 0) {
    throw Exception('Invalid File Name: Max length is less than 0.');
  }
  if (trimmedFileName.length > length) {
    trimmedFileName = trimmedFileName.substring(0, length);
  }
  return trimmedFileName;
}

/// Copy the **contents** of the source directory to the destination directory.
Future<void> copyDirectory(Directory source, Directory destination) async {
  List<FileSystemEntity> contents = source.listSync();
  for (FileSystemEntity content in contents) {
    String newPath = FilePath.join(destination.path, content.name);

    if (content is File) {
      var resultFile = File(newPath);
      resultFile.createSync();
      var data = content.readAsBytesSync();
      resultFile.writeAsBytesSync(data);
    } else if (content is Directory) {
      Directory newDirectory = Directory(newPath);
      newDirectory.createSync();
      copyDirectory(content.absolute, newDirectory.absolute);
    }
  }
}

/// Copy the **contents** of the source directory to the destination directory.
/// This function is executed in an isolate to prevent the UI from freezing.
Future<void> copyDirectoryIsolate(
  Directory source,
  Directory destination,
) async {
  await Isolate.run(() => overrideIO(() => copyDirectory(source, destination)));
}

String findValidDirectoryName(String path, String directory) {
  var name = sanitizeFileName(directory);
  var dir = Directory("$path/$name");
  var i = 1;
  while (dir.existsSync() && dir.listSync().isNotEmpty) {
    name = sanitizeFileName("$directory($i)");
    dir = Directory("$path/$name");
    i++;
  }
  return name;
}

class DirectoryPicker {
  /// Pick a directory.
  ///
  /// The directory may not be usable after the instance is GCed.
  DirectoryPicker();

  static final _finalizer = Finalizer<String>((path) {
    if (path.startsWith(App.cachePath)) {
      Directory(path).deleteIgnoreError();
    }
    if (App.isIOS || App.isMacOS) {
      _methodChannel.invokeMethod("stopAccessingSecurityScopedResource");
    }
  });

  static const _methodChannel = MethodChannel("kostori/method_channel");

  Future<Directory?> pickDirectory({bool directAccess = false}) async {
    IO._isSelectingFiles = true;
    try {
      String? directory;
      if (App.isWindows || App.isLinux) {
        directory = await file_selector.getDirectoryPath();
      } else if (App.isAndroid) {
        directory = (await AndroidDirectory.pickDirectory())?.path;
        if (directory != null && directAccess) {
          // Native library does not have access to the directory. Copy it to cache.
          var cache = FilePath.join(App.cachePath, "selected_directory");
          if (Directory(cache).existsSync()) {
            Directory(cache).deleteSync(recursive: true);
          }
          Directory(cache).createSync();
          await copyDirectoryIsolate(Directory(directory), Directory(cache));
          directory = cache;
        }
      } else {
        // ios, macos
        directory = await _methodChannel.invokeMethod<String?>(
          "getDirectoryPath",
        );
      }
      if (directory == null) return null;
      _finalizer.attach(this, directory);
      return Directory(directory);
    } finally {
      Future.delayed(const Duration(milliseconds: 100), () {
        IO._isSelectingFiles = false;
      });
    }
  }
}

class IOSDirectoryPicker {
  static const MethodChannel _channel = MethodChannel("kostori/method_channel");

  // 调用 iOS 目录选择方法
  static Future<String?> selectDirectory() async {
    IO._isSelectingFiles = true;
    try {
      final String? path = await _channel.invokeMethod('selectDirectory');
      return path;
    } catch (e) {
      // 返回报错信息
      return e.toString();
    } finally {
      Future.delayed(const Duration(milliseconds: 100), () {
        IO._isSelectingFiles = false;
      });
    }
  }
}

Future<FileSelectResult?> selectFile({required List<String> ext}) async {
  IO._isSelectingFiles = true;
  try {
    var extensions = App.isMacOS || App.isIOS ? null : ext;
    file_selector.XTypeGroup typeGroup = file_selector.XTypeGroup(
      label: 'files',
      extensions: extensions,
    );
    FileSelectResult? file;
    if (App.isAndroid) {
      const selectFileChannel = MethodChannel("kostori/select_file");
      String mimeType = "*/*";
      if (ext.length == 1) {
        mimeType = FileType.fromExtension(ext[0]).mime;
        if (mimeType == "application/octet-stream") {
          mimeType = "*/*";
        }
      }
      var filePath = await selectFileChannel.invokeMethod(
        "selectFile",
        mimeType,
      );
      if (filePath == null) return null;
      file = FileSelectResult(filePath);
    } else {
      var xFile = await file_selector.openFile(
        acceptedTypeGroups: <file_selector.XTypeGroup>[typeGroup],
      );
      if (xFile == null) return null;
      file = FileSelectResult(xFile.path);
    }
    if (!ext.contains(file.path.split(".").last)) {
      App.rootContext.showMessage(
        message: "Invalid file type: ${file.path.split(".").last}",
      );
      return null;
    }
    return file;
  } finally {
    Future.delayed(const Duration(milliseconds: 100), () {
      IO._isSelectingFiles = false;
    });
  }
}

Future<String?> selectDirectory() async {
  IO._isSelectingFiles = true;
  try {
    var path = await file_selector.getDirectoryPath();
    return path;
  } finally {
    Future.delayed(const Duration(milliseconds: 100), () {
      IO._isSelectingFiles = false;
    });
  }
}

// selectDirectoryIOS
Future<String?> selectDirectoryIOS() async {
  return IOSDirectoryPicker.selectDirectory();
}

Future<void> saveFile({
  Uint8List? data,
  required String filename,
  File? file,
}) async {
  if (data == null && file == null) {
    throw Exception("data and file cannot be null at the same time");
  }
  IO._isSelectingFiles = true;
  try {
    if (data != null) {
      var cache = FilePath.join(App.cachePath, filename);
      if (File(cache).existsSync()) {
        File(cache).deleteSync();
      }
      await File(cache).writeAsBytes(data);
      file = File(cache);
    }
    if (App.isMobile) {
      final params = SaveFileDialogParams(sourceFilePath: file!.path);
      await FlutterFileDialog.saveFile(params: params);
    } else {
      final result = await file_selector.getSaveLocation(
        suggestedName: filename,
      );
      if (result != null) {
        var xFile = file_selector.XFile(file!.path);
        await xFile.saveTo(result.path);
      }
    }
  } finally {
    Future.delayed(const Duration(milliseconds: 100), () {
      IO._isSelectingFiles = false;
    });
  }
}

base class _IOOverrides extends IOOverrides {
  @override
  Directory createDirectory(String path) {
    if (App.isAndroid) {
      var dir = AndroidDirectory.fromPathSync(path);
      if (dir == null) {
        return super.createDirectory(path);
      }
      return dir;
    } else {
      return super.createDirectory(path);
    }
  }

  @override
  File createFile(String path) {
    if (path.startsWith("file://")) {
      path = path.substring(7);
    }
    if (App.isAndroid) {
      var f = AndroidFile.fromPathSync(path);
      if (f == null) {
        return super.createFile(path);
      }
      return f;
    } else {
      return super.createFile(path);
    }
  }
}

T overrideIO<T>(T Function() f) {
  return IOOverrides.runWithIOOverrides<T>(f, _IOOverrides());
}

class Share {
  static Future<void> shareFile({
    required Uint8List data,
    required String filename,
    required String mime,
  }) async {
    if (!App.isWindows) {
      await s.SharePlus.instance.share(
        s.ShareParams(
          fileNameOverrides: [filename],
          files: [s.XFile.fromData(data, mimeType: mime)],
        ),
      );
    } else {
      // write to cache
      final file = File(FilePath.join(App.cachePath, filename));
      await file.writeAsBytes(data);
      await s.SharePlus.instance.share(
        s.ShareParams(
          fileNameOverrides: [filename],
          files: [s.XFile(file.path)],
        ),
      );
    }
  }

  static Future<s.ShareResult> shareText(String text) async {
    return await s.SharePlus.instance.share(s.ShareParams(text: text));
  }
}

String bytesToReadableString(int bytes) {
  if (bytes < 1024) {
    return "$bytes B";
  } else if (bytes < 1024 * 1024) {
    return "${(bytes / 1024).toStringAsFixed(2)} KB";
  } else if (bytes < 1024 * 1024 * 1024) {
    return "${(bytes / 1024 / 1024).toStringAsFixed(2)} MB";
  } else {
    return "${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB";
  }
}

class FileSelectResult {
  final String path;

  static final _finalizer = Finalizer<String>((path) {
    if (path.startsWith(App.cachePath)) {
      File(path).deleteIgnoreError();
    }
  });

  FileSelectResult(this.path) {
    _finalizer.attach(this, path);
  }

  Future<void> saveTo(String path) async {
    await File(this.path).copy(path);
  }

  Future<Uint8List> readAsBytes() {
    return File(path).readAsBytes();
  }

  String get name => File(path).name;
}

class KostoriFolder {
  static Future<Directory?> checkPermissionAndPrepareFolder() async {
    Permission permission = Permission.manageExternalStorage;
    var status = await permission.status;
    if (!status.isGranted) {
      status = await permission.request();
      if (!status.isGranted) {
        if (status.isPermanentlyDenied) {
          await openAppSettings();
        }
        Log.warning('权限请求失败', '权限请求失败');
        return null;
      }
    }
    Directory? picturesDir = await AbsolutePath.absoluteDirectory(
      dirType: DirectoryType.pictures,
    );
    if (picturesDir == null) {
      Log.error('获取 Pictures 目录失败', '');
      return null;
    }
    final folderPath = '${picturesDir.path}/Kostori';
    final folder = Directory(folderPath);
    if (!await folder.exists()) {
      await folder.create(recursive: true);
      Log.info('创建文件夹成功', folderPath);
    }
    return folder;
  }
}

class ImageSaver {
  static Future<void> saveImage({
    required Uint8List bytes,
    required String filename,
    WidgetRef? ref,
  }) async {
    try {
      final file = await writeFile(bytes: bytes, filename: filename);
      if (file == null) return;
      showResult(success: true, message: '保存成功');
      if (App.isAndroid) {
        const platform = MethodChannel('kostori/media');
        await platform.invokeMethod('scanFolder', {'path': file.parent.path});
      }
      Log.info('保存文件成功', file.path);
    } catch (e) {
      showResult(success: false, message: '保存失败: $e');
      Log.error('保存失败', '$e');
    } finally {
      await ref?.read(imagesProvider.notifier).loadImages();
    }
  }

  static Future<void> saveImageToGallery(String imageUrl) async {
    try {
      App.rootContext.showMessage(message: '正在保存图片...');

      final response = await AppDio().request<Uint8List>(
        imageUrl,
        options: Options(method: 'GET', responseType: ResponseType.bytes),
      );

      final savedPath = await saveImageToLocalFolder(imageUrl, response.data!);

      if (savedPath != null) {
        showResult(success: true);
        Log.info('saveImageToGallery', savedPath);
      } else {
        showResult(success: false, message: '保存失败：权限或目录异常');
        Log.error('保存失败：权限或目录异常', '');
      }
    } catch (e, s) {
      showResult(success: false, message: '保存失败: $e');
      Log.error('saveImageToGallery', '$e\n$s');
    }
  }

  /// 将任意 Widget 渲染为 PNG 字节（离屏渲染）
  static Future<Uint8List?> captureWidgetToImage({
    required BuildContext context,
    required Widget child,
    double width = 800.0,
    double pixelRatio = 2.0,
    Duration delay = const Duration(milliseconds: 400),
  }) async {
    final offscreenKey = GlobalKey();

    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -10000,
        top: -10000,
        width: width,
        child: RepaintBoundary(
          key: offscreenKey,
          child: Material(child: child),
        ),
      ),
    );

    Overlay.of(context).insert(entry);

    try {
      await Future.delayed(delay);

      final boundary =
          offscreenKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } finally {
      entry.remove();
    }
  }

  /// 保存或分享图片（桌面复制到剪贴板，移动端分享）
  static Future<void> saveOrShareImage({
    required Uint8List bytes,
    required String filename,
    String desktopSuccessMessage = '已复制到剪贴板',
    String mobileSuccessMessage = '截图成功',
  }) async {
    if (App.isDesktop) {
      await writeFile(bytes: bytes, filename: filename);
      await Pasteboard.writeImage(bytes);
      showResult(success: true, message: desktopSuccessMessage);
    } else {
      final file = await writeFile(bytes: bytes, filename: filename);
      if (file == null) return;
      showResult(success: true, message: mobileSuccessMessage);
      final data = await file.readAsBytes();
      await Share.shareFile(data: data, filename: filename, mime: 'image/png');
    }
  }

  static Future<File?> writeFile({
    required Uint8List bytes,
    required String filename,
  }) async {
    try {
      final folderPath = await resolveFolderPath();
      if (folderPath == null) return null;
      final file = File('$folderPath/$filename');
      await file.writeAsBytes(bytes);
      return file;
    } catch (e) {
      Log.error('_writeFile', '$e');
      return null;
    }
  }

  static Future<String?> saveImageToLocalFolder(
    String imageUrl,
    Uint8List data,
  ) async {
    try {
      final folderPath = await resolveFolderPath();
      if (folderPath == null) return null;

      final filename = generateFilename(imageUrl);
      final file = File('$folderPath/$filename');
      await file.writeAsBytes(data);

      if (App.isAndroid) {
        const platform = MethodChannel('kostori/media');
        await platform.invokeMethod('scanFolder', {'path': folderPath});
      }

      return file.path;
    } catch (e) {
      Log.error('_saveImageToLocalFolder', '$e');
      return null;
    }
  }

  /// 统一获取保存目录，Android 检查权限，其他平台用 Documents/Kostori
  static Future<String?> resolveFolderPath() async {
    if (App.isAndroid) {
      final folder = await KostoriFolder.checkPermissionAndPrepareFolder();
      if (folder == null) {
        Log.error('保存失败：权限或目录异常', '');
        return null;
      }
      return folder.path;
    } else {
      final directory = await getApplicationDocumentsDirectory();
      final folderPath = '${directory.path}/Kostori';
      final folder = Directory(folderPath);
      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }
      return folderPath;
    }
  }

  static void showResult({required bool success, String? message}) {
    final safeContext = App.rootContext;
    showCenter(
      seconds: success ? 1 : 3,
      icon: Gif(
        image: AssetImage(
          success ? 'assets/img/check.gif' : 'assets/img/warning.gif',
        ),
        height: success ? 80 : 64,
        fps: 120,
        color: Theme.of(safeContext).colorScheme.primary,
        autostart: Autostart.once,
      ),
      message: message ?? (success ? '保存成功' : '保存失败'),
      context: safeContext,
    );
  }

  static String generateFilename(String url) {
    final uri = Uri.parse(url);
    final filename = uri.pathSegments.last;
    return filename.isNotEmpty
        ? 'bangumi_$filename'
        : 'bangumi_${DateTime.now().millisecondsSinceEpoch}.jpg';
  }
}
