import 'dart:typed_data';

import '../../backend/orgate_client.dart';
import 'swing_models.dart';

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
    if (swing == null) throw StateError('Swing を読めませんでした');
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

  /// 通報する (D-395 / S-060)。[reason] = spam / harassment / illegal / other。届いていない Swing は 404。
  Future<void> report(String id, {required String reason}) => _c.postJson('/reports', {'swingId': id, 'reason': reason});
}
