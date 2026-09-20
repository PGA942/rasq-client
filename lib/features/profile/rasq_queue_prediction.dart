import 'dart:math' as math;

import '../../backend/rasq_account_page_api.dart';

/// キューの予測 (D-279)。SNS のリアクションの予測 (D-041) と同じ考え方で、**純ローカル**に決める:
/// 投稿に付いているキューのうち、自分が持っているパックの絵(件数の多いものほど出やすい。投稿ごとに決まった 1 つ)→
/// 無ければ、最近使った自分の絵 → それも無ければ null(ボタンは素のアイコンのまま、押すとピッカー)。
({String packId, String stickerId, Uri url})? predictQueue(
  RasqAccountPost post, {
  required Set<String> ownedPacks,
  List<String> recent = const [],
  Uri? central,
}) {
  final usable = [
    for (final q in post.queues)
      if (!q.like && q.packId != null && q.url != null && ownedPacks.contains(q.packId)) q,
  ]..sort((a, b) => b.count.compareTo(a.count));
  if (usable.isNotEmpty) {
    final weights = [for (var i = 0; i < usable.length; i++) math.pow(2.0, -i).toDouble()];
    var roll = math.Random(post.id.hashCode).nextDouble() * weights.fold<double>(0, (a, b) => a + b);
    var pick = usable.first;
    for (var i = 0; i < usable.length; i++) {
      roll -= weights[i];
      if (roll <= 0) {
        pick = usable[i];
        break;
      }
    }
    return (packId: pick.packId!, stickerId: pick.stickerId, url: pick.url!);
  }
  if (central == null) return null;
  for (final key in recent) {
    final parts = key.split('|');
    if (parts.length != 2 || !ownedPacks.contains(parts[0])) continue;
    return (packId: parts[0], stickerId: parts[1], url: central.replace(path: '/api/v1/plugins/${parts[0]}/stickers/${parts[1]}', query: null));
  }
  return null;
}
