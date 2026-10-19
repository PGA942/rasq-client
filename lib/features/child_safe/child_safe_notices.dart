import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart' show routerProvider;
import '../../l10n/l10n.dart';
import '../../notify/central_inbox.dart' show CentralNotice;
import '../plugins/slot_plugins.dart' show rootMessengerKeyProvider;
import 'child_safe_providers.dart';
import 'guardian_screen.dart' show childSafeChildDetailProvider, childSafeGuardianProvider;

/// `child_safe` の知らせ (D-309) の受け手([CentralInbox] が、新しく届いた分を古い順に渡す)。
///
/// Central が積むもの(`docs/API.md` チャイルドセーフ「知らせ」): 子へ = 設定が済んだ / 変わった・見守りが終わった。
/// 親へ = 保護者の確認が済んだ・端末がつながった / 子の端末が入った・24 時間たっても子の端末が新しい版を受け取っていない。
///
/// - どちらでも、まず [ChildSafeController.onNotification] で `GET /me/child-safe` を取り直す(子 = 署名を確かめて
///   当てはめ、ack まで。保護者 = 自分の確認の状態)。
/// - **子**(取り直す前か後に見守られている): いちばん新しい知らせの題をトーストに出す。
/// - **保護者**: 子の一覧(`GET /me/child-safe/guardian`)と子ごとの画面を取り直し、題と本文をトーストに出す(「見る」で保護者の画面へ)。
Future<void> handleChildSafeNotices(Ref ref, List<CentralNotice> notices) async {
  if (notices.isEmpty) return;
  final wasChild = ref.read(childSafeProvider).value?.managed == true;
  await ref.read(childSafeProvider.notifier).onNotification('child_safe');
  final isChild = wasChild || ref.read(childSafeProvider).value?.managed == true;
  final latest = notices.last;
  final l = appL10n;
  final more = notices.length > 1 ? l.childSafeNoticeMore(notices.length - 1) : '';
  final messenger = ref.read(rootMessengerKeyProvider).currentState;
  if (isChild) {
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(key: const ValueKey('childSafe.notice'), content: Text('${latest.title.isEmpty ? l.childSafeNoticeRefreshed : latest.title}$more')));
    return;
  }
  ref.invalidate(childSafeGuardianProvider);
  ref.invalidate(childSafeChildDetailProvider);
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      key: const ValueKey('childSafe.guardianNotice'),
      content: Text([latest.title, if (latest.body.isNotEmpty) latest.body].join('\n') + more),
      action: SnackBarAction(label: l.childSafeNoticeView, onPressed: () => ref.read(routerProvider).push('/child-safe/guardian')),
    ));
}
