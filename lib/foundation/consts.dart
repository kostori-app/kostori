import 'app.dart';

import 'package:flutter/material.dart';

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
  1: '不忍直视',
  2: '很差',
  3: '差',
  4: '较差',
  5: '不过不失',
  6: '还行',
  7: '推荐',
  8: '力荐',
  9: '神作',
  10: '超神作',
};

// 超分辨率滤镜
const List<String> mpvAnime4KShaders = [
  'Anime4K_Clamp_Highlights.glsl',
  'Anime4K_Restore_CNN_VL.glsl',
  'Anime4K_Upscale_CNN_x2_VL.glsl',
  'Anime4K_AutoDownscalePre_x2.glsl',
  'Anime4K_AutoDownscalePre_x4.glsl',
  'Anime4K_Upscale_CNN_x2_M.glsl'
];

// 超分辨率滤镜 (轻量)
const List<String> mpvAnime4KShadersLite = [
  'Anime4K_Clamp_Highlights.glsl',
  'Anime4K_Restore_CNN_M.glsl',
  'Anime4K_Restore_CNN_S.glsl',
  'Anime4K_Upscale_CNN_x2_M.glsl',
  'Anime4K_AutoDownscalePre_x2.glsl',
  'Anime4K_AutoDownscalePre_x4.glsl',
  'Anime4K_Upscale_CNN_x2_S.glsl'
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
  '职场'
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
  '凤傲天'
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
  '美少年'
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
  '动态漫画'
];
