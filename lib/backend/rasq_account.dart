import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart' show AccountSession;

import '../session/session_providers.dart';
import '../session/session_storage.dart';
import '../session/rasq_accounts.dart';
import '../session/sns_share.dart' show SnsShareStore;
import 'orgate_client.dart';
import 'rasq_account_page_api.dart';

/// RASQ アカウント (D-087) — アカウントバンドルの顔。
///
/// サーバーが立つまでは `rasqAccountProvider` が「最初のログインアカウントの
/// プロフィールを流用」する仮実装だった。ここが本物の口:
///
/// - **端末発行** — ORGATE-Server の `POST /auth/device`(D-398: ログインは ORGATE、公開プロフィールは Central)。
///   パスワードもメールも要らない。端末が持つ安定 ID を送ると、再インストール後も同じアカウントへ戻る。
///   応答は**アクセストークン**(短命の JWT。Central と ORGATE の両方へ Bearer で渡す)と**リフレッシュトークン**
///   (ORGATE の `POST /auth/refresh` にだけ渡す)。アクセストークンが切れたら([OrgateTokenHolder.refresh])取り直す。
/// - **プロフィール** — Central の `GET/PATCH /me`。パスワードの有無 / メールアドレスは ORGATE の `GET /me` から足す。
/// - **バンドル** — `PUT /me/sns-accounts`。ログイン済み SNS アカウントの
///   一覧をサーバーへ写す。**トークンは送らない**(CONTRACT §3: トークンは
///   ホストのセキュアストレージにのみ置く)。
///
/// 接続先が未設定(`orgateBaseUrlProvider == null`)なら何もしない —
/// アプリはサーバー無しでも従来どおり動く。

@immutable
class RasqAccount {
  const RasqAccount({required this.id, required this.handle, required this.displayName, this.avatarUrl, this.createdAt, this.email, this.emailVerified = false, this.emailPending, this.hasPassword = false, this.roles = const [], this.bio = '', this.bannerUrl, this.location = '', this.birthday = '', this.links = const [], this.showLinksOnSnsProfiles = true, this.keybase, this.termsAccepted, this.termsMissing = const []});

  final String id;
  final String handle;
  final String displayName;
  final Uri? avatarUrl;

  /// いまの版の利用規約を承諾しているか (D-371 / S-053)。null = サーバーが返さない(古いサーバー)。false = 同意待ち
  /// (AsTell・購入・預託・学習への提供が使えない)。
  final bool? termsAccepted;

  /// 足りないもの: `terms` / `privacy` / `age` / `guardian`。
  final List<String> termsMissing;
  final DateTime? createdAt;

  /// メールアドレス (S-019)。自分にだけ見える。[emailPending] = 確認待ちの新しいメール。
  final String? email;
  final bool emailVerified;
  final String? emailPending;

  /// パスワードが設定済みか(別の端末からログインできるか)。
  final bool hasPassword;

  /// 役割(`developer` / `reviewer`)。
  final List<String> roles;

  /// プロフィールの項目 (S-020)。[birthday] = `YYYY-MM-DD` か、年を伏せた `MM-DD`。[links] は 8 組まで。
  final String bio;
  final Uri? bannerUrl;
  final String location;
  final String birthday;
  final List<({String label, String url})> links;

  /// 「SNS のプロフィールにも、つないだアカウントを出す」(D-312)。既定は出す。切ると、誰かがアプリで
  /// この人の SNS のプロフィールを見ても、RASQ アカウントとほかのアカウントは出ない(アカウントページのタイルはそのまま)。
  final bool showLinksOnSnsProfiles;

  /// 確かめた Keybase (D-313)。公開ページにも出る。
  final RasqKeybase? keybase;

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
        bio: j['bio'] as String? ?? '',
        bannerUrl: switch (j['bannerUrl']) { final String u when u.isNotEmpty => Uri.tryParse(u), _ => null },
        location: j['location'] as String? ?? '',
        birthday: j['birthday'] as String? ?? '',
        links: [for (final l in j['links'] as List? ?? const []) if (l is Map) (label: '${l['label'] ?? ''}', url: '${l['url'] ?? ''}')],
        showLinksOnSnsProfiles: j['showLinksOnSnsProfiles'] != false,
        keybase: RasqKeybase.fromJson(j['keybase']),
        termsAccepted: j['terms'] is Map ? (j['terms'] as Map)['accepted'] == true : null,
        termsMissing: [if (j['terms'] is Map) for (final m in ((j['terms'] as Map)['missing'] as List? ?? const [])) '$m'],
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

/// セキュアストレージに置く端末資格情報 (D-316)。
///
/// 保存の形は `{"deviceId", "tokens": {"<accountId>": "<access>"}, "refresh": {"<accountId>": "<refresh>"}, "currentAccountId"}`。
/// **RASQ アカウントごとに 1 組のトークン**を持つ(ORGATE の `/auth/login` はアカウントと端末の組ごとに 1 つのセッションを
/// 出すので、ぶつからない。D-398)。
/// 前の形 `{"deviceId", "token", "accountId"}`(端末に 1 本だけ)は、読むときにそのまま移す。アカウント id が
/// 無かった古いトークンは、いったん空の id で持ち、`GET /me` で分かった id に付け直す。
@immutable
class _DeviceCredentials {
  const _DeviceCredentials({required this.deviceId, this.tokens = const {}, this.refresh = const {}, this.currentAccountId});
  final String deviceId;

  /// RASQ アカウント id → そのアカウントのアクセストークン。
  final Map<String, String> tokens;

  /// RASQ アカウント id → そのアカウントのリフレッシュトークン(ORGATE にだけ渡す)。
  final Map<String, String> refresh;

  /// 最後に使っていた Central のアカウント(台帳に Central のアカウントが 1 つも無い端末は、これを使う)。
  final String? currentAccountId;

  String? tokenOf(String? accountId) => accountId == null ? null : tokens[accountId];

  String? refreshOf(String? accountId) => accountId == null ? null : refresh[accountId];

  /// そのアカウントのトークンを足す / 替える(最後に使ったアカウントにもする)。[refreshToken] が無ければ前のものを残す。
  _DeviceCredentials withToken(String accountId, String token, {String? refreshToken}) => _DeviceCredentials(
        deviceId: deviceId,
        tokens: {...tokens, accountId: token},
        refresh: {...refresh, if (refreshToken != null && refreshToken.isNotEmpty) accountId: refreshToken},
        currentAccountId: accountId,
      );

  _DeviceCredentials withoutToken(String accountId) => _DeviceCredentials(
        deviceId: deviceId,
        tokens: {for (final e in tokens.entries) if (e.key != accountId) e.key: e.value},
        refresh: {for (final e in refresh.entries) if (e.key != accountId) e.key: e.value},
        currentAccountId: currentAccountId == accountId ? null : currentAccountId,
      );

  _DeviceCredentials withCurrent(String? accountId) => _DeviceCredentials(deviceId: deviceId, tokens: tokens, refresh: refresh, currentAccountId: accountId);

  Map<String, Object?> toJson() => {'deviceId': deviceId, 'tokens': tokens, 'refresh': refresh, 'currentAccountId': currentAccountId};

  factory _DeviceCredentials.fromJson(Map<String, Object?> j) {
    final deviceId = j['deviceId'] as String;
    if (j['tokens'] is Map) {
      return _DeviceCredentials(
        deviceId: deviceId,
        tokens: {for (final e in (j['tokens'] as Map).entries) if (e.value is String && (e.value as String).isNotEmpty) '${e.key}': e.value as String},
        refresh: {for (final e in (j['refresh'] as Map? ?? const {}).entries) if (e.value is String && (e.value as String).isNotEmpty) '${e.key}': e.value as String},
        currentAccountId: j['currentAccountId'] as String?,
      );
    }
    // 前の形(端末に 1 本だけ)。
    final token = j['token'] as String?;
    if (token == null || token.isEmpty) return _DeviceCredentials(deviceId: deviceId);
    final id = j['accountId'] as String? ?? '';
    return _DeviceCredentials(deviceId: deviceId, tokens: {id: token}, currentAccountId: id);
  }
}

/// 台帳 (D-138) から見た「いま使う Central のアカウント」(D-316)。
///
/// - 台帳の「いま」が Central のアカウント → その id。
/// - 台帳の「いま」が「この端末のみ」で、台帳に Central のアカウントがある → `''`(Central には、どのアカウントでも入っていない)。
/// - 台帳がまだ読めていない / 台帳に Central のアカウントが 1 つも無い → null(端末に残っている、最後に使ったトークンを使う。
///   台帳より前の資格情報だけがある端末も、これで今までどおり動く)。
String? centralTargetOf(RasqAccountsState? ledger) {
  if (ledger == null || !ledger.accounts.any((a) => a.isCentral)) return null;
  final cur = ledger.current;
  return cur != null && cur.isCentral ? (cur.centralAccountId ?? '') : '';
}

/// アクセストークン(JWT)の期限(`exp`)。JWT でなければ null。署名は確かめない(確かめるのはサーバー)。
DateTime? accessTokenExpiry(String? token) {
  final parts = token?.split('.');
  if (parts == null || parts.length != 3) return null;
  try {
    final claims = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
    final exp = claims is Map ? claims['exp'] : null;
    return exp is num ? DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000) : null;
  } catch (_) {
    return null;
  }
}

/// 現在の RASQ アカウントトークンの置き場。
///
/// [OrgateClient] は呼び出しのたびにここを読み、[OrgateAccountNotifier] が
/// 端末登録の結果を書き込む。**プロバイダー経由で受け渡さない**のは、
/// クライアント → トークン → アカウント → クライアント の循環依存に
/// なるため。依存を持たない箱にしておけば向きが 1 方向に保たれる。
///
/// [accountId] = いま使っている Central のアカウント(D-316。決まるたびに知らせる)。Web 版の保管庫は、
/// [orgateAccountProvider] を listen せずにこれを見る(listen すると、保存先 → アカウント → 保存先 の循環になる)。
class OrgateTokenHolder extends ChangeNotifier {
  /// いまのアクセストークン(ORGATE が出す JWT。Central と ORGATE の両方へ Bearer で渡す)。
  String? token;

  /// アクセストークンを取り直す口(ORGATE の `POST /auth/refresh`)。[OrgateAccountNotifier] が入れる。
  /// 戻り = 新しいアクセストークン(取り直せなければ null = ログインし直し)。
  Future<String?> Function()? refresher;

  Future<String?>? _refreshing;

  /// 取り直す(同時に何本来ても 1 回だけ。リフレッシュトークンは回るので、並べて送ると後のものが外れる)。
  Future<String?> refresh() {
    final r = refresher;
    if (r == null) return Future.value(null);
    return _refreshing ??= r().whenComplete(() => _refreshing = null);
  }

  /// WebSocket など、401 で取り直せない口の前に: 期限まで 60 秒を切っていれば先に取り直す。
  Future<void> ensureFresh() async {
    final exp = accessTokenExpiry(token);
    if (exp != null && exp.difference(DateTime.now()) < const Duration(seconds: 60)) await refresh();
  }

  String? get accountId => _accountId;
  String? _accountId;
  set accountId(String? v) {
    if (v == _accountId) return;
    _accountId = v;
    notifyListeners();
  }
}

final orgateTokenHolderProvider = Provider<OrgateTokenHolder>((ref) => OrgateTokenHolder());

/// RASQ Central 上のアカウントの状態 (D-133 → D-138 → D-316)。
///
/// - 接続先未設定なら常に null。
/// - **端末登録は自動では行わない**(D-138: オンボーディングか RASQ
///   アカウント FOW の「作成」で [createAccount] を呼んだときだけ)。保存済み
///   トークンがあれば `GET /me` で復元する。
/// - **Central のアカウントごとにトークンを持つ** (D-316)。どれを使うかは台帳 (D-138) の「いま」で決まる
///   ([centralTargetOf])。台帳で別の Central のアカウントを選ぶと、ここが作り直され、使うトークンも切り替わる
///   (このプロバイダーを watch しているもの = 保管庫 / バンドルの同期 / チャイルドセーフ / 通知 / アカウントページも、一緒に切り替わる)。
/// - [signOut] でそのアカウントのトークンだけを捨てる(ほかのアカウントのトークンと、SNS セッションは端末に残る)。
class OrgateAccountNotifier extends AsyncNotifier<RasqAccount?> {
  static const storageKey = 'rasq.orgate.device.v1';

  _DeviceCredentials? _creds;

  /// いま使っている Central のアカウント id(null = どれにも入っていない)。
  String? _activeId;

  /// 直近に `GET /me` を取ったときの口 / トークンと、その結果。台帳を読み終えたときなどの作り直しで、同じなら取り直さない。
  ({OrgateClient client, String token, RasqAccount account})? _fetched;

  /// ORGATE の `GET /me`(本人だけの情報: パスワードの有無 / メールアドレス、D-398)。Central の `/me` に重ねて読む。
  Map<String, Object?> _credentials = const {};

  /// ログイン / 端末の発行 / 取り直し / 削除を受ける ORGATE の口 (D-398)。テストでは Central と同じモックになる。
  OrgateClient? get _identity => ref.read(orgateClientProvider);

  /// Central の `/me`(や `PATCH /me` の応答)に、ORGATE の本人だけの情報を重ねて読む。
  RasqAccount _account(Map<String, Object?> central) => RasqAccount.fromJson({...central, ..._credentials});

  /// ログインの応答(ORGATE の `TokenResponse`、D-398)から、アクセストークンとリフレッシュトークン。
  static ({String access, String? refresh})? _tokensOf(Map<String, Object?> res) {
    final access = res['accessToken'] as String?;
    if (access == null || access.isEmpty) return null;
    return (access: access, refresh: res['refreshToken'] as String?);
  }

  /// 現在のトークン(build 完了前は null)。
  String? get token => _creds?.tokenOf(_activeId);

  /// その Central のアカウントのトークン(この端末でログインしていなければ null)。
  String? tokenFor(String accountId) => _creds?.tokenOf(accountId);

  /// この端末がトークンを持っている Central のアカウント(台帳の行に「ログインが必要」を出すのに使う)。
  Set<String> get signedInAccountIds => {...?_creds?.tokens.keys};

  /// 端末 id(`POST /auth/device` と同じ。プッシュの端末登録 (D-239) でも使う)。
  String? get deviceId => _creds?.deviceId;

  /// 直近の登録が既存のアカウントへの復帰だったか(`POST /auth/device` の `restored`、S-015)。
  bool get lastRestored => _lastRestored;
  bool _lastRestored = false;

  void _publishToken() => ref.read(orgateTokenHolderProvider).token = token;

  /// プロフィールを保存したあとの `/me` を状態にする(作り直しで古い控えに戻らないよう、控えも差し替える)。
  void _setAccount(Map<String, Object?> central) {
    final account = _account(central);
    final f = _fetched;
    if (f != null && f.account.id == account.id) _fetched = (client: f.client, token: f.token, account: account);
    state = AsyncData(account);
  }

  /// アクセストークンを取り直す(ORGATE の `POST /auth/refresh`)。リフレッシュトークンも回る(新しいものを保存する)。
  /// 取り直せなければ(セッションが消された / 期限切れ)そのアカウントのトークンを捨てて null。
  Future<String?> _refreshAccess() async {
    final identity = _identity;
    final id = _activeId;
    final refresh = _creds?.refreshOf(id);
    if (identity == null || id == null || refresh == null) return null;
    final storage = ref.read(sessionStorageProvider);
    try {
      final res = await identity.withToken(() => null).postJson('/auth/refresh', {'refreshToken': refresh});
      final t = _tokensOf(res);
      if (t == null) return null;
      _creds = _creds!.withToken(id, t.access, refreshToken: t.refresh);
      await _save(storage);
      _publishToken();
      return t.access;
    } on OrgateException catch (e) {
      if (e.code.code != '401' && e.code.code != 'session_revoked') rethrow;
      debugPrint('rasq account: refresh token rejected, signing out of $id');
      _creds = _creds!.withoutToken(id);
      await _save(storage);
      _publishToken();
      return null;
    }
  }

  Future<void> _save(SessionStorage storage) => storage.write(storageKey, jsonEncode(_creds!.toJson()));

  @override
  Future<RasqAccount?> build() async {
    // 接続先が変わったら作り直す(開発中にローカルサーバーへ向け直す)。
    final client = ref.watch(centralClientProvider);
    // 台帳の「いま」が変わったら作り直す (D-316)。台帳の読み込みは待たない(Web 版の保管庫は、台帳の読み込みの中から
    // このプロバイダーを待つので、ここで台帳を待つと互いに待ち合う)。読み終えたら、もう一度ここへ来る。
    final target = ref.watch(rasqAccountsProvider.select((s) => centralTargetOf(s.value)));
    // いまのアカウントが決まったら、箱にも書く(Web 版の保管庫が見る)。
    listenSelf((_, next) {
      ref.read(orgateTokenHolderProvider).accountId = next.value?.id;
    });
    if (client == null) return null;

    final storage = ref.read(sessionStorageProvider);
    _creds = await _loadOrCreateCredentials(storage);
    _activeId = switch (target) { null => _creds!.currentAccountId, '' => null, final t => t };
    if (target != null && target.isNotEmpty && _creds!.currentAccountId != target && _creds!.tokens.containsKey(target)) {
      _creds = _creds!.withCurrent(target);
      await _save(storage);
    }
    _publishToken();
    ref.read(orgateTokenHolderProvider).refresher = _refreshAccess;

    // まだ作っていない(トークンなし)なら何もしない — 作るのはユーザーの
    // 選択 (D-138)。台帳で選んだアカウントのトークンが無ければ、ログインし直してもらう。
    final token = this.token;
    if (token == null) {
      _fetched = null;
      return null;
    }
    final f = _fetched;
    if (f != null && identical(f.client, client) && f.token == token && f.account.id == _activeId) return f.account;
    try {
      return await _fetchMe(client, storage, legacy: target == null);
    } on OrgateException catch (e) {
      // アクセストークンが切れていたら、まずリフレッシュトークンで取り直す(D-398)。それも駄目なら、この端末で作った
      // アカウントへ戻るだけ(端末側で消えた場合など)。
      if (e.code.code != '401') rethrow;
      if (await ref.read(orgateTokenHolderProvider).refresh() != null) return _fetchMe(client, storage, legacy: target == null);
      debugPrint('rasq account: token rejected, restoring the device');
      if (!await _restoreDevice(storage)) return null;
      return _fetchMe(client, storage, legacy: target == null);
    }
  }

  /// いまのトークンで `GET /me`。**そのトークンに縛った口**で取る(途中で切り替わっても、別のアカウントの答えと混ざらない)。
  /// [legacy] = 台帳に Central のアカウントが無い端末: 保存していたアカウント id が違っていれば(前の形で id が無かったなど)、
  /// 分かった id にトークンを付け直す。
  Future<RasqAccount> _fetchMe(OrgateClient client, SessionStorage storage, {bool legacy = false}) async {
    final token = this.token!;
    final central = await client.withToken(() => token).getJson('/me');
    await _loadCredentials(token);
    final account = _account(central);
    if (legacy && _activeId != account.id && account.id.isNotEmpty) {
      final refresh = _creds!.refreshOf(_activeId ?? '');
      _creds = _creds!.withoutToken(_activeId ?? '').withToken(account.id, token, refreshToken: refresh);
      _activeId = account.id;
      await _save(storage);
    }
    _fetched = (client: client, token: token, account: account);
    // 台帳の行の名前 / アイコンも、Central のプロフィールに合わせる(使っていないアカウントの行は、台帳の値で出すので)。
    Future.microtask(() {
      if (ref.mounted) ref.read(rasqAccountsProvider.notifier).syncCentralProfile(account.id, handle: account.handle, displayName: account.displayName, avatarUrl: account.avatarUrl);
    });
    return account;
  }

  /// ORGATE の `GET /me`(パスワードの有無 / メールアドレス)。取れなければ前のまま(画面は Central の値で出る)。
  Future<void> _loadCredentials(String token) async {
    final identity = _identity;
    if (identity == null) return;
    try {
      final me = await identity.withToken(() => token).getJson('/me');
      _credentials = {for (final k in const ['hasPassword', 'email', 'emailVerified', 'emailPending']) if (me.containsKey(k)) k: me[k]};
    } catch (e) {
      debugPrint('rasq account: ORGATE /me unavailable: $e');
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

  Future<Map<String, Object?>> _postDevice(OrgateClient client, {String? displayName, bool restoreOnly = false, Map<String, Object?>? consents}) {
    // 表示名の初期値は、指定が無ければ既にログインしている SNS アカウントから借りる。
    final first = ref.read(sessionsProvider).value?.sessions.firstOrNull;
    final name = displayName ?? first?.displayName;
    return client.withToken(() => null).postJson('/auth/device', {
      'deviceId': _creds!.deviceId,
      if (name != null && name.isNotEmpty) 'displayName': name,
      if (restoreOnly) 'restoreOnly': true,
      'consents': ?consents,
    });
  }

  /// 保存していたトークンが 401: **既存のアカウントへ戻るだけ**(D-241 / S-015 `restoreOnly`)。サーバーにアカウントが無い
  /// (削除した / サーバーを作り直した)なら新規には作らない — 新規の発行は同意の FOW のあとだけ。
  /// 戻れるのは**この端末で作ったアカウント**なので、戻った先が使っていたアカウントと違えば(パスワードでログインした
  /// アカウントのトークンが切れた)、それは使わない。どちらの場合も、切れたトークンは捨てて false(ログインし直してもらう)。
  Future<bool> _restoreDevice(SessionStorage storage) async {
    final stale = _activeId;
    final identity = _identity;
    try {
      if (identity == null) throw OrgateException(ErrorCode.http(404), 'ORGATE is not configured');
      final res = await _postDevice(identity, restoreOnly: true);
      final t = _tokensOf(res);
      final accountId = res['accountId'] as String? ?? '';
      if (t != null && (stale == null || stale.isEmpty || stale == accountId)) {
        _creds = (stale == null ? _creds! : _creds!.withoutToken(stale)).withToken(accountId, t.access, refreshToken: t.refresh);
        _activeId = accountId;
        _lastRestored = res['restored'] == true;
        await _save(storage);
        _publishToken();
        return true;
      }
    } on OrgateException catch (e) {
      if (e.code.code != '404') rethrow;
    }
    if (stale != null) _creds = _creds!.withoutToken(stale);
    await _save(storage);
    _publishToken();
    _fetched = null;
    return false;
  }

  /// RASQ アカウントを作る(端末登録 → `GET /me`)。いま使っているアカウントがあればそれを返す。
  /// 接続先が無ければ null(呼び出し側が案内する)。作ったアカウントのトークンは、すぐに使い始める
  /// (登録の同意の記録 / パスワードの設定は、台帳へ載せる前にこのトークンで送る)。
  /// [consents] = 登録の承諾 (D-371 / S-053)。サーバーはアカウントの作成と同じ処理で残し、版が違えば作成ごと失敗する
  /// (`409 terms_version`、トークンは受け取らない)。
  Future<RasqAccount?> createAccount({String? displayName, Map<String, Object?>? consents}) async {
    final client = ref.read(centralClientProvider);
    final identity = _identity;
    if (client == null || identity == null) return null;
    final storage = ref.read(sessionStorageProvider);
    _creds ??= await _loadOrCreateCredentials(storage);
    if (token == null) {
      // 発行は ORGATE。ORGATE が Central に公開プロフィールの行を作り、登録の承諾も Central が確かめて残す (D-398)。
      final res = await _postDevice(identity, displayName: displayName, consents: consents);
      final t = _tokensOf(res);
      if (t == null) throw OrgateException(ErrorCode.http(502), 'ORGATE がトークンを返しませんでした');
      final id = res['accountId'] as String? ?? '';
      _creds = _creds!.withToken(id, t.access, refreshToken: t.refresh);
      _activeId = id;
      _lastRestored = res['restored'] == true;
      await _save(storage);
      _publishToken();
    }
    final account = await _fetchMe(client, storage, legacy: true);
    state = AsyncData(account);
    return account;
  }

  /// Central からログアウト: そのアカウント([accountId]、省けばいま使っているもの)のトークンを捨てる。端末 ID と、
  /// ほかのアカウントのトークンは残す(再作成すると同じアカウントへ戻れる — API.md `POST /auth/device` の再発行)。
  Future<void> signOut({String? accountId}) async {
    final storage = ref.read(sessionStorageProvider);
    _creds ??= await _loadOrCreateCredentials(storage);
    final id = accountId ?? _activeId ?? state.value?.id;
    // ORGATE のセッションも消す(失敗しても、端末のトークンは捨てる。アクセストークンは寿命まで Central で通るが、
    // リフレッシュトークンが消えるので取り直せない)。
    final access = _creds!.tokenOf(id);
    final identity = _identity;
    if (access != null && identity != null) {
      try {
        await identity.withToken(() => access).postJson('/auth/logout', const {});
      } catch (e) {
        // 届かなくても / 応答が変でも、端末のトークンは捨てる(ログアウトはここで止めない)。
        debugPrint('rasq account: logout on ORGATE failed: $e');
      }
    }
    if (id != null) _creds = _creds!.withoutToken(id);
    await _save(storage);
    if (id == null || id == _activeId || id == state.value?.id) {
      _fetched = null;
      _publishToken();
      state = const AsyncData(null);
    }
  }

  /// RASQ アカウントを削除する (D-241 / S-015 `DELETE /me?confirm=<handle>`)。サーバー上の本人に
  /// 紐づくデータがすべて消え、学習へのデータ提供の撤回も同時に始まる。端末はトークンを捨てる
  /// (端末 id は残るが、消したアカウントへは戻れない = 次に作ると新しいアカウント)。
  /// [code] = メールが確認済みのアカウントで要る、`account.delete` の確認コード (S-019)。
  Future<void> deleteAccount({String? code}) async {
    // 削除の入口は ORGATE (D-398)。ORGATE が Central の公開側の削除も呼ぶ。
    final identity = _identity;
    final account = state.value;
    final t = token;
    if (identity == null || account == null || t == null) return;
    await identity.withToken(() => t).delete('/me', {'confirm': account.handle, 'code': ?code});
    _creds = _creds!.withoutToken(account.id); // セッションはもう無い(signOut のログアウトは送らない)。
    await signOut(accountId: account.id);
  }

  /// この端末の安定 ID(ログインのとき、端末ごとに 1 本のトークンにするために渡す)。
  Future<String> ensureDeviceId() async => (_creds ??= await _loadOrCreateCredentials(ref.read(sessionStorageProvider))).deviceId;

  /// `GET /me` を取り直す(メールの確認 / パスワードの設定のあと)。
  Future<RasqAccount?> refresh() async {
    final client = ref.read(centralClientProvider);
    if (client == null || token == null) return state.value;
    final account = await _fetchMe(client, ref.read(sessionStorageProvider));
    state = AsyncData(account);
    return account;
  }

  /// 既存のアカウントへのログイン (S-019 / D-316): `/auth/login` / `/auth/login/email/confirm` / チャイルドセーフの
  /// ログインの応答のトークンを、**そのアカウントのトークンとして**足し(ほかのアカウントのトークンは残す)、台帳に載せて
  /// いまのアカウントにする。
  ///
  /// **いまの RASQ アカウントの SNS セッションは引き継がない**(引き継ぐと、名前は新しいアカウントなのに中身は前のアカウント
  /// のまま、になる)。代わりに、そのアカウントのバンドル(Central にある SNS アカウントの一覧)のうち、この端末にもログインが
  /// あるものをそのアカウントに入れる。残りは SNS のログイン画面に「このアカウントの SNS アカウント」として出る。
  /// バンドルは置き換えない(ほかの端末でつないだぶんを、この端末に無いからといって消さない)。
  Future<RasqAccount?> adoptLogin(Map<String, Object?> res) async {
    final client = ref.read(centralClientProvider);
    final t = _tokensOf(res);
    if (client == null || t == null) return null;
    final token = t.access;
    final storage = ref.read(sessionStorageProvider);
    _creds ??= await _loadOrCreateCredentials(storage);
    final bound = client.withToken(() => token);
    final central = await bound.getJson('/me');
    await _loadCredentials(token);
    final account = _account(central);
    _creds = _creds!.withToken(account.id, token, refreshToken: t.refresh);
    _lastRestored = true;
    await _save(storage);
    // SNS のアクセストークンの端末間共有 (D-319): 新しくログインした端末は、次の見回りで共有を求める(元の端末に問いが出る)。
    await SnsShareStore(storage).markRequest(account.id);
    var bundle = const <String>[];
    try {
      bundle = [for (final e in await bound.getList('/me/sns-accounts')) if (e is Map && e['accountKey'] is String) e['accountKey'] as String];
    } on OrgateException catch (e) {
      debugPrint('rasq account: bundle unavailable after login: $e');
    }
    final onDevice = {for (final s in ref.read(sessionsProvider).value?.allSessions ?? const <AccountSession>[]) s.account.key};
    _fetched = (client: client, token: token, account: account);
    await ref.read(rasqAccountsProvider.future);
    await ref.read(rasqAccountsProvider.notifier).attachCentral(
          centralAccountId: account.id,
          handle: account.handle,
          displayName: account.displayName,
          avatarUrl: account.avatarUrl,
          inheritSessions: false,
          pruneBundle: false,
          adoptKeys: [for (final k in bundle) if (onDevice.contains(k)) k],
        );
    // 台帳の切り替えでも作り直されるが、同じアカウントへのログインし直し(台帳の「いま」が変わらない)でも使い始める。
    _activeId = account.id;
    _publishToken();
    state = AsyncData(account);
    return account;
  }

  /// プロフィールをまとめて保存 (S-020): 画像(選び直したものだけ)→ 項目。`null` は「そのまま」、空文字は「消す」。
  Future<RasqAccount?> saveProfile({
    String? handle,
    String? displayName,
    String? bio,
    String? location,
    String? birthday,
    List<({String label, String url})>? links,
    ({List<int> bytes, String contentType})? avatar,
    ({List<int> bytes, String contentType})? banner,
    bool removeAvatar = false,
    bool removeBanner = false,
  }) async {
    final client = ref.read(centralClientProvider);
    if (client == null) return null;
    if (avatar != null) await client.putBytes('/me/avatar', avatar.bytes, contentType: avatar.contentType);
    if (banner != null) await client.putBytes('/me/banner', banner.bytes, contentType: banner.contentType);
    if (removeAvatar && avatar == null) await client.delete('/me/avatar');
    if (removeBanner && banner == null) await client.delete('/me/banner');
    final res = await client.patchJson('/me', {
      'handle': ?handle,
      'displayName': ?displayName,
      'bio': ?bio,
      'location': ?location,
      'birthday': ?birthday,
      if (links != null) 'links': [for (final l in links) {'label': l.label, 'url': l.url}],
    });
    _setAccount(res);
    return state.value;
  }

  /// 「SNS のプロフィールにも、つないだアカウントを出す」(D-312) を切り替える。すぐ保存する(「決定」を待たない)。
  Future<void> setShowLinksOnSnsProfiles(bool on) async {
    final client = ref.read(centralClientProvider);
    if (client == null) return;
    _setAccount(await client.patchJson('/me', {'showLinksOnSnsProfiles': on}));
  }

  Future<void> updateProfile({String? handle, String? displayName, String? avatarUrl}) async {
    final client = ref.read(centralClientProvider);
    if (client == null) return;
    final res = await client.patchJson('/me', {
      'handle': ?handle,
      'displayName': ?displayName,
      'avatarUrl': ?avatarUrl,
    });
    _setAccount(res);
  }

  /// ログイン済み SNS アカウントをバンドルへ写す。**トークンは送らない。**
  /// サーバーが知るのは「どのアカウントが束ねられているか」だけ。
  ///
  /// [prune] = false なら足すだけで、サーバーにだけあるアカウントは消さない(登録の FOW で
  /// 「置き換えない」を選んだアカウント、D-241)。
  /// アプリを開いている間に 1 回だけ調べる(同期のたびに SNS へ取りに行かない)。
  final Map<String, Map<String, Object?>> _tileCache = {};

  /// タイルに要る情報を、その SNS から取る。**鍵アカウント**か、**直近の投稿の公開範囲がフォロワーのみに寄っている**なら
  /// `autoVisible: false`([snsAutoVisible])。どれも付随情報なので、失敗は握りつぶす。
  Future<Map<String, Object?>> _tileInfo(AccountSession s) async {
    final cached = _tileCache[s.account.key];
    if (cached != null) return cached;
    final out = <String, Object?>{};
    try {
      final registry = ref.read(pluginRegistryProvider);
      final session = registry.session(s);
      final me = await session.me();
      final profile = await session.user(me.id);
      List<String?> visibilities = const [];
      try {
        visibilities = [for (final p in (await session.userPosts(me.id, limit: 20)).items) p.visibility];
      } catch (_) {}
      out['autoVisible'] = snsAutoVisible(isLocked: profile.isLocked, recentVisibilities: visibilities);
      final url = profile.profileUrl ?? profile.url;
      if (url != null && (url.scheme == 'https' || url.scheme == 'http')) out['profileUrl'] = url.toString();
      try {
        final info = await registry.plugin(s.pluginId)?.inspectServer(s.account.instance);
        if (info != null) {
          if (info.name.isNotEmpty) out['serverName'] = info.name;
          if (info.iconUrl != null) out['serverIconUrl'] = info.iconUrl.toString();
        }
      } catch (_) {}
      _tileCache[s.account.key] = out;
    } catch (e) {
      debugPrint('rasq account: tile info unavailable for ${s.account.key}: $e');
    }
    return out;
  }

  /// [accountId] = 同期する Central のアカウント。そのアカウントのトークンに縛った口で送る(途中で切り替わっても、
  /// よそのアカウントのバンドルを書き換えない。D-316)。
  Future<void> syncBundle(List<AccountSession> sessions, {bool prune = true, String? accountId}) async {
    final base = ref.read(centralClientProvider);
    final token = accountId == null ? this.token : tokenFor(accountId);
    if (base == null || state.value == null || token == null) return;
    final client = base.withToken(() => token);
    final wanted = {for (final s in sessions) s.account.key: s};
    try {
      final existing = await client.getList('/me/sns-accounts');
      final existingKeys = {
        for (final e in existing)
          if (e is Map) e['accountKey'] as String? ?? '',
      };
      for (final s in wanted.values) {
        // アカウントページのタイル (S-021): 自動で出してよいか / サーバーの名前とアイコン / その SNS 上のプロフィール。
        // 取れなければ送らない(サーバーは前の値のまま。新規は「出す」)。
        final tile = await _tileInfo(s);
        await client.putJson('/me/sns-accounts', {
          'kind': s.account.kind.name,
          'instance': s.account.instance,
          'handle': s.account.handle,
          'pluginId': s.pluginId,
          if (s.displayName != null) 'displayName': s.displayName,
          if (s.avatarUrl != null) 'avatarUrl': s.avatarUrl.toString(),
          ...tile,
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
  final shown = ref.watch(sessionsProvider).value?.sessions ?? const <AccountSession>[];
  final account = ref.watch(orgateAccountProvider).value;
  final (target, prune, keys) = ref.watch(rasqAccountsProvider.select((s) => (centralTargetOf(s.value), s.value?.current?.pruneBundle ?? true, s.value?.current?.sessionKeys)));
  if (account == null) return;
  // 台帳の「いま」と Central のアカウントが食い違っている(切り替えの途中)あいだは送らない (D-316):
  // 見えているのは台帳の「いま」のアカウントの SNS なので、別のアカウントのバンドルへ写してしまう。
  if (target != null && target != account.id) return;
  // セッションの一覧は、台帳が切り替わってから少し遅れて作り直される。前のアカウントの一覧が残っているあいだに
  // 送らないよう、台帳の「いま」の行に属するものだけにする。
  final sessions = keys == null ? shown : [for (final s in shown) if (keys.contains(s.account.key)) s];
  if (sessions.isEmpty) return;
  // build 中の書き込みを避けるため次のマイクロタスクへ逃がす。
  Future.microtask(() => ref.read(orgateAccountProvider.notifier).syncBundle(sessions, prune: prune, accountId: account.id));
});

/// いまの Central のアカウントの id (D-316)。アカウントごとの中身を持つ口(アカウントページ / AsTell / ストア)は
/// これを watch して、アカウントの切り替えで作り直す(前のアカウントの答えを出し続けない)。
final currentCentralAccountIdProvider = Provider<String?>((ref) => ref.watch(orgateAccountProvider.select((a) => a.value?.id)));

/// この端末がトークンを持っている Central のアカウント (D-316)。台帳の行に「ログインが必要」を出すのに使う。
/// null = まだ分からない(端末の資格情報を読み終える前)。
final centralSignedInAccountIdsProvider = Provider<Set<String>?>((ref) {
  final st = ref.watch(orgateAccountProvider);
  if (st.isLoading && !st.hasValue) return null;
  return ref.read(orgateAccountProvider.notifier).signedInAccountIds;
});

/// いまの RASQ アカウントの Central のハンドル(アカウントページの行き先)。「この端末のみ」なら null。
/// 切り替えの直後([orgateAccountProvider] がまだ前のアカウント)も、台帳の行のハンドルを返す(前のアカウントのページを開かない)。
final currentCentralHandleProvider = Provider<String?>((ref) {
  final me = ref.watch(orgateAccountProvider).value;
  final target = ref.watch(rasqAccountsProvider.select((s) => centralTargetOf(s.value)));
  if (target == null) return me?.handle;
  if (target.isEmpty) return null;
  if (me != null && me.id == target) return me.handle;
  return ref.watch(currentRasqAccountProvider)?.handle;
});
