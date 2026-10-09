import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'media_fetch.dart';
import 'media_policy.dart';
import 'web_image.dart';

/// この面で [url] を描く画像 (セキュリティ確認 2026-10-09 の [11])。読んでよいかは先に [rasqMediaAllowed] で確かめること。
///
/// - ホストの画面([RasqMediaPolicy.unrestricted])/ `data:` / ホストが渡した URL([RasqMediaPolicy.allowedUrls]、
///   プラグインが選んだのではない)は、これまでどおり [NetworkImage](リダイレクトも追う)。
/// - プラグインが選んだ URL(宣言した接続先で許したもの)は [RasqPolicyNetworkImage]: リダイレクトの各ホップで方針を
///   確かめ直す(Web 版は追わない)。宣言した接続先が転送しても、宣言の外へはホストが送らない。
ImageProvider rasqMediaImage(BuildContext context, Uri url) => RasqMediaPolicyScope.of(context).imageFor(url);

extension RasqMediaPolicyImage on RasqMediaPolicy {
  /// [url] を描く画像([rasqMediaImage])。
  ImageProvider imageFor(Uri url) {
    if (isUnrestricted || url.scheme.toLowerCase() == 'data' || allowedUrls.contains(url.toString())) {
      return NetworkImage(url.toString(), webHtmlElementStrategy: rasqWebImageStrategy);
    }
    return RasqPolicyNetworkImage(url, this);
  }
}

/// 制限のある面の画像: ホストの通信([rasqFetchMedia])でリダイレクトを 1 つずつ方針に通して取り、デコードする。
/// キャッシュの鍵は URL(方針は含めない。キャッシュにあれば通信しないので、広い方針で取った絵を狭い面で使っても送り先は増えない)。
@immutable
class RasqPolicyNetworkImage extends ImageProvider<RasqPolicyNetworkImage> {
  const RasqPolicyNetworkImage(this.url, this.policy, {this.scale = 1.0});

  final Uri url;
  final RasqMediaPolicy policy;
  final double scale;

  @override
  Future<RasqPolicyNetworkImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture<RasqPolicyNetworkImage>(this);

  @override
  ImageStreamCompleter loadImage(RasqPolicyNetworkImage key, ImageDecoderCallback decode) => MultiFrameImageStreamCompleter(
        codec: _load(key, decode),
        scale: key.scale,
        debugLabel: key.url.toString(),
        informationCollector: () => [DiagnosticsProperty<Uri>('URL', key.url)],
      );

  static Future<ui.Codec> _load(RasqPolicyNetworkImage key, ImageDecoderCallback decode) async {
    final bytes = await rasqFetchMedia(key.url, key.policy.allows);
    if (bytes.isEmpty) throw StateError('empty image: ${key.url}');
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) => other is RasqPolicyNetworkImage && other.url == url && other.scale == scale;

  @override
  int get hashCode => Object.hash(url, scale);

  @override
  String toString() => '${objectRuntimeType(this, 'RasqPolicyNetworkImage')}("$url", scale: $scale)';
}
