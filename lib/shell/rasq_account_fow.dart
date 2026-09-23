import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart' show AccountSession;

import '../app/providers.dart';
import '../app/router.dart';
import '../backend/notify_api.dart';
import '../backend/orgate_client.dart';
import '../backend/rasq_account.dart';
import '../session/sanctions.dart';
import 'rasq_register_fow.dart';
import 'third_column.dart';
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

/// [onNavigate] = FOW から別の画面へ移るときに呼ぶ(サイドバーを開いたまま FOW を出しているとき、サイドバーも閉じる。D-272)。
/// [overSidebar] = サイドバーを開いたまま出す (D-274): **後ろを暗くして、サイドバーの上に被せる**。1 カラムなら全幅、2 カラムなら左カラム
/// (左カラムに入りきらない幅なら、2 カラムにまたがる)。
Future<void> openRasqAccountFow(WidgetRef ref, {int column = 0, VoidCallback? onNavigate, bool overSidebar = false}) async {
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
    aboveSidebar: overSidebar,
    dimBehind: overSidebar,
    spanColumnsBelow: overSidebar ? 360 : null,
  );
  await manager.showFow<void>(
    id: rasqAccountFowId,
    spec: spec,
    semanticsLabel: 'RASQ アカウント',
    barrierBehavior: OverlayBarrierBehavior.dismissDiscard,
    builder: (ctx, handle) => RasqAccountPanel(onDone: handle.close, onNavigate: onNavigate),
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

/// アカウント FOW で、操作を開いているアカウント (D-291)。null = どれも畳んでいる。
class RasqAccountFowExpanded extends Notifier<String?> {
  @override
  String? build() => null;
  void toggle(String id) => state = state == id ? null : id;
}

final rasqAccountFowExpandedProvider = NotifierProvider<RasqAccountFowExpanded, String?>(RasqAccountFowExpanded.new);

class RasqAccountPanel extends ConsumerWidget {
  const RasqAccountPanel({super.key, required this.onDone, this.onNavigate});
  final VoidCallback onDone;

  /// 別の画面へ移るとき(FOW を閉じるのに加えて呼ぶ)。
  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = RasqTokens.of(context);
    final manager = ref.watch(overlayManagerProvider);
    final ledger = ref.watch(rasqAccountsProvider).value ?? const RasqAccountsState();
    final current = ledger.current;
    final expandedId = ref.watch(rasqAccountFowExpandedProvider);
    final currentSns = ref.watch(currentAccountProvider);
    final unread = ref.watch(unreadNotificationCountProvider);
    final centralOk = ref.watch(centralConfiguredProvider);
    final all = ref.watch(sessionsProvider).value?.allSessions ?? const <AccountSession>[];
    void toast(String m) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }

    // 別の画面へ移る: FOW を閉じ、サイドバーから開いていればサイドバーも閉じる。
    void leave() {
      onDone();
      onNavigate?.call();
    }

    // ↓ で開く操作の一覧 (D-272 → D-291): ドロップダウンをやめて、**タイルの下に折りたたみで出す**(もう一度 ↓ で畳む)。
    List<RasqDropdownItem<String>> itemsOf(RasqAccountRecord r) => [
        const RasqDropdownItem('SNS アカウントを追加', 'addSns'),
        const RasqDropdownItem('設定', 'allSettings'),
        if (r.isCentral) const RasqDropdownItem('アカウントページ', 'page'),
        const RasqDropdownItem('プロフィール編集', 'profile'),
        const RasqDropdownItem('アカウント設定', 'settings'),
        const RasqDropdownItem('通知設定', 'notifications'),
        if (r.isCentral) const RasqDropdownItem('セキュリティ(メール / パスワード / 端末)', 'security'),
        RasqDropdownItem('ログアウト', 'logout', destructive: true, enabled: r.isCentral),
        if (r.isCentral) const RasqDropdownItem('RASQ アカウントを削除', 'delete', destructive: true),
      ];

    Future<void> act(RasqAccountRecord r, String pick) async {
      if (!context.mounted) return;
      switch (pick) {
        case 'addSns':
          leave();
          context.push(Routes.login);
        case 'allSettings':
          leave();
          context.push(Routes.settings);
        case 'page':
          final handle = ref.read(orgateAccountProvider).value?.handle ?? r.handle;
          if (handle == null || handle.isEmpty) return;
          leave();
          context.push(Routes.rasqAccount(handle));
        case 'profile':
          await openRasqProfileSheet(context, ref, record: r, beforeNavigate: leave);
        case 'settings':
          leave();
          context.push('${Routes.settings}/server');
        case 'notifications':
          await showNotificationPrefs(ref);
        case 'security':
          leave();
          context.push('${Routes.settings}/security');
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
        case 'delete':
          // アカウント削除 (D-241 / S-015)。学習へのデータ提供の撤回と、提供済みデータの削除も一緒に始まる
          // (「別に撤回しない限り残る」にはしない = ストアのアカウント削除要件)。
          final ok = await manager.showAlert(
            id: 'rasq.account.delete',
            title: 'RASQ アカウントを削除',
            message: 'サーバー上のプロフィール、アカウントバンドル、同期した設定、レビューとブックマーク、AsTell のルームと共有、通知トークン、同意の記録を削除します。'
                '学習へのデータ提供に同意していた場合は、提供の停止と提供済みデータの削除も同時に始まります。\n'
                '元に戻せません。SNS のログインは端末に残り、「この端末のみ」のアカウントに戻ります。各 SNS 上のアカウントと投稿は消えません。',
            confirmText: '削除する',
            cancelText: 'キャンセル',
            destructive: true,
          );
          if (!ok) return;
          // メールが確認済みのアカウントは、確認コードが要る (S-019) → セキュリティの画面で。
          if (ref.read(orgateAccountProvider).value?.emailVerified == true) {
            if (!context.mounted) return;
            leave();
            context.push('${Routes.settings}/security');
            toast('削除には、メールの確認コードが要ります。「アカウントの削除」から進めてください');
            return;
          }
          try {
            await ref.read(orgateAccountProvider.notifier).deleteAccount();
            await ref.read(rasqAccountsProvider.notifier).detachCentral(r.id);
            ref.invalidate(notifyStoreProvider);
            toast('RASQ アカウントを削除しました');
          } on OrgateException catch (e) {
            toast('削除できませんでした: ${e.message}');
          }
        default:
          break;
      }
    }

    Future<void> create() async {
      final name = ref.read(rasqAccountProvider).displayName;
      try {
        // 登録の FOW (D-241): 利用規約 / 年齢 / バンドルを置き換えるか → 登録 → 同意の記録。
        final rec = await registerRasqAccount(ref, displayName: name, column: fowColumnOf(context), onMessage: toast);
        if (rec == null || !context.mounted) return;
        await openRasqProfileSheet(context, ref, record: rec, beforeNavigate: leave);
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
                  trailing: RasqIconButton(
                    key: ValueKey('rasq.account.toggle.${r.id}'),
                    icon: expandedId == r.id ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 22,
                    tooltip: expandedId == r.id ? '操作を畳む' : 'アカウントの操作',
                    onPressed: () => ref.read(rasqAccountFowExpandedProvider.notifier).toggle(r.id),
                  ),
                  onTap: () async {
                    await ref.read(rasqAccountsProvider.notifier).select(r.id);
                    onDone();
                  },
                ),
              );
            }),
            // 折りたたみの中身 (D-291): そのアカウントの操作。開いているのは 1 つだけ。
            if (expandedId == r.id)
              Container(
                key: ValueKey('rasq.account.actions.${r.id}'),
                color: scheme.surfaceContainerLow,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (final item in itemsOf(r))
                    InkWell(
                      key: ValueKey('rasq.account.action.${r.id}.${item.value}'),
                      onTap: item.enabled ? () => act(r, item.value) : null,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(RasqSpacing.page + 40, 10, RasqSpacing.page, 10),
                        child: Text(
                          item.label,
                          style: RasqTypography.bodySmall.copyWith(color: !item.enabled ? scheme.onSurfaceVariant.withValues(alpha: 0.5) : (item.destructive ? tokens.danger : scheme.onSurface)),
                        ),
                      ),
                    ),
                ]),
              ),
            const Divider(height: 1),
          ],
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // 下のボタン (D-272): 「RASQ アカウントを追加」(作成 / 既存のアカウントにログイン)と「チャイルドセーフ」(セーフモードの設定)。
          // 「SNS アカウントを追加」は、各アカウントの ↓ のメニューへ移した。2 つは 1 行に並べる(縦に積むと一覧が狭くなり、
          // 電話の幅では処置の案内が隠れる)。
          Row(children: [
            Expanded(
              child: Builder(
                builder: (b) => FilledButton.icon(
                  key: const ValueKey('rasq.account.add'),
                  onPressed: !centralOk
                      ? null
                      : () async {
                          final box = b.findRenderObject() as RenderBox;
                          final pick = await manager.showDropdown<String>(id: 'rasq.account.add', anchor: box.localToGlobal(Offset.zero) & box.size, dense: true, items: [
                            RasqDropdownItem('新しく作成', 'create', enabled: ledger.central == null),
                            const RasqDropdownItem('既存のアカウントにログイン', 'login'),
                          ]);
                          if (!context.mounted) return;
                          if (pick == 'create') return create();
                          if (pick == 'login') {
                            leave();
                            context.push('${Routes.settings}/account-login');
                          }
                        },
                  icon: const RasqBrandIcon(size: 18),
                  label: const Text('RASQ アカウントを追加', overflow: TextOverflow.ellipsis),
                ),
              ),
            ),
            const SizedBox(width: RasqSpacing.xs),
            OutlinedButton.icon(
              key: const ValueKey('rasq.account.childSafe'),
              onPressed: () {
                leave();
                // チャイルドセーフ (D-307): 保護者(`GET /me` の roles に guardian)は見守りの画面へ、ほかは入口へ
                // (保護者の確認 / チャイルドモード / セーフモード)。
                final guardian = ref.read(orgateAccountProvider).value?.roles.contains('guardian') ?? false;
                context.push(guardian ? Routes.childSafeGuardian : Routes.childSafe);
              },
              icon: const Icon(Icons.child_care_outlined, size: 18),
              label: const Text('チャイルドセーフ'),
            ),
          ]),
          if (!centralOk)
            Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text('RASQ Central の接続先が未設定です', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
              TextButton(
                onPressed: () {
                  leave();
                  context.push('${Routes.settings}/server');
                },
                child: const Text('接続先を設定'),
              ),
            ]),
        ]),
      ),
    ]);
  }
}

/// プロフィール編集シート: 表示名(+ Central はハンドル)。Central は
/// `PATCH /me` の結果を台帳へ写す。ローカルは台帳が正本。
/// [beforeNavigate] = 画面へ移る前に呼ぶ(FOW を閉じる。FOW は画面より前に出るので、開いたままだと編集画面を覆う)。
Future<void> openRasqProfileSheet(BuildContext context, WidgetRef ref, {required RasqAccountRecord record, VoidCallback? beforeNavigate}) async {
  // Central のアカウントは、SNS のプロフィール編集と同じ作りの画面で (D-269)。この端末だけのアカウントは、表示名だけのシート。
  if (record.isCentral && record.id == ref.read(rasqAccountsProvider).value?.central?.id) {
    final router = GoRouter.of(context);
    beforeNavigate?.call();
    await router.push('${Routes.settings}/rasq-profile');
    return;
  }
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

/// RASQ アカウントのタイル (D-291): サイドバーのバンドルタイルと同じ見た目(大きいアイコン / 表示名 / @handle)。
/// 設定の「RASQについて」の最上部に置く。押すと、アカウントの FOW。
class RasqAccountTile extends ConsumerWidget {
  const RasqAccountTile({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final rasq = ref.watch(rasqAccountProvider);
    return InkWell(
      onTap: () => openRasqAccountFow(ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.md),
        child: Row(children: [
          RasqAvatar(imageUrl: rasq.avatarUrl, size: RasqSizes.avatarLg, fallbackLabel: rasq.displayName),
          const SizedBox(width: RasqSpacing.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(rasq.displayName, style: RasqTypography.title, overflow: TextOverflow.ellipsis),
              Text('@${rasq.account.handle}', style: RasqTypography.handle.copyWith(color: scheme.onSurfaceVariant), overflow: TextOverflow.ellipsis),
            ]),
          ),
          RasqIconButton(icon: Icons.more_horiz, tooltip: 'RASQ アカウント', onPressed: () => openRasqAccountFow(ref)),
        ]),
      ),
    );
  }
}
