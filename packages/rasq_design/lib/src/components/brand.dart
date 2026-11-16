import 'package:flutter/foundation.dart' show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/material.dart';
import 'package:rasq_models/rasq_models.dart';

import '../tokens/sizes.dart';
import '../l10n/design_l10n.dart';
import 'sns_pill.dart' show RasqSnsPill;

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

  /// SNS のロゴ (D-555)。形のまわりで切り出して 192px の正方形にしたもの。出典と使用の条件は [rasqSnsLogoNotices]。
  static const snsBluesky = 'assets/brand/sns_bluesky.png';
  static const snsMisskey = 'assets/brand/sns_misskey.png';
  static const snsMastodon = 'assets/brand/sns_mastodon.png';

  /// その SNS のロゴ。持っていない SNS(mixi2 など)は null。
  static String? snsLogo(SnsKind kind) => switch (kind) {
        SnsKind.bluesky => snsBluesky,
        SnsKind.misskey => snsMisskey,
        SnsKind.mastodon => snsMastodon,
        _ => null,
      };
}

/// SNS のロゴの出典と使用の条件 (D-555)。アプリの「ライセンス」(設定 → 法務)に [registerRasqBrandLicenses] で載せる。
/// 原文はユーザー指定 2026-11-11(綴りだけ直した)。Misskey のロゴは切り出し・縮小して使うので、その旨と、同じ条件で配ることを添える。
const rasqSnsLogoNotices = <({String name, String text})>[
  (
    name: 'Misskey logo',
    text: '"Misskey" logo by Misskey Project is licensed under CC BY-SA.\n'
        'Source: https://assets.misskey-hub.net/public/icon.png\n'
        'Modified by RASQ (cropped and resized). The modified image is distributed under the same license.',
  ),
  (
    name: 'Bluesky logo',
    text: '"Bluesky" logo by Bluesky Social, PBC is used under the Bluesky Trademark and Brand Guidelines.',
  ),
  (
    name: 'Mastodon logo',
    text: '"Mastodon" logo by Mastodon Project is used under the Mastodon Trademark Policy.\n'
        'Source: https://joinmastodon.org/ja/branding',
  ),
];

bool _brandLicensesRegistered = false;

/// [rasqSnsLogoNotices] を Flutter のライセンスの一覧([LicenseRegistry])に載せる。起動のときに 1 度呼ぶ(2 度目からは何もしない)。
void registerRasqBrandLicenses() {
  if (_brandLicensesRegistered) return;
  _brandLicensesRegistered = true;
  LicenseRegistry.addLicense(() => Stream.fromIterable([
        for (final n in rasqSnsLogoNotices) LicenseEntryWithLineBreaks([n.name], n.text),
      ]));
}

/// SNS の丸い印 (D-555)。ロゴのある SNS(Bluesky / Misskey / Mastodon)は**白い丸の中にロゴ**(細い枠つき。ロゴの色を変えずに、
/// 明るい面でも暗い面でも同じに見えるように)、ロゴの無い SNS は従来どおり **SNS の色の丸に頭文字**。
/// ログインのボタン・ログインの画面の見出し・機能の紹介で同じものを使う。
class RasqSnsMark extends StatelessWidget {
  const RasqSnsMark({super.key, required this.kind, this.size = 32});
  final SnsKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final logo = RasqBrandAssets.snsLogo(kind);
    if (logo == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: RasqSnsPill.colorOf(kind), shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(kind.label.characters.first, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.45)),
      );
    }
    return Container(
      key: ValueKey('sns.mark.${kind.name}'),
      width: size,
      height: size,
      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
      padding: EdgeInsets.all(size * 0.16),
      child: Image.asset(logo, package: RasqBrandAssets.package, fit: BoxFit.contain, semanticLabel: kind.label, filterQuality: FilterQuality.medium),
    );
  }
}

/// RAi ボタン (D-093): TL 選択行・トレンド・ノードパレット等に置く共通の
/// 入口。RAi 実装までは [onPressed] なし(表示のみ)でも同じ見た目。
class RasqRaiButton extends StatelessWidget {
  const RasqRaiButton({super.key, this.onPressed, this.size = 26, this.tooltip});

  final VoidCallback? onPressed;
  final double size;
  /// 省略すると「RAi(準備中)」(表示の言語で、D-484)。
  final String? tooltip;

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onPressed ?? () {},
        tooltip: tooltip ?? context.designL10n.designRaiComingSoon,
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
        UserVerification.person => rasqDesignL10n.designVerifiedPerson,
        UserVerification.company => rasqDesignL10n.designVerifiedCompany,
        UserVerification.government => rasqDesignL10n.designVerifiedGovernment,
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
  const RasqAsTellIcon({super.key, this.size = 24, this.selected = true, this.semanticsLabel = 'ASTell'});
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
