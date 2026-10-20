import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../backend/notify_api.dart';
import '../../backend/orgate_client.dart';
import '../../backend/rasq_account.dart';
import '../../l10n/l10n.dart';
import '../../shell/headers.dart';
import '../../shell/rasq_account_fow.dart';

/// 通知専用のアクセストークン (D-239 / Central S-014): 発行してこの端末をプッシュ登録、テスト通知、失効、
/// 配下トークン(マクロ / AsTell 共用)の発行。配信は当面ダミー(APNs / FCM は未接続)なので、テスト通知は
/// サーバーの受信箱に積まれたものを通知トークンで読み戻して確かめる。
class NotifyTokenScreen extends ConsumerStatefulWidget {
  const NotifyTokenScreen({super.key});
  @override
  ConsumerState<NotifyTokenScreen> createState() => _NotifyTokenScreenState();
}

class _NotifyTokenScreenState extends ConsumerState<NotifyTokenScreen> {
  bool _busy = false;
  String? _message;

  Future<void> _run(Future<String?> Function() body) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final m = await body();
      if (mounted) setState(() => _message = m);
    } on OrgateException catch (e) {
      if (mounted) setState(() => _message = context.l10n.settingsNotifyTokenError('$e'));
    } catch (e) {
      if (mounted) setState(() => _message = context.l10n.settingsNotifyTokenError('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configured = ref.watch(centralConfiguredProvider);
    final account = ref.watch(orgateAccountProvider);
    final noAccount = account.hasValue && account.value == null;
    final state = ref.watch(notifyStoreProvider);
    final store = ref.read(notifyStoreProvider.notifier);
    final l = context.l10n;
    return Scaffold(
      appBar: RasqPageHeader(title: l.settingsNotifyTokenTitle),
      body: ListView(children: [
        RasqCaption(
          l.settingsNotifyTokenCaption,
          detail: l.settingsNotifyTokenCaptionDetail,
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.md, RasqSpacing.page, 0),
        ),
        RasqSectionHeader(title: l.settingsNotifyTokenStatusSection),
        RasqValueListTile(title: l.settingsNotifyTokenPushTitle, value: rasqDetail(context, l.settingsNotifyTokenPushPending, l.settingsNotifyTokenPushPendingDetail)),
        if (!configured)
          RasqListTile(title: l.settingsNotifyTokenServerNotConfiguredTitle, subtitle: l.settingsNotifyTokenServerNotConfiguredSubtitle, onTap: () => context.push('/settings/server'))
        else if (noAccount)
          // RASQ アカウントが無いと発行は 401 になる — 先に案内する (D-240)。
          RasqListTile(key: const ValueKey('notify.needAccount'), title: l.settingsNotifyTokenNoAccountTitle, subtitle: l.settingsNotifyTokenNoAccountSubtitle, onTap: () => openRasqAccountFow(ref))
        else
          state.when(
            loading: () => const Padding(padding: EdgeInsets.all(RasqSpacing.page), child: RasqLoading()),
            error: (e, _) => Padding(padding: const EdgeInsets.all(RasqSpacing.page), child: Text(l.settingsNotifyTokenLoadError('$e'), style: RasqTypography.bodySmall.copyWith(color: RasqColors.danger))),
            data: (s) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              RasqValueListTile(key: const ValueKey('notify.status'), title: l.settingsNotifyTokenLocalTokenTitle, value: s.hasLocalToken ? l.settingsNotifyTokenLocalTokenActive : l.settingsNotifyTokenLocalTokenNone),
              RasqValueListTile(title: l.settingsNotifyTokenDevicesTitle, value: l.settingsNotifyTokenDevicesValue(s.devices.length)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.sm),
                child: s.hasLocalToken
                    ? Row(children: [
                        Expanded(
                          child: FilledButton(
                            key: const ValueKey('notify.test'),
                            onPressed: _busy
                                ? null
                                : () => _run(() async {
                                      final item = await store.sendTestAndRead();
                                      return item == null ? l.settingsNotifyTokenTestNotFound : l.settingsNotifyTokenTestFound(item.title, item.status, item.devices);
                                    }),
                            child: Text(l.settingsNotifyTokenTestButton),
                          ),
                        ),
                        const SizedBox(width: RasqSpacing.sm),
                        Expanded(
                          child: OutlinedButton(
                            key: const ValueKey('notify.disable'),
                            onPressed: _busy
                                ? null
                                : () => _run(() async {
                                      await store.unregisterThisDevice();
                                      await store.revoke(s.localTokenId!);
                                      return l.settingsNotifyTokenLocalRevoked;
                                    }),
                            child: Text(l.settingsNotifyTokenRevokeButton),
                          ),
                        ),
                      ])
                    : FilledButton(
                        key: const ValueKey('notify.enable'),
                        onPressed: _busy
                            ? null
                            : () => _run(() async {
                                  await store.enable(label: notifyPlatform());
                                  return l.settingsNotifyTokenEnabled;
                                }),
                        child: Text(l.settingsNotifyTokenEnableButton),
                      ),
              ),
              if (_message != null) Padding(padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page), child: Text(_message!, key: const ValueKey('notify.message'), style: RasqTypography.bodySmall)),
              if (s.tokens.isNotEmpty) RasqSectionHeader(title: l.settingsNotifyTokenTokensSection),
              for (final t in s.tokens)
                RasqListTile(
                  key: ValueKey('notify.token.${t.id}'),
                  title: '${t.isRoot ? l.settingsNotifyTokenKindRoot : l.settingsNotifyTokenKindChild}${t.label == null ? '' : l.settingsNotifyTokenLabelSuffix(t.label!)}${t.id == s.localTokenId ? '${l.settingsCommonSeparator}${l.settingsNotifyTokenThisDevice}' : ''}',
                  subtitle: [t.scopes.join(' / '), l.settingsNotifyTokenIssuedAt(RasqTimestamp.format(t.createdAt)), t.lastUsedAt == null ? l.settingsNotifyTokenUnused : l.settingsNotifyTokenLastUsedAt(RasqTimestamp.format(t.lastUsedAt!))].join(l.settingsCommonSeparator),
                  chevron: false,
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (t.isRoot)
                      RasqIconButton(
                        key: ValueKey('notify.child.${t.id}'),
                        icon: Icons.call_split,
                        size: 20,
                        tooltip: l.settingsNotifyTokenIssueChildTooltip,
                        onPressed: _busy
                            ? null
                            : () => _run(() async {
                                  final raw = await store.issueChild(t.id, scopes: const ['macro', 'astell'], label: 'macro / astell');
                                  unawaited(Clipboard.setData(ClipboardData(text: raw))); // 待たない(クリップボードの無い環境で止まらないように)
                                  return l.settingsNotifyTokenChildIssued;
                                }),
                      ),
                    RasqIconButton(
                      key: ValueKey('notify.revoke.${t.id}'),
                      icon: Icons.delete_outline,
                      size: 20,
                      tooltip: l.settingsNotifyTokenRevokeButton,
                      onPressed: _busy ? null : () => _run(() async {
                            await store.revoke(t.id);
                            return l.settingsNotifyTokenRevoked;
                          }),
                    ),
                  ]),
                ),
            ]),
          ),
        RasqCaption(
          l.settingsNotifyTokenStorageCaption,
          detail: l.settingsNotifyTokenStorageCaptionDetail,
          padding: const EdgeInsets.all(RasqSpacing.page),
        ),
      ]),
    );
  }
}
