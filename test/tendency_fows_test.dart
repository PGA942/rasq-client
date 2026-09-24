import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/trend/example_match.dart';
import 'package:rasq_client/features/trend/genre_topics.dart';
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

  test('話題のまとめ (D-157): 類似した投稿が 1 つの話題になり、話題性の順で上位だけ', () {
    final many = [
      post('a1', 'ロケット発射おめでとう #打上会', ),
      post('a2', 'ロケット発射の中継見た #打上会'),
      post('a3', '打上会のロケット発射、最高だった'),
      post('b1', '今日の晩ごはんはカレー #料理'),
      post('b2', 'カレーのスパイス配合メモ #料理'),
      post('c1', '確定申告の締切いつだっけ'),
    ];
    final topics = topicsOf(many, top: 2);
    expect(topics.length, 2);
    expect(topics.first.posts.length, 3); // ロケット/打上会の話題が最も強い
    expect(topics.first.genres, contains('打上会'));
    expect(topics[1].posts.length, 2);
    expect(topics[1].genres, contains('料理'));
    expect(topicsOf(const [], top: 3), isEmpty);
    // 1 件だけなら 1 話題。
    expect(topicsOf([many.last], top: 3).single.posts.single.id, 'c1');
  });

  testWidgets('簡略カスタマイズ UI (D-157): 「アクションからジャンルを選択」の部品オプションと、指向性/刺激性の部品のオプション', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('検索'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('トレンド設定'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('アルゴリズム(ノード)を編集'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('アルゴリズムを追加'));
    await tester.pumpAndSettle();
    expect(find.text('指向性/刺激性'), findsOneWidget);
    await tester.tap(find.text('アクションからジャンルを選択'));
    await tester.pumpAndSettle();
    // 部品が足され、選択シートが開く。
    expect(find.text('アクションからジャンルを選択'), findsWidgets);
    expect(find.widgetWithText(FilledButton, '好き'), findsWidgets);
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(find.text('指向性/刺激性(プロファイル)'), findsOneWidget); // 追加された部品
    // 部品のタイルを開く → オプション: 指向性/刺激性 / 好きなジャンル / アクションから選択。
    await tester.tap(find.text('指向性/刺激性(プロファイル)'));
    await tester.pumpAndSettle();
    expect(find.text('ノードを設定'), findsOneWidget);
    expect(find.text('トレンドの指向性/刺激性'), findsOneWidget);
    expect(find.text('好きなジャンル/方向性'), findsOneWidget);
    await tester.tap(find.text('トレンドの指向性/刺激性'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('trend.stimulus.radar')), findsOneWidget);
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
    // アクションから選択 (D-157): 類似話題でまとめて同時に出す — 打上会の 2 件が 1 つの話題、カレーが別の話題。
    await tester.tap(find.text('最近のアクションから好きなものを選択'));
    await tester.pumpAndSettle();
    expect(find.text('アクションからジャンルを選択'), findsOneWidget);
    // 縦に並べて好き/好きではないは下に 1 組 (D-158)。話題は 2 つ、既定の対象は先頭(D-314: 共通の「例から選ぶ」FOW のカード)。
    expect(find.widgetWithText(FilledButton, '好き'), findsOneWidget);
    expect(find.byKey(const ValueKey('example.allow')), findsOneWidget);
    expect(find.byKey(const ValueKey('example.deny')), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w.key is ValueKey && (w.key as ValueKey).value.toString().startsWith('example.card.')), findsNWidgets(2));
    expect(find.text('+1 件'), findsOneWidget); // 打上会の話題は代表 + 1 件
    // 打上会の話題(先頭 = 話題性が高い)を好き。
    await tester.tap(find.byKey(const ValueKey('example.allow')));
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((w) => w.key is ValueKey && (w.key as ValueKey).value.toString().startsWith('example.card.')), findsOneWidget);
    // カレーの話題: 「料理」を外して「好きではない」。
    await tester.tap(find.text('#料理'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('example.deny')));
    await tester.pumpAndSettle();
    expect(find.text('全部見ました'), findsOneWidget);
    await tester.tap(find.text('決定').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('#打上会'), findsWidgets); // 好きに入った
    expect(find.textContaining('カレー'), findsWidgets); // 好きではない
    await tester.tap(find.text('決定'));
    await tester.pumpAndSettle();
    profile = await container.read(tendencyProfileProvider.future);
    expect(profile.genres, containsAll(['宇宙', '打上会']));
    expect(profile.disliked, contains('カレー'));
    expect(profile.disliked, isNot(contains('料理')));
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

  testWidgets('例から選ぶ (D-314): 最近のアクションのほか、クリップ / リストの中身も例にでき、TL の採点に効く', (tester) async {
    final container = await pump(tester);
    await tester.tap(find.byTooltip('検索'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('トレンド設定'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ ジャンルを追加'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('最近のアクションから好きなものを選択'));
    await tester.pumpAndSettle();
    // 出どころのチップ: 最近のアクション / プラグイン / クリップ / リスト(ストアは保護者の設定だけ)。
    for (final id in ['actions', 'plugins', 'clips', 'lists']) {
      expect(find.byKey(ValueKey('example.source.$id')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('example.source.store')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('example.source.plugins')));
    await tester.pumpAndSettle();
    expect(find.text('入れているプラグインはありません'), findsOneWidget);

    // クリップ: 名前と、含まれる投稿の先頭がカードに出る。先頭(公開クリップ)を「好きではない」、次は「とばす」。
    await tester.tap(find.byKey(const ValueKey('example.source.clips')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('example.card.clip:c-pub')), findsOneWidget);
    expect(find.text('公開クリップ'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('example.card.clip:c-pub')), matching: find.textContaining('ロケット発射', findRichText: true)), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('example.deny')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('example.skip')));
    await tester.pumpAndSettle();
    expect(find.text('全部見ました'), findsOneWidget);

    // リスト: リストのタイムラインの先頭つき。カードをタップして選び、右スワイプで「好き」。
    await tester.tap(find.byKey(const ValueKey('example.source.lists')));
    await tester.pumpAndSettle();
    expect(find.text('Fediverse Banner'), findsOneWidget);
    await tester.drag(find.byKey(const ValueKey('example.card.list:l1')), const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(find.textContaining('好き 1 / 好きではない 1'), findsWidgets);
    await tester.tap(find.text('決定').last);
    await tester.pumpAndSettle();
    // 好きなジャンルの FOW に例のチップ(タップで外せる)。
    expect(find.byKey(const ValueKey('trend.example.deny.clip:c-pub')), findsOneWidget);
    expect(find.byKey(const ValueKey('trend.example.allow.list:l1')), findsOneWidget);
    await tester.tap(find.text('決定'));
    await tester.pumpAndSettle();
    final profile = await container.read(tendencyProfileProvider.future);
    expect(profile.examples.deny.single.kind, ExampleKind.clip);
    expect(profile.examples.deny.single.text, contains('公開クリップ'));
    expect(profile.examples.allow.single.ref, 'l1');
    expect(profile.genres, isEmpty); // クリップ / リストのカードにはジャンルの候補が無い(例だけが入る)
    expect(profile.active, isTrue);
  });
}
