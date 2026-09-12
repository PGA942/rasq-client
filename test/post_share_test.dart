import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/compose/compose_providers.dart';
import 'package:rasq_client/features/compose/account_select.dart';
import 'package:rasq_client/features/plugins/slot_plugins.dart';
import 'package:rasq_client/features/post/share_fow.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fake_slot_runtime.dart';
import 'support/fakes.dart';

/// 投稿の共有 FOW (D-170): ヘッダーのアカウント選択、コピー、他のアカウントで共有、
/// プラグイン(`post.share` の自動登録 → インライン FOW → `composer.open`)、DM へ共有。
void main() {
  const acc1 = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
  const acc2 = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'second');
  AccountSession session(AccountId a) => AccountSession(account: a, pluginId: 'test.fake', token: 't', createdAt: DateTime(2026), displayName: a.handle);
  Post post(AccountId a, {String id = 'p1', String body = 'こんにちは', String? visibility}) => Post(
        id: id,
        account: a,
        author: UserSummary(id: 'u-$id', account: a, displayName: '作者 $id'),
        createdAt: DateTime(2026, 9, 11),
        body: body,
        visibility: visibility,
        url: Uri.parse('https://example.test/notes/$id'),
      );

  // 1×1 PNG(添付タイルは Image.memory なので本物の画像が要る)。
  const onePx = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';
  late Map<String, FakeSlotRuntime Function()> fakes;
  final clipboard = <String>[];

  setUp(() {
    fakes = {};
    clipboard.clear();
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clipboard.add((call.arguments as Map)['text'] as String);
      return null;
    });
  });

  Future<(ProviderContainer, PluginRegistry)> pump(WidgetTester tester, {required Post Function(AccountId) postOf}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [session(acc1).toJson(), session(acc2).toJson()], 'current': acc1.key}),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (v) => [postOf(v)]));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(registry),
        slotRuntimeLoaderProvider.overrideWithValue(fakeSlotLoader(fakes)),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    return (ProviderScope.containerOf(tester.element(find.byType(RasqApp))), registry);
  }

  Future<void> openShare(WidgetTester tester) async {
    await tester.tap(find.byTooltip('共有').first);
    await tester.pumpAndSettle();
    expect(find.byKey(postShareAccountKey), findsOneWidget);
  }

  testWidgets('共有 FOW: ヘッダーのアカウントピル、内容 / リンクのコピー、他のアカウントで共有 → そのアカウントのコンポーザーにリンク', (tester) async {
    final (c, registry) = await pump(tester, postOf: (a) => post(a, body: 'コピーされる本文'));
    await openShare(tester);
    // 公開投稿: 複数アカウントから選べる(ピルは押せる)。初期値は投稿を受け取ったアカウント。
    final pill = tester.widget<AccountSelectPill>(find.byKey(postShareAccountKey));
    expect(pill.account, acc1);
    expect(pill.onTap, isNotNull);
    await tester.tap(find.byKey(const ValueKey('post.share.copyContent')));
    await tester.pumpAndSettle();
    expect(clipboard.last, 'コピーされる本文');
    await tester.tap(find.byKey(const ValueKey('post.share.copyLink')));
    await tester.pumpAndSettle();
    expect(clipboard.last, 'https://example.test/notes/p1');
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first)).clearSnackBars();
    // ピル → ドロップダウンで second を選ぶ → 他のアカウントで共有 → second のコンポーザー。
    await tester.tap(find.byKey(postShareAccountKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('@second@example.test'));
    await tester.pumpAndSettle();
    expect(tester.widget<AccountSelectPill>(find.byKey(postShareAccountKey)).account, acc2);
    await tester.tap(find.byKey(const ValueKey('post.share.otherAccount')));
    await tester.pumpAndSettle();
    expect(find.byKey(postShareAccountKey), findsNothing); // 共有 FOW は閉じた
    final field = tester.widget<TextField>(find.byType(TextField).last);
    expect(field.controller!.text, 'https://example.test/notes/p1');
    // コンポーザーのピルも同じ見た目で、投稿先 = second。送信すると second のセッションに投稿される。
    final composerPill = tester.widget<AccountSelectPill>(find.byType(AccountSelectPill));
    expect(composerPill.account, acc2);
    await tester.tap(find.text('送信'));
    await tester.pumpAndSettle();
    final s2 = registry.session(session(acc2)) as FakeSnsSession;
    expect(s2.lastDraft?.text, 'https://example.test/notes/p1');
    expect(c.read(currentAccountProvider), acc1);
  });

  testWidgets('非公開投稿(specified)は受け取ったアカウントだけ: ピルは固定', (tester) async {
    await pump(tester, postOf: (a) => post(a, visibility: 'specified'));
    await openShare(tester);
    final pill = tester.widget<AccountSelectPill>(find.byKey(postShareAccountKey));
    expect(pill.account, acc1);
    expect(pill.onTap, isNull);
    expect(pill.tooltip, '受け取ったアカウントだけで共有できます');
  });

  testWidgets('プラグイン (§2.8): post.share を宣言しただけで並ぶ → post.share {post, account, link} → 子 FOW がインライン → composer.open でコンポーザー(文面 + 画像)→ 閉じると post.share.close', (tester) async {
    late FakeSlotRuntime rt;
    fakes['share'] = () => rt = FakeSlotRuntime(
          manifest: {'id': 't.share', 'name': '共有テンプレート', 'version': '0.1.0', 'kind': 'action', 'description': '文面を整える', 'slots': ['post.share'], 'permissions': ['fow.widget']},
          handler: (self, fn, args) {
            if (fn == 'post.share') {
              self.openFow('share-template', {'t': 'Column', 'k': 'root', 'c': [
                {'t': 'Text', 'k': 'hint', 'p': {'text': '文面: ${args['link']}'}},
                {'t': 'Button', 'k': 'go', 'p': {'label': 'コンポーザーへ'}, 'on': {'tap': 'go'}},
              ]}, title: '共有テンプレート');
              return {};
            }
            if (fn == 'go') {
              self.hostFn('composer.open', {'token': self.calls.firstWhere((x) => x.$1 == 'post.share').$2['token'], 'text': '「こんにちは」\nhttps://example.test/notes/p1', 'mediaB64': onePx, 'mimeType': 'image/png', 'name': 'card.png'});
              return {};
            }
            return {};
          },
        );
    final (c, _) = await pump(tester, postOf: (a) => post(a));
    final p = await c.read(slotPluginsProvider.notifier).register('fake:share', bytes: Uint8List.fromList('share'.codeUnits));
    expect(p, isNotNull);
    expect(p!.manifest.appFns, containsAll(['composer.open', 'astell.share']));
    await tester.pumpAndSettle();
    await openShare(tester);
    // 権限(マニフェスト)から自動で並ぶ。
    expect(find.byKey(const ValueKey('post.share.plugin.t.share')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('post.share.plugin.t.share')));
    await tester.pumpAndSettle();
    final call = rt.calls.where((x) => x.$1 == 'post.share').single.$2;
    expect(call['link'], 'https://example.test/notes/p1');
    expect((call['post'] as Map)['url'], 'https://example.test/notes/p1');
    expect((call['post'] as Map)['body'], 'こんにちは');
    expect(call['account'], {'sns': 'misskey', 'instance': 'example.test', 'handle': 'tester'});
    // プラグインの FOW は共有 FOW の子(インライン)。
    final manager = c.read(overlayManagerProvider);
    final entry = manager.entries.where((e) => e.id == 'fow.slot.t.share.share-template').single;
    expect(entry.ownerId, postShareFowId);
    expect(find.text('文面: https://example.test/notes/p1'), findsOneWidget);
    // composer.open → 共有 FOW(と子)が閉じ、選んだアカウントのコンポーザーに文面と画像。
    await tester.tap(find.text('コンポーザーへ'));
    await tester.pumpAndSettle();
    expect(find.byKey(postShareAccountKey), findsNothing);
    expect(manager.entries.where((e) => e.id.startsWith('fow.slot.')), isEmpty);
    expect(tester.widget<TextField>(find.byType(TextField).last).controller!.text, '「こんにちは」\nhttps://example.test/notes/p1');
    expect(find.byWidgetPredicate((w) => w is Image && w.image is MemoryImage), findsOneWidget);
    expect(rt.calls.where((x) => x.$1 == 'post.share.close').single.$2['token'], call['token']);
    // 下書きは添付も持つ (D-174): 閉じて下書き FOW から開き直しても画像が消えない(自動では入らない、D-177)。
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((w) => w is Image && w.image is MemoryImage), findsNothing);
    await tester.tap(find.byTooltip('投稿'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下書き'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('drafts.item.${c.read(composeDraftsProvider.notifier).list.single.id}')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField).last).controller!.text, '「こんにちは」\nhttps://example.test/notes/p1');
    expect(find.byWidgetPredicate((w) => w is Image && w.image is MemoryImage), findsOneWidget);
  });

  testWidgets('DM へ共有: 選んだアカウントの DM 相手を選ぶ → DM コンポーザーにリンク', (tester) async {
    final (_, registry) = await pump(tester, postOf: (a) => post(a));
    await openShare(tester);
    await tester.tap(find.byKey(const ValueKey('post.share.dm')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('post.share.dm.u-p1')));
    await tester.pumpAndSettle();
    expect(find.byKey(postShareAccountKey), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField).last).controller!.text, 'https://example.test/notes/p1');
    await tester.tap(find.text('送信'));
    await tester.pumpAndSettle();
    final s1 = registry.session(session(acc1)) as FakeSnsSession;
    expect(s1.lastDm?.text, 'https://example.test/notes/p1');
  });
}
