import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:rasq_design/rasq_design.dart' show RasqMediaPolicy;
import 'package:rasq_models/rasq_models.dart';
import 'package:rrl_core/rrl_core.dart';
import 'package:rrl_renderer/rrl_renderer.dart';

import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../text/inline_spans.dart';

/// カスタム TL の**完全置き換えタイル** (D-082: `tl.customize`、V5 検証済み)。
///
/// - タイル本体は RRL(RrlRenderer → L2 委譲)で描く。中のイベントは
///   プラグイン関数へ戻る。
/// - **スレッドナビはホスト保証**(V5「thread nav を奪えない」): タイルの
///   どこをタップしてもスレッド展開へ飛ぶタップ層をホストが被せる。
/// - **仮想化 TL の可視性** (D-082): 行の生成/破棄で
///   `lifecycle {visible|hidden}` をプラグインへ届ける(ListView の
///   仮想化がそのまま可視性の代理になる)。
class CustomTileRow extends ConsumerStatefulWidget {
  const CustomTileRow({super.key, required this.timelineId, required this.post, required this.node, required this.plugin});

  /// カスタム TL の id(プラグインローカル)。
  final String timelineId;
  final Post post;
  final RrlNode node;
  final WasmTimelinePlugin plugin;

  @override
  ConsumerState<CustomTileRow> createState() => _CustomTileRowState();
}

class _CustomTileRowState extends ConsumerState<CustomTileRow> {
  @override
  void initState() {
    super.initState();
    widget.plugin.notifyVisibility(widget.timelineId, widget.post.id, visible: true);
  }

  @override
  void dispose() {
    widget.plugin.notifyVisibility(widget.timelineId, widget.post.id, visible: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emojis = ref.watch(emojiCacheProvider);
    return GestureDetector(
      // スレッドナビの保証: 置き換えタイルでもタップでスレッド展開へ。
      behavior: HitTestBehavior.translucent,
      onTap: () => context.pushPost(widget.post),
      child: RrlRenderer(
        node: widget.node,
        host: RrlHost(
          instanceScope: 'customtl:${widget.timelineId}',
          scope: RrlScope({'emojis': emojis}),
          rslParser: InlineSpans.parse,
          // 画像はホストが渡した投稿 / 絵文字の URL だけ (D-407): プラグインが組んだ URL でホストに通信させない。
          mediaPolicy: RasqMediaPolicy.plugin(allowedUrls: {...hostProvidedPostMediaUrls(widget.post), for (final u in emojis.values) ?u?.toString()}),
          onEvent: (nodeId, kind, {fn, payload = const {}}) => widget.plugin.handleEvent(nodeId, kind, fn: fn, payload: payload),
        ),
      ),
    );
  }
}

/// 投稿に入っている(ホストが SNS から取った)画像 / メディアの URL (D-407)。プラグインの面でホストが読んでよいのはこれだけ。
Set<String> hostProvidedPostMediaUrls(Post p, [int depth = 0]) => {
      ?p.author.avatarUrl?.toString(),
      ?p.repostedBy?.avatarUrl?.toString(),
      for (final m in p.media) ...[m.url.toString(), ?m.thumbnailUrl?.toString()],
      for (final o in p.poll?.options ?? const <PollOption>[]) ?o.imageUrl?.toString(),
      for (final u in p.reactionEmojis.values) u.toString(),
      if (depth < 2) ...[
        if (p.quote case final q?) ...hostProvidedPostMediaUrls(q, depth + 1),
        if (p.replyTo case final r?) ...hostProvidedPostMediaUrls(r, depth + 1),
      ],
    };
