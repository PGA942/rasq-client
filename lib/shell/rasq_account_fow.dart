import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart' show AccountSession;

import '../app/providers.dart';
import '../app/router.dart';
import '../backend/orgate_client.dart';
import '../backend/rasq_account.dart';
import '../session/sanctions.dart';
import '../features/notifications/notifications_screen.dart';

/// RASQ アカウントの選択/編集 FOW (D-138: サイドバー右上の … から)。
///
/// - アカウント選択部: 投稿タイルのユーザー名/アイコン部分と同じ行
///   ([RasqUserRow] = アバター + 表示名 + `@handle ● rasq`)。左端に通知数の
///   バッジ、右端の … でドロップダウン(ログアウト / アカウント設定 /
///   プロフィール編集 / 通知設定)。タップで切り替え。
/// - 下部: 「RASQ アカウントを作成」(Central に繋がる構成のとき)と
///   「SNS アカウントを追加」。
const rasqAccountFowId = 'fow.rasq.accounts';

Future<void> openRasqAccountFow(WidgetRef ref, {int column = 0}) async {
  final manager = ref.read(overlayManagerProvider);
  final spec = FowSpec(
    type: FowPanelType.widget,
    initialHeightFactor: 0.55,
    minHeightFactor: 0.3,
    maxHeightFactor: 0.9,
    title: 'RASQ アカウント',
    cancelText: '閉じる',
    dockAboveFooter: true,
    columnIndex: column,
  );
  await manager.showFow<void>(
    id: rasqAccountFowId,
    spec: spec,
    semanticsLabel: 'RASQ アカウント',
    barrierBehavior: OverlayBarrierBehavior.dismissDiscard,
    builder: (ctx, handle) => RasqAccountPanel(onDone: handle.close),
  );
}

/// 処置の案内(テスト用のキー)。
const rasqSanctionBannerKey = Key('rasq.account.sanction');

/// 解除申請のシート (D-152): 申請文 → `POST /me/sanctions/{id}/appeal`。
Future<void> showSanctionAppealSheet(BuildContext context, WidgetRef ref, RasqSanctionEntry entry) async {
  final manager = ref.read(overlayManagerProvider);
  final text = TextEditingController();
  var sent = false;
  await manager.showBottomSheet<void>(
    id: 'rasq.sanction.appeal',
    title: '処置の解除を申請',
    builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
      final scheme = Theme.of(ctx).colorScheme;
      return ListView(shrinkWrap: true, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
          child: Text('${entry.category} / ${entry.level}${entry.note == null ? '' : ' — ${entry.note}'}\n運営(rasq-judge)の担当者が読んで、受理なら処置が解除されます。自動判定は通りません。', style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant)),
        ),
        Padding(padding: const EdgeInsets.all(RasqSpacing.page), child: RasqInput(controller: text, hintText: '申請の理由(必須)', maxLines: 4, autofocus: true)),
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.page),
          child: FilledButton(
            onPressed: () async {
              final m = text.text.trim();
              if (m.isEmpty) return;
              try {
                await submitSanctionAppeal(ref, entry.id, m);
                sent = true;
                manager.close('rasq.sanction.appeal');
              } catch (e) {
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('申請できませんでした: $e')));
              }
            },
            child: const Text('申請する'),
          ),
        ),
      ]);
    }),
  );
  text.dispose();
  if (sent && context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('解除を申請しました。担当者が確認します')));
}

/// 台帳の 1 件を表示用 [UserSummary] に写す。現在のアカウントは
/// [rasqAccountProvider](サーバーのプロフィール優先)、他は台帳の値か、
/// 所属する最初の SNS セッションのプロフィールを借りる。
UserSummary summaryOfRecord(WidgetRef ref, RasqAccountRecord r, {required bool isCurrent}) {
  if (isCurrent) return ref.watch(rasqAccountProvider);
  final all = ref.watch(sessionsProvider).value?.allSessions ?? const <AccountSession>[];
  final first = all.where((s) => r.sessionKeys.contains(s.account.key)).firstOrNull;
  final handle = r.handle ?? first?.account.handle ?? (r.isCentral ? '' : 'local');
  return UserSummary(
    id: 'rasq:${r.id}',
    account: AccountId(kind: SnsKind.other, instance: 'rasq', handle: handle),
    displayName: r.displayName ?? first?.displayName ?? (r.isCentral ? 'RASQ' : 'この端末'),
    avatarUrl: r.avatarUrl ?? first?.avatarUrl,
  );
}

class RasqAccountPanel extends ConsumerWidget {
  const RasqAccountPanel({super.key, required this.onDone});
  final VoidCallback onDone;

  Rect _rectOf(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    return box == null ? Rect.zero : box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = RasqTokens.of(context);
    final manager = ref.watch(overlayManagerProvider);
    final ledger = ref.watch(rasqAccountsProvider).value ?? const RasqAccountsState();
    final current = ledger.current;
    final currentSns = ref.watch(currentAccountProvider);
    final unread = ref.watch(unreadNotificationCountProvider);
    final centralOk = ref.watch(centralConfiguredProvider);
    final all = ref.watch(sessionsProvider).value?.allSessions ?? const <AccountSession>[];
    void toast(String m) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }

    Future<void> more(RasqAccountRecord r, Rect anchor) async {
      final pick = await manager.showDropdown<String>(id: 'rasq.account.more', anchor: anchor, dense: true, items: [
        const RasqDropdownItem('プロフィール編集', 'profile'),
        const RasqDropdownItem('アカウント設定', 'settings'),
        const RasqDropdownItem('通知設定', 'notifications'),
        RasqDropdownItem('ログアウト', 'logout', destructive: true, enabled: r.isCentral),
      ]);
      if (!context.mounted) return;
      switch (pick) {
        case 'profile':
          await openRasqProfileSheet(context, ref, record: r);
        case 'settings':
          onDone();
          context.push('${Routes.settings}/server');
        case 'notifications':
          await showNotificationPrefs(ref);
        case 'logout':
          final ok = await manager.showAlert(
            id: 'rasq.account.logout',
            title: 'RASQ アカウントからログアウト',
            message: 'この端末の RASQ Central との接続を切ります。SNS のログインは端末に残り、「この端末のみ」のアカウントに戻ります。',
            confirmText: 'ログアウト',
            cancelText: 'キャンセル',
            destructive: true,
          );
          if (!ok) return;
          await ref.read(orgateAccountProvider.notifier).signOut();
          await ref.read(rasqAccountsProvider.notifier).detachCentral(r.id);
          toast('RASQ アカウントからログアウトしました');
        default:
          break;
      }
    }

    Future<void> create() async {
      final name = ref.read(rasqAccountProvider).displayName;
      try {
        final account = await ref.read(orgateAccountProvider.notifier).createAccount(displayName: name);
        if (account == null) {
          toast('RASQ Central の接続先が設定されていません');
          return;
        }
        final rec = await ref.read(rasqAccountsProvider.notifier).attachCentral(
              centralAccountId: account.id,
              handle: account.handle,
              displayName: account.displayName,
              avatarUrl: account.avatarUrl,
            );
        if (!context.mounted) return;
        await openRasqProfileSheet(context, ref, record: rec);
      } on OrgateException catch (e) {
        toast('RASQ アカウントを作成できませんでした: ${e.message}');
      }
    }

    final sanctions = ref.watch(rasqSanctionsProvider).value ?? RasqSanctions.none;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        child: ListView(padding: EdgeInsets.zero, children: [
          // アカウントの処置 (D-151): 掛かっていれば先頭に案内。
          if (sanctions.active)
            Container(
              key: rasqSanctionBannerKey,
              margin: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
              padding: const EdgeInsets.all(RasqSpacing.sm),
              decoration: BoxDecoration(color: tokens.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(RasqSizes.radiusSm), border: Border.all(color: tokens.danger.withValues(alpha: 0.4))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('このアカウントには処置が掛かっています: ${sanctions.levelLabel}', style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700, color: tokens.danger)),
                if (sanctions.restrictedFeatures.isNotEmpty)
                  Text('止まっている機能: ${sanctions.restrictedFeatures.map((f) => RasqSanctions.featureLabels[f] ?? f).join(' / ')}', style: RasqTypography.caption),
                if (sanctions.moderated) Text('発言ごとに ${sanctions.reviewDelaySeconds} 秒の検閲遅延が入ります', style: RasqTypography.caption),
                for (final n in sanctions.notes) Text('運営より: $n', style: RasqTypography.caption),
                Text(sanctions.expiresAt == null ? '期限: なし' : '期限: ${sanctions.expiresAt!.toLocal()}', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
                // 解除申請 (D-152): 処置ごとに 1 つ。未処理があれば「申請中」。
                Wrap(spacing: RasqSpacing.xs, children: [
                  for (final e in sanctions.entries)
                    e.canAppeal
                        ? OutlinedButton(
                            onPressed: () => showSanctionAppealSheet(context, ref, e),
                            child: Text('解除を申請(${e.category} / ${e.level})', style: RasqTypography.caption),
                          )
                        : RasqPill(label: '申請中(${e.category})', color: RasqColors.sub, textColor: Colors.white),
                ]),
              ]),
            ),
          if (ledger.accounts.isEmpty)
            Padding(
              padding: const EdgeInsets.all(RasqSpacing.page),
              child: Text('RASQ アカウントはまだありません。', style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant)),
            ),
          for (final r in ledger.accounts) ...[
            Builder(builder: (rowContext) {
              final isCurrent = r.id == current?.id;
              final user = summaryOfRecord(ref, r, isCurrent: isCurrent);
              final snsCount = all.where((s) => r.sessionKeys.contains(s.account.key)).length;
              // 通知数は現在ログイン中の SNS アカウントの分(所属アカウントに付ける)。
              final badgeCount = currentSns != null && r.sessionKeys.contains(currentSns.key) ? unread : 0;
              return Container(
                color: isCurrent ? tokens.link.withValues(alpha: 0.06) : null,
                child: RasqUserRow(
                  user: user,
                  subtitle: '${r.kind.label} ・ SNS $snsCount件${isCurrent ? ' ・ 使用中' : ''}',
                  leading: SizedBox(
                    width: 24,
                    child: Center(child: RasqBadge(count: badgeCount, dot: false)),
                  ),
                  trailing: Builder(
                    builder: (buttonContext) => RasqIconButton(
                      icon: Icons.more_horiz,
                      size: 20,
                      tooltip: 'アカウントの操作',
                      onPressed: () => more(r, _rectOf(buttonContext)),
                    ),
                  ),
                  onTap: () async {
                    await ref.read(rasqAccountsProvider.notifier).select(r.id);
                    onDone();
                  },
                ),
              );
            }),
            const Divider(height: 1),
          ],
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (ledger.central == null) ...[
            FilledButton.icon(
              onPressed: centralOk ? create : null,
              icon: const RasqBrandIcon(size: 18),
              label: const Text('RASQ アカウントを作成'),
            ),
            if (!centralOk)
              Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text('RASQ Central の接続先が未設定です', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
                TextButton(
                  onPressed: () {
                    onDone();
                    context.push('${Routes.settings}/server');
                  },
                  child: const Text('接続先を設定'),
                ),
              ]),
            const SizedBox(height: RasqSpacing.xs),
          ],
          OutlinedButton.icon(
            onPressed: () {
              onDone();
              context.push(Routes.login);
            },
            icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
            label: const Text('SNS アカウントを追加'),
          ),
        ]),
      ),
    ]);
  }
}

/// プロフィール編集シート: 表示名(+ Central はハンドル)。Central は
/// `PATCH /me` の結果を台帳へ写す。ローカルは台帳が正本。
Future<void> openRasqProfileSheet(BuildContext context, WidgetRef ref, {required RasqAccountRecord record}) async {
  final manager = ref.read(overlayManagerProvider);
  final current = summaryOfRecord(ref, record, isCurrent: record.id == ref.read(currentRasqAccountProvider)?.id);
  final name = TextEditingController(text: current.displayName);
  final handle = TextEditingController(text: current.account.handle);
  final ok = await manager.showBottomSheet<bool>(
    id: 'rasq.profile.edit',
    title: 'プロフィール編集',
    confirmText: '保存',
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return Padding(
        padding: const EdgeInsets.all(RasqSpacing.page),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('表示名', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          RasqInput(controller: name, hintText: '表示名', autofocus: true),
          const SizedBox(height: RasqSpacing.sm),
          Text('ハンドル(@なし、a-z 0-9 _)', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          RasqInput(controller: handle, hintText: 'handle', enabled: record.isCentral),
          const SizedBox(height: RasqSpacing.xs),
          Text(
            record.isCentral ? 'RASQ Central 上のプロフィールを更新します。' : 'この端末だけのアカウントです。ハンドルは RASQ アカウントを作成すると付きます。',
            style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant),
          ),
        ]),
      );
    },
  );
  if (ok != true || !context.mounted) return;
  final newName = name.text.trim();
  final newHandle = handle.text.trim();
  try {
    if (record.isCentral) {
      final notifier = ref.read(orgateAccountProvider.notifier);
      await notifier.updateProfile(
        displayName: newName.isEmpty ? null : newName,
        handle: newHandle.isEmpty || newHandle == current.account.handle ? null : newHandle,
      );
      final updated = ref.read(orgateAccountProvider).value;
      await ref.read(rasqAccountsProvider.notifier).updateProfile(record.id, handle: updated?.handle, displayName: updated?.displayName, avatarUrl: updated?.avatarUrl);
    } else {
      await ref.read(rasqAccountsProvider.notifier).updateProfile(record.id, displayName: newName.isEmpty ? null : newName);
    }
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('プロフィールを保存しました')));
  } on OrgateException catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存できませんでした: ${e.message}')));
  }
}
