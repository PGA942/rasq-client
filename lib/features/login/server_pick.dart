import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../backend/server_info_api.dart';
import '../../l10n/l10n.dart';
import '../swing/wagara.dart';
import '../vc/astell_tile.dart' show AstellTile, AstellTileStrip;

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

/// ホスト名から決まる種(FNV-1a)。同じサーバーはいつも同じ背景になる(起動ごとに変わる `String.hashCode` は使わない)。
int serverBannerSeed(String host) {
  var h = 0x811c9dc5;
  for (final c in host.toLowerCase().codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xffffffff;
  }
  return h;
}

/// バナーの無いサーバーの背景 (D-556): Swing のランダム背景(和柄、D-386 / D-387)と同じ描き方で、種はホスト名。
/// 柄の大きさは Swing の画面(1080 幅)の半分の幅で描いたものを縮めて見せる(カードの幅でも柄が読める大きさ)。
class ServerBannerPainter extends CustomPainter {
  ServerBannerPainter(this.host) : spec = SwingBackgroundSpec.random(math.Random(serverBannerSeed(host)));
  final String host;
  final SwingBackgroundSpec spec;

  /// 描くときの仮の幅。
  static const baseWidth = 540.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final k = size.width / baseWidth;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(k);
    paintSwingBackground(canvas, Size(baseWidth, size.height / k), spec);
    canvas.restore();
  }

  @override
  bool shouldRepaint(ServerBannerPainter old) => old.host != host;
}

/// カードのバナーの高さ・アイコンの大きさ。
const serverCardBannerHeight = 64.0;
const serverCardIconSize = 40.0;

/// サーバーのカード (D-556、ワイヤーフレーム p.4「サーバーなどを提案する」): 角丸の四角の中に、上からバナー
/// (Misskey は `backgroundImageUrl`、無ければ `bannerUrl`、それも無ければ**ホスト名を種にした和柄 + 下へのフェード**)→
/// バナーの下端にかかるアイコン → サーバー名 / ホスト → 説明(3 行)→「ログイン」。カードを押しても同じ。
class ServerPickCard extends ConsumerWidget {
  const ServerPickCard({super.key, required this.host, required this.kind, required this.onLogin});
  final String host;
  final SnsKind kind;

  /// null = 押せない(ほかのサーバーを確かめている間)。
  final VoidCallback? onLogin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final caption = RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant);
    final info = ref.watch(serverInfoProvider(host)).value;
    final title = info?.displayName ?? host;
    final banner = info?.backgroundImageUrl ?? info?.bannerUrl;
    final text = (info?.description ?? '').replaceAll(RegExp(r'<[^>]*>'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
    // バナーの無いサーバー: 和柄を、下(カードの地)へ溶けるように。
    final pattern = Stack(fit: StackFit.expand, children: [
      CustomPaint(key: ValueKey('login.server.$host.pattern'), painter: ServerBannerPainter(host)),
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: const [0.25, 1], colors: [scheme.surface.withValues(alpha: 0), scheme.surface]),
        ),
      ),
    ]);
    final iconFallback = ColoredBox(color: RasqSnsPill.colorOf(kind).withValues(alpha: 0.18), child: Icon(Icons.dns_outlined, size: 22, color: scheme.onSurface));
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RasqSizes.radiusLg), side: BorderSide(color: scheme.outlineVariant)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('login.server.$host'),
        onTap: onLogin,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            height: serverCardBannerHeight + serverCardIconSize / 2,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: serverCardBannerHeight,
                child: banner == null
                    ? pattern
                    : Image.network(banner.toString(), key: ValueKey('login.server.$host.banner'), fit: BoxFit.cover, errorBuilder: (_, _, _) => pattern),
              ),
              // 「…」: サーバーのページをブラウザで開く。
              Positioned(
                top: 4,
                right: 4,
                child: Material(
                  color: scheme.surface.withValues(alpha: 0.8),
                  shape: const CircleBorder(),
                  child: SizedBox.square(
                    dimension: 28,
                    child: PopupMenuButton<int>(
                      key: ValueKey('login.server.$host.more'),
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      icon: Icon(Icons.more_horiz, color: scheme.onSurface),
                      tooltip: l10n.loginServerMore,
                      onSelected: (_) => launchUrl(Uri.https(host, '/'), mode: LaunchMode.externalApplication),
                      itemBuilder: (context) => [PopupMenuItem(value: 0, child: Text(l10n.loginServerOpenInBrowser))],
                    ),
                  ),
                ),
              ),
              // アイコン(バナーの下端にかける)。
              Positioned(
                left: RasqSpacing.sm,
                top: serverCardBannerHeight - serverCardIconSize / 2,
                child: Container(
                  width: serverCardIconSize,
                  height: serverCardIconSize,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(RasqSizes.radiusSm + 2), border: Border.all(color: scheme.surface, width: 2), color: scheme.surface),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(RasqSizes.radiusSm),
                    child: info?.iconUrl == null ? iconFallback : Image.network(info!.iconUrl.toString(), fit: BoxFit.cover, errorBuilder: (_, _, _) => iconFallback),
                  ),
                ),
              ),
            ]),
          ),
          // カードは縦長の比で決まっている (D-557): 名前 / ホスト / 説明は残りの高さに入るだけ(説明は入る行数で切る)。
          // ボタンはいつも下に。
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(RasqSpacing.sm, RasqSpacing.xs, RasqSpacing.sm, 0),
              child: LayoutBuilder(builder: (context, box) {
                final lineHeight = (caption.fontSize ?? 12) * (caption.height ?? 1.4) * MediaQuery.textScalerOf(context).scale(1);
                // 名前とホストのぶん(およそ 2 行 + 間)を引いた残りに、説明が何行入るか。
                final room = box.maxHeight - lineHeight * 2.4 - RasqSpacing.xs;
                final descLines = (room / lineHeight).floor().clamp(0, 4);
                return ClipRect(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(title, style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(host, style: caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (text.isNotEmpty && descLines > 0) Padding(padding: const EdgeInsets.only(top: RasqSpacing.xs), child: Text(text, key: ValueKey('login.server.$host.desc'), style: caption, maxLines: descLines, overflow: TextOverflow.ellipsis)),
                  ]),
                );
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(RasqSpacing.sm),
            child: FilledButton(
              key: ValueKey('login.server.$host.login'),
              onPressed: onLogin,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(36), padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.sm), visualDensity: VisualDensity.compact),
              child: Text(l10n.loginButton, maxLines: 1),
            ),
          ),
        ]),
      ),
    );
  }
}

/// 2 列にする幅の下限(これより狭ければ 1 列)。カードは縦長なので、ふつうの電話の幅では 2 列。
const serverGridTwoColumnsMinWidth = 260.0;

/// カードの縦横比(幅 / 高さ)。縦長のまま (D-557)。
const serverCardAspectRatio = 0.68;

/// カードの幅 (D-560): AsTell のタイルと同じ([AstellTile.minWidth] 220px 〜 [AstellTileStrip.maxTileWidth] 600px)。
/// 幅が広がったら、カードを大きくする前に列を増やす(最大 [serverGridMaxColumns] 列)。5 列でも余るときだけ 600px まで大きくし、
/// それより広ければ中央に寄せる(大きな画面でカードの余白が広がりすぎないように)。
const serverCardMinWidth = AstellTile.minWidth;
const serverCardMaxWidth = AstellTileStrip.maxTileWidth;
const serverGridMaxColumns = 5;

/// 1 列のときのカードの幅(縦長のまま、画面いっぱいに大きくしない)。
const serverCardSingleWidth = 220.0;

/// カードの間。
const serverGridGap = RasqSpacing.sm;

/// 幅 [width] に並べる列の数 (D-560)。
int serverGridColumns(double width) {
  if (width < serverGridTwoColumnsMinWidth) return 1;
  return ((width + serverGridGap) / (serverCardMinWidth + serverGridGap)).floor().clamp(2, serverGridMaxColumns);
}

/// [cols] 列のときのカード 1 枚の幅([serverCardMaxWidth] まで)。
double serverCardWidth(double width, int cols) => math.min((width - serverGridGap * (cols - 1)) / cols, serverCardMaxWidth);

/// 「サーバーの検索」: 見出し → 検索欄(並んでいるサーバーを絞り込む)→ 有力なサーバーのカード(縦 2 列のグリッド、D-556。カードは縦長の比、D-557)。
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
      LayoutBuilder(builder: (context, box) {
        final cols = serverGridColumns(box.maxWidth);
        // カードの幅 (D-560): 1 列は 220px、2〜5 列は幅を割ったもの(600px まで)。行は中央に寄せる。
        final w = cols == 1 ? math.min(box.maxWidth, serverCardSingleWidth) : serverCardWidth(box.maxWidth, cols);
        Widget card(String host) => ServerPickCard(host: host, kind: widget.kind, onLogin: widget.enabled ? () => widget.onPick(host) : null);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < shown.length; i += cols)
            Padding(
              padding: const EdgeInsets.only(bottom: serverGridGap),
              // カードは縦長の比で決まる (D-557)。説明の長さで高さは変わらない。最後の行の空きは、左に詰める(グリッドの位置をそろえる)。
              child: Center(
                child: SizedBox(
                  width: w * cols + serverGridGap * (cols - 1),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (var j = 0; j < cols; j++) ...[
                      if (j > 0) const SizedBox(width: serverGridGap),
                      SizedBox(width: w, child: i + j < shown.length ? AspectRatio(aspectRatio: serverCardAspectRatio, child: card(shown[i + j])) : null),
                    ],
                  ]),
                ),
              ),
            ),
        ]);
      }),
    ]);
  }
}
