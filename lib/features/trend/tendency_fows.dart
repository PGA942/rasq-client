import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../nodeprog/node_executor.dart';
import '../relational/relational_engine.dart';
import 'example_picker.dart';
import 'example_sources.dart';
import 'tendency_profile.dart';

/// トレンドプロファイル設定 (D-153、ワイヤーフレーム p.2 中段下): 検索ホーム/
/// トレンド TL の ⚙ から。好きなジャンル/方向性のチップ、⚠ 指向性/刺激性、
/// トレンドプラグイン、キャッシュネットワーク、アルゴリズム(ノード)の編集。
Future<void> showTrendProfileSheet(BuildContext context, WidgetRef ref) async {
  final manager = ref.read(overlayManagerProvider);
  await manager.showBottomSheet<void>(
    id: 'trend.profile',
    title: 'トレンドプロファイル設定',
    cancelText: '閉じる',
    builder: (ctx) => Consumer(builder: (ctx, ref, _) {
      final profile = ref.watch(tendencyProfileProvider).value ?? const TendencyProfile();
      final scheme = Theme.of(ctx).colorScheme;
      return ListView(shrinkWrap: true, children: [
        _label(ctx, '好きなジャンル/方向性${profile.snsDefault ? '(SNS 側の設定に任せる)' : profile.autoGenre ? '(アクションから自動抽出)' : ''}'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
          child: Wrap(spacing: RasqSpacing.xs, runSpacing: RasqSpacing.xs, children: [
            for (final (i, g) in profile.genres.indexed) RasqTogglePillButton(label: g.startsWith('#') ? g : '#$g', activeLabel: g.startsWith('#') ? g : '#$g', active: i == 0, onPressed: () => openGenreFow(ctx, ref)),
            RasqTogglePillButton(label: profile.genres.isEmpty ? '+ ジャンルを追加' : '編集', active: false, onPressed: () => openGenreFow(ctx, ref)),
          ]),
        ),
        const SizedBox(height: RasqSpacing.xs),
        RasqWarningListTile(title: 'トレンドの指向性/刺激性', subtitle: '指向性 ${_dirLabel(profile.directionality)} ・ 刺激性 ${_stimLabel(profile)}', onTap: () => openTendencyFow(ctx, ref)),
        // 設定ページへ (D-238): トレンドプラグインの有効 / 無効、キャッシュネットワークの状態。
        RasqListTile(title: 'トレンドプラグインの設定', subtitle: '検索ホームの候補チップ(trend.suggest)', onTap: () {
          manager.close('trend.profile');
          ref.read(routerProvider).push('/settings/dsl/plugins.trend');
        }),
        RasqListTile(title: 'キャッシュネットワークの設定', subtitle: '未提供(第二期)', onTap: () {
          manager.close('trend.profile');
          ref.read(routerProvider).push('/settings/dsl/trend.cdn');
        }),
        RasqListTile(
          title: 'アルゴリズム(ノード)を編集',
          subtitle: 'トレンドの取得・並べ替えの鎖(ml.tendency ノードでこのプロファイルを使えます)',
          onTap: () {
            manager.close('trend.profile');
            context.push(Routes.tlConfig('trend'));
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, RasqSpacing.page),
          child: Text('このプロファイルは storage.safe(trend.profile)に保存され、おすすめ / トレンド / 関連 TL の既定と、ノードエディタの「指向性/刺激性」ノードが共通で読みます。', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
        ),
      ]);
    }),
  );
}

String _dirLabel(double v) => v <= 0.25 ? '狭い' : v >= 0.75 ? '広い' : 'ふつう';
String _stimLabel(TendencyProfile p) {
  final capped = [for (final e in TendencyProfile.emotions) if (p.stimulusCap(e) < 1.0) TendencyProfile.emotionLabels[e]!];
  return capped.isEmpty ? '制限なし' : '${capped.take(3).join('・')}を抑える';
}

Widget _label(BuildContext context, String text) => Padding(
      padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 2),
      child: Text(text, style: RasqTypography.caption.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );

/// トレンドの指向性/刺激性 FOW (D-153、p.2 中段上): エコーチェンバーの注意 +
/// 指向性スライダー(狭い ⇄ 広い)+ 刺激性レーダー(8 感情の上限、触って決める)。
/// 決定で保存、キャンセルで捨てる。
Future<void> openTendencyFow(BuildContext context, WidgetRef ref) async {
  final manager = ref.read(overlayManagerProvider);
  var draft = ref.read(tendencyProfileProvider).value ?? const TendencyProfile();
  final saved = await manager.showBottomSheet<bool>(
    id: 'trend.tendency',
    title: 'トレンドの指向性/刺激性',
    confirmText: '決定',
    onConfirm: () => saveTendencyProfileFrom(ref, draft),
    builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
      final scheme = Theme.of(ctx).colorScheme;
      return ListView(shrinkWrap: true, children: [
        const RasqNotice.warning(text: 'トレンドの指向性/刺激性を強くすると、エコーチェンバーの影響を受けやすくなる危険性があります。', margin: EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0)),
        RasqSliderListTile(
          title: 'トレンドの指向性',
          subtitle: '好きなジャンル/方向性への近さのしきい値(狭い ⇄ 広い)。狭いほど外れた投稿を落とします。',
          value: draft.directionality,
          min: 0,
          max: 1,
          divisions: 10,
          valueLabel: _dirLabel(draft.directionality),
          onChanged: (v) => setSheet(() => draft = draft.copyWith(directionality: v)),
        ),
        _label(ctx, 'トレンドの刺激性(各感情の上限。中心に寄せるほど抑える)'),
        Center(
          child: RasqRadarChart(
            key: const Key('trend.stimulus.radar'),
            axes: TendencyProfile.emotions,
            values: {for (final e in TendencyProfile.emotions) e: draft.stimulusCap(e)},
            labels: TendencyProfile.emotionLabels,
            onChanged: (axis, v) => setSheet(() => draft = draft.copyWith(stimulus: {...draft.stimulus, axis: v})),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, 0),
          child: Wrap(spacing: RasqSpacing.xs, runSpacing: RasqSpacing.xs, children: [
            for (final e in TendencyProfile.emotions)
              RasqPill(label: '${TendencyProfile.emotionLabels[e]} ${(draft.stimulusCap(e) * 100).round()}%', color: draft.stimulusCap(e) < 1 ? RasqColors.danger : scheme.surfaceContainerHighest, textColor: draft.stimulusCap(e) < 1 ? Colors.white : scheme.onSurface),
          ]),
        ),
        Align(alignment: Alignment.centerRight, child: Padding(padding: const EdgeInsets.only(right: RasqSpacing.sm), child: TextButton(onPressed: () => setSheet(() => draft = draft.copyWith(stimulus: const {})), child: const Text('刺激性をリセット')))),
        RasqSwitchListTile(title: '端末側で適用する', subtitle: 'オフにすると TL の既定適用を止めます(ノードで明示した分は効きます)', value: draft.enabled, onChanged: (v) => setSheet(() => draft = draft.copyWith(enabled: v))),
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.page),
          child: Text('刺激性は語彙ルールで推定しています(emotion8 / GRU の端末推論は ml.infer 配線後に差し替え)。', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
        ),
      ]);
    }),
  );
  if (saved == true && context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('トレンドの指向性/刺激性を保存しました')));
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
    title: '好きなジャンル/方向性',
    confirmText: '決定',
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
        RasqSwitchListTile(title: 'SNS 側の設定に任せる', subtitle: 'オンの間は端末側で絞りません', value: draft.snsDefault, onChanged: (v) => setSheet(() => draft = draft.copyWith(snsDefault: v))),
        RasqSwitchListTile(title: 'あなたのアクションから自動抽出', subtitle: 'リアクションした投稿の特徴語(GLiNER)を好きなジャンルに足します', value: draft.autoGenre, onChanged: (v) => setSheet(() => draft = draft.copyWith(autoGenre: v))),
        RasqListTile(
          title: '最近のアクションから好きなものを選択',
          onTap: () async {
            final picked = await openGenrePickFow(ctx, ref, base: draft);
            if (picked != null) setSheet(() => draft = picked);
          },
        ),
        _label(ctx, '好きなジャンル/方向性(タップで外す)'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
          child: Wrap(spacing: RasqSpacing.xs, runSpacing: RasqSpacing.xs, children: [
            if (draft.genres.isEmpty) Text('まだありません', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
            for (final g in draft.genres) RasqTogglePillButton(label: '#$g', activeLabel: '#$g ✕', active: true, onPressed: () => setSheet(() => draft = draft.copyWith(genres: [for (final x in draft.genres) if (x != g) x]))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
          child: Row(children: [
            Expanded(child: RasqInput(controller: input, hintText: 'ジャンル/キーワードを追加', onSubmitted: add)),
            const SizedBox(width: RasqSpacing.xs),
            RasqIconButton(icon: Icons.add, tooltip: 'ジャンルを追加', onPressed: () => add(input.text)),
          ]),
        ),
        if (draft.examples.isNotEmpty) ...[
          _label(ctx, '例(好き ${draft.examples.allow.length} / 好きではない ${draft.examples.deny.length}。タップで外す)'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
            child: Wrap(spacing: RasqSpacing.xs, runSpacing: RasqSpacing.xs, children: [
              for (final (allow, side) in [(true, draft.examples.allow), (false, draft.examples.deny)])
                for (final e in side)
                  RasqTogglePillButton(
                    key: ValueKey('trend.example.${allow ? 'allow' : 'deny'}.${e.key}'),
                    label: '${allow ? '好き' : '好きではない'}: ${e.shortLabel}',
                    activeLabel: '${allow ? '好き' : '好きではない'}: ${e.shortLabel} ✕',
                    active: allow,
                    onPressed: () => setSheet(() => draft = draft.copyWith(examples: draft.examples.without(e))),
                  ),
            ]),
          ),
        ],
        if (draft.disliked.isNotEmpty) ...[
          _label(ctx, '好きではない(タップで外す)'),
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
  if (saved == true && context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('好きなジャンル/方向性を保存しました')));
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

  for (final m in RegExp(r'#([^\s#＃]+)').allMatches('${p.body} ${p.quote?.body ?? ''}')) {
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
    title: 'アクションからジャンルを選択',
    sources: sources,
    initial: base.examples,
    perPage: perPage,
    intro: '最近のアクションを類似した話題でまとめ、話題性の強いものから $perPage 件ずつ出しています(上のチップでプラグイン / クリップ / リストからも)。カードをタップして選び、候補のジャンルを選んで下の「好き」/「好きではない」(右/左スワイプでも)。',
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
