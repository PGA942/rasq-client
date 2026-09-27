import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:rasq_design/rasq_design.dart';

import 'store_models.dart';

/// ストアのプラグインタイル (D-353)。**明るい色の角丸四角**(色はプラグイン id から決まる = 開くたびに変わらない)の中に、
/// 左上 = アイコン + 名前 + 開発者 / 出どころ、その直下 = **プレビュー画像の自動スライド**、右側 = 説明と DL 数 / 評価 / サイズ / 価格。
/// ストアホームの横の列(AsTell のホームと同じ並べ方)と、検索画面のグリッドで使う。
class StorePluginTile extends StatelessWidget {
  const StorePluginTile({super.key, required this.card, this.installed = false, this.onTap, this.width = storeTileWidth, this.height = storeTileHeight});
  final StorePluginCard card;
  final bool installed;
  final VoidCallback? onTap;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final bg = storeTileColor(card.id);
    const ink = Color(0xFF1B1B1F);
    final muted = ink.withValues(alpha: 0.62);
    final statusNote = card.status == PluginStatus.published ? null : card.status.label;
    final stats = [
      if (card.rating > 0) '★${card.rating.toStringAsFixed(1)}',
      '${formatStoreDownloads(card.downloads)} DL',
      if (card.sizeMb > 0) '${card.sizeMb.toStringAsFixed(card.sizeMb < 1 ? 2 : 1)}MB',
      card.price == 0 ? '無料' : '¥${card.price.toStringAsFixed(0)}',
      if (card.hasAds) '広告あり',
    ];
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        key: ValueKey('store.tile.${card.id}'),
        color: bg,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // 左: 見出し + プレビュー。
              Expanded(
                flex: 11,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    _Icon(url: card.iconUrl, color: bg),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(card.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: RasqTypography.body.copyWith(color: ink, fontWeight: FontWeight.w700)),
                        Text(
                          [if (card.developerName.isNotEmpty) card.developerName, card.origin.label].join(' ・ '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: RasqTypography.caption.copyWith(color: muted),
                        ),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Expanded(child: StorePreviewSlider(key: ValueKey('store.tile.preview.${card.id}'), images: card.tilePreviews, placeholderColor: bg)),
                ]),
              ),
              const SizedBox(width: 10),
              // 右: 説明と数字。
              Expanded(
                flex: 9,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Text(card.summary, overflow: TextOverflow.fade, style: RasqTypography.bodySmall.copyWith(color: ink, height: 1.35)),
                  ),
                  const SizedBox(height: 6),
                  Wrap(spacing: 4, runSpacing: 4, children: [
                    if (installed) _Badge('インストール済み', color: RasqColors.sub),
                    if (statusNote != null) _Badge(statusNote, color: card.status.isCaution ? RasqColors.danger : RasqColors.accent),
                  ]),
                  const SizedBox(height: 4),
                  Text(stats.join(' ・ '), maxLines: 2, overflow: TextOverflow.ellipsis, style: RasqTypography.caption.copyWith(color: muted)),
                  if (card.version.isNotEmpty) Text('v${card.version}', style: RasqTypography.caption.copyWith(color: muted)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// タイルの大きさ(ユーザー指定 ≈ 400 × 300)。
const storeTileWidth = 400.0;
const storeTileHeight = 300.0;

/// プラグイン id から明るい色(パステル)を決める。同じプラグインはいつも同じ色。
Color storeTileColor(String id) {
  var h = 0;
  for (final c in id.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return HSLColor.fromAHSL(1, (h % 360).toDouble(), 0.72, 0.86).toColor();
}

String formatStoreDownloads(int n) => n >= 10000 ? '${(n / 10000).toStringAsFixed(1)}万' : '$n';

class _Icon extends StatelessWidget {
  const _Icon({required this.url, required this.color});
  final Uri? url;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(color: HSLColor.fromColor(color).withLightness(0.7).toColor(), child: const Icon(Icons.extension_outlined, size: 22, color: Color(0xFF1B1B1F)));
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox.square(
        dimension: 40,
        child: url == null ? fallback : Image.network(webHtmlElementStrategy: rasqWebImageStrategy, '$url', fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, {required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: RasqTypography.caption.copyWith(color: color, fontWeight: FontWeight.w700)),
      );
}

/// プレビュー画像の自動スライド (D-353)。2 枚以上なら一定間隔で次へ(指で送っても良い)、下に点。無ければアイコンの色の面。
/// テスト中(`FLUTTER_TEST`)は自動では送らない(タイマーを残さない)。
class StorePreviewSlider extends StatefulWidget {
  const StorePreviewSlider({super.key, required this.images, required this.placeholderColor, this.interval = const Duration(seconds: 4)});
  final List<Uri> images;
  final Color placeholderColor;
  final Duration interval;

  static bool get autoplay => kIsWeb || !Platform.environment.containsKey('FLUTTER_TEST');

  @override
  State<StorePreviewSlider> createState() => _StorePreviewSliderState();
}

class _StorePreviewSliderState extends State<StorePreviewSlider> {
  final _page = PageController();
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    if (widget.images.length > 1 && StorePreviewSlider.autoplay) {
      _timer = Timer.periodic(widget.interval, (_) {
        if (!mounted || !_page.hasClients) return;
        final next = (_index + 1) % widget.images.length;
        _page.animateToPage(next, duration: const Duration(milliseconds: 450), curve: Curves.easeInOut);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    final surface = HSLColor.fromColor(widget.placeholderColor).withLightness(0.93).toColor();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ColoredBox(
        color: surface,
        child: images.isEmpty
            ? Center(child: Icon(Icons.image_outlined, size: 36, color: HSLColor.fromColor(widget.placeholderColor).withLightness(0.6).toColor()))
            : Stack(children: [
                PageView.builder(
                  controller: _page,
                  itemCount: images.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) => Image.network(
                    webHtmlElementStrategy: rasqWebImageStrategy,
                    '${images[i]}',
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Center(child: Icon(Icons.broken_image_outlined)),
                  ),
                ),
                if (images.length > 1)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 6,
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      for (var i = 0; i < images.length; i++)
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: i == _index ? 0.95 : 0.5)),
                        ),
                    ]),
                  ),
              ]),
      ),
    );
  }
}
