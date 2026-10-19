import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/providers.dart';
import '../../l10n/l10n.dart';
import '../settings/settings_dsl.dart' show settingsAreaProvider;
import '../trend/tendency_controls.dart';
import '../trend/tendency_profile.dart';
import 'user_providers.dart';

/// ユーザーページのタブの並べ替え・絞り込み (D-514)。
///
/// 選んでいるタブをもう一度押すと、そのタブにつながったパネル([showTetheredPanel])で開く。中身は
/// - 検索: 読み込んだこの人の投稿を本文で絞る(端末の中で。SNS の口にはユーザーを指定した投稿の検索が無い)
/// - 指向性 / 刺激性: トレンドの傾向 FOW (D-153 / D-470) と同じ採点([tendencyScorer])と同じ部品([TendencyControls]、D-518)。
///   指向性は好きなジャンル / 好きな例(トレンドの設定のもの)への近さのしきい値、刺激性はレーダーの各感情の上限。隠すのは
///   TL と同じく**上限を超えたぶんの合計**が [tendencyStimulusHideAt] 以上の投稿(D-514 では 1 つでも超えたら隠していた)
/// - 表示: ピン留め / リノート / 引用ノート / ダイジェスト(小表示、D-156 のインラインフレーム)
/// - 並べ替え: 新しい順(SNS の並び)/ 古い順 / リアクション数(返信欄の D-070 と同じ)/ 傾向に合う順(TL の `tendency` と同じ適合度)
///
/// 保存は**タブの種類ごとに全員で共通**(KV [userPageTabsKvArea]、キーは [UserPostsFilter] の名前)。返信欄の並び順
/// (`threadReplies`)と同じく、人ごとには持たない(人ごとだと見に行った人の数だけ増え、どこで変えたか分からなくなる)。
/// 検索の語は保存しない(そのページを開いている間だけ)。
enum UserTabSort {
  newest,
  oldest,
  reactions,
  tendency;

  static UserTabSort byName(Object? name) => values.where((s) => s.name == name).firstOrNull ?? newest;

  String label(AppLocalizations l) => switch (this) {
        newest => l.userPageViewSortNewest,
        oldest => l.userPageViewSortOldest,
        reactions => l.userPageViewSortReactions,
        tendency => l.userPageViewSortTendency,
      };
}

/// 1 つのタブの表示の設定 (D-514)。既定 = 今までの表示(SNS の並び・全部出す・絞らない)。
@immutable
class UserTabView {
  const UserTabView({
    this.sort = UserTabSort.newest,
    this.pinned = true,
    this.renotes = true,
    this.quotes = true,
    this.digest = false,
    this.directionality = 1.0,
    this.stimulus = const {},
  });

  final UserTabSort sort;

  /// ピン留めを上に出す(ノートのタブだけ)。
  final bool pinned;

  /// リノート(`repostedBy` のある投稿)を出す。
  final bool renotes;

  /// 引用ノート(`quote` のある投稿)を出す。
  final bool quotes;

  /// ダイジェスト = 小表示(D-156 のインラインフレーム: 本文 3 行 + サムネイル)で並べる。
  final bool digest;

  /// 指向性 0(狭い)〜1(広い = 絞らない)。[TendencyProfile.directionality] と同じ向き。
  final double directionality;

  /// 刺激性: 感情 → 上限 0〜1(無い = 1 = 制限なし)。トレンドの既定 (D-470) とは違い、ここの既定は制限なし
  /// (人のページは自分で見に行くもの。隠す基準は TL と同じ、D-518)。
  final Map<String, double> stimulus;

  static const defaults = UserTabView();

  bool get isDefault => this == defaults;

  double stimulusCap(String emotion) => (stimulus[emotion] ?? 1.0).clamp(0.0, 1.0);

  bool get limitsStimulus => stimulus.values.any((v) => v < 1.0);
  bool get limitsDirection => directionality < 1.0;

  UserTabView copyWith({UserTabSort? sort, bool? pinned, bool? renotes, bool? quotes, bool? digest, double? directionality, Map<String, double>? stimulus}) => UserTabView(
        sort: sort ?? this.sort,
        pinned: pinned ?? this.pinned,
        renotes: renotes ?? this.renotes,
        quotes: quotes ?? this.quotes,
        digest: digest ?? this.digest,
        directionality: directionality ?? this.directionality,
        stimulus: stimulus ?? this.stimulus,
      );

  /// 採点に使うプロファイル: 好きなジャンル / 好きな例 / 好きではないもの は [base](トレンドの設定)、しきい値と上限はこのタブの値。
  TendencyProfile profileOn(TendencyProfile? base) => (base ?? const TendencyProfile()).copyWith(enabled: true, snsDefault: false, directionality: directionality, stimulus: {...stimulus});

  Map<String, Object?> toJson() => {
        if (sort != UserTabSort.newest) 'sort': sort.name,
        if (!pinned) 'pinned': false,
        if (!renotes) 'renotes': false,
        if (!quotes) 'quotes': false,
        if (digest) 'digest': true,
        if (directionality < 1.0) 'directionality': directionality,
        if (limitsStimulus) 'stimulus': {for (final e in stimulus.entries) if (e.value < 1.0) e.key: e.value},
      };

  static UserTabView fromJson(Object? raw) {
    if (raw is! Map) return defaults;
    final st = raw['stimulus'];
    return UserTabView(
      sort: UserTabSort.byName(raw['sort']),
      pinned: raw['pinned'] != false,
      renotes: raw['renotes'] != false,
      quotes: raw['quotes'] != false,
      digest: raw['digest'] == true,
      directionality: ((raw['directionality'] as num?) ?? 1.0).toDouble().clamp(0.0, 1.0),
      stimulus: st is Map ? {for (final e in st.entries) if (e.value is num) '${e.key}': (e.value as num).toDouble().clamp(0.0, 1.0)} : const {},
    );
  }

  @override
  bool operator ==(Object other) =>
      other is UserTabView &&
      other.sort == sort &&
      other.pinned == pinned &&
      other.renotes == renotes &&
      other.quotes == quotes &&
      other.digest == digest &&
      other.directionality == directionality &&
      mapEquals({for (final e in stimulus.entries) if (e.value < 1.0) e.key: e.value}, {for (final e in other.stimulus.entries) if (e.value < 1.0) e.key: e.value});

  @override
  int get hashCode => Object.hash(sort, pinned, renotes, quotes, digest, directionality, Object.hashAllUnordered([for (final e in stimulus.entries) if (e.value < 1.0) '${e.key}=${e.value}']));
}

/// 検索の語に合うか(空白で区切った語を全部含む。本文 / CW / 引用の本文 / 添付の説明)。大文字小文字は見ない。
bool userPostMatches(Post p, String query) {
  final terms = query.toLowerCase().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  if (terms.isEmpty) return true;
  final text = [p.body, p.contentWarning ?? '', p.quote?.body ?? '', for (final m in p.media) m.alt ?? ''].join('\n').toLowerCase();
  return terms.every(text.contains);
}

/// 投稿の並びに設定を掛ける(純関数、D-514)。[base] = トレンドの設定(指向性の好きなジャンル / 例)。
/// [sorted] = false なら絞るだけで並べ替えない(ピン留めの並び)。
List<Post> applyUserTabView(List<Post> posts, UserTabView v, {String query = '', TendencyProfile? base, bool sorted = true}) {
  final needsProfile = v.limitsStimulus || v.limitsDirection || v.sort == UserTabSort.tendency;
  final profile = needsProfile ? v.profileOn(base) : null;
  bool keep(Post p) {
    if (!v.renotes && p.repostedBy != null) return false;
    if (!v.quotes && p.quote != null) return false;
    if (!userPostMatches(p, query)) return false;
    // 刺激性: 上限を超えたぶんの合計が TL と同じ境目以上なら隠す (D-518。D-514 では 1 つでも超えたら隠していたが、トレンドの
    // 指向性 / 刺激性と同じ部品にしたので、同じレーダーの形が同じ投稿を隠すように揃えた)。
    if (v.limitsStimulus && tendencyScorer.stimulusPenaltyOf(p, profile!) >= tendencyStimulusHideAt) return false;
    // 指向性: 好きなジャンル / 例が無ければ落とさない(TL と同じ)。好きではないものも落とす。
    if (v.limitsDirection && (tendencyScorer.isDisliked(p, profile!) || (profile.hasDirection && tendencyScorer.directionOf(p, profile) < profile.directionThreshold))) return false;
    return true;
  }

  final kept = [for (final p in posts) if (keep(p)) p];
  if (!sorted) return kept;
  List<Post> byScore(double Function(Post) score) {
    final scored = [for (final (i, p) in kept.indexed) (i, p, score(p))];
    scored.sort((a, b) => b.$3 != a.$3 ? b.$3.compareTo(a.$3) : a.$1.compareTo(b.$1));
    return [for (final s in scored) s.$2];
  }

  return switch (v.sort) {
    UserTabSort.newest => kept,
    UserTabSort.oldest => kept.reversed.toList(),
    UserTabSort.reactions => byScore((p) => p.reactionTotal.toDouble()),
    UserTabSort.tendency => byScore((p) => tendencyScorer.score(p, profile!).value),
  };
}

// ── 保存 ────────────────────────────────────────────────────────────

/// 置き場(`userPageTabs.v1`。キー = [UserPostsFilter] の名前、値 = [UserTabView.toJson]。既定に戻したら消す)。
const userPageTabsKvArea = 'userPageTabs';

/// タブの設定(読み込み中 / 無ければ既定)。
UserTabView watchUserTabView(WidgetRef ref, UserPostsFilter tab) => UserTabView.fromJson(ref.watch(settingsAreaProvider(userPageTabsKvArea)).value?[tab.name]);

Future<void> saveUserTabView(WidgetRef ref, UserPostsFilter tab, UserTabView v) => ref.read(settingsAreaProvider(userPageTabsKvArea).notifier).set(tab.name, v.isDefault ? null : v.toJson());

// ── パネル ──────────────────────────────────────────────────────────

const userTabViewPanelId = 'user.tabView';

/// タブにつながった並べ替え・絞り込みのパネル (D-514)。変えたらすぐ一覧に効く(保存もすぐ)。閉じる / 外のタップ / タブ
/// (首)のタップで閉じる。[anchor] = タブの名前の矩形(グローバル座標)。[query] = このページのこのタブの検索の語。
/// [chartHeld] = 指が指向性 / 刺激性の欄に触れている間 true(ページはその間、横のスワイプと戻るジェスチャーを止める)。
///
/// 見た目 (D-517 / D-518): 「このタイムラインから探す」(タイムラインの一時変更 FOW、D-338)と同じ並び = 太字の見出し →
/// 検索欄(検索画面と同じ丸い枠)→ 太い下線の節(並べ替え / 表示 / 指向性・刺激性)。下は FOW の標準のフッター
/// ([FowFooter]: 件数 + リセット / 閉じる)。幅は広い画面なら [userTabViewPanelWidth] まで広げ、指向性 / 刺激性を横に並べる。
Future<void> showUserTabViewPanel(
  BuildContext ctx,
  WidgetRef ref, {
  required Rect anchor,
  required UserPostsFilter tab,
  required String tabLabel,
  required ValueNotifier<String> query,
  required ValueNotifier<bool> chartHeld,
  required ({String id, UserPostsFilter filter, String? account}) postsKey,
  bool hasPinned = false,
}) async {
  final manager = ref.read(overlayManagerProvider);
  if (manager.contains(userTabViewPanelId)) {
    manager.close(userTabViewPanelId);
    return;
  }
  final search = TextEditingController(text: query.value);
  void onText() => query.value = search.text;
  search.addListener(onText);
  // 首(元のタブ)の中は、ページのタブと同じ見た目(∨ + 名前)。名前が首の丸より広くても切らない。
  final scheme = Theme.of(ctx).colorScheme;
  final labelColor = TabBarTheme.of(ctx).labelColor ?? scheme.primary;
  // 首の丸はタブの名前を包む大きさ(高さはタブの高さ以上)。
  final side = anchor.width > anchor.height ? anchor.width + 8 : anchor.height;
  final neck = Rect.fromCenter(center: anchor.center, width: side, height: side);
  try {
    await manager.showTetheredPanel<void>(
      id: userTabViewPanelId,
      anchor: neck,
      width: userTabViewPanelWidth,
      iconExtent: 22,
      title: ctx.l10n.userPageViewTitle(tabLabel),
      // 見出しの字は「このタイムラインから探す」と同じ大きさ。閉じるはフッターへ (D-517)。
      titleStyle: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      cancelText: null,
      confirmText: null,
      anchorChild: OverflowBox(
        maxWidth: double.infinity,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.keyboard_arrow_down, size: 16, color: labelColor),
          Text(tabLabel, style: (Theme.of(ctx).textTheme.labelLarge ?? const TextStyle()).merge(RasqTypography.tab).copyWith(color: labelColor), maxLines: 1, softWrap: false),
        ]),
      ),
      builder: (_) => UserTabViewPanelBody(tab: tab, tabLabel: tabLabel, search: search, query: query, chartHeld: chartHeld, postsKey: postsKey, hasPinned: hasPinned),
      footer: (_, handle) => UserTabViewPanelFooter(tab: tab, search: search, query: query, postsKey: postsKey, onClose: handle.close),
    );
  } finally {
    chartHeld.value = false;
    search.removeListener(onText);
    search.dispose();
  }
}

/// パネルの幅の上限。スマホではタブのカラムの幅(-余白)まで縮み、指向性 / 刺激性は縦に積む([tendencyStackBreakpoint])。
const userTabViewPanelWidth = 560.0;

/// パネルの中身(テストとプレビューからも組める)。
class UserTabViewPanelBody extends ConsumerWidget {
  const UserTabViewPanelBody({super.key, required this.tab, required this.tabLabel, required this.search, required this.query, required this.chartHeld, required this.postsKey, this.hasPinned = false});
  final UserPostsFilter tab;
  final String tabLabel;
  final TextEditingController search;
  final ValueNotifier<String> query;
  final ValueNotifier<bool> chartHeld;
  final ({String id, UserPostsFilter filter, String? account}) postsKey;
  final bool hasPinned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final v = watchUserTabView(ref, tab);
    final base = ref.watch(tendencyProfileProvider).value;
    void set(UserTabView next) => saveUserTabView(ref, tab, next);
    Widget chip(String key, String text, bool selected, VoidCallback onTap) => RasqFilterChip(key: ValueKey('user.tabView.$key'), item: RasqFilterChipItem(label: text, selected: selected, onTap: onTap));
    Widget chips(List<Widget> children) => Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
          child: Wrap(spacing: RasqSpacing.xs, runSpacing: RasqSpacing.xs, children: children),
        );
    final noDirection = !(base?.hasDirection ?? false);
    // 検索欄: 検索画面 / 「このタイムラインから探す」と同じ丸い枠(onSurface の線)。
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(RasqSizes.searchBarHeight), borderSide: BorderSide(color: scheme.onSurface, width: 1.2));
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.sm, 0, RasqSpacing.sm, RasqSpacing.xs),
        child: SizedBox(
          height: RasqSizes.searchBarHeight,
          child: TextField(
            key: const ValueKey('user.tabView.search'),
            controller: search,
            style: Theme.of(context).textTheme.bodySmall,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              hintText: l.userPageViewSearchHint(tabLabel),
              prefixIcon: Icon(Icons.search, size: 20, color: scheme.onSurface),
              prefixIconConstraints: const BoxConstraints(minWidth: RasqSizes.minTap, minHeight: RasqSizes.searchBarHeight),
              suffixIcon: ValueListenableBuilder<String>(
                valueListenable: query,
                builder: (_, q, _) => q.isEmpty ? const SizedBox.shrink() : IconButton(key: const ValueKey('user.tabView.search.clear'), iconSize: 16, visualDensity: VisualDensity.compact, onPressed: search.clear, icon: const Icon(Icons.close)),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: border,
              enabledBorder: border,
              focusedBorder: border.copyWith(borderSide: BorderSide(color: scheme.primary, width: 1.5)),
            ),
          ),
        ),
      ),
      RasqSectionHeader(title: l.userPageViewSortLabel, topMargin: RasqSpacing.xs),
      chips([
        for (final s in UserTabSort.values) chip('sort.${s.name}', s.label(l), v.sort == s, () => set(v.copyWith(sort: s))),
      ]),
      RasqSectionHeader(title: l.userPageViewShowLabel, topMargin: RasqSpacing.sm),
      chips([
        if (hasPinned) chip('pinned', l.userPageViewShowPinned, v.pinned, () => set(v.copyWith(pinned: !v.pinned))),
        chip('renotes', l.userPageViewShowRenotes, v.renotes, () => set(v.copyWith(renotes: !v.renotes))),
        // 引用のタブは全部が引用ノートなので出さない。
        if (tab != UserPostsFilter.quotes) chip('quotes', l.userPageViewShowQuotes, v.quotes, () => set(v.copyWith(quotes: !v.quotes))),
        chip('digest', l.userPageViewShowDigest, v.digest, () => set(v.copyWith(digest: !v.digest))),
      ]),
      RasqSectionHeader(title: l.userPageViewTendencyLabel, topMargin: RasqSpacing.sm),
      // トレンドの指向性 / 刺激性と同じ部品 (D-518)。指が触れている間、ページの横のスワイプ(タブの切り替え / 戻る)を止める
      // (レーダーの軸とスライダーのつまみを横に動かせるように、D-514)。
      TendencyControls(
        key: const ValueKey('user.tabView.chart'),
        keyPrefix: 'user.tabView.tendency',
        radarKey: const ValueKey('user.tabView.radar'),
        directionality: v.directionality,
        onDirectionality: (x) => set(v.copyWith(directionality: x)),
        stimulusCap: v.stimulusCap,
        onStimulus: (axis, x) => set(v.copyWith(stimulus: {...v.stimulus, axis: x})),
        directivityTitle: l.userPageViewDirectivityTitle,
        directivitySubtitle: noDirection ? l.userPageViewDirectivityNoGenres : l.trendProfileDirectivitySubtitle,
        stimulusTitle: l.userPageViewStimulusTitle,
        // ここの既定は制限なし。
        onStimulusReset: v.limitsStimulus ? () => set(v.copyWith(stimulus: const {})) : null,
        onHold: (held) => chartHeld.value = held,
      ),
      const SizedBox(height: RasqSpacing.xs),
    ]);
  }
}

/// パネルのフッター (D-517): 件数(読み込んだうち表示している数)+ リセット / 閉じる。FOW の標準のフッター([FowFooter])。
class UserTabViewPanelFooter extends ConsumerWidget {
  const UserTabViewPanelFooter({super.key, required this.tab, required this.search, required this.query, required this.postsKey, required this.onClose});
  final UserPostsFilter tab;
  final TextEditingController search;
  final ValueNotifier<String> query;
  final ({String id, UserPostsFilter filter, String? account}) postsKey;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final v = watchUserTabView(ref, tab);
    final base = ref.watch(tendencyProfileProvider).value;
    final posts = ref.watch(userPostsProvider(postsKey)).value?.items;
    return ValueListenableBuilder<String>(
      valueListenable: query,
      builder: (_, q, _) => FowFooter(
        leading: posts == null ? null : Text(l.userPageViewCount(applyUserTabView(posts, v, query: q, base: base, sorted: false).length, posts.length), key: const ValueKey('user.tabView.count')),
        actions: [
          TextButton(
            key: const ValueKey('user.tabView.reset'),
            onPressed: v.isDefault && q.isEmpty
                ? null
                : () {
                    search.clear();
                    saveUserTabView(ref, tab, UserTabView.defaults);
                  },
            child: Text(l.userPageViewReset),
          ),
          TextButton(key: const ValueKey('user.tabView.close'), onPressed: onClose, child: Text(l.userPageViewClose, style: const TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}
