import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';

import '../../session/session_providers.dart';

/// 通知を「どこまで見たか」(D-557)。SNS アカウントごとに、見た通知のうちいちばん新しい時刻を端末に持つ。
///
/// Misskey は通知ごとの既読(`isRead`)を返さなくなった(通知が Redis に移った版から)ので、通知の `read` だけを見ると
/// ずっと未読(青いハイライト)のままになっていた。いまは **`read` が true か、見たところより前**なら既読とする。
@immutable
class NotificationSeenState {
  const NotificationSeenState({this.ready = false, this.byAccount = const {}});

  /// 端末から読み終えたか(読み終える前は、見たところが無いのか分からない)。
  final bool ready;

  /// アカウントのキー(`AccountId.key`)→ 見たところ。
  final Map<String, DateTime> byAccount;

  DateTime? of(String accountKey) => byAccount[accountKey];
}

/// 未読か: SNS が既読と言っていなくて、見たところより新しい。
bool isNotificationUnread(NotificationItem n, DateTime? seen) => !n.read && (seen == null || n.createdAt.isAfter(seen));

class NotificationSeen extends Notifier<NotificationSeenState> {
  static const storageKey = 'notifications.seen.v1';

  @override
  NotificationSeenState build() {
    _restore();
    return const NotificationSeenState();
  }

  Future<void> _restore() async {
    var map = <String, DateTime>{};
    try {
      final raw = await ref.read(sessionStorageProvider).read(storageKey);
      if (raw != null) {
        final j = jsonDecode(raw);
        if (j is Map) {
          for (final e in j.entries) {
            final at = DateTime.tryParse('${e.value}');
            if (at != null) map['${e.key}'] = at;
          }
        }
      }
    } catch (e) {
      debugPrint('notification seen: $e');
    }
    // 読んでいる間に見たところを進めていたら、新しい方を残す。
    for (final e in state.byAccount.entries) {
      final old = map[e.key];
      if (old == null || e.value.isAfter(old)) map[e.key] = e.value;
    }
    state = NotificationSeenState(ready: true, byAccount: map);
  }

  /// [accountKey] の通知を [at] まで見た(前より新しいときだけ進める)。
  Future<void> markSeen(String accountKey, DateTime at) async {
    final old = state.byAccount[accountKey];
    if (old != null && !at.isAfter(old)) return;
    final next = {...state.byAccount, accountKey: at};
    state = NotificationSeenState(ready: state.ready, byAccount: next);
    try {
      await ref.read(sessionStorageProvider).write(storageKey, jsonEncode({for (final e in next.entries) e.key: e.value.toUtc().toIso8601String()}));
    } catch (e) {
      debugPrint('notification seen: $e');
    }
  }
}

final notificationSeenProvider = NotifierProvider<NotificationSeen, NotificationSeenState>(NotificationSeen.new);

/// いちばん新しい通知の時刻(無ければ null)。
DateTime? newestNotificationAt(Iterable<NotificationItem> items) {
  DateTime? out;
  for (final n in items) {
    if (out == null || n.createdAt.isAfter(out)) out = n.createdAt;
  }
  return out;
}
