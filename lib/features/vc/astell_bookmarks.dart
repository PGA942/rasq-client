import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../notify/local_notifier.dart';
import '../settings/settings_dsl.dart';
import 'astell_models.dart';
import 'astell_providers.dart';

/// AsTell のブックマークと開始通知 (D-160)。どちらも storage.safe(共有領域)に
/// 置く — RASQ アカウント単位の保存で、SNS アカウントを切り替えても同じ。
/// ブックマークはルームのスナップショット(タイルをオフラインでも描ける)。
const astellBookmarksSlot = 'astell.bookmarks';
const astellRemindersSlot = 'astell.reminders';
const _area = 'storage.safe';

final astellBookmarksProvider = FutureProvider<List<AstellRoom>>((ref) async {
  final raw = (await ref.watch(settingsAreaProvider(_area).future))[astellBookmarksSlot];
  return [for (final r in (raw as List? ?? const [])) if (r is Map) AstellRoom.fromJson(r.cast<String, Object?>())];
});

final astellBookmarkedProvider = Provider.family<bool, String>((ref, id) => ref.watch(astellBookmarksProvider).value?.any((r) => r.id == id) ?? false);

/// ブックマークの保存/削除。戻り値は新しい状態(true = 保存した)。
Future<bool> toggleAstellBookmark(WidgetRef ref, AstellRoom room) async {
  final store = ref.read(settingsAreaProvider(_area).notifier);
  final current = await ref.read(astellBookmarksProvider.future);
  final has = current.any((r) => r.id == room.id);
  final next = has ? [for (final r in current) if (r.id != room.id) r] : [room, ...current];
  await store.set(astellBookmarksSlot, [for (final r in next) r.toJson()]);
  ref.invalidate(astellBookmarksProvider);
  return !has;
}

/// ブックマークのスナップショットをサーバーの今の姿で更新(取れた分だけ)。
Future<void> refreshAstellBookmarks(WidgetRef ref) async {
  final current = await ref.read(astellBookmarksProvider.future);
  if (current.isEmpty) return;
  final client = ref.read(astellClientProvider);
  final next = <AstellRoom>[];
  for (final r in current) {
    try {
      next.add(await client.room(r.id) ?? r);
    } catch (e) {
      debugPrint('astell bookmark refresh ${r.id}: $e');
      next.add(r);
    }
  }
  await ref.read(settingsAreaProvider(_area).notifier).set(astellBookmarksSlot, [for (final r in next) r.toJson()]);
  ref.invalidate(astellBookmarksProvider);
}

/// 開始通知の登録 1 件。
@immutable
class AstellReminder {
  const AstellReminder({required this.roomId, required this.title, required this.at, required this.notificationId});
  final String roomId;
  final String title;
  final DateTime at;
  final int notificationId;

  Map<String, Object?> toJson() => {'roomId': roomId, 'title': title, 'at': at.toUtc().toIso8601String(), 'notificationId': notificationId};
  static AstellReminder? tryParse(Object? v) {
    if (v is! Map) return null;
    final at = DateTime.tryParse(v['at'] as String? ?? '');
    final id = v['roomId'] as String?;
    if (at == null || id == null) return null;
    return AstellReminder(roomId: id, title: v['title'] as String? ?? '', at: at.toLocal(), notificationId: (v['notificationId'] as num?)?.toInt() ?? astellNotificationId(id));
  }
}

/// OS 通知の id(32bit、ルーム id のハッシュ)。
int astellNotificationId(String roomId) => roomId.hashCode & 0x7fffffff;

final astellRemindersProvider = FutureProvider<List<AstellReminder>>((ref) async {
  final raw = (await ref.watch(settingsAreaProvider(_area).future))[astellRemindersSlot];
  final list = [for (final r in (raw as List? ?? const [])) ?AstellReminder.tryParse(r)];
  list.sort((a, b) => a.at.compareTo(b.at));
  return list;
});

final astellRemindedProvider = Provider.family<bool, String>((ref, id) => ref.watch(astellRemindersProvider).value?.any((r) => r.roomId == id) ?? false);

enum AstellReminderResult { registered, removed, unavailable, notScheduled }

/// 開始通知の登録/解除 (D-160): 開催予定時刻に OS のローカル通知を 1 回鳴らす。
Future<AstellReminderResult> toggleAstellReminder(WidgetRef ref, AstellRoom room) async {
  final store = ref.read(settingsAreaProvider(_area).notifier);
  final notifier = ref.read(localNotifierProvider);
  final current = await ref.read(astellRemindersProvider.future);
  final existing = current.where((r) => r.roomId == room.id).firstOrNull;
  if (existing != null) {
    await notifier.cancel(existing.notificationId);
    await store.set(astellRemindersSlot, [for (final r in current) if (r.roomId != room.id) r.toJson()]);
    ref.invalidate(astellRemindersProvider);
    return AstellReminderResult.removed;
  }
  final at = room.scheduledAt;
  if (at == null || !room.isScheduled) return AstellReminderResult.notScheduled;
  final id = astellNotificationId(room.id);
  final ok = await notifier.schedule(id: id, title: appL10n.vcReminderNotificationTitle, body: appL10n.vcReminderNotificationBody(room.ownerDisplayName, room.title), at: at, payload: 'rasq://astell/${Uri.encodeComponent(room.id)}');
  if (!ok) return AstellReminderResult.unavailable;
  await store.set(astellRemindersSlot, [...current.map((r) => r.toJson()), AstellReminder(roomId: room.id, title: room.title, at: at, notificationId: id).toJson()]);
  ref.invalidate(astellRemindersProvider);
  return AstellReminderResult.registered;
}

/// ルームが消えていても登録を解除できる口(通知画面の「解除」)。
final localNotifierCancelProvider = Provider<Future<void> Function(AstellReminder)>((ref) => (r) async {
      await ref.read(localNotifierProvider).cancel(r.notificationId);
      final current = await ref.read(astellRemindersProvider.future);
      await ref.read(settingsAreaProvider(_area).notifier).set(astellRemindersSlot, [for (final x in current) if (x.roomId != r.roomId) x.toJson()]);
      ref.invalidate(astellRemindersProvider);
    });
