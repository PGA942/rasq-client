import 'package:flutter/material.dart';
import 'package:rasq_models/rasq_models.dart';

import '../theme/rasq_tokens_extension.dart';
import '../tokens/colors.dart';
import '../tokens/sizes.dart';
import 'avatar.dart';

/// アイコン&追加情報バンドル (D-140 / D-141、ワイヤーフレーム p.3 の VC タイル左上)。
///
/// 3 層:
/// 1. **背面**: 角丸四角形の**ワイヤー**(黄色の塗り、枠線も同色)。アイコンの縁取りが
///    収まる高さ(= [size])で、**左端からアイコンの下を通って**右へ伸び人数を収める。
/// 2. **アイコン**: 円形、円形の縁取りつき(縁取りは [size] の内側)。背面より
///    1 レイヤー上で左端に重なる。
/// 3. **LIVE**: 角丸ワイヤーの**下辺中央**に重ねる(赤地・白文字)。
///
/// D-336: アイコンの縁取りは**黄色**(ワイヤーと同じ色。以前は白)、角丸ワイヤーは [grow](3px)だけ大きく、アイコンはその内側。
/// **1 人 / 2 人**(人数 2 以下)のときは、アイコンをワイヤーの太さいっぱいに広げる([fillBelow])。
///
/// **人数**は角丸ワイヤーの右端、上下中央、縁取りなし。
/// - 1000 未満: `+4`
/// - 1000 以上: `k` 表記で**小数点以下切り捨て**(`2560 → +2k`)
/// - 100k 以上: `+` を消し、整数 + 単位を **1 行 3 文字・最大 2 行** に折る
///   (`123456 → "123" / "k"`、`2_500_000 → "2M"`、`123_000_000 → "123" / "M"`)。
class RasqAvatarBundle extends StatelessWidget {
  const RasqAvatarBundle({
    super.key,
    required this.user,
    this.count,
    this.live = false,
    this.size = RasqSizes.avatarMd,
    this.color,
    this.fillColor,
    this.ringColor,
    this.onTap,
  });

  final UserSummary user;

  /// 追加情報 = 参加人数(ホスト以外)。null / 0 なら出さない。
  final int? count;

  /// LIVE 表記(下辺中央)。
  final bool live;

  /// アイコンの直径 = 角丸ワイヤーの高さ。
  final double size;

  /// ワイヤーの色(塗りと枠線。既定: ブランドの黄色)。
  final Color? color;

  /// 塗りだけ変えたいとき(既定: [color] を薄く)。
  final Color? fillColor;

  /// アイコンの円形縁取り(既定: 面色 = 背面から浮いて見える)。
  final Color? ringColor;
  final VoidCallback? onTap;

  /// 折り返し 1 行の文字数(100k 以上)。
  static const charsPerLine = 3;

  /// 角丸ワイヤーをアイコンより大きくする量 (D-336)。
  static const grow = 3.0;

  /// この人数以下なら、アイコンをワイヤーの太さいっぱいに (D-336)。
  static const fillBelow = 2;

  /// 表示文字列(改行は 2 行目)。
  static String formatCount(int n) {
    if (n < 1000) return '+$n';
    if (n < 100_000) return '+${n ~/ 1000}k';
    // 100k 以上: + なし、整数 + 単位。1M からは M。
    final text = n < 1_000_000 ? '${n ~/ 1000}k' : '${n ~/ 1_000_000}M';
    if (text.length <= charsPerLine) return text;
    final first = text.substring(0, charsPerLine);
    final rest = text.substring(charsPerLine);
    return '$first\n${rest.length > charsPerLine ? rest.substring(0, charsPerLine) : rest}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = RasqTokens.of(context);
    final wire = color ?? RasqColors.yellow;
    final fill = fillColor ?? wire.withValues(alpha: 0.6);
    final ring = ringColor ?? wire;
    final label = (count ?? 0) > 0 ? formatCount(count!) : null;
    final twoLines = label != null && label.contains('\n');
    final wireHeight = size + grow; // 縁取りつきのアイコンが内側に収まる(D-336 で 3px 大きく)。
    // 1 人 / 2 人は、アイコンをワイヤーの太さいっぱいに。それ以外はワイヤーの内側(上下左右 grow/2)。
    final fill1 = (count ?? 0) <= fillBelow;
    final avatarSize = fill1 ? wireHeight : size;
    final inset = fill1 ? 0.0 : grow / 2;
    final countStyle = TextStyle(fontSize: size * (twoLines ? 0.26 : 0.3), fontWeight: FontWeight.w700, color: scheme.onSurface, height: 1.05);
    final liveHeight = size * 0.28;

    // 角丸ワイヤーの幅: 左端(アイコンの下)から右へ、人数の文字幅 + 余白。
    final countWidth = label == null ? 0.0 : _textWidth(label, countStyle) + size * 0.3;
    const wireLeft = 0.0;
    final wireWidth = size + grow + size * 0.15 + countWidth;
    final totalWidth = wireWidth;

    // 縁取りはアイコンの内側に収める(外にはみ出すと行の高さと中心がずれる)。
    final ringWidth = size * 0.06;
    final avatar = Container(
      key: const ValueKey('avatarBundle.avatar'),
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ring, width: ringWidth)),
      child: RasqAvatar(imageUrl: user.avatarUrl, size: avatarSize - ringWidth * 2, fallbackLabel: user.displayName),
    );

    Widget bundle = SizedBox(
      width: totalWidth,
      height: wireHeight + (live ? liveHeight / 2 : 0),
      child: Stack(clipBehavior: Clip.none, children: [
        // 1. 背面: 角丸四角のワイヤー(黄色の塗り + 同色の枠線、左端まで)。
        Positioned(
          left: wireLeft,
          top: 0,
          width: wireWidth,
          height: wireHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fill,
              border: Border.all(color: wire, width: 1.5),
              borderRadius: BorderRadius.circular(wireHeight / 2),
            ),
          ),
        ),
        // 人数: 右端、上下中央、縁取りなし(100k 以上は 2 行)。
        if (label != null)
          Positioned(
            left: size + grow,
            top: 0,
            width: wireWidth - size - grow - size * 0.15,
            height: wireHeight,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(label, style: countStyle, maxLines: 2, softWrap: true, textAlign: TextAlign.right),
            ),
          ),
        // 2. アイコン: 円形 + 円形縁取り(黄色)、背面より上。
        Positioned(left: inset, top: inset, child: avatar),
        // 3. LIVE: 角丸ワイヤーの下辺中央(アイコンを除いた右側の中央)。
        if (live)
          Positioned(
            left: size / 2,
            width: wireWidth - size / 2,
            top: wireHeight - liveHeight / 2,
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
    return Semantics(label: label == null ? user.displayName : '${user.displayName} ${label.replaceAll('\n', '')}', child: bundle);
  }

  static double _textWidth(String text, TextStyle style) {
    final painter = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr, maxLines: 2)..layout();
    return painter.width;
  }
}
