import 'package:flutter/material.dart';
import 'package:rasq_models/rasq_models.dart';

import '../tokens/sizes.dart';

/// Brand assets shipped with the design system (原典: 特殊なコンポーネント置き場).
///
/// All images live in `assets/brand/` of this package and are referenced with
/// `package: 'rasq_design'`, so app screens and the RRL renderer get the same
/// artwork. Backgrounds were keyed out so the marks sit on any surface.
abstract final class RasqBrandAssets {
  static const package = 'rasq_design';
  static const icon = 'assets/brand/rasq_icon.png';
  static const fullLogo = 'assets/brand/rasq_full_logo.png';
  static const verifiedPerson = 'assets/brand/verified_person.png';
  static const verifiedCompany = 'assets/brand/verified_company.png';
  static const verifiedGovernment = 'assets/brand/verified_government.png';

  /// Deep-colour AsTell mark — for light surfaces.
  static const asTellDark = 'assets/brand/astell_dark.png';

  /// Pastel AsTell mark — for dark surfaces.
  static const asTellLight = 'assets/brand/astell_light.png';

  /// RAi ボタン(Assets2/rai_button — コマ型ロボットの丸バッジ)。
  static const raiButton = 'assets/brand/rai_button.png';
}

/// RAi ボタン (D-093): TL 選択行・トレンド・ノードパレット等に置く共通の
/// 入口。RAi 実装までは [onPressed] なし(表示のみ)でも同じ見た目。
class RasqRaiButton extends StatelessWidget {
  const RasqRaiButton({super.key, this.onPressed, this.size = 26, this.tooltip = 'RAi(準備中)'});

  final VoidCallback? onPressed;
  final double size;
  final String tooltip;

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onPressed ?? () {},
        tooltip: tooltip,
        icon: Image.asset(
          RasqBrandAssets.raiButton,
          package: RasqBrandAssets.package,
          width: size,
          height: size,
          fit: BoxFit.contain,
          semanticLabel: 'RAi',
          filterQuality: FilterQuality.medium,
        ),
        constraints: const BoxConstraints(minWidth: RasqSizes.minTap, minHeight: RasqSizes.minTap),
      );
}

/// The RASQ app mark (swoosh + orange dot), e.g. next to official plugins or
/// as the sidebar brand.
class RasqBrandIcon extends StatelessWidget {
  const RasqBrandIcon({super.key, this.size = 24, this.semanticsLabel = 'RASQ'});
  final double size;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) => Image.asset(
        RasqBrandAssets.icon,
        package: RasqBrandAssets.package,
        width: size,
        height: size,
        fit: BoxFit.contain,
        semanticLabel: semanticsLabel,
        filterQuality: FilterQuality.medium,
      );
}

/// Full RASQ word-mark. Black glyphs on a transparent background; in dark
/// themes the whole mark is tinted with `onSurface` so it stays legible
/// ([monochrome] forces that tint regardless of theme).
class RasqLogo extends StatelessWidget {
  const RasqLogo({super.key, this.height = 32, this.monochrome, this.semanticsLabel = 'RASQ'});
  final double height;
  final bool? monochrome;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final mono = monochrome ?? dark;
    final image = Image.asset(
      RasqBrandAssets.fullLogo,
      package: RasqBrandAssets.package,
      height: height,
      fit: BoxFit.contain,
      semanticLabel: semanticsLabel,
      filterQuality: FilterQuality.medium,
    );
    if (!mono) return image;
    return ColorFiltered(colorFilter: ColorFilter.mode(Theme.of(context).colorScheme.onSurface, BlendMode.srcIn), child: image);
  }
}

/// RASQ account verification badge (個人 / 法人 / 公的機関), rendered next to a
/// display name. Returns nothing for [UserVerification.none] so it can be
/// dropped into a row unconditionally.
class RasqVerifiedBadge extends StatelessWidget {
  const RasqVerifiedBadge({super.key, required this.kind, this.size = 16});
  final UserVerification kind;
  final double size;

  static String labelOf(UserVerification kind) => switch (kind) {
        UserVerification.none => '',
        UserVerification.person => '認証済み(個人)',
        UserVerification.company => '認証済み(法人)',
        UserVerification.government => '認証済み(公的機関)',
      };

  static String? assetOf(UserVerification kind) => switch (kind) {
        UserVerification.none => null,
        UserVerification.person => RasqBrandAssets.verifiedPerson,
        UserVerification.company => RasqBrandAssets.verifiedCompany,
        UserVerification.government => RasqBrandAssets.verifiedGovernment,
      };

  @override
  Widget build(BuildContext context) {
    final asset = assetOf(kind);
    if (asset == null) return const SizedBox.shrink();
    final label = labelOf(kind);
    return Tooltip(
      message: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Image.asset(asset, package: RasqBrandAssets.package, width: size, height: size, fit: BoxFit.contain, semanticLabel: label, filterQuality: FilterQuality.medium),
      ),
    );
  }
}

/// AsTell (VC) mark used for the global-nav tab and VC surfaces. Picks the
/// deep-colour variant on light surfaces and the pastel one on dark surfaces;
/// an unselected tab is shown slightly faded like the Material nav icons.
class RasqAsTellIcon extends StatelessWidget {
  const RasqAsTellIcon({super.key, this.size = 24, this.selected = true, this.semanticsLabel = 'AsTell'});
  final double size;
  final bool selected;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Opacity(
      opacity: selected ? 1 : 0.6,
      child: Image.asset(
        dark ? RasqBrandAssets.asTellLight : RasqBrandAssets.asTellDark,
        package: RasqBrandAssets.package,
        width: size,
        height: size,
        fit: BoxFit.contain,
        semanticLabel: semanticsLabel,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}
