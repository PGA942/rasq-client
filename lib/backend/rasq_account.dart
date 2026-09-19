import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart' show AccountSession;

import '../session/session_providers.dart';
import '../session/session_storage.dart';
import '../session/rasq_accounts.dart';
import 'orgate_client.dart';

/// RASQ アカウント (D-087) — アカウントバンドルの顔。
///
/// サーバーが立つまでは `rasqAccountProvider` が「最初のログインアカウントの
/// プロフィールを流用」する仮実装だった。ここが本物の口:
///
/// - **端末発行** — `POST /auth/device`。パスワードもメールも要らない。
///   端末が持つ安定 ID を送ると、再インストール後も同じアカウントへ戻る。
/// - **プロフィール** — `GET/PATCH /me`。
/// - **バンドル** — `PUT /me/sns-accounts`。ログイン済み SNS アカウントの
///   一覧をサーバーへ写す。**トークンは送らない**(CONTRACT §3: トークンは
///   ホストのセキュアストレージにのみ置く)。
///
/// 接続先が未設定(`orgateBaseUrlProvider == null`)なら何もしない —
/// アプリはサーバー無しでも従来どおり動く。

@immutable
class RasqAccount {
  const RasqAccount({required this.id, required this.handle, required this.displayName, this.avatarUrl, this.createdAt, this.email, this.emailVerified = false, this.emailPending, this.hasPassword = false, this.roles = const []});

  final String id;
  final String handle;
  final String displayName;
  final Uri? avatarUrl;
  final DateTime? createdAt;

  /// メールアドレス (S-019)。自分にだけ見える。[emailPending] = 確認待ちの新しいメール。
  final String? email;
  final bool emailVerified;
  final String? emailPending;

  /// パスワードが設定済みか(別の端末からログインできるか)。
  final bool hasPassword;

  /// 役割(`developer` / `reviewer`)。
  final List<String> roles;

  factory RasqAccount.fromJson(Map<String, Object?> j) => RasqAccount(
        id: j['id'] as String? ?? j['accountId'] as String? ?? '',
        handle: j['handle'] as String? ?? '',
        displayName: j['displayName'] as String? ?? '',
        avatarUrl: switch (j['avatarUrl']) { final String u when u.isNotEmpty => Uri.tryParse(u), _ => null },
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
        email: j['email'] as String?,
        emailVerified: j['emailVerified'] == true,
        emailPending: j['emailPending'] as String?,
        hasPassword: j['hasPassword'] == true,
        roles: [for (final r in j['roles'] as List? ?? const []) '$r'],
      );

  /// サイドバーのバンドルタイルが使う形。ハンドルはインスタンスなしの素の
  /// `@handle` で出す(個別アカウント行の `handle@instance` と区別する)。
  UserSummary toUserSummary() => UserSummary(
        id: 'rasq:$id',
        account: AccountId(kind: SnsKind.other, instance: 'rasq', handle: handle),
        displayName: displayName.isEmpty ? handle : displayName,
        avatarUrl: avatarUrl,
      );
}

/// セキュアストレージに置く端末資格情報。
@immutable
class _DeviceCredentials {
  const _DeviceCredentials({required this.deviceId, this.token, this.accountId});
  final String deviceId;
  final String? token;
  final String? accountId;

  Map<String, Object?> toJson() => {'deviceId': deviceId, 'token': token, 'accountId': accountId};
  factory _DeviceCredentials.fromJson(Map<String, Object?> j) =>
      _DeviceCredentials(deviceId: j['deviceId'] as String, token: j['token'] as String?, accountId: j['accountId'] as String?);
}

/// 現在の RASQ アカウントトークンの置き場。
///
/// [OrgateClient] は呼び出しのたびにここを読み、[OrgateAccountNotifier] が
/// 端末登録の結果を書き込む。**プロバイダー経由で受け渡さない**のは、
/// クライアント → トークン → アカウント → クライアント の循環依存に
/// なるため。依存を持たない箱にしておけば向きが 1 方向に保たれる。
class OrgateTokenHolder {
  String? token;
}

final orgateTokenHolderProvider = Provider<OrgateTokenHolder>((ref) => OrgateTokenHolder());

/// RASQ Central 上のアカウントの状態 (D-133 → D-138)。
///
/// - 接続先未設定なら常に null。
/// - **端末登録は自動では行わない**(D-138: オンボーディングか RASQ
///   アカウント FOW の「作成」で [createAccount] を呼んだときだけ)。保存済み
///   トークンがあれば `GET /me` で復元する。
/// - [signOut] でトークンを捨てる(SNS セッションは端末に残る)。
class OrgateAccountNotifier extends AsyncNotifier<RasqAccount?> {
  static const storageKey = 'rasq.orgate.device.v1';

  _DeviceCredentials? _creds;

  /// 現在のトークン(build 完了前は null)。
  String? get token => _creds?.token;

  /// 端末 id(`POST /auth/device` と同じ。プッシュの端末登録 (D-239) でも使う)。
  String? get deviceId => _creds?.deviceId;

  /// 直近の登録が既存のアカウントへの復帰だったか(`POST /auth/device` の `restored`、S-015)。
  bool get lastRestored => _lastRestored;
  bool _lastRestored = false;

  void _publishToken() => ref.read(orgateTokenHolderProvider).token = _creds?.token;

  @override
  Future<RasqAccount?> build() async {
    // 接続先が変わったら作り直す(開発中にローカルサーバーへ向け直す)。
    final client = ref.watch(centralClientProvider);
    if (client == null) return null;

    final storage = ref.read(sessionStorageProvider);
    _creds = await _loadOrCreateCredentials(storage);
    _publishToken();

    // まだ作っていない(トークンなし)なら何もしない — 作るのはユーザーの
    // 選択 (D-138)。
    if (_creds!.token == null) return null;
    try {
      return RasqAccount.fromJson(await client.getJson('/me'));
    } on OrgateException catch (e) {
      // トークンが失効していたら 1 回だけ取り直す(端末側で消えた場合など)。
      if (e.code.code != '401') rethrow;
      debugPrint('rasq account: token rejected, restoring the device');
      try {
        // **既存のアカウントへ戻るだけ**(D-241 / S-015 `restoreOnly`)。サーバーにアカウントが無い
        // (削除した / サーバーを作り直した)なら新規には作らない — 新規の発行は同意の FOW のあとだけ。
        await _registerDevice(client, storage, restoreOnly: true);
      } on OrgateException catch (e2) {
        if (e2.code.code != '404') rethrow;
        _creds = _DeviceCredentials(deviceId: _creds!.deviceId);
        await storage.write(storageKey, jsonEncode(_creds!.toJson()));
        _publishToken();
        return null;
      }
      return RasqAccount.fromJson(await client.getJson('/me'));
    }
  }

  Future<_DeviceCredentials> _loadOrCreateCredentials(SessionStorage storage) async {
    final raw = await storage.read(storageKey);
    if (raw != null) {
      try {
        return _DeviceCredentials.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
      } catch (e) {
        debugPrint('rasq account: corrupt device credentials, starting fresh: $e');
      }
    }
    // 端末 ID は 1 度だけ作って持ち続ける。再インストールで消えれば新規
    // アカウントになるが、サーバーが端末を識別する唯一の手掛かりなので
    // トークンとは別に保持する。
    final rnd = Random.secure();
    final id = base64Url.encode(List<int>.generate(18, (_) => rnd.nextInt(256))).replaceAll('=', '');
    final creds = _DeviceCredentials(deviceId: id);
    await storage.write(storageKey, jsonEncode(creds.toJson()));
    return creds;
  }

  Future<void> _registerDevice(OrgateClient client, SessionStorage storage, {String? displayName, bool restoreOnly = false}) async {
    // 表示名の初期値は、指定が無ければ既にログインしている SNS アカウントから借りる。
    final first = ref.read(sessionsProvider).value?.sessions.firstOrNull;
    final name = displayName ?? first?.displayName;
    final res = await client.postJson('/auth/device', {
      'deviceId': _creds!.deviceId,
      if (name != null && name.isNotEmpty) 'displayName': name,
      if (restoreOnly) 'restoreOnly': true,
    });
    _creds = _DeviceCredentials(
      deviceId: _creds!.deviceId,
      token: res['token'] as String?,
      accountId: res['accountId'] as String?,
    );
    _lastRestored = res['restored'] == true;
    await storage.write(storageKey, jsonEncode(_creds!.toJson()));
    _publishToken();
  }

  /// RASQ アカウントを作る(端末登録 → `GET /me`)。既にあればそれを返す。
  /// 接続先が無ければ null(呼び出し側が案内する)。
  Future<RasqAccount?> createAccount({String? displayName}) async {
    final client = ref.read(centralClientProvider);
    if (client == null) return null;
    final storage = ref.read(sessionStorageProvider);
    _creds ??= await _loadOrCreateCredentials(storage);
    if (_creds!.token == null) {
      await _registerDevice(client, storage, displayName: displayName);
    }
    final account = RasqAccount.fromJson(await client.getJson('/me'));
    state = AsyncData(account);
    return account;
  }

  /// Central からログアウト: トークンを捨て、端末 ID だけ残す(再作成すると
  /// 同じアカウントへ戻れる — API.md `POST /auth/device` の再発行)。
  Future<void> signOut() async {
    final storage = ref.read(sessionStorageProvider);
    _creds ??= await _loadOrCreateCredentials(storage);
    _creds = _DeviceCredentials(deviceId: _creds!.deviceId);
    await storage.write(storageKey, jsonEncode(_creds!.toJson()));
    _publishToken();
    state = const AsyncData(null);
  }

  /// RASQ アカウントを削除する (D-241 / S-015 `DELETE /me?confirm=<handle>`)。サーバー上の本人に
  /// 紐づくデータがすべて消え、学習へのデータ提供の撤回も同時に始まる。端末はトークンを捨てる
  /// (端末 id は残るが、消したアカウントへは戻れない = 次に作ると新しいアカウント)。
  /// [code] = メールが確認済みのアカウントで要る、`account.delete` の確認コード (S-019)。
  Future<void> deleteAccount({String? code}) async {
    final client = ref.read(centralClientProvider);
    final account = state.value;
    if (client == null || account == null) return;
    await client.delete('/me', {'confirm': account.handle, 'code': ?code});
    await signOut();
  }

  /// この端末の安定 ID(ログインのとき、端末ごとに 1 本のトークンにするために渡す)。
  Future<String> ensureDeviceId() async => (_creds ??= await _loadOrCreateCredentials(ref.read(sessionStorageProvider))).deviceId;

  /// `GET /me` を取り直す(メールの確認 / パスワードの設定のあと)。
  Future<RasqAccount?> refresh() async {
    final client = ref.read(centralClientProvider);
    if (client == null || _creds?.token == null) return state.value;
    final account = RasqAccount.fromJson(await client.getJson('/me'));
    state = AsyncData(account);
    return account;
  }

  /// 既存のアカウントへのログイン (S-019): `/auth/login` / `/auth/login/email/confirm` の応答のトークンを、この端末のものにする。
  Future<RasqAccount?> adoptLogin(Map<String, Object?> res) async {
    final client = ref.read(centralClientProvider);
    final token = res['token'] as String?;
    if (client == null || token == null || token.isEmpty) return null;
    final storage = ref.read(sessionStorageProvider);
    _creds ??= await _loadOrCreateCredentials(storage);
    _creds = _DeviceCredentials(deviceId: _creds!.deviceId, token: token, accountId: res['accountId'] as String?);
    _lastRestored = true;
    await storage.write(storageKey, jsonEncode(_creds!.toJson()));
    _publishToken();
    return refresh();
  }

  Future<void> updateProfile({String? handle, String? displayName, String? avatarUrl}) async {
    final client = ref.read(centralClientProvider);
    if (client == null) return;
    final res = await client.patchJson('/me', {
      'handle': ?handle,
      'displayName': ?displayName,
      'avatarUrl': ?avatarUrl,
    });
    state = AsyncData(RasqAccount.fromJson(res));
  }

  /// ログイン済み SNS アカウントをバンドルへ写す。**トークンは送らない。**
  /// サーバーが知るのは「どのアカウントが束ねられているか」だけ。
  ///
  /// [prune] = false なら足すだけで、サーバーにだけあるアカウントは消さない(登録の FOW で
  /// 「置き換えない」を選んだアカウント、D-241)。
  Future<void> syncBundle(List<AccountSession> sessions, {bool prune = true}) async {
    final client = ref.read(centralClientProvider);
    if (client == null || state.value == null) return;
    final wanted = {for (final s in sessions) s.account.key: s};
    try {
      final existing = await client.getList('/me/sns-accounts');
      final existingKeys = {
        for (final e in existing)
          if (e is Map) e['accountKey'] as String? ?? '',
      };
      for (final s in wanted.values) {
        await client.putJson('/me/sns-accounts', {
          'kind': s.account.kind.name,
          'instance': s.account.instance,
          'handle': s.account.handle,
          'pluginId': s.pluginId,
          if (s.displayName != null) 'displayName': s.displayName,
          if (s.avatarUrl != null) 'avatarUrl': s.avatarUrl.toString(),
        });
      }
      if (!prune) return;
      for (final gone in existingKeys.where((k) => k.isNotEmpty && !wanted.containsKey(k))) {
        await client.delete('/me/sns-accounts/${Uri.encodeComponent(gone)}');
      }
    } on OrgateException catch (e) {
      // バンドル同期は付随機能。失敗してもアプリは動き続ける。
      debugPrint('rasq account: bundle sync failed: $e');
    }
  }
}

final orgateAccountProvider = AsyncNotifierProvider<OrgateAccountNotifier, RasqAccount?>(OrgateAccountNotifier.new);

/// ログイン済みアカウントが変わるたびにバンドルを同期する。アプリ起動時に
/// 1 度 watch しておけば以後は自動で追随する。
final orgateBundleSyncProvider = Provider<void>((ref) {
  final sessions = ref.watch(sessionsProvider).value?.sessions ?? const <AccountSession>[];
  final account = ref.watch(orgateAccountProvider).value;
  if (account == null || sessions.isEmpty) return;
  final prune = ref.watch(currentRasqAccountProvider)?.pruneBundle ?? true;
  // build 中の書き込みを避けるため次のマイクロタスクへ逃がす。
  Future.microtask(() => ref.read(orgateAccountProvider.notifier).syncBundle(sessions, prune: prune));
});
