import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../app/router.dart';
import '../../shell/headers.dart';
import '../home/material_icons.dart';
import '../plugins/slot_plugins.dart';
import 'custom_client.dart';
import 'custom_page.dart';

/// 登録済みのページ型プラグイン(同じ id は 1 つ = 既定の版)。
final installedPagePluginsProvider = Provider<List<SlotPlugin>>((ref) {
  final seen = <String>{};
  return [
    for (final p in ref.watch(activeSlotPluginsProvider))
      if (p.has(SlotIds.page) && seen.add(p.storePluginId ?? p.id)) p,
  ];
});

/// カスタムプラグイン (D-357): インストール済みのページ型を開く / 招待コードで参加 / ストアで探す。
class CustomPluginsScreen extends ConsumerStatefulWidget {
  const CustomPluginsScreen({super.key});
  @override
  ConsumerState<CustomPluginsScreen> createState() => _CustomPluginsScreenState();
}

class _CustomPluginsScreenState extends ConsumerState<CustomPluginsScreen> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final plugins = ref.watch(installedPagePluginsProvider);
    return Scaffold(
      appBar: const RasqPageHeader(title: 'カスタムプラグイン', showMore: false),
      body: ListView(padding: const EdgeInsets.only(bottom: RasqSpacing.lg), children: [
        const RasqSectionHeader(title: '招待コードで参加', topMargin: 0),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
          child: Row(children: [
            Expanded(
              child: TextField(
                key: const ValueKey('custom.invite.code'),
                controller: _code,
                decoration: const InputDecoration(hintText: '招待コード', isDense: true),
                onSubmitted: (_) => _join(),
              ),
            ),
            const SizedBox(width: RasqSpacing.xs),
            FilledButton(key: const ValueKey('custom.invite.join'), onPressed: _join, child: const Text('参加')),
          ]),
        ),
        const RasqSectionHeader(title: 'インストール済み'),
        if (plugins.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
            child: Text('まだありません。ストアの「カスタム」から探せます。', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          ),
        for (final p in plugins)
          RasqListTile(
            key: ValueKey('custom.plugins.${p.storePluginId ?? p.id}'),
            leading: Icon(materialIconByName(p.manifest.page?.icon) ?? Icons.dashboard_customize_outlined),
            title: p.manifest.page?.title ?? p.manifest.name,
            subtitle: [
              p.manifest.page?.isShared == true ? 'みんなで使える' : '1 人で使う',
              if (p.manifest.page?.allows('astell') == true) 'AsTell',
              if (p.manifest.page?.allows('profile') == true) 'プロフィール',
            ].join(' ・ '),
            onTap: () => context.push(Routes.customPage(p.storePluginId ?? p.id)),
          ),
        RasqListTile(leading: const Icon(Icons.storefront_outlined), title: 'ストアでカスタムプラグインを探す', onTap: () => context.push(Routes.storeSearch())),
      ]),
    );
  }

  void _join() {
    final code = _code.text.trim();
    if (code.isEmpty) return;
    context.push(Routes.customInvite(code));
  }
}

/// 招待コード → そのセッションのページへ(D-357)。
class CustomInviteScreen extends ConsumerStatefulWidget {
  const CustomInviteScreen({super.key, required this.code});
  final String code;
  @override
  ConsumerState<CustomInviteScreen> createState() => _CustomInviteScreenState();
}

class _CustomInviteScreenState extends ConsumerState<CustomInviteScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  Future<void> _resolve() async {
    try {
      final s = await ref.read(customSessionClientProvider).invite(widget.code);
      if (!mounted) return;
      if (s == null) return setState(() => _error = 'この招待コードのセッションは見つかりません(閉じられたかもしれません)');
      context.pushReplacement(Routes.customPage(s.pluginId, CustomPageArgs(pluginId: s.pluginId, version: s.version, sessionId: s.id).query));
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const RasqPageHeader(title: '招待', showMore: false),
        body: _error == null
            ? const Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5)))
            : RasqEmptyView(key: const ValueKey('custom.invite.error'), title: '参加できませんでした', hint: _error),
      );
}
