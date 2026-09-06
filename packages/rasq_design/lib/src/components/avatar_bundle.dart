import 'package:flutter/material.dart';
import 'package:rasq_models/rasq_models.dart';

import '../theme/rasq_tokens_extension.dart';
import '../tokens/colors.dart';
import '../tokens/sizes.dart';
import 'avatar.dart';

/// アイコン&追加情報バンドル (D-140、ワイヤーフレーム p.3 の VC タイル左上)。
///
/// 3 層:
/// 1. **背面**: 角丸四角形の**ワイヤー**(縁取り + 薄い塗り)。アイコンの右半分から
///    右へ伸び、人数を収める。
/// 2. **アイコン**: 円形、円形の縁取りつき。背面より 1 レイヤー上で左端に重なる。
/// 3. **LIVE**: 角丸ワイヤーの**下辺中央**に重ねる(赤地・白文字)。
///
/// **人数**は角丸ワイヤーの右端、上下中央。縁取りなし。1000 以上は `k` 表記で
/// **小数第 1 位で切り捨て**(`2560 → +2.5k`、`1000 → +1k`)。
class RasqAvatarBundle extends StatelessWidget {
  const RasqAvatarBundle({
    super.key,
    required this.user,
    this.count,
    this.live = false,
    this.size = RasqSizes.avatarMd,
    this.color,
    this.ringColor,
    this.onTap,
  });

  final UserSummary user;

  /// 追加情報 = 参加人数(ホスト以外)。null / 0 なら出さない。
  final int? count;

  /// LIVE 表記(下辺中央)。
  final bool live;

  /// アイコンの直径。角丸ワイヤーの高さはこの 0.8 倍。
  final double size;

  /// ワイヤーの色(既定: ブランドのアクセント)。
  final Color? color;

  /// アイコンの円形縁取り(既定: 面色 = 背面から浮いて見える)。
  final Color? ringColor;
  final VoidCallback? onTap;

  /// `+N`。1000 以上は `k`、小数第 1 位で**切り捨て**。
  static String formatCount(int n) {
    if (n < 1000) return '+$n';
    final tenths = n ~/ 100; // 2560 → 25
    final whole = tenths ~/ 10;
    final frac = tenths % 10;
    return frac == 0 ? '+${whole}k' : '+$whole.${frac}k';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = RasqTokens.of(context);
    final wire = color ?? RasqColors.accent;
    final ring = ringColor ?? scheme.surface;
    final label = (count ?? 0) > 0 ? formatCount(count!) : null;
    final wireHeight = size * 0.8;
    final wireTop = (size - wireHeight) / 2;
    final countStyle = TextStyle(fontSize: size * 0.3, fontWeight: FontWeight.w700, color: scheme.onSurface, height: 1.0);
    final liveHeight = size * 0.28;

    // 角丸ワイヤーの幅: アイコンの中心から右へ、人数の文字幅 + 余白。
    final countWidth = label == null ? 0.0 : _textWidth(label, countStyle) + size * 0.3;
    final wireLeft = size / 2;
    final wireWidth = size / 2 + size * 0.15 + countWidth;
    final totalWidth = wireLeft + wireWidth;

    // 縁取りは [size] の内側に収める(外にはみ出すと行の高さと中心がずれる)。
    final ringWidth = size * 0.06;
    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ring, width: ringWidth)),
      child: RasqAvatar(imageUrl: user.avatarUrl, size: size - ringWidth * 2, fallbackLabel: user.displayName),
    );

    Widget bundle = SizedBox(
      width: totalWidth,
      height: size + (live ? liveHeight / 2 : 0),
      child: Stack(clipBehavior: Clip.none, children: [
        // 1. 背面: 角丸四角のワイヤー。
        Positioned(
          left: wireLeft,
          top: wireTop,
          width: wireWidth,
          height: wireHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: wire.withValues(alpha: 0.18),
              border: Border.all(color: wire, width: 1.5),
              borderRadius: BorderRadius.circular(wireHeight / 2),
            ),
          ),
        ),
        // 人数: 右端、上下中央、縁取りなし。
        if (label != null)
          Positioned(
            left: wireLeft,
            top: wireTop,
            width: wireWidth - size * 0.15,
            height: wireHeight,
            child: Align(alignment: Alignment.centerRight, child: Text(label, style: countStyle, maxLines: 1, softWrap: false)),
          ),
        // 2. アイコン: 円形 + 円形縁取り、背面より上。
        Positioned(left: 0, top: 0, child: avatar),
        // 3. LIVE: 角丸ワイヤーの下辺中央。
        if (live)
          Positioned(
            left: wireLeft,
            width: wireWidth,
            top: wireTop + wireHeight - liveHeight / 2,
            height: liveHeight,
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: size * 0.12),
                height: liveHeight,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: tokens.live, borderRadius: BorderRadius.circular(3)),
                child: Text('LIVE', style: TextStyle(color: RasqColors.white, fontSize: size * 0.2, fontWeight: FontWeight.w800, height: 1.0)),
              ),
            ),
          ),
      ]),
    );
    if (onTap != null) bundle = GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: bundle);
    return Semantics(label: label == null ? user.displayName : '${user.displayName} $label', child: bundle);
  }

  static double _textWidth(String text, TextStyle style) {
    final painter = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr, maxLines: 1)..layout();
    return painter.width;
  }
}
