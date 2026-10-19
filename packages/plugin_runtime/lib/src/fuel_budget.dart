import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'wasm_runtime.dart';

/// ビットマップを触るプラグインを見分けるスロット (§2.2)。
const kComposerMediaSlot = 'composer.media';

/// 全画面表示プラグインのスロット (§2.4)。`viewer.open` で画像本体(長辺 1024 の PNG)を受け取り、自分で復号して見る
/// = ビットマップを触る (D-519)。
const kViewerOverlaySlot = 'viewer.overlay';

/// このプラグインに渡す 1 呼び出しあたりの fuel 予算。
///
/// 実測では正当な処理のコストが 5 万倍ひらく: 画像編集 (2048x1536) が
/// 21.5 億に対し、トレンドやビューワーは 12 万。全部を重いほうに合わせると
/// 暴走を止めるのに数秒かかり、軽いほうに合わせると正当な画像編集が落ちる。
///
/// 分ける軸は `kind` **ではない**。実測で最も重かったのは `kind: action`、
/// 最も軽かったのが `kind: mediaViewer` で、`kind` は「どこに挿さるか」で
/// あって「いくらかかるか」ではなかった。コストに効くのはビットマップを
/// 触るかどうかで、これはスロットと権限の宣言から読める。
///
/// `viewer.overlay` も画像を受け取って復号する (D-519)。「ビューワーは 12 万」は画像を渡さない呼び出し
/// (`plugin.manifest` など)の値で、QR コード検出(sample.media-fullscreen)の `viewer.open` は長辺 1024 の画像 1 枚で
/// 4.5〜10 億かかる(版と画像による)。5000 万では毎回 `E02` で落ち、全画面のトグルが「!」(失敗)になっていた。
int fuelBudgetFor({required Set<String> permissions, Set<String> slots = const {}}) {
  final touchesBitmaps = slots.contains(kComposerMediaSlot) ||
      slots.contains(kViewerOverlaySlot) ||
      permissions.contains(RasqPermissions.replaceMedia) ||
      permissions.contains(RasqPermissions.tagMedia);
  return touchesBitmaps ? RasqWasmPlugin.mediaFuelBudget : RasqWasmPlugin.standardFuelBudget;
}

/// fuel 予算 [budget] に倍率 [factor] を掛ける(サイドロードの制限モードは 0.5、D-308)。
///
/// [budget] が null = ランタイム既定(重いほう = [RasqWasmPlugin.mediaFuelBudget])として掛ける。
/// [factor] が 1 以上なら [budget] をそのまま返す(null は null のまま = ランタイム既定)。
/// 0 以下は 1 に丸める(予算 0 = 何も動かない、を倍率の書き損じで作らない)。
int? scaleFuelBudget(int? budget, double factor) {
  if (factor >= 1) return budget;
  final scaled = ((budget ?? RasqWasmPlugin.mediaFuelBudget) * factor).floor();
  return scaled < 1 ? 1 : scaled;
}
