import 'dart:async';

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

  /// いますぐ出す通知 (D-415: 画面の読み取りの入口)。同じ [id] は上書き。出せたら true。
  Future<bool> show({required int id, required String title, required String body, String? payload});
  Future<void> cancel(int id);

  /// 通知をタップしたときの payload (D-415)。アプリが通知から起動したときの分も、[listenForTaps] のあとに流す。
  Stream<String> get taps;

  /// タップを受け始める(起動時に 1 回。権限は頼まない)。
  Future<void> listenForTaps();
}

/// 何も鳴らさず台帳だけ持つ(テスト / Web)。[tap] でタップを真似る。
class MemoryLocalNotifier implements LocalNotifier {
  final Map<int, ({String title, String body, DateTime at, String? payload})> scheduled = {};
  final Map<int, ({String title, String body, String? payload})> shown = {};
  final _taps = StreamController<String>.broadcast();
  @override
  Future<bool> schedule({required int id, required String title, required String body, required DateTime at, String? payload}) async {
    scheduled[id] = (title: title, body: body, at: at, payload: payload);
    return true;
  }

  @override
  Future<bool> show({required int id, required String title, required String body, String? payload}) async {
    shown[id] = (title: title, body: body, payload: payload);
    return true;
  }

  @override
  Future<void> cancel(int id) async {
    scheduled.remove(id);
    shown.remove(id);
  }

  @override
  Stream<String> get taps => _taps.stream;

  @override
  Future<void> listenForTaps() async {}

  /// 出ている通知 [id] をタップした(テスト用)。
  void tap(int id) {
    final payload = shown.remove(id)?.payload ?? scheduled.remove(id)?.payload;
    if (payload != null) _taps.add(payload);
  }
}

/// `flutter_local_notifications` 実装。初回に初期化(権限要求含む)。時刻は UTC の
/// 絶対時刻で登録するのでタイムゾーン DB の現在地は要らない。
class FlutterLocalNotifier implements LocalNotifier {
  final _plugin = FlutterLocalNotificationsPlugin();
  final _taps = StreamController<String>.broadcast();
  Future<bool>? _ready;
  Future<void>? _permission;
  bool _tzReady = false;

  // 初期化では権限を頼まない(起動時にタップを受け始めるため、D-415)。権限は初めて通知を出す / 登録するときに頼む。
  static const _darwinInit = DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false);

  Future<bool> _init() => _ready ??= () async {
        try {
          final ok = await _plugin.initialize(
            settings: const InitializationSettings(
              android: AndroidInitializationSettings('@mipmap/ic_launcher'),
              iOS: _darwinInit,
              macOS: _darwinInit,
              linux: LinuxInitializationSettings(defaultActionName: '開く'),
            ),
            onDidReceiveNotificationResponse: (r) {
              final p = r.payload;
              if (p != null && p.isNotEmpty) _taps.add(p);
            },
          );
          return ok ?? true;
        } catch (e) {
          // 起動時にタップを受け始めるときは黙る(テスト / プラグインの無い環境)。通知を出す / 登録するときに出す。
          _initError = e;
          return false;
        }
      }();

  Object? _initError;
  void _logUnavailable() => debugPrint('local notifications unavailable: $_initError');

  /// 通知の権限(iOS / macOS の許可、Android 13 以降の POST_NOTIFICATIONS)。1 度だけ頼む。
  Future<void> _ensurePermission() => _permission ??= () async {
        try {
          await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, badge: true, sound: true);
          await _plugin.resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, badge: true, sound: true);
          await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
        } catch (e) {
          debugPrint('local notification permission: $e');
        }
      }();

  /// 画面の読み取りの入口 (D-415): 音は鳴らさず、すぐ出す。
  static const _glimpseChannel = AndroidNotificationDetails('rasq.discover.glimpse', '画面の読み取り', channelDescription: 'タップすると、いま見ている画面を少しだけ読み取ります', importance: Importance.high, priority: Priority.high, playSound: false);

  @override
  Stream<String> get taps => _taps.stream;

  @override
  Future<void> listenForTaps() async {
    if (kIsWeb || !await _init()) return;
    try {
      final launch = await _plugin.getNotificationAppLaunchDetails();
      final p = launch?.notificationResponse?.payload;
      if ((launch?.didNotificationLaunchApp ?? false) && p != null && p.isNotEmpty) _taps.add(p);
    } catch (e) {
      debugPrint('local notification launch details: $e');
    }
  }

  @override
  Future<bool> show({required int id, required String title, required String body, String? payload}) async {
    if (kIsWeb) return false;
    if (!await _init()) {
      _logUnavailable();
      return false;
    }
    await _ensurePermission();
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(android: _glimpseChannel, iOS: DarwinNotificationDetails(presentSound: false), macOS: DarwinNotificationDetails(presentSound: false), linux: LinuxNotificationDetails()),
        payload: payload,
      );
      return true;
    } catch (e) {
      debugPrint('local notification show failed: $e');
      return false;
    }
  }

  /// 開始通知の音 (D-331) = ユーザー提供の目覚まし用の音源。Android は `res/raw/alarm.wav`(チャンネルの音は作った後に変えられない
  /// ので id を v2 に)、iOS / macOS は Runner に同梱した `alarm.wav`(Xcode で Runner に足す。無ければ既定の音)。
  static const _channel = AndroidNotificationDetails('rasq.astell.v2', 'ASTell の開始', channelDescription: 'ブックマークした VC の開始通知', importance: Importance.high, priority: Priority.high, sound: RawResourceAndroidNotificationSound('alarm'));
  static const _darwin = DarwinNotificationDetails(sound: 'alarm.wav');

  @override
  Future<bool> schedule({required int id, required String title, required String body, required DateTime at, String? payload}) async {
    if (kIsWeb) return false;
    if (!await _init()) {
      _logUnavailable();
      return false;
    }
    await _ensurePermission();
    try {
      if (!_tzReady) {
        tzdata.initializeTimeZones();
        _tzReady = true;
      }
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
        notificationDetails: const NotificationDetails(android: _channel, iOS: _darwin, macOS: _darwin, linux: LinuxNotificationDetails()),
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
