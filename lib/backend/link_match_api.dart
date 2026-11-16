import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'orgate_client.dart';

/// リンクの照合 (D-551、Central S-129)。ほかの SNS の書き出しに出てくるアカウントから、RASQ のユーザーを探す。
///
/// 書き出しは端末から出さない。1 件ごとに `sha256(ソルト \n サービス \n 名前)` とサービス(ホスト名)だけを送る。
/// 揃え方([linkMatchService] / [linkMatchName])とハッシュは Central の `link_match.rs` と同じ。

/// サービス(ホスト名)を揃える: 小文字、`www.` / `mobile.` / `m.` を外す、`twitter.com` → `x.com`、`threads.com` → `threads.net`。
String linkMatchService(String host) {
  var h = host.trim().toLowerCase();
  while (h.endsWith('.')) {
    h = h.substring(0, h.length - 1);
  }
  for (final p in const ['www.', 'mobile.', 'm.']) {
    if (h.startsWith(p)) {
      h = h.substring(p.length);
      break;
    }
  }
  return switch (h) { 'twitter.com' => 'x.com', 'threads.com' => 'threads.net', _ => h };
}

/// 名前を揃える(小文字、先頭の `@` を外す)。空 / 200 文字超は null。
String? linkMatchName(String name) {
  final n = name.trim().replaceFirst(RegExp(r'^@+'), '').toLowerCase();
  return n.isEmpty || n.runes.length > 200 ? null : n;
}

/// X の内部 ID の名前(`id:<数字>`)。数字でなければ null。
String? linkMatchXId(String id) {
  final t = id.trim();
  return RegExp(r'^\d{1,20}$').hasMatch(t) ? 'id:$t' : null;
}

/// 照合のハッシュ(16 進の小文字)。
String linkMatchHash(String salt, String service, String name) => sha256.convert(utf8.encode('$salt\n$service\n$name')).toString();

/// 見つかった RASQ のユーザー。
@immutable
class LinkMatchAccount {
  const LinkMatchAccount({required this.id, required this.handle, required this.displayName, this.avatarUrl, this.bio = '', this.verified = false});
  final String id;
  final String handle;
  final String displayName;
  final Uri? avatarUrl;
  final String bio;

  /// 持ち主の確認が済んだ SNS の連携で当たった。プロフィールのリンク / X の名乗りは名乗っているだけなので false。
  final bool verified;
  String get label => displayName.isEmpty ? handle : displayName;

  static LinkMatchAccount? fromJson(Object? j) {
    if (j is! Map || '${j['handle'] ?? ''}'.isEmpty) return null;
    final u = Uri.tryParse('${j['avatarUrl'] ?? ''}');
    return LinkMatchAccount(
      id: '${j['id'] ?? ''}',
      handle: '${j['handle']}',
      displayName: '${j['displayName'] ?? ''}',
      avatarUrl: u != null && (u.scheme == 'https' || u.scheme == 'http') && u.host.isNotEmpty ? u : null,
      bio: '${j['bio'] ?? ''}',
      verified: j['verified'] == true,
    );
  }
}

/// X の名乗り(ダミーの X 認証)。X には確かめに行っていない。
@immutable
class XIdentity {
  const XIdentity({required this.handle, this.userId, this.method = 'dummy'});
  final String handle;
  final String? userId;
  final String method;

  static XIdentity? fromJson(Object? j) => j is Map && '${j['handle'] ?? ''}'.isNotEmpty
      ? XIdentity(handle: '${j['handle']}', userId: j['userId'] as String?, method: '${j['method'] ?? 'dummy'}')
      : null;
}

/// X のハンドルの形(英数字と `_`、15 文字まで。先頭の `@` は外す)。合わなければ null。
String? validXHandle(String input) {
  final h = input.trim().replaceFirst(RegExp(r'^@+'), '');
  return RegExp(r'^[A-Za-z0-9_]{1,15}$').hasMatch(h) ? h : null;
}

/// 回数の制限(429)で断られたか。
bool isRateLimited(Object e) => e is OrgateException && e.code.code == '429';

/// 1 回に送る数の既定(Central が `maxItems` で知らせる)。
const linkMatchDefaultBatch = 200;

class LinkMatchApi {
  LinkMatchApi(this._client);
  final OrgateClient _client;

  /// ハッシュを作るための値(`GET /accounts/match-links`)。
  Future<({String salt, int maxItems})> info() async {
    final j = await _client.withToken(() => null).getJson('/accounts/match-links');
    final max = (j['maxItems'] as num?)?.toInt() ?? linkMatchDefaultBatch;
    return (salt: '${j['salt'] ?? ''}', maxItems: max.clamp(1, 1000));
  }

  /// ハッシュの照合(`POST /accounts/match-links`、匿名)。戻りは `サービス\nハッシュ` → 当たった人。当たらなかった鍵は入らない。
  Future<Map<String, List<LinkMatchAccount>>> match(List<({String service, String hash})> items) async {
    final j = await _client.withToken(() => null).postJson('/accounts/match-links', {
      'items': [for (final i in items) {'service': i.service, 'hash': i.hash}],
    });
    return {
      for (final m in j['matches'] as List? ?? const [])
        if (m is Map)
          '${m['service']}\n${m['hash']}': [
            for (final a in m['accounts'] as List? ?? const [])
              if (LinkMatchAccount.fromJson(a) != null) LinkMatchAccount.fromJson(a)!,
          ],
    };
  }

  /// 自分の X の名乗り(`GET /me/x-identity`)。
  Future<XIdentity?> xIdentity() async => XIdentity.fromJson((await _client.getJson('/me/x-identity'))['identity']);

  /// ダミーの X 認証: 申告をそのまま持たせる(`PUT /me/x-identity`)。
  Future<XIdentity?> putXIdentity({required String handle, String? userId}) async =>
      XIdentity.fromJson((await _client.putJson('/me/x-identity', {'handle': handle, 'userId': ?userId}))['identity']);

  Future<void> deleteXIdentity() => _client.delete('/me/x-identity');
}

/// Central の接続先が無ければ null。
final linkMatchApiProvider = Provider<LinkMatchApi?>((ref) {
  final client = ref.watch(centralClientProvider);
  return client == null ? null : LinkMatchApi(client);
});
