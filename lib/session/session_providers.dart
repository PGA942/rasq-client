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
      official: true,
      verified: true,
    ),
    kind: SnsKind.bluesky,
    loadBytes: () async => (await rootBundle.load('assets/plugins/bluesky_wasm.wasm')).buffer.asUint8List(),
    authFlowFactory: (host, {callback}) async => BlueskyCredentialFlow(plugin: bluesky, host: host),
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
        official: true,
        verified: true,
      ),
      kind: SnsKind.mastodon,
      loadBytes: () async => (await rootBundle.load('assets/plugins/mastodon_wasm.wasm')).buffer.asUint8List(),
      authFlowFactory: brokeredAuthFactory(ref, provider: 'mastodon', pluginId: mastodonPluginId, kind: SnsKind.mastodon),
    ))
    // Bluesky (D-175): wasm プラグイン。認証はハンドル + アプリパスワード(`sns.login` = createSession)。
    ..register(bluesky)
    // wasm SNS サンプル (D-079: 実登録の口)。この pluginId のセッションは
    // sns.* 境界(WasmSnsSession)として解決され、アプリの通常パイプラインが
    // wasm の上で動く。ログイン UI には出ない(pluginFor は Misskey が先)—
    // 登録は dev 画面の「実登録」から。
    ..register(WasmSnsPlugin(
      manifest: const PluginManifest(id: wasmSamplePluginId, name: 'Misskey (wasm sample)', version: '0.1.0', kind: PluginKind.sns, supportedSns: [SnsKind.misskey]),
      kind: SnsKind.misskey,
      loadBytes: () async => (await rootBundle.load('assets/plugins/misskey_wasm_sample.wasm')).buffer.asUint8List(),
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
    final visible = owner == null ? all : [for (final s in all) if (owner.sessionKeys.contains(s.account.key)) s];
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
  final s = state?.sessions.where((x) => x.account.key == key).firstOrNull ?? state?.allSessions.where((x) => x.account.key == key).firstOrNull;
  if (s == null) return ref.watch(currentSnsSessionProvider);
  return ref.watch(pluginRegistryProvider).session(s);
});

/// [sessionForAccountProvider] のアカウント id 版。

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
