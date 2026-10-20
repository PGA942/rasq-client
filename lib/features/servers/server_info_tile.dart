import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../backend/server_info_api.dart';
import '../../l10n/l10n.dart';

/// サーバー情報タイル (D-345)。**インスタンスのあるサービスだけ**(Central S-043 が nodeinfo で見分ける。Bluesky など
/// インスタンスの無いもの / 分からないものは何も出さない)。上から バナー → アイコン + サーバー名 + ホスト → ソフトとバージョン /
/// 人数 / 投稿数 / 登録の受付 → 説明(3 行)→ **クラウド版 RAi によるユーザーの特性の解説**(コミュニティの話が出てきている
/// サーバーだけ。それ以外は欄ごと出さない)→「サーバーを開く」。
class ServerInfoTile extends ConsumerWidget {
  const ServerInfoTile({super.key, required this.host, this.withRai = true, this.onOpen, this.openLabel});
  final String host;

  /// RAi の解説を引くか(一覧に並べるときは切る)。
  final bool withRai;

  /// 「サーバーを開く」の差し替え(既定 = ブラウザ)。
  final VoidCallback? onOpen;

  /// そのボタンの文言(オンボーディングでは「このサーバーに登録」、D-412)。null = 「サーバーを開く」。
  final String? openLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(serverInfoProvider(host));
    return info.when(
      loading: () => const SizedBox(height: 48, child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))),
      error: (_, _) => const SizedBox.shrink(),
      data: (i) => i == null ? const SizedBox.shrink() : _ServerInfoCard(info: i, withRai: withRai, onOpen: onOpen, openLabel: openLabel ?? context.l10n.serversOpen),
    );
  }
}

class _ServerInfoCard extends ConsumerWidget {
  const _ServerInfoCard({required this.info, required this.withRai, this.onOpen, required this.openLabel});
  final RasqServerInfo info;
  final bool withRai;
  final VoidCallback? onOpen;
  final String openLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final rai = withRai ? ref.watch(serverRaiProvider(info.host)).value : null;
    final theme = _color(info.themeColor) ?? RasqColors.sub;
    final stats = [
      if (info.software != null) '${info.software}${info.version == null ? '' : ' ${info.version}'}',
      if (info.users != null) context.l10n.serversUsers(_count(info.users!)),
      if (info.posts != null) context.l10n.serversPosts(_count(info.posts!)),
      if (info.registrationOpen != null) info.registrationOpen! ? context.l10n.serversRegistrationOpen : context.l10n.serversRegistrationClosed,
    ];
    return Container(
      key: ValueKey('server.tile.${info.host}'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(RasqSizes.radiusLg),
        gradient: LinearGradient(colors: [theme.withValues(alpha: 0.22), RasqColors.main.withValues(alpha: 0.08)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        if (info.bannerUrl != null) SizedBox(height: 64, child: Image.network(info.bannerUrl.toString(), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink())),
        Padding(
          padding: const EdgeInsets.all(RasqSpacing.sm),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(RasqSizes.radiusSm),
                child: SizedBox.square(
                  dimension: 32,
                  child: info.iconUrl == null
                      ? ColoredBox(color: theme.withValues(alpha: 0.4), child: const Icon(Icons.dns_outlined, size: 18))
                      : Image.network(info.iconUrl.toString(), fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.dns_outlined, size: 18)),
                ),
              ),
              const SizedBox(width: RasqSpacing.sm),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(info.displayName, style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(info.host, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
            ]),
            if (stats.isNotEmpty) ...[
              const SizedBox(height: RasqSpacing.xs),
              Text(stats.join(context.l10n.serversStatsSeparator), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            if (info.description?.trim().isNotEmpty ?? false) ...[
              const SizedBox(height: RasqSpacing.xs),
              Text(_plain(info.description!), style: RasqTypography.bodySmall, maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
            if (rai != null && rai.showable) _RaiSection(profile: rai),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: ValueKey('server.tile.open.${info.host}'),
                onPressed: onOpen ?? () => launchUrl(Uri.https(info.host, '/'), mode: LaunchMode.externalApplication),
                child: Text(openLabel),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// クラウド版 RAi の解説。本文は出さず、RAi の要約と短い語だけ。
class _RaiSection extends StatelessWidget {
  const _RaiSection({required this.profile});
  final RaiServerProfile profile;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: ValueKey('server.tile.rai.${profile.host}'),
      margin: const EdgeInsets.only(top: RasqSpacing.sm),
      padding: const EdgeInsets.all(RasqSpacing.sm),
      decoration: BoxDecoration(color: scheme.surface.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(RasqSizes.radiusMd)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          const Icon(Icons.auto_awesome, size: 14, color: RasqColors.sub),
          const SizedBox(width: RasqSpacing.xs),
          Expanded(child: Text(context.l10n.serversRaiTitle, style: RasqTypography.caption.copyWith(fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: RasqSpacing.xs),
        Text(profile.summary!.trim(), style: RasqTypography.bodySmall),
        if (profile.traits.isNotEmpty || profile.topics.isNotEmpty) ...[
          const SizedBox(height: RasqSpacing.xs),
          Wrap(spacing: RasqSpacing.xs, runSpacing: RasqSpacing.xs, children: [
            for (final t in profile.traits.take(4)) _Chip(t, color: RasqColors.sub),
            for (final t in profile.topics.take(4)) _Chip('#$t', color: RasqColors.link),
          ]),
        ],
        const SizedBox(height: RasqSpacing.xs),
        Text(context.l10n.serversRaiSource(profile.sampleCount), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, {required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: RasqTypography.caption.copyWith(color: color)),
      );
}

/// 本文に埋めるサーバー情報タイル(PostRow 用、AsTell のタイルと同じ置き方)。
class ServerInfoPostTile extends StatelessWidget {
  const ServerInfoPostTile({super.key, required this.host});
  final String host;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: RasqSpacing.xs), child: ServerInfoTile(host: host));
}

/// サーバー情報の FOW(ユーザーページの … から)。インスタンスでなければ案内だけ。
Future<void> showServerInfoFow(WidgetRef ref, String host) async {
  final manager = ref.read(overlayManagerProvider);
  final info = await ref.read(serverInfoProvider(host).future);
  await manager.showBottomSheet<void>(
    id: 'server.info',
    title: appL10n.serversInfoTitle,
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.md),
      child: info == null ? Text(appL10n.serversInfoUnavailable(host), style: RasqTypography.bodySmall) : ServerInfoTile(host: host),
    ),
  );
}

String _count(int n) {
  if (n >= 100000000) return appL10n.serversCountHundredMillions((n / 100000000).toStringAsFixed(1));
  if (n >= 10000) return appL10n.serversCountTenThousands((n / 10000).toStringAsFixed(n >= 100000 ? 0 : 1));
  return '$n';
}

/// 説明の HTML(Mastodon)をざっくり文字だけに。
String _plain(String s) => s.replaceAll(RegExp(r'<br\s*/?>|</p>\s*<p>'), '\n').replaceAll(RegExp(r'<[^>]+>'), '').replaceAll('&amp;', '&').replaceAll('&lt;', '<').replaceAll('&gt;', '>').replaceAll('&quot;', '"').replaceAll('&#39;', "'").trim();

Color? _color(String? hex) {
  if (hex == null) return null;
  final m = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(hex.trim());
  return m == null ? null : Color(0xFF000000 | int.parse(m.group(1)!, radix: 16));
}
