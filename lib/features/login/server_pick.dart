import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../backend/server_info_api.dart';
import '../../l10n/l10n.dart';

/// ログインの画面の「サーバーの検索」(D-554、ワイヤーフレーム p.4「PDS変更 / インスタンスURL入力」)。
///
/// URL の欄は空のまま、下に**有力なサーバーを 10 個ほど**並べ、タイルを押すとそのまま認証へ進む。検索欄は並んでいるサーバーを
/// 絞り込む(名前 / ホスト)。並びは端末に持つ一覧([popularServers])で、名前・アイコン・説明は Central のサーバー情報
/// (`/servers/{host}/info`、6 時間の控え)から。Central が無い / 読めないときはホスト名だけで出す。

/// 有力なサーバー(SNS ごと、上から順に出す)。一覧を Central から配るようにするときは、[popularServersProvider] を差し替える。
const popularServers = <SnsKind, List<String>>{
  SnsKind.misskey: ['misskey.io', 'misskey.design', 'misskey.art', 'nijimiss.moe', 'sushi.ski', 'oekakiskey.com', 'misskey.cloud', 'live-theater.net', 'misskey.backspace.fm', 'novelskey.tarbin.net'],
  SnsKind.mastodon: ['mastodon.social', 'mstdn.jp', 'fedibird.com', 'pawoo.net', 'mastodon.online', 'mas.to', 'mstdn.social', 'fosstodon.org', 'mastodon.world', 'hachyderm.io'],
  SnsKind.bluesky: ['bsky.social'],
};

/// 一覧に出す数。
const popularServersMax = 10;

final popularServersProvider = Provider.family<List<String>, SnsKind>((ref, kind) => (popularServers[kind] ?? const <String>[]).take(popularServersMax).toList());

/// 入力欄の文字 → ホスト名(`https://` と、パスを外して小文字に)。
String serverHostOf(String input) => input.trim().replaceFirst(RegExp(r'^https?://'), '').split('/').first.toLowerCase();

/// サーバーのタイル(ワイヤーフレーム p.4): 左にアイコン、名前(太字)と右上の「…」、その下にホスト、説明(2 行)、右端に「>」。
/// [name] / [iconUrl] / [description] を渡せばそれを使い、無ければ Central のサーバー情報を読む。
class ServerPickTile extends ConsumerWidget {
  const ServerPickTile({super.key, required this.host, required this.kind, this.onTap, this.name, this.iconUrl, this.description, this.trailing});
  final String host;
  final SnsKind kind;

  /// null = 押せない(確かめたサーバーの表示。「>」も出さない)。
  final VoidCallback? onTap;
  final String? name;
  final Uri? iconUrl;
  final String? description;

  /// 名前の右に足すもの(「登録の受付なし」の印など)。
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final caption = RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant);
    // 渡された情報が無いときだけ、Central に聞く(Bluesky の PDS は nodeinfo が無いので、ホスト名だけで出る)。
    final info = name == null ? ref.watch(serverInfoProvider(host)).value : null;
    final title = name ?? info?.displayName ?? host;
    final icon = iconUrl ?? info?.iconUrl;
    final text = (description ?? info?.description ?? '').replaceAll(RegExp(r'<[^>]*>'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('login.server.$host'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: RasqSpacing.sm),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(RasqSizes.radiusSm),
                    child: SizedBox.square(
                      dimension: 44,
                      child: icon == null
                          ? ColoredBox(color: RasqSnsPill.colorOf(kind).withValues(alpha: 0.18), child: Icon(Icons.dns_outlined, size: 22, color: scheme.onSurface))
                          : Image.network(icon.toString(), fit: BoxFit.cover, errorBuilder: (_, _, _) => ColoredBox(color: RasqSnsPill.colorOf(kind).withValues(alpha: 0.18), child: Icon(Icons.dns_outlined, size: 22, color: scheme.onSurface))),
                    ),
                  ),
                  const SizedBox(width: RasqSpacing.sm),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Row(children: [
                        Expanded(child: Text(title, style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        if (trailing != null) Padding(padding: const EdgeInsets.only(left: RasqSpacing.xs), child: trailing),
                        // 「…」: サーバーのページをブラウザで開く。
                        SizedBox(
                          height: 24,
                          child: PopupMenuButton<int>(
                            key: ValueKey('login.server.$host.more'),
                            padding: EdgeInsets.zero,
                            iconSize: 18,
                            icon: Icon(Icons.more_horiz, color: scheme.onSurfaceVariant),
                            tooltip: context.l10n.loginServerMore,
                            onSelected: (_) => launchUrl(Uri.https(host, '/'), mode: LaunchMode.externalApplication),
                            itemBuilder: (context) => [PopupMenuItem(value: 0, child: Text(context.l10n.loginServerOpenInBrowser))],
                          ),
                        ),
                      ]),
                      Text(host, style: caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ]),
                  ),
                ]),
                if (text.isNotEmpty) Padding(padding: const EdgeInsets.only(top: RasqSpacing.xs), child: Text(text, style: caption, maxLines: 2, overflow: TextOverflow.ellipsis)),
              ]),
            ),
            if (onTap != null) Icon(Icons.chevron_right, color: scheme.onSurface),
          ]),
        ),
      ),
    );
  }
}

/// 「サーバーの検索」: 見出し → 検索欄(並んでいるサーバーを絞り込む)→ 有力なサーバーのタイル。
class ServerPickList extends ConsumerStatefulWidget {
  const ServerPickList({super.key, required this.kind, required this.onPick, this.enabled = true});
  final SnsKind kind;
  final ValueChanged<String> onPick;
  final bool enabled;

  @override
  ConsumerState<ServerPickList> createState() => _ServerPickListState();
}

class _ServerPickListState extends ConsumerState<ServerPickList> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final all = ref.watch(popularServersProvider(widget.kind));
    final q = _query.text.trim().toLowerCase();
    final shown = [
      for (final host in all)
        if (q.isEmpty || host.contains(q) || (ref.watch(serverInfoProvider(host)).value?.displayName.toLowerCase().contains(q) ?? false)) host,
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      RasqSectionHeader(title: l10n.loginSnsServerSection, topMargin: 0),
      RasqInput(
        key: const ValueKey('login.server.search'),
        controller: _query,
        hintText: l10n.loginServerSearchHint,
        textInputAction: TextInputAction.search,
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: RasqSpacing.xs),
      if (shown.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: RasqSpacing.md),
          child: Text(l10n.loginServerSearchEmpty, key: const ValueKey('login.server.none'), style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant)),
        ),
      for (final host in shown) ...[
        ServerPickTile(host: host, kind: widget.kind, onTap: widget.enabled ? () => widget.onPick(host) : null),
        Divider(height: 1, color: scheme.outlineVariant),
      ],
    ]);
  }
}
