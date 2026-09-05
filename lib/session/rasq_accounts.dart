import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart' show AccountSession;

import 'session_providers.dart';
import 'session_storage.dart';

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
///   端末資格情報は [OrgateAccountNotifier] が持つ(1 台に 1 つ)。
///
/// 永続化は KV `rasq.accounts.v1`(セキュアストレージ)。SNS セッションの
/// 実体は従来どおり `rasq.sessions.v1` にあり、こちらは**所属(キー)**だけを
/// 持つ。[SessionsNotifier] はこの台帳を見て、現在の RASQ アカウントに属する
/// セッションだけを `sessions` として見せる。
enum RasqAccountKind {
  local('local', 'この端末のみ'),
  central('central', 'RASQ Central');

  const RasqAccountKind(this.wire, this.label);
  final String wire;
  final String label;
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
  final DateTime createdAt;

  bool get isCentral => kind == RasqAccountKind.central;

  RasqAccountRecord copyWith({String? handle, String? displayName, Uri? avatarUrl, List<String>? sessionKeys, bool clearAvatar = false}) => RasqAccountRecord(
        id: id,
        kind: kind,
        handle: handle ?? this.handle,
        displayName: displayName ?? this.displayName,
        avatarUrl: clearAvatar ? null : (avatarUrl ?? this.avatarUrl),
        centralAccountId: centralAccountId,
        sessionKeys: sessionKeys ?? this.sessionKeys,
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
  RasqAccountRecord? get central => accounts.where((a) => a.isCentral).firstOrNull;

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

  /// Central のアカウントを台帳に載せて現在にする。**現在のアカウントの SNS
  /// セッションはそのまま引き継ぐ**(端末ローカルから Central へ「昇格」する
  /// 使い方が基本 — バンドルが空になって再ログインを迫られないように)。
  Future<RasqAccountRecord> attachCentral({required String centralAccountId, required String handle, required String displayName, Uri? avatarUrl, bool inheritSessions = true}) async {
    final cur = _cur;
    final id = 'central-$centralAccountId';
    final existing = cur.accounts.where((a) => a.id == id).firstOrNull;
    if (existing != null) {
      final updated = existing.copyWith(handle: handle, displayName: displayName, avatarUrl: avatarUrl);
      await _persist(cur.copyWith(accounts: [for (final a in cur.accounts) a.id == id ? updated : a], currentId: id));
      return updated;
    }
    final inherited = inheritSessions ? (cur.current?.sessionKeys ?? const <String>[]) : const <String>[];
    final rec = RasqAccountRecord(
      id: id,
      kind: RasqAccountKind.central,
      handle: handle,
      displayName: displayName,
      avatarUrl: avatarUrl,
      centralAccountId: centralAccountId,
      sessionKeys: inherited,
      createdAt: DateTime.now(),
    );
    await _persist(cur.copyWith(accounts: [...cur.accounts, rec], currentId: id, onboardingDone: true));
    return rec;
  }

  /// Central からログアウト: 台帳から外し、その SNS セッションは「この端末のみ」
  /// へ戻す(端末から SNS ログインは消えない)。
  Future<void> detachCentral(String id) async {
    final cur = _cur;
    final gone = cur.accounts.where((a) => a.id == id).firstOrNull;
    if (gone == null) return;
    var rest = [for (final a in cur.accounts) if (a.id != id) a];
    final local = rest.where((a) => a.id == localId).firstOrNull ?? RasqAccountRecord(id: localId, kind: RasqAccountKind.local, createdAt: DateTime.now());
    final merged = local.copyWith(sessionKeys: {...local.sessionKeys, ...gone.sessionKeys}.toList());
    rest = [for (final a in rest) if (a.id != localId) a, merged];
    await _persist(cur.copyWith(accounts: rest, currentId: cur.currentId == id ? localId : cur.currentId));
  }

  Future<void> select(String id) async {
    final cur = _cur;
    if (cur.currentId == id || !cur.accounts.any((a) => a.id == id)) return;
    await _persist(cur.copyWith(currentId: id));
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
      for (final a in cur.accounts) a.id == target.id ? a.copyWith(sessionKeys: [...a.sessionKeys, key]) : a,
    ]));
  }

  /// SNS ログアウト: どのアカウントからも外す。
  Future<void> removeSessionKey(String key) async {
    final cur = _cur;
    if (!cur.accounts.any((a) => a.sessionKeys.contains(key))) return;
    await _persist(cur.copyWith(accounts: [
      for (final a in cur.accounts) a.copyWith(sessionKeys: [for (final k in a.sessionKeys) if (k != key) k]),
    ]));
  }
}

final rasqAccountsProvider = AsyncNotifierProvider<RasqAccountsNotifier, RasqAccountsState>(RasqAccountsNotifier.new);

/// 現在の RASQ アカウント(台帳がまだ無ければ null)。
final currentRasqAccountProvider = Provider<RasqAccountRecord?>((ref) => ref.watch(rasqAccountsProvider).value?.current);
