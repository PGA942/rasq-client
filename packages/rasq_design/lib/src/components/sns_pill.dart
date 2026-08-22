import 'package:flutter/material.dart';
import 'package:rasq_models/rasq_models.dart';

import '../tokens/colors.dart';

/// Colour dot + label shown after `@username` in every user row
/// (ワイヤーフレーム: `@username ● BlueSky`).
class RasqSnsPill extends StatelessWidget {
  const RasqSnsPill({super.key, required this.account, this.showLabel = true, this.dotSize = 10});

  final AccountId account;
  final bool showLabel;
  final double dotSize;

  static Color colorOf(SnsKind kind) => switch (kind) {
        SnsKind.bluesky => const Color(0xFF1185FE),
        SnsKind.misskey => const Color(0xFF86B300),
        SnsKind.mastodon => const Color(0xFF6364FF),
        SnsKind.mixi2 => RasqColors.accent,
        SnsKind.other => RasqColors.muted,
      };

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: dotSize, height: dotSize, decoration: BoxDecoration(color: colorOf(account.kind), shape: BoxShape.circle)),
        if (showLabel) ...[
          const SizedBox(width: 3),
          Flexible(child: Text(account.instance, style: style, overflow: TextOverflow.ellipsis)),
        ],
      ],
    );
  }
}
