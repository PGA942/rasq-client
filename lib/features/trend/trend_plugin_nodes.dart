import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart' show TimelineKind;

import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../child_safe/child_safe_providers.dart' show childGateProvider;
import '../nodeprog/node_executor.dart' show mergePostLists;
import '../nodeprog/tl_components.dart';
import '../nodeprog/tl_sections_view.dart' show TlPostsDisplay;
import '../plugins/slot_plugins.dart';
import 'tendency_profile.dart';
import 'trend_providers.dart';

/// トレンドプラグインのノード (D-470)。
///
/// D-470 より前のトレンドプラグイン(スロット `trend.suggest`)は、検索ホームの末尾の**固定の置き場**(「検索の候補」のチップ)
/// にしか出せなかった。いまは TL のカスタマイズ(と一時変更 FOW)の「SNSタイムライン」の並び / セクションに置く**ノード**
/// (`TlSourceComponent(tl: 'trendplugin:<プラグイン id>')`)で、形式([TrendNodeForm])を選んで出す:
/// - **トレンドを取得**: 候補のワードをトレンドのタイルの形で(タップでそのワードのトレンド TL)。
/// - **Today**: 候補の上位 [trendPluginTodayWords] 語の投稿をまとめたダイジェスト(いまのアカウントの検索結果を合流して新しい順。
///   表示モード / 件数はノードの設定)。
/// - **カスタム(候補のチップ)**: 前の「検索の候補」と同じチップ。トレンドページの既定の末尾はこのノード(前の置き場の引き継ぎ)。
///
/// プラグインの契約は変えていない(`trend.suggest {recent, query?, limit?}` をホストが呼んで、答えをノードの形に包む)。
/// `recent` は、トレンドページではそのページのトレンドのワード(通報 / 運営の制限 / 傾向を掛けたもの)、ほかの TL では
/// RASQ アカウントでまとめたトレンド(D-388)。候補には傾向 FOW の好きではないジャンル / 指向性を掛ける(トレンドのタイルと同じ)。

/// プラグインに聞く候補の数(ノードの件数はこの中から)。
const trendPluginRequestLimit = 20;

/// Today の形式で投稿を集める候補の語の数。
const trendPluginTodayWords = 3;

/// プラグインに渡すトレンドのワードの数。
const _recentLimit = 10;

typedef TrendPluginSuggestion = ({String text, String? reason, String plugin});

/// どのプラグインに(空 = 全部)、どのトレンドのワードを渡すか(改行区切り。family のキーなので文字列にしておく)。
typedef TrendPluginQuery = ({String plugin, String recent});

/// トレンドプラグインの候補 (D-470)。答えられなかったプラグインは飛ばす。同じ語(`#` と大文字小文字を無視)は 1 つに。
final trendPluginSuggestionsProvider = FutureProvider.autoDispose.family<List<TrendPluginSuggestion>, TrendPluginQuery>((ref, q) async {
  ref.watch(slotPluginsForProvider(SlotIds.trendSuggest)); // 入れる / 外すで聞き直す
  final recent = q.recent.isEmpty ? const <String>[] : q.recent.split('\n');
  List<({String text, String? reason, SlotPlugin plugin})> raw;
  try {
    raw = await ref.read(slotPluginsProvider.notifier).trendSuggest(recent, pluginId: q.plugin, limit: trendPluginRequestLimit);
  } catch (e) {
    debugPrint('trend plugin(${q.plugin}): $e');
    raw = const [];
  }
  final seen = <String>{};
  final out = [
    for (final s in raw)
      if (s.text.trim().isNotEmpty && seen.add(trendKey(s.text.trim()))) (text: s.text.trim(), reason: s.reason, plugin: s.plugin.manifest.name),
  ];
  TendencyProfile? profile;
  try {
    profile = await ref.watch(tendencyProfileProvider.future);
  } catch (_) {}
  return applyTendencyToTags(out, (s) => s.text, profile);
});

typedef TrendPluginToday = ({List<String> words, List<Post> posts});

/// Today の形式 (D-470): 候補の上位の語をいまのアカウントで検索して合流し、新しい順に。傾向 FOW のプロファイルも掛ける。
final trendPluginTodayProvider = FutureProvider.autoDispose.family<TrendPluginToday, TrendPluginQuery>((ref, q) async {
  final words = [for (final s in await ref.watch(trendPluginSuggestionsProvider(q).future)) s.text].take(trendPluginTodayWords).toList();
  final session = ref.watch(currentSnsSessionProvider);
  if (session == null || words.isEmpty) return (words: words, posts: const <Post>[]);
  final lists = <List<Post>>[];
  for (final w in words) {
    final query = w.replaceFirst(RegExp(r'^[#＃]'), '');
    try {
      lists.add((await session.searchPosts(query)).items);
    } catch (e) {
      debugPrint('trend plugin today($query): $e');
    }
  }
  final merged = [...mergePostLists(lists)]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  TendencyProfile? profile;
  try {
    profile = await ref.watch(tendencyProfileProvider.future);
  } catch (_) {}
  return (words: words, posts: applyTendencyProfile(merged, profile));
});

/// ノードが指すトレンドプラグイン(空の id = 入れているもの全部)。
List<SlotPlugin> trendPluginsOf(WidgetRef ref, TlSourceComponent node) {
  final all = ref.watch(slotPluginsForProvider(SlotIds.trendSuggest));
  final id = node.trendPluginId;
  return id.isEmpty ? all : [for (final p in all) if (p.id == id) p];
}

/// 見出し: 「トレンド(トレンドサジェスト)」「Today(…)」「検索の候補(…)」。プラグインが 1 つに決まらなければ「トレンドプラグイン」。
String trendPluginNodeLabel(WidgetRef ref, TlSourceComponent node) {
  final plugins = trendPluginsOf(ref, node);
  final name = plugins.length == 1 ? plugins.single.manifest.name : 'トレンドプラグイン';
  return '${node.form.heading}($name)';
}

/// プラグインに渡すトレンドのワード。[trends] はトレンドページのタイルに出しているワード(無ければ RASQ アカウントのトレンド)。
TrendPluginQuery trendPluginQueryOf(WidgetRef ref, TlSourceComponent node, AsyncValue<List<TrendTag>>? trends) {
  final tags = trends?.value ?? ref.watch(sourcedTrendsProvider).value?.tags ?? const <TrendTag>[];
  return (plugin: node.trendPluginId, recent: [for (final t in tags.take(_recentLimit)) t.tag].join('\n'));
}

/// このノードを(見出しごと)出さないか: トレンドプラグインが入っていない / 見守りでトレンドを止めている / 候補のチップで候補が無い
/// (前の固定の置き場と同じく、何も出さない)。
bool trendPluginNodeHidden(WidgetRef ref, TlSourceComponent node, AsyncValue<List<TrendTag>>? trends) {
  if (trendPluginsOf(ref, node).isEmpty) return true;
  final gate = ref.watch(childGateProvider);
  if (!gate.searchAllowed('trend')) return true;
  if (node.form == TrendNodeForm.today && !gate.searchAllowed('posts')) return true;
  if (node.form == TrendNodeForm.chips) {
    final items = ref.watch(trendPluginSuggestionsProvider(trendPluginQueryOf(ref, node, trends)));
    return items.hasValue && items.requireValue.isEmpty;
  }
  return false;
}

/// トレンドプラグインのノードの中身(形式ごと)。出さないときは空。
class TrendPluginNodeContent extends ConsumerWidget {
  const TrendPluginNodeContent({super.key, required this.node, this.trends});
  final TlSourceComponent node;
  final AsyncValue<List<TrendTag>>? trends;

  static Widget _loading() => const Padding(padding: EdgeInsets.all(RasqSpacing.md), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (trendPluginNodeHidden(ref, node, trends)) return const SizedBox.shrink();
    final q = trendPluginQueryOf(ref, node, trends);
    final key = node.trendPluginId.isEmpty ? 'all' : node.trendPluginId;
    if (node.form == TrendNodeForm.today) {
      final today = ref.watch(trendPluginTodayProvider(q));
      final v = today.value;
      if (v == null) return today.hasError ? const RasqCaption('読み込めませんでした') : _loading();
      if (v.posts.isEmpty) return RasqCaption(v.words.isEmpty ? '候補のワードはまだありません' : '${v.words.map((w) => '「$w」').join('')}の投稿はまだありません');
      final scheme = Theme.of(context).colorScheme;
      return Column(key: ValueKey('trend.plugin.today.$key'), mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, 0),
          child: Text('${v.words.map((w) => '「$w」').join('')}の投稿', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
        ),
        TlPostsDisplay(posts: v.posts, mode: node.display, limit: node.limit, scrollable: false, kind: TimelineKind.home),
      ]);
    }
    final items = ref.watch(trendPluginSuggestionsProvider(q));
    final v = items.value;
    if (v == null) return items.hasError ? const RasqCaption('読み込めませんでした') : _loading();
    final shown = v.take(node.limit).toList();
    if (shown.isEmpty) return const RasqCaption('候補のワードはまだありません');
    if (node.form == TrendNodeForm.chips) {
      return Padding(
        key: ValueKey('trend.plugin.chips.$key'),
        padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.sm),
        child: Wrap(spacing: RasqSpacing.xs, runSpacing: RasqSpacing.xs, children: [
          for (final s in shown) ActionChip(label: Text('#${s.text.replaceFirst(RegExp(r'^[#＃]'), '')}'), tooltip: s.reason, onPressed: () => context.pushTrend(s.text.replaceFirst(RegExp(r'^[#＃]'), ''))),
        ]),
      );
    }
    return Column(key: ValueKey('trend.plugin.tiles.$key'), mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final s in shown) _PluginTrendTile(suggestion: s)]);
  }
}

/// 「トレンドを取得」の形式の 1 行: ワード + 理由。タップでそのワードのトレンド TL(いまのアカウント)。
class _PluginTrendTile extends StatelessWidget {
  const _PluginTrendTile({required this.suggestion});
  final TrendPluginSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final word = suggestion.text.replaceFirst(RegExp(r'^[#＃]'), '');
    final reason = suggestion.reason;
    return InkWell(
      key: ValueKey('trend.plugin.tile.$word'),
      onTap: () => context.pushTrend(word),
      child: Container(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: scheme.outlineVariant))),
        padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.sm),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(word, style: RasqTypography.title.copyWith(fontSize: 16)),
          if (reason != null && reason.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(reason, maxLines: 1, overflow: TextOverflow.ellipsis, style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ]),
      ),
    );
  }
}
