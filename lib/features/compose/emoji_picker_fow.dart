import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import 'emoji_panel.dart';

/// 絵文字ピッカー FOW (widget type): docked, resizable, content behind stays
/// interactive. One entry point for両方の用途 —
/// * カーソルのあるテキストフィールドへ挿入(コンポーザーの子FOW)
/// * 投稿へのリアクション入力(リアクションボタン長押し)
const emojiPickerFowId = 'fow.emoji';

Future<void> openEmojiPicker(
  WidgetRef ref, {
  required ValueChanged<String> onPick,
  String? ownerId,
  bool closeOnPick = false,
  String title = '絵文字',
  String? predictionContext,
  Map<String, int> existingReactions = const {},
  Widget? actionBar,
  int column = 0,
  Rect? anchor,
  // ステッカーのピッカーとして使う (D-273)。
  List<EmojiPanelSticker>? stickers,
}) async {
  final manager = ref.read(overlayManagerProvider);
  // FOW のクロームは 2 系統 (D-055):
  // ① ヘッダー行系(閉じる/タイトル + 上辺ハンドル) — 通常はこちら。
  //    リアクションピッカーも現状この系統(投稿のバーの複製は置かない)。
  // ② アクションバー系([actionBar] 指定時): バー自体が角丸枠の縁 =
  //    掴めるヘッダー枠になり、ハンドルは反対側の外縁。掴んでいる間は
  //    ハンドル消失 → 離した位置で上付き/下付き決定。**実物のアクション
  //    バーへのアンカー付け**(ワイヤーフレーム 1p 左下)は FOW 再設計
  //    (RRL 拡張)時にこの系統で実装する。
  final reaction = actionBar != null;
  final spec = FowSpec(
    type: FowPanelType.widget,
    initialHeightFactor: 0.4,
    minHeightFactor: 0.25,
    maxHeightFactor: 0.8,
    title: reaction ? null : title,
    cancelText: reaction ? null : '閉じる',
    dockAboveFooter: true,
    showHandle: !reaction,
    // 横ドッキング (D-062): 開いた側のカラムに揃う。ヘッダー(FowMoveGrip)を
    // 掴んで左右カラムへ移動でき、壁へ 50px めり込ませると壁付けピンになる。
    columnIndex: column,
  );
  // 実物アクションボタンへのアンカー (D-065): リアクション長押しはボタンの
  // 矩形を受け取り、基本下付き(余白不足で上付き)で張り付く。縦ドラッグで
  // 反転、別カラムへ動かすと壁付き表示へ。
  spec.anchor = anchor;
  await manager.showFow<void>(
    id: emojiPickerFowId,
    ownerId: ownerId,
    semanticsLabel: title,
    // 同手法化 (D-051): 角丸枠 + フッター上にドック + **余白クリックで消失**
    // (ポップアップは出ない)。
    barrierBehavior: OverlayBarrierBehavior.dismissDiscard,
    spec: spec,
    builder: (ctx, handle) => EmojiPanel(
      predictionContext: predictionContext,
      existingReactions: existingReactions,
      actionBar: actionBar,
      stickers: stickers,
      spec: actionBar == null ? null : spec,
      onPick: (e) {
        onPick(e);
        if (closeOnPick) handle.close(result: e);
      },
    ),
  );
}

void closeEmojiPicker(WidgetRef ref) => ref.read(overlayManagerProvider).close(emojiPickerFowId);
