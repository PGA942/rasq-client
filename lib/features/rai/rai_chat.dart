import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:url_launcher/url_launcher.dart';

import 'rai_providers.dart';
import 'rai_reference.dart';
import 'rai_reference_providers.dart';
import 'rai_widgets.dart';

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
              Expanded(child: Text('案内を一時停止中(${s.suspended!.stepIndex + 1} / ${s.suspended!.steps.length} 手順目)。前の画面に戻ると続きます。', style: RasqTypography.bodySmall)),
              TextButton(key: const ValueKey('rai.chat.resume'), onPressed: () => Navigator.of(context).maybePop(), child: const Text('続きへ')),
            ]),
          );
    if (log.isEmpty && !live) {
      return ListView(key: const ValueKey('rai.chat.empty'), padding: EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xl, RasqSpacing.page, bottomPadding), children: [
        ?suspended,
        Text('マクロとか、お任せください！', textAlign: TextAlign.center, style: RasqTypography.title),
        const SizedBox(height: RasqSpacing.xs),
        Text('インストラクション: 操作を聞くと RAi がボタンまで移動して指差します。\nアシスタント: 端末内モデルで答えます。モデルはバーのチップから選べます(マクロは第二期)。', textAlign: TextAlign.center, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
        if (s.history.isNotEmpty) ...[
          const RasqSectionHeader(title: '最近の質問', topMargin: RasqSpacing.xl),
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
        rows.add(_UserRow(key: ValueKey('rai.chat.user.$i'), text: u.query!));
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
        rowIndex: i,
      ));
    }
    if (live) {
      if (s.query != null && s.query != lastQuery) rows.add(_UserRow(key: const ValueKey('rai.chat.user.live'), text: s.query!));
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

class _UserRow extends StatelessWidget {
  const _UserRow({super.key, required this.text});
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
  const _RaiRow({super.key, required this.text, required this.at, required this.error, required this.latest, required this.links, required this.choices, required this.rowIndex, this.streaming = false, this.proposal, this.proposalSteps = 0});
  final String text;
  final DateTime? at;
  final bool error;
  final bool latest;
  final bool streaming;
  final List<Uri> links;
  final RaiOperation? proposal;
  final int proposalSteps;
  final List<({String id, String index})> choices;
  final int rowIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final n = ref.read(raiProvider.notifier);
    final op = proposal;
    final thinking = streaming && (text == '…' || text.trim().isEmpty);
    return Padding(
      padding: const EdgeInsets.only(bottom: RasqSpacing.sm, right: 32),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.only(top: 2), child: RaiIcon(size: 28)),
        const SizedBox(width: RasqSpacing.xs),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.md, vertical: RasqSpacing.sm),
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(RasqSizes.radiusLg),
                border: Border.all(color: error ? RasqColors.danger : scheme.outlineVariant),
              ),
              child: thinking
                  ? const _ThinkingDots()
                  : Text(text, style: RasqTypography.body.copyWith(color: error ? RasqColors.danger : scheme.onSurface)),
            ),
            if (at != null) Padding(padding: const EdgeInsets.only(top: 2, left: 4), child: Text(RasqTimestamp.format(at!), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant))),
            // 行の下のタイル (D-218)。
            for (final (k, u) in links.indexed) RaiLinkCard(key: ValueKey('rai.chat.link.$rowIndex.$k'), url: u),
            if (op != null) _ProposalTile(op: op, steps: proposalSteps, onGuide: () => n.guide(op.id)),
            if (choices.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: RasqSpacing.xs),
                child: Wrap(spacing: RasqSpacing.xs, runSpacing: RasqSpacing.xs, children: [
                  for (final c in choices)
                    ActionChip(key: ValueKey('rai.chat.choice.${c.id}'), label: Text(c.index, style: RasqTypography.bodySmall), onPressed: latest ? () => n.pick(c.id) : null),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}

/// 提案の操作タイル: 見出し + 手順数 + 「この手順で案内」。
class _ProposalTile extends StatelessWidget {
  const _ProposalTile({required this.op, required this.steps, required this.onGuide});
  final RaiOperation op;
  final int steps;
  final VoidCallback onGuide;
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
      child: Row(children: [
        const Icon(Icons.route_outlined, size: 20),
        const SizedBox(width: RasqSpacing.xs),
        Expanded(child: Text('$title · $steps 手順', style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w600))),
        FilledButton(key: ValueKey('rai.chat.guide.$id'), onPressed: onGuide, style: FilledButton.styleFrom(minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 12)), child: const Text('この手順で案内')),
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
class _ThinkingDots extends StatelessWidget {
  const _ThinkingDots();
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
