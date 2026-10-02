import 'package:flutter/widgets.dart';

/// ホストが代わりに取りに行く画像 / メディアの URL を、その面を描いた主(プラグイン)の権限で絞る (D-407、セキュリティ指摘 #9)。
///
/// プラグインの RRL は「データ」なので、`Image` の `src` やアバター / メディア / アイコンの URL をホストがそのまま
/// `Image.network` に渡すと、`network` を持たない(制限モードの)プラグインでも、下書きなどを URL のクエリに入れて
/// 作者のサーバーへ送れてしまう(画像の読み込み = ホストの通信)。そこで:
/// - ホスト自身の画面(スコープ無し)は [unrestricted]。
/// - プラグインの面は [RasqMediaPolicyScope] で包み、`data:` と、ホストが渡した URL([allowedUrls])と、
///   `network` 権限 + 宣言した接続先([hostAllowed])に合う http(s) だけを読む。それ以外は**通信せず**に代わりの表示へ。
/// `file:` などその他のスキームはプラグインの面では読まない(端末内のファイルを覗かせない)。
@immutable
class RasqMediaPolicy {
  const RasqMediaPolicy._({required this.isUnrestricted, this.hostAllowed, this.allowedUrls = const {}});

  /// ホストの画面: 何でも読む(従来どおり)。
  static const RasqMediaPolicy unrestricted = RasqMediaPolicy._(isUnrestricted: true);

  /// 端末内だけ(`data:`)。制限モード / `network` を持たないプラグインの既定。
  static const RasqMediaPolicy localOnly = RasqMediaPolicy._(isUnrestricted: false);

  /// プラグインの面: [hostAllowed] (`network` 権限があるときだけ渡す。宣言した接続先の判定) と、ホストが渡した URL
  /// [allowedUrls](完全一致)。
  const RasqMediaPolicy.plugin({bool Function(String host)? hostAllowed, Set<String> allowedUrls = const {}})
      : this._(isUnrestricted: false, hostAllowed: hostAllowed, allowedUrls: allowedUrls);

  final bool isUnrestricted;

  /// http(s) の接続先を許すか。null = どこも許さない。
  final bool Function(String host)? hostAllowed;

  /// ホストが渡した(プラグインが作ったのではない)URL。完全一致だけ許す。
  final Set<String> allowedUrls;

  /// [url] を読んでよいか(読まないときは通信しない)。
  bool allows(Uri? url) {
    if (url == null) return false;
    final scheme = url.scheme.toLowerCase();
    if (scheme == 'data') return true;
    if (isUnrestricted) return true;
    if (scheme != 'http' && scheme != 'https') return false;
    if (allowedUrls.contains(url.toString())) return true;
    final host = url.host;
    if (host.isEmpty) return false;
    return hostAllowed?.call(host) ?? false;
  }

  /// [allowedUrls] を足した写し(面ごとにホストが渡すデータの URL を足す)。
  RasqMediaPolicy withAllowedUrls(Iterable<String> urls) {
    if (isUnrestricted) return this;
    return RasqMediaPolicy._(isUnrestricted: false, hostAllowed: hostAllowed, allowedUrls: {...allowedUrls, ...urls});
  }
}

/// 子孫の画像 / メディアの読み込みに [policy] を掛ける。入れ子では内側(より狭いはず)が勝つ。
class RasqMediaPolicyScope extends InheritedWidget {
  const RasqMediaPolicyScope({super.key, required this.policy, required super.child});

  final RasqMediaPolicy policy;

  /// いまの面の方針。スコープが無ければホストの画面 = [RasqMediaPolicy.unrestricted]。
  static RasqMediaPolicy of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<RasqMediaPolicyScope>()?.policy ?? RasqMediaPolicy.unrestricted;

  @override
  bool updateShouldNotify(RasqMediaPolicyScope oldWidget) => !identical(oldWidget.policy, policy);
}

/// この面で [url] を読んでよいか([RasqMediaPolicyScope.of] の答え)。
bool rasqMediaAllowed(BuildContext context, Uri? url) => RasqMediaPolicyScope.of(context).allows(url);
