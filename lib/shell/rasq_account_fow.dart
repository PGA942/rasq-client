import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart' show AccountSession;

import '../app/navigation.dart';
import '../app/providers.dart';
import '../app/router.dart';
import '../backend/notify_api.dart';
import '../backend/orgate_client.dart';
import '../backend/rasq_account.dart';
import '../session/rasq_account_logout.dart';
import '../session/sanctions.dart';
import '../features/onboarding/rasq_register_screen.dart' show openRasqAccountCreation;
import '../features/notifications/notifications_screen.dart';
import '../features/plugins/slot_plugins.dart' show rootMessengerKeyProvider;

/// RASQ アカウントの選択/編集 FOW (D-138: サイドバー右上の … から)。
///
/// - アカウント選択部: 投稿タイルのユーザー名/アイコン部分と同じ行
///   ([RasqUserRow] = アバター + 表示名 + `@handle ● rasq`)。左端に通知数の
///   バッジ、右端の … でドロップダウン(ログアウト / アカウント設定 /
///   プロフィール編集 / 通知設定)。タップで切り替え。
/// - 下部: 「アカウントを新規作成」「ログイン」(Central に繋がる構成のとき。それぞれの画面へそのまま、D-419 → D-425)と
///   「チャイルドセーフ」。
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
          child: Text('${entry.category} / ${entry.level}${entry.note == null ? '' : ' — ${entry.note}'}\n${rasqDetail(ctx, '運営の担当者が読んで、受理なら処置が解除されます。', '運営(rasq-judge)の担当者が読んで、受理なら処置が解除されます。自動判定は通りません。')}', style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant)),
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

    // そのアカウントの操作は、**そのアカウントに切り替えてから**行う (D-316): 開く画面(アカウントページ / プロフィール /
    // セキュリティ / 削除)は、いまの Central のアカウントのトークンで話すので、切り替えずに開くと別のアカウントの中身になる。
    Future<void> useAccount(RasqAccountRecord r) async {
      if (ref.read(currentRasqAccountProvider)?.id == r.id) return;
      await ref.read(rasqAccountsProvider.notifier).select(r.id);
      try {
        await ref.read(orgateAccountProvider.future);
      } catch (_) {}
    }

    Future<void> act(RasqAccountRecord r, String pick) async {
      if (!context.mounted) return;
      // ログアウトだけは切り替えずに、そのアカウントから出る。
      if (pick != 'logout') await useAccount(r);
      if (!context.mounted) return;
      switch (pick) {
        case 'addSns':
          leave();
          context.push(Routes.login);
        case 'allSettings':
          leave();
          context.push(Routes.settings);
        case 'page':
          final handle = ref.read(currentCentralHandleProvider) ?? r.handle;
          if (handle == null || handle.isEmpty) return;
          // 幅の広い画面では第3カラムに開く (D-425)。FOW を閉じる前に開く(閉じると context が使えなくなる)。
          context.pushRasqAccount(handle);
          leave();
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
          // SNS アカウントをどうするか (D-409)。既定は「SNS アカウントもログアウトする」。ほかの RASQ アカウントへは移さない。
          final sns = await askRasqLogoutSns(
            ref.read,
            id: 'rasq.account.logout',
            title: 'RASQ アカウントからログアウト',
            message: 'この端末から RASQ アカウントを外します。',
            confirmText: 'ログアウト',
          );
          if (sns == null || !context.mounted) return;
          // 台帳が変わると、この FOW が作り直されることがある: コンテナから読む。
          final read = ProviderScope.containerOf(context, listen: false).read;
          // そのアカウントのトークンだけを捨てる(ほかの RASQ アカウントのログインは残る。D-316)。SNS はトークンを捨ててから。
          await ref.read(orgateAccountProvider.notifier).signOut(accountId: r.centralAccountId);
          await releaseRasqAccount(read, r.id, sns: sns);
          toast(sns == RasqLogoutSns.logout ? 'RASQ アカウントと、その SNS アカウントからログアウトしました' : 'RASQ アカウントからログアウトしました。SNS アカウントは「この端末のみ」に移しました');
        case 'delete':
          // アカウント削除 (D-241 / S-015)。学習へのデータ提供の撤回と、提供済みデータの削除も一緒に始まる
          // (「別に撤回しない限り残る」にはしない = ストアのアカウント削除要件)。
          // 切り替えたはずのアカウントと違う(ログインが切れている)なら、消さない。
          if (ref.read(orgateAccountProvider).value?.id != r.centralAccountId) {
            toast('このアカウントに、もう一度ログインしてから削除してください');
            return;
          }
          // メールが確認済みのアカウントは、確認コードが要る (S-019) → セキュリティの画面で。
          if (ref.read(orgateAccountProvider).value?.emailVerified == true) {
            if (!context.mounted) return;
            leave();
            context.push('${Routes.settings}/security');
            toast('削除には、メールの確認コードが要ります。「アカウントの削除」から進めてください');
            return;
          }
          // SNS アカウントをどうするか (D-409)。確認コードが要るアカウントは、セキュリティの画面で選ぶ(ここで 2 度聞かない)。
          final sns = await askRasqLogoutSns(
            ref.read,
            id: 'rasq.account.delete',
            title: 'RASQ アカウントを削除',
            message: 'サーバー上のプロフィール、アカウントバンドル、同期した設定、レビューとブックマーク、ASTell のルームと共有、通知トークン、同意の記録を削除します。'
                '「アルゴリズムとコミュニティへの貢献」に同意していた場合は、提供の停止と提供済みデータの削除も同時に始まります。\n'
                '元に戻せません。各 SNS 上のアカウントと投稿は消えません。',
            confirmText: '削除する',
          );
          if (sns == null || !context.mounted) return;
          final read = ProviderScope.containerOf(context, listen: false).read;
          try {
            await ref.read(orgateAccountProvider.notifier).deleteAccount();
            await releaseRasqAccount(read, r.id, sns: sns);
            ref.invalidate(notifyStoreProvider);
            toast('RASQ アカウントを削除しました');
          } on OrgateException catch (e) {
            toast('削除できませんでした: ${e.message}');
          }
        default:
          break;
      }
    }

    // 新規作成 (D-419): オンボーディング v2 の ①(ユーザー名・パスワード・年齢)→ ②(規約・チャイルドセーフ)→ 登録 のページ。
    // 前は D-405 の登録ページを開き、しかも**台帳に Central のアカウントがあると「新しく作成」を押せなかった**(D-316 からは
    // ログアウトしても行が残るので、一度でも作った端末では作れなかった)。いまのアカウントのトークンがあると作らずにそれを返す
    // 作り(`createAccount`)も直した。FOW とサイドバーは閉じ、作れたら元の画面へ戻ってお知らせを出す。
    Future<void> create() async {
      final router = ref.read(routerProvider);
      final messenger = ref.read(rootMessengerKeyProvider);
      // FOW を閉じると ref は使えなくなるので、コンテナから読む。
      final read = ProviderScope.containerOf(context, listen: false).read;
      leave();
      void say(String m) => messenger.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(m)));
      final rec = await openRasqAccountCreation(router, read, onMessage: say);
      if (rec != null) say('RASQ アカウント @${rec.handle ?? ''} を作成しました');
    }

    // ログイン (D-419 → D-425): パスワード + メールのコード(2 段階)の画面へ、そのまま。FOW とサイドバーは閉じる。
    void login() {
      final router = ref.read(routerProvider);
      leave();
      router.push('${Routes.settings}/account-login');
    }

    final sanctions = ref.watch(rasqSanctionsProvider).value ?? RasqSanctions.none;
    // この端末がトークンを持っていない Central のアカウント(ログインが切れた / 前の版で上書きされた)には「ログインが必要」(D-316)。
    final signedIn = ref.watch(centralSignedInAccountIdsProvider);
    bool needsLogin(RasqAccountRecord r) => centralOk && signedIn != null && r.isCentral && !signedIn.contains(r.centralAccountId);
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
                  subtitle: '${r.kind.label} ・ SNS $snsCount件${isCurrent ? ' ・ 使用中' : ''}${needsLogin(r) ? ' ・ ログインが必要' : ''}',
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
                    final relogin = needsLogin(r);
                    final router = ref.read(routerProvider);
                    final messenger = ref.read(rootMessengerKeyProvider);
                    await ref.read(rasqAccountsProvider.notifier).select(r.id);
                    onDone();
                    // トークンが無ければ、そのアカウントでログインし直す画面へ(FOW は閉じたので、ルーターから)。
                    if (relogin) {
                      onNavigate?.call();
                      router.push('${Routes.settings}/account-login');
                      messenger.currentState?.showSnackBar(SnackBar(content: Text('@${r.handle ?? ''} に、もう一度ログインしてください')));
                    }
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
          // 下のボタン (D-272 → D-419 → D-425): 「アカウントを新規作成」「ログイン」(選択肢を挟まず、それぞれの画面へ)と
          // 「チャイルドセーフ」(セーフモードの設定)。「SNS アカウントを追加」は、各アカウントの ↓ のメニューへ移した。
          // 3 つは 1 行に並べる(縦に積むと一覧が狭くなり、電話の幅では処置の案内が隠れる)。狭い幅では
          // 「チャイルドセーフ」はアイコンだけ(長押し / 読み上げで名前)。
          LayoutBuilder(builder: (context, box) {
            final compact = box.maxWidth < 440;
            final childSafe = OutlinedButton.icon(
              key: const ValueKey('rasq.account.childSafe'),
              style: compact ? OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12), minimumSize: const Size(44, 40)) : null,
              onPressed: () {
                leave();
                // チャイルドセーフ (D-307): 保護者(`GET /me` の roles に guardian)は見守りの画面へ、ほかは入口へ
                // (保護者の確認 / チャイルドモード / セーフモード)。
                final guardian = ref.read(orgateAccountProvider).value?.roles.contains('guardian') ?? false;
                context.push(guardian ? Routes.childSafeGuardian : Routes.childSafe);
              },
              icon: const Icon(Icons.child_care_outlined, size: 18),
              label: compact ? const SizedBox.shrink() : const Text('チャイルドセーフ'),
            );
            return Row(children: [
              Expanded(
                flex: 3,
                child: FilledButton.icon(
                  key: const ValueKey('rasq.account.create'),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
                  onPressed: !centralOk ? null : create,
                  icon: const RasqBrandIcon(size: 18),
                  label: const Text('アカウントを新規作成', overflow: TextOverflow.ellipsis),
                ),
              ),
              const SizedBox(width: RasqSpacing.xs),
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  key: const ValueKey('rasq.account.login'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
                  onPressed: !centralOk ? null : login,
                  child: const Text('ログイン', overflow: TextOverflow.ellipsis),
                ),
              ),
              const SizedBox(width: RasqSpacing.xs),
              compact ? Tooltip(message: 'チャイルドセーフ', child: Semantics(label: 'チャイルドセーフ', child: childSafe)) : childSafe,
            ]);
          }),
          if (!centralOk)
            Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text('RASQ サーバーの接続先が未設定です', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
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
  if (record.isCentral && record.id == ref.read(currentRasqAccountProvider)?.id) {
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
            record.isCentral ? 'RASQ のサーバー上のプロフィールを更新します。' : 'この端末だけのアカウントです。ハンドルは RASQ アカウントを作成すると付きます。',
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
