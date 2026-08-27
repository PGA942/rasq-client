import 'package:meta/meta.dart';

/// Misskey Play(Flash)等、SNS 側のインタラクティブコンテンツへの
/// **外部リンク**(D-039)。RASQ 内では実行せず、ユーザーページの
/// クリップ/Play タブからブラウザで開く。
@immutable
class PlayInfo {
  const PlayInfo({required this.id, required this.title, this.summary, required this.url});

  final String id;
  final String title;
  final String? summary;

  /// SNS 側の実行ページ(例: `https://misskey.io/play/:id`)。
  final Uri url;
}
