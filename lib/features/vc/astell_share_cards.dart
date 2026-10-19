import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';

import '../../l10n/l10n.dart';
import '../../session/session_providers.dart' show emojiCacheProvider;
import '../../text/inline_spans.dart';
import 'astell_models.dart';
import 'astell_stream.dart';

/// 共有欄のカード型横スライド (D-333)。
///
/// - 1 枚のカードは**高さ 200px、幅は最大 300px の横長の角丸四角形**。画像 / 動画は縦横比から幅を決め(300px を超えるときだけ
///   300px に揃える)、テキスト / 投稿 / 文字起こし / リンク / 配信は 300px。
/// - **配信は左端に優先表示**(ホストの配信、画面共有中のピアの画面。映像は LiveKit、届くまではサムネイル)。
/// - チャットのテキスト / 共有された投稿 / 文字起こし = **投稿インラインビュー形式**(アバター・名前・@handle・本文)。
/// - 画像 / 動画 / 配信 / プラグインの参加タイル = **表示タイル**: 左上に種類のアイコン、右上に「…」(ドロップダウン)、中央に再生ボタン(動画だけ)。
/// - 右端の「>」で**全てのピン留め**(一覧、レガシーの表示)へ。
/// 従来の縦の一覧(D-146)は設定でレガシーとして選べる([astellShareStyleProvider])。
const astellShareCardHeight = 200.0;
const astellShareCardMaxWidth = 300.0;
const astellShareCardMinWidth = 140.0;
const astellShareCardsKey = ValueKey('astell.shares.cards');
const astellShareAllKey = ValueKey('astell.shares.all');

/// 配信のカード(ホストの配信 / ピアの画面共有)。
@immutable
class AstellLiveCardData {
  const AstellLiveCardData({required this.id, required this.identity, required this.screen, required this.title, this.thumbnailUrl, required this.onTap, this.onMore});
  final String id;

  /// LiveKit の identity(アカウント id)。
  final String identity;
  final bool screen;
  final String title;
  final Uri? thumbnailUrl;
  final VoidCallback onTap;
  final void Function(Rect anchor)? onMore;
}

/// 共有欄の 1 件(共有か文字起こし)。
@immutable
class AstellShareCardEntry {
  const AstellShareCardEntry({this.share, this.transcript}) : assert(share != null || transcript != null);
  final AstellShare? share;
  final AstellTranscript? transcript;
  String get id => share?.id ?? transcript!.id;
}

/// 表示タイルで出すか(画像 / 動画 / そのほかのファイル / プラグインなど、文字でないもの)。
bool astellShareIsTile(AstellShare s) => !const {'text', 'post', 'link'}.contains(s.kind);

/// カードの幅: 画像 / 動画は縦横比(`payload.width` / `height`)から、高さ 200px 揃え。300px を超えるときだけ 300px。分からなければ 300px。
double astellShareCardWidth(AstellShare? s) {
  if (s == null || !astellShareIsTile(s)) return astellShareCardMaxWidth;
  final w = (s.payload['width'] as num?)?.toDouble();
  final h = (s.payload['height'] as num?)?.toDouble();
  if (w == null || h == null || w <= 0 || h <= 0) return astellShareCardMaxWidth;
  return (astellShareCardHeight * w / h).clamp(astellShareCardMinWidth, astellShareCardMaxWidth);
}

/// カードを出すのに要る最低の高さ。これより狭い(ルーム FOW が低い / 画面が小さい)ときは見出しの行と「>」だけ。
const astellShareCardMinHeight = 96.0;

class AstellShareCards extends StatelessWidget {
  const AstellShareCards({super.key, required this.lives, required this.entries, required this.myHandle, required this.onOpen, required this.onMore, required this.onShowAll, this.onUnpin, this.height = astellShareCardHeight});
  final List<AstellLiveCardData> lives;

  /// カードの高さ(最大 [astellShareCardHeight])。幅は高さに比例して縮む。
  final double height;

  /// 新しい順。
  final List<AstellShareCardEntry> entries;
  final String myHandle;
  final void Function(AstellShare share) onOpen;
  final void Function(AstellShare share, Rect anchor) onMore;
  final void Function(AstellShareCardEntry entry)? onUnpin;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final count = lives.length + entries.length;
    final cramped = height < astellShareCardMinHeight;
    // 高さに合わせて幅も縮める(縦横比を保つ)。
    final k = cramped ? 1.0 : height / astellShareCardHeight;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, cramped && count > 0 ? RasqSpacing.xs : RasqSpacing.page, RasqSpacing.xs),
          child: Row(
            children: [
              Expanded(
                child: Text(count == 0 ? context.l10n.vcShares : context.l10n.vcSharesCount(count), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
              ),
              // 狭くてカードを出せないときは、見出しの右の「>」から一覧へ。
              if (cramped && count > 0) RasqIconButton(key: astellShareAllKey, icon: Icons.chevron_right, size: 20, tooltip: context.l10n.vcSharesShowAll, onPressed: onShowAll),
            ],
          ),
        ),
        if (count == 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.xs),
            child: Text(context.l10n.vcSharesEmpty, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          )
        else if (!cramped)
          SizedBox(
            key: astellShareCardsKey,
            height: height,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
              children: [
                for (final l in lives) ...[
                  SizedBox(
                    width: astellShareCardMaxWidth * k,
                    height: height,
                    child: _LiveCard(key: ValueKey('astell.card.live.${l.id}'), data: l),
                  ),
                  const SizedBox(width: RasqSpacing.sm),
                ],
                for (final e in entries) ...[
                  SizedBox(
                    key: ValueKey('astell.card.${e.id}'),
                    width: astellShareCardWidth(e.share) * k,
                    height: height,
                    child: e.share != null
                        ? (astellShareIsTile(e.share!) ? _ShareTile(share: e.share!, onOpen: () => onOpen(e.share!), onMore: (r) => onMore(e.share!, r)) : _InlineCard.share(share: e.share!, mine: e.share!.handle == myHandle || e.share!.accountId == 'me', onOpen: () => onOpen(e.share!), onMore: (r) => onMore(e.share!, r)))
                        : _InlineCard.transcript(transcript: e.transcript!, onUnpin: onUnpin == null ? null : () => onUnpin!(e)),
                  ),
                  const SizedBox(width: RasqSpacing.sm),
                ],
                // 右端の「>」: 全てのピン留め(一覧、レガシーの表示)へ。
                Center(
                  child: Tooltip(
                    message: context.l10n.vcSharesShowAll,
                    child: Material(
                      key: astellShareAllKey,
                      color: scheme.surfaceContainerHigh,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: onShowAll,
                        child: const SizedBox(width: 44, height: 44, child: Icon(Icons.chevron_right)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 表示タイルの共通の枠: 角丸、左上にアイコン、右上に「…」。
class _TileFrame extends StatelessWidget {
  const _TileFrame({required this.icon, required this.background, required this.onTap, this.onMore, this.center, this.caption, this.label, this.labelColor});
  final IconData icon;
  final Widget background;
  final VoidCallback onTap;
  final void Function(Rect anchor)? onMore;
  final Widget? center;
  final String? caption;
  final String? label;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(RasqSizes.radiusMd),
      child: Material(
        color: Colors.black,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              background,
              if (center != null) Center(child: center),
              Positioned(
                left: 8,
                top: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
                      child: Icon(icon, size: 16, color: Colors.white),
                    ),
                    if (label != null) ...[const SizedBox(width: 4), RasqPill(label: label!, color: labelColor ?? RasqColors.sub, textColor: Colors.white)],
                  ],
                ),
              ),
              // 「…」は左上の種類のアイコンと同じ大きさ・高さ・見た目で右上に (D-336)。
              if (onMore != null)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Builder(
                    builder: (ctx) => Tooltip(
                      message: context.l10n.vcShareActions,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () {
                            final box = ctx.findRenderObject() as RenderBox;
                            onMore!(box.localToGlobal(Offset.zero) & box.size);
                          },
                          child: const SizedBox(width: 28, height: 28, child: Icon(Icons.more_horiz, size: 16, color: Colors.white)),
                        ),
                      ),
                    ),
                  ),
                ),
              if (caption != null)
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 6,
                  child: Text(
                    caption!,
                    style: RasqTypography.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _thumb(BuildContext context, Uri? url) {
  final scheme = Theme.of(context).colorScheme;
  if (url == null) return ColoredBox(color: scheme.surfaceContainerHighest);
  return Image.network(
    webHtmlElementStrategy: rasqWebImageStrategy,
    url.toString(),
    fit: BoxFit.cover,
    errorBuilder: (_, _, _) => ColoredBox(color: scheme.surfaceContainerHighest),
  );
}

class _LiveCard extends StatelessWidget {
  const _LiveCard({super.key, required this.data});
  final AstellLiveCardData data;
  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: _TileFrame(
        icon: data.screen ? Icons.desktop_windows : Icons.videocam,
        label: 'LIVE',
        labelColor: RasqColors.live,
        onTap: data.onTap,
        onMore: data.onMore,
        caption: data.title,
        background: AstellLiveVideo(identity: data.identity, screen: data.screen, fit: BoxFit.cover, fallback: _thumb(context, data.thumbnailUrl)),
      ),
    );
  }
}

class _ShareTile extends StatelessWidget {
  const _ShareTile({required this.share, required this.onOpen, required this.onMore});
  final AstellShare share;
  final VoidCallback onOpen;
  final void Function(Rect anchor) onMore;
  @override
  Widget build(BuildContext context) {
    final s = share;
    final icon = switch (s.mediaClass) {
      'image' => Icons.image_outlined,
      'video' => Icons.movie_outlined,
      'media' || 'file' => Icons.insert_drive_file_outlined,
      _ => Icons.extension_outlined, // プラグインの参加タイルなど
    };
    return _TileFrame(
      icon: icon,
      onTap: onOpen,
      onMore: onMore,
      // 再生ボタンは動画だけ。
      center: s.isVideo ? const Icon(Icons.play_circle_fill, size: 48, color: Colors.white70) : null,
      caption: '${s.displayName}: ${s.headline}',
      background: s.thumbnailUrl != null
          ? _thumb(context, s.thumbnailUrl)
          : ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Center(child: Icon(icon, size: 40, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
    );
  }
}

/// 投稿インラインビュー形式のカード(テキスト / 投稿 / リンク / 文字起こし)。
///
/// D-336: 画像があれば**左に、カードの高さの 9 割**で出す(アイコンや本文は右へずれる)。ユーザー ID(@handle)は出さず、
/// **サーバーのアイコンとサーバー名**(投稿はその SNS のインスタンス、リンクはそのサイト、チャット / 文字起こしは RASQ)。
/// 「…」は右端。
class _InlineCard extends ConsumerWidget {
  const _InlineCard.share({required AstellShare this.share, required this.mine, required this.onOpen, required void Function(Rect) this.onMore}) : transcript = null, onUnpin = null;
  const _InlineCard.transcript({required AstellTranscript this.transcript, this.onUnpin}) : share = null, mine = false, onOpen = null, onMore = null;
  final AstellShare? share;
  final AstellTranscript? transcript;
  final bool mine;
  final VoidCallback? onOpen;
  final void Function(Rect anchor)? onMore;
  final VoidCallback? onUnpin;

  /// サーバーの表示(アイコン + 名前)。
  Widget _server(BuildContext context) {
    final s = share;
    final style = RasqTypography.caption.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    if (s != null && s.kind == 'post') {
      final kind = SnsKind.values.where((k) => k.name == s.payload['sns']).firstOrNull ?? SnsKind.other;
      final instance = s.payload['instance'] as String? ?? s.url?.host ?? '';
      if (instance.isNotEmpty) return DefaultTextStyle.merge(style: style, child: RasqSnsPill(account: AccountId(kind: kind, instance: instance, handle: ''), dotSize: 12));
    }
    if (s != null && s.kind == 'link' && (s.url?.host.isNotEmpty ?? false)) {
      return DefaultTextStyle.merge(style: style, child: RasqSnsPill(account: AccountId(kind: SnsKind.other, instance: s.url!.host, handle: ''), dotSize: 12));
    }
    // チャット / 文字起こし: RASQ(AsTell)。
    return Row(mainAxisSize: MainAxisSize.min, children: [
      const RasqBrandIcon(size: 12),
      const SizedBox(width: 3),
      Flexible(child: Text(transcript != null ? context.l10n.vcShareTranscriptSource : 'RASQ', style: style, maxLines: 1, overflow: TextOverflow.ellipsis)),
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final emojis = ref.watch(emojiCacheProvider);
    final s = share;
    final t = transcript;
    // 投稿の共有はその投稿の作者(payload)、テキスト / 文字起こしは発言者。
    final isPost = s != null && s.kind == 'post';
    final name = isPost ? (s.payload['author'] as String? ?? s.displayName) : (s?.displayName ?? t!.displayName);
    final avatar = isPost ? Uri.tryParse(s.payload['avatarUrl'] as String? ?? '') : null;
    final body = s != null ? s.headline : t!.text;
    final thumbs = <Uri>[
      if (isPost)
        for (final m in (s.payload['media'] as List? ?? const []))
          if (m is Map && (m['thumbnailUrl'] ?? m['url']) is String) ?Uri.tryParse((m['thumbnailUrl'] ?? m['url']) as String),
      if (s != null && s.kind == 'link' && s.thumbnailUrl != null) s.thumbnailUrl!,
    ];
    Widget? trailing;
    if (onMore != null) {
      trailing = Builder(
        builder: (ctx) => RasqIconButton(
          icon: Icons.more_horiz,
          size: 18,
          tooltip: context.l10n.vcShareActions,
          onPressed: () {
            final box = ctx.findRenderObject() as RenderBox;
            onMore!(box.localToGlobal(Offset.zero) & box.size);
          },
        ),
      );
    } else if (onUnpin != null && t != null && t.pinned) {
      trailing = RasqIconButton(icon: Icons.push_pin, size: 16, color: RasqColors.link, tooltip: context.l10n.vcUnpin, onPressed: onUnpin);
    }
    return Material(
      color: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RasqSizes.radiusMd), side: BorderSide(color: scheme.outline)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: LayoutBuilder(builder: (context, c) {
          // 画像: カードの高さの 9 割(上下に 5% ずつの余白)、幅は高さと同じまで(カードの 4 割を超えない)。
          final imgH = c.maxHeight * 0.9;
          final imgW = imgH.clamp(0.0, c.maxWidth * 0.4);
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (thumbs.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(c.maxHeight * 0.05, c.maxHeight * 0.05, 0, c.maxHeight * 0.05),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(RasqSizes.radiusSm),
                  child: SizedBox(
                    key: const ValueKey('astell.card.image'),
                    width: imgW,
                    height: imgH,
                    child: Stack(fit: StackFit.expand, children: [
                      // 閲覧注意 / CW 付きはぼかして印を出す(開いてから見る、TERMS-10)。
                      if (s != null && (s.isSensitive || s.contentWarning != null))
                        Stack(fit: StackFit.expand, children: [
                          ImageFiltered(imageFilter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18), child: _thumb(context, thumbs.first)),
                          Container(
                            key: const ValueKey('astell.card.sensitive'),
                            color: Colors.black.withValues(alpha: 0.35),
                            alignment: Alignment.center,
                            child: const Icon(Icons.visibility_off_outlined, color: Colors.white, size: 22),
                          ),
                        ])
                      else
                        _thumb(context, thumbs.first),
                      if (thumbs.length > 1)
                        Positioned(
                          right: 4,
                          bottom: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(8)),
                            child: Text('+${thumbs.length - 1}', style: RasqTypography.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                          ),
                        ),
                    ]),
                  ),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(RasqSpacing.sm, RasqSpacing.sm, 0, RasqSpacing.sm),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    RasqAvatar(imageUrl: avatar, size: 28, fallbackLabel: name),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        RasqRichText(InlineSpans.parse(mine && !isPost ? context.l10n.vcYou : name, emojis: emojis), style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                        _server(context),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Expanded(child: ClipRect(child: RasqRichText(InlineSpans.parse(body, emojis: emojis), style: RasqTypography.bodySmall, maxLines: 8, overflow: TextOverflow.ellipsis))),
                ]),
              ),
            ),
            // 「…」は右端(右上)。
            if (trailing != null) trailing else const SizedBox(width: RasqSpacing.sm),
          ]);
        }),
      ),
    );
  }
}
