import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';


import '../../shell/headers.dart';
import 'rai_llm.dart';
import 'rai_models_fow.dart';
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

/// 端末内モデル (D-181 → D-183 で FOW へ): ここは今のモデルと状態だけ。詳細はモデル FOW。
class _ModelSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final llm = ref.watch(raiLlmProvider);
    final st = ref.watch(raiLlmStatusProvider).value ?? llm.current;
    final spec = llm.spec;
    final phaseText = switch (st.phase) {
      RaiLlmPhase.notInstalled => '未ダウンロード(${spec.sizeMb} MB)',
      RaiLlmPhase.downloading => 'ダウンロード中 ${st.progress ?? 0}%',
      RaiLlmPhase.ready => '準備完了',
      RaiLlmPhase.loading => st.message ?? '読み込み中',
      RaiLlmPhase.generating => '生成中',
      RaiLlmPhase.unavailable => '使えません',
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const RasqSectionHeader(title: '端末内モデル', topMargin: RasqSpacing.xl),
      RasqListTile(
        key: const ValueKey('rai.model.tile'),
        title: '$raiLocalModelLabel = ${spec.label}',
        subtitle: st.message == null || st.phase == RaiLlmPhase.loading ? phaseText : '$phaseText — ${st.message}',
        leading: Icon(Icons.smartphone, size: 20, color: scheme.onSurfaceVariant),
        onTap: () => showRaiModelsFow(ref),
      ),
      Padding(
        padding: const EdgeInsets.only(top: RasqSpacing.sm),
        child: OutlinedButton.icon(key: const ValueKey('rai.models.open'), onPressed: () => showRaiModelsFow(ref), icon: const Icon(Icons.tune, size: 18), label: const Text('モデルを選ぶ(ローカル / クラウド)')),
      ),
      const SizedBox(height: RasqSpacing.xs),
      Text('フォールアップ先(サーバー側 / クラウドの大きいモデル)は未接続です。端末内モデルが使えないときは失敗表示になります。', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
    ]);
  }
}
