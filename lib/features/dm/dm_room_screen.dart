import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../shell/headers.dart';
import '../../shell/third_column.dart';
import '../compose/compose_target.dart';
import '../compose/composer_sheet.dart';
import '../home/post_row.dart';
import 'dm_providers.dart';
import '../home/timeline_providers.dart';
import '../../l10n/l10n.dart';

/// DMルーム: ページヘッダー(相手名) + ルームタイムライン(通常投稿の使い回し).
/// 送信は**常駐 stick コンポーザー** (D-050): ページを開くと縮小状態で置かれ、
/// 送信後も残る(ページ遷移で自動消滅 D-048)。
class DmRoomScreen extends ConsumerStatefulWidget {
  const DmRoomScreen({super.key, required this.peerId, this.room});
  final String peerId;
  final DmRoom? room;

  @override
  ConsumerState<DmRoomScreen> createState() => _DmRoomScreenState();
}

class _DmRoomScreenState extends ConsumerState<DmRoomScreen> {
  /// 常駐 stick (D-050)。このページへ戻ってきたときも無ければ置き直す。
  bool _composerScheduled = false;
  bool _composerDismissed = false; // ✕ で閉じた(このページ滞在中は再表示しない)
  void _ensureComposer(DmRoom room) {
    if (_composerDismissed || _composerScheduled || ref.read(overlayManagerProvider).contains(composerFowId)) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return; // 最前面のときだけ
    _composerScheduled = true;
    final kind = DynamicTimelines.forRoom(room);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!mounted) return;
        await showComposer(ref, ComposeDm(room), resident: true, column: fowColumnOf(context), onPosted: (_) {
          ref.read(timelineProvider(kind).notifier).refresh();
          ref.invalidate(dmRoomsProvider);
        });
        // 遷移直後はナビゲーターが未反映のことがあるので 1 フレーム待つ。
        if (!mounted) return;
        await WidgetsBinding.instance.endOfFrame;
        if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) _composerDismissed = true;
      } finally {
        _composerScheduled = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final peerId = widget.peerId;
    final rooms = ref.watch(dmRoomsProvider).value;
    final resolved = widget.room ?? rooms?.where((r) => r.peer.id == peerId).firstOrNull;
    final kind = resolved == null ? DynamicTimelines.dm(peerId) : DynamicTimelines.forRoom(resolved);
    final tl = ref.watch(timelineProvider(kind));
    final notifier = ref.read(timelineProvider(kind).notifier);
    final actions = ref.watch(currentSnsSessionProvider)?.actions ?? const [];
    final title = resolved?.displayTitle ?? tl.value?.posts.where((p) => p.author.id == peerId).firstOrNull?.author.displayName ?? 'DM';
    if (resolved != null) _ensureComposer(resolved);
    return Scaffold(
      appBar: RasqPageHeader(
        title: title,
        onMore: () {},
        // このページだけの DM 設定 (D-127: 未設定なら tl.dm の共通設定が効く)。
        actions: [RasqIconButton(icon: Icons.settings, size: 20, tooltip: context.l10n.dmRoomSettings, onPressed: () => context.push(Routes.tlConfig('tl.${kind.id}')))],
      ),
      body: tl.when(
        loading: () => const RasqLoading(),
        error: (e, _) => RasqErrorView(code: e is SnsApiException ? e.code : ErrorCode.internalServerError.copyWith(message: '$e'), onRetry: notifier.refresh, retryLabel: context.l10n.dmRetry),
        data: (s) => RefreshIndicator(
          onRefresh: notifier.refresh,
          child: s.posts.isEmpty
              ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: [const SizedBox(height: 120), RasqEmptyView(title: context.l10n.dmRoomEmpty)])
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: s.posts.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (context, i) => PostRow(post: s.posts[i], actions: actions, onAction: (a, {args = const {}}) => notifier.perform(s.posts[i], a, args: args), onTap: () => context.pushPost(s.posts[i])),
                ),
        ),
      ),
    );
  }
}
