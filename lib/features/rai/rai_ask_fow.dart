import 'package:flutter/material.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import 'rai_automation.dart';

/// 選択肢タイル (D-229): 自動化の途中で足りない入力(フィード / ワード / 本文 / 取り込み先)を、入力タイルの上の
/// FOW で聞く。候補はチップ、自由入力があれば欄 + 「決定」。「やめる」= null。
const raiAskFowId = 'fow.rai.ask';

Future<String?> showRaiAskFow(OverlayManager manager, RaiAutoAsk ask, {Rect? anchor, double? maxWidth}) {
  if (manager.contains(raiAskFowId)) manager.close(raiAskFowId);
  return manager.showFow<String>(
    id: raiAskFowId,
    spec: FowSpec(title: ask.question, cancelText: 'やめる', initialHeightFactor: ask.allowFree ? 0.42 : 0.32, maxHeightFactor: 0.8, columnIndex: 0, maxWidth: maxWidth)
      ..anchor = anchor
      ..anchorBelow = anchor == null ? null : false,
    builder: (_, handle) => RaiAskBody(ask: ask, onPick: (v) => handle.close(result: v)),
  );
}

class RaiAskBody extends StatefulWidget {
  const RaiAskBody({super.key, required this.ask, required this.onPick});
  final RaiAutoAsk ask;
  final ValueChanged<String> onPick;
  @override
  State<RaiAskBody> createState() => _RaiAskBodyState();
}

class _RaiAskBodyState extends State<RaiAskBody> {
  final _text = TextEditingController();
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ask = widget.ask;
    return ListView(key: const ValueKey('rai.ask.fow'), padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.xl), children: [
      if (ask.hint != null) Text(ask.hint!, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
      if (ask.options.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: RasqSpacing.xs),
          child: Wrap(spacing: RasqSpacing.xs, runSpacing: RasqSpacing.xs, children: [
            for (final (i, o) in ask.options.indexed) ActionChip(key: ValueKey('rai.ask.option.$i'), label: Text(o.label, style: RasqTypography.bodySmall), onPressed: () => widget.onPick(o.id)),
          ]),
        ),
      if (ask.allowFree)
        Padding(
          padding: const EdgeInsets.only(top: RasqSpacing.sm),
          child: Row(children: [
            Expanded(
              child: TextField(
                key: const ValueKey('rai.ask.text'),
                controller: _text,
                style: RasqTypography.bodySmall,
                decoration: InputDecoration(hintText: ask.options.isEmpty ? '${ask.label}を入れる' : 'ほかの${ask.label}を入れる', isDense: true),
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty) widget.onPick(v.trim());
                },
              ),
            ),
            const SizedBox(width: RasqSpacing.xs),
            FilledButton(
              key: const ValueKey('rai.ask.ok'),
              onPressed: () {
                if (_text.text.trim().isNotEmpty) widget.onPick(_text.text.trim());
              },
              child: const Text('決定'),
            ),
          ]),
        ),
    ]);
  }
}
