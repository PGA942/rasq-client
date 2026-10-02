import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../backend/orgate_client.dart';
import '../backend/rasq_account.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart' show AccountSession;

import 'rasq_accounts.dart';
import 'session_providers.dart';
import 'session_storage.dart';

/// Web 版の保存先 (D-300 / S-033): **SNS のログイン情報(アクセストークン入り)はブラウザに置かず、RASQ アカウントの保管庫 (ORGATE、D-399) に預ける**。
///
/// - 預けるのは [vaulted] のキーだけ(SNS のセッション一覧)。RASQ 自身のトークンなど、ほかのキーは [local](ブラウザ)に置く —
///   保管庫を開くのに RASQ のトークンが要るので。
/// - RASQ アカウントにログインしていない間は、メモリにだけ持つ(タブを閉じると消える。Web 版は RASQ アカウントでのログインが前提)。
///   ログインしたら、メモリのぶんを預ける。RASQ アカウントが変わったら、SNS のセッションを読み直す。
/// - 保管庫は **Central のアカウントごと** (D-316)。読み書きは、そのときのアカウントのトークンに縛った口で行い、
///   アカウントを切り替えたら「最後に知った状態」も捨てる(前のアカウントのログインを、次のアカウントの保管庫へ持ち込まない)。
/// - 前の版(ブラウザに置いていた)のぶんが残っていれば、保管庫へ移してブラウザからは消す。
class CentralVaultSessionStorage implements SessionStorage {
  CentralVaultSessionStorage(this._ref, this.local, {this.pollInterval = const Duration(seconds: 45)}) {
    // RASQ アカウントの読み込みは、この保存先を読む。作っている最中に読ませないよう、見張りはひと呼吸おいてから始める。
    Future.microtask(_watchAccount);
  }

  void _watchAccount() {
    if (!_ref.mounted) return;
    // [orgateAccountProvider] は listen しない(このプロバイダーは、アカウントの読み込みから読まれる。listen すると循環になる)。
    // 代わりに、トークンの箱が知らせる「いまのアカウント」を見る。
    final holder = _ref.read(orgateTokenHolderProvider);
    var prev = holder.accountId;
    void onChange() {
      final next = holder.accountId;
      if (prev == next) return;
      prev = next;
      Future.microtask(() => _onAccountChanged(next));
    }

    holder.addListener(onChange);
    _ref.onDispose(() => holder.removeListener(onChange));
  }

  Future<void> _onAccountChanged(String? next) async {
    if (!_ref.mounted) return;
    _known = SessionOps();
    _knownFor = null;
    if (next != null) {
      // ログインした: ログイン前(持ち主なし)にメモリにだけ持っていたぶんを預ける(ログインしたら預ける、という約束どおり)。
      // 別のアカウントが預け損ねたぶん(SNS のトークン入り)は、このアカウントの保管庫へ持ち込まない (D-407、指摘 #20)。
      // そのアカウントに戻るまでメモリに残し(ログアウトで消える)、戻ったら read が保管庫の台帳に重ねて預け直す。
      for (final e in [for (final e in _memory.entries) if (e.key.owner == null) e]) {
        if (await _put(e.key.key, e.value, owner: next) && identical(_memory[e.key], e.value)) _memory.remove(e.key);
      }
    } else {
      _memory.clear();
    }
    if (_ref.mounted) _ref.invalidate(sessionsProvider);
  }

  final Ref _ref;
  final SessionStorage local;

  /// ほかの端末の操作を見に行く間隔(0 = 見に行かない。テスト用)。
  final Duration pollInterval;
  /// 保管庫へ預けられなかった / まだ預けられないぶん。[owner] = 預けるはずだった Central のアカウント
  /// (null = RASQ アカウントにログインする前に持ったもの)。持ち主の違う保管庫へは預けない (D-407、指摘 #20)。
  final Map<({String key, String? owner}), String> _memory = {};

  /// [owner] の保管庫へ預けてよい(= そのアカウントのもの、無ければログイン前の)メモリのぶんの置き場所。
  ({String key, String? owner})? _memorySlotFor(String key, String? owner) {
    if (owner != null && _memory.containsKey((key: key, owner: owner))) return (key: key, owner: owner);
    if (_memory.containsKey((key: key, owner: null))) return (key: key, owner: null);
    return null;
  }

  String? _memoryFor(String key, String? owner) => _memory[_memorySlotFor(key, owner)];

  /// [owner] のぶんとログイン前のぶんを消す(保管庫へ預け終えた)。ほかのアカウントのぶんは残す。
  void _forgetMemory(String key, String? owner) {
    _memory.remove((key: key, owner: owner));
    _memory.remove((key: key, owner: null));
  }

  /// いまのアカウント(トークンの箱が知らせるもの)。保管庫の口が作れないときに、メモリのぶんの持ち主として使う。
  String? get _holderAccountId => _ref.read(orgateTokenHolderProvider).accountId;

  static const vaulted = {SessionsNotifier.storageKey};

  /// いまの Central のアカウントと、そのトークンに縛った口。ログインしていなければ null。
  Future<({OrgateClient client, String accountId})?> _client() async {
    final String? accountId;
    try {
      accountId = (await _ref.read(orgateAccountProvider.future))?.id;
    } catch (_) {
      return null;
    }
    if (accountId == null) return null;
    final token = _ref.read(orgateAccountProvider.notifier).tokenFor(accountId);
    // 保管庫は ORGATE (D-399、本人だけが見る情報)。
    final base = _ref.read(orgateClientProvider);
    if (base == null || token == null) return null;
    return (client: base.withToken(() => token), accountId: accountId);
  }

  /// [owner] の保管庫へ預ける。いまのアカウントが [owner] でなければ預けない(切り替わった後に前のアカウントのぶんを
  /// 次のアカウントへ書かない)。
  Future<bool> _put(String key, String value, {required String owner}) async {
    final c = await _client();
    if (c == null || c.accountId != owner) return false;
    return _putWith(c.client, key, value);
  }

  Future<bool> _putWith(OrgateClient client, String key, String value) async {
    try {
      await client.putJson('/me/vault/$key', {'value': value});
      return true;
    } on OrgateException catch (e) {
      debugPrint('RASQ: ログイン情報を保管庫へ預けられませんでした: ${e.message}');
      return false;
    }
  }

  /// 保管庫の中身を読む。無ければ空の台帳。読めなければ null。
  Future<SessionOps?> _fetch(OrgateClient client, String key) async {
    try {
      final value = (await client.getJson('/me/vault/$key'))['value'];
      return value is String ? SessionOps.parse(value) : SessionOps();
    } on OrgateException catch (e) {
      if (e.code.code == '404') return SessionOps();
      debugPrint('RASQ: 保管庫を読めませんでした: ${e.message}');
      return null;
    }
  }

  /// この端末(タブ)が最後に知った状態。ログイン / ログアウトの操作は、これとの差から起こす。
  SessionOps _known = SessionOps();

  /// [_known] がどの Central のアカウントの保管庫のものか。
  String? _knownFor;

  /// [accountId] の保管庫を触る前に: 別のアカウントの「最後に知った状態」なら捨てる。
  void _forAccount(String accountId) {
    if (_knownFor == accountId) return;
    _known = SessionOps();
    _knownFor = accountId;
  }
  Timer? _poll;

  @override
  Future<String?> read(String key) async {
    if (!vaulted.contains(key)) return local.read(key);
    final c = await _client();
    if (c == null) return _memoryFor(key, _holderAccountId);
    final client = c.client;
    _forAccount(c.accountId);
    final remote = await _fetch(client, key);
    if (remote == null) return _memoryFor(key, c.accountId) ?? _known.toSessionsJson();
    // 前の版がブラウザ / メモリに置いていたぶんがあれば、操作として足してから、ブラウザのぶんを消す。
    // メモリのぶんは、このアカウントのもの / ログイン前のものだけ(別のアカウントのぶんは混ぜない、指摘 #20)。
    final slot = _memorySlotFor(key, c.accountId);
    final memOld = _memory[slot];
    final old = memOld ?? await local.read(key);
    if (old != null) {
      final merged = remote.merged(SessionOps().applying(old, at: DateTime.fromMillisecondsSinceEpoch(0)));
      if (await _putWith(client, key, merged.encode())) {
        if (slot != null && identical(_memory[slot], memOld)) _memory.remove(slot);
        await local.delete(key);
      }
      _known = merged;
    } else {
      _known = remote;
    }
    _startPolling(key);
    _adoptKeys(c.accountId);
    return _known.toSessionsJson();
  }

  @override
  Future<void> write(String key, String value) async {
    if (!vaulted.contains(key)) return local.write(key, value);
    final c = await _client();
    if (c == null) {
      _memory[(key: key, owner: _holderAccountId)] = value;
      return;
    }
    final client = c.client;
    _forAccount(c.accountId);
    // いま保管庫にある台帳に、この端末の操作(知っていた状態との差)を重ねる。ほかの端末の操作は消さない。
    final mine = _known.applying(value, at: DateTime.now());
    final remote = await _fetch(client, key);
    final merged = (remote ?? SessionOps()).merged(mine).pruned(DateTime.now());
    if (await _putWith(client, key, merged.encode())) {
      _forgetMemory(key, c.accountId);
    } else {
      // 預け直しは、このアカウントの保管庫へだけ(別のアカウントへ切り替わったら持ち込まない、指摘 #20)。
      _memory[(key: key, owner: c.accountId)] = value;
    }
    final changedElsewhere = !merged.sameLoginsAs(mine);
    _known = merged;
    _adoptKeys(c.accountId);
    // ほかの端末でのログイン / ログアウトが混ざっていたら、画面にも反映する。
    if (changedElsewhere) Future.microtask(() => _ref.mounted ? _ref.invalidate(sessionsProvider) : null);
  }

  @override
  Future<void> delete(String key) async {
    if (!vaulted.contains(key)) return local.delete(key);
    _forgetMemory(key, _holderAccountId);
    // 全部ログアウトした、という操作として残す(保管庫ごと消すと、ほかの端末の古い状態が生き返る)。
    await write(key, '{"sessions":[]}');
  }

  /// ほかの端末でのログイン / ログアウトを拾う: ときどき保管庫を見て、変わっていたらセッションを読み直す。
  void _startPolling(String key) {
    if (_poll != null || pollInterval == Duration.zero) return;
    _poll = Timer.periodic(pollInterval, (_) async {
      if (!_ref.mounted) return;
      final c = await _client();
      if (c == null || c.accountId != _knownFor) return;
      final remote = await _fetch(c.client, key);
      if (remote != null && _ref.mounted && c.accountId == _knownFor && !remote.sameLoginsAs(_known)) _ref.invalidate(sessionsProvider);
    });
    _ref.onDispose(() => _poll?.cancel());
  }

  /// 保管庫でログイン中の SNS アカウントを、この端末の台帳の RASQ アカウントに所属させる
  /// (別のブラウザでログインしたぶんは、こちらの台帳にはまだ載っていない — 載せないと、あるのに見えない)。
  /// [accountId] = 読んだ保管庫の持ち主(D-316: 読んでいるあいだに切り替わっても、別のアカウントの行へ入れない)。
  void _adoptKeys(String accountId) {
    final keys = _known.loggedInKeys;
    Future.microtask(() async {
      if (!_ref.mounted) return;
      await _ref.read(rasqAccountsProvider.notifier).adoptCentralSessionKeys(keys, centralAccountId: accountId);
    });
  }
}

/// SNS のログイン / ログアウトの**操作の台帳** (D-302)。アカウントごとに、最後の操作(ログイン + そのセッション / ログアウト)と時刻を持つ。
/// 端末どうしは、アカウントごとに**新しいほうの操作**を取って混ぜる — 「最後に保存した端末の一覧で上書き」にしない
/// (A でログインした直後に、古い一覧を持った B が何かを保存しても、A のログインは消えない。B でのログアウトも A に伝わる)。
class SessionOps {
  SessionOps({Map<String, SessionOp>? ops, this.current, this.bundle = false}) : ops = ops ?? {};
  final Map<String, SessionOp> ops;
  final String? current;
  final bool bundle;

  /// ログアウトの記録を残しておく期間(これより古い端末の一覧が生き返ることは、まず無い)。
  static const tombstoneDays = 30;

  List<String> get loggedInKeys => [for (final e in _logins) e.key];

  Iterable<MapEntry<String, SessionOp>> get _logins {
    final l = [for (final e in ops.entries) if (e.value.session != null) e];
    l.sort((a, b) => a.value.at.compareTo(b.value.at));
    return l;
  }

  /// 保存の形(v2)か、前の版(`{"sessions":[…]}` そのまま = 全部ログイン、時刻は分からない)。
  static SessionOps parse(String raw) {
    try {
      final j = (jsonDecode(raw) as Map).cast<String, Object?>();
      if (j['v'] == 2) {
        return SessionOps(
          ops: {
            for (final e in ((j['ops'] as Map?) ?? const {}).entries)
              if (e.value is Map) '${e.key}': SessionOp.fromJson((e.value as Map).cast<String, Object?>()),
          },
          current: j['current'] as String?,
          bundle: j['bundle'] == true,
        );
      }
      return SessionOps().applying(raw, at: DateTime.fromMillisecondsSinceEpoch(0));
    } catch (e) {
      debugPrint('RASQ: 保管庫の中身を読めませんでした(空として扱います): $e');
      return SessionOps();
    }
  }

  String encode() => jsonEncode({'v': 2, 'ops': {for (final e in ops.entries) e.key: e.value.toJson()}, 'current': current, 'bundle': bundle});

  /// アプリのセッション一覧(`SessionsNotifier` の保存の形)へ。ログインした順。
  String toSessionsJson() => jsonEncode({'sessions': [for (final e in _logins) e.value.session], 'current': ops[current]?.session != null ? current : null, 'bundle': bundle});

  /// アプリが保存しようとした一覧 [sessionsJson] との差を、操作にする: 増えた / 中身が変わった = ログイン、消えた = ログアウト。
  SessionOps applying(String sessionsJson, {required DateTime at}) {
    final j = (jsonDecode(sessionsJson) as Map).cast<String, Object?>();
    final next = <String, Map<String, Object?>>{};
    for (final s in (j['sessions'] as List? ?? const [])) {
      final m = (s as Map).cast<String, Object?>();
      next[AccountSession.fromJson(m).account.key] = m;
    }
    final out = Map<String, SessionOp>.of(ops);
    for (final e in next.entries) {
      final had = out[e.key]?.session;
      if (had == null || jsonEncode(had) != jsonEncode(e.value)) out[e.key] = SessionOp(at: at, session: e.value);
    }
    for (final k in ops.keys) {
      if (ops[k]!.session != null && !next.containsKey(k)) out[k] = SessionOp(at: at);
    }
    return SessionOps(ops: out, current: j['current'] as String? ?? current, bundle: j.containsKey('bundle') ? j['bundle'] == true : bundle);
  }

  /// アカウントごとに、新しいほうの操作を取る。表示中のアカウント / 総合表示は [mine] のものを優先。
  SessionOps merged(SessionOps mine) {
    final out = Map<String, SessionOp>.of(ops);
    for (final e in mine.ops.entries) {
      final theirs = out[e.key];
      if (theirs == null || !theirs.at.isAfter(e.value.at)) out[e.key] = e.value;
    }
    return SessionOps(ops: out, current: mine.current ?? current, bundle: mine.bundle);
  }

  /// 古いログアウトの記録を捨てる。
  SessionOps pruned(DateTime now) => SessionOps(
        ops: {for (final e in ops.entries) if (e.value.session != null || now.difference(e.value.at).inDays < tombstoneDays) e.key: e.value},
        current: current,
        bundle: bundle,
      );

  /// ログイン中のアカウントと、その中身(トークン)が同じか。
  bool sameLoginsAs(SessionOps other) => jsonEncode({for (final e in _logins) e.key: e.value.session}) == jsonEncode({for (final e in other._logins) e.key: e.value.session});
}

/// 1 つの SNS アカウントへの最後の操作。[session] があればログイン、無ければログアウト。
class SessionOp {
  const SessionOp({required this.at, this.session});
  final DateTime at;
  final Map<String, Object?>? session;

  static SessionOp fromJson(Map<String, Object?> j) => SessionOp(
        at: DateTime.tryParse('${j['at']}')?.toUtc() ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        session: j['op'] == 'login' && j['session'] is Map ? (j['session'] as Map).cast<String, Object?>() : null,
      );

  Map<String, Object?> toJson() => {'op': session != null ? 'login' : 'logout', 'at': at.toUtc().toIso8601String(), 'session': ?session};
}
