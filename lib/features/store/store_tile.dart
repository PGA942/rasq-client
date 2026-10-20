import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../app/router.dart';
import '../../backend/payments_api.dart' show paidFeaturesProvider;
import '../../l10n/l10n.dart';
import 'store_install.dart';
import 'store_models.dart';
import 'store_providers.dart';

/// ストアのプラグインタイル (D-353 → D-354)。**種別ごとの薄い色の角丸四角**(色は [StorePluginType] の色相、テーマの背景に 1/3 の濃さで重ねる)。
/// - 上の見出し行(全幅): アイコン + 名前 + 開発者 / 種別 → ★ と DL 数 → **入手 / 更新 / 金額 / 開く のボタン**。
/// - その下: 左 = プレビュー画像の自動スライド、右 = **説明の半透明(テーマの背景色)の角丸タイル**(説明 + 状態の印 + サイズ / 版 / 広告)。
/// ボタン: 入っていない = 無料なら「入手」/ 有料なら金額、入っていてストアに新しい版 = 「更新」(どれも確認シート → 検証 → 登録、
/// プラグインページと同じ [confirmAndInstallPlugin])、入っていて最新 = 「開く」(インストール済みのページ)。停止中などは押せない。
/// ストアホームの横の列、検索画面のグリッド、プラグインを管理のブックマークで使う。
class StorePluginTile extends ConsumerStatefulWidget {
  const StorePluginTile({super.key, required this.card, this.installedVersion, this.onTap, this.width = storeTileWidth, this.height = storeTileHeight});
  final StorePluginCard card;

  /// 入っている版(null = 入っていない)。
  final String? installedVersion;
  final VoidCallback? onTap;
  final double width;
  final double height;

  @override
  ConsumerState<StorePluginTile> createState() => _StorePluginTileState();
}

/// ボタンの種類。
enum StoreTileAction { get, buy, update, open, unavailable }

/// 入っている版 / 掲載から、ボタンの種類を決める。
StoreTileAction storeTileActionOf(StorePluginCard card, String? installedVersion) {
  if (installedVersion != null) {
    return isNewerVersion(card.version, installedVersion) ? StoreTileAction.update : StoreTileAction.open;
  }
  if (card.status.isCaution && card.status != PluginStatus.warning) return StoreTileAction.unavailable;
  return card.price == 0 ? StoreTileAction.get : StoreTileAction.buy;
}

class _StorePluginTileState extends ConsumerState<StorePluginTile> {
  bool _busy = false;

  Future<void> _act(StoreTileAction action) async {
    final card = widget.card;
    if (action == StoreTileAction.open) {
      context.push(Routes.storeInstalledPlugin(card.id));
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _busy = true);
    String? message;
    try {
      final detail = await ref.read(storeClientProvider).plugin(card.id);
      if (!mounted) return;
      // 確認シートを出している間は回さない(回すのは掲載を引く間と、検証 / 登録の間だけ)。
      setState(() => _busy = false);
      if (detail == null) {
        message = appL10n.storePluginNotFound;
      } else {
        message = await confirmAndInstallPlugin(ref, detail, onBusy: (b) {
          if (mounted) setState(() => _busy = b);
        });
      }
    } catch (e) {
      message = appL10n.storeInstallFailed('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (message != null) messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final scheme = Theme.of(context).colorScheme;
    final bg = storeTileColor(card.pluginType, scheme);
    final ink = scheme.onSurface;
    final muted = scheme.onSurfaceVariant;
    final statusNote = card.status == PluginStatus.published ? null : card.status.label;
    final action = storeTileActionOf(card, widget.installedVersion);
    // 公開テストでは有料の機能が止まっている (D-401): 金額は出すが押せない。
    final buyBlocked = action == StoreTileAction.buy && !ref.watch(paidFeaturesProvider);
    final meta = [
      if (card.sizeMb > 0) '${card.sizeMb.toStringAsFixed(card.sizeMb < 1 ? 2 : 1)}MB',
      if (card.version.isNotEmpty) 'v${card.version}',
      if (card.hasAds) context.l10n.storeHasAds,
    ];
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Material(
        key: ValueKey('store.tile.${card.id}'),
        color: bg,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // 見出し行(全幅): アイコン / 名前 + 開発者・種別 / ★・DL / ボタン。
              Row(children: [
                _Icon(url: card.iconUrl, type: card.pluginType),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(card.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: RasqTypography.body.copyWith(color: ink, fontWeight: FontWeight.w700)),
                    Text(
                      [if (card.developerName.isNotEmpty) card.developerName, card.pluginType.label].join(context.l10n.storeDotSeparator),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RasqTypography.caption.copyWith(color: muted),
                    ),
                  ]),
                ),
                const SizedBox(width: 6),
                Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                  Text(card.rating > 0 ? '★${card.rating.toStringAsFixed(1)}' : '★ -', style: RasqTypography.caption.copyWith(color: ink, fontWeight: FontWeight.w700)),
                  Text('${formatStoreDownloads(card.downloads)} DL', style: RasqTypography.caption.copyWith(color: muted)),
                ]),
                const SizedBox(width: 8),
                _ActionButton(
                    key: ValueKey('store.tile.action.${card.id}'),
                    action: action,
                    price: card.price,
                    busy: _busy,
                    tooltip: buyBlocked ? context.l10n.storeBuyDisabled : null,
                    onPressed: action == StoreTileAction.unavailable || buyBlocked ? null : () => _act(action)),
              ]),
              const SizedBox(height: 10),
              Expanded(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(flex: 11, child: StorePreviewSlider(key: ValueKey('store.tile.preview.${card.id}'), images: card.tilePreviews, placeholderColor: bg)),
                  const SizedBox(width: 10),
                  // 説明: 半透明(テーマの背景色)の角丸タイル。
                  Expanded(
                    flex: 9,
                    child: Container(
                      key: ValueKey('store.tile.about.${card.id}'),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: scheme.surface.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(12)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(child: Text(card.summary, overflow: TextOverflow.fade, style: RasqTypography.bodySmall.copyWith(color: ink, height: 1.35))),
                        if (statusNote != null) ...[
                          const SizedBox(height: 4),
                          _Badge(statusNote, color: card.status.isCaution ? RasqColors.danger : RasqColors.accent),
                        ],
                        if (meta.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(meta.join(context.l10n.storeDotSeparator), maxLines: 1, overflow: TextOverflow.ellipsis, style: RasqTypography.caption.copyWith(color: muted)),
                        ],
                      ]),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({super.key, required this.action, required this.price, required this.busy, required this.onPressed, this.tooltip});
  final StoreTileAction action;
  final String? tooltip;
  final double price;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final label = switch (action) {
      StoreTileAction.get => context.l10n.storeTileGet,
      StoreTileAction.buy => '¥${price.toStringAsFixed(0)}',
      StoreTileAction.update => context.l10n.storeTileUpdate,
      StoreTileAction.open => context.l10n.storeOpen,
      StoreTileAction.unavailable => context.l10n.storeTileUnavailable,
    };
    final child = busy ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : Text(label);
    const style = ButtonStyle(
      visualDensity: VisualDensity.compact,
      padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14)),
      minimumSize: WidgetStatePropertyAll(Size(56, 32)),
      shape: WidgetStatePropertyAll(StadiumBorder()),
    );
    // 入っていて最新(開く)は控えめに、それ以外は塗りつぶし。
    final button = action == StoreTileAction.open
        ? OutlinedButton(style: style, onPressed: busy ? null : onPressed, child: child)
        : FilledButton(style: style, onPressed: busy ? null : onPressed, child: child);
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}

/// タイルの大きさ(ユーザー指定 ≈ 400 × 300)。
const storeTileWidth = 400.0;
const storeTileHeight = 300.0;

/// 種別の色 (D-354): 種別の色相のパステルを、テーマの背景に **1/3 の濃さ**で重ねる(D-353 の 3 倍くらい薄い)。暗いテーマでは濃い色を薄く重ねる。
Color storeTileColor(StorePluginType type, ColorScheme scheme) {
  final dark = scheme.brightness == Brightness.dark;
  final base = type.hue < 0
      ? HSLColor.fromAHSL(1, 0, 0, dark ? 0.5 : 0.8).toColor()
      : HSLColor.fromAHSL(1, type.hue, 0.72, dark ? 0.5 : 0.86).toColor();
  return Color.alphaBlend(base.withValues(alpha: dark ? 0.22 : 0.33), scheme.surface);
}

String formatStoreDownloads(int n) => n >= 10000 ? compactCountOrNull(n) ?? appL10n.storeDownloadsTenThousands((n / 10000).toStringAsFixed(1)) : '$n';

class _Icon extends StatelessWidget {
  const _Icon({required this.url, required this.type});
  final Uri? url;
  final StorePluginType type;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = type.hue < 0 ? scheme.surfaceContainerHighest : HSLColor.fromAHSL(1, type.hue, 0.6, scheme.brightness == Brightness.dark ? 0.35 : 0.78).toColor();
    final fallback = ColoredBox(color: tint, child: Icon(Icons.extension_outlined, size: 22, color: scheme.onSurface));
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
    final scheme = Theme.of(context).colorScheme;
    final surface = Color.alphaBlend(scheme.surface.withValues(alpha: 0.5), widget.placeholderColor);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ColoredBox(
        color: surface,
        child: images.isEmpty
            ? Center(child: Icon(Icons.image_outlined, size: 36, color: scheme.onSurfaceVariant.withValues(alpha: 0.5)))
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
