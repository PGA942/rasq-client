import 'package:flutter/material.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../l10n/l10n.dart';

/// 投票フォーム (ワイヤーフレーム): 回答1 / 回答2 / ＋その他 / ∧時間指定 / 複数回答 / 日 時間 分 秒.
class PollDraft {
  PollDraft() : choices = [TextEditingController(), TextEditingController()];
  final List<TextEditingController> choices;
  bool multiple = false;
  bool timed = false;
  int days = 0, hours = 0, minutes = 0, seconds = 0;

  Duration? get expiresAfter => timed ? Duration(days: days, hours: hours, minutes: minutes, seconds: seconds) : null;
  List<String> get texts => [for (final c in choices) c.text.trim()].where((t) => t.isNotEmpty).toList();
  bool get isValid => texts.length >= 2 && (!timed || (expiresAfter!.inSeconds > 0));
  void dispose() {
    for (final c in choices) {
      c.dispose();
    }
  }
}

class PollEditor extends StatefulWidget {
  const PollEditor({super.key, required this.draft, required this.onRemove, this.maxChoices = 10});
  final PollDraft draft;

  /// 選択肢の上限(SNS は 10、RASQ は 6。S-023)。
  final int maxChoices;
  final VoidCallback onRemove;
  @override
  State<PollEditor> createState() => _PollEditorState();
}

class _PollEditorState extends State<PollEditor> {
  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: RasqSpacing.sm),
      padding: const EdgeInsets.all(RasqSpacing.sm),
      decoration: BoxDecoration(border: Border.all(color: scheme.onSurface), borderRadius: BorderRadius.circular(RasqSizes.radiusMd)),
      child: Column(children: [
        for (var i = 0; i < d.choices.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              if (i == 0) RasqIconButton(icon: Icons.cancel, size: 20, onPressed: widget.onRemove, tooltip: context.l10n.composePollRemoveTooltip) else const SizedBox(width: RasqSizes.minTap),
              Expanded(
                child: TextField(
                  controller: d.choices[i],
                  decoration: InputDecoration(hintText: context.l10n.composePollChoiceHint(i + 1), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              if (d.choices.length > 2)
                RasqIconButton(icon: Icons.close, size: 18, tooltip: context.l10n.composePollChoiceDeleteTooltip, onPressed: () => setState(() => d.choices.removeAt(i).dispose()))
              else
                const SizedBox(width: RasqSizes.minTap),
            ]),
          ),
        Row(children: [
          const SizedBox(width: RasqSizes.minTap),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: d.choices.length >= widget.maxChoices ? null : () => setState(() => d.choices.add(TextEditingController())),
              icon: const Icon(Icons.add),
              label: Text(context.l10n.composePollAddChoice),
              style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), alignment: Alignment.centerLeft),
            ),
          ),
          const SizedBox(width: RasqSizes.minTap),
        ]),
        const Divider(),
        Row(children: [
          InkWell(
            onTap: () => setState(() => d.timed = !d.timed),
            child: Row(children: [Icon(d.timed ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 18), Text(context.l10n.composePollTimed, style: RasqTypography.bodySmall)]),
          ),
          const Spacer(),
          Switch(value: d.multiple, onChanged: (v) => setState(() => d.multiple = v)),
          Text(context.l10n.composePollMultiple, style: RasqTypography.bodySmall),
        ]),
        if (d.timed)
          Row(children: [
            _num(context.l10n.composePollUnitDays, d.days, (v) => d.days = v),
            _num(context.l10n.composePollUnitHours, d.hours, (v) => d.hours = v),
            _num(context.l10n.composePollUnitMinutes, d.minutes, (v) => d.minutes = v),
            _num(context.l10n.composePollUnitSeconds, d.seconds, (v) => d.seconds = v),
          ]),
      ]),
    );
  }

  Widget _num(String unit, int value, ValueChanged<int> set) => Expanded(
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: TextEditingController(text: '$value'),
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 8)),
              onChanged: (t) => setState(() => set(int.tryParse(t) ?? 0)),
            ),
          ),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text(unit, style: RasqTypography.caption)),
        ]),
      );
}
