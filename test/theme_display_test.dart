import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/backend/rasq_account.dart';
import 'package:rasq_client/features/profile/profile_image_flow.dart';
import 'package:rasq_client/features/theme/icon_theme/icon_theme_codec.dart';
import 'package:rasq_client/features/theme/icon_theme/icon_theme_editor_screen.dart';
import 'package:rasq_client/features/theme/icon_theme/icon_theme_reader.dart' show iconThemeProvider;
import 'package:rasq_client/features/theme/icon_theme/rasq_theme_spec.dart';
import 'package:rasq_client/features/theme/muted_themes_screen.dart';
import 'package:rasq_client/features/theme/theme_display.dart';
import 'package:rasq_client/features/theme/theme_packs.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart';
import 'package:rasq_client/l10n/gen/app_localizations.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:rasq_store/rasq_store.dart';

import 'support/fakes.dart';

/// ほかの人のテーマの出し方 (D-587): 着せ替えと同じ層・エフェクトは中身の上・設定(出す範囲 / 優先 / 値でのミュート)・
/// テーマ編集の固定の欄・プロフィールの画像の変更(画像を選ぶ → 全画面の加工画面)。
void main() {
  const basic = IconThemeBasic(bgMode: IconThemeBg.gradient, gradient: 2, bg: [17, 34, 68], text: [255, 255, 255], accent: [0, 204, 255], particle: 3, amount: 10, speed: 5);
  const spec = RasqThemeSpec(basic: basic, frames: [RasqThemeFrameRef(svgId: 'sakura', x: 0.9, y: 0.1, size: 0.3, opacity: 0.5)]);
  const viewer = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'me');
  const author = (viewer: viewer, userId: 'u1');

  Widget app(Widget home, {List overrides = const []}) => ProviderScope(
        overrides: [sessionStorageProvider.overrideWithValue(MemorySessionStorage()), ...overrides.cast()],
        child: MaterialApp(theme: RasqTheme.light(), locale: const Locale('ja'), localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, home: home),
      );

  group('値でのミュートのハッシュ', () {
    test('見た目が同じなら、出す場所・出どころが違っても同じ。色が 1 つ違えば別', () {
      final a = themeValueHash(spec.copyWith(scope: const RasqThemeScope.hashtag('x'), source: RasqThemeSource.atmos));
      expect(themeValueHash(spec), a);
      expect(themeValueHash(spec.copyWith(scope: const RasqThemeScope.thread('p1'))), a);
      const other = IconThemeBasic(bgMode: IconThemeBg.gradient, gradient: 2, bg: [17, 34, 69], text: [255, 255, 255], accent: [0, 204, 255], particle: 3, amount: 10, speed: 5);
      expect(themeValueHash(const RasqThemeSpec(basic: other, frames: [RasqThemeFrameRef(svgId: 'sakura', x: 0.9, y: 0.1, size: 0.3, opacity: 0.5)])), isNot(a));
      expect(a, hasLength(32));
    });
  });

  group('出すかどうか', () {
    Future<ProviderContainer> probe(WidgetTester tester, {ThemeAuthor? who = author, List overrides = const []}) async {
      await tester.pumpWidget(app(
        Consumer(builder: (_, ref, _) => Text(watchThemeVisible(ref, origin: ThemeOrigin.icon, spec: spec, author: who) ? 'shown' : 'hidden', textDirection: TextDirection.ltr)),
        overrides: overrides,
      ));
      await tester.pump();
      return ProviderScope.containerOf(tester.element(find.byType(Consumer)));
    }

    String shown() => find.text('shown').evaluate().isNotEmpty ? 'shown' : 'hidden';

    testWidgets('既定は全員に出す。「出さない」・値でミュートしたものは出さない', (tester) async {
      final c = await probe(tester);
      expect(shown(), 'shown');
      await c.read(settingsAreaProvider(themeSettingsArea).notifier).set('display.icon.scope', ThemeDisplayScope.off.name);
      await tester.pump();
      expect(shown(), 'hidden');
      await c.read(settingsAreaProvider(themeSettingsArea).notifier).set('display.icon.scope', ThemeDisplayScope.all.name);
      await tester.pump();
      expect(shown(), 'shown');
      final ref = tester.element(find.byType(Consumer)) as WidgetRef;
      await muteTheme(ref, spec.copyWith(source: RasqThemeSource.atmos), ThemeOrigin.atmos, now: DateTime.utc(2026, 11, 17));
      await tester.pump();
      expect(shown(), 'hidden', reason: '値で覚えるので、Atmos でミュートした同じ値もアイコンで出ない');
      expect(c.read(mutedThemesProvider).single.origin, ThemeOrigin.atmos);
      await unmuteTheme(ref, themeValueHash(spec));
      await tester.pump();
      expect(shown(), 'shown');
    });

    testWidgets('着せ替えを選んでいる間は、既定では出さない(優先をオンにすれば出す)', (tester) async {
      final c = await probe(tester, overrides: [activeSkinProvider.overrideWithValue(const RasqSkin(id: 'p', name: 'p'))]);
      expect(shown(), 'hidden');
      await setThemeOverPlugin(tester.element(find.byType(Consumer)) as WidgetRef, ThemeOrigin.icon, true);
      await tester.pump();
      expect(shown(), 'shown');
      expect(c.read(themeOverPluginProvider(ThemeOrigin.atmos)), isFalse, reason: '種類ごと');
    });

    testWidgets('「フォローしている人だけ」: フォローしていれば出す。分からない / していない人と、持ち主のいないタグのページ', (tester) async {
      final c = await probe(tester);
      await setThemeDisplayScope(tester.element(find.byType(Consumer)) as WidgetRef, ThemeOrigin.icon, ThemeDisplayScope.followees);
      await tester.pump();
      expect(shown(), 'hidden', reason: 'まだ分からない(問い合わせ中)');
      await tester.pump(const Duration(milliseconds: 300)); // まとめて問い合わせる待ち(セッションが無いので分からないまま)
      c.read(followStateProvider.notifier).apply(viewer.key, 'misskey:example.test:u1', const FollowState(following: true));
      await tester.pump();
      expect(shown(), 'shown');
      c.read(followStateProvider.notifier).apply(viewer.key, 'misskey:example.test:u1', const FollowState());
      await tester.pump();
      expect(shown(), 'hidden');
      await probe(tester, who: null);
      final ref = tester.element(find.byType(Consumer)) as WidgetRef;
      await setThemeDisplayScope(ref, ThemeOrigin.icon, ThemeDisplayScope.followees);
      await tester.pump();
      expect(shown(), 'shown', reason: 'タグのページには持ち主がいない');
    });
  });

  group('付け方(着せ替えと同じ層)', () {
    testWidgets('色を上書きし、背景を敷き、エフェクトは中身の上。押すのは中身に届き、テーマが後から付いても中身は作り直さない', (tester) async {
      final holder = ValueNotifier<RasqThemeSpec?>(null);
      var taps = 0;
      Color? primary;
      await tester.pumpWidget(app(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: ValueListenableBuilder<RasqThemeSpec?>(
            valueListenable: holder,
            builder: (_, s, _) => ThemedSurface(
              spec: s,
              child: Scaffold(
                body: Center(
                  child: Builder(builder: (context) {
                    primary = Theme.of(context).colorScheme.primary;
                    return _Counter(onTap: () => taps++);
                  }),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.byKey(const ValueKey('counter')));
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
      expect(find.byKey(const ValueKey('iconTheme.particles')), findsNothing);

      holder.value = spec;
      await tester.pump();
      expect(primary, const Color(0xFF00CCFF));
      expect(find.byKey(const ValueKey('iconTheme.particles')), findsOneWidget);
      expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, isNull);
      expect(Theme.of(tester.element(find.byType(Scaffold))).scaffoldBackgroundColor, Colors.transparent, reason: '下に敷いた背景を見せる');
      expect(find.text('1'), findsOneWidget, reason: '中身の状態はそのまま');
      // エフェクト(パーティクル・フレーム)は中身より後ろ(上)に描くが、押すのは中身に届く。
      final effects = tester.getRect(find.byKey(const ValueKey('iconTheme.particles')));
      expect(effects.contains(tester.getCenter(find.byKey(const ValueKey('counter')))), isTrue);
      await tester.tap(find.byKey(const ValueKey('counter')));
      await tester.pump();
      expect(find.text('2'), findsOneWidget);
      expect(taps, 2);
    });
  });

  group('ユーザーページ', () {
    testWidgets('その人のアイコンのテーマをページ全体に。「…」の「このテーマを表示しない」で値をミュートすると消える', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final avatar = Uri.parse('https://example.test/alice.png');
      final alice = UserSummary(id: 'u-alice', account: viewer, displayName: 'アリス', avatarUrl: avatar);
      final post = Post(id: 'a1', account: viewer, author: alice, createdAt: DateTime(2026, 11, 17), body: 'こんにちは');
      final storage = MemorySessionStorage({
        SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
      });
      await tester.pumpWidget(ProviderScope(
        overrides: [
          sessionStorageProvider.overrideWithValue(storage),
          pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: (_) => [post]))),
          iconThemeProvider.overrideWith((ref, url) async => url == avatar.toString() ? spec : null),
        ],
        child: const RasqApp(),
      ));
      await tester.pumpAndSettle();
      final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
      c.read(routerProvider).push('/user/${alice.id}', extra: alice);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      Finder themed() => find.byWidgetPredicate((w) => w is ThemedSurface && w.spec != null);
      expect(themed(), findsOneWidget);
      expect(find.byKey(const ValueKey('iconTheme.particles')), findsOneWidget, reason: 'エフェクトは中身の上');

      await tester.tap(find.byTooltip('メニュー').last);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.text('このテーマを表示しない'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(themed(), findsNothing);
      expect(c.read(mutedThemesProvider).single.hash, themeValueHash(spec));
    });
  });

  group('設定', () {
    testWidgets('ミュートしたテーマの一覧: 見本と解除。空なら案内', (tester) async {
      await tester.pumpWidget(app(const MutedThemesScreen()));
      await tester.pump();
      expect(find.byKey(const ValueKey('theme.muted.empty')), findsOneWidget);
      final ref = tester.element(find.byType(MutedThemesScreen)) as WidgetRef;
      await muteTheme(ref, spec, ThemeOrigin.icon);
      await tester.pump();
      final h = themeValueHash(spec);
      expect(find.byKey(ValueKey('theme.muted.$h')), findsOneWidget);
      expect(find.text('アイコンに埋め込まれたテーマ'), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('theme.muted.$h.unmute')));
      await tester.pump();
      expect(find.byKey(const ValueKey('theme.muted.empty')), findsOneWidget);
    });
  });

  group('テーマ編集の固定の欄', () {
    Future<void> open(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(const IconThemeEditorScreen()));
      for (var i = 0; i < 20 && find.byKey(const ValueKey('iconTheme.target')).evaluate().isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }
    }

    testWidgets('狭い: 変換先のアイコンと「画像を変更」は上に固定。「アイコンを選ぶ」「アップロード(見本)」の段は無い', (tester) async {
      await open(tester, const Size(420, 900));
      final pinned = tester.getRect(find.byKey(const ValueKey('iconTheme.pinned')));
      final stations = tester.getRect(find.byKey(const ValueKey('iconTheme.stations')));
      expect(pinned.bottom, lessThanOrEqualTo(stations.top + 1));
      expect(find.text('画像を変更'), findsOneWidget);
      expect(find.byKey(const ValueKey('iconTheme.sample')), findsNothing);
      expect(find.byKey(const ValueKey('iconTheme.station.03')), findsNothing);
      expect(find.text('アップロード(見本)'), findsNothing);
      // 段をスクロールしても、固定の欄は動かない。
      await tester.drag(find.byKey(const ValueKey('iconTheme.stations')), const Offset(0, -400));
      await tester.pump();
      expect(tester.getRect(find.byKey(const ValueKey('iconTheme.pinned'))), pinned);
    });

    testWidgets('2 カラムの幅: 固定の欄は左', (tester) async {
      await open(tester, const Size(1000, 900));
      final pinned = tester.getRect(find.byKey(const ValueKey('iconTheme.pinned')));
      final stations = tester.getRect(find.byKey(const ValueKey('iconTheme.stations')));
      expect(pinned.right, lessThanOrEqualTo(stations.left));
      expect(pinned.top, stations.top);
    });
  });

  group('プロフィールの画像の変更', () {
    http.Response json(Object body, [int code = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), code, headers: {'content-type': 'application/json'});

    testWidgets('「アイコンの変更」/ ヘッダーを押す → 画像を選ぶ → 全画面の加工画面 → 決めた画像。加工画面でやめたら変えない', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final me = <String, Object?>{'id': 'acc-1', 'handle': 'taro', 'displayName': 'タロ', 'bio': '', 'location': '', 'birthday': '', 'links': []};
      final mock = MockClient((req) async => req.method == 'GET' && req.url.path.endsWith('/me') ? json(me) : json({'error': {'code': '404', 'message': 'x'}}, 404));
      final storage = MemorySessionStorage({
        SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
        OrgateAccountNotifier.storageKey: jsonEncode({'deviceId': 'device-abc', 'token': 'device-token', 'accountId': 'acc-1'}),
      });
      final picked = (bytes: Uint8List.fromList([1, 2, 3]), name: 'pick.jpg', mime: 'image/jpeg');
      final edited = <ProfileImagePick>[];
      ProfileImagePick? answer;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          sessionStorageProvider.overrideWithValue(storage),
          pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline))),
          orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: mock, tokenProvider: () => ref.read(orgateTokenHolderProvider).token)),
          centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
          orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
          profileImagePickerProvider.overrideWithValue(() async => picked),
          profileImageEditorProvider.overrideWithValue((_, img) async {
            edited.add(img);
            return answer;
          }),
        ],
        child: const RasqApp(),
      ));
      await tester.pumpAndSettle();
      final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
      c.read(routerProvider).push('${Routes.settings}/rasq-profile');
      await tester.pumpAndSettle();
      Finder memoryIn(String key) => find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(Image));

      // 加工画面でやめた → 何も変えない。
      answer = null;
      await tester.tap(find.byKey(const ValueKey('rasqProfile.avatar.change')));
      await tester.pumpAndSettle();
      expect(edited.single.name, 'pick.jpg');
      expect(memoryIn('rasqProfile.avatar'), findsNothing);

      // 決めた → アイコンが加工後の画像に。
      answer = (bytes: Uint8List.fromList(_png1x1), name: 'edited.png', mime: 'image/png');
      await tester.tap(find.byKey(const ValueKey('rasqProfile.avatar.change')));
      await tester.pumpAndSettle();
      expect(edited, hasLength(2));
      expect((tester.widget<Image>(memoryIn('rasqProfile.avatar')).image as MemoryImage).bytes, _png1x1);

      // ヘッダーは押すだけで同じ流れ。
      await tester.tap(find.byKey(const ValueKey('rasqProfile.banner.change')));
      await tester.pumpAndSettle();
      expect(edited, hasLength(3));
      expect((tester.widget<Image>(memoryIn('rasqProfile.banner.change')).image as MemoryImage).bytes, _png1x1);
      // 名前の欄はアイコンの段の下。
      expect(tester.getRect(find.byKey(const ValueKey('rasqProfile.name'))).top, greaterThan(tester.getRect(find.byKey(const ValueKey('rasqProfile.avatar.change'))).bottom));
    });
  });
}

/// 1×1 の PNG(白)。
const _png1x1 = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, //
  0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54, 0x08, 0xD7, 0x63, 0xF8, 0xFF, 0xFF, 0x3F, 0x00, 0x05, 0xFE, 0x02, 0xFE, 0xDC, 0xCC, 0x59, 0xE7, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, //
  0x44, 0xAE, 0x42, 0x60, 0x82,
];

class _Counter extends StatefulWidget {
  const _Counter({required this.onTap});
  final VoidCallback onTap;
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int _n = 0;
  @override
  Widget build(BuildContext context) => TextButton(
        key: const ValueKey('counter'),
        onPressed: () {
          widget.onTap();
          setState(() => _n++);
        },
        child: Text('$_n'),
      );
}
