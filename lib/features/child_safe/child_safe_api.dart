import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../backend/orgate_client.dart';
import 'child_safe_policy.dart';

/// チャイルドセーフ v2 の Central の口 (D-307)。基点は `/api/v1`、Bearer(`POST /auth/child-login` だけ無し)。
///
/// Web コンソールがするもの: 保護者の確認(日本は JPKI、ほかは自己申告)/ つなぐ / 見守りを終える / 読むだけの要約。
/// **許す / 止めるの一覧の編集はアプリだけ**(ここの `PUT …/settings`)。

@immutable
class ChildSafeGuardianStatus {
  const ChildSafeGuardianStatus({this.verified = false, this.method, this.country, this.verifiedAt});
  final bool verified;

  /// `jpki` / `self_declared`(Central の `guardian.method`)。
  final String? method;
  final String? country;
  final DateTime? verifiedAt;
  static const none = ChildSafeGuardianStatus();
  factory ChildSafeGuardianStatus.fromJson(Map<String, Object?> j) => ChildSafeGuardianStatus(
        verified: j['verified'] == true,
        method: j['method'] as String?,
        country: j['country'] as String?,
        verifiedAt: DateTime.tryParse('${j['verifiedAt'] ?? ''}'),
      );
  String get methodLabel => switch (method) { 'jpki' => 'マイナンバーカード (JPKI)', 'self_declared' => '自己申告', null => '—', final m => m };
}

/// 見守っている子の 1 行(`GET /me/child-safe/guardian` の `children[]`)。
@immutable
class ChildSafeChildRow {
  const ChildSafeChildRow({required this.handle, this.displayName = '', this.state = 'pending_setup', this.revision = 0, this.appliedRevision = 0, this.ageBand = '13-15', this.createdByGuardian = false, this.linkedAt});
  final String handle;
  final String displayName;
  final String state;
  final int revision;
  final int appliedRevision;
  final String ageBand;
  final bool createdByGuardian;
  final DateTime? linkedAt;
  bool get pending => state == 'pending_setup';

  /// 最新の設定が子の端末で当てはまっているか。
  bool get applied => revision > 0 && appliedRevision >= revision;
  factory ChildSafeChildRow.fromJson(Map<String, Object?> j) => ChildSafeChildRow(
        handle: '${j['handle'] ?? ''}',
        displayName: '${j['displayName'] ?? ''}',
        state: '${j['state'] ?? 'pending_setup'}',
        revision: (j['revision'] as num?)?.toInt() ?? 0,
        appliedRevision: (j['appliedRevision'] as num?)?.toInt() ?? 0,
        ageBand: '${j['ageBand'] ?? '13-15'}',
        createdByGuardian: j['createdByGuardian'] == true,
        linkedAt: DateTime.tryParse('${j['linkedAt'] ?? ''}'),
      );
}

/// `GET /me/child-safe/guardian`。
@immutable
class ChildSafeGuardianInfo {
  const ChildSafeGuardianInfo({this.status = ChildSafeGuardianStatus.none, this.pledgeVersion, this.requiredMethod, this.jpkiMode, this.emailVerified = false, this.ageBand, this.pledgeAccepted = false, this.children = const []});
  final ChildSafeGuardianStatus status;
  final String? pledgeVersion;

  /// `jpki` / `self_declared` / null(国をまだ申告していない)。
  final String? requiredMethod;

  /// `off`(準備中)/ `dummy`(開発用)/ `oidc`。
  final String? jpkiMode;

  /// `requirements`(自己申告の前提): 確認済みのメール / 最新の年齢の申告 / いまの版の誓約に同意済みか。
  final bool emailVerified;
  final String? ageBand;
  final bool pledgeAccepted;
  final List<ChildSafeChildRow> children;
  bool get jpkiAvailable => jpkiMode != null && jpkiMode != 'off';
  factory ChildSafeGuardianInfo.fromJson(Map<String, Object?> j) {
    final req = j['requirements'] is Map ? (j['requirements'] as Map).cast<String, Object?>() : const <String, Object?>{};
    return ChildSafeGuardianInfo(
      status: ChildSafeGuardianStatus.fromJson(j),
      pledgeVersion: j['pledgeVersion']?.toString(),
      requiredMethod: j['requiredMethod'] as String?,
      jpkiMode: j['jpkiMode'] as String?,
      emailVerified: req['emailVerified'] == true,
      ageBand: req['ageBand'] as String?,
      pledgeAccepted: req['pledgeAccepted'] == true,
      children: [for (final c in j['children'] as List? ?? const []) if (c is Map) ChildSafeChildRow.fromJson(c.cast<String, Object?>())],
    );
  }
}

/// 1 日ぶんの要約(**値は無い**: 数と話題の見出しだけ)。
@immutable
class ChildSafeSummaryDay {
  const ChildSafeSummaryDay({required this.date, this.posts = 0, this.blocked = 0, this.topics = const []});
  final String date;
  final int posts;
  final int blocked;
  final List<String> topics;
  factory ChildSafeSummaryDay.fromJson(Map<String, Object?> j) => ChildSafeSummaryDay(
        date: '${j['date'] ?? ''}',
        posts: (j['posts'] as num?)?.toInt() ?? 0,
        blocked: (j['blocked'] as num?)?.toInt() ?? 0,
        topics: [for (final t in j['topics'] as List? ?? const []) '$t'],
      );
}

@immutable
class ChildSafeSummary {
  const ChildSafeSummary({this.days = const [], this.since});
  final List<ChildSafeSummaryDay> days;
  final String? since;
  factory ChildSafeSummary.fromJson(Map<String, Object?> j) =>
      ChildSafeSummary(days: [for (final d in j['days'] as List? ?? const []) if (d is Map) ChildSafeSummaryDay.fromJson(d.cast<String, Object?>())], since: j['since']?.toString());
}

/// `GET /me/child-safe/children/{handle}`。
@immutable
class ChildSafeChildDetail {
  const ChildSafeChildDetail({required this.row, this.settings, this.signature, this.issuedAt, this.summary = const ChildSafeSummary()});
  final ChildSafeChildRow row;

  /// null = まだ決めていない(`pending_setup`)。
  final ChildSafePolicy? settings;
  final String? signature;
  final String? issuedAt;
  final ChildSafeSummary summary;
  factory ChildSafeChildDetail.fromJson(Map<String, Object?> j) => ChildSafeChildDetail(
        row: ChildSafeChildRow.fromJson(j),
        settings: j['settings'] is Map ? ChildSafePolicy.fromJson((j['settings'] as Map).cast<String, Object?>()) : null,
        signature: j['signature'] as String?,
        issuedAt: j['issuedAt']?.toString(),
        summary: j['summary'] is Map ? ChildSafeSummary.fromJson((j['summary'] as Map).cast<String, Object?>()) : const ChildSafeSummary(),
      );
}

class ChildSafeApi {
  ChildSafeApi(this._client);
  final OrgateClient _client;

  // ── 子 / だれでも ──
  Future<Map<String, Object?>> status() => _client.getJson('/me/child-safe');
  Future<void> ack(int revision) => _client.postJson('/me/child-safe/ack', {'revision': revision});

  /// 1 日ぶんの報告。**数と話題の見出しだけ**(投稿の本文は送らない)。
  Future<void> report({required String date, required int posts, required int blocked, required List<String> topics}) =>
      _client.postJson('/me/child-safe/report', {'date': date, 'posts': posts, 'blocked': blocked, 'topics': topics});

  /// 既にある子のアカウントを、保護者のコードでつなぐ。
  Future<void> pair(String code) => _client.postJson('/me/child-safe/pair', {'code': code});

  /// 保護者が作った子のアカウントへ、1 度きりのコードでログインする(Bearer は付けない)。
  /// 応答は `POST /auth/device` の成功と同じ形(→ [OrgateAccountNotifier.adoptLogin])。
  Future<Map<String, Object?>> childLogin({required String code, required String deviceId}) => _client.withToken(() => null).postJson('/auth/child-login', {'code': code, 'deviceId': deviceId});

  Future<ChildSafeCatalog> catalog() async => ChildSafeCatalog.fromJson(await _client.getJson('/me/child-safe/catalog'));

  /// ストアの署名鍵(`GET /store-key`)。制限の署名もこの鍵。
  Future<String?> storeKey() async => (await _client.getJson('/store-key'))['publicKey'] as String?;

  // ── 保護者 ──
  Future<ChildSafeGuardianInfo> guardian() async => ChildSafeGuardianInfo.fromJson(await _client.getJson('/me/child-safe/guardian'));
  Future<({String code, DateTime? expiresAt, String? link})> createPairing() async {
    final r = await _client.postJson('/me/child-safe/pairings', const {});
    return (code: '${r['code'] ?? ''}', expiresAt: DateTime.tryParse('${r['expiresAt'] ?? ''}'), link: r['link'] as String?);
  }

  Future<({String handle, String loginCode, DateTime? expiresAt})> createChild({required String handle, required String displayName, required String ageBand}) async {
    final r = await _client.postJson('/me/child-safe/children', {'handle': handle, 'displayName': displayName, 'ageBand': ageBand});
    return (handle: '${r['handle'] ?? handle}', loginCode: '${r['loginCode'] ?? ''}', expiresAt: DateTime.tryParse('${r['expiresAt'] ?? ''}'));
  }

  Future<ChildSafeChildDetail> child(String handle) async => ChildSafeChildDetail.fromJson(await _client.getJson('/me/child-safe/children/${Uri.encodeComponent(handle)}'));
  Future<int> putSettings(String handle, ChildSafePolicy policy) async =>
      ((await _client.putJson('/me/child-safe/children/${Uri.encodeComponent(handle)}/settings', policy.toJson()))['revision'] as num?)?.toInt() ?? 0;
  Future<void> end(String handle) => _client.postJson('/me/child-safe/children/${Uri.encodeComponent(handle)}/end', const {});
  Future<ChildSafeSummary> summary(String handle) async => ChildSafeSummary.fromJson(await _client.getJson('/me/child-safe/children/${Uri.encodeComponent(handle)}/summary'));
}

final childSafeApiProvider = Provider<ChildSafeApi?>((ref) {
  final client = ref.watch(centralClientProvider);
  return client == null ? null : ChildSafeApi(client);
});

/// サーバーのエラーを 1 行に。Central のメッセージは日本語なので、決まった言い換えが無いものはそのまま出す。
String childSafeErrorMessage(Object e) {
  if (e is! OrgateException) return '$e';
  return switch (e.code.code) {
    '404' when e.message.isEmpty || e.message == 'not found' => 'コードが違うか、期限が切れています',
    '409' when e.message.contains('taken') || e.message.contains('handle') || e.message.contains('ハンドル') => 'そのハンドルは使われています',
    '409' when e.message.isEmpty => 'もう見守られている(か、だれかを見守っている)アカウントです',
    '410' => 'コードの期限が切れたか、もう使われています。保護者に出し直してもらってください',
    '403' when e.message.contains('device') => 'この端末ではログインできません',
    '429' => '試行が多すぎます。しばらく待ってから、やり直してください',
    _ => e.message,
  };
}
