import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/nodeprog/node_tabs.dart';
import 'package:rasq_client/features/nodeprog/timeline_config_screen.dart' show TimelineConfigScreen;
import 'package:rasq_client/features/nodeprog/tl_components.dart';
import 'package:rasq_client/features/nodeprog/tl_sections_view.dart';
import 'package:rasq_client/features/plugins/slot_plugins.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart';
import 'package:rasq_client/features/trend/tendency_fows.dart';
import 'package:rasq_client/features/trend/tendency_profile.dart';
import 'package:rasq_client/features/trend/trend_screen.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fake_slot_runtime.dart';
import 'support/fakes.dart';

/// D-470: トレンドプラグインをタイムラインのノードに(トレンドを取得 / Today / カスタム)・トレンドの設定の 2 カラム・
/// 刺激性の既定(恐れ / 嫌悪 / 怒り 45%)。
void main() {
  const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
  Post post(String id, String body, {int minutes = 0}) =>
      Post(id: id, account: acc, author: UserSummary(id: 'u-$id', account: acc, displayName: '作者$id'), createdAt: DateTime(2026, 10, 13, 12).subtract(Duration(minutes: minutes)), body: body);
  final posts = [
    post('p1', '打ち上げの写真を撮った #打上会', minutes: 1),
    post('p2', '今日の反省会のメモ', minutes: 2),
    post('p3', '晩ごはんはカレー', minutes: 3),
  ];

  group('構成', () {
    test('トレンドプラグインのノード: 形式は JSON に残り、どの形式もブロック(本体のグラフに入れない)', () {
      const n = TlSourceComponent(tl: '${trendPluginKindPrefix}sample.trend', form: TrendNodeForm.today, limit: 3);
      final back = TlSourceComponent.fromJson(jsonDecode(jsonEncode(n.toJson())) as Map<String, Object?>);
      expect((back.isTrendPlugin, back.trendPluginId, back.form, back.limit, back.isBlock), (true, 'sample.trend', TrendNodeForm.today, 3, true));
      expect(const TlSourceComponent(tl: 'home').toJson().containsKey('form'), isFalse, reason: 'ほかのノードには書かない');
      expect(TlSourceComponent.fromJson(const {'tl': trendPluginKindPrefix}).form, TrendNodeForm.tiles, reason: '形式の無いものはトレンドを取得');
      final g = compileTlConfig(const TlConfig(sources: [n, TlSourceComponent(tl: 'home')]), scope: 'tl.home');
      expect([for (final x in g.nodes) if (x.type == 'tl.source') x.inputs.first.value], ['home']);
      expect(tlPageLayout(const TlConfig(sources: [n, TlSourceComponent(tl: 'home')])).before.single.tl, n.tl);
    });

    test('トレンドページ: 既定の末尾は「検索の候補」。版 3 の保存には足し、版 4 / 既にあるものはそのまま', () {
      final def = defaultTlConfig(trendTilesScope);
      expect(def.sources.last.tl, trendPluginKindPrefix);
      expect(def.sources.last.form, TrendNodeForm.chips);
      expect(trendPageConfig(null).sources.last.form, TrendNodeForm.chips);
      // D-443 の版(3)で保存したトレンドページ: 前は固定で出ていた候補のチップをノードで足す。
      final v3 = TlConfig.fromJson({
        'sources': [
          {'tl': sectionKind, 'label': 'トレンド', 'children': [{'tl': trendTagsKind, 'limit': 10}]},
        ],
        'algorithms': const [],
        'clock': '',
        'layout': 3,
      });
      final migrated = trendPageConfig(v3);
      expect(migrated.sources.map((s) => s.tl), [sectionKind, trendPluginKindPrefix]);
      expect(migrated.sources.last.form, TrendNodeForm.chips);
      // 版 4 で保存(候補を外した)ならそのまま。版 3 でも既にノードがあれば足さない。
      final v4 = TlConfig.fromJson({...v3.toJson(), 'layout': 4});
      expect(trendPageConfig(v4).sources.length, 1);
      final has = TlConfig.fromJson({
        ...v3.toJson(),
        'sources': [
          {'tl': '${trendPluginKindPrefix}x', 'form': 'tiles'},
        ],
        'layout': 3,
      });
      expect(trendPageConfig(has).sources.single.form, TrendNodeForm.tiles);
      // 保存し直すと版 4。
      expect(migrated.copyWith().layout, TlConfig.trendPluginLayout);
    });
  });

  group('刺激性の既定 (D-470)', () {
    test('新しいプロファイルは 恐れ / 嫌悪 / 怒り 45%、ほかは制限なし', () {
      const p = TendencyProfile();
      expect({for (final e in TendencyProfile.emotions) e: p.stimulusCap(e)}, {
        'joy': 1.0, 'trust': 1.0, 'fear': 0.45, 'surprise': 1.0, 'sadness': 1.0, 'disgust': 0.45, 'anger': 0.45, 'anticipation': 1.0,
      });
      expect(p.active, isTrue);
      // 往復しても同じ。
      expect(TendencyProfile.fromJson(p.toJson()).stimulusCap('anger'), 0.45);
    });

    test('保存した値は書き換えない(触っていない軸 = 制限なしも)。刺激性の欄が無い保存は既定', () {
      expect(TendencyProfile.fromJson(const {'stimulus': {}}).stimulusCap('anger'), 1.0);
      final saved = TendencyProfile.fromJson(const {'stimulus': {'anger': 0.8}});
      expect((saved.stimulusCap('anger'), saved.stimulusCap('fear'), saved.stimulusCap('disgust')), (0.8, 1.0, 1.0));
      expect(TendencyProfile.fromJson(const {'enabled': true}).stimulusCap('fear'), 0.45);
    });

    test('強い怒りの投稿は既定で後ろへ / 落ちる', () {
      final calm = post('c', '今日はいい天気');
      final angry = post('a', 'ふざけるな、許せない、むかつく 😡 🤬 気持ち悪い 最悪 キモ');
      expect(tendencyScorer.apply([angry, calm], const TendencyProfile()).map((p) => p.id), ['c']);
      expect(tendencyScorer.apply([angry, calm], const TendencyProfile(stimulus: {})).map((p) => p.id), ['a', 'c'], reason: '制限なしの保存は素通し');
    });
  });

  late Map<String, FakeSlotRuntime Function()> fakes;
  setUp(() => fakes = {
        'trend': () => FakeSlotRuntime(
              manifest: {'id': 'sample.trend', 'name': 'トレンドサジェスト', 'version': '0.1.0', 'kind': 'trend', 'slots': ['trend.suggest'], 'permissions': <String>[]},
              handler: (_, fn, args) => fn == 'trend.suggest'
                  ? {
                      'suggestions': [
                        {'text': '写真', 'reason': '「打上会」と一緒によく使われます'},
                        {'text': '反省会', 'reason': '「打上会」と一緒によく使われます'},
                        {'text': '雑談', 'reason': '定番のタグ'},
                      ],
                    }
                  : null,
            ),
      });

  Future<ProviderContainer> pump(WidgetTester tester, {Size size = const Size(1080, 2340), bool plugin = true, TlConfig? social}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final key = fakeSession().account.key;
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': key}),
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: (_) => posts))),
        slotRuntimeLoaderProvider.overrideWithValue(fakeSlotLoader(fakes)),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    if (plugin) {
      await c.read(slotPluginsProvider.notifier).register('store:sample.trend', bytes: Uint8List.fromList('trend'.codeUnits));
    }
    if (social != null) {
      // 開いたときに見えるタブ(テストの SNS はソーシャル)。
      await c.read(settingsAreaProvider(nodeprogAreaFor(key, 'tl.social')).notifier).set('tlcfg', jsonEncode(social.toJson()));
    }
    await tester.pumpAndSettle();
    return c;
  }

  group('トレンドプラグインのノード', () {
    testWidgets('TL に置く: トレンドを取得 = タイル(タップでトレンド TL)、Today = 上位の語の投稿、カスタム = チップ(セクションの中でも)', (tester) async {
      await pump(tester, social: const TlConfig(sources: [
        TlSourceComponent(tl: '${trendPluginKindPrefix}sample.trend', form: TrendNodeForm.tiles, limit: 2),
        TlSourceComponent(tl: '${trendPluginKindPrefix}sample.trend', form: TrendNodeForm.today, limit: 5),
        TlSourceComponent(tl: sectionKind, label: 'プラグイン', children: [TlSourceComponent(tl: trendPluginKindPrefix, form: TrendNodeForm.chips, limit: 10)]),
        TlSourceComponent(tl: 'social'),
      ]));
      // 見出し: 形式 + プラグインの名前。
      expect(find.text('トレンド(トレンドサジェスト)'), findsOneWidget);
      expect(find.text('Today(トレンドサジェスト)'), findsOneWidget);
      // トレンドを取得: 件数(2)まで、理由つき。
      final tiles = find.byKey(const ValueKey('trend.plugin.tiles.sample.trend'));
      expect(find.descendant(of: tiles, matching: find.byKey(const ValueKey('trend.plugin.tile.写真'))), findsOneWidget);
      expect(find.descendant(of: tiles, matching: find.byKey(const ValueKey('trend.plugin.tile.反省会'))), findsOneWidget);
      expect(find.descendant(of: tiles, matching: find.byKey(const ValueKey('trend.plugin.tile.雑談'))), findsNothing);
      expect(find.descendant(of: tiles, matching: find.text('「打上会」と一緒によく使われます')), findsNWidgets(2));
      // Today: 上位 3 語(写真 / 反省会 / 雑談)の検索結果を合流(カレーは入らない)。
      final today = find.byKey(const ValueKey('trend.plugin.today.sample.trend'));
      expect(find.descendant(of: today, matching: find.text('「写真」「反省会」「雑談」の投稿')), findsOneWidget);
      expect(find.descendant(of: today, matching: find.textContaining('打ち上げの写真')), findsOneWidget);
      expect(find.descendant(of: today, matching: find.textContaining('反省会のメモ')), findsOneWidget);
      expect(find.descendant(of: today, matching: find.textContaining('カレー')), findsNothing);
      // カスタム(候補のチップ): セクションの中。
      await tester.scrollUntilVisible(find.byKey(const ValueKey('trend.plugin.chips.all')), 300, scrollable: find.byType(Scrollable).first);
      expect(find.descendant(of: find.byKey(const ValueKey('trend.plugin.chips.all')), matching: find.text('#雑談')), findsOneWidget);
      // タイルを押すと、そのワードのトレンド TL。
      await tester.scrollUntilVisible(find.byKey(const ValueKey('trend.plugin.tile.写真')), -300, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.byKey(const ValueKey('trend.plugin.tile.写真')));
      await tester.pumpAndSettle();
      expect(find.byWidgetPredicate((w) => w is TrendScreen && w.tag == '写真'), findsOneWidget);
    });

    testWidgets('トレンドプラグインが無ければ、ノードは見出しごと出さない', (tester) async {
      await pump(tester, plugin: false, social: const TlConfig(sources: [
        TlSourceComponent(tl: trendPluginKindPrefix, form: TrendNodeForm.tiles),
        TlSourceComponent(tl: 'social'),
      ]));
      expect(find.textContaining('トレンドプラグイン'), findsNothing);
      expect(find.textContaining('打ち上げの写真'), findsWidgets, reason: '本体の TL はそのまま');
    });

    testWidgets('検索ホーム: 前の固定の「検索の候補」はトレンドページの末尾のノード(候補のチップ)', (tester) async {
      await pump(tester);
      await tester.tap(find.byTooltip('検索'));
      await tester.pumpAndSettle();
      expect(find.text('検索の候補(トレンドサジェスト)'), findsOneWidget);
      expect(find.byKey(const ValueKey('trend.plugin.chips.all')), findsOneWidget);
      expect(find.text('#写真'), findsOneWidget);
    });

    testWidgets('カスタマイズ: パレットにプラグインごとの 3 つの形式。足して … で形式を切り替える', (tester) async {
      final c = await pump(tester);
      await c.read(settingsAreaProvider(nodeprogAreaFor(fakeSession().account.key, 'tl.home')).notifier).set('tlcfg', jsonEncode(defaultTlConfig('tl.home').toJson()));
      c.read(routerProvider).push(Routes.tlConfig('tl.home'));
      await tester.pumpAndSettle();
      final list = find.descendant(of: find.byType(TimelineConfigScreen), matching: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down)).first;
      await tester.scrollUntilVisible(find.text('タイムラインを追加'), 200, scrollable: list);
      await tester.tap(find.text('タイムラインを追加'));
      await tester.pumpAndSettle();
      final palette = find.byType(Scrollable).last;
      for (final t in ['トレンドを取得: トレンドサジェスト', 'Today: トレンドサジェスト', 'カスタム(候補のチップ): トレンドサジェスト']) {
        await tester.scrollUntilVisible(find.text(t), 200, scrollable: palette);
        expect(find.text(t), findsOneWidget);
      }
      await tester.ensureVisible(find.text('Today: トレンドサジェスト'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Today: トレンドサジェスト'));
      await tester.pumpAndSettle();
      Future<TlConfig> saved() async {
        final area = await c.read(settingsAreaProvider(nodeprogAreaFor(fakeSession().account.key, 'tl.home')).future);
        return TlConfig.fromJson((jsonDecode(area['tlcfg']! as String) as Map).cast<String, Object?>());
      }

      var cfg = await saved();
      final i = cfg.sources.indexWhere((s) => s.isTrendPlugin);
      expect((cfg.sources[i].trendPluginId, cfg.sources[i].form), ('sample.trend', TrendNodeForm.today));
      // … → 形式: Today → トレンドを取得。
      final more = find.byKey(ValueKey('tlconfig.source.$i.more'));
      await tester.scrollUntilVisible(more, 200, scrollable: list);
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(find.text('表示モード: 通常 TL'), findsOneWidget, reason: 'Today の形式は投稿を出すので表示モードも');
      await tester.tap(find.text('形式: Today'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('トレンドを取得').last);
      await tester.pumpAndSettle();
      cfg = await saved();
      expect(cfg.sources[i].form, TrendNodeForm.tiles);
      expect(cfg.layout, TlConfig.currentLayout);
    });
  });

  group('トレンドの指向性/刺激性 (D-470)', () {
    Future<ProviderContainer> openFow(WidgetTester tester, {Size size = const Size(1080, 2340)}) async {
      final c = await pump(tester, size: size, plugin: false);
      await tester.tap(find.byTooltip('検索'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('トレンド設定'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('トレンドの指向性/刺激性'));
      await tester.pumpAndSettle();
      return c;
    }

    testWidgets('スマホ (D-518): 幅が狭いので指向性の下に刺激性を積む(ユーザーページの「ノートの表示」と同じ部品)', (tester) async {
      await openFow(tester);
      expect(find.byType(TendencyControls), findsOneWidget);
      expect(find.byKey(const Key('trend.tendency.stacked')), findsOneWidget);
      expect(find.byKey(const Key('trend.tendency.columns')), findsNothing);
      final dir = tester.getRect(find.byKey(const Key('trend.tendency.directivity')));
      final stim = tester.getRect(find.byKey(const Key('trend.tendency.stimulus')));
      expect(stim.top, greaterThanOrEqualTo(dir.bottom - 1), reason: 'レーダーは下');
      expect(stim.width, closeTo(dir.width, 1));
      final radar = find.byKey(const Key('trend.stimulus.radar'));
      expect(find.descendant(of: find.byKey(const Key('trend.tendency.stimulus')), matching: radar), findsOneWidget);
      expect(find.text('怒り 45%'), findsOneWidget);
    });

    for (final (name, size, split) in [('広い画面(狭いほうの比)', const Size(1600, 1600), tendencyNarrowSplit), ('広い画面', const Size(2400, 1600), tendencyWideSplit)]) {
      testWidgets('$name: 指向性と刺激性を横に並べ(刺激性が細い)、左右のスワイプは無い', (tester) async {
        await openFow(tester, size: size);
        final dir = find.byKey(const Key('trend.tendency.directivity'));
        final stim = find.byKey(const Key('trend.tendency.stimulus'));
        expect(dir, findsOneWidget);
        expect(stim, findsOneWidget);
        // 同じ高さから始まる 2 カラム(横並び)。
        expect(tester.getTopLeft(dir).dy, tester.getTopLeft(stim).dy);
        expect(tester.getTopLeft(stim).dx, greaterThan(tester.getTopRight(dir).dx - 1));
        final ratio = tester.getSize(stim).width / (tester.getSize(dir).width + tester.getSize(stim).width);
        expect(ratio, closeTo(split.$2 / (split.$1 + split.$2), 0.02));
        // 横にページを送る部品は無い。
        final sheet = find.ancestor(of: dir, matching: find.byType(ListView)).first;
        expect(find.descendant(of: sheet, matching: find.byType(PageView)), findsNothing);
        expect(find.descendant(of: sheet, matching: find.byType(TabBarView)), findsNothing);
        expect(find.descendant(of: sheet, matching: find.byWidgetPredicate((w) => w is Scrollable && (w.axisDirection == AxisDirection.left || w.axisDirection == AxisDirection.right))), findsNothing);
        // 左へスワイプしても刺激性は同じ場所(ページが替わらない)。
        final before = tester.getTopLeft(stim);
        await tester.dragFrom(tester.getTopLeft(dir) + const Offset(20, 6), const Offset(-300, 0));
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(stim), before);
        // レーダーは刺激性のカラムに入る。
        final radar = find.byKey(const Key('trend.stimulus.radar'));
        expect(find.descendant(of: stim, matching: radar), findsOneWidget);
        expect(tester.getSize(radar).width, lessThanOrEqualTo(tester.getSize(stim).width));
        // 既定: 恐れ / 嫌悪 / 怒りは 45%。
        expect(find.text('怒り 45%'), findsOneWidget);
        expect(find.text('喜び 100%'), findsOneWidget);
      });
    }

    testWidgets('「端末側で適用する」→「設定を共有」、指向性のカラムに。オフで保存すると TL の既定適用を止める', (tester) async {
      final c = await openFow(tester);
      expect(find.text('端末側で適用する'), findsNothing);
      final dir = find.byKey(const Key('trend.tendency.directivity'));
      final share = find.byKey(const Key('trend.tendency.share'));
      expect(find.descendant(of: dir, matching: share), findsOneWidget);
      expect(find.descendant(of: share, matching: find.text('設定を共有')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('trend.tendency.stimulus')), matching: find.text('設定を共有')), findsNothing);
      await tester.tap(find.descendant(of: share, matching: find.byType(Switch)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('決定'));
      await tester.pumpAndSettle();
      final profile = await c.read(tendencyProfileProvider.future);
      expect(profile.enabled, isFalse);
      expect(profile.active, isFalse);
      expect(profile.stimulusCap('anger'), 0.45, reason: '既定の上限は保存される');
    });

    testWidgets('刺激性をリセットは既定(45%)に戻す', (tester) async {
      await openFow(tester);
      final radar = find.byKey(const Key('trend.stimulus.radar'));
      await tester.tapAt(tester.getCenter(radar) + const Offset(0, -10)); // 真上の軸(喜び)を中心寄りに
      await tester.pumpAndSettle();
      expect(find.text('喜び 100%'), findsNothing);
      await tester.ensureVisible(find.text('刺激性をリセット'));
      await tester.tap(find.text('刺激性をリセット'));
      await tester.pumpAndSettle();
      expect(find.text('喜び 100%'), findsOneWidget);
      expect(find.text('恐れ 45%'), findsOneWidget);
    });
  });
}
