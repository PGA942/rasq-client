import 'dart:convert';
import '../notify/push_fcm.dart' show pushMessagingProvider, pushTokenFor;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import 'orgate_client.dart';
import 'rasq_account.dart';

/// 通知専用のアクセストークンと端末のプッシュ登録 (D-239 / Central S-014)。第 3 段階 (D-400) から口は **ORGATE-Server**
/// ([orgateClientProvider]、トークンの取り直しつき)。サーバー側のデータは移していないので、前の通知トークンは無効(作り直し)。
///
/// - 通知トークンは RASQ アカウントの端末トークン(フル権限)とは別物で、読めるのは自分宛ての通知の受信箱だけ。
///   発行 / 一覧 / 失効 / 端末登録は端末トークンで行い、受信箱は通知トークンで読む。
/// - 生のトークンは発行時に 1 度だけ返るので、端末の保存領域([notifyTokenStorageKey])に置く。
/// - 配下トークン(`parentId` つき、scopes = macro / astell)はマクロ / AsTell 共用のため(将来)。
/// - 配信は当面ダミー(APNs / FCM は未接続): サーバーは受信箱に積むだけ。アプリはテスト送信の後に受信箱を読んで確かめる。
@immutable
class NotifyToken {
  const NotifyToken({required this.id, this.parentId, this.label, this.scopes = const ['notify'], required this.createdAt, this.lastUsedAt});
  final String id;
  final String? parentId;
  final String? label;
  final List<String> scopes;
  final DateTime createdAt;
  final DateTime? lastUsedAt;
  bool get isRoot => parentId == null;

  factory NotifyToken.fromJson(Map<String, Object?> j) => NotifyToken(
        id: '${j['id']}',
        parentId: j['parentId'] as String?,
        label: j['label'] as String?,
        scopes: [for (final s in (j['scopes'] as List? ?? const [])) '$s'],
        createdAt: DateTime.tryParse('${j['createdAt']}') ?? DateTime.fromMillisecondsSinceEpoch(0),
        lastUsedAt: j['lastUsedAt'] == null ? null : DateTime.tryParse('${j['lastUsedAt']}'),
      );
}

@immutable
class PushDevice {
  const PushDevice({required this.deviceId, required this.platform, this.tokenId, required this.updatedAt});
  final String deviceId;
  final String platform;
  final String? tokenId;
  final DateTime updatedAt;
  factory PushDevice.fromJson(Map<String, Object?> j) => PushDevice(
        deviceId: '${j['deviceId']}',
        platform: '${j['platform']}',
        tokenId: j['tokenId'] as String?,
        updatedAt: DateTime.tryParse('${j['updatedAt']}') ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
}

@immutable
class NotifyOutboxItem {
  const NotifyOutboxItem({required this.id, required this.kind, required this.title, required this.body, required this.status, required this.devices, required this.createdAt});
  final String id;
  final String kind;
  final String title;
  final String body;
  final String status;
  final int devices;
  final DateTime createdAt;
  factory NotifyOutboxItem.fromJson(Map<String, Object?> j) => NotifyOutboxItem(
        id: '${j['id']}',
        kind: '${j['kind']}',
        title: '${j['title'] ?? ''}',
        body: '${j['body'] ?? ''}',
        status: '${j['status']}',
        devices: (j['devices'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse('${j['createdAt']}') ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
}

/// 端末に置く通知トークン(生の値)。`{id, token}`。
const notifyTokenStorageKey = 'rasq.notify.token.v1';

class NotifyApi {
  NotifyApi(this.client);
  final OrgateClient client;

  Future<List<NotifyToken>> tokens() async => [for (final e in await client.getList('/me/notify/tokens')) NotifyToken.fromJson((e as Map).cast<String, Object?>())];

  /// 発行。戻り値 = (情報, 生のトークン)。生のトークンはこの 1 回しか取れない。
  Future<(NotifyToken, String)> issue({String? label, List<String>? scopes, String? parentId}) async {
    final j = await client.postJson('/me/notify/tokens', {'label': ?label, 'scopes': ?scopes, 'parentId': ?parentId});
    return (NotifyToken.fromJson(j), '${j['token']}');
  }

  Future<void> revoke(String id) => client.delete('/me/notify/tokens/$id');

  Future<List<PushDevice>> devices() async => [for (final e in await client.getList('/me/notify/devices')) PushDevice.fromJson((e as Map).cast<String, Object?>())];

  Future<PushDevice> registerDevice({required String deviceId, required String platform, required String pushToken, String? tokenId}) async =>
      PushDevice.fromJson(await client.putJson('/me/notify/devices', {'deviceId': deviceId, 'platform': platform, 'pushToken': pushToken, 'tokenId': ?tokenId}));

  Future<void> unregisterDevice(String deviceId) => client.delete('/me/notify/devices/${Uri.encodeComponent(deviceId)}');

  Future<NotifyOutboxItem> sendTest({String? title, String? body}) async => NotifyOutboxItem.fromJson(await client.postJson('/me/notify/test', {'title': ?title, 'body': ?body}));

  /// 受信箱は**通知トークン**で読む。
  Future<List<NotifyOutboxItem>> outbox(String notifyToken, {DateTime? since, int limit = 30}) async => [
        for (final e in await client.withToken(() => notifyToken).getList('/notify/outbox', {'since': since?.toUtc().toIso8601String(), 'limit': '$limit'}))
          NotifyOutboxItem.fromJson((e as Map).cast<String, Object?>()),
      ];
}

final notifyApiProvider = Provider<NotifyApi?>((ref) {
  // 通知は ORGATE (D-400 / Central S-064 / ORGATE O-003)。
  final client = ref.watch(orgateClientProvider);
  return client == null ? null : NotifyApi(client);
});

/// プッシュの端末登録で使う platform(Central の語彙)。
String notifyPlatform() {
  if (kIsWeb) return 'web';
  return switch (defaultTargetPlatform) {
    TargetPlatform.iOS => 'ios',
    TargetPlatform.android => 'android',
    TargetPlatform.macOS => 'macos',
    TargetPlatform.windows => 'windows',
    _ => 'linux',
  };
}

/// ダミーのプッシュ端末トークン(APNs / FCM に繋ぐまでの仮の値)。
String dummyPushToken([Random? random]) {
  final r = random ?? Random.secure();
  return 'dummy:${base64Url.encode([for (var i = 0; i < 18; i++) r.nextInt(256)]).replaceAll('=', '')}';
}

/// 通知トークンの状態(この端末に保存した生のトークン + サーバー側の一覧 / 端末登録)。
@immutable
class NotifyState {
  const NotifyState({this.tokens = const [], this.devices = const [], this.localTokenId, this.localToken});
  final List<NotifyToken> tokens;
  final List<PushDevice> devices;

  /// この端末に保存してある通知トークン(id と生の値)。サーバー側で失効していれば捨てる。
  final String? localTokenId;
  final String? localToken;
  bool get hasLocalToken => localToken != null && tokens.any((t) => t.id == localTokenId);
}

class NotifyStore extends AsyncNotifier<NotifyState> {
  @override
  Future<NotifyState> build() async {
    final api = ref.watch(notifyApiProvider);
    final account = await ref.watch(orgateAccountProvider.future);
    if (api == null || account == null) return const NotifyState();
    final tokens = await api.tokens();
    final devices = await api.devices();
    String? id, token;
    try {
      final raw = await ref.read(sessionStorageProvider).read(notifyTokenStorageKey);
      if (raw != null) {
        final j = (jsonDecode(raw) as Map).cast<String, Object?>();
        id = j['id'] as String?;
        token = j['token'] as String?;
      }
    } catch (_) {}
    if (id != null && !tokens.any((t) => t.id == id)) {
      // サーバー側で失効済み → 端末の控えも捨てる。
      id = null;
      token = null;
      await ref.read(sessionStorageProvider).delete(notifyTokenStorageKey);
    }
    return NotifyState(tokens: tokens, devices: devices, localTokenId: id, localToken: token);
  }

  NotifyApi get _api => ref.read(notifyApiProvider)!;

  /// 通知トークンを発行してこの端末に保存し、端末をプッシュ登録する(ダミーの端末トークン)。
  Future<void> enable({String? label}) async {
    final (info, raw) = await _api.issue(label: label);
    await ref.read(sessionStorageProvider).write(notifyTokenStorageKey, jsonEncode({'id': info.id, 'token': raw}));
    final deviceId = ref.read(orgateAccountProvider.notifier).deviceId;
    // Android で FCM が使えれば、その登録トークン(D-449)。無ければダミー(受信箱だけ)。
    if (deviceId != null) await _api.registerDevice(deviceId: deviceId, platform: notifyPlatform(), pushToken: await pushTokenFor(ref.read(pushMessagingProvider)), tokenId: info.id);
    ref.invalidateSelf();
    await future;
  }

  /// 配下トークン(マクロ / AsTell 共用)を発行する。生の値を返す(呼び出し側が渡す先に渡す)。
  Future<String> issueChild(String parentId, {required List<String> scopes, String? label}) async {
    final (_, raw) = await _api.issue(label: label, scopes: scopes, parentId: parentId);
    ref.invalidateSelf();
    await future;
    return raw;
  }

  Future<void> revoke(String id) async {
    await _api.revoke(id);
    ref.invalidateSelf();
    await future;
  }

  Future<void> unregisterThisDevice() async {
    final deviceId = ref.read(orgateAccountProvider.notifier).deviceId;
    if (deviceId != null) await _api.unregisterDevice(deviceId);
    ref.invalidateSelf();
    await future;
  }

  /// テスト通知を積んで、通知トークンで受信箱から読み戻す。戻り値 = 受信箱で見つかった項目(無ければ null)。
  Future<NotifyOutboxItem?> sendTestAndRead() async {
    final st = state.value;
    final sent = await _api.sendTest();
    final token = st?.localToken;
    if (token == null) return sent;
    final items = await _api.outbox(token, limit: 10);
    return items.where((i) => i.id == sent.id).firstOrNull;
  }
}

final notifyStoreProvider = AsyncNotifierProvider<NotifyStore, NotifyState>(NotifyStore.new);
