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
import '../home/post_row.dart';
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
        RasqListTile(title: 'トレンドプラグインの設定', subtitle: 'サーバーサイドのトレンドプロバイダー(準備中)', onTap: () => manager.showAlert(id: 'trend.profile.plugins', title: 'トレンドプラグインの設定', message: 'トレンドプロバイダープラグインの配布(ストア)後にここへ繋ぎます。', confirmText: 'OK')),
        RasqListTile(title: 'キャッシュネットワークの設定', subtitle: 'CDN からの読み込み(準備中)', onTap: () => manager.showAlert(id: 'trend.profile.cdn', title: 'キャッシュネット設定', message: 'CDN の URL / 取得期間 / メディアのみ、はキャッシュネット実装時にここへ繋ぎます。', confirmText: 'OK')),
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
      final tokens = RasqTokens.of(ctx);
      return ListView(shrinkWrap: true, children: [
        Container(
          margin: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
          padding: const EdgeInsets.all(RasqSpacing.sm),
          decoration: BoxDecoration(color: tokens.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(RasqSizes.radiusSm), border: Border.all(color: tokens.danger.withValues(alpha: 0.4))),
          child: Row(children: [
            Icon(Icons.warning_amber_rounded, color: tokens.danger, size: 18),
            const SizedBox(width: RasqSpacing.xs),
            Expanded(child: Text('トレンドの指向性/刺激性を強くすると、エコーチェンバーの影響を受けやすくなる危険性があります。', style: RasqTypography.caption.copyWith(color: tokens.danger))),
          ]),
        ),
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

/// 最近のアクションから好きなものを選択 (D-154): リアクション済みの投稿を
/// 1 枚ずつカードで出し、候補のジャンルをタップで選び「好き」/「好きではない」
/// (右/左スワイプでも)。戻り値は編集後のプロファイル(決定せず閉じたら null)。
Future<TendencyProfile?> openGenrePickFow(BuildContext context, WidgetRef ref, {required TendencyProfile base}) async {
  final manager = ref.read(overlayManagerProvider);
  final session = ref.read(currentSnsSessionProvider);
  var draft = base;
  List<Post> cards = const [];
  String? error;
  if (session != null) {
    try {
      cards = (await session.reactedPosts(limit: 20)).items;
    } catch (e) {
      error = '$e';
    }
  }
  var index = 0;
  final selected = <String>{};
  if (!context.mounted) return null;
  final done = await manager.showBottomSheet<bool>(
    id: 'trend.genres.pick',
    title: 'アクションからジャンルを選択',
    confirmText: '決定',
    builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
      final scheme = Theme.of(ctx).colorScheme;
      if (error != null) return Padding(padding: const EdgeInsets.all(RasqSpacing.page), child: Text('最近のアクションを取得できませんでした: $error', style: RasqTypography.bodySmall.copyWith(color: scheme.error)));
      if (cards.isEmpty) return const Padding(padding: EdgeInsets.all(RasqSpacing.page), child: RasqEmptyView(title: '最近のアクションがありません', hint: 'リアクションやブックマークをすると、ここから好きなジャンルを選べます'));
      if (index >= cards.length) {
        return Padding(padding: const EdgeInsets.all(RasqSpacing.page), child: RasqEmptyView(title: '全部見ました', hint: '好き ${draft.genres.length} / 好きではない ${draft.disliked.length}。決定で保存します'));
      }
      final p = cards[index];
      final candidates = genreCandidatesOf(p);
      if (selected.isEmpty && candidates.isNotEmpty) selected.addAll(candidates.take(2));
      void decide(bool like) {
        final picked = selected.isEmpty ? candidates.take(1).toList() : selected.toList();
        if (like) {
          draft = draft.copyWith(genres: [...draft.genres, for (final g in picked) if (!draft.genres.contains(g)) g], disliked: [for (final d in draft.disliked) if (!picked.contains(d)) d]);
        } else {
          draft = draft.copyWith(disliked: [...draft.disliked, for (final g in picked) if (!draft.disliked.contains(g)) g], genres: [for (final d in draft.genres) if (!picked.contains(d)) d]);
        }
        selected.clear();
        setSheet(() => index++);
      }

      return ListView(shrinkWrap: true, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
          child: Dismissible(
            key: ValueKey('genre.pick.${p.key}'),
            direction: DismissDirection.horizontal,
            confirmDismiss: (dir) async {
              decide(dir == DismissDirection.startToEnd); // 右へ = 好き
              return false; // 自分でカードを差し替える
            },
            background: Container(alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: RasqSpacing.page), child: const Text('好き', style: TextStyle(color: RasqColors.link, fontWeight: FontWeight.w700))),
            secondaryBackground: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: RasqSpacing.page), child: Text('好きではない', style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700))),
            // インラインフレームの小表示 (D-156)。
            child: InlinePostFrame(post: p, maxLines: 6, onTap: () {}),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
          child: Text('最近のアクションから好きな投稿、ジャンルを選択します。投稿内の単語や画像をタップすると、そのまま「好き/好きでない」ボタンを押したりスワイプしたりしてサンプル追加します。(${index + 1}/${cards.length})', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, 0),
          child: Wrap(spacing: RasqSpacing.xs, runSpacing: RasqSpacing.xs, children: [
            if (candidates.isEmpty) Text('この投稿からはジャンルを拾えませんでした', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
            for (final g in candidates) RasqTogglePillButton(label: '#$g', activeLabel: '#$g', active: selected.contains(g), onPressed: () => setSheet(() => selected.contains(g) ? selected.remove(g) : selected.add(g))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(RasqSpacing.page),
          child: Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => decide(false), child: const Text('好きではない'))),
            const SizedBox(width: RasqSpacing.sm),
            Expanded(child: FilledButton(onPressed: () => decide(true), child: const Text('好き'))),
          ]),
        ),
      ]);
    }),
  );
  return done == true ? draft : null;
}
