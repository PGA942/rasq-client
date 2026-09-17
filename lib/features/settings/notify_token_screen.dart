import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../backend/notify_api.dart';
import '../../backend/orgate_client.dart';
import '../../shell/headers.dart';

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
      if (mounted) setState(() => _message = 'できませんでした — $e');
    } catch (e) {
      if (mounted) setState(() => _message = 'できませんでした — $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final configured = ref.watch(centralConfiguredProvider);
    final state = ref.watch(notifyStoreProvider);
    final store = ref.read(notifyStoreProvider.notifier);
    final caption = RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant);
    return Scaffold(
      appBar: const RasqPageHeader(title: '通知専用のアクセストークン'),
      body: ListView(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.md, RasqSpacing.page, 0),
          child: Text(
            '通知トークンは、RASQ サーバーからの通知を受け取るためだけのトークンです(読めるのは自分宛ての通知の受信箱だけ。投稿やアカウントの操作はできません)。'
            'マクロ / AsTell 用の配下トークンもここから発行します。',
            style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        const RasqSectionHeader(title: '状態'),
        const RasqValueListTile(title: 'プッシュ配信', value: 'ダミー(APNs / FCM は未接続)'),
        if (!configured)
          RasqListTile(title: 'RASQ サーバーの接続先が未設定です', subtitle: '接続先を入れると発行できます', onTap: () => context.push('/settings/server'))
        else
          state.when(
            loading: () => const Padding(padding: EdgeInsets.all(RasqSpacing.page), child: RasqLoading()),
            error: (e, _) => Padding(padding: const EdgeInsets.all(RasqSpacing.page), child: Text('取得できませんでした: $e', style: RasqTypography.bodySmall.copyWith(color: RasqColors.danger))),
            data: (s) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              RasqValueListTile(key: const ValueKey('notify.status'), title: 'この端末のトークン', value: s.hasLocalToken ? '有効' : '未発行'),
              RasqValueListTile(title: 'プッシュ登録している端末', value: '${s.devices.length} 台'),
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
                                      return item == null ? 'テスト通知を積みましたが、受信箱で見つかりませんでした' : '受信箱で確認できました: 「${item.title}」(${item.status}、端末 ${item.devices} 台)';
                                    }),
                            child: const Text('テスト通知を送る'),
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
                                      return 'この端末のトークンを失効しました';
                                    }),
                            child: const Text('失効する'),
                          ),
                        ),
                      ])
                    : FilledButton(
                        key: const ValueKey('notify.enable'),
                        onPressed: _busy
                            ? null
                            : () => _run(() async {
                                  await store.enable(label: notifyPlatform());
                                  return '発行して、この端末をプッシュ登録しました';
                                }),
                        child: const Text('通知トークンを発行してこの端末を登録'),
                      ),
              ),
              if (_message != null) Padding(padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page), child: Text(_message!, key: const ValueKey('notify.message'), style: RasqTypography.bodySmall)),
              if (s.tokens.isNotEmpty) const RasqSectionHeader(title: '発行済みのトークン'),
              for (final t in s.tokens)
                RasqListTile(
                  key: ValueKey('notify.token.${t.id}'),
                  title: '${t.isRoot ? '通知トークン' : '配下トークン'}${t.label == null ? '' : '(${t.label})'}${t.id == s.localTokenId ? ' ・ この端末' : ''}',
                  subtitle: '${t.scopes.join(' / ')} ・ 発行 ${RasqTimestamp.format(t.createdAt)}${t.lastUsedAt == null ? ' ・ 未使用' : ' ・ 最終使用 ${RasqTimestamp.format(t.lastUsedAt!)}'}',
                  chevron: false,
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (t.isRoot)
                      RasqIconButton(
                        key: ValueKey('notify.child.${t.id}'),
                        icon: Icons.call_split,
                        size: 20,
                        tooltip: '配下トークンを発行(マクロ / AsTell 共用)',
                        onPressed: _busy
                            ? null
                            : () => _run(() async {
                                  final raw = await store.issueChild(t.id, scopes: const ['macro', 'astell'], label: 'macro / astell');
                                  unawaited(Clipboard.setData(ClipboardData(text: raw))); // 待たない(クリップボードの無い環境で止まらないように)
                                  return '配下トークンを発行してクリップボードにコピーしました(生の値が見られるのは今だけです)';
                                }),
                      ),
                    RasqIconButton(
                      key: ValueKey('notify.revoke.${t.id}'),
                      icon: Icons.delete_outline,
                      size: 20,
                      tooltip: '失効する',
                      onPressed: _busy ? null : () => _run(() async {
                            await store.revoke(t.id);
                            return '失効しました';
                          }),
                    ),
                  ]),
                ),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.all(RasqSpacing.page),
          child: Text('生のトークンは発行時にだけ受け取り、端末内の安全な領域に保存します。サーバーに残るのはハッシュだけです。親のトークンを失効すると配下のトークンも失効します。', style: caption),
        ),
      ]),
    );
  }
}
