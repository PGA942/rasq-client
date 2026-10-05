import 'package:meta/meta.dart';

/// Result of probing an instance host (サーバーの検索 / PDS変更).
@immutable
class ServerInfo {
  const ServerInfo({required this.host, required this.name, this.software, this.version, this.description, this.iconUrl, this.registrationOpen, this.maintainer});
  final String host;
  final String name;
  final String? software;
  final String? version;
  final String? description;
  final Uri? iconUrl;
  final bool? registrationOpen;
  final String? maintainer;
}

/// サーバーの管理者が出している広告 (D-438): Misskey の `meta.ads`。RASQ の広告枠(TL の投稿の間など)に AdMob と交互に出す。
@immutable
class ServerAd {
  const ServerAd({required this.id, required this.url, required this.imageUrl, this.place = 'horizontal', this.ratio = 1, this.dayOfWeek = 0});
  final String id;

  /// 押したときに開く先。
  final Uri url;
  final Uri imageUrl;

  /// `horizontal` / `horizontal-big` / `square`(Misskey の置き場所)。
  final String place;

  /// 出す割合(大きいほどよく出る)。
  final int ratio;

  /// 出す曜日のビット(日曜 = 1、月曜 = 2 … 土曜 = 64)。0 = 毎日。
  final int dayOfWeek;

  /// [day] (DateTime.weekday: 月 = 1 … 日 = 7) に出してよいか。
  bool showsOn(int day) => dayOfWeek == 0 || dayOfWeek & (1 << (day % 7)) != 0;

  /// Misskey の `meta` の `ads` の 1 件。形が違えば null。
  static ServerAd? fromMisskey(Object? j) {
    if (j is! Map) return null;
    final id = j['id'];
    final url = j['url'] is String ? Uri.tryParse(j['url'] as String) : null;
    final image = j['imageUrl'] is String ? Uri.tryParse(j['imageUrl'] as String) : null;
    if (id is! String || url == null || image == null || !const {'https', 'http'}.contains(url.scheme) || image.scheme != 'https') return null;
    return ServerAd(
      id: id,
      url: url,
      imageUrl: image,
      place: j['place'] is String ? j['place'] as String : 'horizontal',
      ratio: j['ratio'] is num ? (j['ratio'] as num).toInt().clamp(0, 1000) : 1,
      dayOfWeek: j['dayOfWeek'] is num ? (j['dayOfWeek'] as num).toInt() : 0,
    );
  }
}
