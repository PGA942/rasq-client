import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../app/providers.dart' show overlayManagerProvider;
import '../backend/rasq_account.dart' show centralSignedInAccountIdsProvider;
import 'rasq_accounts.dart';
import 'session_providers.dart';
import 'sns_share.dart' show SnsShareStore;
import '../l10n/l10n.dart';

/// RASQ アカウントからのログアウト / 削除で、その SNS アカウントをどうするか (D-409)。
enum RasqLogoutSns {
  /// SNS アカウントもログアウトする(既定)。端末からセッション(トークン)を消す。
  logout,

  /// 「この端末のみ」のアカウントへ移す(D-138 の前の挙動)。
  moveToLocal,
}

/// `ref.read`(WidgetRef / Ref / ProviderContainer のどれでも渡せる)。
typedef RasqProviderRead = T Function<T>(ProviderListenable<T> provider);

/// RASQ アカウント [recordId] を台帳から外し、その SNS アカウントを [sns] のとおりにする (D-409)。
///
/// Central のトークンを捨てた(`signOut` / `deleteAccount`)**あとで**呼ぶ。トークンが残っていると、SNS のログアウトが
/// 端末間共有 (D-319) と Web 版の保管庫を通って、ほかの端末のそのアカウントの SNS まで消してしまう。
///
/// - [RasqLogoutSns.logout]: そのアカウントだけが持っていた SNS セッションを端末から消す(SNS のログアウトと同じ
///   [SessionsNotifier.removeKeys])。「この端末のみ」の行にもあれば、そこからも消える。ほかの Central のアカウントの行にも
///   あるものだけは、そのアカウントのために残す(そのアカウントの行にもともとあったもの — 持ち込みではない)。
/// - [RasqLogoutSns.moveToLocal]: 「この端末のみ」へ移す。
///
/// どちらでも、ほかの Central のアカウントの行へは入れない。次に使うアカウントは [RasqAccountsNotifier.detachCentral]。
Future<void> releaseRasqAccount(RasqProviderRead read, String recordId, {required RasqLogoutSns sns}) async {
  final ledger = await read(rasqAccountsProvider.future);
  final rec = ledger.accounts.where((a) => a.id == recordId).firstOrNull;
  if (rec == null) return;
  // ほかの Central のアカウントも持っている SNS(そのアカウントのバンドルにもあった)は、そちらのために端末に残す。
  // 「この端末のみ」にもある分(作成のときに引き継いだ等)は消す — 「SNS アカウントもログアウトする」を選んだので。
  final elsewhere = {for (final a in ledger.accounts) if (a.id != recordId && a.isCentral) ...a.sessionKeys};
  final central = rec.centralAccountId;
  // その SNS はもうこの端末のこのアカウントのものではない: 端末間共有の「揃えた記録」から外す。
  if (central != null) await SnsShareStore(read(sessionStorageProvider)).forgetKnown(central, rec.sessionKeys);
  if (sns == RasqLogoutSns.logout) {
    await read(sessionsProvider.notifier).removeKeys([for (final k in rec.sessionKeys) if (!elsewhere.contains(k)) k]);
  }
  await read(rasqAccountsProvider.notifier).detachCentral(
        recordId,
        keepSessions: sns == RasqLogoutSns.moveToLocal,
        signedInCentral: read(centralSignedInAccountIdsProvider) ?? const {},
      );
}

/// ログアウト / 削除の確認 (D-409)。SNS アカウントをどうするかを選ばせる(既定は「SNS アカウントもログアウトする」)。
/// キャンセルなら null。
Future<RasqLogoutSns?> askRasqLogoutSns(
  RasqProviderRead read, {
  required String id,
  required String title,
  required String message,
  required String confirmText,
}) async {
  final pick = ValueNotifier(RasqLogoutSns.logout);
  final result = await read(overlayManagerProvider).show(RasqOverlayEntry(
    id: id,
    layer: OverlayLayer.modal,
    alignment: Alignment.center,
    semanticsLabel: title,
    builder: (context, handle) {
      final scheme = Theme.of(context).colorScheme;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Material(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: ValueListenableBuilder<RasqLogoutSns>(
              valueListenable: pick,
              builder: (context, value, _) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(message, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 8),
                Text(context.l10n.sessionLogoutSnsHeading, style: Theme.of(context).textTheme.labelMedium),
                RasqRadioListTile<RasqLogoutSns>(
                  key: ValueKey('$id.sns.logout'),
                  title: context.l10n.sessionLogoutSnsLogout,
                  subtitle: context.l10n.sessionLogoutSnsLogoutSubtitle,
                  value: RasqLogoutSns.logout,
                  groupValue: value,
                  onChanged: (v) => pick.value = v,
                ),
                RasqRadioListTile<RasqLogoutSns>(
                  key: ValueKey('$id.sns.moveToLocal'),
                  title: context.l10n.sessionLogoutSnsMoveToLocal,
                  subtitle: context.l10n.sessionLogoutSnsMoveToLocalSubtitle,
                  value: RasqLogoutSns.moveToLocal,
                  groupValue: value,
                  onChanged: (v) => pick.value = v,
                ),
                const SizedBox(height: 4),
                OverflowBar(alignment: MainAxisAlignment.end, overflowAlignment: OverflowBarAlignment.end, children: [
                  TextButton(key: ValueKey('$id.cancel'), onPressed: handle.cancel, child: Text(context.l10n.sessionCancel)),
                  TextButton(
                    key: ValueKey('$id.confirm'),
                    onPressed: () => handle.close(result: value),
                    child: Text(confirmText, style: TextStyle(color: scheme.error, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      );
    },
  ));
  pick.dispose();
  return result is RasqLogoutSns ? result : null;
}
