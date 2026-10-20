import 'package:flutter/widgets.dart';
import 'package:rasq_design/rasq_design.dart' show RasqDesignL10nContext;

/// 「やめる」ボタンの名前の既定 (D-534)。`cancelText` を省いたときの値で、描くときに表示の言語の「キャンセル」
/// (rasq_design の部品 `design_overlay`)に置き換える。`null` は「やめるボタンを出さない」のまま。
/// 自分の既定を持つ包み(引数をそのまま渡す関数)は、この値を既定にすれば同じ振る舞いになる。
const String kOverlayDefaultCancel = '\u0000overlay.cancel';

/// [text] が [kOverlayDefaultCancel] なら表示の言語の「キャンセル」、ほかはそのまま。
String overlayCancelLabel(BuildContext context, String text) => text == kOverlayDefaultCancel ? context.designL10n.designOverlayCancel : text;
