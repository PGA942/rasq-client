import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:url_launcher/url_launcher.dart';

import 'rai_automation.dart';
import '../../app/providers.dart';
import '../nodeprog/inline_node_graph.dart';
import 'rai_providers.dart';
import 'rai_rich_text.dart';
import 'rai_trace_graph.dart';
import 'rai_llm.dart' show raiSettingsArea;
import '../settings/settings_dsl.dart';
import 'rai_reference.dart';
import 'rai_reference_providers.dart';
import 'rai_widgets.dart';
import '../../l10n/l10n.dart';

/// RAi ホームのチャット (D-218): 発言の履歴を AI チャットボットの形式で並べる。背景は RAi(層側で描く)。
///
/// - 行 = 質問(右、`rai.chat.user.<i>`)と RAi の返事(左、`rai.chat.msg.<i>`、`i` は古い順)。
/// - 生成中 / 記録前の返事は末尾に `rai.chat.live`(考え中は点滅の「…」)。
/// - **URL サムネイル / タイルは出てきた行の下**: リンクカード(`rai.chat.link.<i>.<k>`)、提案タイル
///   (`rai.chat.guide.<opId>` → その手順で案内)、選択肢のチップ(`rai.chat.choice.<id>`、最新の行だけ押せる)。
/// - 空のときは「マクロとか、お任せください！」と最近の質問。
class RaiChatList extends ConsumerWidget {
  const RaiChatList({super.key, this.bottomPadding = 240});
  final double bottomPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final s = ref.watch(raiProvider);
    final n = ref.read(raiProvider.notifier);
    // 索引は監視しない (D-218): 埋め込みの切り替えで索引が組み直る間、FakeAsync では読み込みが終わらず pumpAndSettle が止まらない。
    final index = ref.read(raiReferenceProvider).value;
    final log = s.log.reversed.toList(); // 古い順
    final live = s.bubble != null && (s.busy || log.isEmpty || log.last.text != s.bubble);
    // 一時停止した案内 (D-220): 戻ると続く。
    final suspended = s.suspended == null
        ? null
        : Container(
            key: const ValueKey('rai.chat.suspended'),
            margin: const EdgeInsets.only(bottom: RasqSpacing.sm),
            padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.md, vertical: RasqSpacing.sm),
            decoration: BoxDecoration(color: RasqColors.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(RasqSizes.radiusMd), border: Border.all(color: RasqColors.accent.withValues(alpha: 0.5))),
            child: Row(children: [
              const Icon(Icons.pause_circle_outline, size: 20),
              const SizedBox(width: RasqSpacing.xs),
              Expanded(child: Text(context.l10n.raiChatSuspended(s.suspended!.stepIndex + 1, s.suspended!.steps.length), style: RasqTypography.bodySmall)),
              TextButton(key: const ValueKey('rai.chat.resume'), onPressed: () => Navigator.of(context).maybePop(), child: Text(context.l10n.raiChatResume)),
            ]),
          );
    if (log.isEmpty && !live) {
      return ListView(key: const ValueKey('rai.chat.empty'), padding: EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xl, RasqSpacing.page, bottomPadding), children: [
        ?suspended,
        Text(context.l10n.raiChatHeadline, textAlign: TextAlign.center, style: RasqTypography.title),
        const SizedBox(height: RasqSpacing.xs),
        Text(
            rasqDetail(context, context.l10n.raiChatIntro, context.l10n.raiChatIntroDetail),
            textAlign: TextAlign.center,
            style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
        if (s.history.isNotEmpty) ...[
          RasqSectionHeader(title: context.l10n.raiChatRecent, topMargin: RasqSpacing.xl),
          for (final h in s.history)
            RasqListTile(
              title: h,
              leading: Icon(Icons.history, size: 20, color: scheme.onSurfaceVariant),
              chevron: false,
              onTap: () => n.ask(h),
            ),
        ],
      ]);
    }
    final rows = <Widget>[];
    String? lastQuery;
    for (var i = 0; i < log.length; i++) {
      final u = log[i];
      if (u.query != null && u.query != lastQuery) {
        lastQuery = u.query;
        rows.add(RaiChatUserRow(key: ValueKey('rai.chat.user.$i'), text: u.query!));
      }
      // 案内の手順 (D-232): 連続する同じ操作の手順は 1 つの角丸タイルに(丸数字 + 交互の背景)。
      if (u.step != null) {
        final group = <RaiUtterance>[u];
        while (i + 1 < log.length && log[i + 1].step == (group.last.step ?? 0) + 1 && log[i + 1].opId == u.opId && (log[i + 1].query == null || log[i + 1].query == lastQuery)) {
          i++;
          group.add(log[i]);
        }
        rows.add(_InstructionTile(key: ValueKey('rai.chat.steps.${i - group.length + 1}'), title: u.opId == null ? null : index?.operation(u.opId!)?.index, steps: group));
        continue;
      }
      rows.add(_RaiRow(
        key: ValueKey('rai.chat.msg.$i'),
        text: u.text,
        at: u.at,
        error: u.error,
        latest: i == log.length - 1 && !live,
        links: u.links,
        proposal: u.proposal == null ? null : index?.operation(u.proposal!),
        proposalSteps: u.proposal == null || index == null ? 0 : (index.operation(u.proposal!) == null ? 0 : index.expand(index.operation(u.proposal!)!).length),
        choices: u.choices,
        candidates: [for (final id in u.candidates) if (index?.operation(id) != null) (index!.operation(id)!, index.expand(index.operation(id)!).length)],
        approval: u.approval,
        trace: u.trace,
        graphScope: u.graphScope,
        rowIndex: i,
      ));
    }
    if (live) {
      if (s.query != null && s.query != lastQuery) rows.add(RaiChatUserRow(key: const ValueKey('rai.chat.user.live'), text: s.query!));
      rows.add(_RaiRow(key: const ValueKey('rai.chat.live'), text: s.bubble!, at: null, error: s.error, latest: true, streaming: s.busy, links: const [], choices: s.busy ? const [] : s.choices, rowIndex: -1));
    }
    if (suspended != null) rows.add(suspended);
    // 新しいものが下(reverse で下端に寄せる)。
    return ListView(
      key: const ValueKey('rai.chat.list'),
      reverse: true,
      padding: EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.md, RasqSpacing.page, bottomPadding),
      children: rows.reversed.toList(),
    );
  }
}

/// 質問の行(右寄せの吹き出し)。RAi ホームのチャットとオンボーディングの「RAi に聞く」(D-427)で同じもの。
class RaiChatUserRow extends StatelessWidget {
  const RaiChatUserRow({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: RasqSpacing.sm, left: 48),
        padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.md, vertical: RasqSpacing.sm),
        decoration: BoxDecoration(color: RasqColors.accent.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(RasqSizes.radiusLg)),
        child: Text(text, style: RasqTypography.body.copyWith(color: scheme.onSurface)),
      ),
    );
  }
}

class _RaiRow extends ConsumerWidget {
  const _RaiRow({super.key, required this.text, required this.at, required this.error, required this.latest, required this.links, required this.choices, required this.rowIndex, this.streaming = false, this.proposal, this.proposalSteps = 0, this.candidates = const [], this.approval, this.trace = const [], this.graphScope});
  final String text;

  /// 承認待ちの自動化の操作 id (D-226)。
  final String? approval;

  /// 自動化の工程 (D-229)。
  final List<RaiAutoStep> trace;

  /// インラインのノード表示のスコープ (D-234)。
  final String? graphScope;
  final DateTime? at;
  final bool error;
  final bool latest;
  final bool streaming;
  final List<Uri> links;
  final RaiOperation? proposal;
  final int proposalSteps;
  final List<({String id, String index})> choices;
  final int rowIndex;

  /// 候補の操作(タイル)と手順数 (D-222)。最新の行だけ × で外せる。
  final List<(RaiOperation, int)> candidates;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.read(raiProvider.notifier);
    final op = proposal;
    final thinking = streaming && (text == '…' || text.trim().isEmpty);
    return RaiReplyRow(text: text, at: at, error: error, thinking: thinking, richKey: ValueKey('rai.chat.rich.$rowIndex'), below: [
      // 行の下のタイル (D-218)。
      for (final (k, u) in links.indexed) RaiLinkCard(key: ValueKey('rai.chat.link.$rowIndex.$k'), url: u),
      if (op != null) _ProposalTile(op: op, steps: proposalSteps, onGuide: () => n.guide(op.id), onSkip: () => n.skip(op.id)),
      // 承認タイル (D-226): 「スキップ」の説明の下。最新の行だけ押せる。
      if (approval != null) _ApprovalTile(opId: approval!, enabled: latest, onApprove: () => n.approve(approval!), onDecline: () => n.decline(approval!)),
      // 工程タイル (D-229): 自動化の各手順の状態(関数で済 / 畳んだ / 案内へ / 失敗)。視覚的なデバッグ用。
      if (trace.isNotEmpty) _TraceTile(key: ValueKey('rai.chat.trace.$rowIndex'), steps: trace),
      // インラインのノード表示 (D-234): 自動化が書いたグラフを 80% で。拡大で全画面のエディタへ。
      if (graphScope != null)
        Padding(
          padding: const EdgeInsets.only(top: RasqSpacing.xs),
          child: InlineNodeGraph(key: ValueKey('rai.chat.graph.$rowIndex'), scope: graphScope!, accountKey: ref.read(currentAccountProvider)?.key),
        ),
      // 候補 (D-222): 返事の下に並べ、右の × で「これじゃない」→ 除外して答え直す。
      if (candidates.isNotEmpty)
        Row(key: ValueKey('rai.chat.candidates.$rowIndex'), crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final (c, steps) in candidates) _ProposalTile(key: ValueKey('rai.chat.candidate.${c.id}'), op: c, steps: steps, onGuide: () => n.guide(c.id), onSkip: () => n.skip(c.id)),
            ]),
          ),
          if (latest)
            Padding(
              padding: const EdgeInsets.only(top: RasqSpacing.xs),
              child: RasqIconButton(key: ValueKey('rai.chat.reject.$rowIndex'), icon: Icons.close, size: 18, tooltip: context.l10n.raiChatRejectCandidates, onPressed: () => n.rejectCandidates([for (final (c, _) in candidates) c.id])),
            ),
        ]),
      if (choices.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: RasqSpacing.xs),
          child: Wrap(spacing: RasqSpacing.xs, runSpacing: RasqSpacing.xs, children: [
            for (final c in choices)
              ActionChip(key: ValueKey('rai.chat.choice.${c.id}'), label: Text(c.index, style: RasqTypography.bodySmall), onPressed: latest ? () => n.pick(c.id) : null),
          ]),
        ),
    ]);
  }
}

/// RAi の返事の行(左に RAi のアイコン、枠なしのリッチテキスト、時刻、その下にタイル)。RAi ホームのチャットと
/// オンボーディングの「RAi に聞く」(D-427)で同じもの。[thinking] なら「…」、[error] なら赤の文字。
class RaiReplyRow extends StatelessWidget {
  const RaiReplyRow({super.key, required this.text, this.at, this.error = false, this.thinking = false, this.richKey, this.below = const []});
  final String text;
  final DateTime? at;
  final bool error;
  final bool thinking;
  final Key? richKey;

  /// 行の下に並べるもの(リンク / 提案 / 候補のタイルなど)。
  final List<Widget> below;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: RasqSpacing.sm, right: 32),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.only(top: 2), child: RaiIcon(size: 28)),
        const SizedBox(width: RasqSpacing.xs),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // 返事は枠なしのリッチテキスト (D-232)。失敗は赤の文字、生成中はドット。
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.xs, vertical: RasqSpacing.xs),
              child: thinking
                  ? const RaiThinkingDots()
                  : error
                      ? Text(text, style: RasqTypography.body.copyWith(color: RasqColors.danger))
                      : RaiRichText(text, key: richKey),
            ),
            if (at != null) Padding(padding: const EdgeInsets.only(top: 2, left: 4), child: Text(RasqTimestamp.format(at!), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant))),
            ...below,
          ]),
        ),
      ]),
    );
  }
}

/// 提案の操作タイル: 見出し + 手順数 + 「スキップ」(D-226: 案内を出さずに RAi がやる)+ 「この手順で案内」。
class _ProposalTile extends StatelessWidget {
  const _ProposalTile({super.key, required this.op, required this.steps, required this.onGuide, required this.onSkip});
  final RaiOperation op;
  final int steps;
  final VoidCallback onGuide;
  final VoidCallback onSkip;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = op.index;
    final id = op.id;
    return Container(
      key: ValueKey('rai.chat.proposal.$id'),
      margin: const EdgeInsets.only(top: RasqSpacing.xs),
      padding: const EdgeInsets.all(RasqSpacing.sm),
      decoration: BoxDecoration(color: scheme.surfaceContainerHighest.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(RasqSizes.radiusMd)),
      // 見出しの行とボタンの行 (D-226: 「スキップ」が増えて 1 行に収まらない幅がある)。
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.route_outlined, size: 20),
          const SizedBox(width: RasqSpacing.xs),
          Expanded(child: Text(context.l10n.raiChatProposalTitle(title, steps), style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w600))),
        ]),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton(key: ValueKey('rai.chat.skip.$id'), onPressed: onSkip, style: TextButton.styleFrom(minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 8)), child: Text(context.l10n.raiChatSkip)),
          const SizedBox(width: RasqSpacing.xs),
          FilledButton(key: ValueKey('rai.chat.guide.$id'), onPressed: onGuide, style: FilledButton.styleFrom(minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 12)), child: Text(context.l10n.raiChatGuide)),
        ]),
      ]),
    );
  }
}

/// インストラクション履歴のタイル (D-232): 角丸の枠の中に、手順ごとに丸数字 + 文(背景はグレー / 白の交互)。
class _InstructionTile extends StatelessWidget {
  const _InstructionTile({super.key, required this.title, required this.steps});
  final String? title;
  final List<RaiUtterance> steps;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: RasqSpacing.sm, right: 32),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.only(top: 2), child: RaiIcon(size: 28)),
        const SizedBox(width: RasqSpacing.xs),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: scheme.surface.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(RasqSizes.radiusLg), border: Border.all(color: scheme.outlineVariant)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(RasqSpacing.md, RasqSpacing.xs, RasqSpacing.md, 2),
                    child: Text(context.l10n.raiChatGuideTitle(title!), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                  ),
                for (final (k, u) in steps.indexed)
                  Container(
                    key: ValueKey('rai.chat.step.${u.step}'),
                    color: k.isEven ? scheme.surfaceContainerHighest.withValues(alpha: 0.55) : Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.md, vertical: 6),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(width: 22, child: Text(raiCircled(u.step ?? k + 1), style: RasqTypography.body.copyWith(color: RasqColors.link, fontWeight: FontWeight.w600))),
                      Expanded(child: Text(u.text, style: RasqTypography.body.copyWith(color: scheme.onSurface))),
                    ]),
                  ),
              ]),
            ),
            Padding(padding: const EdgeInsets.only(top: 2, left: 4), child: Text(RasqTimestamp.format(steps.last.at), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant))),
          ]),
        ),
      ]),
    );
  }
}

/// 工程タイル (D-229): 手順ごとの状態を 1 行ずつ。✓ = 関数で済、⤵ = 畳んだ(関数で代替 / 説明だけ)、
/// 👉 = 案内へ、✗ = 失敗、? = 選択待ち。
class _TraceTile extends ConsumerStatefulWidget {
  const _TraceTile({super.key, required this.steps});
  final List<RaiAutoStep> steps;
  @override
  ConsumerState<_TraceTile> createState() => _TraceTileState();
}

class _TraceTileState extends ConsumerState<_TraceTile> {
  /// 工程グラフ (D-236): 3 手順以上で自動表示(設定 `rai.traceGraphAuto`、既定 on)。それ未満 / off なら
  /// 「グラフビューで表示」ボタン。
  bool? _showGraph;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final steps = widget.steps;
    final auto = (ref.watch(settingsAreaProvider(raiSettingsArea)).value ?? const <String, Object?>{})['traceGraphAuto'] != false;
    final showGraph = _showGraph ?? (auto && steps.length >= 3);
    return Container(
      margin: const EdgeInsets.only(top: RasqSpacing.xs),
      padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.sm, vertical: RasqSpacing.xs),
      decoration: BoxDecoration(color: scheme.surfaceContainerHighest.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(RasqSizes.radiusMd)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(context.l10n.raiChatTrace, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
        for (final s in steps)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(
                switch (s.status) {
                  RaiAutoStatus.done => Icons.check_circle_outline,
                  RaiAutoStatus.skipped => Icons.subdirectory_arrow_right,
                  RaiAutoStatus.guide => Icons.touch_app_outlined,
                  RaiAutoStatus.failed => Icons.error_outline,
                  RaiAutoStatus.asking => Icons.help_outline,
                  _ => Icons.radio_button_unchecked,
                },
                size: 16,
                color: switch (s.status) { RaiAutoStatus.done => RasqColors.link, RaiAutoStatus.failed => RasqColors.danger, _ => scheme.onSurfaceVariant },
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${s.index + 1}. ${s.text}${s.binding == null ? '' : ' → ${s.binding!.call}'}${s.detail.isEmpty ? '' : '(${s.detail})'}',
                  style: RasqTypography.caption.copyWith(color: s.status == RaiAutoStatus.skipped ? scheme.onSurfaceVariant : scheme.onSurface),
                ),
              ),
            ]),
          ),
        // 工程グラフ (D-236)。
        if (showGraph)
          Padding(padding: const EdgeInsets.only(top: RasqSpacing.xs), child: RaiTraceGraph(key: const ValueKey('rai.chat.tracegraph'), trace: steps))
        else
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const ValueKey('rai.chat.tracegraph.show'),
              onPressed: () => setState(() => _showGraph = true),
              style: TextButton.styleFrom(minimumSize: const Size(0, 28), padding: const EdgeInsets.symmetric(horizontal: 8), visualDensity: VisualDensity.compact),
              icon: const Icon(Icons.account_tree_outlined, size: 16),
              label: Text(context.l10n.raiChatShowGraph, style: RasqTypography.caption),
            ),
          ),
      ]),
    );
  }
}

/// 承認タイル (D-226): 「スキップ」の説明の下。「実行する」で RAi が手順を自動で進める、「やめる」で何もしない。
class _ApprovalTile extends StatelessWidget {
  const _ApprovalTile({required this.opId, required this.enabled, required this.onApprove, required this.onDecline});
  final String opId;
  final bool enabled;
  final VoidCallback onApprove;
  final VoidCallback onDecline;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: ValueKey('rai.chat.approval.$opId'),
      margin: const EdgeInsets.only(top: RasqSpacing.xs),
      padding: const EdgeInsets.all(RasqSpacing.sm),
      decoration: BoxDecoration(color: RasqColors.link.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(RasqSizes.radiusMd), border: Border.all(color: RasqColors.link.withValues(alpha: 0.5))),
      child: Row(children: [
        const Icon(Icons.auto_awesome, size: 20),
        const SizedBox(width: RasqSpacing.xs),
        Expanded(child: Text(opId.startsWith(raiHeldCallsPrefix) ? context.l10n.raiChatApproveHeld : context.l10n.raiChatApprove, style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w600, color: scheme.onSurface))),
        TextButton(key: ValueKey('rai.chat.decline.$opId'), onPressed: enabled ? onDecline : null, style: TextButton.styleFrom(minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 8)), child: Text(context.l10n.raiChatDecline)),
        FilledButton(key: ValueKey('rai.chat.approve.$opId'), onPressed: enabled ? onApprove : null, style: FilledButton.styleFrom(minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 12)), child: Text(context.l10n.raiChatRun)),
      ]),
    );
  }
}

/// リンクカード (D-218): ホスト + パス。タップで外部ブラウザ。
class RaiLinkCard extends StatelessWidget {
  const RaiLinkCard({super.key, required this.url, this.onOpen});
  final Uri url;
  final Future<void> Function(Uri)? onOpen;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: RasqSpacing.xs),
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(RasqSizes.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(RasqSizes.radiusMd),
          onTap: () => (onOpen ?? (u) => launchUrl(u, mode: LaunchMode.externalApplication))(url),
          child: Padding(
            padding: const EdgeInsets.all(RasqSpacing.sm),
            child: Row(children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: scheme.surface, borderRadius: BorderRadius.circular(8)), child: Icon(Icons.link, color: scheme.onSurfaceVariant)),
              const SizedBox(width: RasqSpacing.sm),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(url.host, style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                  Text(url.path.isEmpty ? url.toString() : url.path, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
              Icon(Icons.open_in_new, size: 18, color: scheme.onSurfaceVariant),
            ]),
          ),
        ),
      ),
    );
  }
}

/// 考え中の「…」(D-218)。アニメーションは使わない(テストの pumpAndSettle を止めない)。
/// 考え中の「…」(返事の行の中)。
class RaiThinkingDots extends StatelessWidget {
  const RaiThinkingDots({super.key});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (final a in const [1.0, 0.6, 0.3])
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Container(width: 6, height: 6, decoration: BoxDecoration(color: scheme.onSurfaceVariant.withValues(alpha: a), shape: BoxShape.circle)),
        ),
    ]);
  }
}
