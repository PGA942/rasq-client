import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:sns_misskey/sns_misskey.dart';

import 'session_storage.dart';

/// wasm SNS サンプルの pluginId(dev「実登録」とレジストリ解決で共用)。
const wasmSamplePluginId = 'misskey-wasm-sample';

/// Overridable in tests (MemorySessionStorage).
final sessionStorageProvider = Provider<SessionStorage>((ref) => SecureSessionStorage());

/// Installed SNS plugins. M1: Misskey only (D-010). Bluesky / Mastodon are
/// registered once ORGATE-server can issue tokens.
final pluginRegistryProvider = Provider<PluginRegistry>((ref) {
  final r = PluginRegistry()
    ..register(MisskeyPlugin())
    // wasm SNS サンプル (D-079: 実登録の口)。この pluginId のセッションは
    // sns.* 境界(WasmSnsSession)として解決され、アプリの通常パイプラインが
    // wasm の上で動く。ログイン UI には出ない(pluginFor は Misskey が先)—
    // 登録は dev 画面の「実登録」から。
    ..register(WasmSnsPlugin(
      manifest: const PluginManifest(id: wasmSamplePluginId, name: 'Misskey (wasm sample)', version: '0.1.0', kind: PluginKind.sns, supportedSns: [SnsKind.misskey]),
      kind: SnsKind.misskey,
      loadBytes: () async => (await rootBundle.load('assets/plugins/misskey_wasm_sample.wasm')).buffer.asUint8List(),
    ));
  ref.onDispose(r.closeAll);
  return r;
});

@immutable
class SessionsState {
  const SessionsState({this.sessions = const [], this.currentKey, this.bundleView = false});
  final List<AccountSession> sessions;
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

  SessionsState copyWith({List<AccountSession>? sessions, String? currentKey, bool? bundleView}) =>
      SessionsState(sessions: sessions ?? this.sessions, currentKey: currentKey ?? this.currentKey, bundleView: bundleView ?? this.bundleView);
}

/// Logged-in accounts + the selected one. Persisted as one JSON blob in
/// secure storage under [storageKey].
class SessionsNotifier extends AsyncNotifier<SessionsState> {
  static const storageKey = 'rasq.sessions.v1';

  @override
  Future<SessionsState> build() async {
    final raw = await ref.read(sessionStorageProvider).read(storageKey);
    if (raw == null) return const SessionsState();
    try {
      final j = (jsonDecode(raw) as Map).cast<String, Object?>();
      final list = [for (final s in (j['sessions'] as List? ?? const [])) AccountSession.fromJson((s as Map).cast<String, Object?>())];
      return SessionsState(sessions: list, currentKey: j['current'] as String?, bundleView: j['bundle'] == true);
    } catch (e) {
      debugPrint('sessions: corrupt storage, starting fresh: $e');
      return const SessionsState();
    }
  }

  Future<void> _persist(SessionsState s) async {
    await ref.read(sessionStorageProvider).write(
          storageKey,
          jsonEncode({'sessions': s.sessions.map((e) => e.toJson()).toList(), 'current': s.currentKey, 'bundle': s.bundleView}),
        );
    state = AsyncData(s);
  }

  Future<void> add(AuthResult result) async {
    final cur = state.value ?? const SessionsState();
    final others = cur.sessions.where((s) => s.account != result.session.account).toList();
    await _persist(SessionsState(sessions: [...others, result.session], currentKey: result.session.account.key));
  }

  Future<void> remove(AccountId account) async {
    final cur = state.value ?? const SessionsState();
    await ref.read(pluginRegistryProvider).closeSession(account);
    final rest = cur.sessions.where((s) => s.account != account).toList();
    await _persist(SessionsState(sessions: rest, currentKey: cur.currentKey == account.key ? rest.firstOrNull?.account.key : cur.currentKey));
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

/// 総合表示中か (D-087)。
final bundleViewProvider = Provider<bool>((ref) => ref.watch(sessionsProvider).value?.bundleView ?? false);

/// RASQ アカウント(バンドルの顔)(D-087)。ORGATE サーバーのアカウントが
/// できるまでは最初のログインアカウントのプロフィールを流用し、ハンドルは
/// インスタンスなしの素の形(`@handle`)で出す — 個別アカウント行の
/// `handle@instance` と区別が付く。
final rasqAccountProvider = Provider<UserSummary>((ref) {
  final sessions = ref.watch(sessionsProvider).value?.sessions ?? const <AccountSession>[];
  final first = sessions.firstOrNull;
  if (first == null) {
    return const UserSummary(id: '-', account: AccountId(kind: SnsKind.other, instance: '', handle: ''), displayName: 'RASQ');
  }
  return UserSummary(
    id: 'rasq:${first.account.handle}',
    account: AccountId(kind: SnsKind.other, instance: 'rasq', handle: first.account.handle),
    displayName: first.displayName ?? first.account.handle,
    avatarUrl: first.avatarUrl,
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
