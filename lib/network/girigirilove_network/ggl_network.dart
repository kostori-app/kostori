import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/parser.dart';
import 'package:kostori/network/res.dart';

import '../../foundation/log.dart';
import 'ggl_models.dart';

class GGLNetwork {
  static const baseData = "";

  static const url = "https://anime.girigirilove.com";

  factory GGLNetwork() =>
      cache == null ? (cache = GGLNetwork.create()) : cache!;

  GGLNetwork.create();

  static GGLNetwork? cache;

  final dio = Dio(BaseOptions(headers: {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.3',
  }));

  Future<String?> get(String url) async {
    try {
      // 创建 Dio 实例
      Dio dio = Dio();

      // 发起 GET 请求
      Response response = await dio.get(url);

      // 如果请求成功，返回网页的 HTML 内容
      if (response.statusCode == 200) {
        return response.data; // 返回网页的 HTML 内容
      } else {
        print('请求失败，状态码：${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('请求出错：$e');
      return null;
    }
  }

  // Future<Res<HomePageData>> getHomePage() async {
  //   String? htmlContent = await get(url);
  //   // 检查是否成功获取 HTML
  //   if (htmlContent == null) {
  //     return Res(null, errorMessage: "获取网页内容失败");
  //   }
  //
  //   try {
  //     // 解析 HTML
  //     Document document = parse(htmlContent);
  //
  //     // 存储解析结果
  //     List<HomePageItem> items = [];
  //
  //     // 选择导航栏中的链接 <li class="swiper-slide"> 并提取数据
  //     document.querySelectorAll('li.swiper-slide a').forEach((element) {
  //       String title = element.text.trim(); // 获取导航标题
  //       String link = element.attributes['href'] ?? ''; // 获取导航链接
  //
  //       // 创建 HomePageItem 并添加到列表中
  //       items.add(HomePageItem(title, link));
  //     });
  //
  //     // 返回解析的 HomePageData
  //     return Res(HomePageData(items));
  //   } catch (e, s) {
  //     print('解析 HTML 出错: $e\n$s');
  //     return Res(null, errorMessage: e.toString());
  //   }
  // }

  Future<Res<List<GglAnimeBrief>>> getLatest(int page) async {
    // print("Fetching latest anime for page $page");
    var res =
        await get("https://anime.girigirilove.com/show/2--------$page---/");
    // 解析 HTML 字符串
    Document document = html_parser.parse(res);
    // print(document.outerHtml);
    // 选择所有符合条件的 div 元素
    List<Element> animeDivs =
        document.querySelectorAll('div.border-box div.public-list-box');
    try {
      var animes = <GglAnimeBrief>[];
      for (var div in animeDivs) {
        try {
          // 提取 <a> 标签
          Element? aTag = div.querySelector('a.public-list-exp');
          if (aTag == null) continue;

          String href = aTag.attributes['href']?.trim() ?? '';
          String title = aTag.attributes['title']?.trim() ?? '';

          // 提取 <img> 标签的 data-src
          Element? imgTag = aTag.querySelector('img.gen-movie-img');
          String dataSrc = imgTag?.attributes['data-src']?.trim() ?? '';

          // 提取 <span class="public-prt hide ol3"> 的文本
          Element? spanPrt = div.querySelector('span.public-prt');
          String category = spanPrt?.text.trim() ?? '';
          List<String> categoryList = category.isNotEmpty
              ? category.split(',').map((e) => e.trim()).toList()
              : [];

          // 提取 <span class="public-list-prb hide ft2"> 的文本
          Element? spanPrb = div.querySelector('span.public-list-prb');
          String status = spanPrb?.text.trim() ?? '';

          // 提取 <div class="public-list-subtitle cor5 hide ft2"> 的文本
          Element? subtitleDiv = div.querySelector('div.public-list-subtitle');
          String subtitle = subtitleDiv?.text.trim() ?? '';

          // print(title);
          animes.add(GglAnimeBrief(
              href, title, subtitle, dataSrc, categoryList, status));
          // print("添加数据成功");
        } catch (e) {
          // print("1");
          continue;
        }
      }
      // print(animes);
      return Res(animes, subData: 9999);
    } catch (e, s) {
      LogManager.addLog(LogLevel.error, "Data Analysis", "$e\n$s");
      return Res(null, errorMessage: e.toString());
    }
  }

  Future<Res<GglAnimeInfo>> getAnimeInfo(String id) async {
    var res = await get("$url$id");
    // 解析 HTML 字符串
    Document document = html_parser.parse(res);

    // 1. 提取标题
    var titleElement = document.querySelector('h3.slide-info-title.hide');
    String title = titleElement?.text?.trim() ?? '';

    // 2. 提取简介
    var descriptionElement = document.querySelector('#height_limit.text.cor3');
    String description = descriptionElement?.text?.trim() ?? '';

    // 3. 提取导演
    List<String> director = extractLinksAfterStrong(document, '导演');

    // 4. 提取演员
    List<String> actors = extractLinksAfterStrong(document, '演员');

    // 5. 提取类型标签
    List<String> tags = extractLinksAfterStrong(document, '类型');

    // 6. 提取图片链接
    var imageElement = document.querySelector('div.detail-pic img');
    String imageUrl = imageElement?.attributes['data-src'] ?? '';

    // 7. 提取集数
    var episodeElements =
        document.querySelectorAll('ul.anthology-list-play li.box.border a');
    List<String> episodes = episodeElements.map((e) => e.text.trim()).toList();

    // 提取链接文本
    var linkElement = document.querySelector('span#bar.share-url.bj.cor5');
    String link = linkElement?.text?.trim() ?? '';

    List<Element> animeDivs =
        document.querySelectorAll('div.border-box div.public-list-box');

    String subName = "";
    try {
      // 定义一个 map 来存储集数 ID 和名称
      var series = <int, String>{};
      var epNames = <String>[];
      int sort = 1;
      // 查找所有 <li> 元素，它们包含集数的链接和名称
      var episodeElements =
          document.querySelectorAll('.anthology-list-play li a');

      for (var epElement in episodeElements) {
        // 获取集数的链接
        var href = epElement.attributes['href'];
        if (href != null) {
          // 将集数编号存入 series，使用 sort 作为 key
          series[sort] = href;

          // 获取集数名称
          var name = epElement.text.trim();
          if (name.isEmpty) {
            // 如果名称为空，自动生成“第N話”
            name = "第$sort話";
          }
          epNames.add(name);

          // 增加 sort，表示下一个集数
          sort++;
          // print(series);
        }
      }
      var related = <GglAnimeBrief>[];

      for (var div in animeDivs) {
        try {
          // 提取 <a> 标签
          Element? aTag = div.querySelector('a.public-list-exp');
          if (aTag == null) continue;

          String href = aTag.attributes['href']?.trim() ?? '';
          String title = aTag.attributes['title']?.trim() ?? '';

          // 提取 <img> 标签的 data-src
          Element? imgTag = aTag.querySelector('img.gen-movie-img');
          String dataSrc = imgTag?.attributes['data-src']?.trim() ?? '';

          // 提取 <span class="public-prt hide ol3"> 的文本
          Element? spanPrt = div.querySelector('span.public-prt');
          String category = spanPrt?.text.trim() ?? '';
          List<String> categoryList = category.isNotEmpty
              ? category.split(',').map((e) => e.trim()).toList()
              : [];

          // 提取 <span class="public-list-prb hide ft2"> 的文本
          Element? spanPrb = div.querySelector('span.public-list-prb');
          String status = spanPrb?.text.trim() ?? '';

          // 提取 <div class="public-list-subtitle cor5 hide ft2"> 的文本
          Element? subtitleDiv = div.querySelector('div.public-list-subtitle');
          String subtitle = subtitleDiv?.text.trim() ?? '';

          // print(title);
          related.add(GglAnimeBrief(
              href, title, subtitle, dataSrc, categoryList, status));
          // print("添加数据成功");
        } catch (e) {
          // print("1");
          continue;
        }
      }
      // 构建 GglAnimeInfo 对象
      return Res(GglAnimeInfo(title, link, subName, description, imageUrl,
          director, actors, series, tags, related, false, epNames));
    } catch (e, s) {
      // print("res为null");
      LogManager.addLog(LogLevel.error, "Data Analysis", "$e\n$s");
      return Res(null, errorMessage: e.toString());
    }
  }

  static String extractSingleTextAfterStrong(
      Document document, String targetText) {
    List<Element> strongElements =
        document.querySelectorAll('div.slide-info.hide strong');
    for (var strong in strongElements) {
      String strongText =
          strong.text.trim().replaceAll(':', '').replaceAll('：', '').trim();
      if (strongText == targetText) {
        // 假设导演名称在 <strong> 后面的兄弟节点
        return strong.nextElementSibling?.text?.trim() ?? '';
      }
    }
    return '';
  }

  static List<String> extractLinksAfterStrong(
      Document document, String targetText) {
    List<String> results = [];
    List<Element> strongElements =
        document.querySelectorAll('div.slide-info.hide strong');
    for (var strong in strongElements) {
      String strongText =
          strong.text.trim().replaceAll(':', '').replaceAll('：', '').trim();
      if (strongText == targetText) {
        var parent = strong.parent;
        if (parent != null) {
          // 获取 <strong> 后面的所有 <a> 元素
          var linkElements = parent.querySelectorAll('a');
          results = linkElements.map((e) => e.text.trim()).toList();
          break; // 找到后退出循环
        }
      }
    }
    return results;
  }

  // Future<String> getGglVideoLink(String series) async {
  //   var res = await get("$url$series");
  //   // 解析 HTML 字符串
  //   Document document = html_parser.parse(res);
  //
  //   print('src值为: $res');
  //   Element? iframeElement = document.querySelector("tbody td iframe");
  //   if (iframeElement == null) {
  //     throw Exception("未找到 iframe 元素");
  //   }
  //   String src = iframeElement?.attributes['src'] ?? "";
  //
  //   print('src值为: $src');
  //   // 解析视频链接
  //
  //   String videoUrl = src
  //       .split("?")
  //       .last
  //       .split("&")
  //       .firstWhere(
  //         (param) => param.startsWith("url="),
  //         orElse: () => "",
  //       )
  //       .substring(4);
  //
  //   if (videoUrl.isEmpty) {
  //     throw Exception("URL 解析失败");
  //   }
  //   print(videoUrl);
  //   return videoUrl;
  // }

  Future<String> parsePlayLink(String html) async {
    var res = await dio.get("$url$html");
    var doc = parse(res.data.toString());
    var div = doc.querySelector('.player-left');
    div ??= doc.querySelector('.player-top');
    var script =
        div!.querySelector('script')!.text.split(',').map((e) => e.trim());
    for (var line in script) {
      if (line.contains("\"url\"")) {
        var encoded =
            line.split(':')[1].replaceAll("\"", '').replaceAll(',', '');
        var decoded = base64Decode(encoded);
        var urlEncoded = String.fromCharCodes(decoded);
        var videoLink = Uri.decodeFull(urlEncoded);
        // logger.i('Parsed video link: $videoLink');
        return videoLink;
      }
    }
    return '';
  }
}

var gglNetwork = GGLNetwork();
