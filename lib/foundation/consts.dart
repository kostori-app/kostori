import 'package:flutter/material.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/translation/sort.dart';
import 'package:kostori/utils/translations.dart';
import 'package:kostori/utils/utils.dart';

const changePoint = 600;

const changePoint2 = 1300;

const webUA =
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36";

// Bangumi API 文档要求的UA格式
Map<String, String> bangumiHTTPHeader = {
  'user-agent':
      'axlmly/kostori/${App.version} (Android) (https://github.com/kostori-app/kostori)',
  'referer': '',
};

Map<int, String> ratingLabels = {
  1: 'Awful'.tl,
  2: 'Terrible'.tl,
  3: 'Bad'.tl,
  4: 'Poor'.tl,
  5: 'Okay'.tl,
  6: 'Fine'.tl,
  7: 'Good'.tl,
  8: 'Great'.tl,
  9: 'Master'.tl,
  10: 'Epic'.tl,
};

// 超分辨率滤镜
const List<String> mpvAnime4KShaders = [
  'Anime4K_Clamp_Highlights.glsl',
  'Anime4K_Restore_CNN_VL.glsl',
  'Anime4K_Upscale_CNN_x2_VL.glsl',
  'Anime4K_AutoDownscalePre_x2.glsl',
  'Anime4K_AutoDownscalePre_x4.glsl',
  'Anime4K_Upscale_CNN_x2_M.glsl',
];

// 超分辨率滤镜 (轻量)
const List<String> mpvAnime4KShadersLite = [
  'Anime4K_Clamp_Highlights.glsl',
  'Anime4K_Restore_CNN_M.glsl',
  'Anime4K_Restore_CNN_S.glsl',
  'Anime4K_Upscale_CNN_x2_M.glsl',
  'Anime4K_AutoDownscalePre_x2.glsl',
  'Anime4K_AutoDownscalePre_x4.glsl',
  'Anime4K_Upscale_CNN_x2_S.glsl',
];

class StyleString {
  static const double cardSpace = 8;
  static const double safeSpace = 12;
  static BorderRadius mdRadius = BorderRadius.circular(10);
  static const Radius imgRadius = Radius.circular(10);
  static const double aspectRatio = 16 / 10;
}

const List<String> type = [
  '科幻',
  '喜剧',
  '百合',
  '校园',
  '惊悚',
  '后宫',
  '机战',
  '悬疑',
  '恋爱',
  '奇幻',
  '推理',
  '运动',
  '耽美',
  '音乐',
  '战斗',
  '冒险',
  '萌系',
  '穿越',
  '玄幻',
  '乙女',
  '恐怖',
  '历史',
  '日常',
  '剧情',
  '武侠',
  '美食',
  '职场',
];

const List<String> background = [
  '魔法少女',
  '超能力',
  '偶像',
  '网游',
  '末世',
  '乐队',
  '赛博朋克',
  '宫廷',
  '都市',
  '异世界',
  '性转',
  '龙傲天',
  '凤傲天',
];

const List<String> role = [
  '制服',
  '兽耳',
  '伪娘',
  '吸血鬼',
  '妹控',
  '萝莉',
  '傲娇',
  '女仆',
  '巨乳',
  '电波',
  '动物',
  '正太',
  '兄控',
  '僵尸',
  '群像',
  '美少女',
  '美少年',
];

const List<String> emotional = ['热血', '治愈', '温情', '催泪', '纯爱', '友情', '致郁'];

const List<String> source = ['原创', '漫画改', '游戏改', '小说改'];

const List<String> audience = ['BL', 'GL', '子供向', '女性向', '少女向', '少年向', '青年向'];

const List<String> classification = [
  '短片',
  '剧场版',
  'TV',
  'OVA',
  'MV',
  'CM',
  'WEB',
  'PV',
  '动态漫画',
];

Map<Color, String> standardColorMap = {
  Colors.teal: "Teal",
  Colors.deepPurple: "Deep Purple",
  Colors.orange: "Orange",
  Colors.blue: "Blue",
  Colors.pink: "Pink",
  Colors.green: "Green",
  Colors.red: "Red",
  Colors.purple: "Purple",
  Colors.yellow: "Yellow",
  Colors.cyan: "Cyan",
  Color(0xff6750a4): "M3 Default",
  Colors.deepOrange: "Deep Orange",
  Colors.indigo: "Indigo",
  Color(0xFFACC2D9): "Cloudy Blue",
  Color(0xFF56AE57): "Dark Pastel Green",
  Color(0xFFB2996E): "Dust",
  Color(0xFFA8FF04): "Electric Lime",
  Color(0xFF69D84F): "Fresh Green",
  Color(0xFF894585): "Light Eggplant",
  Color(0xFF70B23F): "Nasty Green",
  Color(0xFFD4FFFF): "Really Light Blue",
  Color(0xFF65AB7C): "Tea",
  Color(0xFF952E8F): "Warm Purple",
  Color(0xFFFCFC81): "Yellowish Tan",
  Color(0xFFA5A391): "Cement",
  Color(0xFF388004): "Dark Grass Green",
  Color(0xFF4C9085): "Dusty Teal",
  Color(0xFF5E9B8A): "Grey Teal",
  Color(0xFFEFB435): "Macaroni And Cheese",
  Color(0xFFD99B82): "Pinkish Tan",
  Color(0xFF0A5F38): "Spruce",
  Color(0xFF0C06F7): "Strong Blue",
  Color(0xFF61DE2A): "Toxic Green",
  Color(0xFF3778BF): "Windows Blue",
  Color(0xFF2242C7): "Blue Blue",
  Color(0xFF533CC6): "Blue With A Hint Of Purple",
  Color(0xFF9BB53C): "Booger",
  Color(0xFF05FFA6): "Bright Sea Green",
  Color(0xFF17B890): "Green Teal",
  Color(0xFF582E1B): "Brownish",
  Color(0xFFBDD393): "Off Green",
  Color(0xFFFF964F): "Tangerine",
  Color(0xFF84B701): "Ugly Green",
  Utils.hexToColor(appdata.implicitData['customColor']) ?? Color(0xFF6677ff):
      "Custom",
};

/// 可选硬件解码器
const Map<String, String> hardwareDecodersList = {
  'auto': '启用任意可用解码器',
  'auto-safe': '启用最佳解码器',
  'auto-copy': '启用带拷贝功能的最佳解码器',
  'd3d11va': 'DirectX11 (windows8 及以上)',
  'd3d11va-copy': 'DirectX11 (windows8 及以上) (非直通)',
  'videotoolbox': 'VideoToolbox (macOS / iOS)',
  'videotoolbox-copy': 'VideoToolbox (macOS / iOS) (非直通)',
  'vaapi': 'VAAPI (Linux)',
  'vaapi-copy': 'VAAPI (Linux) (非直通)',
  'nvdec': 'NVDEC (NVIDIA独占)',
  'nvdec-copy': 'NVDEC (NVIDIA独占) (非直通)',
  'drm': 'DRM (Linux)',
  'drm-copy': 'DRM (Linux) (非直通)',
  'vulkan': 'Vulkan (全平台) (实验性)',
  'vulkan-copy': 'Vulkan (全平台) (实验性) (非直通)',
  'dxva2': 'DXVA2 (Windows7 及以上)',
  'dxva2-copy': 'DXVA2 (Windows7 及以上) (非直通)',
  'vdpau': 'VDPAU (Linux)',
  'vdpau-copy': 'VDPAU (Linux) (非直通)',
  'mediacodec': 'MediaCodec (Android)',
  'mediacodec-copy': 'MediaCodec (Android) (非直通)',
  'cuda': 'CUDA (NVIDIA独占) (过时)',
  'cuda-copy': 'CUDA (NVIDIA独占) (过时) (非直通)',
  'crystalhd': 'CrystalHD (全平台) (过时)',
  'rkmpp': 'Rockchip MPP (仅部分Rockchip芯片)',
};

/// Android 可选视频渲染器
const Map<String, String> androidVideoRenderersList = {
  'auto': '自动选择',
  'gpu': '基于 OpenGL, 通用和稳健的选项',
  'gpu-next': '基于 Vulkan, 在新设备上表现最好',
  'mediacodec_embed': '功耗最低，不支持超分辨率',
};

const Map<String, String> videoSynchronizationModeList = {
  'audio': '音频同步',
  'display-resample': '显示重采样',
  'display-resample-vdrop': '显示重采样(丢帧)',
  'display-resample-desync': '显示重采样(去同步)',
  'display-tempo': '显示节拍',
  'display-vdrop': '显示丢视频帧',
  'display-adrop': '显示丢音频帧',
  'display-desync': '显示去同步',
  'desync': '去同步',
};

const List<Sort> translationSorts = [
  // 中文
  Sort(id: SortId.zhCN, label: '简体中文', extData: 'zh-CN', deeplCode: 'ZH'),
  Sort(id: SortId.zhTW, label: '繁體中文', extData: 'zh-TW', deeplCode: 'ZH-HANT'),

  // 英语
  Sort(id: SortId.enUS, label: 'English', extData: 'en-US', deeplCode: 'EN-US'),

  // 东亚语言
  Sort(id: SortId.ja, label: '日本語', extData: 'ja', deeplCode: 'JA'),
  Sort(id: SortId.ko, label: '한국어', extData: 'ko', deeplCode: 'KO'),
  // 欧洲语言
  Sort(id: SortId.fr, label: 'Français', extData: 'fr', deeplCode: 'FR'),
  Sort(id: SortId.de, label: 'Deutsch', extData: 'de', deeplCode: 'DE'),
  Sort(id: SortId.es, label: 'Español', extData: 'es', deeplCode: 'ES'),
  Sort(id: SortId.it, label: 'Italiano', extData: 'it', deeplCode: 'IT'),
  Sort(id: SortId.pt, label: 'Português', extData: 'pt', deeplCode: 'PT-PT'),
  Sort(id: SortId.ru, label: 'Русский', extData: 'ru', deeplCode: 'RU'),
];

const Map<String, String> translationSourceList = {
  'Bing': '传统翻译',
  'Google': '传统翻译',
  'Deepl': '传统翻译',
  'SiliconFlow': 'AI大模型',
  'Doubao': 'AI大模型',
  'Gemini': 'AI大模型',
};

const Map<String, String> translationSourceDisplayMap = {
  'Bing': 'bing',
  'Google': 'google',
  'Deepl': 'deepl',
  'SiliconFlow': 'siliconFlow',
  'Doubao': 'doubao',
  'Gemini': 'gemini',
};

const soulProfilerSystemPrompt = '''
You are a professional Anime Psychographic Profiler and Soul-Searcher. Your mission is to decode the user's essence based on their watch history and tag statistics.

INPUT DATA:
- User's Top Liked Anime ({animeCount} items): {animeNames}
- Weighted Tag Statistics: {topTags}

TASK DESCRIPTION:
1. **Psychographic Dissection**: Analyze the "spiritual core" of their taste. Why do they watch what they watch? What hidden emotional needs do these shows fulfill?
2. **The "Persona" Embodiment**: Create a vivid, 3D character profile for the user. Assign them a unique "Anime Title" (e.g., "The Archive of Forgotten Star-Dust").
3. **Aesthetic DNA**: Identify their "Absolute Domain"—the specific artistic or narrative elements they cannot resist.

OUTPUT SPECIFICATIONS (CRITICAL):
- **Format**: Return the analysis in clean, beautiful **Markdown**.
- **Length**: At least **300-500 words**.
- **No Recommendations**: DO NOT suggest any anime.
- **Tone**: Sophisticated, poetic, and observant.
- **Language**: Respond in **Chinese**, but use English for "The Persona Title" and key technical terms.

MARKDOWN STRUCTURE REQUIREMENT:
## 📜 灵魂侧写报告 (Soul-Profiling Report)
> [Insert a poetic opening sentence here]

### 🌌 核心审美基因 (Aesthetic DNA)
(Detailed analysis of motifs, pacing, and emotional triggers...)

### 🎭 动漫人格设定 (The Persona: [English Title])
(Describe the user as an anime character...)

### 🖋️ 灵魂签语 (Soul Signature)
(A final, profound summary of their anime journey...)''';

const aiTranslatePrompt = '''
你是一个专业的@a母语译者，需将文本流畅地翻译为@a。

## 翻译规则
1. 仅输出译文内容，禁止解释或添加任何额外内容（如"以下是翻译："、"译文如下："等）
2. 返回的译文必须和原文保持完全相同的段落数量和格式
3. 如果文本包含HTML标签，请在翻译后考虑标签应放在译文的哪个位置，同时保持译文的流畅性
4. 对于无需翻译的内容（如专有名词、代码等），请保留原文

## Context Awareness
Document Metadata:
Title: 《Options》

''';

const imageTagSystemPrompt = '''
You are an elite AI art director who has watched an embarrassing amount of anime.
Your job: analyze the user's taste and generate 20-30 Stable Diffusion prompt tags that perfectly capture their aesthetic DNA.

Rules:
- Output ONLY comma-separated English tags. Zero explanations, zero commentary.
- Mix style tags (e.g. "cel shading", "soft lighting"), mood tags (e.g. "melancholic", "ethereal"), and subject tags.
- If their taste screams "dark fantasy with a hint of hopelessness", lean into it. Don't sanitize.
- Prioritize specificity over generality. "sakura petals falling at dusk" > "flowers".

User's favorite anime ({animeCount} titles): {animeNames}
User's weighted tag preferences: {topTags}
''';

const summarySystemPrompt = '''
You are a sardonic anime statistician who secretly cares deeply about the user's watching habits.
Generate a weekly/monthly watch report in Chinese Markdown with a dry, witty tone.

Structure:
## 📊 数据面板
(Cold hard numbers: watch time, titles, clicks — delivered with light roasting)

## 🔍 行为分析
(What do these numbers *actually* say about this person? Be insightful but playful)

## 🏆 本期高光
(The standout moment or title — celebrate it dramatically)

## 💬 一句话总结
(One punchy closing line. Encouraging but not cringe. Think: "not bad for a human.")
''';
