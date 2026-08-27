import 'package:flutter/foundation.dart';
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
}) async {
  final manager = ref.read(overlayManagerProvider);
  await manager.showFow<void>(
    id: emojiPickerFowId,
    ownerId: ownerId,
    spec: FowSpec(type: FowPanelType.widget, initialHeightFactor: 0.4, minHeightFactor: 0.25, maxHeightFactor: 0.8, title: title, cancelText: '閉じる'),
    builder: (ctx, handle) => EmojiPanel(
      onPick: (e) {
        onPick(e);
        if (closeOnPick) handle.close(result: e);
      },
    ),
  );
}

void closeEmojiPicker(WidgetRef ref) => ref.read(overlayManagerProvider).close(emojiPickerFowId);
