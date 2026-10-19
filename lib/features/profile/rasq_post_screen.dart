import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../backend/orgate_client.dart';
import '../../backend/rasq_account.dart';
import '../../backend/rasq_account_page_api.dart';
import '../../shell/headers.dart';
import '../../shell/third_column.dart';
import '../child_safe/child_safe_providers.dart' show childGateProvider;
import '../compose/compose_target.dart';
import '../compose/composer_sheet.dart';
import '../../l10n/l10n.dart';
import '../post/thread_section.dart';
import '../post/thread_section_bar.dart';
import '../settings/settings_dsl.dart';
import 'rasq_post_tile.dart';
import 'rasq_reactions_screen.dart';

/// 返信欄に出すもの (D-294): 帯の長押しで切り替える(SNS の欄の切り替え D-070 と同じ)。保存先も同じ(キーは `rasqMode`)。
enum RasqSectionMode {
  replies,
  queues,
  rebroads,
  quotes;

  String get label => switch (this) {
        replies => appL10n.profilePostReply,
        queues => appL10n.profilePostQueue,
        rebroads => appL10n.profilePostRebroad,
        quotes => appL10n.profilePostQuote,
      };
}

/// RASQ の投稿の詳細 (D-271 / S-022 → D-292): **SNS の投稿の詳細 (Misskey) と同じ作り**。
///
/// 元の投稿(返信のとき)→ この投稿 → **返信欄の帯**(∨ 短押しで並び順。SNS と同じ部品・同じ保存先)→ 返信。
/// 下には、SNS の返信と同じ**常駐の返信コンポーザー**(縮小状態で貼り付き、触ると開く。✕ で消えたら、返信ボタンで呼び戻す)。
/// 返信は RASQ アカウントとして送る(文字だけ、500 文字まで)。
class RasqPostScreen extends ConsumerStatefulWidget {
  const RasqPostScreen({super.key, required this.postId, this.onClose, this.residentComposer = true});
  final String postId;

  /// FOW の中で開いたとき (D-389: Swing の返信欄から): ヘッダーの < でこれを呼ぶ(画面を戻さない)。
  final VoidCallback? onClose;

  /// 常駐の返信コンポーザーを置くか(FOW の中では、呼んだ側が返信欄を持つので置かない)。
  final bool residentComposer;
  @override
  ConsumerState<RasqPostScreen> createState() => _RasqPostScreenState();
}

class _RasqPostScreenState extends ConsumerState<RasqPostScreen> {
  bool _composerScheduled = false;
  bool _composerDismissed = false; // ✕ で閉じた(このページにいる間は、返信ボタンを押すまで出さない)
  final Set<String> _openQueues = {};

  void _refresh() {
    ref.invalidate(rasqThreadProvider(widget.postId));
    ref.invalidate(rasqPostReactionsProvider(widget.postId));
  }

  Future<void> _switchMode(Rect rect, RasqSectionMode current) async {
    final m = await ref.read(overlayManagerProvider).showDropdown<RasqSectionMode>(id: 'rasqThread.mode', anchor: rect, dense: true, items: [
      for (final x in RasqSectionMode.values) RasqDropdownItem(x.label, x, checked: x == current),
    ]);
    if (m != null) await ref.read(settingsAreaProvider(threadRepliesKvArea).notifier).set('rasqMode', m.name);
  }

  /// 常駐の返信コンポーザー (D-050 と同じ流儀): このページが最前面のときだけ置く。ページを移ると自動で消える。
  void _ensureReplyComposer(RasqAccountPost target) {
    if (!widget.residentComposer) return;
    if (ref.read(orgateAccountProvider).value == null) return; // ログインしていなければ、返信できない
    if (_composerDismissed || _composerScheduled || ref.read(overlayManagerProvider).contains(composerFowId)) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    _composerScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!mounted) return;
        await showComposer(ref, ComposeReply(target.toPost(central: ref.read(centralBaseUrlProvider))), resident: true, column: fowColumnOf(context), onPosted: (_) => _refresh());
        if (!mounted) return;
        await WidgetsBinding.instance.endOfFrame;
        if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) _composerDismissed = true;
      } finally {
        _composerScheduled = false;
      }
    });
  }

  Future<void> _sort(Rect rect, ThreadSortOrder current) async {
    final o = await ref.read(overlayManagerProvider).showDropdown<ThreadSortOrder>(id: 'sort.thread', anchor: rect, dense: true, items: [
      for (final s in ThreadSortOrder.values) RasqDropdownItem(s.label, s, checked: s == current),
    ]);
    if (o != null) await ref.read(settingsAreaProvider(threadRepliesKvArea).notifier).set('order', o.name);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final thread = ref.watch(rasqThreadProvider(widget.postId));
    final saved = ref.watch(settingsAreaProvider(threadRepliesKvArea)).value ?? const <String, Object?>{};
    final order = ThreadSortOrder.values.asNameMap()[saved['order']] ?? ThreadSortOrder.none;
    final mode = RasqSectionMode.values.asNameMap()[saved['rasqMode']] ?? RasqSectionMode.replies;
    final target = thread.value?.post;
    // チャイルドセーフ (D-454、セキュリティ確認 2026-10-09 の [9]): SNS の投稿の詳細と同じく、見せない投稿 / 見守りの時間に
    // 詳細を開かせない設定なら、中身も返信欄も(常駐の返信コンポーザーも)出さない。
    final childBlocked = rasqPostDetailBlockReason(ref.watch(childGateProvider), target);
    if (childBlocked != null) {
      return Scaffold(
        appBar: RasqPageHeader(title: l10n.profilePostTitle, onBack: widget.onClose),
        body: RasqEmptyView(key: const ValueKey('childSafe.postHidden'), title: l10n.childSafePostHidden, hint: childBlocked == l10n.childSafePostHidden ? l10n.childSafeScreensBlockedHint : childBlocked),
      );
    }
    if (target != null) _ensureReplyComposer(target);
    // 返信ボタン: 消した常駐コンポーザーを呼び戻す (D-096 と同じ)。
    void reply() => setState(() => _composerDismissed = false);

    return Scaffold(
      appBar: RasqPageHeader(title: l10n.profilePostTitle, onBack: widget.onClose),
      body: thread.when(
        loading: () => const RasqLoading(),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(RasqSpacing.page),
          child: Text(e is OrgateException && e.code.code == '404' ? l10n.profilePostGone : l10n.profilePostLoadFailed('${e is OrgateException ? e.message : e}'), style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant)),
        ),
        data: (t) {
          // 並び順は、SNS の返信欄と同じ関数で(SNS の投稿の形に写して並べ、元の投稿へ戻す)。
          final central = ref.watch(centralBaseUrlProvider);
          final byId = {for (final r in t.replies) r.id: r};
          final sorted = [
            for (final p in sortThreadPosts([for (final r in t.replies) r.toPost(central: central)], order, t.post.toPost(central: central)))
              if (byId[p.id] != null) byId[p.id]!,
          ];
          // 常駐コンポーザーのぶん、下を空ける。
          return ListView(padding: const EdgeInsets.only(bottom: 160), children: [
            if (t.parent != null) RasqPostTileView(post: t.parent!, onChanged: _refresh, onOpen: () => context.push(Routes.rasqPost(t.parent!.id))),
            if (t.parent == null && t.post.isReply && !t.parentHidden)
              Padding(padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0), child: Text(l10n.profilePostParentDeleted, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant))),
            RasqPostTileView(post: t.post, focused: true, onChanged: _refresh, onReply: reply),
            // 帯: 短押し = 並び順(返信のとき)、長押し = 欄の切り替え、右 = 「リアクションを表示」のページへ (D-294)。
            ThreadSectionBar(
              label: mode == RasqSectionMode.replies ? l10n.profilePostRepliesCount(t.replies.length) : mode.label,
              order: mode == RasqSectionMode.replies ? order : ThreadSortOrder.none,
              onSortTap: mode == RasqSectionMode.replies ? (r) => _sort(r, order) : null,
              onModeTap: (r) => _switchMode(r, mode),
              trailing: TextButton(
                key: const ValueKey('rasqThread.showReactions'),
                onPressed: () => context.push(Routes.rasqPostReactions(t.post.id)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [Text(l10n.profilePostMenuReactions), const Icon(Icons.chevron_right, size: 18)]),
              ),
            ),
            if (mode == RasqSectionMode.replies) ...[
              if (t.replies.isEmpty) Padding(padding: const EdgeInsets.all(RasqSpacing.page), child: Text(l10n.profilePostNoRepliesYet, style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant))),
              for (final r in sorted) ...[
                RasqPostTileView(key: ValueKey('rasqThread.reply.${r.id}'), post: r, onChanged: _refresh, onOpen: () => context.push(Routes.rasqPost(r.id))),
                const Divider(),
              ],
            ] else
              ref.watch(rasqPostReactionsProvider(widget.postId)).when(
                    loading: () => const RasqLoading(),
                    error: (e, _) => Padding(padding: const EdgeInsets.all(RasqSpacing.page), child: Text(l10n.profilePostLoadFailed('${e is OrgateException ? e.message : e}'), style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant))),
                    data: (rx) => switch (mode) {
                      RasqSectionMode.queues => RasqQueueSections(groups: rx.queues, open: _openQueues, shrinkWrap: true, onToggle: (k) => setState(() => _openQueues.contains(k) ? _openQueues.remove(k) : _openQueues.add(k))),
                      RasqSectionMode.rebroads => RasqActorList(actors: rx.rebroads, empty: l10n.profilePostNoRebroads, shrinkWrap: true),
                      _ => RasqPostTileList(posts: rx.quotes, empty: l10n.profilePostNoQuotes, onChanged: _refresh, shrinkWrap: true),
                    },
                  ),
          ]);
        },
      ),
    );
  }
}
