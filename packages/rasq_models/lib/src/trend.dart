import 'package:meta/meta.dart';

/// One trending word (トレンドホーム). Phase-1 sample sources it from the SNS
/// (`hashtags/trend`); the trend provider plugin / server replaces it later.
@immutable
class TrendTag {
  const TrendTag({required this.tag, this.usersCount, this.postsCount, this.chart = const [], this.related = const []});
  final String tag;
  final int? usersCount;
  final int? postsCount;

  /// Recent activity series (oldest → newest), for sparklines.
  final List<int> chart;

  /// Related words shown under the tag (「発射 バルバトスⅢ 周回軌道」).
  final List<String> related;
}
