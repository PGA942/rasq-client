import 'package:flutter/material.dart';
import 'package:rasq_models/rasq_models.dart';

import '../tokens/colors.dart';
import '../platform/media_policy.dart';
import '../platform/media_image.dart';

/// Server icon + label shown after `@username` in every user row
/// (ワイヤーフレーム: `@username ● BlueSky`)。
///
/// D-179: 色の ● の代わりに**サーバー(インスタンス)のアイコン**(favicon)を出す。読めない /
/// 読み込み中は従来の SNS 色の ● にフォールバックする。URL は [iconUrlOf](差し替え可)。
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

  /// サーバーアイコンの URL。Bluesky は PDS ではなくアプリ(bsky.app)のもの。
  /// アプリ側で差し替えられる(例: プラグインが返すインスタンス情報のアイコン)。
  static Uri? Function(AccountId account) iconUrlOf = (account) => switch (account.kind) {
        SnsKind.bluesky => Uri.https('bsky.app', '/static/favicon-32x32.png'),
        SnsKind.mixi2 => null,
        _ => account.instance.isEmpty ? null : Uri.https(account.instance, '/favicon.ico'),
      };

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    final dot = Container(width: dotSize, height: dotSize, decoration: BoxDecoration(color: colorOf(account.kind), shape: BoxShape.circle));
    final url = iconUrlOf(account);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: '${account.kind.name} ${account.instance}',
          child: SizedBox(
            width: dotSize,
            height: dotSize,
            child: url == null || !rasqMediaAllowed(context, url)
                ? dot
                : ClipRRect(
                    borderRadius: BorderRadius.circular(dotSize * 0.25),
                    child: Image(
                      image: rasqMediaImage(context, url),
                      width: dotSize,
                      height: dotSize,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (_, _, _) => dot,
                      // 読み込み中は ● を出し、来たらそのまま差し替える。
                      loadingBuilder: (_, child, progress) => progress == null ? child : dot,
                    ),
                  ),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(width: 3),
          Flexible(child: Text(account.instance, style: style, overflow: TextOverflow.ellipsis)),
        ],
      ],
    );
  }
}
