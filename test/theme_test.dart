import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/home/post_row.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart';
import 'package:rasq_client/features/store/rasqpkg.dart';
import 'package:rasq_client/features/store/store_providers.dart';
import 'package:rasq_client/features/theme/theme_packs.dart';
import 'package:rasq_client/features/theme/theme_settings_screen.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// 着せ替え (D-335、契約 v0.16 §2.12 `kind: "theme"`): 宣言の読み取り、配布物の検証、ストアからのインストール、選択と適用。
void main() {
  final starry = File('test/fixtures/rasqpkg/sample.theme-starry-0.1.0.rasqpkg').readAsBytesSync();
  final img = MemoryImage(base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='));

  group('宣言 (RasqSkin.parse)', () {
    RasqSkin parse(Map<String, Object?> theme) => RasqSkin.parse(id: 't', name: 'T', theme: theme, image: (id) => id == 'bg' ? img : null, materialIcon: themeIconByName);

    test('色(#RRGGBB / #AARRGGBB、書けるキーだけ)、明るさ、アイコン(画像 / 別の Material)、面(色・角丸・レイヤー)', () {
      final s = parse({
        'brightness': 'dark',
        'colors': {
          'dark': {'primary': '#8AB4FF', 'surface': '#CC0B1026', 'bogus': '#FFFFFF', 'onSurface': 'red'},
        },
        'icons': {'favorite_border': 'asset:bg', 'repeat': 'material:autorenew', 'no_such_icon_name': 'material:add', 'reply': 'asset:missing'},
        'surfaces': {
          'postTile': {
            'color': '#0B1026',
            'radius': 99,
            'layers': [
              {'asset': 'bg', 'position': 'above', 'fit': 'none', 'repeat': 'repeat', 'opacity': 2},
              {'asset': 'missing'},
            ],
          },
          'sidebar': {'color': '#000000'},
        },
      });
      expect(s.only, Brightness.dark);
      expect(s.appliesTo(Brightness.light), isFalse);
      expect(s.colors[Brightness.dark], {'primary': const Color(0xFF8AB4FF), 'surface': const Color(0xCC0B1026)});
      final dark = s.applyColors(RasqTheme.dark().colorScheme);
      expect(dark.primary, const Color(0xFF8AB4FF));
      // 合わない明るさには色を当てない。
      expect(s.applyColors(RasqTheme.light().colorScheme).primary, RasqTheme.light().colorScheme.primary);
      expect(s.iconFor(Icons.favorite_border)?.image, img);
      expect(s.iconFor(Icons.repeat)?.icon, Icons.autorenew);
      expect(s.iconFor(Icons.reply), isNull, reason: '無い画像を指すものは捨てる');
      final tile = s.surface(RasqSkinSurfaceId.postTile, Brightness.dark)!;
      expect(tile.color, const Color(0xFF0B1026));
      expect(tile.radius, 48, reason: '角丸は 0〜48');
      expect(tile.layers, hasLength(1));
      expect((tile.layers.single.above, tile.layers.single.fit, tile.layers.single.repeat, tile.layers.single.opacity), (true, BoxFit.none, ImageRepeat.repeat, 1.0));
      expect(s.surface(RasqSkinSurfaceId.postTile, Brightness.light), isNull);
      expect(s.surfaces.keys, [RasqSkinSurfaceId.postTile], reason: '知らない面は捨てる');
    });

    test('v0.17 (D-337): グラデーションのレイヤー、帯の高さ、面の文字色(onColor)。asset と gradient はどちらか 1 つ', () {
      final s = parse({
        'surfaces': {
          'postTile': {
            'layers': [
              {'gradient': {'colors': ['#1F1E33', '#001F1E33']}, 'alignment': 'topCenter', 'height': 28},
              {'gradient': {'colors': ['#FF0000']}}, // 1 色は捨てる
              {'asset': 'bg', 'gradient': {'colors': ['#000000', '#FFFFFF']}}, // 両方は捨てる
              {'gradient': {'colors': ['#000000', '#FFFFFF'], 'stops': [0, 0.3], 'begin': 'centerLeft', 'end': 'centerRight'}, 'height': 999},
            ],
          },
          'fow': {'color': '#02775C', 'onColor': '#FFFFFF', 'layers': [{'gradient': {'colors': ['#02775C', '#178178']}}]},
        },
      });
      final tile = s.surface(RasqSkinSurfaceId.postTile, Brightness.light)!;
      expect(tile.layers, hasLength(2));
      final band = tile.layers.first;
      expect(band.image, isNull);
      expect((band.gradient! as LinearGradient).colors, [const Color(0xFF1F1E33), const Color(0x001F1E33)]);
      expect(((band.gradient! as LinearGradient).begin, (band.gradient! as LinearGradient).end), (Alignment.topCenter, Alignment.bottomCenter));
      expect(band.height, 28);
      expect(tile.layers.last.height, 400, reason: '帯の高さは 1〜400');
      expect((tile.layers.last.gradient! as LinearGradient).stops, [0.0, 0.3]);
      final fow = s.surface(RasqSkinSurfaceId.fow, Brightness.dark)!;
      expect(fow.onColor, const Color(0xFFFFFFFF));
      final themed = RasqSkin.withOnColor(RasqTheme.light(), fow.onColor!);
      expect(themed.colorScheme.onSurface, const Color(0xFFFFFFFF));
      expect(themed.iconTheme.color, const Color(0xFFFFFFFF));
    });

    testWidgets('帯は上辺に高さぶん、onColor は面の中の文字に効く', (tester) async {
      final s = parse({
        'surfaces': {
          'postTile': {'onColor': '#FF00FF', 'layers': [{'gradient': {'colors': ['#1F1E33', '#001F1E33']}, 'alignment': 'topCenter', 'height': 28}]},
        },
      });
      await tester.pumpWidget(MaterialApp(
        theme: RasqTheme.light(),
        home: RasqSkinScope(skin: s, child: const Scaffold(body: Center(child: SizedBox(width: 300, height: 120, child: RasqSkinned(surface: RasqSkinSurfaceId.postTile, child: Text('本文', key: ValueKey('body'))))))),
      ));
      final box = tester.getRect(find.byType(RasqSkinned));
      final band = tester.getRect(find.byWidgetPredicate((w) => w is DecoratedBox && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).gradient != null));
      expect(band.top, box.top);
      expect(band.height, 28);
      expect(band.width, box.width);
      expect(DefaultTextStyle.of(tester.element(find.byKey(const ValueKey('body')))).style.color, const Color(0xFFFF00FF));
    });

    test('app の面に背景があれば Scaffold を透明に(アプリの一番下の面を見せる)', () {
      final s = parse({
        'surfaces': {
          'app': {'color': '#060914', 'layers': [{'asset': 'bg'}]},
        },
      });
      expect(s.applyTo(RasqTheme.dark()).scaffoldBackgroundColor, Colors.transparent);
      expect(parse({}).applyTo(RasqTheme.dark()).scaffoldBackgroundColor, RasqTheme.dark().scaffoldBackgroundColor);
    });
  });

  group('配布物', () {
    test('サンプル「星空」: kind theme、wasm 無し、画像 4 枚(use: theme)、スロットには出さない', () {
      final p = RasqPackage.open(starry);
      expect((p.root.id, p.root.kind, p.root.isTheme, p.root.isPack), ('sample.theme-starry', 'theme', true, true));
      expect(p.root.wasm, isEmpty);
      expect(p.slotPlugins, isEmpty);
      expect(p.stickers, isEmpty);
      expect(p.themeImages.keys, unorderedEquals(['sky', 'stars', 'button', 'heart']));
      expect(p.themeImages.values.every((v) => isPackImage(v.bytes)), isTrue);
    });

    test('サンプル「RASQ」(v0.17): グラデーションの帯 + 薄いマーク(画像 1 枚)、FOW のグラデーションと白い文字', () {
      final p = RasqPackage.open(File('test/fixtures/rasqpkg/sample.theme-rasq-0.1.0.rasqpkg').readAsBytesSync());
      expect((p.root.id, p.root.isTheme), ('sample.theme-rasq', true));
      expect(p.themeImages.keys, ['mark']);
      final s = RasqSkin.parse(id: p.root.id, name: 'RASQ', theme: (p.root.manifest['theme'] as Map).cast<String, Object?>(), image: (id) => id == 'mark' ? img : null, materialIcon: themeIconByName);
      expect(s.only, isNull, reason: '明るい / 暗いどちらでも');
      final tile = s.surface(RasqSkinSurfaceId.postTile, Brightness.light)!;
      expect(tile.layers.map((l) => l.gradient != null), [false, true]);
      expect(tile.layers.last.height, 28);
      final fow = s.surface(RasqSkinSurfaceId.fow, Brightness.light)!;
      expect(fow.onColor, const Color(0xFFFFFFFF));
      expect((fow.layers.single.gradient! as LinearGradient).colors, [const Color(0xFF02775C), const Color(0xFF178178)]);
    });

    test('宣言の整合: 画像の参照は assets(use: theme)に、面は 4 つだけ', () {
      Map<String, Object?> m(Map<String, Object?> theme) => {'assets': [{'id': 'a', 'path': 'a.png', 'use': 'theme'}], 'theme': theme};
      checkThemeManifest(m({'icons': {'reply': 'asset:a', 'repeat': 'material:autorenew'}, 'surfaces': {'fow': {'layers': [{'asset': 'a'}]}}}));
      expect(() => checkThemeManifest({'assets': []}), throwsA(isA<RasqPackageException>()));
      expect(() => checkThemeManifest(m({'icons': {'reply': 'asset:b'}})), throwsA(isA<RasqPackageException>()));
      expect(() => checkThemeManifest(m({'surfaces': {'fow': {'layers': [{'asset': 'b'}]}}})), throwsA(isA<RasqPackageException>()));
      expect(() => checkThemeManifest(m({'surfaces': {'sidebar': {}}})), throwsA(isA<RasqPackageException>()));
      // v0.17: グラデーションのレイヤー(画像の参照は要らない)。asset と gradient は 1 つだけ、色は 2〜8、stops は同じ数。
      checkThemeManifest(m({'surfaces': {'fow': {'layers': [{'gradient': {'colors': ['#000000', '#FFFFFF']}}]}}}));
      expect(() => checkThemeManifest(m({'surfaces': {'fow': {'layers': [{'asset': 'a', 'gradient': {'colors': ['#000000', '#FFFFFF']}}]}}})), throwsA(isA<RasqPackageException>()));
      expect(() => checkThemeManifest(m({'surfaces': {'fow': {'layers': [{'opacity': 1}]}}})), throwsA(isA<RasqPackageException>()));
      expect(() => checkThemeManifest(m({'surfaces': {'fow': {'layers': [{'gradient': {'colors': ['#000000']}}]}}})), throwsA(isA<RasqPackageException>()));
      expect(() => checkThemeManifest(m({'surfaces': {'fow': {'layers': [{'gradient': {'colors': ['#000000', '#FFFFFF'], 'stops': [0]}}]}}})), throwsA(isA<RasqPackageException>()));
    });
  });

  for (final wide in [false, true]) {
  testWidgets('使っている途中で着せ替えを選んでも作り直さない(Hero のタグが重ならない)、FOW の背景も変わる (D-374${wide ? '、デスクトップ幅' : ''})', (tester) async {
    tester.view.physicalSize = wide ? const Size(1600, 1000) : const Size(1080, 2340);
    tester.view.devicePixelRatio = wide ? 1 : 3;
    addTearDown(tester.view.reset);
    final dir = Directory.systemTemp.createTempSync('rasq-d374');
    addTearDown(() => dir.deleteSync(recursive: true));
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline))),
        themePackDirProvider.overrideWithValue(() async => dir),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    c.read(themeModeProvider.notifier).set(ThemeModeSetting.light);
    // FAB のある画面を 2 つ開いておく(ホームと AsTell。タブは同じルームに並ぶ)。
    c.read(routerProvider).go(Routes.vc);
    await tester.pumpAndSettle();
    c.read(routerProvider).go(Routes.home);
    await tester.pumpAndSettle();
    final homeState = tester.state(find.byType(Navigator).first);
    final r = await tester.runAsync(() => c.read(installedPluginsProvider.notifier).install('sample.theme-starry'));
    expect(r?.error, isNull);
    await tester.pumpAndSettle();
    // 使っている途中で選ぶ。
    await c.read(settingsAreaProvider(themeSettingsArea).notifier).set('id', 'sample.theme-starry');
    await tester.pumpAndSettle();
    expect(c.read(activeSkinProvider), isNotNull);
    expect(tester.takeException(), isNull);
    expect(identical(tester.state(find.byType(Navigator).first), homeState), isTrue, reason: 'ナビゲーターを作り直していない');
    // 画面を移る(Hero の遷移が走る)。明るいモードでは効かない着せ替えなので、案内から暗いモードへ。
    c.read(routerProvider).push(Routes.settingsTheme);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('theme.brightnessHint')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('theme.brightnessHint.switch')));
    await tester.pumpAndSettle();
    expect(c.read(themeModeProvider), ThemeModeSetting.dark);
    expect(find.byKey(const ValueKey('theme.brightnessHint')), findsNothing);
    c.read(routerProvider).pop();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    c.read(overlayManagerProvider).showFow<void>(id: 'test.fow', spec: FowSpec(title: 'テスト'), builder: (_, _) => const Text('FOW の中身'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    bool sky(Widget w) => w is Image && w.image is FileImage && (w.image as FileImage).file.path.endsWith('sky.png');
    final panel = find.ancestor(of: find.text('FOW の中身'), matching: find.byType(RasqSkinned));
    expect(panel, findsWidgets);
    expect(find.descendant(of: panel.first, matching: find.byWidgetPredicate(sky)), findsWidgets, reason: 'FOW の背景(夜空)');
  });
  }

  testWidgets('ストアからインストール → 設定で選ぶ → 暗いモードで面 / アイコンが変わる → 削除で既定に戻る', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final dir = Directory.systemTemp.createTempSync('rasq-d335');
    addTearDown(() => dir.deleteSync(recursive: true));
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(registry),
        themePackDirProvider.overrideWithValue(() async => dir),
        themePackPickerProvider.overrideWithValue(() async => starry),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    c.read(themeModeProvider.notifier).set(ThemeModeSetting.dark);

    // ストア(同梱のサンプル)からインストール。
    final r = await tester.runAsync(() => c.read(installedPluginsProvider.notifier).install('sample.theme-starry'));
    expect(r?.error, isNull);
    await tester.pumpAndSettle();
    final pack = c.read(themePacksProvider).single;
    expect(pack.name, '星空');
    expect(pack.images.keys, unorderedEquals(['sky', 'stars', 'button', 'heart']));
    expect(pack.images.values.every((p) => File(p).existsSync()), isTrue);
    // 入れたらそのまま使う (D-375: 以前は選ぶまで効かず「入れたのに変わらない」になっていた)。
    expect(c.read(activeThemeIdProvider), 'sample.theme-starry');
    expect(c.read(activeSkinProvider), isNotNull);

    // 設定 → アプリの外観 → フォントやカラースキーム(D-375: 以前はライト / ダークのシートしか開かず、ここへ来られなかった)。
    c.read(routerProvider).push('/settings/section/appearance');
    await tester.pumpAndSettle();
    expect(find.text('ダーク ・ 星空'), findsOneWidget, reason: '行にカラースキームと着せ替え');
    await tester.tap(find.byKey(const ValueKey('settings.appearance.theme')));
    await tester.pumpAndSettle();
    expect(find.byType(ThemeSettingsScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('theme.pack.sample.theme-starry')), findsOneWidget);
    expect(find.byKey(const ValueKey('theme.mode.dark')), findsOneWidget);
    // 外す → 選び直す。
    await tester.tap(find.text('着せ替えなし(既定)'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(c.read(activeSkinProvider), isNull);
    await tester.tap(find.byKey(const ValueKey('theme.pack.sample.theme-starry')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(c.read(activeThemeIdProvider), 'sample.theme-starry');
    final skin = c.read(activeSkinProvider)!;
    expect(skin.only, Brightness.dark);
    // 色が当たる(暗いモード)。
    expect(Theme.of(tester.element(find.byType(ThemeSettingsScreen))).colorScheme.primary, const Color(0xFF8AB4FF));
    // アイコンの差し替え: favorite_border は画像、repeat は別の Material アイコン。
    expect(skin.iconFor(Icons.favorite_border)?.image, isA<FileImage>());
    expect(skin.iconFor(Icons.repeat)?.icon, Icons.autorenew);

    // ホームの投稿タイルに面(星の粒のレイヤー)とアイコン(画像のいいね)。
    c.read(routerProvider).go(Routes.home);
    await tester.pumpAndSettle();
    expect(find.byType(PostRow), findsWidgets);
    bool fileImage(Widget w, String name) => w is Image && w.image is FileImage && (w.image as FileImage).file.path.endsWith(name);
    expect(find.byWidgetPredicate((w) => fileImage(w, 'stars.png')), findsWidgets);
    expect(find.byWidgetPredicate((w) => fileImage(w, 'sky.png')), findsWidgets, reason: 'アプリの一番下の面');
    expect(find.byWidgetPredicate((w) => fileImage(w, 'button.png')), findsWidgets, reason: 'アクションボタンの背景');

    // 明るいモードでは面を使わない(この着せ替えは暗いモード用)。
    c.read(themeModeProvider.notifier).set(ThemeModeSetting.light);
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((w) => fileImage(w, 'stars.png')), findsNothing);

    // 削除(ストアのインストールごと)→ 既定に戻る。
    await tester.runAsync(() => c.read(installedPluginsProvider.notifier).uninstall('sample.theme-starry'));
    await tester.pumpAndSettle();
    expect(c.read(themePacksProvider), isEmpty);
    expect(c.read(activeThemeIdProvider), isNull);
    expect(c.read(activeSkinProvider), isNull);

    // ファイルから読み込む(.rasqpkg、未審査の印)→ そのまま選ばれる。
    c.read(routerProvider).push(Routes.settingsTheme);
    await tester.pumpAndSettle();
    // 読み込み(展開 + 画像の書き出し)は本物の非同期。決まった時間ではなく、入って選ばれるまで待つ(混んだ CI では 200ms で
    // 終わらず、くるくるが回り続けて pumpAndSettle が時間切れになっていた)。
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('theme.import')));
      for (var i = 0; i < 100 && !(c.read(themePacksProvider).any((p) => p.sideloaded) && c.read(activeThemeIdProvider) == 'sample.theme-starry'); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    await tester.pumpAndSettle();
    expect(c.read(themePacksProvider).single.sideloaded, isTrue);
    expect(c.read(activeThemeIdProvider), 'sample.theme-starry');
    expect(find.textContaining('ファイルから読み込み(未審査)'), findsOneWidget);
    await c.read(settingsAreaProvider(themeSettingsArea).notifier).set('id', null);
  });
}
