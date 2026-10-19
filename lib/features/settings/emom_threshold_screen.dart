import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../l10n/l10n.dart';
import '../../shell/headers.dart';
import '../trend/trend_restrictions.dart';
import 'settings_dsl.dart';

/// 設定 → トレンド → EmoM の閾値 (D-404 / Central S-068)。
///
/// - 閾値(0〜100、既定 50)。**高いほど許容が広い**(刺激の強い話題も出す = 運営が制限したトレンドが隠れにくい)。
/// - 「閾値を公開する(制限の目安に使う)」(既定オフ)。オンなら値だけを Central へ送り、変えたら送り直し、オフで消してもらう。
/// - EmoM(感情 / 刺激の度合いのモデル)はまだ無い。いまはこの閾値を、運営のトレンドの制限にだけ使う。
class EmomThresholdScreen extends ConsumerStatefulWidget {
  const EmomThresholdScreen({super.key});
  @override
  ConsumerState<EmomThresholdScreen> createState() => _EmomThresholdScreenState();
}

class _EmomThresholdScreenState extends ConsumerState<EmomThresholdScreen> {
  /// ドラッグ中の値(離したときに保存する)。
  double? _dragging;
  EmomSyncResult? _sync;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // 開いたときに、送れていない分を送る。
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_syncNow()));
  }

  Future<void> _syncNow() async {
    if (!mounted) return;
    setState(() => _busy = true);
    final container = ProviderScope.containerOf(context, listen: false);
    final r = await syncEmomDisclosure(container.read);
    if (mounted) {
      setState(() {
        _busy = false;
        _sync = r;
      });
    }
  }

  Future<void> _set(String key, Object? value) async {
    await ref.read(settingsAreaProvider(emomArea).notifier).set(key, value);
    await _syncNow();
  }

  static String _band(AppLocalizations l, int v) => v < 30
      ? l.settingsEmomBandLow
      : v < 70
          ? l.settingsEmomBandMiddle
          : l.settingsEmomBandHigh;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = context.l10n;
    final values = ref.watch(settingsAreaProvider(emomArea)).value ?? const <String, Object?>{};
    final threshold = emomThresholdOf(values);
    final disclose = values['disclose'] == true;
    final shown = (_dragging ?? threshold.toDouble()).round();
    final sent = values['sent'];
    final status = switch (_sync) {
      _ when _busy => l.settingsEmomStatusSending,
      EmomSyncResult.noAccount when disclose => l.settingsEmomStatusNoAccount,
      EmomSyncResult.failed => l.settingsEmomStatusFailed,
      _ when disclose && sent == threshold => l.settingsEmomStatusDisclosed('$threshold'),
      _ when disclose => l.settingsEmomStatusPending,
      _ => l.settingsEmomStatusNotDisclosed,
    };
    Widget text(String t, {Key? key}) => Padding(
          key: key,
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, RasqSpacing.xs),
          child: Text(t, style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant)),
        );
    return Scaffold(
      appBar: RasqPageHeader(title: l.settingsEmomTitle),
      body: ListView(children: [
        text(l.settingsEmomIntro),
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.md, RasqSpacing.page, 0),
          child: Row(children: [
            Text(l.settingsEmomThresholdLabel, style: RasqTypography.title.copyWith(fontSize: 16)),
            const Spacer(),
            Text('$shown', key: const ValueKey('emom.value'), style: RasqTypography.title.copyWith(fontSize: 20)),
            Text(' / $emomThresholdMax', style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant)),
          ]),
        ),
        Slider(
          key: const ValueKey('emom.slider'),
          min: emomThresholdMin.toDouble(),
          max: emomThresholdMax.toDouble(),
          divisions: emomThresholdMax - emomThresholdMin,
          value: shown.toDouble(),
          label: '$shown',
          onChanged: (v) => setState(() => _dragging = v),
          onChangeEnd: (v) async {
            await _set('threshold', v.round());
            if (mounted) setState(() => _dragging = null);
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
          child: Row(children: [
            Text(l.settingsEmomScaleLow, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
            const Spacer(),
            Text(l.settingsEmomScaleHigh, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          ]),
        ),
        text(_band(l, shown), key: const ValueKey('emom.band')),
        text(l.settingsEmomExplanation('$emomThresholdDefault')),
        const Divider(),
        RasqSwitchListTile(
          key: const ValueKey('emom.disclose'),
          title: l.settingsEmomDiscloseTitle,
          subtitle: l.settingsEmomDiscloseSubtitle,
          value: disclose,
          onChanged: (v) => _set('disclose', v),
        ),
        text(status, key: const ValueKey('emom.status')),
        const Divider(),
        text(l.settingsEmomRestrictionExplanation),
      ]),
    );
  }
}
