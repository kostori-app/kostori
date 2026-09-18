/// `implicitData` 中与设备无关、需要跨端同步的配置键。
///
/// `implicitData` 整体不参与 WebDAV 同步（里面还存着下载目录、并发数、
/// 分片数等设备本地设置），只有下面列出的键会随「数据」部分一起上传/下载，
/// 见 `lib/utils/data.dart` 的 `_writeMergeFilesFor` / `_applyImportedData`。
const String sourceDisplayModesKey = 'animeSourceDisplayModes';

/// 番源选用的文本规则 id 列表（`{sourceKey: [ruleId, ...]}`）
const String sourceTextRulesKey = 'animeSourceTextRules';

/// 番源下载标题格式（文件名模板，`{sourceKey: format}`）
const String downloadTitleFormatsKey = 'downloadTitleFormats';

/// 参与跨端同步的 implicitData 键
const List<String> syncedImplicitKeys = [
  sourceDisplayModesKey,
  sourceTextRulesKey,
  downloadTitleFormatsKey,
];
