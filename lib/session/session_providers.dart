import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:sns_misskey/sns_misskey.dart';

import '../backend/rasq_account.dart';
import '../backend/sns_oauth.dart';
import 'rasq_accounts.dart';
import 'session_storage.dart';
import 'bluesky_auth.dart';
import 'mixi2_auth.dart';
import '../features/plugins/fetch_shape_telemetry.dart';
import '../features/child_safe/child_safe_providers.dart' show childSnsAllowProvider;

/// wasm SNS サンプルの pluginId(dev「実登録」とレジストリ解決で共用)。
const wasmSamplePluginId = 'misskey-wasm-sample';

/// Mastodon プラグイン (D-135) の pluginId。ログイン画面とレジストリで共用。
const mastodonPluginId = 'rasq.official.mastodon';

/// Overridable in tests (MemorySessionStorage).
final sessionStorageProvider = Provider<SessionStorage>((ref) => SecureSessionStorage());

/// Installed SNS plugins.
///
/// - Misskey: Dart 直書きアダプタ (D-010)。MiAuth はクライアント単体で完結する。
/// - Misskey (wasm sample): 同じ SNS の wasm 実装。ログイン UI には出ない
///   (`pluginFor` は Dart 版が先)— 登録は dev 画面の「実登録」から。
/// - Mastodon (D-135): wasm プラグイン。**認証は orgate-server の OAuth
///   ブローカー経由**(インスタンスごとの client_secret が要るため)。
///   サーバー未設定ならログイン開始時にその旨のエラーを返す。
final pluginRegistryProvider = Provider<PluginRegistry>((ref) {
  // 通信の形の報告(同意した端末だけ)。同梱の SNS プラグインはストアに版が無いので
  // 404 で捨てられるが、ストアから入れた SNS プラグインと同じ口を通しておく。
  void onFetchShape(String pluginId, String version, Map<String, Object?> s) => ref.read(fetchShapeTelemetryProvider).report(pluginId, version, s);
  // Bluesky (D-175): 認証フローがプラグイン自身(匿名ワーカー)を使うので先に作る。
  late final WasmSnsPlugin bluesky;
  bluesky = WasmSnsPlugin(
    manifest: const PluginManifest(
      id: blueskyPluginId,
      name: 'Bluesky',
      version: '0.1.0',
      kind: PluginKind.sns,
      supportedSns: [SnsKind.bluesky],
      permissions: ['network', 'storage.safe', 'register_action'],
      // createSession は bsky.social、以後の XRPC はアカウントの PDS(= instance)。
      network: PluginNetwork(hosts: ['bsky.social'], instance: true),
      official: true,
      verified: true,
    ),
    kind: SnsKind.bluesky,
    loadBytes: () async => (await rootBundle.load('assets/plugins/bluesky_wasm.wasm')).buffer.asUint8List(),
    authFlowFactory: (host, {callback}) async => BlueskyCredentialFlow(plugin: bluesky, host: host),
    onFetchShape: onFetchShape,
  );
  // mixi2 (D-206、サンプル): 公式 API 申請前なのでダミーモード(ホスト `dummy`)で流れを確かめる。
  late final WasmSnsPlugin mixi2;
  mixi2 = WasmSnsPlugin(
    manifest: const PluginManifest(
      id: mixi2PluginId,
      name: 'mixi2 (サンプル)',
      version: '0.1.0',
      kind: PluginKind.sns,
      supportedSns: [SnsKind.mixi2],
      permissions: ['network', 'storage.safe', 'register_action'],
      network: PluginNetwork(instance: true),
      official: true,
      verified: false,
    ),
    kind: SnsKind.mixi2,
    loadBytes: () async => (await rootBundle.load('assets/plugins/mixi2_wasm.wasm')).buffer.asUint8List(),
    authFlowFactory: mixi2AuthFactory(ref, () => mixi2),
    onFetchShape: onFetchShape,
  );
  final r = PluginRegistry()
    ..register(MisskeyPlugin())
    ..register(WasmSnsPlugin(
      manifest: const PluginManifest(
        id: mastodonPluginId,
        name: 'Mastodon',
        version: '0.1.0',
        kind: PluginKind.sns,
        supportedSns: [SnsKind.mastodon],
        permissions: ['network', 'storage.safe', 'register_action'],
        network: PluginNetwork(instance: true),
        official: true,
        verified: true,
      ),
      kind: SnsKind.mastodon,
      loadBytes: () async => (await rootBundle.load('assets/plugins/mastodon_wasm.wasm')).buffer.asUint8List(),
      authFlowFactory: brokeredAuthFactory(ref, provider: 'mastodon', pluginId: mastodonPluginId, kind: SnsKind.mastodon),
      onFetchShape: onFetchShape,
    ))
    // Bluesky (D-175): wasm プラグイン。認証はハンドル + アプリパスワード(`sns.login` = createSession)。
    ..register(bluesky)
    ..register(mixi2)
    // wasm SNS サンプル (D-079: 実登録の口)。この pluginId のセッションは
    // sns.* 境界(WasmSnsSession)として解決され、アプリの通常パイプラインが
    // wasm の上で動く。ログイン UI には出ない(pluginFor は Misskey が先)—
    // 登録は dev 画面の「実登録」から。
    ..register(WasmSnsPlugin(
      manifest: const PluginManifest(id: wasmSamplePluginId, name: 'Misskey (wasm sample)', version: '0.1.0', kind: PluginKind.sns, supportedSns: [SnsKind.misskey], permissions: ['network', 'storage.safe'], network: PluginNetwork(instance: true)),
      kind: SnsKind.misskey,
      loadBytes: () async => (await rootBundle.load('assets/plugins/misskey_wasm_sample.wasm')).buffer.asUint8List(),
      onFetchShape: onFetchShape,
    ));
  ref.onDispose(() async {
    await r.closeAll();
    // セッションを持たないワーカー(inspectServer 用の匿名ワーカー)も
    // ここで閉じる。
    for (final p in r.plugins.whereType<WasmSnsPlugin>()) {
      await p.dispose();
    }
  });
  return r;
});

@immutable
class SessionsState {
  const SessionsState({this.sessions = const [], this.currentKey, this.bundleView = false, List<AccountSession>? allSessions}) : _all = allSessions;

  /// **現在の RASQ アカウントに属する** SNS セッション (D-138)。バンドル TL /
  /// コンポーザー / サイドバーのアカウント行はこれを見る。
  final List<AccountSession> sessions;

  /// 端末にある全セッション(RASQ アカウントを跨いだ集合)。永続化の単位。
  List<AccountSession> get allSessions => _all ?? sessions;
  final List<AccountSession>? _all;
  final String? currentKey;

  /// 総合表示 (D-087): アカウントバンドルタイル(RASQ アカウント)が選択
  /// されている状態。ホームの TL は全アカウント合流の「総合」になる。
  /// 個別アカウントを選ぶと false に戻る(current は裏で保持)。
  final bool bundleView;

  AccountSession? get current {
    if (sessions.isEmpty) return null;
    return sessions.where((s) => s.account.key == currentKey).firstOrNull ?? sessions.first;
  }

  bool get isLoggedIn => sessions.isNotEmpty;

  SessionsState copyWith({List<AccountSession>? sessions, String? currentKey, bool? bundleView, List<AccountSession>? allSessions}) =>
      SessionsState(sessions: sessions ?? this.sessions, currentKey: currentKey ?? this.currentKey, bundleView: bundleView ?? this.bundleView, allSessions: allSessions ?? _all);
}

/// Logged-in accounts + the selected one. Persisted as one JSON blob in
/// secure storage under [storageKey].
class SessionsNotifier extends AsyncNotifier<SessionsState> {
  static const storageKey = 'rasq.sessions.v1';

  @override
  Future<SessionsState> build() async {
    // 現在の RASQ アカウント (D-138) が変われば見せるセッションも変わる。
    // 見守り中 (D-307) は、保護者が許した SNS(種類 / サーバー)のセッションだけを見せる。
    // (箱はチャイルドセーフが書く。ここからチャイルドセーフには依存しない。)
    ref.watch(childSnsAllowProvider);
    final ledger = await ref.watch(rasqAccountsProvider.future);
    final raw = await ref.read(sessionStorageProvider).read(storageKey);
    if (raw == null) return const SessionsState();
    try {
      final j = (jsonDecode(raw) as Map).cast<String, Object?>();
      final list = [for (final s in (j['sessions'] as List? ?? const [])) AccountSession.fromJson((s as Map).cast<String, Object?>())];
      return _view(list, currentKey: j['current'] as String?, bundleView: j['bundle'] == true, ledger: ledger);
    } catch (e) {
      debugPrint('sessions: corrupt storage, starting fresh: $e');
      return const SessionsState();
    }
  }

  /// 全セッションから、現在の RASQ アカウントに属する分だけを見せる形を作る。
  /// 台帳が無い(移行前・テストの素の状態)なら全部見せる。current が所属外
  /// なら所属内の先頭へ寄せる。
  SessionsState _view(List<AccountSession> all, {String? currentKey, bool bundleView = false, RasqAccountsState? ledger}) {
    final owner = (ledger ?? ref.read(rasqAccountsProvider).value ?? const RasqAccountsState()).current;
    final sns = ref.read(childSnsAllowProvider);
    final visible = [
      for (final s in all)
        if ((owner == null || owner.sessionKeys.contains(s.account.key)) && (sns == null || sns.permits(s.account.kind.name, s.account.instance))) s,
    ];
    final key = visible.any((s) => s.account.key == currentKey) ? currentKey : visible.firstOrNull?.account.key;
    return SessionsState(sessions: visible, currentKey: key, bundleView: bundleView, allSessions: all);
  }

  Future<void> _persist(SessionsState s) async {
    await ref.read(sessionStorageProvider).write(
          storageKey,
          jsonEncode({'sessions': s.allSessions.map((e) => e.toJson()).toList(), 'current': s.currentKey, 'bundle': s.bundleView}),
        );
    state = AsyncData(s);
  }

  Future<void> add(AuthResult result) async {
    final sns = ref.read(childSnsAllowProvider);
    if (sns != null && !sns.addAccounts) throw StateError('保護者が SNS アカウントの追加を止めています');
    final cur = state.value ?? const SessionsState();
    // 新しいログインは現在の RASQ アカウントに所属させる (D-138)。
    await ref.read(rasqAccountsProvider.notifier).addSessionKey(result.session.account.key);
    final others = cur.allSessions.where((s) => s.account != result.session.account).toList();
    await _persist(_view([...others, result.session], currentKey: result.session.account.key, ledger: ref.read(rasqAccountsProvider).value));
  }

  Future<void> remove(AccountId account) async {
    final cur = state.value ?? const SessionsState();
    await ref.read(pluginRegistryProvider).closeSession(account);
    await ref.read(rasqAccountsProvider.notifier).removeSessionKey(account.key);
    final rest = cur.allSessions.where((s) => s.account != account).toList();
    await _persist(_view(rest, currentKey: cur.currentKey == account.key ? null : cur.currentKey, bundleView: cur.bundleView, ledger: ref.read(rasqAccountsProvider).value));
  }

  /// RASQ アカウントからのログアウトで、その SNS アカウントもログアウトする (D-409): [keys](`AccountId.key`)の
  /// セッションを閉じ、台帳と端末の保存から消す。[remove] をまとめて行うもの(保存は 1 回)。
  Future<void> removeKeys(Iterable<String> keys) async {
    final drop = keys.toSet();
    if (drop.isEmpty) return;
    final cur = state.value ?? await future;
    final registry = ref.read(pluginRegistryProvider);
    final ledger = ref.read(rasqAccountsProvider.notifier);
    for (final s in cur.allSessions) {
      if (drop.contains(s.account.key)) await registry.closeSession(s.account);
    }
    for (final k in drop) {
      await ledger.removeSessionKey(k);
    }
    final rest = [for (final s in cur.allSessions) if (!drop.contains(s.account.key)) s];
    if (rest.length == cur.allSessions.length) return;
    await _persist(_view(rest, currentKey: drop.contains(cur.currentKey) ? null : cur.currentKey, bundleView: cur.bundleView, ledger: ref.read(rasqAccountsProvider).value));
  }

  /// SNS のアクセストークンの端末間共有 (D-319): ほかの端末のログイン [logins] を取り込み(同じアカウントは置き換え)、
  /// ほかの端末でのログアウト [logouts](`AccountId.key`)を反映する。取り込んだものは、その Central のアカウント
  /// ([centralAccountId]) の台帳の行に所属させる。開いているセッションは閉じる(新しいトークンで開き直す)。
  Future<void> applyShared({required String centralAccountId, List<AccountSession> logins = const [], List<String> logouts = const []}) async {
    if (logins.isEmpty && logouts.isEmpty) return;
    final cur = state.value ?? await future;
    final registry = ref.read(pluginRegistryProvider);
    final ledger = ref.read(rasqAccountsProvider.notifier);
    for (final s in cur.allSessions) {
      if (logouts.contains(s.account.key) || logins.any((l) => l.account == s.account)) await registry.closeSession(s.account);
    }
    for (final k in logouts) {
      await ledger.removeSessionKey(k);
    }
    await ledger.addCentralSessionKeys([for (final s in logins) s.account.key], centralAccountId: centralAccountId);
    final keep = [for (final s in cur.allSessions) if (!logouts.contains(s.account.key) && !logins.any((l) => l.account == s.account)) s];
    await _persist(_view([...keep, ...logins], currentKey: cur.currentKey, bundleView: cur.bundleView, ledger: ref.read(rasqAccountsProvider).value));
  }

  Future<void> setCurrent(AccountId account) async {
    final cur = state.value ?? const SessionsState();
    if (cur.currentKey == account.key && !cur.bundleView) return;
    // 個別アカウントの選択は総合表示を抜ける (D-087)。
    await _persist(cur.copyWith(currentKey: account.key, bundleView: false));
  }

  /// 総合表示 (D-087): アカウントバンドルタイルの短押しで入る。
  Future<void> setBundleView(bool on) async {
    final cur = state.value ?? const SessionsState();
    if (cur.bundleView == on) return;
    await _persist(cur.copyWith(bundleView: on));
  }
}

final sessionsProvider = AsyncNotifierProvider<SessionsNotifier, SessionsState>(SessionsNotifier.new);

/// Current account session (null while loading / logged out).
final currentAccountSessionProvider = Provider<AccountSession?>((ref) => ref.watch(sessionsProvider).value?.current);

/// Open SnsSession for the current account.
final currentSnsSessionProvider = Provider<SnsSession?>((ref) {
  final s = ref.watch(currentAccountSessionProvider);
  if (s == null) return null;
  return ref.watch(pluginRegistryProvider).session(s);
});

final currentAccountProvider = Provider<AccountId?>((ref) => ref.watch(currentAccountSessionProvider)?.account);

/// 投稿/ユーザーが属するアカウント(`AccountId.key`)のセッション (D-155)。
/// ↓ で別アカウントのコピーを選んで開いた画面は、以降そのアカウントで展開する
/// (スレッド / リアクション / ユーザーページ / 返信の投稿先)。ログイン中で
/// なければ現在のセッションに縮退。null = 現在。
final sessionForAccountProvider = Provider.family<SnsSession?, String?>((ref, key) {
  if (key == null) return ref.watch(currentSnsSessionProvider);
  final state = ref.watch(sessionsProvider).value;
  final s = _sessionForKey(state, key);
  if (s == null) return ref.watch(currentSnsSessionProvider);
  return ref.watch(pluginRegistryProvider).session(s);
});

/// [key](`AccountId.key`)のセッション。ログイン中のアカウントそのものが無ければ、**Bluesky だけは**ほかの Bluesky のアカウント
/// (現在のアカウントが Bluesky ならそれ)で代える (D-423): 人の id(DID)と投稿の id(`at://` の URI)は、どのサーバー(PDS)の
/// アカウントからでも同じものを指す。ユーザーページは作者の `AccountId.key`(Bluesky では `bluesky:<見ているサーバー>:<handle>`)で
/// 開くので、総合表示で現在のアカウントが Misskey などのとき、Bluesky の人のページが Misskey のセッションで DID を引いて
/// 「見つからない」になっていた。Misskey / Mastodon の id はサーバーの中でだけ通じるので、代えない(従来どおり現在へ縮退)。
AccountSession? _sessionForKey(SessionsState? state, String key) {
  if (state == null) return null;
  final exact = state.sessions.where((x) => x.account.key == key).firstOrNull ?? state.allSessions.where((x) => x.account.key == key).firstOrNull;
  if (exact != null || !key.startsWith('${SnsKind.bluesky.name}:')) return exact;
  final cur = state.current;
  if (cur != null && cur.account.kind == SnsKind.bluesky) return cur;
  return state.sessions.where((x) => x.account.kind == SnsKind.bluesky).firstOrNull;
}

/// [kind] / [instance] の SNS の投稿・人の id がそのまま通じるアカウントか (D-423)。同じ種類で同じサーバー。
/// Bluesky は DID / `at://` の URI がサーバー(PDS)に関係なく通じるので、種類だけを見る。
bool accountServes(AccountId a, String kind, String instance) => a.kind.name == kind && (a.kind == SnsKind.bluesky || a.instance.toLowerCase() == instance.toLowerCase());

/// [sessions] のうち、[kind] / [instance] の投稿にそのまま操作できるもの (D-423、[accountServes])。[preferKey] のアカウント
/// (投稿した本人のアカウントなど)を先に、次に同じサーバーのもの。
AccountSession? sessionServing(Iterable<AccountSession> sessions, String kind, String instance, {String? preferKey}) {
  final ok = [for (final s in sessions) if (accountServes(s.account, kind, instance)) s];
  return ok.where((s) => s.account.key == preferKey).firstOrNull ?? ok.where((s) => s.account.instance.toLowerCase() == instance.toLowerCase()).firstOrNull ?? ok.firstOrNull;
}

/// [sessionForAccountProvider] のアカウント id 版 (D-421): [key] のアカウントがログイン中ならそれ、無ければ現在。
/// 「誰として見ているか」(フォローの状態の鍵・自分の投稿 / 自分のページの判定)は、操作に使うセッションと同じアカウントで決める。
/// 総合表示(RASQ アカウントを選んでいる間)は TL に全アカウントの投稿が流れるので、現在のアカウントで決めると
/// ほかのアカウントの自分の投稿が「他人」になり、フォロー中の一覧も別のアカウントの関係を見て「未フォロー」になっていた。
final viewerForAccountProvider = Provider.family<AccountId?, String?>((ref, key) {
  if (key != null) {
    final s = _sessionForKey(ref.watch(sessionsProvider).value, key);
    if (s != null) return s.account;
  }
  return ref.watch(currentAccountProvider);
});

/// 見ているアカウント([viewerForAccountProvider] と同じ選び方)の、SNS の中での自分の id。分かるときだけ (D-423):
/// Bluesky はログインで受け取った DID(トークンの JSON の `did`)。ハンドルは変えられるので、ハンドルで比べると、
/// ハンドルを変えたあとの自分の投稿が「他人」になる。Misskey / Mastodon は持っていない(null。名前と `me()` で比べる)。
final viewerUserIdProvider = Provider.family<String?, String?>((ref, key) {
  final state = ref.watch(sessionsProvider).value;
  final s = (key == null ? null : _sessionForKey(state, key)) ?? state?.current;
  return s == null ? null : blueskyDidOf(s);
});

/// 端末にあるアカウントのうち、Bluesky の DID が [userId] のもの (D-423)。
bool isOwnBlueskyId(Iterable<AccountSession> sessions, String userId) => userId.startsWith('did:') && sessions.any((s) => blueskyDidOf(s) == userId);

/// 同じ人か (D-421): ハンドルの大文字小文字・先頭の `@`・`handle@host` の形、サーバーの `https://`・末尾の `/`・大文字小文字の
/// 違いは見ない(SNS の種類は見ない: 投稿の作者は種類を持たないことがある)。
///
/// Bluesky どうし (D-423) はハンドル(`alice.bsky.social` のようなドメインそのもの)だけで比べる。サーバーの欄は、プラグインが
/// 「見ているアカウントのサーバー(PDS)」を入れるので、同じ人でも見ているアカウントによって `bsky.social` と自前の PDS に分かれる。
bool sameAccountIdentity(AccountId a, AccountId b) {
  if (a.kind == SnsKind.bluesky && b.kind == SnsKind.bluesky) {
    String h(AccountId x) {
      var v = x.handle.trim().toLowerCase();
      if (v.startsWith('@')) v = v.substring(1);
      return v;
    }

    return h(a).isNotEmpty && h(a) == h(b);
  }
  (String, String) norm(AccountId x) {
    var h = x.handle.trim().toLowerCase();
    if (h.startsWith('@')) h = h.substring(1);
    var host = x.instance.trim().toLowerCase();
    final at = h.indexOf('@');
    if (at >= 0) {
      if (at + 1 < h.length) host = h.substring(at + 1);
      h = h.substring(0, at);
    }
    host = host.replaceFirst(RegExp(r'^[a-z]+://'), '');
    while (host.endsWith('/')) {
      host = host.substring(0, host.length - 1);
    }
    return (h, host);
  }

  final x = norm(a);
  return x.$1.isNotEmpty && x == norm(b);
}

/// [user] が [viewer](見ているアカウント)自身か (D-421)。名前で比べ、[me] が同じアカウントのプロフィールなら id でも比べる
/// (`me()` を取れていないあいだの [currentUserProvider] は id が `-`)。
///
/// [viewerId] (D-423) = 見ているアカウントの SNS の中での id が分かっていれば([viewerUserIdProvider]、Bluesky の DID)、それでも比べる。
bool isViewerSelf(UserSummary user, AccountId? viewer, {UserSummary? me, String? viewerId}) {
  if (viewer != null && sameAccountIdentity(user.account, viewer)) return true;
  if (viewerId != null && viewerId.isNotEmpty && user.id == viewerId) return true;
  if (me == null || me.id == '-' || me.id.isEmpty) return false;
  // id はそのサーバーの中でだけ通じる。
  if (viewer != null && !sameAccountIdentity(me.account, viewer)) return false;
  return user.id == me.id || sameAccountIdentity(user.account, me.account);
}

/// フォローの状態の鍵 (`viewerKind:viewerInstance:userId`)。関係はそのアカウントのサーバーの id で返るので、見ているアカウントで作る。
String followUserKey(AccountId viewer, String userId) => '${viewer.kind.name}:${viewer.instance}:$userId';

/// 総合表示中か (D-087)。
final bundleViewProvider = Provider<bool>((ref) => ref.watch(sessionsProvider).value?.bundleView ?? false);

/// RASQ アカウント(バンドルの顔)(D-087)。
///
/// ORGATE サーバーに繋がっていれば**本物の RASQ アカウント**
/// ([orgateAccountProvider] = `GET /me`)を出す。接続先が未設定、または
/// まだ取得できていない間は、最初のログインアカウントのプロフィールを
/// 流用する(サーバー無しでもサイドバーが成立する)。
/// どちらの場合もハンドルはインスタンスなしの素の形(`@handle`)で出す —
/// 個別アカウント行の `handle@instance` と区別が付く。
final rasqAccountProvider = Provider<UserSummary>((ref) {
  final record = ref.watch(currentRasqAccountProvider);
  final server = ref.watch(orgateAccountProvider).value;
  // Central アカウント (D-138): サーバーのプロフィールが取れていればそれ、
  // まだなら台帳に写した値。
  if (record != null && record.isCentral) {
    if (server != null && server.id == record.centralAccountId) return server.toUserSummary();
    return UserSummary(
      id: 'rasq:${record.centralAccountId}',
      account: AccountId(kind: SnsKind.other, instance: 'rasq', handle: record.handle ?? ''),
      displayName: record.displayName ?? record.handle ?? 'RASQ',
      avatarUrl: record.avatarUrl,
    );
  }

  // 「この端末のみ」: 明示のプロフィールがあればそれ、無ければ所属する最初の
  // SNS アカウントを借りる(従来の挙動)。
  final sessions = ref.watch(sessionsProvider).value?.sessions ?? const <AccountSession>[];
  final first = sessions.firstOrNull;
  final handle = record?.handle ?? first?.account.handle ?? '';
  final displayName = record?.displayName ?? first?.displayName ?? (first?.account.handle ?? 'RASQ');
  if (first == null && record == null) {
    return const UserSummary(id: '-', account: AccountId(kind: SnsKind.other, instance: '', handle: ''), displayName: 'RASQ');
  }
  return UserSummary(
    id: 'rasq:${record?.id ?? handle}',
    account: AccountId(kind: SnsKind.other, instance: 'rasq', handle: handle),
    displayName: displayName,
    avatarUrl: record?.avatarUrl ?? first?.avatarUrl,
  );
});

/// Viewer profile. Resolves synchronously from the cached session bits and
/// refreshes from `me()` in the background.
final currentUserProvider = Provider<UserSummary>((ref) {
  final s = ref.watch(currentAccountSessionProvider);
  final fetched = ref.watch(_meProvider).value;
  if (fetched != null && s != null && fetched.account == s.account) return fetched;
  if (s == null) {
    return const UserSummary(id: '-', account: AccountId(kind: SnsKind.other, instance: '', handle: ''), displayName: 'RASQ');
  }
  return UserSummary(id: '-', account: s.account, displayName: s.displayName ?? s.account.handle, avatarUrl: s.avatarUrl);
});

final _meProvider = FutureProvider<UserSummary?>((ref) async {
  final session = ref.watch(currentSnsSessionProvider);
  if (session == null) return null;
  try {
    return await session.me();
  } catch (e) {
    debugPrint('me(): $e');
    return null;
  }
});

/// Custom-emoji URL cache shared by all rows; missing shortcodes are fetched
/// lazily through the session and the map is updated in place.
class EmojiCache extends Notifier<Map<String, Uri?>> {
  final Set<String> _inflight = {};

  @override
  Map<String, Uri?> build() {
    ref.watch(currentAccountProvider); // reset per account
    _inflight.clear();
    return const {};
  }

  void request(Iterable<String> shortcodes) {
    final session = ref.read(currentSnsSessionProvider);
    if (session == null) return;
    for (final code in shortcodes) {
      if (state.containsKey(code) || _inflight.contains(code)) continue;
      _inflight.add(code);
      session.emojiUrl(code).then((u) {
        _inflight.remove(code);
        state = {...state, code: u};
      }).catchError((_) {
        _inflight.remove(code);
        state = {...state, code: null};
      });
    }
  }
}

final emojiCacheProvider = NotifierProvider<EmojiCache, Map<String, Uri?>>(EmojiCache.new);

/// あるアカウントのサーバーの絵文字の URL (D-284)。総合 TL では、投稿が流れてきたアカウントごとにサーバーが違うので、
/// 表示中のアカウント([emojiCacheProvider])ではなく、そのアカウントで引く。無ければ null。
final accountEmojiUrlProvider = FutureProvider.family<Uri?, ({String account, String name})>((ref, k) async {
  final session = ref.watch(sessionForAccountProvider(k.account));
  try {
    return await session?.emojiUrl(k.name);
  } catch (_) {
    return null;
  }
});
