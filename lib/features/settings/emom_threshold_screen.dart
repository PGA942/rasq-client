import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';

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

  static String _band(int v) => v < 30
      ? '控えめ — 運営が制限したトレンドを早めに隠します'
      : v < 70
          ? 'ふつう'
          : '広め — 運営が強く制限したトレンドだけを隠します';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final values = ref.watch(settingsAreaProvider(emomArea)).value ?? const <String, Object?>{};
    final threshold = emomThresholdOf(values);
    final disclose = values['disclose'] == true;
    final shown = (_dragging ?? threshold.toDouble()).round();
    final sent = values['sent'];
    final status = switch (_sync) {
      _ when _busy => '送っています…',
      EmomSyncResult.noAccount when disclose => 'RASQ アカウントでログインすると公開できます(この端末では使えます)',
      EmomSyncResult.failed => '送れませんでした。次に開いたとき(またはトレンドを読み直したとき)送り直します',
      _ when disclose && sent == threshold => '公開しています(値 $threshold)',
      _ when disclose => 'まだ届いていません',
      _ => '公開していません',
    };
    Widget text(String t, {Key? key}) => Padding(
          key: key,
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, RasqSpacing.xs),
          child: Text(t, style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant)),
        );
    return Scaffold(
      appBar: const RasqPageHeader(title: 'EmoM の閾値'),
      body: ListView(children: [
        text('EmoM は、投稿やトレンドの気持ちの強さ・刺激の強さを見積もる RASQ のモデルです(準備中)。'
            'いまはこの閾値を、RASQ の運営が通報を確かめてトレンドを制限するときの目安にだけ使います。'),
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.md, RasqSpacing.page, 0),
          child: Row(children: [
            Text('閾値', style: RasqTypography.title.copyWith(fontSize: 16)),
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
            Text('低い(隠れやすい)', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
            const Spacer(),
            Text('高い(隠れにくい)', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          ]),
        ),
        text(_band(shown), key: const ValueKey('emom.band')),
        text('閾値が高いほど、刺激の強い話題も受け入れる設定です。運営が制限したトレンドが隠れにくくなります。'
            '低いほど、制限されたトレンドを早めに隠します。既定は $emomThresholdDefault です。'),
        const Divider(),
        RasqSwitchListTile(
          key: const ValueKey('emom.disclose'),
          title: '閾値を公開する(制限の目安に使う)',
          subtitle: '値だけを RASQ のサーバーに送ります。運営は、公開された値をまとめた分布(どの値の人が何人いるか)だけを使い、'
              'あなたの値を個別に見ることはありません。オフにすると、送った値を消します。',
          value: disclose,
          onChanged: (v) => _set('disclose', v),
        ),
        text(status, key: const ValueKey('emom.status')),
        const Divider(),
        text('運営がトレンドを「N%」で制限すると、公開された閾値の低いほうから N% ほどの人に、そのトレンドが出なくなります。'
            '公開していなくても、この端末の閾値で同じように判定します(閾値はこの端末に保存されます)。'
            '「全員に非表示」にされたトレンドは、閾値に関係なく出ません。隠れたトレンドは、検索のトレンドの一覧に並ばなくなるだけです。'),
      ]),
    );
  }
}
