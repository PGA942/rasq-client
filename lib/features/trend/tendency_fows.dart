import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../l10n/l10n.dart';
import '../nodeprog/node_executor.dart';
import '../relational/relational_engine.dart';
import 'example_picker.dart';
import 'example_sources.dart';
import 'tendency_controls.dart';
import 'tendency_profile.dart';

export 'tendency_controls.dart' show TendencyControls, TendencyStimulusChip, tendencyStackBreakpoint, tendencyNarrowSplit, tendencyWideSplit, tendencyWideBreakpoint;

/// トレンドプロファイル設定 (D-153、ワイヤーフレーム p.2 中段下): 検索ホーム/
/// トレンド TL の ⚙ から。好きなジャンル/方向性のチップ、⚠ 指向性/刺激性、
/// トレンドプラグイン、キャッシュネットワーク、アルゴリズム(ノード)の編集。
Future<void> showTrendProfileSheet(BuildContext context, WidgetRef ref) async {
  final manager = ref.read(overlayManagerProvider);
  await manager.showBottomSheet<void>(
    id: 'trend.profile',
    title: context.l10n.trendProfileSheetTitle,
    cancelText: context.l10n.trendProfileClose,
    builder: (ctx) => Consumer(builder: (ctx, ref, _) {
      final l = ctx.l10n;
      final profile = ref.watch(tendencyProfileProvider).value ?? const TendencyProfile();
      return ListView(shrinkWrap: true, children: [
        _label(ctx, profile.snsDefault ? l.trendProfileGenresSnsDefault : profile.autoGenre ? l.trendProfileGenresAuto : l.trendProfileGenres),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
          child: Wrap(spacing: RasqSpacing.xs, runSpacing: RasqSpacing.xs, children: [
            for (final (i, g) in profile.genres.indexed) RasqTogglePillButton(label: g.startsWith('#') ? g : '#$g', activeLabel: g.startsWith('#') ? g : '#$g', active: i == 0, onPressed: () => openGenreFow(ctx, ref)),
            RasqTogglePillButton(label: profile.genres.isEmpty ? l.trendProfileAddGenrePill : l.trendProfileEdit, active: false, onPressed: () => openGenreFow(ctx, ref)),
          ]),
        ),
        const SizedBox(height: RasqSpacing.xs),
        RasqWarningListTile(title: l.trendProfileTendencyTitle, subtitle: l.trendProfileTendencySummary(_dirLabel(profile.directionality), _stimLabel(profile)), onTap: () => openTendencyFow(ctx, ref)),
        // 設定ページへ (D-238): トレンドプラグインの有効 / 無効、キャッシュネットワークの状態。
        RasqListTile(title: l.trendProfilePluginsTitle, subtitle: l.trendProfilePluginsSubtitle, detail: l.trendProfilePluginsDetail, onTap: () {
          manager.close('trend.profile');
          ref.read(routerProvider).push('/settings/dsl/plugins.trend');
        }),
        RasqListTile(title: l.trendProfileCacheNetworkTitle, subtitle: l.trendProfileComingSoon, onTap: () {
          manager.close('trend.profile');
          ref.read(routerProvider).push('/settings/dsl/trend.cdn');
        }),
        RasqListTile(
          title: l.trendProfileAlgorithmTitle,
          subtitle: l.trendProfileAlgorithmSubtitle,
          detail: l.trendProfileAlgorithmDetail,
          onTap: () {
            manager.close('trend.profile');
            context.push(Routes.tlConfig('trend'));
          },
        ),
        RasqCaption(
          l.trendProfileSharedCaption,
          detail: l.trendProfileSharedCaptionDetail,
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, RasqSpacing.page),
        ),
      ]);
    }),
  );
}

String _dirLabel(double v) => TendencyControls.directionLabel(v);
String _stimLabel(TendencyProfile p) {
  final labels = TendencyProfile.emotionLabels;
  final capped = [for (final e in TendencyProfile.emotions) if (p.stimulusCap(e) < 1.0) labels[e]!];
  return capped.isEmpty ? appL10n.trendProfileStimNone : appL10n.trendProfileStimCapped(capped.take(3).join(appL10n.trendProfileListSeparator));
}

Widget _label(BuildContext context, String text) => Padding(
      padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 2),
      child: Text(text, style: RasqTypography.caption.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );

/// トレンドの指向性/刺激性 FOW (D-153、p.2 中段上): エコーチェンバーの注意 +
/// 指向性スライダー(狭い ⇄ 広い)+ 刺激性レーダー(8 感情の上限、触って決める)。
/// 決定で保存、キャンセルで捨てる。
///
/// **2 カラム (D-470)**: 指向性と刺激性を横に並べる(左右のスワイプで行き来しない。どちらも 1 つの縦スクロールの中)。
/// 刺激性のほうを細く: [tendencyNarrowSplit](62 / 38)、幅 [tendencyWideBreakpoint] 以上は 60 / 40 でレーダーを大きく。
/// **D-518**: 欄は共通の部品 [TendencyControls](ユーザーページの「ノートの表示」と同じ)。幅が [tendencyStackBreakpoint]
/// 未満(スマホ)なら横に並べず、指向性の下に刺激性を積む。「設定を共有」(前の「端末側で適用する」= TL の既定適用の
/// オン / オフ)は指向性の欄に置く。
Future<void> openTendencyFow(BuildContext context, WidgetRef ref) async {
  final manager = ref.read(overlayManagerProvider);
  var draft = ref.read(tendencyProfileProvider).value ?? const TendencyProfile();
  final saved = await manager.showBottomSheet<bool>(
    id: 'trend.tendency',
    title: context.l10n.trendProfileTendencyTitle,
    confirmText: context.l10n.trendProfileDecide,
    onConfirm: () => saveTendencyProfileFrom(ref, draft),
    builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
      return ListView(shrinkWrap: true, children: [
        RasqNotice.warning(text: ctx.l10n.trendProfileEchoChamberWarning, margin: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0)),
        // 指向性 / 刺激性の欄はユーザーページの「ノートの表示」と同じ部品 (D-518)。幅が狭ければ縦に積む。
        TendencyControls(
          directionality: draft.directionality,
          onDirectionality: (v) => setSheet(() => draft = draft.copyWith(directionality: v)),
          stimulusCap: draft.stimulusCap,
          onStimulus: (axis, v) => setSheet(() => draft = draft.copyWith(stimulus: {...draft.stimulus, axis: v})),
          directivityTitle: ctx.l10n.trendProfileDirectivityTitle,
          directivitySubtitle: ctx.l10n.trendProfileDirectivitySubtitle,
          directivityDetail: ctx.l10n.trendProfileDirectivityDetail,
          stimulusTitle: ctx.l10n.trendProfileStimulusTitle,
          // 既定(恐れ / 嫌悪 / 怒り 45%、D-470)へ戻す。
          onStimulusReset: () => setSheet(() => draft = draft.copyWith(stimulus: TendencyProfile.defaultStimulus)),
          directivityExtra: [
            // 設定を共有 (D-470、前の「端末側で適用する」): オフにすると、おすすめ / トレンド / 関連 TL の既定適用を止める。
            RasqSwitchListTile(
              key: const Key('trend.tendency.share'),
              title: ctx.l10n.trendProfileShareTitle,
              subtitle: ctx.l10n.trendProfileShareSubtitle,
              detail: ctx.l10n.trendProfileShareDetail,
              value: draft.enabled,
              onChanged: (v) => setSheet(() => draft = draft.copyWith(enabled: v)),
            ),
          ],
        ),
        RasqCaption(
          ctx.l10n.trendProfileStimulusEstimate,
          detail: ctx.l10n.trendProfileStimulusEstimateDetail,
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, RasqSpacing.page),
        ),
      ]);
    }),
  );
  if (saved == true && context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.trendProfileTendencySaved)));
}

/// 好きなジャンル/方向性 FOW (D-153、p.2 中段): SNS 側の設定に任せる /
/// あなたのアクションから自動抽出 / 最近のアクションから好きなものを選択 > /
/// ジャンルのチップ(タップで外す、入力で追加)。
Future<void> openGenreFow(BuildContext context, WidgetRef ref) async {
  final manager = ref.read(overlayManagerProvider);
  var draft = ref.read(tendencyProfileProvider).value ?? const TendencyProfile();
  final input = TextEditingController();
  final saved = await manager.showBottomSheet<bool>(
    id: 'trend.genres',
    title: context.l10n.trendProfileGenres,
    confirmText: context.l10n.trendProfileDecide,
    onConfirm: () => saveTendencyProfileFrom(ref, draft),
    builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
      final scheme = Theme.of(ctx).colorScheme;
      void add(String raw) {
        final g = raw.trim().replaceFirst(RegExp(r'^#'), '');
        if (g.isEmpty || draft.genres.contains(g)) return;
        setSheet(() => draft = draft.copyWith(genres: [...draft.genres, g], disliked: [for (final d in draft.disliked) if (d != g) d]));
        input.clear();
      }

      return ListView(shrinkWrap: true, children: [
        RasqSwitchListTile(title: ctx.l10n.trendProfileSnsDefaultTitle, subtitle: ctx.l10n.trendProfileSnsDefaultSubtitle, value: draft.snsDefault, onChanged: (v) => setSheet(() => draft = draft.copyWith(snsDefault: v))),
        RasqSwitchListTile(title: ctx.l10n.trendProfileAutoGenreTitle, subtitle: ctx.l10n.trendProfileAutoGenreSubtitle, value: draft.autoGenre, onChanged: (v) => setSheet(() => draft = draft.copyWith(autoGenre: v))),
        RasqListTile(
          title: ctx.l10n.trendProfilePickFromActions,
          onTap: () async {
            final picked = await openGenrePickFow(ctx, ref, base: draft);
            if (picked != null) setSheet(() => draft = picked);
          },
        ),
        _label(ctx, ctx.l10n.trendProfileGenresTapToRemove),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
          child: Wrap(spacing: RasqSpacing.xs, runSpacing: RasqSpacing.xs, children: [
            if (draft.genres.isEmpty) Text(ctx.l10n.trendProfileNoneYet, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
            for (final g in draft.genres) RasqTogglePillButton(label: '#$g', activeLabel: '#$g ✕', active: true, onPressed: () => setSheet(() => draft = draft.copyWith(genres: [for (final x in draft.genres) if (x != g) x]))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
          child: Row(children: [
            Expanded(child: RasqInput(controller: input, hintText: ctx.l10n.trendProfileAddGenreHint, onSubmitted: add)),
            const SizedBox(width: RasqSpacing.xs),
            RasqIconButton(icon: Icons.add, tooltip: ctx.l10n.trendProfileAddGenre, onPressed: () => add(input.text)),
          ]),
        ),
        if (draft.examples.isNotEmpty) ...[
          _label(ctx, ctx.l10n.trendProfileExamplesLabel(draft.examples.allow.length, draft.examples.deny.length)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
            child: Wrap(spacing: RasqSpacing.xs, runSpacing: RasqSpacing.xs, children: [
              for (final (allow, side) in [(true, draft.examples.allow), (false, draft.examples.deny)])
                for (final e in side)
                  RasqTogglePillButton(
                    key: ValueKey('trend.example.${allow ? 'allow' : 'deny'}.${e.key}'),
                    label: allow ? ctx.l10n.trendProfileExampleAllow(e.shortLabel) : ctx.l10n.trendProfileExampleDeny(e.shortLabel),
                    activeLabel: '${allow ? ctx.l10n.trendProfileExampleAllow(e.shortLabel) : ctx.l10n.trendProfileExampleDeny(e.shortLabel)} ✕',
                    active: allow,
                    onPressed: () => setSheet(() => draft = draft.copyWith(examples: draft.examples.without(e))),
                  ),
            ]),
          ),
        ],
        if (draft.disliked.isNotEmpty) ...[
          _label(ctx, ctx.l10n.trendProfileDislikedTapToRemove),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
            child: Wrap(spacing: RasqSpacing.xs, runSpacing: RasqSpacing.xs, children: [
              for (final g in draft.disliked) RasqTogglePillButton(label: g, activeLabel: '$g ✕', active: true, onPressed: () => setSheet(() => draft = draft.copyWith(disliked: [for (final x in draft.disliked) if (x != g) x]))),
            ]),
          ),
        ],
        const SizedBox(height: RasqSpacing.page),
      ]);
    }),
  );
  input.dispose();
  if (saved == true && context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.trendProfileGenresSaved)));
}

// ── アクションからジャンルを選択 (D-154、p.2 右下) ──────────────────

/// 1 件の投稿からのジャンル候補: ハッシュタグ > 特徴語(GLiNER 相当の抽出、
/// D-104 と同じ `extractFeatures`)> メディアの alt(SigLIP の画像 → 語は
/// ml.infer 配線後。それまでは alt テキストの特徴語)。最大 [max]。
List<String> genreCandidatesOf(Post p, {int max = 6}) {
  final out = <String>[];
  void add(String s) {
    final g = s.trim().replaceFirst(RegExp(r'^#'), '');
    if (g.length >= 2 && !RegExp(r'^\d+$').hasMatch(g) && !out.contains(g)) out.add(g);
  }

  for (final m in RegExp(r'#([^\s#＃]+)').allMatches('${p.body} ${p.quote?.body ?? ''}')) { // l10n-ignore: ハッシュタグの照合(全角の＃)
    add(m.group(1)!);
  }
  final features = extractFeatures(p).toList()..sort((a, b) => b.length.compareTo(a.length));
  for (final f in features) {
    if (f.startsWith('@') || f.startsWith('http') || RegExp(r'^[a-z0-9._-]+$').hasMatch(f) && f.length < 4) continue;
    add(f);
    if (out.length >= max) break;
  }
  for (final m in p.media) {
    final alt = m.alt;
    if (alt == null || alt.isEmpty) continue;
    for (final f in extractFeaturesText(alt)) {
      add(f);
      if (out.length >= max) break;
    }
  }
  return out.take(max).toList();
}

/// アクションから自動抽出 (D-153/D-154): リアクション済みの投稿群の特徴語を
/// 頻出順に(GLiNER 抽出ノードと同じ [topFeaturesOf])。
List<String> autoGenresOf(List<Post> reacted, {int max = 8}) => [for (final f in topFeaturesOf(reacted, max: max * 2)) if (f.length >= 2 && !RegExp(r'^\d+$').hasMatch(f)) f].take(max).toList();

/// 最近のアクションから好きなものを選択 (D-154/D-157 → D-314): 共通の「例から選ぶ」FOW([openExamplePickFow])で、
/// リアクション済みの投稿を**類似話題でまとめ**(n-gram/特徴語 → Louvain、`topicsOf`)、話題性の強い順に 3 件ずつ
/// カードで出す。上のチップで**入れているプラグイン / クリップ / リスト**の中身からも選べる。「好き」/「好きではない」
/// (右/左スワイプでも)で、そのもの全体が好きな例 / 好きではない例になり(`TendencyProfile.examples`)、話題のカードで
/// 選んでいたジャンルの候補は、いままでどおり好きなジャンル / 好きではないジャンルにも入る。
/// 戻り値は編集後のプロファイル(決定せず閉じたら null)。
Future<TendencyProfile?> openGenrePickFow(BuildContext context, WidgetRef ref, {required TendencyProfile base, int perPage = 3}) async {
  List<ExampleCandidate>? recent;
  Object? error;
  try {
    recent = await recentActionCandidates(ref);
  } catch (e) {
    error = e;
  }
  if (!context.mounted) return null;
  final sources = ownExampleSources(ref, recent: error == null ? recent : null);
  final decisions = await openExamplePickFow(
    context,
    ref,
    id: 'trend.genres.pick',
    title: context.l10n.trendProfilePickTitle,
    sources: sources,
    initial: base.examples,
    perPage: perPage,
    intro: rasqDetail(
      context,
      context.l10n.trendProfilePickIntro,
      context.l10n.trendProfilePickIntroDetail(perPage),
    ),
  );
  return decisions == null ? null : applyTrendDecisions(base, decisions);
}

/// 決め([ExampleDecision])をプロファイルへ: そのものを好きな例 / 好きではない例に入れ、選んでいたジャンルは
/// 好きなジャンル / 好きではないジャンルへ(反対側からは外す。D-154 と同じ)。決めた順に当てる。
TendencyProfile applyTrendDecisions(TendencyProfile base, List<ExampleDecision> decisions) {
  var draft = base;
  for (final d in decisions) {
    final picked = d.genres;
    if (d.allow) {
      draft = draft.copyWith(genres: [...draft.genres, for (final g in picked) if (!draft.genres.contains(g)) g], disliked: [for (final x in draft.disliked) if (!picked.contains(x)) x]);
    } else {
      draft = draft.copyWith(disliked: [...draft.disliked, for (final g in picked) if (!draft.disliked.contains(g)) g], genres: [for (final x in draft.genres) if (!picked.contains(x)) x]);
    }
    draft = draft.copyWith(examples: draft.examples.withExample(d.candidate.example, allow: d.allow));
  }
  return draft;
}
