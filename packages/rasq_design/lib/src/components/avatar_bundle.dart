import 'dart:math' as math;

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
/// D-388: ワイヤーと縁取りは**下ほど濃いグラデーション**([wireTop] → [wireBottom])、縁取りをもう少し太く([ringRatio])。
/// [caption] を渡すと、LIVE の印の代わりに**下辺に地の色の角丸で名前を載せる**(ワイヤーを切り抜いたように見える。LIVE なら赤地)。
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
    this.faces = const [],
    this.caption,
    this.captionKey,
  });

  /// 下辺に載せる名前(ヘッダーのチップのルーム名、D-388)。あれば LIVE の印は出さず、LIVE なら名前の地を赤にする。
  final String? caption;
  final Key? captionKey;

  /// ワイヤーのグラデーション(上 → 下、D-388)。
  static const wireTop = Color(0xFFF6E359);
  static const wireBottom = Color(0xFFF09937);

  final UserSummary user;

  /// 1〜3 人のときの顔 (D-376): 先頭が [user](オーナー)。空でなければ人数を書かず、アイコンを半分ずつ重ねて並べ、
  /// 角丸ワイヤーをその幅(最大 [maxWireWidth])まで伸ばす。
  final List<UserSummary> faces;

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

  /// アイコンの縁取りの太さ(直径に対する比、D-386 で 2 割増し、D-388 でもう少し)。
  static const ringRatio = 0.085;

  /// 角丸ワイヤーをアイコンより大きくする量 (D-336)。
  static const grow = 3.0;

  /// この人数以下なら、アイコンをワイヤーの太さいっぱいに (D-336)。
  static const fillBelow = 2;

  /// 角丸ワイヤーの最大幅(人数の表記が一番長い `+999` のとき)。顔を並べるときもこれを超えない。
  static double maxWireWidth(double size) => size + grow + size * 0.15 + _textWidth('+999', TextStyle(fontSize: size * 0.3, fontWeight: FontWeight.w700, height: 1.05)) + size * 0.3;

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
    // 色を渡さなければ、下ほど濃いグラデーション (D-388)。
    final gradient = color == null && fillColor == null ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [wireTop, wireBottom]) : null;
    final fill = fillColor ?? wire.withValues(alpha: 0.6);
    final ring = ringColor ?? wire;
    final ringGradient = ringColor == null ? gradient : null;
    final stacked = faces.isNotEmpty;
    final label = !stacked && (count ?? 0) > 0 ? formatCount(count!) : null;
    final twoLines = label != null && label.contains('\n');
    final wireHeight = size + grow; // 縁取りつきのアイコンが内側に収まる(D-336 で 3px 大きく)。
    // 1 人 / 2 人は、アイコンをワイヤーの太さいっぱいに。それ以外はワイヤーの内側(上下左右 grow/2)。
    final fill1 = stacked || (count ?? 0) <= fillBelow;
    final avatarSize = fill1 ? wireHeight : size;
    final inset = fill1 ? 0.0 : grow / 2;
    final countStyle = TextStyle(fontSize: size * (twoLines ? 0.26 : 0.3), fontWeight: FontWeight.w700, color: scheme.onSurface, height: 1.05);
    final liveHeight = size * 0.28;
    final captionHeight = size * 0.36;

    // 角丸ワイヤーの幅: 左端(アイコンの下)から右へ、人数の文字幅 + 余白。
    final countWidth = label == null ? 0.0 : _textWidth(label, countStyle) + size * 0.3;
    // 顔を並べる (D-376): 1 つずつ半分重ねる。最大幅に収まらなければ重ねを深くする。
    final maxWidth = maxWireWidth(size);
    final step = faces.length < 2 ? 0.0 : ((maxWidth - avatarSize) / (faces.length - 1)).clamp(0.0, avatarSize / 2);
    final wireWidth = stacked ? (faces.length < 2 ? avatarSize : avatarSize + step * (faces.length - 1)) : size + grow + size * 0.15 + countWidth;
    // 名前を載せるときは、名前が読める幅(直径の 1.9 倍)まで広げ、ワイヤーはその真ん中に置く (D-388)。
    final totalWidth = caption != null ? math.max(wireWidth, size * 1.9) : wireWidth;
    final wireLeft = (totalWidth - wireWidth) / 2;

    // 縁取りはアイコンの内側に収める(外にはみ出すと行の高さと中心がずれる)。D-386: 太さを 2 割増し(0.06 → 0.072)。
    final ringWidth = size * ringRatio;
    Widget face(UserSummary u, Key key) => Container(
          key: key,
          width: avatarSize,
          height: avatarSize,
          padding: ringGradient == null ? null : EdgeInsets.all(ringWidth),
          decoration: ringGradient == null
              ? BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ring, width: ringWidth))
              : BoxDecoration(shape: BoxShape.circle, gradient: ringGradient),
          child: ringGradient == null
              ? RasqAvatar(imageUrl: u.avatarUrl, size: avatarSize - ringWidth * 2, fallbackLabel: u.displayName)
              : ClipOval(child: RasqAvatar(imageUrl: u.avatarUrl, size: avatarSize - ringWidth * 2, fallbackLabel: u.displayName)),
        );
    final avatar = face(stacked ? faces.first : user, const ValueKey('avatarBundle.avatar'));

    Widget bundle = SizedBox(
      width: totalWidth,
      height: wireHeight + (caption != null ? captionHeight * 0.3 : live ? liveHeight / 2 : 0),
      child: Stack(clipBehavior: Clip.none, children: [
        // 1. 背面: 角丸四角のワイヤー(黄色の塗り + 同色の枠線、左端まで)。
        Positioned(
          left: wireLeft,
          top: 0,
          width: wireWidth,
          height: wireHeight,
          child: DecoratedBox(
            decoration: gradient != null
                ? BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(wireHeight / 2))
                : BoxDecoration(
                    color: fill,
                    border: Border.all(color: wire, width: 1.5),
                    borderRadius: BorderRadius.circular(wireHeight / 2),
                  ),
          ),
        ),
        // 人数: 右端、上下中央、縁取りなし(100k 以上は 2 行)。
        if (label != null)
          Positioned(
            left: wireLeft + size + grow,
            top: 0,
            width: wireWidth - size - grow - size * 0.15,
            height: wireHeight,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(label, style: countStyle, maxLines: 2, softWrap: true, textAlign: TextAlign.right),
            ),
          ),
        // 2. アイコン: 円形 + 円形縁取り(黄色)、背面より上。顔を並べるときは右から描き、左(オーナー)を一番上に。
        for (var i = faces.length - 1; i >= 1; i--) Positioned(left: wireLeft + step * i, top: 0, child: face(faces[i], ValueKey('avatarBundle.face.$i'))),
        Positioned(left: wireLeft + inset, top: inset, child: avatar),
        // 3'. 名前 (D-388): 下辺に地の色の角丸で載せる(LIVE なら赤地)。
        if (caption != null)
          Positioned(
            left: 0,
            width: totalWidth,
            top: wireHeight - captionHeight * 0.7,
            height: captionHeight,
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: size * 0.1),
                height: captionHeight,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: live ? tokens.live : scheme.surface, borderRadius: BorderRadius.circular(captionHeight / 2)),
                child: Text(
                  caption!,
                  key: captionKey,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: live ? RasqColors.white : scheme.onSurface, fontSize: size * 0.24, fontWeight: FontWeight.w700, height: 1.0),
                ),
              ),
            ),
          ),
        // 3. LIVE: 角丸ワイヤーの下辺中央(アイコンを除いた右側の中央)。
        if (live && caption == null)
          Positioned(
            left: wireLeft + size / 2,
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
    return Semantics(label: stacked ? faces.map((f) => f.displayName).join('、') : label == null ? user.displayName : '${user.displayName} ${label.replaceAll('\n', '')}', child: bundle);
  }

  static double _textWidth(String text, TextStyle style) {
    final painter = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr, maxLines: 2)..layout();
    return painter.width;
  }
}
