import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/router.dart';
import '../backend/notify_api.dart';
import '../backend/rasq_account.dart';
import 'local_notifier.dart';
import '../l10n/l10n.dart';

/// Android のプッシュ通知 (D-449): Firebase Cloud Messaging で受ける。
///
/// - 送る側は ORGATE(`ORGATE_PUSH_MODE=fcm`、FCM HTTP v1)。端末は今までどおり `PUT /me/notify/devices` で登録し、
///   `pushToken` にダミーの代わりに **FCM の登録トークン**を入れる(トークンが変われば登録し直す)。
/// - Firebase の設定は `google-services.json` / gradle のプラグインを使わず、ビルド時の `--dart-define` で渡す
///   (`RASQ_FCM_API_KEY` / `RASQ_FCM_APP_ID_ANDROID` / `RASQ_FCM_SENDER_ID` / `RASQ_FCM_PROJECT_ID`)。どれかが無ければ使わない
///   (今までどおりダミーのトークン = 受信箱だけ)。iOS(APNs)/ デスクトップ / Web はまだ使わない。
/// - アプリを開いている間に届いたものは、端末の通知(チャンネル `rasq_default`)で出す(FCM は前面では出さない)。
///   通知を押すと通知のページへ。

/// ビルド時の Firebase の設定(Android)。揃っていなければ null。
FirebaseOptions? fcmOptionsFromEnvironment() {
  const apiKey = String.fromEnvironment('RASQ_FCM_API_KEY');
  const appId = String.fromEnvironment('RASQ_FCM_APP_ID_ANDROID');
  const sender = String.fromEnvironment('RASQ_FCM_SENDER_ID');
  const project = String.fromEnvironment('RASQ_FCM_PROJECT_ID');
  if (apiKey.isEmpty || appId.isEmpty || sender.isEmpty || project.isEmpty) return null;
  return const FirebaseOptions(apiKey: apiKey, appId: appId, messagingSenderId: sender, projectId: project);
}

/// プッシュの受け口(テストで差し替える)。
abstract interface class PushMessaging {
  /// 端末の登録トークン(取れなければ null)。初めてなら通知の権限も頼む。
  Future<String?> token();
  Stream<String> get tokenRefresh;

  /// アプリを開いている間に届いた通知(見出し / 本文 / data)。
  Stream<({String title, String body, Map<String, String> data})> get foreground;

  /// 通知を押してアプリが開いた / 前面に来た。
  Stream<Map<String, String>> get opened;
}

/// Android の通知チャンネル(ORGATE が `android.notification.channel_id` に入れる)。
const pushChannelId = 'rasq_default';

class FcmPushMessaging implements PushMessaging {
  FcmPushMessaging(this.options);
  final FirebaseOptions options;
  Future<FirebaseMessaging?>? _ready;

  Future<FirebaseMessaging?> _init() => _ready ??= () async {
        try {
          await Firebase.initializeApp(options: options);
          // 背景で届いた通知が使うチャンネルを先に作っておく。
          await FlutterLocalNotificationsPlugin()
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
              ?.createNotificationChannel(AndroidNotificationChannel(pushChannelId, appL10n.notifyPushChannelName, description: appL10n.notifyPushChannelDescription, importance: Importance.high));
          return FirebaseMessaging.instance;
        } catch (e) {
          debugPrint('fcm: unavailable: $e');
          return null;
        }
      }();

  @override
  Future<String?> token() async {
    final m = await _init();
    if (m == null) return null;
    try {
      await m.requestPermission();
      return await m.getToken();
    } catch (e) {
      debugPrint('fcm: token: $e');
      return null;
    }
  }

  @override
  Stream<String> get tokenRefresh => Stream.fromFuture(_init()).asyncExpand((m) => m?.onTokenRefresh ?? const Stream<String>.empty());

  @override
  Stream<({String title, String body, Map<String, String> data})> get foreground => Stream.fromFuture(_init()).asyncExpand((m) => m == null
      ? const Stream.empty()
      : FirebaseMessaging.onMessage.map((r) => (title: r.notification?.title ?? r.data['title']?.toString() ?? 'RASQ', body: r.notification?.body ?? r.data['body']?.toString() ?? '', data: {for (final e in r.data.entries) e.key: '${e.value}'})));

  @override
  Stream<Map<String, String>> get opened => Stream.fromFuture(_init()).asyncExpand((m) async* {
        if (m == null) return;
        final first = await m.getInitialMessage();
        if (first != null) yield {for (final e in first.data.entries) e.key: '${e.value}'};
        yield* FirebaseMessaging.onMessageOpenedApp.map((r) => {for (final e in r.data.entries) e.key: '${e.value}'});
      });
}

/// この端末のプッシュの受け口。Android で Firebase の設定があるときだけ。
final pushMessagingProvider = Provider<PushMessaging?>((ref) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
  final options = fcmOptionsFromEnvironment();
  return options == null ? null : FcmPushMessaging(options);
});

/// プッシュの端末トークン: FCM が使えればその登録トークン、無ければダミー(受信箱だけ)。
Future<String> pushTokenFor(PushMessaging? push) async => await push?.token() ?? dummyPushToken();

/// 通知のペイロードの印(端末の通知を押したら通知のページへ)。
const pushNotificationPayload = 'rasq.push';

/// 起動したら繋いでおく: トークンが変われば登録し直す / 前面で届いたら端末の通知 / 押したら通知のページ。
final pushBridgeProvider = Provider<void>((ref) {
  final push = ref.watch(pushMessagingProvider);
  if (push == null) return;
  final subs = <StreamSubscription<Object?>>[
    push.tokenRefresh.listen((t) async {
      // 通知を受けると決めた端末(通知トークンを持っている)だけ登録し直す。
      final state = ref.read(notifyStoreProvider).value;
      final deviceId = ref.read(orgateAccountProvider.notifier).deviceId;
      final api = ref.read(notifyApiProvider);
      if (state == null || !state.hasLocalToken || deviceId == null || api == null) return;
      try {
        await api.registerDevice(deviceId: deviceId, platform: notifyPlatform(), pushToken: t, tokenId: state.localTokenId);
      } catch (e) {
        debugPrint('fcm: re-register: $e');
      }
    }),
    push.foreground.listen((m) {
      unawaited(ref.read(localNotifierProvider).show(id: (m.data['id'] ?? '${m.title}${m.body}').hashCode & 0x7fffffff, title: m.title, body: m.body, payload: pushNotificationPayload));
    }),
    push.opened.listen((_) => unawaited(ref.read(routerProvider).push(Routes.notifications))),
  ];
  ref.onDispose(() {
    for (final s in subs) {
      unawaited(s.cancel());
    }
  });
});
