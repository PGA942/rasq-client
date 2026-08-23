import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';

/// 通知プロファイル設定 (種別 ON/OFF). In-memory for now; persisted with
/// settings in the next batch. Applied client-side as a filter.
@immutable
class NotificationPrefs {
  const NotificationPrefs({this.enabled = true, this.kinds = const {}});
  final bool enabled;

  /// kind → on/off (absent = on).
  final Map<NotificationKind, bool> kinds;
  bool isOn(NotificationKind k) => kinds[k] ?? true;
  NotificationPrefs copyWith({bool? enabled, Map<NotificationKind, bool>? kinds}) => NotificationPrefs(enabled: enabled ?? this.enabled, kinds: kinds ?? this.kinds);
}

class NotificationPrefsStore extends Notifier<NotificationPrefs> {
  @override
  NotificationPrefs build() => const NotificationPrefs();
  void setKind(NotificationKind k, bool on) => state = state.copyWith(kinds: {...state.kinds, k: on});
  void setEnabled(bool on) => state = state.copyWith(enabled: on);
}

final notificationPrefsProvider = NotifierProvider<NotificationPrefsStore, NotificationPrefs>(NotificationPrefsStore.new);

/// Rows shown in the 通知プロファイル設定 sheet (ワイヤーフレーム順).
const notificationPrefRows = <(String, List<NotificationKind>)>[
  ('リアクションを通知する', [NotificationKind.reaction]),
  ('リノートを通知する', [NotificationKind.repost]),
  ('引用を通知する', [NotificationKind.quote]),
  ('ASTellを通知する', [NotificationKind.vc]),
  ('タイマー付きブックマークを通知する', [NotificationKind.timer]),
  ('投票の完了を通知する', [NotificationKind.pollEnded]),
  ('フォローを通知する', [NotificationKind.follow, NotificationKind.followRequest, NotificationKind.followAccepted]),
  ('その他の通知を配信する', [NotificationKind.reply, NotificationKind.mention, NotificationKind.listAdded, NotificationKind.other]),
];
