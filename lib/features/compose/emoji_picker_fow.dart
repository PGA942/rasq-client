import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import '../../l10n/l10n.dart';
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
  String? title,
  String? predictionContext,
  Map<String, int> existingReactions = const {},
  Widget? actionBar,
  int column = 0,
  Rect? anchor,
  // ボタンにつながった形で出す (D-517): [anchor] と組で、首の中に描くボタンの見た目。null なら従来のアンカー付き(D-065)。
  Widget? anchorChild,
  TetherSide preferredSide = TetherSide.below,
  // どのアカウントのカスタム絵文字を出すか (D-278)。null = いま表示しているアカウント。
  String? accountKey,
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
  final resolvedTitle = title ?? appL10n.composeEmojiPickerTitle;
  final spec = FowSpec(
    type: FowPanelType.widget,
    initialHeightFactor: 0.4,
    minHeightFactor: 0.25,
    maxHeightFactor: 0.8,
    title: reaction ? null : resolvedTitle,
    cancelText: reaction ? null : appL10n.composeEmojiPickerClose,
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
  // ボタンから出す (D-517): アクションのボタン(リアクション / コンポーザーの絵文字)から開いたときは、ボタンにつながった形
  // (FowSpec.tether、D-513)。すぐ選べる絵文字の「その他」からも、同じ元のボタンにつなげ直す。
  // 検索欄でキーボードが出ても中身の Element は同じ(つながる側が替わっても入力のフォーカスは外れない)。ボタンがキーボードに
  // 隠れたときは首を外してキーボードの上に置き(TetheredPanel)、閉じればまたつながる。
  if (anchor != null && anchorChild != null) {
    // 親の FOW(コンポーザー)の中のボタンから下に開くときは、親をパネルの高さぶん持ち上げる(入力欄を覆わない。以前の
    // 子 FOW のドックと同じ並び: 入力欄 → ツールバー → ピッカー)。
    spec.tether = FowTether(anchorChild: anchorChild, preferredSide: preferredSide, width: 380, liftOwner: ownerId != null && preferredSide == TetherSide.below);
  }
  await manager.showFow<void>(
    id: emojiPickerFowId,
    ownerId: ownerId,
    semanticsLabel: resolvedTitle,
    // 同手法化 (D-051): 角丸枠 + フッター上にドック + **余白クリックで消失**
    // (ポップアップは出ない)。
    barrierBehavior: OverlayBarrierBehavior.dismissDiscard,
    spec: spec,
    builder: (ctx, handle) => EmojiPanel(
      accountKey: accountKey,
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
