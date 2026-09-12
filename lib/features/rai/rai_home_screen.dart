import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';

import '../../shell/headers.dart';
import 'rai_llm.dart';
import 'rai_overlay.dart';
import 'rai_providers.dart';
import 'rai_widgets.dart';

/// RAi ホーム (D-179、ワイヤーフレーム p.4): マスコット + 「マクロとか、お任せください！」+
/// 直近の質問。開くと RAi バー(アシスタントモード)が出る。マクロ / チャット履歴は第二期。
class RaiHomeScreen extends ConsumerStatefulWidget {
  const RaiHomeScreen({super.key});
  @override
  ConsumerState<RaiHomeScreen> createState() => _RaiHomeScreenState();
}

class _RaiHomeScreenState extends ConsumerState<RaiHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showRai(ref, mode: RaiMode.assistant);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = ref.watch(raiProvider);
    return Scaffold(
      appBar: RasqPageHeader(title: 'RAi', onBack: () => Navigator.of(context).maybePop()),
      body: ListView(padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xl, RasqSpacing.page, 240), children: [
        const Center(child: RaiMascot(size: 180)),
        const SizedBox(height: RasqSpacing.md),
        Text('マクロとか、お任せください！', textAlign: TextAlign.center, style: RasqTypography.title),
        const SizedBox(height: RasqSpacing.xs),
        Text('インストラクション: 操作を聞くと RAi がボタンまで移動して指差します。\nアシスタント: 端末内モデル($raiLocalModelLabel)で答えます(マクロは第二期)。', textAlign: TextAlign.center, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
        _ModelSection(),
        if (s.history.isNotEmpty) ...[
          const RasqSectionHeader(title: '最近の質問', topMargin: RasqSpacing.xl),
          for (final h in s.history)
            RasqListTile(
              title: h,
              leading: Icon(Icons.history, size: 20, color: scheme.onSurfaceVariant),
              chevron: false,
              onTap: () {
                showRai(ref, mode: RaiMode.instruction);
                ref.read(raiProvider.notifier).ask(h);
              },
            ),
        ],
      ]),
    );
  }
}

/// 端末内モデル (D-181): 状態 / ダウンロード / 解放 / 削除 / モデルの切り替え。
class _ModelSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final llm = ref.watch(raiLlmProvider);
    final st = ref.watch(raiLlmStatusProvider).value ?? llm.current;
    final spec = llm.spec;
    final manager = ref.read(overlayManagerProvider);
    Future<void> guard(Future<void> Function() f) async {
      try {
        await f();
      } on RaiLlmException catch (e) {
        if (context.mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(e.message)));
      }
    }

    final phaseText = switch (st.phase) {
      RaiLlmPhase.notInstalled => '未ダウンロード(${spec.sizeMb} MB)',
      RaiLlmPhase.downloading => 'ダウンロード中 ${st.progress ?? 0}%',
      RaiLlmPhase.ready => '準備完了',
      RaiLlmPhase.loading => '読み込み中',
      RaiLlmPhase.generating => '生成中',
      RaiLlmPhase.unavailable => '使えません',
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const RasqSectionHeader(title: '端末内モデル', topMargin: RasqSpacing.xl),
      RasqListTile(
        key: const ValueKey('rai.model.tile'),
        title: '$raiLocalModelLabel = ${spec.label}',
        subtitle: st.message == null ? phaseText : '$phaseText — ${st.message}',
        leading: Icon(Icons.smartphone, size: 20, color: scheme.onSurfaceVariant),
        chevron: false,
      ),
      if (st.phase == RaiLlmPhase.downloading)
        Padding(padding: const EdgeInsets.symmetric(vertical: RasqSpacing.xs), child: LinearProgressIndicator(value: (st.progress ?? 0) / 100)),
      Wrap(spacing: RasqSpacing.sm, children: [
        if (st.phase == RaiLlmPhase.notInstalled || st.phase == RaiLlmPhase.unavailable)
          FilledButton.icon(key: const ValueKey('rai.model.download'), onPressed: () => guard(llm.install), icon: const Icon(Icons.download, size: 18), label: const Text('ダウンロード')),
        if (st.ready || st.phase == RaiLlmPhase.loading)
          OutlinedButton.icon(key: const ValueKey('rai.model.release'), onPressed: () => guard(llm.release), icon: const Icon(Icons.memory, size: 18), label: const Text('メモリを解放')),
        if (st.ready)
          OutlinedButton.icon(
            key: const ValueKey('rai.model.delete'),
            onPressed: () async {
              final ok = await manager.showAlert(id: 'rai.model.delete', title: 'モデルを削除しますか', message: '${spec.fileName} を端末から消します。', confirmText: '削除', cancelText: 'キャンセル', destructive: true);
              if (ok) await guard(llm.uninstall);
            },
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('削除'),
          ),
      ]),
      const SizedBox(height: RasqSpacing.sm),
      Text('モデルの切り替え(既定は 4B 級 / 3〜4bit の GGUF。LiteRT は iOS 向け)', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
      for (final m in raiModelSpecs)
        RasqListTile(
          key: ValueKey('rai.model.pick.${m.id}'),
          title: m.label,
          subtitle: '${m.engine.label} · ${m.fileName} · ${m.sizeMb} MB',
          leading: Icon(m.id == spec.id ? Icons.radio_button_checked : Icons.radio_button_off, size: 20, color: m.id == spec.id ? RasqColors.link : scheme.onSurfaceVariant),
          chevron: false,
          enabled: st.phase != RaiLlmPhase.downloading,
          onTap: () => guard(() => llm.select(m)),
        ),
      Text('フォールアップ先(サーバー側 / クラウドの大きいモデル)は未接続です。端末内モデルが使えないときは失敗表示になります。', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
    ]);
  }
}
