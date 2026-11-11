import 'dart:typed_data';

import '../../backend/orgate_client.dart';
import 'swing_models.dart';
import '../../l10n/l10n.dart';

/// Central の Swing (S-056)。`docs/API.md` §4i。
class SwingApi {
  SwingApi(this._c);
  final OrgateClient _c;

  /// 自分に届いている Swing(既定は見終えていないものだけ)。
  Future<List<Swing>> feed({bool all = false}) async => [
        for (final x in await _c.getList('/swings/feed', {if (all) 'all': 'true'}))
          ?Swing.tryParse(x),
      ];

  /// 自分が出している Swing(届け先と見終えた人数つき)。
  Future<List<Swing>> mine() async => [for (final x in await _c.getList('/me/swings')) ?Swing.tryParse(x)];

  /// 画像 / 動画を上げる → media id。
  Future<String> uploadMedia(Uint8List bytes, {required String contentType}) async {
    final j = await _c.postBytes('/swings/media', bytes, contentType: contentType);
    return '${j['id']}';
  }

  Future<Swing> create(NewSwing s) async {
    final j = await _c.postJson('/swings', s.toJson());
    final swing = Swing.tryParse(j);
    if (swing == null) throw StateError(appL10n.swingUnreadable);
    return swing;
  }

  /// [create] と同じ。ただしプラグインの版がそのサーバーで配られていなければ(`404 version_not_available`: アプリ同梱のサンプルの版を
  /// 持っている / 審査待ちの版など、D-424 / Central S-079)、版を付けずに作り直す(サーバーの現在の版)。
  Future<Swing> createServed(NewSwing s) async {
    try {
      return await create(s);
    } on OrgateException catch (e) {
      final p = s.plugin;
      if (e.serverCode != versionNotAvailable || p == null || p.version == null || p.packageId != null) rethrow;
      return create(s.withPlugin(p.withoutVersion()));
    }
  }

  /// Central の `error.code`: 版がそのサーバーで配られていない (S-079)。
  static const versionNotAvailable = 'version_not_available';

  Future<void> seen(String id) => _c.postJson('/swings/$id/seen', const {});

  Future<void> delete(String id) => _c.delete('/swings/$id');

  // ── P2P (D-549 / Central S-128) ────────────────────────────────

  /// Central の `error.code`: P2P の Swing を受けない設定(`CENTRAL_SWING_DELIVERY=server`)。
  static const p2pDisabled = 'swing_p2p_disabled';

  /// Central の `error.code`: この端末の署名鍵が登録されていない(外された / 別の端末で替えた)。
  static const keyUnknown = 'swing_key_unknown';

  /// この端末の Swing の署名鍵(公開鍵)を登録する。
  Future<void> registerKey(String deviceId, String publicKey) async {
    await _c.putJson('/me/swing-keys/${Uri.encodeComponent(deviceId)}', {'publicKey': publicKey});
  }

  /// P2P の Swing を作る(実体は上げない)。
  Future<Swing> createP2p(Map<String, Object?> manifest, String signature) async {
    final j = await _c.postJson('/swings/p2p', {'manifest': manifest, 'signature': signature});
    final swing = Swing.tryParse(j);
    if (swing == null) throw StateError(appL10n.swingUnreadable);
    return swing;
  }

  /// いま取りに行ける相手(伏せた札と役目)。
  Future<List<({String source, String role})>> sources(String id) async {
    final j = await _c.getJson('/swings/$id/sources');
    return [
      for (final s in (j['sources'] as List? ?? const []))
        if (s is Map && s['source'] is String) (source: s['source'] as String, role: '${s['role']}'),
    ];
  }

  /// 相手へシグナリングを仲介してもらう。
  Future<void> signal(String id, {required String to, required String session, required String kind, Object? data}) =>
      _c.postJson('/swings/$id/signal', {'to': to, 'session': session, 'kind': kind, 'data': data});

  /// TURN の資格情報(`RTCConfiguration.iceServers` の形と、有効時間)。
  Future<({List<Map<String, Object?>> iceServers, int ttlSecs})> turn() async {
    final j = await _c.getJson('/me/swing-turn');
    return (
      iceServers: [for (final s in (j['iceServers'] as List? ?? const [])) if (s is Map) s.cast<String, Object?>()],
      ttlSecs: (j['ttlSecs'] as num?)?.toInt() ?? 600,
    );
  }

  /// 自分への、まだ送っていない写しの求め。
  Future<List<({String caseId, String swingId, String? mediaSha256, String manifestSha256})>> evidenceRequests() async => [
        for (final r in await _c.getList('/me/swing-evidence-requests'))
          if (r is Map && r['swingId'] is String && r['manifestSha256'] is String)
            (caseId: '${r['caseId']}', swingId: r['swingId'] as String, mediaSha256: r['mediaSha256'] as String?, manifestSha256: r['manifestSha256'] as String),
      ];

  /// 写しを送る。
  Future<void> uploadEvidence(String id, Uint8List bytes, {required String manifestSha256, required String contentType}) async {
    await _c.postBytes('/swings/$id/evidence', bytes, contentType: contentType, headers: {'X-Rasq-Manifest-Hash': manifestSha256});
  }

  /// 合わない実体を渡してきた相手を知らせる。
  Future<void> integrity(String id, String source) => _c.postJson('/swings/$id/integrity', {'source': source});

  /// 通報する (D-395 / S-060)。[reason] = spam / harassment / illegal / other。届いていない Swing は 404。
  Future<void> report(String id, {required String reason}) => _c.postJson('/reports', {'swingId': id, 'reason': reason});
}
