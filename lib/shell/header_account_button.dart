import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../app/providers.dart';
import '../l10n/l10n.dart';

/// **ヘッダーのアカウントのボタン** (D-415、D-411 の浮かべたタイルを置き換えた): 戻る `<` の右に置く丸いアイコン。どのアカウント
/// (のセッション)でこの画面を読んでいるかをアイコンで出し、タップでその場に**アカウントの選択**を開く
/// (上に RASQ アカウント = アイコン・表示名・@ハンドル・閉じる `^`、下にその RASQ アカウントの SNS アカウント、いまのものにチェック)。
/// 選ぶと [onPick]。トレンドTL・投稿の詳細(スレッド)で使う。
class HeaderAccountButton extends ConsumerWidget {
  const HeaderAccountButton({
    super.key,
    required this.account,
    required this.onPick,
    this.id = 'accountButton',
    this.marked = const [],
    this.markLabel = '',
    this.busy = false,
    this.size = RasqSizes.searchBarHeight,
  });

  /// 読んでいるアカウント。null = いまのアカウント。
  final AccountId? account;

  /// 選んだアカウント(いま読んでいるものを選び直したときは呼ばない)。
  final ValueChanged<AccountId> onPick;

  /// 選択の id(オーバーレイの重複防止。選択の部品のキーの頭にも使う)。
  final String id;

  /// 選択で印を付けるアカウント(トレンドを出したアカウント / 開いたアカウント)と、その印の文言。
  final List<AccountId> marked;
  final String markLabel;

  /// 切り替え中(別のアカウントで投稿を探している間)。
  final bool busy;

  /// アイコンの直径。
  final double size;

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
    return Tooltip(
      message: shown == null ? context.l10n.shellAccountHeaderPickTooltip : context.l10n.shellAccountHeaderReadingAsTooltip('$shown'),
      child: Semantics(
        button: true,
        label: context.l10n.shellAccountHeaderSwitchSemantics,
        child: Builder(builder: (ctx) {
          return InkResponse(
            onTap: busy ? null : () => _pick(ctx, ref, shown),
            radius: size / 2 + 6,
            child: SizedBox(
              width: size + 8,
              height: RasqSizes.minTap,
              child: Center(
                child: Stack(alignment: Alignment.center, children: [
                  DecoratedBox(
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: scheme.outlineVariant)),
                    child: RasqAvatar(imageUrl: avatarUrl, size: size, fallbackLabel: name, semanticsLabel: context.l10n.shellAccountHeaderAvatarSemantics),
                  ),
                  if (busy) SizedBox(width: size, height: size, child: CircularProgressIndicator(strokeWidth: 2, color: scheme.primary)),
                ]),
              ),
            ),
          );
        }),
      ),
    );
  }

  Future<void> _pick(BuildContext ctx, WidgetRef ref, AccountId? shown) async {
    final accounts = ref.read(sessionsProvider).value?.sessions ?? const <AccountSession>[];
    if (accounts.isEmpty) return;
    final rasq = ref.read(rasqAccountProvider);
    final box = ctx.findRenderObject() as RenderBox;
    final origin = box.localToGlobal(Offset.zero);
    // ボタンの上に重ねて開く(RASQ アカウントの行がボタンの位置に来る)。錨は高さ 0 の線にして、その下に出す。
    final anchor = Rect.fromLTWH(origin.dx - RasqSpacing.sm, origin.dy, 0, 0);
    final picked = await ref.read(overlayManagerProvider).show(RasqOverlayEntry(
      id: '$id.pick',
      layer: OverlayLayer.dropdown,
      anchor: anchor,
      semanticsLabel: ctx.l10n.shellAccountPickerSemantics,
      builder: (context, handle) => AccountPickerPanel(
        id: id,
        rasq: rasq,
        accounts: [for (final s in accounts) s.account],
        selected: shown,
        marked: marked,
        markLabel: markLabel,
        onClose: handle.cancel,
        onPick: (a) => handle.close(result: a.key),
      ),
    ));
    if (picked is! String || picked == shown?.key) return;
    final account = accounts.where((s) => s.account.key == picked).firstOrNull?.account;
    if (account != null) onPick(account);
  }
}

/// アカウントの選択 (D-415): 上に RASQ アカウント(アイコン・表示名・@ハンドル・閉じる `^`)、下にその SNS アカウント。
/// いま読んでいるものにチェック、[marked] には印の文言([markLabel])を添える。
class AccountPickerPanel extends StatelessWidget {
  const AccountPickerPanel({
    super.key,
    required this.id,
    required this.rasq,
    required this.accounts,
    required this.selected,
    required this.onPick,
    required this.onClose,
    this.marked = const [],
    this.markLabel = '',
  });

  final String id;
  final UserSummary rasq;
  final List<AccountId> accounts;
  final AccountId? selected;
  final ValueChanged<AccountId> onPick;
  final VoidCallback onClose;
  final List<AccountId> marked;
  final String markLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = RasqTokens.of(context);
    return ConstrainedBox(
      key: ValueKey('$id.picker'),
      constraints: const BoxConstraints(minWidth: 260, maxWidth: 320),
      child: Material(
        color: scheme.surface,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RasqSizes.radiusLg), side: BorderSide(color: scheme.outlineVariant)),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: RasqSpacing.xs),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(RasqSpacing.sm, 0, RasqSpacing.xs, RasqSpacing.xs),
              child: Row(children: [
                RasqAvatar(imageUrl: rasq.avatarUrl, size: RasqSizes.searchBarHeight, fallbackLabel: rasq.displayName),
                const SizedBox(width: RasqSpacing.sm),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(rasq.displayName, key: ValueKey('$id.rasqName'), style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('@${rasq.account.handle}', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ),
                RasqIconButton(key: ValueKey('$id.close'), icon: Icons.keyboard_arrow_up, size: 20, tooltip: context.l10n.shellAccountPickerCloseTooltip, onPressed: onClose),
              ]),
            ),
            for (final a in accounts)
              InkWell(
                key: ValueKey('$id.item.${a.key}'),
                onTap: () => onPick(a),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.sm, vertical: 6),
                  child: Row(children: [
                    RasqSnsPill(account: a, showLabel: false, dotSize: 16),
                    const SizedBox(width: RasqSpacing.sm),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text('$a', style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (markLabel.isNotEmpty && marked.contains(a))
                          Text(markLabel, key: ValueKey('$id.mark.${a.key}'), style: RasqTypography.caption.copyWith(color: tokens.link)),
                      ]),
                    ),
                    SizedBox(
                      width: 24,
                      child: a == selected ? Icon(Icons.check, key: ValueKey('$id.check.${a.key}'), size: 18, color: scheme.primary) : null,
                    ),
                  ]),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
