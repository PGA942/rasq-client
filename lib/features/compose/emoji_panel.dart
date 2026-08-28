import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';

import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../app/providers.dart';
import '../home/reaction_history.dart';
import 'compose_providers.dart';
import 'emoji_prediction.dart';

/// 絵文字ピッカー (D-040: 検索 / 履歴 / **予測** / **デフォルト** / 独自の絵文字).
/// Emits the text to insert (`😀` or `:shortcode:`).
///
/// - 「予測」= 文脈([predictionContext])× 利用履歴 × 既存リアクションの
///   ルールベース予測(SigLIP/GLiNER 配線後に前段を強化 — 絵文字予測.md)
/// - 「デフォルト」(旧: 全てのemoji)は見出し長押しでバンドル編集(FOW)へ
///   移行する予定(M4 のプレースホルダー)
class EmojiPanel extends ConsumerStatefulWidget {
  const EmojiPanel({super.key, required this.onPick, this.height, this.predictionContext, this.existingReactions = const {}});
  final ValueChanged<String> onPick;

  /// Fixed height; null = fill the parent (FOW panel).
  final double? height;

  /// 予測の文脈(CW + 本文 + 親/引用。コンポーザーでは下書きテキスト)。
  final String? predictionContext;

  /// 対象投稿に既に付いているリアクション(リアクション用途のとき)。
  final Map<String, int> existingReactions;

  static const unicode = ['😀', '😂', '🥹', '😍', '🤔', '😭', '😡', '🥳', '😴', '🙏', '👍', '👎', '👏', '🙌', '💪', '❤️', '💔', '🔥', '✨', '🎉', '🚀', '🌙', '☀️', '🌸', '🍣', '🍜', '☕', '🍺', '🐱', '🐶', '🐟', '🦀', '💡', '📌', '✅', '❌', '⚠️', '💯', '🆗', '🔁'];

  @override
  ConsumerState<EmojiPanel> createState() => _EmojiPanelState();
}

class _EmojiPanelState extends ConsumerState<EmojiPanel> {
  final _q = TextEditingController();
  bool _customOpen = true;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  void _pick(String e) {
    ref.read(recentEmojiProvider.notifier).push(e);
    widget.onPick(e);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final custom = ref.watch(customEmojisProvider);
    final recent = ref.watch(recentEmojiProvider);
    final q = _q.text.trim().toLowerCase();
    final uni = EmojiPanel.unicode;
    return Container(
      height: widget.height,
      decoration: BoxDecoration(border: Border(top: BorderSide(color: scheme.outlineVariant))),
      child: Column(mainAxisSize: MainAxisSize.max, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.md, RasqSpacing.sm, RasqSpacing.md, 4),
          child: RasqSearchBar(controller: _q, hintText: '検索', onChanged: (_) => setState(() {})),
        ),
        Expanded(
          child: ListView(padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.md), children: [
            if (q.isEmpty && recent.isNotEmpty) ...[
              _label('履歴'),
              _grid([for (final e in recent) _EmojiCell(text: e, url: _urlFor(e, custom.value), onTap: () => _pick(e))]),
            ],
            // 予測 (D-040): 文脈 × 履歴 × 既存リアクションのルールベース。
            if (q.isEmpty) ...[
              () {
                final predicted = predictEmojis(
                  context: widget.predictionContext ?? '',
                  existingReactions: widget.existingReactions,
                  history: ref.watch(reactionHistoryProvider).value ?? const {},
                  recent: recent,
                  custom: custom.value ?? const [],
                );
                if (predicted.isEmpty) return const SizedBox.shrink();
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _label('予測'),
                  _grid([for (final e in predicted) _EmojiCell(text: e, url: _urlFor(e, custom.value), onTap: () => _pick(e))]),
                ]);
              }(),
            ],
            InkWell(
              onLongPress: () => ref.read(overlayManagerProvider).showAlert(id: 'emoji.bundle', title: 'バンドル編集', message: 'デフォルト欄のバンドル編集(FOW)は M4 で実装します。', confirmText: 'OK'),
              child: _label('デフォルト'),
            ),
            _grid([for (final e in uni) _EmojiCell(text: e, onTap: () => _pick(e))]),
            InkWell(
              onTap: () => setState(() => _customOpen = !_customOpen),
              child: Row(children: [Icon(_customOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 16), _label('独自の絵文字')]),
            ),
            if (_customOpen)
              custom.when(
                loading: () => const RasqLoading(),
                error: (_, _) => const SizedBox.shrink(),
                data: (list) {
                  final filtered = q.isEmpty ? list : list.where((e) => e.name.toLowerCase().contains(q) || e.aliases.any((a) => a.toLowerCase().contains(q))).toList();
                  if (filtered.isEmpty) return Padding(padding: const EdgeInsets.all(8), child: Text('独自の絵文字はありません', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)));
                  // 遅延読み込み (D-041): visibility_detector で見えたセルだけ
                  // 画像を読む → 件数上限を撤去できる。Wrap なので不等幅でも
                  // 横に詰めて改行される。
                  return _grid([for (final e in filtered) _EmojiCell(text: ':${e.name}:', url: e.url, lazy: true, onTap: () => _pick(':${e.name}:'))]);
                },
              ),
            const SizedBox(height: 12),
          ]),
        ),
      ]),
    );
  }

  static Uri? _urlFor(String e, List<EmojiInfo>? custom) {
    if (!e.startsWith(':') || custom == null) return null;
    final name = e.substring(1, e.length - 1);
    return custom.where((c) => c.name == name).firstOrNull?.url;
  }

  Widget _label(String t) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(t, style: RasqTypography.caption.copyWith(fontWeight: FontWeight.w700)));
  Widget _grid(List<Widget> cells) => Wrap(spacing: 4, runSpacing: 4, children: cells);
}

class _EmojiCell extends StatefulWidget {
  const _EmojiCell({required this.text, required this.onTap, this.url, this.lazy = false});
  final String text;
  final Uri? url;
  final VoidCallback onTap;

  /// true = 画面に入るまで画像を読まない(独自の絵文字の大量リスト用)。
  final bool lazy;

  @override
  State<_EmojiCell> createState() => _EmojiCellState();
}

class _EmojiCellState extends State<_EmojiCell> {
  bool _seen = false;

  @override
  Widget build(BuildContext context) {
    final loadNow = !widget.lazy || _seen || widget.url == null;
    // 可変幅表示 + ホバー/長押しチップ (D-040/D-041: Miria 方式参考 —
    // セル幅を固定せず絵文字の実寸比で並べ、Wrap が不等幅のまま改行する)。
    final inner = loadNow
        ? RasqCustomEmoji(url: widget.url, fallbackText: widget.text, height: 26, name: widget.text.startsWith(':') ? widget.text.replaceAll(':', '') : widget.text)
        : const SizedBox(width: 26, height: 26);
    final cell = InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        constraints: const BoxConstraints(minWidth: 36),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        // widthFactor: 1 で shrink-wrap — 素の Center は有界制約で全幅に
        // 広がり、Wrap で 1 行 1 絵文字になってしまう (D-042 修正)。
        child: Center(widthFactor: 1, child: inner),
      ),
    );
    if (loadNow) return cell;
    return VisibilityDetector(
      key: Key('emoji-cell-${widget.text}'),
      onVisibilityChanged: (info) {
        if (!_seen && info.visibleFraction > 0 && mounted) setState(() => _seen = true);
      },
      child: cell,
    );
  }
}
