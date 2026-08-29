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
  // リアクションピッカー (D-052〜D-054): 対象投稿のアクションボタンを同伴。
  // このとき FOW は**完全ヘッダーレス**(閉じる/タイトル行なし) — バー自体が
  // 角丸枠の上辺(= 掴めるヘッダー枠)になり、ハンドルは反対側の外縁に出る
  // (バーを掴んでいる間はハンドル消失 → 離した位置で上付き/下付き決定)。
  // 閉じるのは余白クリック / esc。
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
  );
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
      spec: actionBar == null ? null : spec,
      onPick: (e) {
        onPick(e);
        if (closeOnPick) handle.close(result: e);
      },
    ),
  );
}

void closeEmojiPicker(WidgetRef ref) => ref.read(overlayManagerProvider).close(emojiPickerFowId);
