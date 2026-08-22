import 'package:flutter/material.dart';

import '../tokens/colors.dart';

/// Semantic colours that are not part of Material's ColorScheme.
/// Accessed via `RasqTokens.of(context)`.
@immutable
class RasqTokens extends ThemeExtension<RasqTokens> {
  const RasqTokens({
    required this.live,
    required this.inVc,
    required this.warning,
    required this.danger,
    required this.link,
    required this.muted,
    required this.divider,
    required this.surfaceAlt,
    required this.sensitiveOverlay,
    required this.ctaGradient,
  });

  final Color live;
  final Color inVc;
  final Color warning;
  final Color danger;
  final Color link;
  final Color muted;
  final Color divider;
  final Color surfaceAlt;
  final Color sensitiveOverlay;
  final Gradient ctaGradient;

  static const light = RasqTokens(
    live: RasqColors.live,
    inVc: RasqColors.inVc,
    warning: RasqColors.warning,
    danger: RasqColors.danger,
    link: RasqColors.link,
    muted: RasqColors.muted,
    divider: Color(0xFFE0E0E0),
    surfaceAlt: Color(0xFFF4F5F7),
    sensitiveOverlay: Color(0xCC9E9E9E),
    ctaGradient: RasqColors.ctaGradient,
  );

  static const dark = RasqTokens(
    live: RasqColors.live,
    inVc: RasqColors.inVc,
    warning: RasqColors.warning,
    danger: Color(0xFFFF6B6B),
    link: Color(0xFF64B5F6),
    muted: Color(0xFF9AA0A6),
    divider: Color(0xFF2C2C2E),
    surfaceAlt: Color(0xFF1C1C1E),
    sensitiveOverlay: Color(0xCC424242),
    ctaGradient: RasqColors.ctaGradient,
  );

  static RasqTokens of(BuildContext context) => Theme.of(context).extension<RasqTokens>() ?? light;

  @override
  RasqTokens copyWith({
    Color? live,
    Color? inVc,
    Color? warning,
    Color? danger,
    Color? link,
    Color? muted,
    Color? divider,
    Color? surfaceAlt,
    Color? sensitiveOverlay,
    Gradient? ctaGradient,
  }) =>
      RasqTokens(
        live: live ?? this.live,
        inVc: inVc ?? this.inVc,
        warning: warning ?? this.warning,
        danger: danger ?? this.danger,
        link: link ?? this.link,
        muted: muted ?? this.muted,
        divider: divider ?? this.divider,
        surfaceAlt: surfaceAlt ?? this.surfaceAlt,
        sensitiveOverlay: sensitiveOverlay ?? this.sensitiveOverlay,
        ctaGradient: ctaGradient ?? this.ctaGradient,
      );

  @override
  RasqTokens lerp(ThemeExtension<RasqTokens>? other, double t) {
    if (other is! RasqTokens) return this;
    return RasqTokens(
      live: Color.lerp(live, other.live, t)!,
      inVc: Color.lerp(inVc, other.inVc, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      link: Color.lerp(link, other.link, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      sensitiveOverlay: Color.lerp(sensitiveOverlay, other.sensitiveOverlay, t)!,
      ctaGradient: Gradient.lerp(ctaGradient, other.ctaGradient, t)!,
    );
  }
}
