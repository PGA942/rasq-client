import 'router.dart';

/// 外から来た `rasq://` のリンク (D-456): Central の Web のページ(AsTell ルームの公開ページ / RASQ アカウントページ /
/// カスタムプラグインの招待、rasq-central S-092)の「アプリで開く」のチップ。
///
/// - AsTell ルーム: `rasq://astell/<UUID か共有 URL の Base58 コード>` → `/astell/<ref>`([AstellOpenScreen])。
/// - RASQ アカウント: `rasq://account/<handle>` → `/rasq/<handle>`。
/// - カスタムプラグインの招待: `rasq://custom-invite/<code>` → `/custom/invite/<code>`。
///
/// Android は intent-filter にこの 3 つの host だけを載せる(ほかの `rasq://` は受けない。AndroidManifest.xml)。
/// iOS は `rasq` の scheme ごと届くので、ここで知らない host は null(ルーターがホームへ)。形の合わない値は
/// その種類の入口(VC / ホーム / カスタムプラグイン)へ寄せ、画面には渡さない。
/// Web クライアント(Central の `/app/`、path の URL)はこれと同じアプリの中の場所(`/app/astell/<code>` など)を直接開く。
const rasqLinkScheme = 'rasq';
const astellLinkHost = 'astell';
const accountLinkHost = 'account';
const customInviteLinkHost = 'custom-invite';

final _roomRef = RegExp(r'^[0-9A-Za-z-]{1,64}$');
final _handle = RegExp(r'^@?([A-Za-z0-9_.-]{1,64})$');
final _inviteCode = RegExp(r'^[A-Za-z0-9]{4,32}$');

/// AsTell ルームの参照(UUID か Base58 コード)として受けるか。
bool isAstellRoomRef(String s) => _roomRef.hasMatch(s);

/// `rasq://…` → アプリの中の場所。このファイルの扱う host でなければ null。
String? rasqDeepLinkLocation(Uri uri) {
  if (uri.scheme != rasqLinkScheme) return null;
  final first = uri.pathSegments.where((s) => s.isNotEmpty).firstOrNull ?? '';
  switch (uri.host) {
    case astellLinkHost:
      return isAstellRoomRef(first) ? Routes.astellRoom(first) : Routes.vc;
    case accountLinkHost:
      final m = _handle.firstMatch(first);
      return m == null ? Routes.home : Routes.rasqAccount(m.group(1)!);
    case customInviteLinkHost:
      return _inviteCode.hasMatch(first) ? Routes.customInvite(first) : Routes.customPlugins;
  }
  return null;
}

/// カスタムプラグインの招待リンク (D-456): Central の `/custom/invite/<code>`(rasq-central S-092)。開くと
/// 「Web クライアントで開く」/「アプリで開く」のチップのページ。招待コードだけより、SNS やメッセージに貼りやすい。
/// Central の起点のパス(`/api/v1` など)は捨て、オリジンの直下に置く。
String centralCustomInviteUrl(Uri central, String code) =>
    Uri(scheme: central.scheme, host: central.host, port: central.hasPort ? central.port : null, pathSegments: ['custom', 'invite', code]).toString();
