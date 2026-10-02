import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../app/providers.dart';
import '../features/servers/server_badge.dart';

/// **浮かせたアカウントのタイル** (D-411): 画面の中身の上に浮かべた小さなタイル。どのアカウント(のセッション)でこの画面を
/// 読んでいるかを「アイコン + @ハンドル + {サーバーのアイコン} サーバー名」で出し、タップでいまの RASQ アカウントに入っている
/// SNS アカウントから選び直す([onPick])。トレンドTL・投稿の詳細(スレッド)で使う。D-397 のサーバーの印はこれに統合した。
class FloatingAccountTile extends ConsumerWidget {
  const FloatingAccountTile({super.key, required this.account, required this.onPick, this.id = 'accountTile', this.marked = const [], this.markLabel = '', this.busy = false});

  /// 読んでいるアカウント。null = いまのアカウント。
  final AccountId? account;

  /// 選んだアカウント(いま読んでいるものを選び直したときは呼ばない)。
  final ValueChanged<AccountId> onPick;

  /// ドロップダウンの id(オーバーレイの重複防止)。
  final String id;

  /// 選ぶ一覧で印を付けるアカウント(トレンドを出したアカウント / 投稿が元から属するアカウント)と、その印の文言。
  final List<AccountId> marked;
  final String markLabel;

  /// 切り替え中(別のアカウントで投稿を探している間)。
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final current = ref.watch(currentAccountProvider);
    final shown = account ?? current;
    final sessions = ref.watch(sessionsProvider).value;
    final me = ref.watch(currentUserProvider);
    final session = shown == null ? null : sessions?.allSessions.where((s) => s.account == shown).firstOrNull;
    // アイコンは、いまのアカウントなら me() のプロフィール、ほかはセッションに控えたもの。
    final avatarUrl = shown != null && me.account == shown ? me.avatarUrl : session?.avatarUrl;
    final name = shown != null && me.account == shown ? me.displayName : (session?.displayName ?? shown?.handle ?? '');
    return Material(
      color: scheme.surface,
      elevation: 3,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Builder(builder: (ctx) {
        return InkWell(
          onTap: busy ? null : () => _pick(ctx, ref, shown),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              RasqAvatar(imageUrl: avatarUrl, size: 28, fallbackLabel: name, semanticsLabel: 'アカウント'),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('@${shown?.handle ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700)),
                  if (shown != null) ServerBadge(account: shown, iconSize: 12),
                ]),
              ),
              const SizedBox(width: 2),
              if (busy)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              else
                Icon(Icons.unfold_more, size: 16, color: scheme.onSurfaceVariant),
            ]),
          ),
        );
      }),
    );
  }

  Future<void> _pick(BuildContext ctx, WidgetRef ref, AccountId? shown) async {
    final accounts = ref.read(sessionsProvider).value?.sessions ?? const <AccountSession>[];
    if (accounts.isEmpty) return;
    final box = ctx.findRenderObject() as RenderBox;
    final picked = await ref.read(overlayManagerProvider).showDropdown<String>(
      id: '$id.pick',
      anchor: box.localToGlobal(Offset.zero) & box.size,
      dense: true,
      items: [
        for (final s in accounts)
          RasqDropdownItem('${s.account}${marked.contains(s.account) && markLabel.isNotEmpty ? '($markLabel)' : ''}', s.account.key, checked: s.account == shown),
      ],
    );
    if (picked == null || picked == shown?.key) return;
    final account = accounts.where((s) => s.account.key == picked).firstOrNull?.account;
    if (account != null) onPick(account);
  }
}
