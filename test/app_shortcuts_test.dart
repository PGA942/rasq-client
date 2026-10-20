import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_actions/quick_actions.dart' show ShortcutItem;
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/app_shortcuts.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/child_safe/child_gate.dart';
import 'package:rasq_client/features/child_safe/child_safe_policy.dart';
import 'package:rasq_client/features/child_safe/child_safe_providers.dart';
import 'package:rasq_client/features/compose/composer_sheet.dart' show composerFowId;
import 'package:rasq_client/features/dm/dm_screen.dart' show dmNewSheetId;
import 'package:rasq_client/features/rai/rai_embedding_model.dart';
import 'package:rasq_client/features/rai/rai_home_screen.dart';
import 'package:rasq_client/features/rai/rai_llm.dart';
import 'package:rasq_client/features/rai/rai_providers.dart';
import 'package:rasq_client/features/search/search_filter_bar_view.dart' show SearchFilterBox;
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/child_safe_fakes.dart';
import 'support/fake_rai_embedding_model.dart';
import 'support/fake_rai_llm.dart';
import 'support/fakes.dart';

/// 端末のショートカットの口の代わり (quick_actions のチャネルを使わない)。[launch] = 起動のもとになったショートカット
/// (Android の getLaunchAction / iOS の起動時の項目と同じく、initialize の中で届く)。
class FakeShortcutsPlatform implements AppShortcutsPlatform {
  FakeShortcutsPlatform({this.launch});
  final String? launch;
  void Function(String type)? handler;
  List<ShortcutItem>? items;

  @override
  Future<void> initialize(void Function(String type) onAction) async {
    handler = onAction;
    if (launch != null) onAction(launch!);
  }

  @override
  Future<void> setItems(List<ShortcutItem> items) async => this.items = items;
}

ChildGate gateOf(Map<String, Object?> settings, {String state = 'active'}) =>
    ChildGate(state: ChildSafeState(managed: true, state: state, policy: ChildSafePolicy.fromJson(settings)), now: DateTime(2026, 9, 24, 12));

/// ホーム画面のアプリのショートカット (D-483)。
void main() {
  group('種類 / 名前 / 端末の設定', () {
    test('種類 ↔ ショートカット、知らない種類は null', () {
      for (final s in AppShortcut.values) {
        expect(AppShortcut.fromType(s.type), s);
      }
      expect(AppShortcut.fromType('rasq.unknown'), isNull);
      expect(AppShortcut.fromType(null), isNull);
    });

    test('名前は 1 か所(X と同じ 3 つ + RAiと探す)', () {
      expect([for (final s in AppShortcut.values) appShortcutLabel(s)], ['検索', '新しいポスト', 'メッセージを作成', 'RAiと探す']);
    });

    test('Android は動的な 4 項目(名前 + drawable のアイコン)、iOS は Info.plist の静的な項目なので置かない', () {
      final items = appShortcutItemsFor(TargetPlatform.android);
      expect([for (final i in items) i.type], [for (final s in AppShortcut.values) s.type]);
      expect([for (final i in items) i.localizedTitle], [for (final s in AppShortcut.values) appShortcutLabel(s)]);
      for (final i in items) {
        expect(File('android/app/src/main/res/drawable/${i.icon}.xml').existsSync(), isTrue, reason: '${i.icon} (API 25)');
        expect(File('android/app/src/main/res/drawable-anydpi-v26/${i.icon}.xml').existsSync(), isTrue, reason: '${i.icon} (adaptive)');
      }
      expect(appShortcutItemsFor(TargetPlatform.iOS), isEmpty);
    });

    test('iOS の Info.plist の項目と InfoPlist.strings が Dart の種類 / 名前と揃っている', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      final types = RegExp(r'<key>UIApplicationShortcutItemType</key>\s*<string>([^<]+)</string>').allMatches(plist).map((m) => m.group(1)).toList();
      final titles = RegExp(r'<key>UIApplicationShortcutItemTitle</key>\s*<string>([^<]+)</string>').allMatches(plist).map((m) => m.group(1)).toList();
      final symbols = RegExp(r'<key>UIApplicationShortcutItemIconSymbolName</key>\s*<string>([^<]+)</string>').allMatches(plist).map((m) => m.group(1)).toList();
      expect(types, [for (final s in AppShortcut.values) s.type]);
      expect(titles, [for (final s in AppShortcut.values) appShortcutLabel(s)]);
      expect(symbols, ['magnifyingglass', 'square.and.pencil', 'envelope', 'sparkles']);
      Map<String, String> strings(String lang) => {
            for (final m in RegExp(r'^"([^"]+)" = "([^"]+)";$', multiLine: true).allMatches(File('ios/Runner/$lang.lproj/InfoPlist.strings').readAsStringSync())) m.group(1)!: m.group(2)!,
          };
      expect(strings('ja'), {for (final t in titles) t!: t});
      expect(strings('en'), {'検索': 'Search', '新しいポスト': 'New post', 'メッセージを作成': 'New message', 'RAiと探す': 'Search with RAi'});
      // ほかの言語も同じキー(日本語の既定の名前)を全部訳す。
      for (final lang in ['zh-Hans', 'zh-Hant', 'ko']) {
        expect(strings(lang).keys.toSet(), titles.toSet(), reason: lang);
      }
    });
  });

  group('行き先と関所 (planAppShortcut)', () {
    test('ふだん: 検索タブ / いまの画面に投稿 / DM で新規メッセージ / RAi を入力にフォーカス', () {
      final off = ChildGate.off;
      expect(planAppShortcut(AppShortcut.search, loggedIn: true, gate: off), (location: Routes.search, followUp: AppShortcutFollowUp.focusSearch, blocked: null));
      expect(planAppShortcut(AppShortcut.newPost, loggedIn: true, gate: off), (location: null, followUp: AppShortcutFollowUp.composePost, blocked: null));
      expect(planAppShortcut(AppShortcut.newMessage, loggedIn: true, gate: off), (location: Routes.dm, followUp: AppShortcutFollowUp.composeMessage, blocked: null));
      expect(planAppShortcut(AppShortcut.askRai, loggedIn: true, gate: off), (location: Routes.raiAsk, followUp: AppShortcutFollowUp.askRai, blocked: null));
    });

    test('ログインしていない: どれも移らず案内だけ(ルーターが入口に置いている)', () {
      for (final s in AppShortcut.values) {
        expect(planAppShortcut(s, loggedIn: false, gate: ChildGate.off), (location: null, followUp: AppShortcutFollowUp.none, blocked: appShortcutLoginHint));
      }
    });

    test('見守り: 保護者が決めるまで(鍵)はどれも開かない', () {
      final locked = ChildGate(state: const ChildSafeState(managed: true, state: 'pending_setup'));
      expect(locked.locked, isTrue);
      for (final s in AppShortcut.values) {
        final p = planAppShortcut(s, loggedIn: true, gate: locked);
        expect(p.location, isNull);
        expect(p.blocked, isNotNull);
      }
    });

    test('見守り: 止めている機能(DM / RAi / 検索 / 投稿)は開かず理由を出す。止めていないものは開く', () {
      // v2() は DM と ASTell を止めている。
      final gate = gateOf(v2());
      expect(planAppShortcut(AppShortcut.newMessage, loggedIn: true, gate: gate).blocked, '保護者が DM を止めています');
      expect(planAppShortcut(AppShortcut.newMessage, loggedIn: true, gate: gate).location, isNull);
      expect(planAppShortcut(AppShortcut.newPost, loggedIn: true, gate: gate).blocked, isNull);

      final noRai = v2();
      ((noRai['allow'] as Map)['rai'] as Map)['enabled'] = false;
      expect(planAppShortcut(AppShortcut.askRai, loggedIn: true, gate: gateOf(noRai)).blocked, '保護者が RAi を止めています');

      final noSearch = v2();
      (noSearch['allow'] as Map)['search'] = {'posts': false, 'users': false, 'trend': false, 'store': false};
      expect(planAppShortcut(AppShortcut.search, loggedIn: true, gate: gateOf(noSearch)).blocked, '保護者が検索を止めています');

      final noPost = v2();
      ((noPost['allow'] as Map)['features'] as Map)['post'] = false;
      expect(planAppShortcut(AppShortcut.newPost, loggedIn: true, gate: gateOf(noPost)).blocked, contains('投稿'));
    });
  });

  group('アプリの中で開く', () {
    late FakeShortcutsPlatform platform;

    Future<ProviderContainer> pump(WidgetTester tester, {String? launch, bool loggedIn = true, ChildGate? gate}) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      rootBundle.clear();
      platform = FakeShortcutsPlatform(launch: launch);
      final storage = MemorySessionStorage({
        if (loggedIn) SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
      });
      final registry = PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline));
      await tester.pumpWidget(ProviderScope(
        overrides: [
          sessionStorageProvider.overrideWithValue(storage),
          pluginRegistryProvider.overrideWithValue(registry),
          appShortcutsPlatformProvider.overrideWithValue(platform),
          raiLlmProvider.overrideWithValue(FakeRaiLlm(phase: RaiLlmPhase.ready)),
          raiEmbeddingModelProvider.overrideWithValue(FakeRaiEmbeddingModel()),
          deviceRamReaderProvider.overrideWithValue(() async => (totalMb: 8192, availableMb: 4096)),
          if (gate != null) childGateProvider.overrideWithValue(gate),
        ],
        child: const RasqApp(),
      ));
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    }

    String visible(ProviderContainer c) => visibleLocationOf(c.read(routerProvider).routerDelegate.currentConfiguration);

    Future<void> tapShortcut(WidgetTester tester, AppShortcut s) async {
      platform.handler!(s.type);
      await tester.pumpAndSettle();
    }

    testWidgets('起動したら端末へ項目を置く(テストの既定の端末は Android)', (tester) async {
      await pump(tester);
      expect(platform.handler, isNotNull);
      expect(platform.items?.map((i) => i.type), [for (final s in AppShortcut.values) s.type]);
    });

    testWidgets('コールドスタート: 起動のもとのショートカット(メッセージを作成)を、ログインを読み終えてから開く', (tester) async {
      final c = await pump(tester, launch: AppShortcut.newMessage.type);
      expect(visible(c), Routes.dm);
      expect(c.read(overlayManagerProvider).contains(dmNewSheetId), isTrue);
      expect(find.text('新規メッセージ'), findsWidgets);
    });

    testWidgets('検索: 検索タブを開いて検索欄にフォーカス', (tester) async {
      final c = await pump(tester);
      expect(visible(c), Routes.home);
      await tapShortcut(tester, AppShortcut.search);
      expect(visible(c), Routes.search);
      expect(tester.widget<SearchFilterBox>(find.byType(SearchFilterBox)).focusNode!.hasFocus, isTrue);
    });

    testWidgets('新しいポスト: いまの画面の上に投稿のコンポーザー', (tester) async {
      final c = await pump(tester);
      await tapShortcut(tester, AppShortcut.newPost);
      expect(c.read(overlayManagerProvider).contains(composerFowId), isTrue);
      expect(visible(c), Routes.home);
    });

    testWidgets('RAiと探す: RAi ホームを入力中で開く。もう開いていれば入力中に戻す', (tester) async {
      final c = await pump(tester);
      await tapShortcut(tester, AppShortcut.askRai);
      expect(find.byType(RaiHomeScreen), findsOneWidget);
      expect(c.read(raiProvider).asking, isTrue);
      expect(c.read(raiProvider).mode, RaiMode.assistant);
      expect(tester.widget<TextField>(find.byKey(const ValueKey('rai.input'))).focusNode!.hasFocus, isTrue);
      c.read(raiProvider.notifier).setAsking(false);
      await tester.pumpAndSettle();
      await tapShortcut(tester, AppShortcut.askRai);
      expect(find.byType(RaiHomeScreen), findsOneWidget); // 重ねて開かない
      expect(c.read(raiProvider).asking, isTrue);
    });

    testWidgets('見守りで DM を止めていれば、メッセージを作成は開かずに理由', (tester) async {
      final c = await pump(tester, gate: gateOf(v2()));
      await tapShortcut(tester, AppShortcut.newMessage);
      expect(visible(c), Routes.home);
      expect(c.read(overlayManagerProvider).contains(dmNewSheetId), isFalse);
      expect(find.text('保護者が DM を止めています'), findsOneWidget);
    });

    testWidgets('ログインしていない: 入口(オンボーディング)のまま案内だけ', (tester) async {
      final c = await pump(tester, loggedIn: false, launch: AppShortcut.newPost.type);
      expect(visible(c), Routes.onboarding);
      expect(c.read(overlayManagerProvider).contains(composerFowId), isFalse);
      expect(find.text(appShortcutLoginHint), findsOneWidget);
    });
  });
}
