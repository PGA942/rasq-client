import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import '../home/post_row.dart';
import 'example_match.dart';

/// 例から選ぶ (D-314): 投稿 / プラグイン / クリップ / リスト(/ ストアの掲載)の中身をひと目で見て、
/// 「許す(好き)例」/「止める(好きではない)例」を決める共通の FOW。自分のトレンド(「最近のアクションから好きなものを
/// 選択」)と、チャイルドセーフの保護者の設定が使う。見た目と操作は D-154/D-157/D-158 の選択 FOW と同じ: 縦にカードを
/// [perPage] 枚、カードをタップして対象を選び、下の 1 組のボタン(右 / 左スワイプでも)で決める。決めたカードは消え、次のカードが出る。

/// 候補 1 件(カード 1 枚)。
@immutable
class ExampleCandidate {
  const ExampleCandidate({required this.example, this.title = '', this.subtitle, this.posts = const [], this.genres = const [], this.tags = const []});

  /// 決めたときに入る例(中身の要約つき)。
  final ContentExample example;

  /// 見出し(プラグイン / クリップ / リストの名前。投稿の話題は空)。
  final String title;

  /// 説明(プラグインの説明、クリップ / リストの説明)。
  final String? subtitle;

  /// 中身の投稿(先頭が代表。投稿の話題なら話題の投稿、クリップ / リストなら含まれる投稿)。
  final List<Post> posts;

  /// ジャンルの候補(自分のトレンドの「最近のアクション」だけ。タップで選び、好き / 好きではないのジャンルにも入る)。
  final List<String> genres;

  /// 小さな札(プラグインのスロットなど)。
  final List<String> tags;

  String get key => example.key;
}

/// 候補の出どころ(上のチップ 1 つ)。[load] は開いたときに 1 度([searchHint] があれば、検索のたびに)呼ぶ。
@immutable
class ExampleSource {
  const ExampleSource({required this.id, required this.label, required this.load, this.searchHint, this.emptyTitle = '候補がありません', this.emptyHint, this.preloaded});
  final String id;
  final String label;
  final Future<List<ExampleCandidate>> Function(String query) load;

  /// 検索できる出どころ(ストアなど)の入力欄のヒント。null = 検索なし。
  final String? searchHint;
  final String emptyTitle;
  final String? emptyHint;

  /// 開く前に読んでおいた候補(最初のカードがすぐ出るように)。
  final List<ExampleCandidate>? preloaded;
}

/// 決め 1 件。[genres] は選んでいたジャンルの候補(無ければ空)。
@immutable
class ExampleDecision {
  const ExampleDecision({required this.candidate, required this.allow, this.genres = const []});
  final ExampleCandidate candidate;
  final bool allow;
  final List<String> genres;
}

/// 読み込みの状態(出どころごと)。
class _SourceState {
  List<ExampleCandidate>? items;
  Object? error;
  bool loading = false;
  String query = '';
}

/// 例から選ぶ FOW を開く。決定で決めた順の [ExampleDecision] を返す(決定せずに閉じたら null)。
/// [initial] は今ある例(数の表示と、もう決めた候補を出さないため)。
Future<List<ExampleDecision>?> openExamplePickFow(
  BuildContext context,
  WidgetRef ref, {
  required String id,
  required String title,
  required List<ExampleSource> sources,
  ContentExamples initial = ContentExamples.none,
  String allowLabel = '好き',
  String denyLabel = '好きではない',
  String? intro,
  int perPage = 3,
}) async {
  final manager = ref.read(overlayManagerProvider);
  final states = {for (final s in sources) s.id: _SourceState()..items = s.preloaded};
  final decisions = <ExampleDecision>[];
  final decided = <String>{for (final e in [...initial.allow, ...initial.deny]) e.key};
  final selected = <String, Set<String>>{};
  var current = sources.first.id;
  String? focused; // 下のボタンの対象 (D-158)
  final search = TextEditingController();

  int count(bool allow) {
    var ex = initial;
    for (final d in decisions) {
      ex = ex.withExample(d.candidate.example, allow: d.allow);
    }
    return allow ? ex.allow.length : ex.deny.length;
  }

  if (!context.mounted) return null;
  final done = await manager.showBottomSheet<bool>(
    id: id,
    title: title,
    confirmText: '決定',
    builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
      final scheme = Theme.of(ctx).colorScheme;
      final source = sources.firstWhere((s) => s.id == current);
      final st = states[current]!;

      Future<void> load(ExampleSource s, String query) async {
        final state = states[s.id]!;
        state
          ..loading = true
          ..error = null
          ..query = query;
        try {
          final items = await s.load(query);
          if (state.query == query) state.items = items;
        } catch (e) {
          state.error = e;
        } finally {
          state.loading = false;
          if (ctx.mounted) setSheet(() {});
        }
      }

      if (st.items == null && !st.loading && st.error == null) Future.microtask(() => load(source, st.query));

      final pending = [for (final c in st.items ?? const <ExampleCandidate>[]) if (!decided.contains(c.key)) c];
      final page = pending.take(perPage).toList();
      if (page.isNotEmpty && !page.any((c) => c.key == focused)) focused = page.first.key;

      Set<String> selOf(ExampleCandidate c) => selected[c.key] ?? c.genres.take(2).toSet();
      void decide(ExampleCandidate c, bool allow) {
        final sel = selOf(c);
        decisions.add(ExampleDecision(candidate: c, allow: allow, genres: sel.isEmpty ? c.genres.take(1).toList() : [for (final g in c.genres) if (sel.contains(g)) g]));
        decided.add(c.key);
        selected.remove(c.key);
        setSheet(() {});
      }

      void skip(ExampleCandidate c) => setSheet(() => decided.add(c.key));

      Widget body;
      if (st.error != null) {
        body = Padding(padding: const EdgeInsets.all(RasqSpacing.page), child: Text('${source.label}を読み込めませんでした: ${st.error}', style: RasqTypography.bodySmall.copyWith(color: scheme.error)));
      } else if (st.items == null) {
        body = const Padding(padding: EdgeInsets.all(RasqSpacing.page), child: RasqLoading());
      } else if (st.items!.isEmpty) {
        body = Padding(padding: const EdgeInsets.all(RasqSpacing.page), child: RasqEmptyView(title: source.emptyTitle, hint: source.emptyHint));
      } else if (page.isEmpty) {
        body = Padding(padding: const EdgeInsets.all(RasqSpacing.page), child: RasqEmptyView(title: '全部見ました', hint: '$allowLabel ${count(true)} / $denyLabel ${count(false)}。決定で保存します'));
      } else {
        body = Column(mainAxisSize: MainAxisSize.min, children: [
          for (final c in page)
            Padding(
              padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
              child: Dismissible(
                key: ValueKey('example.swipe.${c.key}'),
                direction: DismissDirection.horizontal,
                confirmDismiss: (dir) async {
                  decide(c, dir == DismissDirection.startToEnd); // 右へ = 許す(好き)
                  return false; // 自分でカードを差し替える
                },
                background: Container(alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: RasqSpacing.page), child: Text(allowLabel, style: const TextStyle(color: RasqColors.link, fontWeight: FontWeight.w700))),
                secondaryBackground: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: RasqSpacing.page), child: Text(denyLabel, style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700))),
                child: GestureDetector(
                  key: ValueKey('example.card.${c.key}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setSheet(() => focused = c.key),
                  child: _CandidateCard(
                    candidate: c,
                    focused: c.key == focused,
                    selected: selOf(c),
                    onTap: () => setSheet(() => focused = c.key),
                    onGenre: (g) => setSheet(() {
                      focused = c.key;
                      final sel = selected.putIfAbsent(c.key, () => c.genres.take(2).toSet());
                      sel.contains(g) ? sel.remove(g) : sel.add(g);
                    }),
                  ),
                ),
              ),
            ),
          const SizedBox(height: RasqSpacing.sm),
        ]);
      }

      final target = page.where((c) => c.key == focused).firstOrNull;
      return Column(mainAxisSize: MainAxisSize.min, children: [
        Flexible(
          child: ListView(shrinkWrap: true, children: [
            if (sources.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
                child: Wrap(spacing: RasqSpacing.xs, runSpacing: RasqSpacing.xs, children: [
                  for (final s in sources)
                    ChoiceChip(
                      key: ValueKey('example.source.${s.id}'),
                      label: Text(s.label),
                      selected: s.id == current,
                      onSelected: (_) => setSheet(() {
                        current = s.id;
                        focused = null;
                      }),
                    ),
                ]),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
              child: Text(
                '${intro ?? '中身を見て、下の「$allowLabel」/「$denyLabel」(右 / 左スワイプでも)で例にします。新しいものは、例との近さで分けます。'}($allowLabel ${count(true)} / $denyLabel ${count(false)}・残り ${pending.length} 件)',
                key: const ValueKey('example.summary'),
                style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            if (source.searchHint != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
                child: Row(children: [
                  Expanded(child: RasqInput(key: const ValueKey('example.search'), controller: search, hintText: source.searchHint, onSubmitted: (q) => load(source, q.trim()))),
                  const SizedBox(width: RasqSpacing.xs),
                  RasqIconButton(icon: Icons.search, tooltip: '探す', onPressed: () => load(source, search.text.trim())),
                ]),
              ),
            body,
          ]),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, RasqSpacing.xs),
          child: Row(children: [
            Expanded(child: OutlinedButton(key: const ValueKey('example.deny'), onPressed: target == null ? null : () => decide(target, false), child: Text(denyLabel))),
            const SizedBox(width: RasqSpacing.xs),
            TextButton(key: const ValueKey('example.skip'), onPressed: target == null ? null : () => skip(target), child: const Text('とばす')),
            const SizedBox(width: RasqSpacing.xs),
            Expanded(child: FilledButton(key: const ValueKey('example.allow'), onPressed: target == null ? null : () => decide(target, true), child: Text(allowLabel))),
          ]),
        ),
      ]);
    }),
  );
  search.dispose();
  return done == true ? decisions : null;
}

/// 候補のカード: 種類ごとに中身を小さく見せる(投稿 = インラインフレーム、プラグイン = 名前 / 説明 / スロット、
/// クリップ / リスト = 名前と含まれる投稿の先頭 2 件)。
class _CandidateCard extends StatelessWidget {
  const _CandidateCard({required this.candidate, required this.focused, required this.selected, required this.onTap, required this.onGenre});
  final ExampleCandidate candidate;
  final bool focused;
  final Set<String> selected;
  final VoidCallback onTap;
  final ValueChanged<String> onGenre;

  static const _icons = {
    ExampleKind.plugin: Icons.extension_outlined,
    ExampleKind.clip: Icons.collections_bookmark_outlined,
    ExampleKind.list: Icons.list_alt_outlined,
    ExampleKind.post: Icons.chat_bubble_outline,
    ExampleKind.text: Icons.short_text,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = candidate;
    final kind = c.example.kind;
    final caption = RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant);
    final more = c.posts.length - (kind == ExampleKind.post ? 1 : 2);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(RasqSizes.radiusLg),
        border: Border.all(color: focused ? RasqColors.link : scheme.outlineVariant, width: focused ? 2 : 1),
        color: focused ? RasqColors.link.withValues(alpha: 0.06) : null,
      ),
      padding: const EdgeInsets.all(RasqSpacing.xs),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (kind == ExampleKind.post && c.posts.isNotEmpty)
          // インラインフレームの小表示 (D-156)。右上に話題の件数。
          InlinePostFrame(post: c.posts.first, maxLines: 3, onTap: onTap, badge: c.posts.length > 1 ? RasqPill(label: '+${c.posts.length - 1} 件', color: RasqColors.sub, textColor: Colors.white) : null)
        else ...[
          Row(children: [
            Icon(_icons[kind], size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: RasqSpacing.xs),
            Expanded(child: Text(c.title.isEmpty ? c.example.shortLabel : c.title, style: RasqTypography.displayName, maxLines: 1, overflow: TextOverflow.ellipsis)),
            RasqPill(label: kind.label, color: scheme.surfaceContainerHighest, textColor: scheme.onSurface),
          ]),
          if (c.subtitle != null && c.subtitle!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(c.subtitle!, style: caption, maxLines: 2, overflow: TextOverflow.ellipsis)),
          if (c.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: RasqSpacing.xs),
              child: Wrap(spacing: 4, runSpacing: 4, children: [for (final t in c.tags) RasqPill(label: t, outlined: true)]),
            ),
          for (final p in c.posts.take(2)) Padding(padding: const EdgeInsets.only(top: RasqSpacing.xs), child: InlinePostFrame(post: p, maxLines: 2, onTap: onTap)),
          if ((kind == ExampleKind.clip || kind == ExampleKind.list) && c.posts.isEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text('投稿を読めませんでした(名前と説明で比べます)', style: caption)),
          if (more > 0 && kind != ExampleKind.post) Padding(padding: const EdgeInsets.only(top: 2), child: Text('ほか $more 件', style: caption)),
        ],
        if (c.genres.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: RasqSpacing.xs),
            child: Wrap(spacing: RasqSpacing.xs, runSpacing: RasqSpacing.xs, children: [
              for (final g in c.genres) RasqTogglePillButton(label: '#$g', activeLabel: '#$g', active: selected.contains(g), onPressed: () => onGenre(g)),
            ]),
          ),
      ]),
    );
  }
}
