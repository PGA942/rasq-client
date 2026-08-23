import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';

import 'compose_providers.dart';

/// 絵文字ピッカー (ワイヤーフレーム: 検索 / 履歴 / 全てのemoji / 独自の絵文字).
/// Emits the text to insert (`😀` or `:shortcode:`).
class EmojiPanel extends ConsumerStatefulWidget {
  const EmojiPanel({super.key, required this.onPick, this.height});
  final ValueChanged<String> onPick;

  /// Fixed height; null = fill the parent (FOW panel).
  final double? height;

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
            _label('全てのemoji'),
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
                  return _grid([for (final e in filtered.take(240)) _EmojiCell(text: ':${e.name}:', url: e.url, onTap: () => _pick(':${e.name}:'))]);
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

class _EmojiCell extends StatelessWidget {
  const _EmojiCell({required this.text, required this.onTap, this.url});
  final String text;
  final Uri? url;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Tooltip(
          message: text,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Center(
              child: url == null ? Text(text, style: const TextStyle(fontSize: 22)) : Image.network(url.toString(), width: 26, height: 26, errorBuilder: (_, _, _) => Text(text, style: const TextStyle(fontSize: 10))),
            ),
          ),
        ),
      );
}
