import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show SnackBar, Text;
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart' show AccountSession;

import '../app/providers.dart' show overlayManagerProvider;
import '../backend/orgate_client.dart';
import '../backend/rasq_account.dart';
import '../features/child_safe/child_safe_providers.dart' show childSnsAllowProvider;
import '../features/plugins/slot_plugins.dart' show rootMessengerKeyProvider;
import '../notify/central_inbox.dart' show CentralNotice;
import 'central_vault_storage.dart' show SessionOp, SessionOps;
import 'rasq_accounts.dart';
import 'session_providers.dart';
import 'session_storage.dart';
import 'sns_share_crypto.dart';
import '../l10n/l10n.dart';

/// SNS のアクセストークンの端末間共有 (D-319、ORGATE `GET|PUT /me/sns-share*`。D-399 で Central から移った)。**E2E**。
///
/// 別の端末で RASQ アカウントにログインすると、SNS のアカウントはログインボタンが出るだけだった (D-316)。
/// 元の端末で承認すると、新しい端末もそのトークンで SNS アカウントに一斉ログインする。
///
/// - 端末の鍵: Central のアカウントごとに X25519 の鍵ペア。秘密鍵(種)は端末の安全な保存先 ([sessionStorageProvider]) に置き、
///   公開鍵だけを ORGATE に置く。Web 版もブラウザ側の保存先(保管庫へ預けるのは SNS のセッション一覧だけ。D-300)。
/// - 共有の本体: アカウントの共有鍵 K で AES-GCM した [SessionOps](ログイン / ログアウトの台帳)。ORGATE の `/me/data/sns.share.v1`。
///   K は端末ごとに、その端末の公開鍵で包んで ORGATE に置く。**ORGATE は K も平文も見ない** ([SnsShareCrypto])。
/// - 状態(ORGATE): `off`(アカウントを作ったとき)/ `on` / `declined`。
/// - 見回り([check]): 起動 / アプリへ戻ったとき / アカウントの切り替え / [snsSharePollIntervalProvider] ごと(保管庫の見回りと同じ 45 秒)。
///   いま使っている Central のアカウントについて行う(共有はアカウントごと。切り替えると、そのアカウントの分を確かめる)。
///   - 共有を求めている端末(新しくログインした端末)があって、状態が `off` なら、この端末で「アクセストークンを共有して、SNS アカウントに
///     一斉ログインしますか?」。はい → `on`、K を作って自分と相手に包み、本体を上げる。いいえ → `declined`(以後は自動で聞かない)。
///   - `on` で、この端末が K を持っていれば、求めている端末ごとに「新しい端末(名前)にも SNS のアクセストークンを共有しますか?」。
///     サーバーが勝手に配る形にはしない(RASQ のパスワードが漏れただけで、SNS のトークンまで渡らないように)。
///   - K を持っていれば、本体と、この端末の SNS のログイン / ログアウトを混ぜる([mergeSnsShare])。
/// - ログアウトは、ログアウトの記録(時刻つき)として本体に残し、ほかの端末でもログアウトにする(古い一覧を持った端末が、
///   次に本体を書くときに蘇らせない。30 日で捨てる。捨てたあとも、同期したことのあるアカウントが本体から消えていれば外す)。
/// - **承認の問いを早く** (D-322): 新しい端末が共有を求めると、ORGATE が Central の受信箱に積んで同じアカウントの端末へ知らせる(受信箱の
///   `sns_share.request`)。開いているアプリには即時の知らせ([CentralInbox] の長いポーリング)ですぐ届き、[handleSnsShareNotices] が
///   すぐ見回って問いを出す(45 秒の見回りを待たない)。
/// - **メールでの承認** (D-422 / ORGATE O-012 / Central S-078): 求めると確認済みのメールへ 1 回きりのリンクが届き、ブラウザで
///   RASQ アカウントにログインして「承認して共有する / 承認する(SNS はこの端末でログインし直す)/ 心当たりが無い」を選べる。
///   サーバーは K もトークンも見ない(印を付けるだけ)。K を持つ端末は印のある端末に問いを出さずに包む。K を持つ端末が 1 台も
///   無ければ、SNS にログインしている端末が K を作り直す。どの端末も開かれていなければ、新しい端末は待つか、自分で SNS にログインする。求めている端末の側も、承認を待っている間は [snsSharePollWhileWaitingProvider] おきに
///   見回って(上限つき)、承認されたらすぐ取り込む。取り込んだら [SnsShareView.joins] を進め、SNS のログイン画面は TL へ移る。
/// - **署名と、受け取るときの検査** (D-547 / Codex Security #17 / ORGATE O-020): 端末ごとに Ed25519 の署名鍵も持ち、公開鍵を
///   X25519 の公開鍵と一緒に登録する。K を包むときは包みに署名し([SnsShareCrypto.wrapMessage])、受け取るときは、包んだ端末
///   (`wrappedBy`)の署名鍵で確かめる。包んだ端末は、自分か、この端末が覚えている持ち主(まだ何も覚えていない最初の参加だけは、
///   状態で承認済みの端末)。同じ世代なのに K の指紋が違う包み・今の世代なのに開けない本体は受け取らず、何も上げずに止まって
///   知らせる([SnsShareProblem])。ログインのときは、手元の署名鍵で所持の証明を付ける(`AccountSecurityApi.login`)。

/// Central のアカウントの共有の状態。
enum SnsShareMode {
  off,
  on,
  declined;

  static SnsShareMode fromWire(Object? w) => values.where((m) => m.name == w).firstOrNull ?? off;
}

/// この端末で共有を止めた理由 (D-547)。止めている間は K を使わず、本体を読み書きせず、ほかの端末にも包まない。
/// 直すのは、持ち主の端末で共有をオフ → オンにすること(新しい世代になれば、止めたものは効かなくなる)。
enum SnsShareProblem {
  /// 同じ世代なのに K が替わった包みが届いた(共有の鍵が差し替えられた可能性)。
  keyReplaced,

  /// 今の世代の本体が、受け取った K で開けない(空として扱って上げ直さない)。
  bodyUnreadable;

  String get message => switch (this) {
        keyReplaced => appL10n.sessionShareKeyReplaced,
        bodyUnreadable => appL10n.sessionShareBodyUnreadable,
      };
}

@immutable
class SnsShareDevice {
  const SnsShareDevice({required this.deviceId, this.label, required this.publicKey, this.signingKey, this.requested = false, this.approved = false, this.current = false, this.approvedBy, this.lastUsedAt, this.emailApproved = false, this.emailDecision});
  final String deviceId;
  final String? label;
  final Uint8List publicKey;

  /// その端末の署名鍵(Ed25519 の公開鍵、D-547)。包みの署名を確かめる。
  final Uint8List? signingKey;

  /// その端末が共有を求めている(新しくログインした / 設定でオンにした)。
  final bool requested;

  /// 共有している(K が包んである)。
  final bool approved;
  final bool current;
  final String? approvedBy;
  final DateTime? lastUsedAt;

  /// メールのリンクで「承認して共有する」が選ばれた (D-422 / ORGATE O-012)。K を持つ端末は問いを出さずに包む。
  final bool emailApproved;

  /// メールのリンクでの決定(`share` / `device_only`)。`device_only` = 求めを下ろした(SNS はその端末でログインし直す)。
  final String? emailDecision;

  String get name => (label == null || label!.isEmpty) ? appL10n.sessionUnnamedDevice : label!;

  factory SnsShareDevice.fromJson(Map<String, Object?> j) => SnsShareDevice(
        deviceId: j['deviceId'] as String? ?? '',
        label: j['label'] as String?,
        publicKey: base64.decode(j['publicKey'] as String? ?? ''),
        signingKey: _bytes(j['signingKey']),
        requested: j['requested'] == true,
        approved: j['approved'] == true,
        current: j['current'] == true,
        approvedBy: j['approvedBy'] as String?,
        lastUsedAt: DateTime.tryParse(j['lastUsedAt'] as String? ?? ''),
        emailApproved: j['emailApproved'] == true,
        emailDecision: j['emailDecision'] as String?,
      );
}

Uint8List? _bytes(Object? w) {
  if (w is! String || w.isEmpty) return null;
  try {
    return base64.decode(w);
  } on FormatException {
    return null;
  }
}

@immutable
class SnsShareStatus {
  const SnsShareStatus({this.mode = SnsShareMode.off, this.keyId, this.deviceId, this.wrappedKey, this.wrappedBy, this.wrapSignature, this.devices = const []});
  final SnsShareMode mode;

  /// 今の K の世代(K を持つ端末が無ければ null)。
  final String? keyId;

  /// この端末の deviceId(ORGATE が、呼んだトークンから答える)。
  final String? deviceId;

  /// この端末あての包んだ K。
  final Uint8List? wrappedKey;

  /// [wrappedKey] を包んだ端末の deviceId と、その端末の署名 (D-547)。
  final String? wrappedBy;
  final Uint8List? wrapSignature;
  final List<SnsShareDevice> devices;

  SnsShareDevice? get me => devices.where((d) => d.current).firstOrNull;

  /// この端末が K を持っている(本体を読み書きできる)。
  bool get holding => mode == SnsShareMode.on && keyId != null && wrappedKey != null && (me?.approved ?? false);

  /// この端末が共有を求めていて、まだ承認されていない(SNS のログイン画面に案内を出す)。
  bool get waiting => mode != SnsShareMode.declined && (me?.requested ?? false) && !(me?.approved ?? false);

  /// この端末の求めが、メールのリンクで「承認する(SNS はこの端末でログインし直す)」になった (D-422)。
  bool get approvedWithoutSharing => me?.emailDecision == 'device_only' && !(me?.approved ?? false);

  /// 共有を求めている、ほかの端末。
  List<SnsShareDevice> get asking => [for (final d in devices) if (!d.current && d.requested && !d.approved) d];

  factory SnsShareStatus.fromJson(Map<String, Object?> j) => SnsShareStatus(
        mode: SnsShareMode.fromWire(j['state']),
        keyId: j['keyId'] as String?,
        deviceId: j['deviceId'] as String?,
        wrappedKey: switch (j['wrappedKey']) { final String w when w.isNotEmpty => base64.decode(w), _ => null },
        wrappedBy: j['wrappedBy'] as String?,
        wrapSignature: _bytes(j['wrapSignature']),
        devices: [for (final d in j['devices'] as List? ?? const []) if (d is Map) SnsShareDevice.fromJson(d.cast<String, Object?>())],
      );
}

/// ORGATE の口(そのアカウントのトークンに縛った [OrgateClient] で作る、D-399)。
class SnsShareApi {
  SnsShareApi(this._client);
  final OrgateClient _client;

  /// 共有の本体を置くユーザーデータの領域。
  static const bodyArea = 'sns.share.v1';

  Future<SnsShareStatus> status() async => SnsShareStatus.fromJson(await _client.getJson('/me/sns-share'));

  /// この端末の X25519 の公開鍵 [publicKey] と、署名鍵 [signingKey](D-547、必須)を置く。
  Future<SnsShareStatus> register(List<int> publicKey, {required List<int> signingKey, bool? request}) async => SnsShareStatus.fromJson(
      await _client.putJson('/me/sns-share/device', {'publicKey': base64.encode(publicKey), 'signingKey': base64.encode(signingKey), 'request': ?request}));

  Future<SnsShareStatus> setMode(SnsShareMode mode, {SnsShareMode? from}) async =>
      SnsShareStatus.fromJson(await _client.putJson('/me/sns-share/state', {'state': mode.name, 'from': ?from?.name}));

  /// [deviceId] あてに包んだ K を置く。[signature] = この端末の署名鍵での [SnsShareCrypto.wrapMessage] の署名 (D-547)。
  /// 署名が合わない = 403 `wrap_signature_invalid`、宛先にもう同じ世代の包みがある = 409 `already_wrapped`。
  Future<SnsShareStatus> wrap(String deviceId, {required String keyId, required List<int> wrappedKey, required List<int> signature}) async =>
      SnsShareStatus.fromJson(await _client.putJson('/me/sns-share/devices/${Uri.encodeComponent(deviceId)}/key', {'keyId': keyId, 'wrappedKey': base64.encode(wrappedKey), 'signature': base64.encode(signature)}));

  Future<SnsShareStatus> remove(String deviceId) async {
    await _client.delete('/me/sns-share/devices/${Uri.encodeComponent(deviceId)}');
    return status();
  }

  /// メールでの承認のリンクを、確認済みのメールへ送り直す (D-422 / ORGATE O-012)。戻り = 送った先(伏せ字)。
  Future<String> requestEmailApproval() async => '${(await _client.postJson('/me/sns-share/email-approval', const {}))['email'] ?? ''}';

  Future<({Uint8List bytes, int version})?> body() => _client.getData(bodyArea);
  Future<int?> putBody(List<int> bytes, {int? ifMatch}) => _client.putData(bodyArea, bytes, encrypted: true, ifMatch: ifMatch);
}

/// 端末に置くもの(`rasq.snsShare.v1`、[sessionStorageProvider] = ネイティブはセキュアストレージ、Web はブラウザ):
/// `{"<Central のアカウント id>": {"seed": 秘密鍵の種 (base64), "request": 次の見回りで共有を求める, "keyId", "known": {"<accountKey>": 指紋}}}`。
/// `known` = 最後に本体と揃えたときの、ログイン中の SNS セッションの指紋(トークンそのものは置かない。Web 版でもブラウザに残らない)。
/// D-547 で足したもの:
/// - `signingSeed` = 署名鍵(Ed25519)の種 (base64)。`seed` と同じく端末から出さない。
/// - `handle` / `email` = そのアカウントのハンドルとメール(小文字)。ログインで、入力したハンドル / メールから署名鍵を選ぶ。
/// - `trust` = `{"keyId", "fp": K の指紋, "holders": [持ち主の端末の署名鍵 (base64)]}`。最後に受け取った世代と、その世代で見た持ち主。
/// - `problem` = `{"keyId", "kind"}`。その世代では共有を止めている([SnsShareProblem])。
class SnsShareStore {
  SnsShareStore(this._storage);
  final SessionStorage _storage;
  static const storageKey = 'rasq.snsShare.v1';

  Future<Map<String, Map<String, Object?>>> _all() async {
    final raw = await _storage.read(storageKey);
    if (raw == null) return {};
    try {
      return {for (final e in (jsonDecode(raw) as Map).entries) if (e.value is Map) '${e.key}': (e.value as Map).cast<String, Object?>()};
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, Object?>> entry(String accountId) async => (await _all())[accountId] ?? const {};

  Future<void> update(String accountId, Map<String, Object?> Function(Map<String, Object?> e) f) async {
    final all = await _all();
    all[accountId] = f({...?all[accountId]});
    await _storage.write(storageKey, jsonEncode(all));
  }

  /// その Central のアカウントの端末の鍵(種)。無ければ作る。
  Future<Uint8List> seed(String accountId) async {
    final s = (await entry(accountId))['seed'];
    if (s is String && s.isNotEmpty) return base64.decode(s);
    final fresh = SnsShareCrypto.newDeviceSeed();
    await update(accountId, (e) => {...e, 'seed': base64.encode(fresh)});
    return fresh;
  }

  /// その Central のアカウントの署名鍵(Ed25519 の種、D-547)。無ければ作る。
  Future<Uint8List> signingSeed(String accountId) async {
    final s = (await entry(accountId))['signingSeed'];
    if (s is String && s.isNotEmpty) return base64.decode(s);
    final fresh = SnsShareCrypto.newDeviceSeed();
    await update(accountId, (e) => {...e, 'signingSeed': base64.encode(fresh)});
    return fresh;
  }

  /// ログインで署名鍵を選べるように、そのアカウントのハンドルとメールを控える(変わったときだけ書く)。
  Future<void> noteIdentity(String accountId, {required String handle, String? email}) async {
    final e = await entry(accountId);
    final h = handle.toLowerCase();
    final m = email?.toLowerCase();
    if (e['handle'] == h && e['email'] == m) return;
    await update(accountId, (e) => {...e, 'handle': h, 'email': m});
  }

  /// ログインで入力したハンドル / メール [identifier] のアカウントの署名鍵(手元に無ければ null = 証明を付けない)。
  Future<Uint8List?> signingSeedForLogin(String identifier) async {
    final id = identifier.trim().toLowerCase();
    final handle = id.startsWith('@') ? id.substring(1) : id;
    for (final e in (await _all()).values) {
      final s = e['signingSeed'];
      if (s is! String || s.isEmpty) continue;
      if ((handle.isNotEmpty && e['handle'] == handle) || (id.isNotEmpty && e['email'] == id)) return base64.decode(s);
    }
    return null;
  }

  /// 最後に受け取った世代と K の指紋、その世代で見た持ち主の署名鍵 (D-547)。何も覚えていなければ null(最初の参加)。
  Future<({String keyId, String fingerprint, Set<String> holders})?> trust(String accountId) async {
    final t = (await entry(accountId))['trust'];
    if (t is! Map || t['keyId'] is! String || t['fp'] is! String) return null;
    return (keyId: t['keyId'] as String, fingerprint: t['fp'] as String, holders: {for (final h in t['holders'] as List? ?? const []) if (h is String) h});
  }

  /// 世代 [keyId] の K(指紋 [fingerprint])を受け取った / 作った。持ち主 [holders] は、同じ世代なら前に見たものに足し、
  /// 新しい世代なら置き換える(外された端末を、いつまでも持ち主として数えない)。
  Future<void> remember(String accountId, {required String keyId, required String fingerprint, required Iterable<String> holders}) async {
    final before = await trust(accountId);
    final all = {if (before != null && before.keyId == keyId) ...before.holders, ...holders};
    if (before != null && before.keyId == keyId && before.fingerprint == fingerprint && before.holders.length == all.length) return;
    await update(accountId, (e) => {...e, 'trust': {'keyId': keyId, 'fp': fingerprint, 'holders': all.toList()..sort()}});
  }

  /// その世代で共有を止めている理由(止めていなければ null)。
  Future<({String keyId, SnsShareProblem kind})?> problem(String accountId) async {
    final p = (await entry(accountId))['problem'];
    final kind = p is Map ? SnsShareProblem.values.where((k) => k.name == p['kind']).firstOrNull : null;
    if (kind == null || p is! Map || p['keyId'] is! String) return null;
    return (keyId: p['keyId'] as String, kind: kind);
  }

  /// 世代 [keyId] で共有を止める。新しく止めたら true(同じものを止めていれば false = 知らせ直さない)。
  Future<bool> setProblem(String accountId, String keyId, SnsShareProblem kind) async {
    final before = await problem(accountId);
    if (before != null && before.keyId == keyId && before.kind == kind) return false;
    await update(accountId, (e) => {...e, 'problem': {'keyId': keyId, 'kind': kind.name}});
    return true;
  }

  /// [keys] をこの端末の「揃えた記録」から外す (D-409)。RASQ アカウントからのログアウトで、その SNS がこの端末の
  /// そのアカウントから離れたとき。残すと、次にそのアカウントへログインしたとき「この端末でログアウトした」と数えて、
  /// ほかの端末の SNS までログアウトさせてしまう。
  Future<void> forgetKnown(String accountId, Iterable<String> keys) async {
    final drop = keys.toSet();
    final known = (await entry(accountId))['known'];
    if (drop.isEmpty || known is! Map || !known.keys.any(drop.contains)) return;
    await update(accountId, (e) => {...e, 'known': {for (final k in known.entries) if (!drop.contains(k.key)) k.key: k.value}});
  }

  /// 新しくログインした: 次の見回りで、共有を求める。
  Future<void> markRequest(String accountId) => update(accountId, (e) => {...e, 'request': true});
}

/// SNS セッションの指紋(並びの違いで変わらないよう、いったん [AccountSession] に通す)。
String snsShareFingerprint(Map<String, Object?> session) {
  final canonical = jsonEncode(AccountSession.fromJson(session).toJson());
  return sha256.convert(utf8.encode(canonical)).toString().substring(0, 32);
}

/// 本体とこの端末を混ぜた結果。
@immutable
class SnsShareMerge {
  const SnsShareMerge({required this.body, required this.upload, required this.logins, required this.logouts});

  /// 新しい本体。
  final SessionOps body;

  /// 本体を書き換える必要がある(この端末の操作が混ざった / 古いログアウトの記録を捨てた)。
  final bool upload;

  /// この端末へ取り込むログイン(セッションの JSON)。
  final List<Map<String, Object?>> logins;

  /// この端末でログアウトにする SNS アカウント。
  final List<String> logouts;
}

/// 本体 [remote] と、この端末のこのアカウントの SNS セッション [local] を混ぜる。[known] = 前に揃えたときの指紋。
///
/// - この端末の操作: 指紋が変わった / 増えた = ログイン(時刻はそのログインの時刻 `createdAt`)、前にあって消えた = ログアウト(時刻 = [now])。
/// - アカウントごとに新しいほうの操作を取る([SessionOps.merged])。ログアウトの記録は 30 日で捨てる。
/// - 本体の操作のうち、この端末と違うものを取り込む(ログイン = 入れる / 替える、ログアウト = 外す)。
/// - 同期したことがあって、この端末では変わっていないのに、本体から消えたもの(記録を捨てたあとのログアウト)も外す。
SnsShareMerge mergeSnsShare({required SessionOps remote, required List<AccountSession> local, required Map<String, String> known, required DateTime now}) {
  final byKey = {for (final s in local) s.account.key: s};
  final fp = {for (final s in local) s.account.key: snsShareFingerprint(s.toJson())};
  final mine = <String, SessionOp>{
    for (final s in local)
      if (known[s.account.key] != fp[s.account.key]) s.account.key: SessionOp(at: s.createdAt.toUtc(), session: s.toJson()),
    for (final k in known.keys)
      if (!byKey.containsKey(k)) k: SessionOp(at: now.toUtc()),
  };
  final merged = remote.merged(SessionOps(ops: mine)).pruned(now);
  final body = SessionOps(ops: merged.ops);
  final logins = <Map<String, Object?>>[];
  final logouts = <String>[];
  for (final e in body.ops.entries) {
    final session = e.value.session;
    if (session != null) {
      if (fp[e.key] != snsShareFingerprint(session)) logins.add(session);
    } else if (byKey.containsKey(e.key)) {
      logouts.add(e.key);
    }
  }
  for (final k in known.keys) {
    if (byKey.containsKey(k) && !body.ops.containsKey(k) && known[k] == fp[k]) logouts.add(k);
  }
  return SnsShareMerge(body: body, upload: body.encode() != SessionOps(ops: remote.ops).encode(), logins: logins, logouts: logouts);
}

/// 問いの中身。[first] = 最初の問い(状態が `off`)、そうでなければ端末ごとの承認。
@immutable
class SnsShareQuestion {
  const SnsShareQuestion({required this.first, required this.devices, this.accountHandle});
  final bool first;
  final List<SnsShareDevice> devices;
  final String? accountHandle;

  String get title => first ? appL10n.sessionShareAskFirstTitle : appL10n.sessionShareAskDeviceTitle(devices.first.name);

  String get message {
    final l = appL10n;
    final handle = accountHandle;
    final names = devices.map((d) => d.name).join(l.sessionDeviceListSeparator);
    if (first) return handle == null ? l.sessionShareAskFirstMessage(names) : l.sessionShareAskFirstMessageHandle(names, handle);
    return handle == null ? l.sessionShareAskDeviceMessage : l.sessionShareAskDeviceMessageHandle(handle);
  }
}

/// 問いを出す口(はい = true / いいえ = false / 答えずに閉じた = null)。テストで差し替える。
typedef SnsShareAsk = Future<bool?> Function(SnsShareQuestion question);

final snsShareAskProvider = Provider<SnsShareAsk>((ref) => (q) => ref.read(overlayManagerProvider).showChoiceAlert<bool>(
      id: 'snsShare.ask',
      title: q.title,
      message: q.message,
      choices: [RasqAlertChoice(appL10n.sessionShareYes, true, primary: true), RasqAlertChoice(appL10n.sessionShareNo, false)],
      cancelText: null,
    ));

/// 見回りの間隔(0 = タイマーでは回さない。テスト用)。Web 版の保管庫の見回り (D-302) と同じ 45 秒。
final snsSharePollIntervalProvider = Provider<Duration>((ref) => const Duration(seconds: 45));

/// 承認を待っている間の見回り (D-322): `every` おきに、待ち始めてから `limit` まで(そのあとは、ふだんの見回りだけ)。
/// `every` が 0 なら回さない(テスト用)。
final snsSharePollWhileWaitingProvider = Provider<({Duration every, Duration limit})>((ref) => (every: const Duration(seconds: 3), limit: const Duration(minutes: 5)));

/// 受信箱の知らせの種類: 新しい端末が共有を求めた(Central の `sns_share.request`。中身は端末の名前と deviceId だけ)。
const snsShareRequestKind = 'sns_share.request';

/// `sns_share.request` の受け手 ([CentralInbox]): 答えずに閉じた問いも出し直して、すぐ見回る(問いの答えは待たない。
/// 受信箱の読みを、ユーザーが答えるまで止めないように)。
Future<void> handleSnsShareNotices(Ref ref, List<CentralNotice> notices) async {
  final devices = {for (final n in notices) if (n.payload['deviceId'] is String) n.payload['deviceId'] as String};
  unawaited(ref.read(snsShareProvider.notifier).onRequested(devices));
}

/// 画面が見る形。
@immutable
class SnsShareView {
  const SnsShareView({this.accountId, this.status, this.busy = false, this.joins = 0, this.problem});

  /// いま見ている Central のアカウント(ログインしていなければ null)。
  final String? accountId;

  /// Central の答え(まだ / 取れなければ null)。
  final SnsShareStatus? status;
  final bool busy;

  /// 承認を待っていたこの端末が、共有されたログインを取り込んだ回数 (D-322。SNS のログイン画面が TL へ移る合図)。
  final int joins;

  /// 今の世代で共有を止めている(確認が要る、D-547)。
  final SnsShareProblem? problem;
}

class _Ctx {
  _Ctx(this.api, this.accountId, this.handle, this.email, this.store);
  final SnsShareApi api;

  /// 端末に置くもの(見回りの初めに取る。途中で破棄されても読み書きできる)。
  final SnsShareStore store;
  final String accountId;
  final String handle;
  final String? email;
}

class SnsShareNotifier extends Notifier<SnsShareView> {
  Timer? _timer;

  /// 承認を待っている間の見回り (D-322) と、待ち始めた時刻。
  Timer? _waitTimer;
  DateTime? _waitingSince;

  /// 承認を待っていたアカウント(取り込めたら [SnsShareView.joins] を進める)。
  final Set<String> _wasWaiting = {};
  AppLifecycleListener? _lifecycle;
  Future<void>? _inflight;
  bool _again = false;

  /// この起動のあいだに、答えずに閉じた問い(`<accountId>:first` / `<accountId>:<deviceId>`)。見回りのたびに出し直さない。
  final Set<String> _dismissed = {};

  /// アカウントごとの、共有を止めている世代と理由 (D-547。見回りの初めに端末の保存先から読む)。
  final Map<String, ({String keyId, SnsShareProblem kind})?> _problems = {};

  @override
  SnsShareView build() {
    final every = ref.watch(snsSharePollIntervalProvider);
    try {
      _lifecycle = AppLifecycleListener(onResume: () => unawaited(check()));
    } catch (_) {
      _lifecycle = null; // バインディングの無いテスト
    }
    if (every > Duration.zero) _timer = Timer.periodic(every, (_) => unawaited(check()));
    ref.onDispose(() {
      _timer?.cancel();
      _waitTimer?.cancel();
      _lifecycle?.dispose();
    });
    ref.listen(orgateAccountProvider.select((a) => a.value?.id), (prev, next) {
      if (prev == next) return;
      state = SnsShareView(accountId: next);
      _waitingSince = null;
      unawaited(check());
    });
    // この端末で SNS にログイン / ログアウトしたら、共有中なら本体へ。
    ref.listen(sessionsProvider, (_, next) {
      if (next.hasValue && (state.status?.holding ?? false)) unawaited(check());
    });
    Future.microtask(check);
    return const SnsShareView();
  }

  SnsShareStore get _store => SnsShareStore(ref.read(sessionStorageProvider));

  /// いまの Central のアカウントと、そのトークンに縛った口。
  Future<_Ctx?> _ctx() async {
    // 端末間の共有は ORGATE (D-399)。端末 = ORGATE のセッションの端末。
    final client = ref.read(orgateClientProvider);
    if (client == null) return null;
    final RasqAccount? me;
    try {
      me = await ref.read(orgateAccountProvider.future);
    } catch (_) {
      return null;
    }
    if (me == null || !ref.mounted) return null;
    final token = ref.read(orgateAccountProvider.notifier).tokenFor(me.id);
    if (token == null) return null;
    return _Ctx(SnsShareApi(client.withToken(() => token)), me.id, me.handle, me.email, _store);
  }

  void _publish(_Ctx c, SnsShareStatus s, {bool busy = false}) {
    if (!ref.mounted) return;
    // 見回りの途中でアカウントが切り替わっていたら、前のアカウントの答えは出さない。
    final current = ref.read(orgateAccountProvider).value?.id;
    if (current != null && current != c.accountId) return;
    if (s.waiting) _wasWaiting.add(c.accountId);
    state = SnsShareView(accountId: c.accountId, status: s, busy: busy, joins: state.accountId == c.accountId ? state.joins : 0, problem: _problemOf(c, s));
  }

  /// 今の世代で共有を止めているなら、その理由。
  SnsShareProblem? _problemOf(_Ctx c, SnsShareStatus s) {
    final p = _problems[c.accountId];
    return p != null && s.mode == SnsShareMode.on && p.keyId == s.keyId ? p.kind : null;
  }

  /// 世代 [keyId] で共有を止めて、知らせる(同じものは知らせ直さない)。
  Future<void> _halt(_Ctx c, String keyId, SnsShareProblem kind) async {
    debugPrint('snsShare: stopped sharing on this device (${kind.name})');
    final fresh = await c.store.setProblem(c.accountId, keyId, kind);
    _problems[c.accountId] = (keyId: keyId, kind: kind);
    if (!ref.mounted) return;
    final s = state.status;
    if (s != null && state.accountId == c.accountId) _publish(c, s, busy: state.busy);
    if (fresh) ref.read(rootMessengerKeyProvider).currentState?.showSnackBar(SnackBar(content: Text(kind.message)));
  }

  /// 承認を待っている間は、数秒おきに見回る(待ち始めてから上限まで)。待っていなければ止める。
  void _scheduleWhileWaiting() {
    _waitTimer?.cancel();
    _waitTimer = null;
    if (!ref.mounted) return;
    if (!(state.status?.waiting ?? false)) {
      _waitingSince = null;
      return;
    }
    final p = ref.read(snsSharePollWhileWaitingProvider);
    if (p.every <= Duration.zero) return;
    final since = _waitingSince ??= DateTime.now();
    if (DateTime.now().difference(since) >= p.limit) return;
    _waitTimer = Timer(p.every, () => unawaited(check()));
  }

  /// 新しい端末が共有を求めた知らせ (D-322、[handleSnsShareNotices]): その端末について答えずに閉じた問いも出し直して、すぐ見回る。
  Future<void> onRequested(Set<String> deviceIds) {
    _dismissed.removeWhere((k) => k.endsWith(':first') || deviceIds.any((d) => k.endsWith(':$d')));
    return check();
  }

  /// 1 回見回る(重ねて呼ばれたら、走っている 1 回のあとにもう 1 回)。
  Future<void> check() {
    final running = _inflight;
    if (running != null) {
      _again = true;
      return running;
    }
    final run = _inflight = _check().catchError((Object e) => debugPrint('snsShare: check failed ($e)')).whenComplete(() {
      _inflight = null;
      if (_again && ref.mounted) {
        _again = false;
        unawaited(check());
      } else {
        _scheduleWhileWaiting();
      }
    });
    return run;
  }

  Future<void> _check() async {
    final c = await _ctx();
    if (c == null) return;
    try {
      _problems[c.accountId] = await c.store.problem(c.accountId);
      var s = await _ensureRegistered(c);
      _publish(c, s);
      if (s.deviceId == null || !ref.mounted) return;
      switch (s.mode) {
        case SnsShareMode.off:
          final asking = s.asking;
          final me = s.me;
          if (asking.isEmpty || me == null || _dismissed.contains('${c.accountId}:first')) return;
          // D-422: 自分も求めている端末(ログインで入った端末)でも、SNS にログインしていれば答える。前は求めている端末は
          // 一律に飛ばしていたので、どの端末もログインで入った(作った端末が無い / 作った端末で入り直した)ときに、誰も問われなかった。
          if (me.requested && (await _localSessions(c)).isEmpty) return;
          final yes = await ref.read(snsShareAskProvider)(SnsShareQuestion(first: true, devices: asking, accountHandle: c.handle));
          if (!ref.mounted) return;
          if (yes == null) {
            _dismissed.add('${c.accountId}:first');
          } else if (yes) {
            await _enable(c, from: SnsShareMode.off, approve: asking);
          } else {
            _publish(c, await c.api.setMode(SnsShareMode.declined, from: SnsShareMode.off));
          }
        case SnsShareMode.on:
          if (!s.holding) {
            // D-422: K を持つ端末が 1 台も残っていない(全部ログアウトした / パスワードの再設定でほかを消した / メールで承認して
            // `on` になったばかり)。前は誰も K を作り直さず、求めている端末はずっと待っていた。SNS にログインしているこの端末が
            // K を作り直す(自分と、メールで承認された端末に包む。ほかの求めには、次の見回りで問いを出す)。
            if (s.keyId == null && (await _localSessions(c)).isNotEmpty && ref.mounted) {
              await _enable(c, from: SnsShareMode.on, emailApproved: true);
              _again = true;
            }
            return;
          }
          // D-547: この世代で止めている(鍵が差し替えられた / 本体が開けない)。K を使わず、ほかの端末にも包まない。
          if (_problemOf(c, s) != null) return;
          final key = await _unwrap(c, s);
          if (key == null) return;
          for (final d in s.asking) {
            // メールのリンクで承認された端末 (D-422): 問いを出さずに包む(承認したのは本人。ここで知らせる)。
            if (d.emailApproved) {
              s = await _wrapFor(c, d, key, s.keyId!);
              _publish(c, s);
              ref.read(rootMessengerKeyProvider).currentState?.showSnackBar(SnackBar(content: Text(appL10n.sessionShareEmailApproved(d.name))));
              continue;
            }
            if (_dismissed.contains('${c.accountId}:${d.deviceId}')) continue;
            final yes = await ref.read(snsShareAskProvider)(SnsShareQuestion(first: false, devices: [d], accountHandle: c.handle));
            if (!ref.mounted) return;
            if (yes == null) {
              _dismissed.add('${c.accountId}:${d.deviceId}');
            } else if (yes) {
              s = await _wrapFor(c, d, key, s.keyId!);
            } else {
              s = await c.api.remove(d.deviceId);
            }
            _publish(c, s);
          }
          await _sync(c, key, s.keyId!);
        case SnsShareMode.declined:
          return;
      }
    } on OrgateException catch (e) {
      // 409 = ほかの端末が先に答えた / 書いた。次の見回りで揃う。
      debugPrint('snsShare: ${e.code.code} ${e.message}');
    }
  }

  /// この端末の、このアカウントの SNS セッション(共有できるもの)。
  Future<List<AccountSession>> _localSessions(_Ctx c) async {
    final record = ref.read(rasqAccountsProvider).value?.centralRecord(c.accountId);
    if (record == null) return const [];
    final sessions = await ref.read(sessionsProvider.future);
    return [for (final s in sessions.allSessions) if (record.sessionKeys.contains(s.account.key)) s];
  }

  /// メールでの承認のリンクを送り直す (D-422)。戻り = 送った先(伏せ字)。送れなければ [OrgateException]。
  Future<String?> requestEmailApproval() async {
    final c = await _ctx();
    if (c == null) return null;
    return c.api.requestEmailApproval();
  }

  /// この端末の X25519 の公開鍵と署名鍵(Ed25519 の公開鍵)。
  Future<({Uint8List publicKey, Uint8List signingKey})> _keys(_Ctx c) async =>
      (publicKey: await SnsShareCrypto.publicKeyOf(await c.store.seed(c.accountId)), signingKey: await SnsShareCrypto.signingPublicKeyOf(await c.store.signingSeed(c.accountId)));

  /// この端末の公開鍵と署名鍵を ORGATE に置く。
  Future<SnsShareStatus> _register(_Ctx c, {bool? request}) async {
    final k = await _keys(c);
    return c.api.register(k.publicKey, signingKey: k.signingKey, request: request);
  }

  /// この端末の公開鍵と署名鍵を Central に置く(無い / どちらかが変わった / 共有を求めるとき)。
  Future<SnsShareStatus> _ensureRegistered(_Ctx c) async {
    final k = await _keys(c);
    await c.store.noteIdentity(c.accountId, handle: c.handle, email: c.email);
    final entry = await c.store.entry(c.accountId);
    final request = entry['request'] == true;
    var s = await c.api.status();
    if (s.deviceId == null) return s;
    final me = s.me;
    if (me == null || !listEquals(me.publicKey, k.publicKey) || !listEquals(me.signingKey, k.signingKey) || (request && !me.requested)) {
      s = await c.api.register(k.publicKey, signingKey: k.signingKey, request: request ? true : null);
    }
    if (request) await c.store.update(c.accountId, (e) => {...e}..remove('request'));
    return s;
  }

  /// この端末あての包みを確かめてから開く (D-547)。使えなければ null。
  ///
  /// - 包んだ端末(`wrappedBy`)は、自分か、覚えている持ち主。まだ何も覚えていない最初の参加だけは、状態で承認済みの端末を信じる。
  /// - 署名(`wrapSignature`)は、その端末の署名鍵で確かめる(自分なら手元の鍵で)。宛先・公開鍵・世代・包みのバイト列まで含む。
  /// - 同じ世代なのに K の指紋が覚えているものと違えば、受け取らずに止める([SnsShareProblem.keyReplaced])。
  Future<Uint8List?> _unwrap(_Ctx c, SnsShareStatus s) async {
    final keyId = s.keyId!;
    final wrapped = s.wrappedKey!;
    final mine = await _keys(c);
    final trust = await c.store.trust(c.accountId);
    final by = s.devices.where((d) => d.deviceId == s.wrappedBy).firstOrNull;
    final self = by != null && by.deviceId == s.deviceId;
    final signer = self ? mine.signingKey : by?.signingKey;
    final known = signer != null && (self || (trust == null ? by!.approved : trust.holders.contains(base64.encode(signer))));
    final signature = s.wrapSignature;
    if (!known || signature == null) {
      debugPrint('snsShare: the wrapped key was not wrapped by a known holder');
      return null;
    }
    final message = SnsShareCrypto.wrapMessage(accountId: c.accountId, deviceId: s.deviceId!, recipientPublicKey: mine.publicKey, keyId: keyId, wrappedKey: wrapped);
    if (!await SnsShareCrypto.verify(publicKey: signer, message: message, signature: signature)) {
      debugPrint('snsShare: the signature on the wrapped key did not verify');
      return null;
    }
    final key = await SnsShareCrypto.unwrap(wrapped: wrapped, seed: await c.store.seed(c.accountId), accountId: c.accountId, deviceId: s.deviceId!, keyId: keyId);
    if (key == null) {
      debugPrint('snsShare: the wrapped key for this device could not be opened');
      return null;
    }
    final fingerprint = SnsShareCrypto.keyFingerprint(key);
    if (trust != null && trust.keyId == keyId && trust.fingerprint != fingerprint) {
      await _halt(c, keyId, SnsShareProblem.keyReplaced);
      return null;
    }
    await c.store.remember(c.accountId, keyId: keyId, fingerprint: fingerprint, holders: {
      base64.encode(mine.signingKey),
      base64.encode(signer),
      for (final d in s.devices)
        if (d.approved && d.signingKey != null && d.signingKey!.length == 32) base64.encode(d.signingKey!),
    });
    return key;
  }

  /// [d] あてに K を包み、この端末の署名鍵で署名して置く (D-547)。
  Future<SnsShareStatus> _wrapFor(_Ctx c, SnsShareDevice d, List<int> key, String keyId) async {
    final wrapped = await SnsShareCrypto.wrap(shareKey: key, recipientPublicKey: d.publicKey, accountId: c.accountId, deviceId: d.deviceId, keyId: keyId);
    final message = SnsShareCrypto.wrapMessage(accountId: c.accountId, deviceId: d.deviceId, recipientPublicKey: d.publicKey, keyId: keyId, wrappedKey: wrapped);
    final signature = await SnsShareCrypto.sign(await c.store.signingSeed(c.accountId), message);
    return c.api.wrap(d.deviceId, keyId: keyId, wrappedKey: wrapped, signature: signature);
  }

  /// 共有をオンにする: 状態を `on` に、この端末も共有を求めた形にして、新しい K を作って自分と [approve] に包み、本体を上げる。
  /// [approve] は、本人が問いに「はい」と答えた端末だけ。[emailApproved] = メールのリンクで承認された端末にも包む。
  /// それ以外の求めている端末には包まない(K を作り直したあとの見回りで、1 台ずつ問いを出す)。前は設定の「この端末にも
  /// 共有してもらう」から K を作り直すと、求めているだけの(承認されていない)端末にも全部包んでいた(セキュリティ確認
  /// 2026-10-09 の [16])。包む相手は、K を作る直前に読み直した状態で確かめる(まだ求めていて、問いのときと鍵が同じ端末だけ)。
  Future<void> _enable(_Ctx c, {required SnsShareMode from, List<SnsShareDevice> approve = const [], bool emailApproved = false}) async {
    var s = from == SnsShareMode.on ? await c.api.status() : await c.api.setMode(SnsShareMode.on, from: from);
    s = await _register(c, request: true);
    final asking = {for (final d in s.asking) d.deviceId: d};
    final yes = {for (final d in approve) d.deviceId: d};
    final to = [
      for (final d in asking.values)
        if ((emailApproved && d.emailApproved) || (yes[d.deviceId] != null && listEquals(yes[d.deviceId]!.publicKey, d.publicKey))) d,
    ];
    final key = SnsShareCrypto.newShareKey();
    final keyId = SnsShareCrypto.newKeyId();
    final me = s.me!;
    // 作った世代と K の指紋を覚える(あとで同じ世代の別の K が届いても受け取らない。D-547)。
    await c.store.remember(c.accountId, keyId: keyId, fingerprint: SnsShareCrypto.keyFingerprint(key), holders: {base64.encode((await _keys(c)).signingKey)});
    s = await _wrapFor(c, me, key, keyId);
    for (final d in to) {
      s = await _wrapFor(c, d, key, keyId);
    }
    _publish(c, s);
    await _sync(c, key, keyId);
  }

  /// 本体と、この端末のこのアカウントの SNS セッションを揃える。ほかの端末が先に書いていたら(409)読み直す。
  Future<void> _sync(_Ctx c, List<int> key, String keyId) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      if (!ref.mounted) return;
      final record = ref.read(rasqAccountsProvider).value?.centralRecord(c.accountId);
      final sessions = await ref.read(sessionsProvider.future);
      if (record == null || !ref.mounted) return;
      final local = [for (final s in sessions.allSessions) if (record.sessionKeys.contains(s.account.key)) s];
      final entry = await c.store.entry(c.accountId);
      var known = entry['keyId'] == keyId ? {for (final e in ((entry['known'] as Map?) ?? const {}).entries) '${e.key}': '${e.value}'} : <String, String>{};
      final raw = await c.api.body();
      final current = raw != null && SnsShareCrypto.keyIdOf(raw.bytes) == keyId;
      final opened = current ? await SnsShareCrypto.open(shareKey: key, keyId: keyId, accountId: c.accountId, body: raw.bytes) : null;
      // D-547: 今の世代の本体なのに開けない = 受け取った K が違う。空として扱って手元のトークンを上げ直さず、止めて知らせる。
      if (current && opened == null) {
        await _halt(c, keyId, SnsShareProblem.bodyUnreadable);
        return;
      }
      // 本体が無い / 前の世代: 空から(前に揃えた記録からログアウトを起こさない)。
      if (opened == null) known = {};
      final remote = opened == null ? SessionOps() : SessionOps.parse(opened);
      final m = mergeSnsShare(remote: remote, local: local, known: known, now: DateTime.now());
      final imported = await _apply(c, m);
      if (m.upload) {
        final sealed = await SnsShareCrypto.seal(shareKey: key, keyId: keyId, accountId: c.accountId, plaintext: m.body.encode());
        try {
          await c.api.putBody(sealed, ifMatch: raw?.version);
        } on OrgateException catch (e) {
          if (e.code.code == '409') continue;
          rethrow;
        }
      }
      // 揃えた記録: 本体のログインのうち、この端末に同じものがあるもの(入れられなかったもの = プラグインが無い、は数えない。
      // 数えると、次の見回りで「この端末でログアウトした」ことになってしまう)。
      final after = {for (final s in (ref.read(sessionsProvider).value?.allSessions ?? const <AccountSession>[])) s.account.key: snsShareFingerprint(s.toJson())};
      final nextKnown = {
        for (final e in m.body.ops.entries)
          if (e.value.session != null && after[e.key] == snsShareFingerprint(e.value.session!)) e.key: after[e.key]!,
      };
      await c.store.update(c.accountId, (e) => {...e, 'keyId': keyId, 'known': nextKnown});
      final joined = _wasWaiting.remove(c.accountId) && imported > 0;
      if (imported > 0) {
        ref.read(rootMessengerKeyProvider).currentState?.showSnackBar(SnackBar(content: Text(appL10n.sessionShareImported(imported))));
      }
      // 承認を待っていた端末が取り込めた: SNS のログイン画面は TL へ (D-322)。
      if (joined && ref.mounted && state.accountId == c.accountId) {
        state = SnsShareView(accountId: state.accountId, status: state.status, busy: state.busy, joins: state.joins + 1);
      }
      return;
    }
  }

  /// 取り込み(ログイン / ログアウト)を、この端末のセッションへ。取り込んだログインの数。
  Future<int> _apply(_Ctx c, SnsShareMerge m) async {
    if (m.logins.isEmpty && m.logouts.isEmpty) return 0;
    final registry = ref.read(pluginRegistryProvider);
    final allow = ref.read(childSnsAllowProvider);
    final logins = <AccountSession>[];
    for (final j in m.logins) {
      try {
        final s = AccountSession.fromJson(j);
        // この端末に無いプラグインのセッション / 見守りで追加を止めている SNS は入れない。
        if (registry.plugin(s.pluginId) == null) continue;
        if (allow != null && (!allow.addAccounts || !allow.permits(s.account.kind.name, s.account.instance))) continue;
        logins.add(s);
      } catch (e) {
        debugPrint('snsShare: skipped a shared session ($e)');
      }
    }
    await ref.read(sessionsProvider.notifier).applyShared(centralAccountId: c.accountId, logins: logins, logouts: m.logouts);
    return logins.length;
  }

  /// 設定のスイッチ: オン = 共有を始める(ほかの端末が既に共有していれば、この端末の承認を求める)。オフ = `declined`
  /// (Central の本体と、すべての包んだ K を消す。以後、自動では聞かない)。
  Future<void> setEnabled(bool on) async {
    final c = await _ctx();
    if (c == null) return;
    final cur = state.status;
    if (cur != null) _publish(c, cur, busy: true);
    try {
      // 走っている見回り(K の作り直しなど)が済んでから、読み直して決める(同じ K を 2 台で作り直さない)。
      final running = _inflight;
      if (running != null) await running;
      if (!ref.mounted) return;
      if (!on) {
        _publish(c, await c.api.setMode(SnsShareMode.declined));
        // 止めていた理由も外す(オンにし直すと新しい世代になる。D-547)。
        await c.store.update(c.accountId, (e) => {...e}..remove('known')..remove('keyId')..remove('problem'));
        _problems.remove(c.accountId);
        return;
      }
      final s = await _ensureRegistered(c);
      if (s.mode == SnsShareMode.on && s.keyId != null) {
        // ほかの端末が K を持っている: この端末は承認を待つ。
        _publish(c, s.me?.requested == true ? s : await _register(c, request: true));
        return;
      }
      // K を持つ端末がいない(on のまま): この端末が K を作り直す。包むのは自分と、メールで承認された端末だけ
      // (この操作は「この端末にも」で、ほかの端末を承認するものではない。[16])。
      await _enable(c, from: s.mode, emailApproved: s.mode == SnsShareMode.on);
    } finally {
      final s = state.status;
      if (s != null && ref.mounted) _publish(c, s);
      // 設定から求め直したら、承認を待つ間の見回りも始め直す。
      _waitingSince = null;
      _scheduleWhileWaiting();
    }
  }

  /// 設定の一覧から: その端末に共有する(承認)。
  Future<void> approve(SnsShareDevice d) async {
    final c = await _ctx();
    final s = state.status;
    if (c == null || s == null || !s.holding || _problemOf(c, s) != null) return;
    final key = await _unwrap(c, s);
    if (key == null) return;
    _publish(c, await _wrapFor(c, d, key, s.keyId!));
  }

  /// 設定の一覧から: その端末を共有から外す。
  Future<void> removeDevice(SnsShareDevice d) async {
    final c = await _ctx();
    if (c == null) return;
    _publish(c, await c.api.remove(d.deviceId));
  }
}

final snsShareProvider = NotifierProvider<SnsShareNotifier, SnsShareView>(SnsShareNotifier.new);

/// この端末が共有の承認を待っている(SNS のログイン画面の案内)。
final snsShareWaitingProvider = Provider<bool>((ref) => ref.watch(snsShareProvider.select((v) => v.status?.waiting ?? false)));
