import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// 端末ローカル通知 (D-160): 開催予約した AsTell の開始などを OS の通知に登録する。
/// 実装は `flutter_local_notifications`。テスト/未対応環境は [MemoryLocalNotifier]
/// (登録内容を覚えるだけ)に差し替える。
abstract class LocalNotifier {
  /// [at] に 1 回だけ鳴る通知を登録する。同じ [id] は上書き。登録できたら true。
  Future<bool> schedule({required int id, required String title, required String body, required DateTime at, String? payload});
  Future<void> cancel(int id);
}

/// 何も鳴らさず台帳だけ持つ(テスト / Web)。
class MemoryLocalNotifier implements LocalNotifier {
  final Map<int, ({String title, String body, DateTime at, String? payload})> scheduled = {};
  @override
  Future<bool> schedule({required int id, required String title, required String body, required DateTime at, String? payload}) async {
    scheduled[id] = (title: title, body: body, at: at, payload: payload);
    return true;
  }

  @override
  Future<void> cancel(int id) async => scheduled.remove(id);
}

/// `flutter_local_notifications` 実装。初回に初期化(権限要求含む)。時刻は UTC の
/// 絶対時刻で登録するのでタイムゾーン DB の現在地は要らない。
class FlutterLocalNotifier implements LocalNotifier {
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<bool>? _ready;

  Future<bool> _init() => _ready ??= () async {
        try {
          tzdata.initializeTimeZones();
          final ok = await _plugin.initialize(
            settings: const InitializationSettings(
              android: AndroidInitializationSettings('@mipmap/ic_launcher'),
              iOS: DarwinInitializationSettings(),
              macOS: DarwinInitializationSettings(),
              linux: LinuxInitializationSettings(defaultActionName: '開く'),
            ),
          );
          return ok ?? true;
        } catch (e) {
          debugPrint('local notifications unavailable: $e');
          return false;
        }
      }();

  static const _channel = AndroidNotificationDetails('rasq.astell', 'AsTell の開始', channelDescription: 'ブックマークした VC の開始通知', importance: Importance.high, priority: Priority.high);

  @override
  Future<bool> schedule({required int id, required String title, required String body, required DateTime at, String? payload}) async {
    if (kIsWeb || !await _init()) return false;
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
        notificationDetails: const NotificationDetails(android: _channel, iOS: DarwinNotificationDetails(), macOS: DarwinNotificationDetails(), linux: LinuxNotificationDetails()),
        // 正確なアラーム権限を要求しない(数分のずれは許容)。
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
      return true;
    } catch (e) {
      debugPrint('local notification schedule failed: $e');
      return false;
    }
  }

  @override
  Future<void> cancel(int id) async {
    if (kIsWeb || !await _init()) return;
    try {
      await _plugin.cancel(id: id);
    } catch (e) {
      debugPrint('local notification cancel failed: $e');
    }
  }
}

/// テストでは [MemoryLocalNotifier] に差し替える。
final localNotifierProvider = Provider<LocalNotifier>((ref) => kIsWeb ? MemoryLocalNotifier() : FlutterLocalNotifier());
