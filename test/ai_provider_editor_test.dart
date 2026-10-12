import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/components/ai_provider_editor.dart';
import 'package:kostori/components/ai_provider_settings_section.dart';
import 'package:kostori/database/ai_database.dart';
import 'package:kostori/foundation/ai_service/ai_provider_settings.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/repositories/ai_provider_settings_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AiDatabase database;
  late AiProviderSettingsRepository repository;
  late Directory temp;
  late Dio dio;
  var loadedPreviewFont = false;
  setUpAll(() async {
    final font = File('C:/Windows/Fonts/msyh.ttc');
    if (await font.exists()) {
      final loader = FontLoader('AiProviderPreview');
      loader.addFont(
        Future.value(ByteData.sublistView(await font.readAsBytes())),
      );
      await loader.load();
      loadedPreviewFont = true;
    }
  });
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('kostori_ai_widgets_');
    App.dataPath = temp.path;
    database = AiDatabase.forTesting(NativeDatabase.memory());
    dio = Dio();
    repository = AiProviderSettingsRepository(database: database, dio: dio);
    await LocaleSettings.setLocale(AppLocale.en);
  });
  tearDown(() async {
    dio.close(force: true);
    await database.close();
    final key = File('${temp.path}${Platform.pathSeparator}hub_secret.key');
    if (await key.exists()) await key.delete();
    await temp.delete();
  });

  Widget app(Widget body) => TranslationProvider(
    child: MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff778dbd),
          brightness: Brightness.dark,
        ),
        fontFamily: loadedPreviewFont ? 'AiProviderPreview' : null,
      ),
      home: body,
    ),
  );

  Widget editor(AiProviderSettings settings) => AiProviderEditor(
    settings: settings,
    repository: repository,
    selectModels: (_, ids) async => ids,
    modelsBuilder: (view) => ListView(
      children: [
        for (final model in view.models)
          ListTile(
            title: Text(model.label),
            onTap: () => view.onSelected(model.modelId),
          ),
      ],
    ),
  );

  const builtin = AiProviderSettings(
    source: 'openai',
    name: 'OpenAI',
    baseUrl: 'https://api.openai.com/v1',
    apiKey: 'sk-test-preview',
    model: 'gpt-4.1-mini',
    apiFormat: 'openai_responses',
  );
  const custom = AiProviderSettings(
    source: 'custom_preview',
    name: 'Local AI',
    baseUrl: 'http://localhost:11434/v1',
    model: 'local-model',
    isNew: true,
  );

  testWidgets('内置和新建自定义服务商共用三个设置区域和全部连接字段', (tester) async {
    for (final settings in [builtin, custom]) {
      await tester.pumpWidget(app(editor(settings)));
      await tester.pumpAndSettle();
      expect(find.text('Connection'), findsOneWidget);
      expect(find.text('Model settings'), findsOneWidget);
      expect(find.text('Advanced'), findsOneWidget);
      expect(find.byKey(const ValueKey('ai-provider-api-key')), findsOneWidget);
      final name = tester.widget<TextField>(
        find.byKey(const ValueKey('ai-provider-name')),
      );
      expect(name.readOnly, !settings.isCustom);
      final key = tester.widget<TextField>(
        find.byKey(const ValueKey('ai-provider-api-key')),
      );
      expect(key.obscureText, isTrue);
      await tester.tap(find.text('Advanced'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('ai-provider-models-url')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });

  testWidgets('窄屏弹出键盘时模型设置仍可滚动，保存区不溢出', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(app(editor(custom)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Model settings'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('ai-provider-default-model')),
      findsOneWidget,
    );
    expect(find.text('Apply'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('服务商列表按相同规则展示内置和自定义状态', (tester) async {
    final opened = <String>[];
    await tester.pumpWidget(
      app(
        Scaffold(
          body: AiProviderSettingsSection(
            providers: [
              builtin,
              custom.copyWith(isNew: false, isEnabled: false),
            ],
            onOpen: (provider) => opened.add(provider.source),
            onAdd: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ai-provider-openai')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ai-provider-openai')));
    await tester.tap(find.text('Custom Providers'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('ai-provider-custom_preview')),
      findsOneWidget,
    );
    expect(find.text('Disabled'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ai-provider-custom_preview')));
    expect(opened, ['openai', 'custom_preview']);
  });

  testWidgets('导出共享编辑器的内置和自定义预览', (tester) async {
    final output = Platform.environment['KOSTORI_AI_PREVIEW_DIR'];
    if (output == null) return;
    await tester.runAsync(() => LocaleSettings.setLocale(AppLocale.zhCn));
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in {
      'desktop': const Size(600, 760),
      'mobile': const Size(360, 780),
    }.entries) {
      tester.view.physicalSize = size.value;
      for (final entry in {'builtin': builtin, 'custom': custom}.entries) {
        final boundaryKey = GlobalKey();
        await tester.pumpWidget(
          app(RepaintBoundary(key: boundaryKey, child: editor(entry.value))),
        );
        await tester.pumpAndSettle();
        for (final tab in {
          'connection': t.aiProviderConnection,
          'models': t.modelSettings,
          'advanced': t.aiProviderAdvanced,
        }.entries) {
          await tester.tap(find.text(tab.value));
          await tester.pumpAndSettle();
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File('$output/${entry.key}-${size.key}-${tab.key}.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    }
  });
}
