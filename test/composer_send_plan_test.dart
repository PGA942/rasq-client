import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
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
import 'package:rasq_client/features/compose/poll_editor.dart';
import 'package:rasq_client/features/nodeprog/node_graph.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// アップロードを止めておけるフェイク(送っている途中の書き換えを試す)。
class _PausedUploadPlugin extends FakeSnsPlugin {
  _PausedUploadPlugin({required super.posts});

  /// これが終わるまで uploadMedia は返らない。
  final gate = Completer<void>();
  int uploads = 0;

  @override
  SnsSession open(AccountSession session) {
    final s = _PausedUploadSession(this, session, posts(session.account));
    opened.add(s);
    return s;
  }
}

class _PausedUploadSession extends FakeSnsSession {
  _PausedUploadSession(this.plugin, super.session, super.posts);
  final _PausedUploadPlugin plugin;

  @override
  Future<MediaItem> uploadMedia(Uint8List bytes, String filename, {String? mimeType, bool sensitive = false, String? alt}) async {
    final n = ++plugin.uploads;
    await plugin.gate.future;
    return MediaItem(id: 'm$n', type: MediaType.image, url: Uri.parse('https://example.test/m$n.png'), sensitive: sensitive);
  }
}

/// 送る内容は判定の前に確定し、判定した内容をそのまま送る(セキュリティ確認 2026-10-21 の #19)。
/// 判定のあと(アップロード / 警告の確認)に入力欄・注釈・投票・公開範囲を書き換えても、プラグインが本文を書き換えても、送るのは判定したもの。
void main() {
  final me = fakeSession();
  final second = AccountSession(account: const AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'second'), pluginId: 'test.fake', token: 't2', createdAt: DateTime(2026), displayName: 'second');
  const alice = UserSummary(id: 'alice', account: AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'alice'), displayName: 'アリス');
  Post post(String id) => Post(id: id, account: me.account, author: alice, createdAt: DateTime(2026, 10, 21, 10), body: 'もとの投稿');
  // 「投稿」の強さは standard(リンクは確かめる、画像は止めない)。メディア付きの投稿は許す。
  const denyHorror = ChildSafeComposer(enabled: true, level: ChildSafeLevel.standard, topics: ChildSafeTopics(topics: ['ホラー']));
  final kid = ChildGate(
    state: ChildSafeState(managed: true, state: 'active', policy: ChildSafePolicy(composer: denyHorror, allow: const ChildSafeAllow(features: {'post.media': true}))),
    now: DateTime(2026, 10, 21, 12),
  );
  // 1x1 の透明な PNG(添付のタイルが描ける本物の画像)。
  final image = ComposerInitialFile(
      bytes: base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII='), name: 'a.png', mimeType: 'image/png');

  Future<(ProviderContainer, _PausedUploadPlugin)> pumpApp(WidgetTester tester, {List<AccountSession>? sessions, Map<String, String> storage = const {}}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final plugin = _PausedUploadPlugin(posts: (v) => [post('p1')]);
    final registry = PluginRegistry()..register(plugin);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(MemorySessionStorage({
          SessionsNotifier.storageKey: jsonEncode({'sessions': [for (final s in sessions ?? [me]) s.toJson()], 'current': me.account.key}),
          ...storage,
        })),
        pluginRegistryProvider.overrideWithValue(registry),
        childGateProvider.overrideWithValue(kid),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    return (ProviderScope.containerOf(tester.element(find.byType(RasqApp))), plugin);
  }

  FakeSnsSession sessionOf(_PausedUploadPlugin plugin, AccountSession s) => plugin.opened.lastWhere((e) => e.account == s.account);
  TextEditingController input(WidgetTester tester) => tester.widget<TextField>(find.byKey(const ValueKey('composer.input'))).controller!;

  /// 送るを押して、アップロードで止まるところまで進める(待ちのあいだは進み続けるので pumpAndSettle は使わない)。
  Future<void> sendUntilUpload(WidgetTester tester, _PausedUploadPlugin plugin) async {
    await tester.tap(find.byKey(const ValueKey('composer.send')));
    for (var i = 0; i < 20 && plugin.uploads == 0; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(plugin.uploads, 1, reason: 'アップロードの途中で止まっている');
  }

  testWidgets('アップロードの途中で本文を止める話題へ書き換えても、送るのは判定した本文。注釈 / 投票 / 公開範囲の書き換えも送らない', (tester) async {
    final (c, plugin) = await pumpApp(tester);
    unawaited(showComposerWith(const ComposeNormal(), manager: c.read(overlayManagerProvider), router: c.read(routerProvider), initialFiles: [image]));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('composer.tool.cw')));
    await tester.pump();
    await tester.enterText(find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == '注釈..'), 'ちゅうい');
    await tester.tap(find.byKey(const ValueKey('composer.tool.poll')));
    await tester.pumpAndSettle();
    final pollFields = find.descendant(of: find.byType(PollEditor), matching: find.byType(TextField));
    await tester.enterText(pollFields.at(0), 'みけ');
    await tester.enterText(pollFields.at(1), 'くろ');
    // 本文は最後に(送るボタンが投票の入力を見て有効になるよう、コンポーザーを描き直す)。
    await tester.enterText(find.byKey(const ValueKey('composer.input')), 'ねこの話');
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('composer.send'))).onPressed, isNotNull);

    await sendUntilUpload(tester, plugin);
    // 送っているあいだ、入力欄は書き換えられない。
    expect(tester.widget<TextField>(find.byKey(const ValueKey('composer.input'))).readOnly, isTrue);
    // それでも(プラグインの遅れた書き換えなど)入力欄・注釈・投票・公開範囲が変わったとする。
    input(tester).text = 'ホラーの話';
    for (final f in tester.widgetList<TextField>(find.byType(TextField))) {
      if (f.controller?.text == 'ちゅうい') f.controller!.text = 'ホラー注意';
      if (f.controller?.text == 'みけ') f.controller!.text = 'ホラー';
    }
    c.read(composeOptionsProvider.notifier).setVisibility('home');
    await tester.pump();

    plugin.gate.complete();
    await tester.pumpAndSettle();
    final draft = sessionOf(plugin, me).lastDraft;
    expect(draft?.text, 'ねこの話');
    expect(draft?.contentWarning, 'ちゅうい');
    expect(draft?.poll?.choices, ['みけ', 'くろ']);
    expect(draft?.visibility, 'public');
    expect(draft?.mediaIds, ['m1']);
  });

  testWidgets('書き換えたあとの本文は、送るときに判定し直して止める', (tester) async {
    final (c, plugin) = await pumpApp(tester);
    unawaited(showComposerWith(const ComposeNormal(), manager: c.read(overlayManagerProvider), router: c.read(routerProvider), initialFiles: [image]));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('composer.input')), 'ねこの話');
    plugin.gate.complete();
    await tester.pump();
    // 送る前に書き換えた(判定より前)なら、書き換えたものを判定して止める。
    input(tester).text = 'ホラーの話';
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('composer.send')));
    await tester.pumpAndSettle();
    expect(sessionOf(plugin, me).lastDraft, isNull);
    expect(plugin.uploads, 0);
  });

  testWidgets('連動先には、連動先ごとに判定した加工のあとの本文をそのまま送る(途中の書き換えは届かない)', (tester) async {
    // second 宛てだけ「ねこ」→「ネコ」に加工する。
    final regex = builtinNodeCatalog.firstWhere((e) => e.type == 'composer.regex').instantiate('rx0', Offset.zero);
    final graph = NodeGraph(nodes: [
      regex.copyWith(inputs: [regex.inputs[0].copyWith(value: '${second.account}'), regex.inputs[1].copyWith(value: 'ねこ'), regex.inputs[2].copyWith(value: 'ネコ')]),
    ]);
    final (c, plugin) = await pumpApp(tester, sessions: [me, second], storage: {
      'nodeprog.${me.account.key}.composer.v1': jsonEncode({'graph': jsonEncode(graph.toJson())}),
    });
    unawaited(showComposerWith(const ComposeNormal(), manager: c.read(overlayManagerProvider), router: c.read(routerProvider), initialFiles: [image]));
    await tester.pumpAndSettle();
    // 主投稿先を me に固定 → 複数選択モードで second を「通常投稿」に。
    await tester.tap(find.byTooltip('投稿先を選ぶ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('${me.account}'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('投稿先を選ぶ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('複数選択モード'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('${second.account}'));
    await tester.pumpAndSettle();
    expect(find.text('通常投稿'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('composer.input')), 'ねこの話');
    await tester.pump();

    await sendUntilUpload(tester, plugin);
    input(tester).text = 'ホラーの話';
    await tester.pump();
    plugin.gate.complete();
    await tester.pumpAndSettle();
    expect(sessionOf(plugin, me).lastDraft?.text, 'ねこの話');
    expect(sessionOf(plugin, second).lastDraft?.text, 'ネコの話');
  });

  testWidgets('警告の確認のあいだに書き換えても、送るのは確認した本文', (tester) async {
    final (c, plugin) = await pumpApp(tester);
    plugin.gate.complete();
    unawaited(showComposerWith(const ComposeNormal(), manager: c.read(overlayManagerProvider), router: c.read(routerProvider)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('composer.input')), 'これみて https://example.test/a');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('composer.send')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('composer.policy.send')), findsOneWidget);
    input(tester).text = 'ホラーの話';
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('composer.policy.send')));
    await tester.pumpAndSettle();
    expect(sessionOf(plugin, me).lastDraft?.text, 'これみて https://example.test/a');
  });
}
