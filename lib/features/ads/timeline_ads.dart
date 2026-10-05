import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../session/session_providers.dart';
import '../settings/settings_dsl.dart';
import 'ad_placement.dart';
import 'export_ad.dart';

/// TL 系の広告枠 (D-438、D-433 をホーム以外へ)。
///
/// - 置き場所: 投稿の並びの [timelineAdEvery] 件ごと。危ない投稿(CW / センシティブ)の隣には置かない([adGaps] / [postAdSafe])。
///   最後の投稿のあとには置かない。トレンド TL / ユーザーページ / リスト / クリップ / 関連 TL / 返信 / RASQ アカウントページ /
///   検索の結果、と D-433 のホーム。
/// - 中身: いまの SNS のサーバーが広告を出していれば(Misskey の `meta.ads`、[SnsSession.serverAds])、**AdMob と交互**に
///   (偶数番目 = AdMob、奇数番目 = サーバーの広告)。無ければ AdMob だけ。
/// - 出さない: 設定「リソースと広告」の `showAds` がオフ / 子のアカウント / 見守りの状態が分かる前([exportAdAllowedProvider])。
///   サーバーの広告も同じ決まりに従う。

/// TL の投稿の間の広告の間隔(件、D-433)。
const timelineAdEvery = 10;

/// 広告を出してよいか(設定 + 子のアカウント)。
bool timelineAdsOn(WidgetRef ref) => settingValue(ref, 'resources', 'showAds', true) != false && ref.watch(exportAdAllowedProvider);

/// [posts] の並びで、広告を前に置く項目の番号(出さないなら空)。
Set<int> timelineAdGaps(WidgetRef ref, List<Post> posts, {int every = timelineAdEvery}) =>
    timelineAdsOn(ref) ? adGaps(posts.length, (i) => postAdSafe(posts[i]), every: every).toSet() : const <int>{};

/// [rows](= [posts] の 1 件ずつの行)に広告枠を挟んだ並び。キーは `<scope>.ad.<番号>`。
List<Widget> withTimelineAds(WidgetRef ref, List<Post> posts, List<Widget> rows, {required String scope}) {
  assert(posts.length == rows.length);
  final gaps = timelineAdGaps(ref, posts);
  var n = 0;
  return [
    for (var i = 0; i < rows.length; i++) ...[
      if (gaps.contains(i)) TimelineAdSlot(key: ValueKey('$scope.ad.$i'), ordinal: n++),
      rows[i],
    ],
  ];
}

/// いまの SNS のサーバーの広告(今日出してよいもの、横長だけ)。
final serverAdsProvider = FutureProvider<List<ServerAd>>((ref) async {
  final session = ref.watch(currentSnsSessionProvider);
  if (session == null) return const [];
  final today = DateTime.now().weekday;
  final ads = await session.serverAds();
  return [for (final a in ads) if (a.ratio > 0 && a.place != 'square' && a.showsOn(today)) a];
});

/// [ordinal] 番目の広告枠に出すサーバーの広告(割合 [ServerAd.ratio] で重みを付け、同じ番目は同じ広告)。
ServerAd? pickServerAd(List<ServerAd> ads, int ordinal) {
  if (ads.isEmpty) return null;
  final total = ads.fold<int>(0, (s, a) => s + a.ratio);
  if (total <= 0) return null;
  var r = (ordinal * 7919) % total;
  for (final a in ads) {
    if (r < a.ratio) return a;
    r -= a.ratio;
  }
  return ads.last;
}

/// 広告枠 1 つ。[ordinal] = 並びの中で何番目の広告枠か(交互にするため)。
class TimelineAdSlot extends ConsumerWidget {
  const TimelineAdSlot({super.key, required this.ordinal});
  final int ordinal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!timelineAdsOn(ref)) return const SizedBox.shrink();
    final ad = ordinal.isOdd ? pickServerAd(ref.watch(serverAdsProvider).value ?? const [], ordinal ~/ 2) : null;
    if (ad != null) return ServerAdBanner(ad: ad, host: ref.watch(currentSnsSessionProvider)?.account.instance);
    return const Center(child: ExportAdSlot());
  }
}

/// サーバーの広告(画像 + 「広告」の印)。押すと外のブラウザで開く。読めなければ何も出さない。
class ServerAdBanner extends StatelessWidget {
  const ServerAdBanner({super.key, required this.ad, this.host});
  final ServerAd ad;
  final String? host;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      key: ValueKey('serverAd.${ad.id}'),
      padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(host == null ? '広告' : '広告 · $host', style: RasqTypography.caption.copyWith(color: muted)),
        const SizedBox(height: 2),
        Semantics(
          link: true,
          label: '広告を開く',
          child: InkWell(
            onTap: () => launchUrl(ad.url, mode: LaunchMode.externalApplication),
            borderRadius: BorderRadius.circular(8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: ad.place == 'horizontal-big' ? 240 : 120, maxWidth: 600),
                child: Image.network(webHtmlElementStrategy: rasqWebImageStrategy, ad.imageUrl.toString(), fit: BoxFit.contain, errorBuilder: (_, _, _) => const SizedBox.shrink()),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
