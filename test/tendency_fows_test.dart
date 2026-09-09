import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/trend/tendency_fows.dart';
import 'package:rasq_client/features/trend/tendency_profile.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// D-153/D-154: トレンドプロファイル設定 → 指向性/刺激性 FOW(スライダー + レーダー)→
/// 好きなジャンル FOW(チップ / 追加)→ アクションからジャンルを選択(カード)。
void main() {
  const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
  Post post(String id, String body, {List<MediaItem> media = const []}) => Post(id: id, account: acc, author: UserSummary(id: 'u-$id', account: acc, displayName: '作者$id'), createdAt: DateTime(2026, 9, 9), body: body, media: media);
  final posts = [
    post('p1', 'ロケット発射おめでとう！ #打上会 #宇宙'),
    post('p2', '今日の晩ごはんはカレー #料理'),
    post('p3', '打ち上げ中継 #打上会', media: [MediaItem(id: 'm1', type: MediaType.image, url: Uri.parse('https://x.invalid/1.png'), alt: 'ロケットの写真')]),
  ];

  Future<ProviderContainer> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (_) => posts));
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry)],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
  }

  test('ジャンル候補: ハッシュタグ > 特徴語 > メディアの alt、自動抽出は頻出順', () {
    expect(genreCandidatesOf(posts[0]).take(2), ['打上会', '宇宙']);
    expect(genreCandidatesOf(posts[2]), containsAll(['打上会', 'ロケット', '写真'])); // alt の特徴語も候補に
    expect(genreCandidatesOf(post('x', '')), isEmpty);
    final auto = autoGenresOf(posts);
    expect(auto.first, '打上会'); // 2 回出る
  });

  testWidgets('検索ホームの ⚙ → プロファイル設定 → 指向性/刺激性(レーダー)→ ジャンル追加 → アクションから選択 → TL に効く', (tester) async {
    final container = await pump(tester);
    await tester.tap(find.byTooltip('検索'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('トレンド設定'));
    await tester.pumpAndSettle();
    expect(find.text('トレンドプロファイル設定'), findsOneWidget);
    expect(find.text('トレンドの指向性/刺激性'), findsOneWidget);
    expect(find.text('アルゴリズム(ノード)を編集'), findsOneWidget);

    // 指向性/刺激性: 注意 → スライダー → レーダー(触る)→ 決定で保存。
    await tester.tap(find.text('トレンドの指向性/刺激性'));
    await tester.pumpAndSettle();
    expect(find.textContaining('エコーチェンバー'), findsOneWidget);
    final slider = find.byType(Slider);
    expect(slider, findsOneWidget);
    await tester.drag(slider, const Offset(-300, 0)); // 狭い側へ
    await tester.pumpAndSettle();
    final radar = find.byKey(const Key('trend.stimulus.radar'));
    expect(radar, findsOneWidget);
    await tester.tapAt(tester.getCenter(radar) + const Offset(0, -20)); // 真上の軸(joy)を中心寄りに
    await tester.pumpAndSettle();
    expect(find.textContaining('喜び'), findsWidgets);
    await tester.tap(find.text('決定'));
    await tester.pumpAndSettle();
    var profile = await container.read(tendencyProfileProvider.future);
    expect(profile.directionality, lessThan(0.5));
    expect(profile.stimulusCap('joy'), lessThan(1.0));
    expect(find.textContaining('保存しました'), findsOneWidget);

    // 好きなジャンル: 追加 → 決定。
    await tester.tap(find.text('+ ジャンルを追加'));
    await tester.pumpAndSettle();
    expect(find.text('好きなジャンル/方向性'), findsWidgets); // シートのタイトル + 下の設定シートの見出し
    await tester.enterText(find.widgetWithText(TextField, 'ジャンル/キーワードを追加'), '#宇宙');
    await tester.tap(find.byTooltip('ジャンルを追加'));
    await tester.pumpAndSettle();
    expect(find.textContaining('#宇宙'), findsWidgets); // チップは「#宇宙 ✕」
    // アクションから選択: カード → 好き → 好きではない → 決定。
    await tester.tap(find.text('最近のアクションから好きなものを選択'));
    await tester.pumpAndSettle();
    expect(find.text('アクションからジャンルを選択'), findsOneWidget);
    expect(find.textContaining('(1/3)'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '好き'));
    await tester.pumpAndSettle();
    expect(find.textContaining('(2/3)'), findsOneWidget);
    await tester.tap(find.text('#料理')); // 先頭 2 つが選択済みなので「料理」を外す(残りは「カレー」)
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '好きではない'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('決定').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('#打上会'), findsWidgets); // 好きに入った
    expect(find.textContaining('カレー'), findsWidgets); // 好きではない
    await tester.tap(find.text('決定'));
    await tester.pumpAndSettle();
    profile = await container.read(tendencyProfileProvider.future);
    expect(profile.genres, containsAll(['宇宙', '打上会']));
    expect(profile.disliked, ['カレー']);
    expect(profile.active, isTrue);

    // 設定シートに反映(チップと要約)。
    expect(find.textContaining('#宇宙'), findsWidgets);
    expect(find.textContaining('指向性 狭い'), findsOneWidget);
    await tester.tap(find.text('閉じる'));
    await tester.pumpAndSettle();

    // 適用: 狭い + 好き(宇宙/打上会)+ 嫌い(料理)→ カレーの投稿は落ちる。
    final applied = tendencyScorer.apply(posts, profile);
    expect(applied.map((p) => p.id), isNot(contains('p2')));
    expect(applied.map((p) => p.id), containsAll(['p1', 'p3']));
  });
}
