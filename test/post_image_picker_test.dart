import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/compose/post_image_picker_fow.dart';
import 'package:rasq_client/features/media/viewer_plugin_overlay.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// 投稿から画像を探す FOW (D-258): 検索欄 / 探す場所(ドロップダウン)/ 投稿の一覧。公開範囲が限定の投稿は出さない。
void main() {
  const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
  const author = UserSummary(id: 'u1', account: acc, displayName: 'テスター');
  MediaItem img(String id, {bool sensitive = false}) => MediaItem(id: id, type: MediaType.image, url: Uri.parse('https://files.example.test/$id.png'), sensitive: sensitive);
  Post post(String id, String body, {String? visibility, List<MediaItem> media = const []}) => Post(id: id, account: acc, author: author, createdAt: DateTime(2026, 9, 19), body: body, visibility: visibility, media: media);

  final Uint8List tinyPng = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

  test('公開範囲: フォロワーのみ / 指名 / ダイレクトは選べない。公開 / ホーム / 範囲を持たない SNS は選べる', () {
    for (final v in ['followers', 'specified', 'direct', 'private', 'limited']) {
      expect(isPickablePost(post('x', 'b', visibility: v)), isFalse, reason: v);
    }
    for (final v in <String?>['public', 'home', 'unlisted', null]) {
      expect(isPickablePost(post('x', 'b', visibility: v)), isTrue, reason: '$v');
    }
    // 動画 / ファイルは対象外。
    final mixed = post('m', 'b', media: [img('a'), MediaItem(id: 'v', type: MediaType.video, url: Uri.parse('https://files.example.test/v.mp4'))]);
    expect(pickableImagesOf(mixed).map((m) => m.id), ['a']);
  });

  testWidgets('コンポーザー → 探す FOW: 画像のある公開の投稿だけ、場所の切り替え、検索、選ぶと添付になり履歴に残る', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final posts = [
      post('p1', 'ねこの写真', visibility: 'public', media: [img('cat1'), img('cat2', sensitive: true)]),
      post('p2', 'フォロワー限定のねこ', visibility: 'followers', media: [img('secret')]),
      post('p3', '画像なしの投稿', visibility: 'public'),
      post('p4', 'いぬの写真', visibility: 'home', media: [img('dog')]),
    ];
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    final fetched = <Uri>[];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: (_) => posts))),
        viewerImageFetcherProvider.overrideWithValue((url) async {
          fetched.add(url);
          return tinyPng; // 添付のタイルが本当に復号するので、本物の PNG
        }),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    await tester.tap(find.byTooltip('投稿'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('画像'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('投稿から探す'));
    await tester.pumpAndSettle();

    // 既定の場所 = その SNS の最初のタイムライン。画像のある公開の投稿だけ(限定は除いて、件数を出す)。
    expect(find.text('フォロー中'), findsWidgets);
    expect(find.byKey(const ValueKey('postPicker.image.p1.cat1')), findsOneWidget);
    expect(find.byKey(const ValueKey('postPicker.image.p1.cat2')), findsOneWidget);
    expect(find.byKey(const ValueKey('postPicker.image.p4.dog')), findsOneWidget);
    expect(find.byKey(const ValueKey('postPicker.image.p2.secret')), findsNothing);
    expect(find.text('画像なしの投稿'), findsOneWidget); // 後ろのタイムラインの 1 つだけ(FOW の一覧には出ない)
    expect(find.byKey(const ValueKey('postPicker.excluded')), findsOneWidget);
    expect(find.textContaining('1 件は出していません'), findsOneWidget);

    // 検索: 決定で投稿検索の結果に(偽 SNS は本文の部分一致)。
    await tester.enterText(find.byKey(postImagePickerSearchKey), 'いぬ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('検索結果: 「いぬ」'), findsOneWidget);
    expect(find.byKey(const ValueKey('postPicker.image.p4.dog')), findsOneWidget);
    expect(find.byKey(const ValueKey('postPicker.image.p1.cat1')), findsNothing);

    // 探す場所(ドロップダウン)→ 選ぶと検索はやめる。
    await tester.tap(find.byKey(postImagePickerSourceKey));
    await tester.pumpAndSettle();
    for (final label in ['フォロー中', '自分の投稿', 'リアクションした投稿', 'ブックマーク', '最近選んだ画像']) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    await tester.tap(find.text('自分の投稿').last);
    await tester.pumpAndSettle();
    expect(find.text('画像のある投稿はありません'), findsOneWidget); // 偽 SNS の自分の投稿は空
    expect(find.text('検索結果: 「いぬ」'), findsNothing);
    await tester.tap(find.byKey(postImagePickerSourceKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('リアクションした投稿').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('postPicker.image.p1.cat2')), findsOneWidget);

    // 選ぶ(センシティブな 1 枚)→ 取ってきて添付に。センシティブは引き継ぐ。履歴に残る。
    await tester.tap(find.byKey(const ValueKey('postPicker.image.p1.cat2')));
    await tester.pumpAndSettle();
    expect(find.byKey(postImagePickerSearchKey), findsNothing);
    expect(fetched, [Uri.parse('https://files.example.test/cat2.png')]);
    expect(find.byTooltip('センシティブ解除'), findsOneWidget);
    expect(c.read(postPickerRecentProvider).single.item.id, 'cat2');
    expect(jsonDecode((await storage.read(PostPickerRecent.storageKey))!), hasLength(1));

    // 開き直して「最近選んだ画像」→ さっきの 1 枚。
    await tester.tap(find.byTooltip('画像'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('投稿から探す'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(postImagePickerSourceKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('最近選んだ画像').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('postPicker.image.p1.cat2')), findsOneWidget);
    expect(find.byKey(const ValueKey('postPicker.image.p4.dog')), findsNothing);
  });

  test('履歴: 同じ画像は 1 つ(選び直すと先頭へ)、再起動後も読める', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final storage = MemorySessionStorage({});
    ProviderContainer make() {
      final c = ProviderContainer(overrides: [sessionStorageProvider.overrideWithValue(storage)]);
      addTearDown(c.dispose);
      return c;
    }

    final c = make();
    final a = (item: img('a'), post: post('p1', 'A', visibility: 'public', media: [img('a')]));
    final b = (item: img('b'), post: post('p2', 'B', media: [img('b')]));
    await c.read(postPickerRecentProvider.notifier).add(a);
    await c.read(postPickerRecentProvider.notifier).add(b);
    await c.read(postPickerRecentProvider.notifier).add(a);
    expect(c.read(postPickerRecentProvider).map((p) => p.item.id), ['a', 'b']);
    final c2 = make();
    c2.read(postPickerRecentProvider);
    await c2.read(postPickerRecentProvider.notifier).ready;
    final back = c2.read(postPickerRecentProvider);
    expect(back.map((p) => (p.item.id, p.post.id, p.post.author.displayName, p.post.account.key)), [('a', 'p1', 'テスター', acc.key), ('b', 'p2', 'テスター', acc.key)]);
  });
}
