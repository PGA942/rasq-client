import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';

import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart' show overlayManagerProvider;
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/nodeprog/node_tabs.dart' show nodeprogAreaFor;
import 'package:rasq_client/features/nodeprog/timeline_config_screen.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/features/nodeprog/tl_components.dart';
import 'package:rasq_design/rasq_design.dart' show RasqTabs;
import 'package:rasq_overlay/rasq_overlay.dart' show OverlayHost;
import 'package:rasq_client/features/notifications/notification_node_view.dart';
import 'package:rasq_client/features/notifications/notification_nodes.dart';
import 'package:rasq_client/features/notifications/notification_prefs.dart';
import 'package:rasq_client/features/notifications/notifications_screen.dart';
import 'package:rasq_client/notify/local_notifier.dart';
import 'package:rasq_client/notify/push_fcm.dart';
import 'package:rasq_client/session/session_providers.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

// 通知のタブとノード (D-590): 通知の画面の表示はノードで組める。push 通知はノードの外。

const _me = AccountId(kind: SnsKind.misskey, instance: 'misskey.io', handle: 'me');
const _other = AccountId(kind: SnsKind.mastodon, instance: 'mstdn.jp', handle: 'me2');

NotificationItem _n(String id, NotificationKind kind, int minute, {AccountId account = _me, String name = 'だれか', String? body}) => NotificationItem(
      id: id,
      account: account,
      kind: kind,
      createdAt: DateTime.utc(2026, 11, 17, 10, minute),
      read: true,
      actors: [UserSummary(id: 'u-$id', account: AccountId(kind: account.kind, instance: account.instance, handle: 'p$id'), displayName: name)],
      body: body,
    );

class _FakePush implements PushMessaging {
  final fg = StreamController<({String title, String body, Map<String, String> data})>.broadcast();
  @override
  Future<String?> token() async => 'fcm-token';
  @override
  Stream<String> get tokenRefresh => const Stream.empty();
  @override
  Stream<({String title, String body, Map<String, String> data})> get foreground => fg.stream;
  @override
  Stream<Map<String, String>> get opened => const Stream.empty();
}

AccountSession _session(AccountId a) => AccountSession(account: a, pluginId: 'p', token: 't', createdAt: DateTime.utc(2026));

void main() {
  group('ノードの形', () {
    test('通知ノードの種類とフォロー中は kind id に書いて読める', () {
      expect(NotifNodeSpec.parse('notif')!.groups, isEmpty);
      expect(NotifNodeSpec.parse('home'), isNull);
      const spec = NotifNodeSpec(groups: {NotifKindGroup.reactions, NotifKindGroup.mentions}, followingOnly: true);
      expect(spec.tl, 'notif:mentions,reactions,following');
      final back = NotifNodeSpec.parse(spec.tl)!;
      expect(back.groups, {NotifKindGroup.mentions, NotifKindGroup.reactions});
      expect(back.followingOnly, isTrue);
      expect(back.acceptsKind(NotificationKind.reply), isTrue);
      expect(back.acceptsKind(NotificationKind.follow), isFalse);
      expect(const NotifNodeSpec().acceptsKind(NotificationKind.system), isTrue, reason: '種類を絞らなければ全部');
      // 保存した構成(TlConfig の JSON)を通っても同じ。
      final cfg = TlConfig.fromJson(TlConfig(sources: [TlSourceComponent(tl: spec.tl, account: notifAllAccounts)]).toJson());
      expect(cfg.sources.single.isNotif, isTrue);
      expect(cfg.sources.single.account, notifAllAccounts);
    });

    test('最初からあるタブは前の画面と同じ中身。タブの並びは最初からあるタブを必ず含む', () {
      expect(defaultNotifConfig('notif.all').sources.single.tl, 'notif');
      expect(defaultNotifConfig('notif.following').sources.single.notifSpec.followingOnly, isTrue);
      expect(defaultNotifConfig('notif.mentions').sources.single.notifSpec.groups, {NotifKindGroup.mentions});
      expect(defaultNotifConfig('notif.rasq').sources.single.isRasqNotices, isTrue);
      expect([for (final t in parseNotifTabs(null)) t.id], notifBuiltinTabs);
      final saved = parseNotifTabs('[{"id":"u1","label":"仕事"},{"id":"mentions"}]');
      expect([for (final t in saved) t.id], ['u1', 'mentions', 'all', 'following', 'rasq']);
      expect(saved.first.builtin, isFalse);
      expect(nextNotifTabId(saved), 'u2');
    });

    test('アルゴリズム: 時系列順 / 検索絞り込み(含む・除く)。重ねた通知は 1 つに', () {
      final a = _n('a', NotificationKind.reaction, 1, name: '猫好き');
      final b = _n('b', NotificationKind.mention, 3, body: 'ネタバレ注意');
      final c = _n('c', NotificationKind.follow, 2);
      final merged = mergeNotifications([
        [a, b],
        [b, c],
      ]);
      expect([for (final n in merged) n.id], ['b', 'c', 'a']);
      expect([for (final n in applyNotifAlgorithms(merged, const [TlAlgorithmComponent(type: 'queryfilter', query: '猫')])) n.id], ['a']);
      expect([for (final n in applyNotifAlgorithms(merged, const [TlAlgorithmComponent(type: 'queryfilter', query: 'ネタバレ', exclude: true)])) n.id], ['c', 'a']);
      expect(applyNotifAlgorithms(merged, const [TlAlgorithmComponent(type: 'queryfilter')]).length, 3, reason: '語が空なら何もしない');
      expect(applyNotifAlgorithms(merged, const [TlAlgorithmComponent(type: 'suggest')]).length, 3, reason: '重いアルゴリズムは通知には掛けない');
    });

    test('ノードのアカウント: 空 = いま、* = 全部、表記 = そのアカウント(いまのアカウントは同じ読み込みを使う)', () {
      final usable = [_session(_me), _session(_other)];
      expect(notifSourceKeysOf(usable, _me.key, ''), ['']);
      expect(notifSourceKeysOf(usable, _me.key, notifAllAccounts), ['', _other.key]);
      expect(notifSourceKeysOf(usable, _me.key, '$_other'), [_other.key]);
      expect(notifSourceKeysOf(usable, _me.key, '@gone@example.com'), isEmpty);
      expect(notifSourceKeysOf(const [], null, notifAllAccounts), ['']);
    });
  });

  group('通知の画面', () {
    Future<ProviderContainer> pump(WidgetTester tester, {List<Override> extra = const [], List<NotificationItem>? items}) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      late ProviderContainer c;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          sessionStorageProvider.overrideWithValue(MemorySessionStorage({})),
          notificationsProvider.overrideWith((ref) async => Page(items: items ?? [_n('m1', NotificationKind.mention, 5), _n('r1', NotificationKind.reaction, 4), _n('f1', NotificationKind.follow, 3)])),
          ...extra,
        ],
        child: Consumer(builder: (context, ref, _) {
          c = ProviderScope.containerOf(context);
          return MaterialApp(home: OverlayHost(manager: ref.watch(overlayManagerProvider), child: const NotificationsScreen()));
        }),
      ));
      await tester.pumpAndSettle();
      return c;
    }

    Finder tab(String label) => find.descendant(of: find.byType(RasqTabs), matching: find.text(label));
    List<String> shownIds(WidgetTester tester) => [for (final t in tester.widgetList<NotificationTile>(find.byType(NotificationTile))) t.item.id];

    testWidgets('タブ: すべて / フォロー中 / メンション。メンションのタブはメンションだけ', (tester) async {
      await pump(tester);
      expect(tab('すべて'), findsOneWidget);
      expect(tab('フォロー中'), findsOneWidget);
      expect(tab('メンション'), findsOneWidget);
      expect(tab('RASQ'), findsNothing, reason: 'RASQ アカウントにログインしていなければ出さない');
      expect(shownIds(tester), ['m1', 'r1', 'f1']);
      await tester.tap(tab('メンション'));
      await tester.pumpAndSettle();
      expect(shownIds(tester), ['m1']);
    });

    testWidgets('保存した構成でタブの中身が変わる(種類のノード + 検索絞り込み)', (tester) async {
      final c = await pump(tester);
      await tester.runAsync(() => writeNotifConfig(
          c,
          null,
          'notif.all',
          TlConfig(sources: [TlSourceComponent(tl: const NotifNodeSpec(groups: {NotifKindGroup.reactions, NotifKindGroup.follows}).tl)], algorithms: const [TlAlgorithmComponent(type: 'chrono')])));
      await tester.pumpAndSettle();
      expect(shownIds(tester), ['r1', 'f1']);
      // 通知プロファイルの種類の ON/OFF (D-238) は、ノードの上からも全部のタブに掛かる。
      c.read(notificationPrefsProvider.notifier).setKind(NotificationKind.follow, false);
      await tester.pumpAndSettle();
      expect(shownIds(tester), ['r1']);
    });

    testWidgets('全部のアカウントのノード: アカウントごとの通知を合わせ、受け取ったアカウントを出す', (tester) async {
      final c = await pump(tester, extra: [
        usableSessionsProvider.overrideWithValue([_session(_me), _session(_other)]),
        currentAccountProvider.overrideWithValue(_me),
        accountNotificationsProvider(_other.key).overrideWith((ref) async => Page(items: [_n('o1', NotificationKind.mention, 9, account: _other)])),
      ]);
      await tester.runAsync(() => writeNotifConfig(c, _me.key, 'notif.all', const TlConfig(sources: [TlSourceComponent(tl: notifNodeKind, account: notifAllAccounts)], algorithms: [TlAlgorithmComponent(type: 'chrono')])));
      await tester.pumpAndSettle();
      expect(shownIds(tester), ['o1', 'm1', 'r1', 'f1']);
      expect(find.text('@me2@mstdn.jp への通知'), findsOneWidget);
      expect(find.text('@me@misskey.io への通知'), findsNWidgets(3));
    });

    testWidgets('「+」でアカウントごとのタブを足すと、そのアカウントの通知だけのタブができる', (tester) async {
      final c = await pump(tester, extra: [
        usableSessionsProvider.overrideWithValue([_session(_other)]),
        accountNotificationsProvider(_other.key).overrideWith((ref) async => Page(items: [_n('o1', NotificationKind.mention, 9, account: _other)])),
      ]);
      await tester.tap(find.byKey(const ValueKey('notifications.addTab')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('アカウントごとのタブ'));
      // 足したらカスタマイズの画面へ進む(ルーターはこのテストに無いので、タブだけ確かめる)。
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      final tabs = c.read(notifTabsProvider);
      expect(tabs.last.label, '@me2');
      expect(tab('@me2'), findsOneWidget);
      await tester.tap(tab('@me2'));
      await tester.pumpAndSettle();
      expect(shownIds(tester), ['o1']);
    });
  });

  group('カスタマイズの画面(通知のタブ)', () {
    testWidgets('通知用のパレットとアルゴリズムだけ。保存はノードグラフにしない', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final storage = MemorySessionStorage({
        SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
      });
      final registry = PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline));
      await tester.pumpWidget(ProviderScope(overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry)], child: const RasqApp()));
      await tester.pumpAndSettle();
      final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
      unawaited(c.read(routerProvider).push(Routes.tlConfig('notif.mentions')));
      await tester.pumpAndSettle();
      Finder inScreen(Finder f) => find.descendant(of: find.byType(TimelineConfigScreen), matching: f);
      expect(inScreen(find.text('通知のタブの中身を、ノードで組みます(上から順に)')), findsOneWidget);
      expect(inScreen(find.text('通知のノード')), findsOneWidget);
      // タブ行は通知のタブ。
      expect(inScreen(find.text('すべて')), findsOneWidget);
      expect(inScreen(find.text('メンション')), findsWidgets);
      expect(inScreen(find.text('メンション・返信・引用 の通知')), findsOneWidget);

      // アルゴリズムは検索絞り込みと時系列順だけ。
      await tester.tap(inScreen(find.text('アルゴリズムを追加')));
      await tester.pumpAndSettle();
      expect(find.text('検索絞り込み'), findsOneWidget);
      expect(find.text('サジェスト'), findsNothing);
      c.read(overlayManagerProvider).close(tlConfigPaletteFowId);
      await tester.pumpAndSettle();

      // ノードのパレット: 通知 / RASQ の通知 / 開始通知の予定 / セクション(TL の取得元は出さない)。
      await tester.tap(inScreen(find.text('ノードを追加')));
      await tester.pumpAndSettle();
      expect(find.text('通知((現在のアカウント))'), findsOneWidget);
      expect(find.text('RASQ の通知'), findsOneWidget);
      expect(find.text('タイムラインを取得'), findsNothing);
      await tester.tap(find.text('RASQ の通知'));
      await tester.pumpAndSettle();

      final area = await tester.runAsync(() => c.read(settingsAreaProvider(nodeprogAreaFor(fakeSession().account.key, 'notif.mentions')).future));
      final cfg = TlConfig.fromJson((jsonDecode(area!['tlcfg'] as String) as Map).cast<String, Object?>());
      expect([for (final s in cfg.sources) s.tl], ['notif:mentions', rasqNoticesNodeKind]);
      expect(area['graph'], isNull, reason: '通知のタブはノードグラフにしない(push 通知もグラフでは組めない)');
    });
  });

  group('push 通知はノードの外', () {
    test('通知のノードをどう組んでも、前面で届いた push は同じように端末の通知になる', () async {
      Future<int> shownAfterPush(Future<void> Function(ProviderContainer c) configure) async {
        final push = _FakePush();
        final local = MemoryLocalNotifier();
        final c = ProviderContainer(overrides: [
          sessionStorageProvider.overrideWithValue(MemorySessionStorage({})),
          pushMessagingProvider.overrideWithValue(push),
          localNotifierProvider.overrideWithValue(local),
        ]);
        addTearDown(c.dispose);
        await configure(c);
        c.read(pushBridgeProvider);
        push.fg.add((title: 'メンション', body: '@me こんにちは', data: const {'id': 'n1'}));
        push.fg.add((title: 'リアクション', body: '👍', data: const {'id': 'n2'}));
        await pumpEventQueue();
        return local.shown.length;
      }

      final baseline = await shownAfterPush((_) async {});
      expect(baseline, 2);
      // 全部のタブを空に・種類を絞る・タブを消して足す・通知プロファイルの種類もオフ。
      final changed = await shownAfterPush((c) async {
        for (final id in notifBuiltinTabs) {
          await writeNotifConfig(c, null, notifScopeOf(id), const TlConfig());
        }
        await writeNotifConfig(c, null, 'notif.u1', TlConfig(sources: [TlSourceComponent(tl: const NotifNodeSpec(groups: {NotifKindGroup.system}).tl)]));
        await saveNotifTabs(c, const [NotifTab(id: 'u1', label: 'システムだけ')]);
        c.read(notificationPrefsProvider.notifier).setKind(NotificationKind.mention, false);
        c.read(notificationPrefsProvider.notifier).setKind(NotificationKind.reaction, false);
        await pumpEventQueue();
      });
      expect(changed, baseline);
    });

    test('push / 受信箱 / 登録のコード(lib/notify)は、ノードと通知の画面を読み込まない', () {
      for (final f in Directory('lib/notify').listSync().whereType<File>().where((f) => f.path.endsWith('.dart'))) {
        final imports = [for (final l in f.readAsLinesSync()) if (l.startsWith('import ')) l];
        for (final l in imports) {
          expect(l.contains('nodeprog/') || l.contains('features/notifications/'), isFalse, reason: '${f.path}: $l');
        }
      }
      // 通知のノードの側も、push の口を読み込まない(表示だけ)。
      for (final p in ['lib/features/notifications/notification_nodes.dart', 'lib/features/notifications/notification_node_view.dart']) {
        final imports = [for (final l in File(p).readAsLinesSync()) if (l.startsWith('import ')) l];
        expect(imports.where((l) => l.contains('notify/')), isEmpty, reason: p);
      }
    });
  });
}
