import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import 'rai_embedding_model.dart';
import 'rai_layout.dart';
import '../settings/settings_dsl.dart';
import 'rai_llm.dart';
import 'rai_widgets.dart' show raiBarContext;
import '../../l10n/l10n.dart';

/// LLM モデルの FOW (D-183): タイルに ローカル / クラウド、集計された完遂率(35B 未満だけ集計、
/// 未集計は「-%」)、端末 RAM から見た動作可否のインジケーター、状態と操作(ダウンロード / 使う /
/// 削除)。バーのモデルチップから開く。
const raiModelsFowId = 'fow.rai.models';

Future<void> showRaiModelsFow(WidgetRef ref, BuildContext context, {int? column}) async {
  final manager = ref.read(overlayManagerProvider);
  if (manager.contains(raiModelsFowId)) return;
  // 付く場所は文字入力ウィジェットの上 (D-192): バーの矩形をアンカーにして上付き。
  Rect? anchor;
  final barCtx = raiBarContext;
  final barBox = barCtx != null && barCtx.mounted ? barCtx.findRenderObject() : null;
  if (barBox is RenderBox && barBox.hasSize) {
    final tl = barBox.localToGlobal(Offset.zero);
    anchor = tl & barBox.size;
  }
  await manager.showFow<void>(
    id: raiModelsFowId,
    // 幅は入力ウィジェットに揃える (D-185)。
    spec: FowSpec(title: appL10n.raiModelsTitle, cancelText: appL10n.raiModelsClose, initialHeightFactor: 0.7, maxHeightFactor: 0.92, columnIndex: column ?? 0, maxWidth: raiPanelWidth(context))
      ..anchor = anchor
      ..anchorBelow = raiAnchorBelow(anchor),
    builder: (_, _) => const RaiModelsBody(),
  );
}

class RaiModelsBody extends ConsumerWidget {
  const RaiModelsBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final llm = ref.watch(raiLlmProvider);
    final st = ref.watch(raiLlmStatusProvider).value ?? llm.current;
    final ram = ref.watch(deviceRamProvider).value;
    final manager = ref.read(overlayManagerProvider);
    Future<void> guard(Future<void> Function() f) async {
      try {
        await f();
      } on RaiLlmException catch (e) {
        if (context.mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(e.message)));
      }
    }

    final ramText = ram?.totalMb == null ? context.l10n.raiModelsRamUnknown : 'RAM: ${(ram!.totalMb! / 1024).toStringAsFixed(1)} GB${ram.availableMb == null ? '' : context.l10n.raiModelsRamFree((ram.availableMb! / 1024).toStringAsFixed(1))}';
    return ListView(padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.xl), children: [
      RasqCaption(context.l10n.raiModelsCaption(llm.spec.codename, ramText), detail: context.l10n.raiModelsCaptionDetail(llm.spec.codename, llm.spec.label, ramText), padding: EdgeInsets.zero),
      RasqSectionHeader(title: context.l10n.raiModelsSectionLocal, topMargin: RasqSpacing.sm),
      // 選択中を先頭に(操作ボタンがすぐ見える)。
      for (final m in [...raiModelSpecs.where((m) => m.id == llm.spec.id), ...raiModelSpecs.where((m) => m.id != llm.spec.id)]) _tile(context, ref, m, llm: llm, st: st, ram: ram, guard: guard, manager: manager),
      RasqSectionHeader(title: context.l10n.raiModelsSectionEmbedding, topMargin: RasqSpacing.md),
      _EmbeddingTile(ram: ram),
      // 投稿の画像 (D-390): 文の塔と同じ空間。関連 TL / TL のアルゴリズムで、画像も本文と一緒に比べる。
      _EmbeddingTile(ram: ram, model: postVisionModelProvider, status: postVisionStatusProvider, tag: 'postVision', readyNote: context.l10n.raiModelsPostVisionReady, idleNote: context.l10n.raiModelsPostVisionIdle),
      // 絵文字の画像検索 (D-293): 文と絵を同じ空間で比べるので、SigLIP2 の 2 つが揃って初めて効く。
      if (ref.watch(emojiVisionModelProvider) is! UnavailableRaiEmbeddingModel) RasqSectionHeader(title: context.l10n.raiModelsSectionEmoji, topMargin: RasqSpacing.md),
      _EmbeddingTile(ram: ram, model: emojiTextModelProvider, status: emojiTextStatusProvider, tag: 'emojiText', readyNote: context.l10n.raiModelsEmojiTextReady, idleNote: context.l10n.raiModelsEmojiTextIdle),
      _EmbeddingTile(ram: ram, model: emojiVisionModelProvider, status: emojiVisionStatusProvider, tag: 'emojiVision', readyNote: context.l10n.raiModelsEmojiVisionReady, idleNote: context.l10n.raiModelsEmojiVisionIdle),
      RasqSectionHeader(title: context.l10n.raiModelsSectionCloud, topMargin: RasqSpacing.md),
      const _ServerTile(),
      for (final m in raiCloudModelSpecs) _tile(context, ref, m, llm: llm, st: st, ram: ram, guard: guard, manager: manager),
      const SizedBox(height: RasqSpacing.sm),
      RasqCaption(context.l10n.raiModelsCompletionCaption, detail: context.l10n.raiModelsCompletionCaptionDetail, padding: EdgeInsets.zero),
    ]);
  }

  Widget _tile(BuildContext context, WidgetRef ref, RaiModelSpec m, {required RaiLlm llm, required RaiLlmStatus st, required ({int? totalMb, int? availableMb})? ram, required Future<void> Function(Future<void> Function()) guard, required OverlayManager manager}) {
    final scheme = Theme.of(context).colorScheme;
    final selected = m.local && m.id == llm.spec.id;
    final mine = selected ? st : null;
    final verdict = m.cloud ? RaiRamVerdict.ok : raiMemoryVerdict(modelMb: m.sizeMb, totalRamMb: ram?.totalMb);
    final verdictColor = switch (verdict) { RaiRamVerdict.ok => RasqColors.inVc, RaiRamVerdict.tight => RasqColors.warning, RaiRamVerdict.no => RasqColors.danger, RaiRamVerdict.unknown => scheme.onSurfaceVariant };
    final rate = m.params >= 35 ? context.l10n.raiModelsRateExcluded : (m.completionRate == null ? '-%' : '${(m.completionRate! * 100).round()}%');
    final phase = m.cloud
        ? context.l10n.raiModelsNotConnected
        : mine == null
            ? ''
            : switch (mine.phase) {
                RaiLlmPhase.notInstalled => context.l10n.raiModelsPhaseNotInstalled,
                RaiLlmPhase.downloading => context.l10n.raiModelsPhaseDownloading(mine.progress ?? 0),
                RaiLlmPhase.ready => context.l10n.raiModelsPhaseReady,
                RaiLlmPhase.loading => mine.message ?? context.l10n.raiModelsPhaseLoading,
                RaiLlmPhase.generating => context.l10n.raiModelsPhaseGenerating,
                RaiLlmPhase.unavailable => context.l10n.raiModelsPhaseUnavailable,
              };
    return Container(
      key: ValueKey('rai.model.tile.${m.id}'),
      margin: const EdgeInsets.only(bottom: RasqSpacing.sm),
      padding: const EdgeInsets.all(RasqSpacing.md),
      decoration: BoxDecoration(
        color: selected ? scheme.primaryContainer.withValues(alpha: 0.35) : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(RasqSizes.radiusMd),
        border: Border.all(color: selected ? RasqColors.link : scheme.outlineVariant, width: selected ? 1.5 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          RasqPill(label: m.cloud ? context.l10n.raiModelsPillCloud : context.l10n.raiModelsPillLocal, color: m.cloud ? scheme.surfaceContainerHighest : RasqColors.link, textColor: m.cloud ? scheme.onSurface : Colors.white),
          const SizedBox(width: RasqSpacing.sm),
          Expanded(child: Text(m.codename, key: ValueKey('rai.model.name.${m.id}'), style: RasqTypography.listTile, overflow: TextOverflow.ellipsis)),
          if (selected) const Icon(Icons.check_circle, size: 18, color: RasqColors.link),
        ]),
        const SizedBox(height: RasqSpacing.xs),
        Text(m.cloud ? context.l10n.raiModelsCloudLine(m.label, m.params.toStringAsFixed(0)) : '${m.label} · ${m.engine.label} · ${m.fileName} · ${m.sizeMb} MB', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant), overflow: TextOverflow.ellipsis),
        const SizedBox(height: RasqSpacing.xs),
        Row(children: [
          // 完遂率。
          Icon(Icons.task_alt, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 3),
          Text(context.l10n.raiModelsCompletionRate(rate), style: RasqTypography.caption),
          const SizedBox(width: RasqSpacing.md),
          // メモリの判定インジケーター。
          Container(width: 10, height: 10, decoration: BoxDecoration(color: verdictColor, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(m.cloud ? context.l10n.raiModelsMemoryNotNeeded : context.l10n.raiModelsMemory(verdict.label), key: ValueKey('rai.model.ram.${m.id}'), style: RasqTypography.caption),
          const Spacer(),
          if (phase.isNotEmpty) Text(phase, key: ValueKey('rai.model.phase.${m.id}'), style: RasqTypography.caption.copyWith(color: m.cloud ? RasqColors.danger : scheme.onSurfaceVariant)),
        ]),
        if (mine?.phase == RaiLlmPhase.downloading) Padding(padding: const EdgeInsets.only(top: RasqSpacing.xs), child: LinearProgressIndicator(value: (mine!.progress ?? 0) / 100)),
        if (mine?.message != null && mine!.phase != RaiLlmPhase.loading) Padding(padding: const EdgeInsets.only(top: RasqSpacing.xs), child: Text(mine.message!, style: RasqTypography.caption.copyWith(color: RasqColors.danger), maxLines: 3, overflow: TextOverflow.ellipsis)),
        if (m.local)
          Padding(
            padding: const EdgeInsets.only(top: RasqSpacing.sm),
            child: Wrap(spacing: RasqSpacing.sm, runSpacing: RasqSpacing.xs, children: [
              if (!selected)
                OutlinedButton(key: ValueKey('rai.model.use.${m.id}'), onPressed: st.phase == RaiLlmPhase.downloading ? null : () => guard(() => llm.select(m)), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 12)), child: Text(context.l10n.raiModelsUse)),
              if (selected && (mine!.phase == RaiLlmPhase.notInstalled || mine.phase == RaiLlmPhase.unavailable))
                // 同梱 (D-216) なら「展開」、無ければ HF から「ダウンロード」。
                FilledButton.icon(key: const ValueKey('rai.model.download'), onPressed: verdict == RaiRamVerdict.no ? null : () => guard(llm.install), icon: Icon(mine.bundled ? Icons.unarchive_outlined : Icons.download, size: 16), label: Text(mine.bundled ? context.l10n.raiModelsExtract : context.l10n.raiModelsDownload), style: FilledButton.styleFrom(minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 12))),
              if (selected && (mine!.ready || mine.phase == RaiLlmPhase.loading))
                OutlinedButton.icon(key: const ValueKey('rai.model.release'), onPressed: () => guard(llm.release), icon: const Icon(Icons.memory, size: 16), label: Text(context.l10n.raiModelsRelease), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 12))),
              if (selected && mine!.ready)
                OutlinedButton.icon(
                  key: const ValueKey('rai.model.delete'),
                  onPressed: () async {
                    final ok = await manager.showAlert(id: 'rai.model.delete', title: context.l10n.raiModelsDeleteTitle, message: context.l10n.raiModelsDeleteMessage(m.fileName), confirmText: context.l10n.raiModelsDelete, cancelText: context.l10n.raiModelsCancel, destructive: true, ownerId: raiModelsFowId);
                    if (ok) await guard(llm.uninstall);
                  },
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: Text(context.l10n.raiModelsDelete),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 12)),
                ),
            ]),
          ),
      ]),
    );
  }
}

/// リファレンス検索の埋め込みモデル (D-190): SigLIP2 のテキスト塔。未ダウンロードなら n-gram 代替で検索する。
class _EmbeddingTile extends ConsumerWidget {
  const _EmbeddingTile({required this.ram, this.model, this.status, this.tag = 'embed', this.readyNote, this.idleNote});
  final ({int? totalMb, int? availableMb})? ram;

  /// どのモデルのタイルか(既定 = RAi の検索の埋め込み)。
  final Provider<RaiEmbeddingModel>? model;
  final StreamProvider<RaiEmbeddingStatus>? status;
  final String tag;
  final String? readyNote;
  final String? idleNote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final model = ref.watch(this.model ?? raiEmbeddingModelProvider);
    // 端末実行の無い環境では、絵文字の画像検索のタイルは出さない(D-293)。
    if (this.model != null && model is UnavailableRaiEmbeddingModel) return const SizedBox.shrink();
    final st = ref.watch(status ?? raiEmbeddingStatusProvider).value ?? model.current;
    final spec = model.spec;
    final verdict = raiMemoryVerdict(modelMb: spec.sizeMb, totalRamMb: ram?.totalMb);
    Future<void> guard(Future<void> Function() f) async {
      try {
        await f();
      } on RaiEmbeddingException catch (e) {
        if (context.mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(e.message)));
      }
    }

    return Container(
      key: ValueKey('rai.$tag.tile'),
      margin: const EdgeInsets.only(bottom: RasqSpacing.sm),
      padding: const EdgeInsets.all(RasqSpacing.md),
      decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(RasqSizes.radiusMd), border: Border.all(color: st.ready ? RasqColors.link : scheme.outlineVariant, width: st.ready ? 2 : 1)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          RasqPill(label: context.l10n.raiModelsPillLocal, color: RasqColors.link, textColor: Colors.white),
          const SizedBox(width: RasqSpacing.sm),
          Expanded(child: Text(spec.displayLabel, style: RasqTypography.body.copyWith(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: RasqSpacing.xs),
        Text(context.l10n.raiModelsEmbeddingLine(spec.fileName, spec.sizeMb, spec.dims), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant), overflow: TextOverflow.ellipsis),
        const SizedBox(height: RasqSpacing.xs),
        Row(children: [
          Text(context.l10n.raiModelsMemory(verdict.label), style: RasqTypography.caption),
          const SizedBox(width: RasqSpacing.md),
          Text(st.label, key: ValueKey('rai.$tag.phase'), style: RasqTypography.caption.copyWith(color: st.phase == RaiEmbeddingPhase.error ? RasqColors.danger : scheme.onSurfaceVariant)),
        ]),
        if (st.phase == RaiEmbeddingPhase.downloading) Padding(padding: const EdgeInsets.only(top: RasqSpacing.xs), child: LinearProgressIndicator(value: (st.progress ?? 0) / 100)),
        const SizedBox(height: RasqSpacing.xs),
        if (readyNote != null)
          Text(st.ready ? readyNote! : (idleNote ?? ''), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant))
        else
          Text(st.ready ? rasqDetail(context, context.l10n.raiModelsSearchSemantic, context.l10n.raiModelsSearchSemanticDetail(spec.displayLabel)) : rasqDetail(context, context.l10n.raiModelsSearchNgram, context.l10n.raiModelsSearchNgramDetail), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: RasqSpacing.sm),
        Wrap(spacing: RasqSpacing.sm, runSpacing: RasqSpacing.xs, children: [
          if (st.phase == RaiEmbeddingPhase.notInstalled || st.phase == RaiEmbeddingPhase.error)
            FilledButton.icon(key: ValueKey('rai.$tag.download'), onPressed: verdict == RaiRamVerdict.no ? null : () => guard(model.install), icon: const Icon(Icons.download, size: 16), label: Text(context.l10n.raiModelsDownload), style: FilledButton.styleFrom(minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 12))),
          // 同梱のモデル (D-522) は消せない(消せるのはダウンロードしたものだけ)。
          if (!st.bundled && (st.ready || st.phase == RaiEmbeddingPhase.loading))
            OutlinedButton.icon(key: ValueKey('rai.$tag.delete'), onPressed: () => guard(model.uninstall), icon: const Icon(Icons.delete_outline, size: 16), label: Text(context.l10n.raiModelsDelete), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 12))),
        ]),
      ]),
    );
  }
}

/// ローカル推論サーバー (D-216): OpenAI 互換の URL(…/v1)とモデル名。端末内モデルが失敗 / 無応答のとき、
/// 質問と近かったリファレンスを添えて渡す。設定エリア `rai`。
class _ServerTile extends ConsumerStatefulWidget {
  const _ServerTile();
  @override
  ConsumerState<_ServerTile> createState() => _ServerTileState();
}

class _ServerTileState extends ConsumerState<_ServerTile> {
  final _url = TextEditingController();
  final _model = TextEditingController();
  bool _seeded = false;

  @override
  void dispose() {
    _url.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final v = ref.watch(settingsAreaProvider(raiSettingsArea)).value ?? const <String, Object?>{};
    if (!_seeded) {
      _seeded = true;
      _url.text = '${v['serverUrl'] ?? ''}';
      _model.text = '${v['serverModel'] ?? ''}';
    }
    final store = ref.read(settingsAreaProvider(raiSettingsArea).notifier);
    final configured = _url.text.trim().isNotEmpty;
    return Container(
      key: const ValueKey('rai.server.tile'),
      margin: const EdgeInsets.only(bottom: RasqSpacing.sm),
      padding: const EdgeInsets.all(RasqSpacing.md),
      decoration: BoxDecoration(color: scheme.surfaceContainerHighest.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(RasqSizes.radiusMd)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(context.l10n.raiModelsServerTitle, style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w600))),
          RasqPill(label: configured ? context.l10n.raiModelsServerConfigured : context.l10n.raiModelsServerNotConfigured, color: configured ? RasqColors.link : scheme.surfaceContainerHighest, textColor: configured ? Colors.white : scheme.onSurface),
        ]),
        const SizedBox(height: RasqSpacing.xs),
        RasqCaption(context.l10n.raiModelsServerCaption, detail: context.l10n.raiModelsServerCaptionDetail, padding: EdgeInsets.zero),
        const SizedBox(height: RasqSpacing.sm),
        RasqInput(key: const ValueKey('rai.server.url'), controller: _url, hintText: 'http://127.0.0.1:8000/v1', onChanged: (s) => setState(() => store.set('serverUrl', s.trim()))),
        const SizedBox(height: RasqSpacing.xs),
        RasqInput(key: const ValueKey('rai.server.model'), controller: _model, hintText: context.l10n.raiModelsServerModelHint, onChanged: (s) => store.set('serverModel', s.trim())),
      ]),
    );
  }
}
