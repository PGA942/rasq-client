import 'package:flutter/material.dart';
import 'package:rasq_models/rasq_models.dart';

import '../theme/rasq_tokens_extension.dart';
import '../tokens/colors.dart';
import '../tokens/sizes.dart';

/// Single avatar with optional presence ring/badge (LIVE / VC中).
///
/// L2 atomic. Geometry (size/position) is owned by the host: plugins may only
/// supply image source + decoration (スロットポリシー avatar slot).
class RasqAvatar extends StatelessWidget {
  const RasqAvatar({
    super.key,
    this.imageUrl,
    this.size = RasqSizes.avatarMd,
    this.presence = UserPresence.none,
    this.fallbackLabel,
    this.onTap,
    this.badge,
    this.badgeAlignment = Alignment.bottomRight,
    this.semanticsLabel,
  });

  final Uri? imageUrl;
  final double size;
  final UserPresence presence;

  /// Shown when no image is available (first character is used).
  final String? fallbackLabel;
  final VoidCallback? onTap;

  /// Arbitrary overlay widget (e.g. SNS pill, count) placed at [badgeAlignment].
  final Widget? badge;
  final Alignment badgeAlignment;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = RasqTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final ringColor = switch (presence) {
      UserPresence.live => tokens.live,
      UserPresence.inVc => tokens.inVc,
      UserPresence.none => null,
    };

    Widget circle = ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: imageUrl == null
            ? ColoredBox(
                color: RasqColors.accent,
                child: Center(
                  child: Text(
                    (fallbackLabel ?? '?').characters.first,
                    style: TextStyle(color: RasqColors.white, fontSize: size * 0.42, fontWeight: FontWeight.w700),
                  ),
                ),
              )
            : Image.network(
                imageUrl.toString(),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => ColoredBox(color: scheme.surfaceContainerHighest),
              ),
      ),
    );

    if (ringColor != null) {
      circle = Container(
        padding: EdgeInsets.all(size * 0.06),
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ringColor, width: size * 0.06)),
        child: circle,
      );
    }

    final children = <Widget>[circle];
    if (presence == UserPresence.live) {
      children.add(Positioned(
        left: 0,
        right: 0,
        bottom: -size * 0.08,
        child: Center(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: size * 0.12, vertical: size * 0.02),
            decoration: BoxDecoration(color: tokens.live, borderRadius: BorderRadius.circular(4)),
            child: Text('LIVE', style: TextStyle(color: RasqColors.white, fontSize: size * 0.2, fontWeight: FontWeight.w800)),
          ),
        ),
      ));
    }
    if (badge != null) {
      children.add(Positioned.fill(child: Align(alignment: badgeAlignment, child: badge)));
    }

    Widget result = SizedBox(
      width: size,
      height: size,
      child: Stack(clipBehavior: Clip.none, children: children),
    );
    if (semanticsLabel != null) {
      result = Semantics(label: semanticsLabel, image: true, child: result);
    }
    if (onTap != null) {
      result = GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: result);
    }
    return result;
  }
}

/// Stacked group avatar used by VC participants / grouped notifications /
/// DM rooms ("アイコン（シングル・グループ・VC中・LIVE表示）").
class RasqGroupAvatar extends StatelessWidget {
  const RasqGroupAvatar({
    super.key,
    required this.users,
    this.size = RasqSizes.avatarMd,
    this.maxVisible = 3,
    this.overflowCount,
  });

  final List<UserSummary> users;
  final double size;
  final int maxVisible;

  /// Explicit "+N" override; defaults to `users.length - maxVisible`.
  final int? overflowCount;

  @override
  Widget build(BuildContext context) {
    final visible = users.take(maxVisible).toList();
    final extra = overflowCount ?? (users.length - visible.length);
    final step = size * 0.55;
    final width = size + step * (visible.length - 1).clamp(0, maxVisible) + (extra > 0 ? step : 0);
    return SizedBox(
      width: width,
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < visible.length; i++)
            Positioned(
              left: step * i,
              child: RasqAvatar(
                imageUrl: visible[i].avatarUrl,
                size: size,
                presence: visible[i].presence,
                fallbackLabel: visible[i].displayName,
              ),
            ),
          if (extra > 0)
            Positioned(
              left: step * visible.length,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(shape: BoxShape.circle, color: RasqColors.accent),
                alignment: Alignment.center,
                child: Text('+$extra', style: TextStyle(color: RasqColors.white, fontSize: size * 0.34, fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
  }
}
