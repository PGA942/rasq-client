import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';

import '../../l10n/l10n.dart';
import '../settings/settings_dsl.dart';

/// 通知プロファイル設定 (種別 ON/OFF)。設定エリアに保存 (D-238)。Applied client-side as a filter.
@immutable
class NotificationPrefs {
  const NotificationPrefs({this.enabled = true, this.kinds = const {}});
  final bool enabled;

  /// kind → on/off (absent = on).
  final Map<NotificationKind, bool> kinds;
  bool isOn(NotificationKind k) => kinds[k] ?? true;
  NotificationPrefs copyWith({bool? enabled, Map<NotificationKind, bool>? kinds}) => NotificationPrefs(enabled: enabled ?? this.enabled, kinds: kinds ?? this.kinds);
}

/// 保存先 (D-238): 設定エリア `notifications.prefs`(`enabled` と `kinds.<種別名>`)。
const notificationPrefsArea = 'notifications.prefs';

class NotificationPrefsStore extends Notifier<NotificationPrefs> {
  @override
  NotificationPrefs build() {
    final v = ref.watch(settingsAreaProvider(notificationPrefsArea)).value ?? const <String, Object?>{};
    return NotificationPrefs(
      enabled: v['enabled'] != false,
      kinds: {
        for (final k in NotificationKind.values)
          if (v['kinds.${k.name}'] is bool) k: v['kinds.${k.name}'] as bool,
      },
    );
  }

  void setKind(NotificationKind k, bool on) {
    state = state.copyWith(kinds: {...state.kinds, k: on});
    _write('kinds.${k.name}', on);
  }

  void setEnabled(bool on) {
    state = state.copyWith(enabled: on);
    _write('enabled', on);
  }

  /// エリアの読み込みが終わってから書く(読み込み中に書くと、後から届いた空の読み込み結果で上書きされる)。
  Future<void> _write(String key, Object? value) async {
    await ref.read(settingsAreaProvider(notificationPrefsArea).future);
    await ref.read(settingsAreaProvider(notificationPrefsArea).notifier).set(key, value);
  }
}

final notificationPrefsProvider = NotifierProvider<NotificationPrefsStore, NotificationPrefs>(NotificationPrefsStore.new);

/// Rows shown in the 通知プロファイル設定 sheet (ワイヤーフレーム順). 見出しは表示の言語 (D-484)。
List<(String, List<NotificationKind>)> notificationPrefRowsOf(AppLocalizations l) => [
      (l.notificationsPrefReaction, [NotificationKind.reaction]),
      (l.notificationsPrefRepost, [NotificationKind.repost]),
      (l.notificationsPrefQuote, [NotificationKind.quote]),
      (l.notificationsPrefAstell, [NotificationKind.vc]),
      (l.notificationsPrefTimer, [NotificationKind.timer]),
      (l.notificationsPrefPollEnded, [NotificationKind.pollEnded]),
      (l.notificationsPrefFollow, [NotificationKind.follow, NotificationKind.followRequest, NotificationKind.followAccepted]),
      (l.notificationsPrefSystem, [NotificationKind.system]),
      (l.notificationsPrefOther, [NotificationKind.reply, NotificationKind.mention, NotificationKind.listAdded, NotificationKind.other]),
    ];
