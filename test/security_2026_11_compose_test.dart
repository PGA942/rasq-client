import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/child_safe/child_gate.dart';
import 'package:rasq_client/features/child_safe/child_safe_policy.dart';
import 'package:rasq_client/features/child_safe/child_safe_providers.dart';
import 'package:rasq_client/features/compose/compose_providers.dart';
import 'package:rasq_client/features/compose/compose_target.dart';
import 'package:rasq_client/features/compose/composer_sheet.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// セキュリティ確認 2026-11-11(rasq-client)の #9 / #10 / #8 / #23 / #24。
const okAcct = AccountId(kind: SnsKind.misskey, instance: 'ok.example', handle: 'kid');
const ngAcct = AccountId(kind: SnsKind.misskey, instance: 'ng.example', handle: 'kid');
const onlyOk = ChildSafeSnsAllow(kinds: ['misskey'], instances: ['ok.example']);
const alice = UserSummary(id: 'alice', account: AccountId(kind: SnsKind.misskey, instance: 'ok.example', handle: 'alice'), displayName: 'アリス');

AccountSession sess(AccountId a) => AccountSession(account: a, pluginId: 'test.fake', token: 'tok-${a.key}', createdAt: DateTime(2026));

ChildGate kid({Map<String, bool>? features, Map<String, bool>? search, ChildSafeTimeline timeline = const ChildSafeTimeline()}) => ChildGate(
      state: ChildSafeState(managed: true, state: 'active', policy: ChildSafePolicy(timeline: timeline, allow: ChildSafeAllow(features: features, search: search))),
      now: DateTime(2026, 11, 11, 12),
    );

/// アプリの中のチャイルドセーフ(見守られていない = null を書く)に上書きされない、テストから変えられる SNS の制限。
class _TestSnsAllow extends ChildSnsAllowStore {
  @override
  ChildSafeSnsAllow? build() => null;
  @override
  void set(ChildSafeSnsAllow? v) {}
  void force(ChildSafeSnsAllow? v) => state = v;
}

/// 変えられる見守りの関所。
class _GateBox extends Notifier<ChildGate> {
  _GateBox(this.initial);
  final ChildGate initial;
  @override
  ChildGate build() => initial;
  void set(ChildGate g) => state = g;
}

void main() {
  Post post(AccountId a, String id, String body, {UserSummary? author}) => Post(id: id, account: a, author: author ?? alice, createdAt: DateTime(2026, 11, 11, 10), body: body);

  late NotifierProvider<_GateBox, ChildGate> gateBox;

  Future<(ProviderContainer, FakeSnsPlugin)> pumpApp(WidgetTester tester, {ChildGate? gate, List<AccountId> accounts = const [okAcct], SnsKind kind = SnsKind.misskey, String body = 'もとの投稿'}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final plugin = FakeSnsPlugin(kind: kind, posts: (v) => [post(v, 'p1', body)]);
    gateBox = NotifierProvider<_GateBox, ChildGate>(() => _GateBox(gate ?? ChildGate.off));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(MemorySessionStorage({
          SessionsNotifier.storageKey: jsonEncode({'sessions': [for (final a in accounts) sess(a).toJson()], 'current': accounts.first.key}),
        })),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(plugin)),
        childGateProvider.overrideWith((ref) => ref.watch(gateBox)),
        childSnsAllowProvider.overrideWith(_TestSnsAllow.new),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    return (ProviderScope.containerOf(tester.element(find.byType(RasqApp))), plugin);
  }

  FakeSnsSession? opened(FakeSnsPlugin p, AccountId a) => p.opened.where((s) => s.account.key == a.key).lastOrNull;

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const ValueKey('composer.input')), text);
    await tester.pump();
  }

  Future<void> tapSend(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('composer.send')));
    await tester.pumpAndSettle();
  }

  group('#9 見守りの「投稿」', () {
    test('判定: post=false なら投稿 / ダイレクト投稿を止める。DM は dm だけを見る。ダイレクトは post と dm の両方', () async {
      final daily = ChildSafeDaily(MemorySessionStorage({}));
      final now = DateTime(2026, 11, 11, 12);
      final noPost = kid(features: {'post': false});
      expect(childComposeFeatureBlock(noPost), contains(childSafeBlockedText));
      expect(childComposeFeatureBlock(noPost, direct: true), contains(childSafeBlockedText));
      expect(childComposeFeatureBlock(noPost, dm: true), isNull);
      expect(childComposeFeatureBlock(kid(features: {'dm': false}), direct: true), contains(childSafeBlockedText));
      expect(childComposeFeatureBlock(kid()), isNull);
      expect(childComposeFeatureBlock(ChildGate.off), isNull);
      expect((await childComposeVerdictFor(noPost, daily, now, text: 'こんにちは'))?.message, contains(childSafeBlockedText));
      expect(await childComposeVerdictFor(noPost, daily, now, text: 'こんにちは', dm: true), isNull);
    });

    testWidgets('通常のコンポーザー(ホームの作成ボタンと同じ入口)からも送らない', (tester) async {
      final (c, plugin) = await pumpApp(tester, gate: kid(features: {'post': false}));
      unawaited(showComposerWith(const ComposeNormal(), manager: c.read(overlayManagerProvider), router: c.read(routerProvider)));
      await tester.pumpAndSettle();
      await type(tester, 'こんにちは');
      await tapSend(tester);
      expect(opened(plugin, okAcct)?.lastDraft, isNull);
      expect(find.textContaining(childSafeBlockedText), findsWidgets);
    });

    testWidgets('開いたあとに保護者が投稿を止めても、送る前に確かめ直す', (tester) async {
      final (c, plugin) = await pumpApp(tester, gate: kid());
      unawaited(showComposerWith(const ComposeNormal(), manager: c.read(overlayManagerProvider), router: c.read(routerProvider)));
      await tester.pumpAndSettle();
      await type(tester, 'こんにちは');
      c.read(gateBox.notifier).set(kid(features: {'post': false}));
      await tester.pump();
      await tapSend(tester);
      expect(opened(plugin, okAcct)?.lastDraft, isNull);
    });
  });

  group('#10 開いたままのコンポーザーの送り先', () {
    testWidgets('B を投稿先にして開いたあと、B の SNS を止めると B へは送らない(A は残っている)', (tester) async {
      final (c, plugin) = await pumpApp(tester, accounts: [okAcct, ngAcct]);
      unawaited(showComposerWith(const ComposeNormal(), manager: c.read(overlayManagerProvider), router: c.read(routerProvider), postAs: sess(ngAcct)));
      await tester.pumpAndSettle();
      await type(tester, 'こんにちは');
      (c.read(childSnsAllowProvider.notifier) as _TestSnsAllow).force(onlyOk);
      await tester.pump();
      expect(c.read(usableSessionsProvider).map((s) => s.account), [okAcct]);
      await tester.tap(find.byKey(const ValueKey('composer.send')), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(opened(plugin, ngAcct)?.lastDraft, isNull);
      expect(opened(plugin, okAcct)?.lastDraft, isNull, reason: 'ほかのアカウントへ黙って送り替えない');
    });

    testWidgets('止めていなければ、選んだ B へ送れる', (tester) async {
      final (c, plugin) = await pumpApp(tester, accounts: [okAcct, ngAcct]);
      unawaited(showComposerWith(const ComposeNormal(), manager: c.read(overlayManagerProvider), router: c.read(routerProvider), postAs: sess(ngAcct)));
      await tester.pumpAndSettle();
      await type(tester, 'こんにちは');
      await tapSend(tester);
      expect(opened(plugin, ngAcct)?.lastDraft?.text, 'こんにちは');
    });
  });

  group('#8 SNS ごとの公開範囲', () {
    test('宣言: Bluesky は公開だけ。ほかは公開 / ホーム / フォロワー', () {
      expect(composeVisibilitiesFor(SnsKind.bluesky), ['public']);
      expect(composeVisibilitiesFor(SnsKind.misskey), composeAllVisibilities);
      expect(composeVisibilitiesFor(null), composeAllVisibilities);
      expect(composeVisibilitySupported(SnsKind.bluesky, 'followers'), isFalse);
      expect(composeVisibilitySupported(SnsKind.bluesky, null), isTrue);
      expect(composeVisibilitySupported(SnsKind.mastodon, 'followers'), isTrue);
    });

    testWidgets('Bluesky では公開範囲のボタンを出さない。フォロワー限定のまま送ろうとすると聞き、やめれば送らず、よければ公開で送る', (tester) async {
      const bsky = AccountId(kind: SnsKind.bluesky, instance: 'bsky.social', handle: 'kid.bsky.social');
      final (c, plugin) = await pumpApp(tester, accounts: [bsky], kind: SnsKind.bluesky);
      c.read(composeOptionsProvider.notifier).setVisibility('followers');
      unawaited(showComposerWith(const ComposeNormal(), manager: c.read(overlayManagerProvider), router: c.read(routerProvider)));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.lock_outline), findsNothing);
      await type(tester, 'こんにちは');
      await tapSend(tester);
      expect(find.byKey(const ValueKey('composer.visibility.sendPublic')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('composer.visibility.cancel')));
      await tester.pumpAndSettle();
      expect(opened(plugin, bsky)?.lastDraft, isNull);

      await tapSend(tester);
      await tester.tap(find.byKey(const ValueKey('composer.visibility.sendPublic')));
      await tester.pumpAndSettle();
      expect(opened(plugin, bsky)?.lastDraft?.visibility, 'public');
    });

    testWidgets('Misskey ではフォロワー限定をそのまま送る(聞かない)', (tester) async {
      final (c, plugin) = await pumpApp(tester);
      c.read(composeOptionsProvider.notifier).setVisibility('followers');
      unawaited(showComposerWith(const ComposeNormal(), manager: c.read(overlayManagerProvider), router: c.read(routerProvider)));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      await type(tester, 'こんにちは');
      await tapSend(tester);
      expect(find.byKey(const ValueKey('composer.visibility.sendPublic')), findsNothing);
      expect(opened(plugin, okAcct)?.lastDraft?.visibility, 'followers');
    });
  });

  group('#23 DM 一覧の最新の 1 行', () {
    const denyHorror = ChildSafeTimeline(enabled: true, level: ChildSafeLevel.mild, topics: ChildSafeTopics(topics: ['ホラー']));

    testWidgets('部屋で見せない本文は、一覧にも出さない。制限を外せば出る', (tester) async {
      final (c, _) = await pumpApp(tester, gate: kid(timeline: denyHorror), body: 'ホラーの話をしよう');
      await tester.tap(find.byTooltip('DM'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('dm.lastHidden')), findsOneWidget);
      expect(find.textContaining('ホラーの話'), findsNothing);

      c.read(gateBox.notifier).set(kid());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('dm.lastHidden')), findsNothing);
      expect(find.textContaining('ホラーの話'), findsOneWidget);
    });
  });

  group('#24 ユーザーの検索', () {
    test('共通の口: 呼ぶ前と、結果のあとに今の許可を見る', () async {
      var gate = kid(search: {'users': false});
      var calls = 0;
      Future<int> search() async {
        calls++;
        return 1;
      }

      await expectLater(childSafeUserSearch(() => gate, search), throwsA(isA<ChildSafeUserSearchBlocked>()));
      expect(calls, 0);

      gate = kid();
      expect(await childSafeUserSearch(() => gate, search), 1);

      final pending = Completer<int>();
      final f = childSafeUserSearch(() => gate, () => pending.future);
      gate = kid(search: {'users': false});
      pending.complete(2);
      await expectLater(f, throwsA(isA<ChildSafeUserSearchBlocked>()));
    });

    test('RAi の user.search も止める', () {
      expect(kid(search: {'users': false}).raiBlockReason('user.search'), isNotNull);
    });

    testWidgets('DM の相手選び: 止めていれば検索欄を出さず、SNS を探さない', (tester) async {
      await pumpApp(tester, gate: kid(search: {'users': false}));
      await tester.tap(find.byTooltip('DM'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('新規メッセージ'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('dm.userSearch.blocked')), findsOneWidget);
      expect(find.text('DM を送る相手を検索します。'), findsNothing);
    });
  });
}
