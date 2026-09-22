import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:rasq_wasm_runtime/rasq_wasm_runtime.dart';

/// ビットマップを触るプラグインを見分けるスロット (§2.2)。
const kComposerMediaSlot = 'composer.media';

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
int fuelBudgetFor({required Set<String> permissions, Set<String> slots = const {}}) {
  final touchesBitmaps = slots.contains(kComposerMediaSlot) ||
      permissions.contains(RasqPermissions.replaceMedia) ||
      permissions.contains(RasqPermissions.tagMedia);
  return touchesBitmaps ? RasqWasmPlugin.mediaFuelBudget : RasqWasmPlugin.standardFuelBudget;
}
