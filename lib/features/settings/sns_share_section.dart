import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import '../../backend/orgate_client.dart';
import '../../l10n/l10n.dart';
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
      _toast(e.code.code == '409' ? appL10n.settingsSnsShareConflictError : e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggle(bool on) async {
    if (!on) {
      final l = context.l10n;
      final ok = await ref.read(overlayManagerProvider).showAlert(
            id: 'snsShare.off.confirm',
            title: l.settingsSnsShareOffConfirmTitle,
            message: rasqDetail(context, l.settingsSnsShareOffConfirmMessage, l.settingsSnsShareOffConfirmDetail),
            confirmText: l.settingsSnsShareOffConfirmButton,
            cancelText: l.settingsSnsShareCancelButton,
            destructive: true,
          );
      if (!ok) return;
    }
    await _run((n) => n.setEnabled(on), done: on ? null : appL10n.settingsSnsShareStopped);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget pad(Widget child) => Padding(padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, RasqSpacing.xs), child: child);
    final view = ref.watch(snsShareProvider);
    final s = view.status;
    final busy = _busy || view.busy;
    final on = s?.mode == SnsShareMode.on;
    final String subtitle;
    if (s == null) {
      subtitle = l.settingsSnsShareSubtitleLoading;
    } else if (s.deviceId == null) {
      subtitle = l.settingsSnsShareSubtitleUnsupported;
    } else if (!on) {
      subtitle = s.mode == SnsShareMode.off ? l.settingsSnsShareSubtitleOffAsk : l.settingsSnsShareSubtitleOff;
    } else if (s.holding) {
      subtitle = l.settingsSnsShareSubtitleOnHolding;
    } else if (s.waiting) {
      subtitle = l.settingsSnsShareSubtitleOnWaiting;
    } else {
      subtitle = l.settingsSnsShareSubtitleOnNotYet;
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      RasqSectionHeader(title: l.settingsSnsShareHeader),
      RasqCaption(
        l.settingsSnsShareCaption,
        detail: l.settingsSnsShareDetail,
        padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, RasqSpacing.xs),
      ),
      RasqSwitchListTile(
        key: const ValueKey('snsShare.switch'),
        title: l.settingsSnsShareSwitchTitle,
        subtitle: subtitle,
        value: on,
        enabled: !busy && s != null && s.deviceId != null,
        onChanged: _toggle,
      ),
      if (s != null && on && s.deviceId != null && !s.holding && !s.waiting)
        RasqListTile(
          key: const ValueKey('snsShare.request'),
          title: l.settingsSnsShareRequestTitle,
          subtitle: l.settingsSnsShareRequestSubtitle,
          chevron: false,
          onTap: busy ? null : () => _run((n) => n.setEnabled(true), done: l.settingsSnsShareRequested),
        ),
      if (s != null && on && s.devices.isNotEmpty) ...[
        pad(Text(l.settingsSnsShareDevicesLabel, style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700))),
        for (final d in s.devices)
          RasqListTile(
            key: ValueKey('snsShare.device.${d.deviceId}'),
            title: '${d.name}${d.current ? l.settingsSnsShareThisDeviceSuffix : ''}',
            subtitle: d.approved ? l.settingsSnsShareDeviceShared : (d.requested ? l.settingsSnsShareDeviceWaiting : l.settingsSnsShareDeviceNotShared),
            chevron: false,
            trailing: d.current || !(s.holding)
                ? null
                : d.requested && !d.approved
                    ? Row(mainAxisSize: MainAxisSize.min, children: [
                        TextButton(key: ValueKey('snsShare.approve.${d.deviceId}'), onPressed: busy ? null : () => _run((n) => n.approve(d), done: l.settingsSnsShareApproved(d.name)), child: Text(l.settingsSnsShareApproveButton)),
                        TextButton(onPressed: busy ? null : () => _run((n) => n.removeDevice(d)), child: Text(l.settingsSnsShareDeclineButton)),
                      ])
                    : d.approved
                        ? TextButton(key: ValueKey('snsShare.remove.${d.deviceId}'), onPressed: busy ? null : () => _run((n) => n.removeDevice(d), done: l.settingsSnsShareRemoved(d.name)), child: Text(l.settingsSnsShareRemoveButton))
                        : null,
          ),
        RasqCaption(
          l.settingsSnsShareRemovedCaption,
          detail: l.settingsSnsShareRemovedDetail,
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, RasqSpacing.xs),
        ),
      ],
    ]);
  }
}
