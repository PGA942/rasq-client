import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import '../../backend/orgate_client.dart';
import '../../session/sns_share.dart';

/// 「アカウントのセキュリティ」の一節 (D-319): SNS のアクセストークンを端末間で共有(E2E)するスイッチと、端末の一覧。
class SnsShareSection extends ConsumerStatefulWidget {
  const SnsShareSection({super.key});
  @override
  ConsumerState<SnsShareSection> createState() => _SnsShareSectionState();
}

class _SnsShareSectionState extends ConsumerState<SnsShareSection> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // 画面を開いたら取り直す(見回りを待たない)。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(snsShareProvider.notifier).check();
    });
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _run(Future<void> Function(SnsShareNotifier n) action, {String? done}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action(ref.read(snsShareProvider.notifier));
      if (done != null) _toast(done);
    } on OrgateException catch (e) {
      _toast(e.code.code == '409' ? 'ほかの端末が先に変えました。もう一度お試しください' : e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggle(bool on) async {
    if (!on) {
      final ok = await ref.read(overlayManagerProvider).showAlert(
            id: 'snsShare.off.confirm',
            title: 'SNS のアクセストークンの共有をやめますか?',
            message: 'RASQ Central にある共有の中身(暗号化したもの)と、すべての端末の鍵を消します。それぞれの端末の SNS のログインはそのまま残ります。',
            confirmText: 'やめる',
            cancelText: 'キャンセル',
            destructive: true,
          );
      if (!ok) return;
    }
    await _run((n) => n.setEnabled(on), done: on ? null : '共有をやめました');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final caption = RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant);
    Widget pad(Widget child) => Padding(padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, RasqSpacing.xs), child: child);
    final view = ref.watch(snsShareProvider);
    final s = view.status;
    final busy = _busy || view.busy;
    final on = s?.mode == SnsShareMode.on;
    final String subtitle;
    if (s == null) {
      subtitle = '読み込み中…';
    } else if (s.deviceId == null) {
      subtitle = 'この端末のログインは共有に対応していません。ログインし直してください';
    } else if (!on) {
      subtitle = s.mode == SnsShareMode.off ? 'オフ(別の端末で初めてログインしたとき、ここで共有するかを聞きます)' : 'オフ';
    } else if (s.holding) {
      subtitle = 'オン ・ この端末は共有しています';
    } else if (s.waiting) {
      subtitle = 'オン ・ 共有している端末での承認を待っています';
    } else {
      subtitle = 'オン ・ この端末は、まだ共有していません';
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const RasqSectionHeader(title: 'SNS のアクセストークンの共有'),
      pad(Text(
        'SNS のアクセストークンを、この RASQ アカウントでログインしている端末のあいだで暗号化(E2E)して共有します。'
        '新しい端末でログインすると、共有している端末で承認したあと、その端末も SNS アカウントに一斉ログインします。RASQ のサーバーは中身を読めません。',
        style: caption,
      )),
      RasqSwitchListTile(
        key: const ValueKey('snsShare.switch'),
        title: 'SNS のアクセストークンを端末間で共有(E2E)',
        subtitle: subtitle,
        value: on,
        enabled: !busy && s != null && s.deviceId != null,
        onChanged: _toggle,
      ),
      if (s != null && on && s.deviceId != null && !s.holding && !s.waiting)
        RasqListTile(
          key: const ValueKey('snsShare.request'),
          title: 'この端末にも共有してもらう',
          subtitle: '共有している端末に、承認の問いが出ます',
          chevron: false,
          onTap: busy ? null : () => _run((n) => n.setEnabled(true), done: '共有している端末に、承認を求めました'),
        ),
      if (s != null && on && s.devices.isNotEmpty) ...[
        pad(Text('端末', style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700))),
        for (final d in s.devices)
          RasqListTile(
            key: ValueKey('snsShare.device.${d.deviceId}'),
            title: '${d.name}${d.current ? '(この端末)' : ''}',
            subtitle: d.approved ? '共有しています' : (d.requested ? '承認を待っています' : '共有していません'),
            chevron: false,
            trailing: d.current || !(s.holding)
                ? null
                : d.requested && !d.approved
                    ? Row(mainAxisSize: MainAxisSize.min, children: [
                        TextButton(key: ValueKey('snsShare.approve.${d.deviceId}'), onPressed: busy ? null : () => _run((n) => n.approve(d), done: '${d.name} に共有しました'), child: const Text('共有する')),
                        TextButton(onPressed: busy ? null : () => _run((n) => n.removeDevice(d)), child: const Text('断る')),
                      ])
                    : d.approved
                        ? TextButton(key: ValueKey('snsShare.remove.${d.deviceId}'), onPressed: busy ? null : () => _run((n) => n.removeDevice(d), done: '${d.name} を共有から外しました'), child: const Text('外す'))
                        : null,
          ),
        pad(Text('「ログイン中の端末」でその端末をログアウトさせると、その端末の鍵も消えます。外した端末は、それまでに受け取ったアクセストークンを持っています(心当たりが無ければ、SNS 側でもログアウトしてください)。', style: caption)),
      ],
    ]);
  }
}
