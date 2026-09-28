import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/providers.dart';
import '../trend/example_match.dart';
import 'store_models.dart';

/// ストアの非同期更新 (D-358): スワイプで読み直したとき、**いま並んでいるものは位置を変えず**(中身だけ新しい値に)、
/// 画面を開いてから新しく見えるようになったもの(公開されたもの)だけを先頭に足す。[known] = この画面でこれまでに見た id。
/// 戻り = 並べ直した一覧と、新しく足した id。
({List<StorePluginCard> cards, Set<String> added}) mergeFreshCards(List<StorePluginCard> shown, List<StorePluginCard> fetched, Set<String> known) {
  final byId = {for (final c in fetched) c.id: c};
  final added = [for (final c in fetched) if (!known.contains(c.id)) c];
  return (
    cards: [...added, for (final c in shown) byId[c.id] ?? c],
    added: {for (final c in added) c.id},
  );
}

/// 足したタイルの印(「NEW」の札 + ふわっと出る)。
class StoreFreshMark extends StatelessWidget {
  const StoreFreshMark({super.key, required this.fresh, required this.child});
  final bool fresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!fresh) return child;
    final scheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      builder: (_, t, c) => Opacity(opacity: t.clamp(0.0, 1.0), child: Transform.scale(scale: 0.9 + 0.1 * t, child: c)),
      child: Stack(children: [
        child,
        Positioned(
          right: 10,
          bottom: 10,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(999)),
              child: Text('NEW', style: RasqTypography.caption.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── 「最近の投稿内容から選出」(D-358)──────────────────────────────

/// 読む投稿の数(アカウントごと)と、アカウントの数(いま使っているものから)。
const storeRecentPostsPerAccount = 20;
const storeRecentPostsAccounts = 3;

/// これ以上近いものだけ選ぶ(プラグインの紹介文と投稿の文は、同じ話題でも例どうしより離れるので [exampleNearThreshold] より低め)。
const storeRecentPickThreshold = 0.12;

/// 自分の最近の投稿の本文(いま使っているアカウントから順に、[storeRecentPostsAccounts] 個まで)。端末の中だけで使う。
final storeRecentPostTextsProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final all = ref.watch(sessionsProvider).value?.sessions ?? const <AccountSession>[];
  final current = ref.watch(currentAccountProvider);
  final ordered = [...all.where((s) => s.account.key == current?.key), ...all.where((s) => s.account.key != current?.key)].take(storeRecentPostsAccounts);
  final registry = ref.read(pluginRegistryProvider);
  final out = <String>[];
  for (final a in ordered) {
    try {
      final session = registry.session(a);
      final me = await session.me();
      final page = await session.userPosts(me.id, limit: storeRecentPostsPerAccount);
      out.addAll([for (final p in page.items) if (p.body.trim().isNotEmpty) p.body]);
    } catch (_) {
      // 読めないアカウントは飛ばす。
    }
  }
  return out;
});

/// プラグインと最近の投稿の近さ(投稿ごとのいちばん近い値)。
double storeRecentScore(StorePluginCard card, List<ContentExample> posts) =>
    exampleScoresOf([card.name, if (card.summary.trim().isNotEmpty) card.summary, card.pluginType.label], ContentExamples(allow: posts)).allow;

/// 近いものだけを近い順に。
List<StorePluginCard> pickByRecentPosts(List<StorePluginCard> cards, List<String> posts, {double threshold = storeRecentPickThreshold}) {
  final examples = [for (final (i, p) in posts.indexed) ContentExample(kind: ExampleKind.post, ref: 'p$i', text: exampleTextOf([p]))];
  final scored = [for (final c in cards) (c, storeRecentScore(c, examples))]..removeWhere((x) => x.$2 < threshold);
  scored.sort((a, b) => b.$2.compareTo(a.$2));
  return [for (final x in scored) x.$1];
}
