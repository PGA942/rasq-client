import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart' show AccountSession;

import 'session_providers.dart';
import 'session_storage.dart';
import '../l10n/l10n.dart';

/// RASQ アカウントの台帳 (D-138: RASQ アカウントの実体化)。
///
/// これまで「アカウントバンドル」= 端末にログインした SNS アカウント全部
/// だったものを、**1 つの RASQ アカウント**として管理する。端末には複数の
/// RASQ アカウントを置け、それぞれが自分の SNS セッション(バンドル)を持つ。
///
/// - [RasqAccountKind.local]: 端末だけのアカウント。導入したプラグインや
///   設定は端末上にのみ保存される(オンボーディングで「スキップ」した状態 =
///   従来のシステム)。
/// - [RasqAccountKind.central]: RASQ Central (`rasq-central`) に実体がある
///   アカウント。プロフィール/バンドル/インストール履歴がサーバーへ同期される。
///   端末資格情報は [OrgateAccountNotifier] が持つ(Central のアカウントごとに 1 本のトークン。D-316)。
///   台帳の「いま」が、どのトークンで Central と話すかを決める(`centralTargetOf`)。
///
/// 永続化は KV `rasq.accounts.v1`(セキュアストレージ)。SNS セッションの
/// 実体は従来どおり `rasq.sessions.v1` にあり、こちらは**所属(キー)**だけを
/// 持つ。[SessionsNotifier] はこの台帳を見て、現在の RASQ アカウントに属する
/// セッションだけを `sessions` として見せる。
enum RasqAccountKind {
  local('local'),
  central('central');

  const RasqAccountKind(this.wire);

  /// 表示の名前(表示の言語)。
  String get label => switch (this) { local => appL10n.sessionAccountKindLocal, central => appL10n.sessionAccountKindCentral };
  final String wire;
  static RasqAccountKind fromWire(String? w) => values.where((k) => k.wire == w).firstOrNull ?? local;
}

@immutable
class RasqAccountRecord {
  const RasqAccountRecord({
    required this.id,
    required this.kind,
    this.handle,
    this.displayName,
    this.avatarUrl,
    this.centralAccountId,
    this.sessionKeys = const [],
    this.pruneBundle = true,
    this.bundleRemovals = const [],
    required this.createdAt,
  });

  /// 端末内の識別子(`local-…` / `central-<accountId>`)。
  final String id;
  final RasqAccountKind kind;

  /// 表示用。null なら所属する最初の SNS セッションのプロフィールを借りる
  /// (従来の挙動)。
  final String? handle;
  final String? displayName;
  final Uri? avatarUrl;

  /// Central 上のアカウント id(kind == central のとき)。
  final String? centralAccountId;

  /// このアカウントに属する SNS セッション(`AccountId.key`)。
  final List<String> sessionKeys;

  /// サーバーのアカウントバンドルを、この端末の SNS アカウントで**置き換える**か (D-241)。
  /// false = 登録のときに「置き換えない」を選んだ: 足すだけで、サーバーにだけある分は消さない。
  final bool pruneBundle;

  /// この端末で**ログアウトした** SNS アカウントのうち、まだサーバーのバンドル(`sns_links`)から外せていないもの (D-461)。
  /// [pruneBundle] が false の行(ログインで入ったアカウント = ほかの端末のぶんを消さない)は、この端末に無いものを消さないので、
  /// 前はこの端末でログアウトしてもサーバーに残り続け、Web コンソール (S-097) の一覧がアプリと食い違っていた。ログアウトした
  /// ことだけをここに残し、次の同期で `DELETE /me/sns-accounts/{key}` する(消せたら外す。もう一度ログインしたら外す)。
  /// RASQ アカウントからのログアウト(D-409)で SNS も消したときは入れない(アカウントのバンドルは変えない)。
  final List<String> bundleRemovals;
  final DateTime createdAt;

  bool get isCentral => kind == RasqAccountKind.central;

  RasqAccountRecord copyWith({String? handle, String? displayName, Uri? avatarUrl, List<String>? sessionKeys, List<String>? bundleRemovals, bool clearAvatar = false}) => RasqAccountRecord(
        id: id,
        kind: kind,
        handle: handle ?? this.handle,
        displayName: displayName ?? this.displayName,
        avatarUrl: clearAvatar ? null : (avatarUrl ?? this.avatarUrl),
        centralAccountId: centralAccountId,
        sessionKeys: sessionKeys ?? this.sessionKeys,
        pruneBundle: pruneBundle,
        bundleRemovals: bundleRemovals ?? this.bundleRemovals,
        createdAt: createdAt,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'kind': kind.wire,
        'handle': handle,
        'displayName': displayName,
        'avatarUrl': avatarUrl?.toString(),
        'centralAccountId': centralAccountId,
        'sessionKeys': sessionKeys,
        if (!pruneBundle) 'pruneBundle': false,
        if (bundleRemovals.isNotEmpty) 'bundleRemovals': bundleRemovals,
        'createdAt': createdAt.toIso8601String(),
      };

  factory RasqAccountRecord.fromJson(Map<String, Object?> j) => RasqAccountRecord(
        id: j['id'] as String,
        kind: RasqAccountKind.fromWire(j['kind'] as String?),
        handle: j['handle'] as String?,
        displayName: j['displayName'] as String?,
        avatarUrl: switch (j['avatarUrl']) { final String u when u.isNotEmpty => Uri.tryParse(u), _ => null },
        centralAccountId: j['centralAccountId'] as String?,
        sessionKeys: [for (final k in (j['sessionKeys'] as List? ?? const [])) if (k is String) k],
        pruneBundle: j['pruneBundle'] != false,
        bundleRemovals: [for (final k in (j['bundleRemovals'] as List? ?? const [])) if (k is String) k],
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
}

@immutable
class RasqAccountsState {
  const RasqAccountsState({this.accounts = const [], this.currentId, this.onboardingDone = false});
  final List<RasqAccountRecord> accounts;
  final String? currentId;

  /// 初回オンボーディング(RASQ アカウント作成の案内)を済ませたか。
  /// 「スキップ」も済ませた扱い(端末ローカルで使う選択)。
  final bool onboardingDone;

  RasqAccountRecord? get current => accounts.where((a) => a.id == currentId).firstOrNull ?? accounts.firstOrNull;

  /// 台帳に Central のアカウントがあるか。
  bool get hasCentral => accounts.any((a) => a.isCentral);

  /// いまのアカウントが Central のものならそれ(「この端末のみ」なら null)。D-316: 「最初の Central のアカウント」は使わない
  /// (Central のアカウントが 2 つ以上あると、名前と中身が食い違う)。
  RasqAccountRecord? get currentCentral => current?.isCentral == true ? current : null;

  /// Central のアカウント id から、その行。
  RasqAccountRecord? centralRecord(String? centralAccountId) =>
      centralAccountId == null ? null : accounts.where((a) => a.isCentral && a.centralAccountId == centralAccountId).firstOrNull;

  RasqAccountsState copyWith({List<RasqAccountRecord>? accounts, String? currentId, bool? onboardingDone}) =>
      RasqAccountsState(accounts: accounts ?? this.accounts, currentId: currentId ?? this.currentId, onboardingDone: onboardingDone ?? this.onboardingDone);
}

class RasqAccountsNotifier extends AsyncNotifier<RasqAccountsState> {
  static const storageKey = 'rasq.accounts.v1';
  static const localId = 'local-device';

  @override
  Future<RasqAccountsState> build() async {
    final storage = ref.read(sessionStorageProvider);
    final raw = await storage.read(storageKey);
    if (raw != null) {
      try {
        final j = (jsonDecode(raw) as Map).cast<String, Object?>();
        return RasqAccountsState(
          accounts: [for (final a in (j['accounts'] as List? ?? const [])) RasqAccountRecord.fromJson((a as Map).cast<String, Object?>())],
          currentId: j['current'] as String?,
          onboardingDone: j['onboardingDone'] == true,
        );
      } catch (e) {
        debugPrint('rasq accounts: corrupt storage, starting fresh: $e');
      }
    }
    // 移行: 台帳が無く SNS セッションが既にある端末は、従来のバンドルを
    // そのまま「この端末のみ」の RASQ アカウントにする(オンボーディングは
    // 出さない — 既存ユーザーに作成を迫らない)。セッションも無ければ
    // 空のまま返し、オンボーディングへ。
    final existing = await _existingSessionKeys(storage);
    if (existing.isEmpty) return const RasqAccountsState();
    final migrated = RasqAccountsState(
      accounts: [RasqAccountRecord(id: localId, kind: RasqAccountKind.local, sessionKeys: existing, createdAt: DateTime.now())],
      currentId: localId,
      onboardingDone: true,
    );
    await _write(storage, migrated);
    return migrated;
  }

  /// `rasq.sessions.v1` を生で読む(SessionsNotifier はこちらを watch するので、
  /// 逆向きにプロバイダーを読むと循環する)。
  Future<List<String>> _existingSessionKeys(SessionStorage storage) async {
    final raw = await storage.read(SessionsNotifier.storageKey);
    if (raw == null) return const [];
    try {
      final j = (jsonDecode(raw) as Map).cast<String, Object?>();
      return [
        for (final s in (j['sessions'] as List? ?? const [])) AccountSession.fromJson((s as Map).cast<String, Object?>()).account.key,
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> _write(SessionStorage storage, RasqAccountsState s) =>
      storage.write(storageKey, jsonEncode({'accounts': [for (final a in s.accounts) a.toJson()], 'current': s.currentId, 'onboardingDone': s.onboardingDone}));

  Future<void> _persist(RasqAccountsState s) async {
    state = AsyncData(s);
    await _write(ref.read(sessionStorageProvider), s);
  }

  RasqAccountsState get _cur => state.value ?? const RasqAccountsState();

  /// [keys] にもう一度ログインした / 入れた: ログアウトの控え (D-461 [RasqAccountRecord.bundleRemovals]) から外す。
  static List<String> _unremoved(RasqAccountRecord a, Iterable<String> keys) => [for (final k in a.bundleRemovals) if (!keys.contains(k)) k];

  /// 「この端末のみ」のアカウントを用意する(無ければ作る)。
  Future<RasqAccountRecord> ensureLocal() async {
    final cur = _cur;
    final found = cur.accounts.where((a) => a.id == localId).firstOrNull;
    if (found != null) return found;
    final rec = RasqAccountRecord(id: localId, kind: RasqAccountKind.local, createdAt: DateTime.now());
    await _persist(cur.copyWith(accounts: [...cur.accounts, rec], currentId: cur.currentId ?? rec.id));
    return rec;
  }

  /// オンボーディング完了(作成でもスキップでも)。スキップ = ローカルで使う。
  Future<void> completeOnboarding({bool skipped = false}) async {
    if (skipped) await ensureLocal();
    await _persist(_cur.copyWith(onboardingDone: true));
  }

  /// Central のアカウントを台帳に載せて現在にする。既定では**現在のアカウントの SNS
  /// セッションをそのまま引き継ぐ**(端末ローカルから Central へ「昇格」する
  /// 使い方 = 新規登録 — バンドルが空になって再ログインを迫られないように)。
  ///
  /// [inheritSessions] = false は登録の FOW で「置き換えない」を選んだとき (D-241) と、**既存のアカウントへのログイン**
  /// (D-316: 前のアカウントの SNS を持ち込まない)。[pruneBundle] = サーバーのバンドルを、この端末の SNS アカウントで
  /// 置き換えるか(省けば [inheritSessions] と同じ)。[adoptKeys] = そのアカウントに入れる SNS セッション。ログインでは使わない
  /// (D-461: この端末の SNS は本人が選んだものだけを、あとから [addCentralSessionKeys] で移す)。
  Future<RasqAccountRecord> attachCentral({
    required String centralAccountId,
    required String handle,
    required String displayName,
    Uri? avatarUrl,
    bool inheritSessions = true,
    bool? pruneBundle,
    List<String> adoptKeys = const [],
  }) async {
    final cur = _cur;
    final id = 'central-$centralAccountId';
    final existing = cur.accounts.where((a) => a.id == id).firstOrNull;
    if (existing != null) {
      final updated = existing.copyWith(
          handle: handle, displayName: displayName, avatarUrl: avatarUrl, sessionKeys: {...existing.sessionKeys, ...adoptKeys}.toList(), bundleRemovals: _unremoved(existing, adoptKeys));
      await _persist(cur.copyWith(accounts: [for (final a in cur.accounts) a.id == id ? updated : a], currentId: id));
      return updated;
    }
    final inherited = {...inheritSessions ? (cur.current?.sessionKeys ?? const <String>[]) : const <String>[], ...adoptKeys}.toList();
    final rec = RasqAccountRecord(
      id: id,
      kind: RasqAccountKind.central,
      handle: handle,
      displayName: displayName,
      avatarUrl: avatarUrl,
      centralAccountId: centralAccountId,
      sessionKeys: inherited,
      pruneBundle: pruneBundle ?? inheritSessions,
      createdAt: DateTime.now(),
    );
    await _persist(cur.copyWith(accounts: [...cur.accounts, rec], currentId: id, onboardingDone: true));
    return rec;
  }

  /// Central からログアウト / 削除: 台帳から外す。
  ///
  /// [keepSessions] = true(「この端末のみ に移す」)なら、その SNS セッションは「この端末のみ」の行へ移す。false
  /// (「SNS アカウントもログアウトする」、D-409)なら移さない(セッションそのものは呼ぶ側が先に端末から消す —
  /// [releaseRasqAccount])。どちらでも、**ほかの Central のアカウントの行へは入れない**。
  ///
  /// 外したのがいまのアカウントなら、次は (1)「この端末のみ」に SNS があればそこ、(2) 無ければ、この端末がトークンを
  /// 持っている([signedInCentral])ほかの Central のアカウント(その行の SNS だけが見える)、(3) どちらも無ければ
  /// 「この端末のみ」(SNS が無いので入口 = オンボーディングへ)。
  Future<void> detachCentral(String id, {bool keepSessions = true, Set<String> signedInCentral = const {}}) async {
    final cur = _cur;
    final gone = cur.accounts.where((a) => a.id == id).firstOrNull;
    if (gone == null) return;
    final wasCurrent = cur.current?.id == id;
    final rest = [for (final a in cur.accounts) if (a.id != id) a];
    var local = rest.where((a) => a.id == localId).firstOrNull;
    if (keepSessions && gone.sessionKeys.isNotEmpty) {
      local = (local ?? RasqAccountRecord(id: localId, kind: RasqAccountKind.local, createdAt: DateTime.now()))
          .copyWith(sessionKeys: {...?local?.sessionKeys, ...gone.sessionKeys}.toList());
    }
    var next = cur.currentId;
    if (wasCurrent) {
      final other = rest.where((a) => a.isCentral && signedInCentral.contains(a.centralAccountId)).firstOrNull;
      if (local != null && local.sessionKeys.isNotEmpty) {
        next = localId;
      } else if (other != null) {
        next = other.id;
      } else {
        local ??= RasqAccountRecord(id: localId, kind: RasqAccountKind.local, createdAt: DateTime.now());
        next = localId;
      }
    }
    final accounts = [for (final a in rest) if (a.id != localId) a, ?local];
    await _persist(cur.copyWith(accounts: accounts, currentId: next));
  }

  Future<void> select(String id) async {
    final cur = _cur;
    if (cur.currentId == id || !cur.accounts.any((a) => a.id == id)) return;
    await _persist(cur.copyWith(currentId: id));
  }

  /// Central のプロフィール(`GET /me`)を、その行へ写す (D-316)。使っていないアカウントの行(サイドバー / アカウントの FOW)は
  /// 台帳の値で出すので、ほかの端末で変えた名前もここで追いつく。同じなら何もしない。
  Future<void> syncCentralProfile(String centralAccountId, {required String handle, required String displayName, Uri? avatarUrl}) async {
    final cur = state.value;
    final rec = cur?.centralRecord(centralAccountId);
    if (cur == null || rec == null) return;
    if (rec.handle == handle && rec.displayName == displayName && rec.avatarUrl == avatarUrl) return;
    await _persist(cur.copyWith(accounts: [
      for (final a in cur.accounts) a.id == rec.id ? a.copyWith(handle: handle, displayName: displayName, avatarUrl: avatarUrl, clearAvatar: avatarUrl == null) : a,
    ]));
  }

  /// 表示名/ハンドルの更新(ローカルはここが正本、Central は PATCH /me の結果を写す)。
  Future<void> updateProfile(String id, {String? handle, String? displayName, Uri? avatarUrl}) async {
    final cur = _cur;
    await _persist(cur.copyWith(accounts: [
      for (final a in cur.accounts) a.id == id ? a.copyWith(handle: handle, displayName: displayName, avatarUrl: avatarUrl) : a,
    ]));
  }

  /// SNS ログインが増えた: 現在の RASQ アカウントに所属させる。台帳が空なら
  /// 「この端末のみ」を作って入れる。
  Future<void> addSessionKey(String key) async {
    var cur = _cur;
    if (cur.accounts.isEmpty) {
      await ensureLocal();
      cur = _cur;
    }
    final target = cur.current!;
    if (target.sessionKeys.contains(key)) return;
    await _persist(cur.copyWith(accounts: [
      for (final a in cur.accounts) a.id == target.id ? a.copyWith(sessionKeys: [...a.sessionKeys, key], bundleRemovals: _unremoved(a, [key])) : a,
    ]));
  }

  /// Web 版 (D-302): 保管庫でログイン中の SNS アカウント [keys] を、その保管庫の持ち主の Central のアカウント
  /// ([centralAccountId]。D-316: 「最初の」Central のアカウントではない)に所属させる。
  /// ほかのブラウザでログインしたぶんは、この端末の台帳にはまだ載っていない(載せないと、セッションはあるのに見えない)。
  /// 保管庫から消えたもの(ほかの端末でログアウト)は外す。「この端末のみ」の行からは外す(ほかの Central のアカウントの
  /// 行はそのまま — そのアカウントの保管庫を読んだときに合わせる)。台帳にそのアカウントが無ければ何もしない。
  Future<void> adoptCentralSessionKeys(List<String> keys, {required String centralAccountId}) async {
    final cur = state.value;
    final central = cur?.centralRecord(centralAccountId);
    if (cur == null || central == null) return;
    final locals = cur.accounts.where((a) => !a.isCentral && a.sessionKeys.any(keys.contains));
    if (locals.isEmpty && central.sessionKeys.length == keys.length && central.sessionKeys.toSet().containsAll(keys)) return;
    await _persist(cur.copyWith(accounts: [
      for (final a in cur.accounts)
        if (a.id == central.id)
          a.copyWith(sessionKeys: keys, bundleRemovals: _unremoved(a, keys))
        else if (!a.isCentral)
          a.copyWith(sessionKeys: [for (final k in a.sessionKeys) if (!keys.contains(k)) k])
        else
          a,
    ]));
  }

  /// SNS のアクセストークンの端末間共有 (D-319): ほかの端末から取り込んだ SNS セッション [keys] を、その Central のアカウント
  /// ([centralAccountId]) の行に足す。「この端末のみ」の行にあれば、そちらからは外す(同じ SNS を 2 か所に数えない)。
  /// 台帳にそのアカウントが無ければ何もしない。
  Future<void> addCentralSessionKeys(List<String> keys, {required String centralAccountId}) async {
    final cur = state.value;
    final central = cur?.centralRecord(centralAccountId);
    if (cur == null || central == null || keys.isEmpty) return;
    await _persist(cur.copyWith(accounts: [
      for (final a in cur.accounts)
        if (a.id == central.id)
          a.copyWith(sessionKeys: {...a.sessionKeys, ...keys}.toList(), bundleRemovals: _unremoved(a, keys))
        else if (!a.isCentral)
          a.copyWith(sessionKeys: [for (final k in a.sessionKeys) if (!keys.contains(k)) k])
        else
          a,
    ]));
  }

  /// SNS ログアウト: どのアカウントからも外す。
  ///
  /// [unlink] = この端末で、その SNS アカウントからログアウトした(SNS のアカウントの一覧の「ログアウト」)。それを持っていた
  /// Central のアカウントの行に控えを残し、次のバンドルの同期でサーバーからも外す (D-461)。RASQ アカウントからのログアウト
  /// (D-409) / ほかの端末でのログアウトの取り込み (D-319) では残さない(前者はアカウントのバンドルを変えない、後者は
  /// ログアウトした端末が外す)。
  Future<void> removeSessionKey(String key, {bool unlink = false}) async {
    final cur = _cur;
    if (!cur.accounts.any((a) => a.sessionKeys.contains(key))) return;
    await _persist(cur.copyWith(accounts: [
      for (final a in cur.accounts)
        a.copyWith(
          sessionKeys: [for (final k in a.sessionKeys) if (k != key) k],
          bundleRemovals: unlink && a.isCentral && a.sessionKeys.contains(key) && !a.bundleRemovals.contains(key) ? [...a.bundleRemovals, key] : null,
        ),
    ]));
  }

  /// バンドルの同期 (D-461) が、サーバーから外せた(か、もともと無かった)ログアウトの控えを消す。変わらなければ書かない。
  Future<void> clearBundleRemovals(String centralAccountId, Iterable<String> keys) async {
    final cur = state.value;
    final rec = cur?.centralRecord(centralAccountId);
    if (cur == null || rec == null || !rec.bundleRemovals.any(keys.contains)) return;
    await _persist(cur.copyWith(accounts: [for (final a in cur.accounts) a.id == rec.id ? a.copyWith(bundleRemovals: _unremoved(a, keys)) : a]));
  }
}

final rasqAccountsProvider = AsyncNotifierProvider<RasqAccountsNotifier, RasqAccountsState>(RasqAccountsNotifier.new);

/// 現在の RASQ アカウント(台帳がまだ無ければ null)。
final currentRasqAccountProvider = Provider<RasqAccountRecord?>((ref) => ref.watch(rasqAccountsProvider).value?.current);
