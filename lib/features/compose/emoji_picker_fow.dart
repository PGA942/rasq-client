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
}) async {
  final manager = ref.read(overlayManagerProvider);
  // リアクションピッカー (D-052/D-053): 対象投稿のアクションボタンを同伴。
  // ホスト側の上辺ハンドルは消し、バーの**反対側の外縁**にハンドルを出す
  // (バーを掴んでいる間はハンドル消失 → 離した位置で上付き/下付き決定)。
  final spec = FowSpec(
    type: FowPanelType.widget,
    initialHeightFactor: 0.4,
    minHeightFactor: 0.25,
    maxHeightFactor: 0.8,
    title: title,
    cancelText: '閉じる',
    dockAboveFooter: true,
    showHandle: actionBar == null,
  );
  await manager.showFow<void>(
    id: emojiPickerFowId,
    ownerId: ownerId,
    // 同手法化 (D-051): 角丸枠 + フッター上にドック + **余白クリックで消失**
    // (ポップアップは出ない)。
    barrierBehavior: OverlayBarrierBehavior.dismissDiscard,
    spec: spec,
    builder: (ctx, handle) => EmojiPanel(
      predictionContext: predictionContext,
      existingReactions: existingReactions,
      actionBar: actionBar,
      spec: actionBar == null ? null : spec,
      onPick: (e) {
        onPick(e);
        if (closeOnPick) handle.close(result: e);
      },
    ),
  );
}

void closeEmojiPicker(WidgetRef ref) => ref.read(overlayManagerProvider).close(emojiPickerFowId);
