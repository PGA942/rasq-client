import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../app/router.dart';
import '../../shell/headers.dart';
import 'rai_layout.dart';
import 'rai_mascot_3d.dart';
import 'rai_motion.dart';
import 'rai_overlay.dart';
import 'rai_providers.dart';
import 'rai_stats.dart';
import 'rai_widgets.dart';

/// スタンバイの枠 (D-199): 自分のグローバル矩形を [raiStandbySlotProvider] に報告する。3D では枠だけ、2D では薄い RAi。
class _StandbySlot extends ConsumerStatefulWidget {
  const _StandbySlot({required this.size});
  final double size;
  @override
  ConsumerState<_StandbySlot> createState() => _StandbySlotState();
}

class _StandbySlotState extends ConsumerState<_StandbySlot> {
  /// dispose では ref を使えないので通知先を持っておく。
  late final RaiStandbySlot _slot = ref.read(raiStandbySlotProvider.notifier);

  void _report() {
    if (!mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    // 報告元付き (D-214): 別の枠の後始末で消されない。
    if (ref.read(raiStandbySlotProvider) != rect) _slot.set(rect, owner: this);
  }

  @override
  void initState() {
    super.initState();
    _slot; // 早めに解決しておく
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
  }

  @override
  void dispose() {
    final n = _slot;
    WidgetsBinding.instance.addPostFrameCallback((_) => n.set(null, owner: this));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
    final three = ref.watch(raiMascot3dProvider);
    return SizedBox(
      key: const ValueKey('rai.home.mascot'),
      width: widget.size,
      height: widget.size * 1.25,
      child: three ? null : RaiMascot(size: widget.size, opacity: 0.35),
    );
  }
}

/// RAi ホーム (D-179、ワイヤーフレーム p.4): マスコット + 「マクロとか、お任せください！」+
/// 直近の質問。開くと RAi バー(アシスタントモード)が出る。
///
/// サイドバー (D-214): ヘッダーの ← の右の RAi アイコンで開く。開いている間は入力タイルが消え、
/// 「新しい会話」/ 会話の履歴 / アチーブメント / マクロ(ダミー)が出る。
class RaiHomeScreen extends ConsumerStatefulWidget {
  const RaiHomeScreen({super.key});
  @override
  ConsumerState<RaiHomeScreen> createState() => _RaiHomeScreenState();
}

class _RaiHomeScreenState extends ConsumerState<RaiHomeScreen> {
  late final RaiController _rai = ref.read(raiProvider.notifier);

  @override
  void initState() {
    super.initState();
    _rai; // dispose では ref を使えないので先に解決しておく
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showRai(ref, mode: RaiMode.assistant);
    });
  }

  @override
  void dispose() {
    // 画面を離れたらサイドバーは閉じる(バーを隠したままにしない)。
    final n = _rai;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        n.toggleSidebar(open: false);
      } catch (_) {}
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = ref.watch(raiProvider);
    final screen = MediaQuery.sizeOf(context);
    final sidebarWidth = math.min(320.0, screen.width * 0.85);
    return Scaffold(
      appBar: RasqPageHeader(
        title: 'RAi',
        onBack: () => Navigator.of(context).maybePop(),
        // サイドバーのボタン (D-214): ← の右に RAi のアイコン。
        leading: Semantics(
          button: true,
          label: 'RAi サイドバー',
          toggled: s.sidebarOpen,
          child: InkResponse(
            key: const ValueKey('rai.sidebar.toggle'),
            radius: 22,
            onTap: () => _rai.toggleSidebar(),
            child: SizedBox(
              width: RasqSizes.minTap,
              height: RasqSizes.minTap,
              child: Center(
                child: Container(
                  width: 30,
                  height: 30,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(color: s.sidebarOpen ? RasqColors.accent.withValues(alpha: 0.25) : scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
                  child: Image.asset('assets/images/rai_icon.png', semanticLabel: 'RAi'),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Stack(children: [
        // 大画面はコラム形式 (D-185): 入力ウィジェットと同じ幅の列を中央に。
        Center(
          child: SizedBox(
            width: raiPanelWidth(context) + RasqSpacing.page * 2,
            child: LayoutBuilder(builder: (context, c) {
              // スタンバイ (D-192): 大きな RAi を薄く敷き、その上に「マクロとか、お任せください！」。
              final standby = raiApproachSize.clamp(raiPointSize, math.max(raiPointSize, math.min(c.maxWidth * 0.95, screen.height * 0.55))).toDouble();
              return Stack(children: [
                // 3D (D-199): 描くのは RAi 層の 1 つの空間(ここは枠だけ報告)。2D(テスト)は従来の薄い表示。
                Positioned(top: RasqSpacing.md, left: 0, right: 0, child: IgnorePointer(child: Center(child: _StandbySlot(size: standby)))),
                ListView(padding: EdgeInsets.fromLTRB(RasqSpacing.page, standby * 0.9, RasqSpacing.page, 240), children: [
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
                        onTap: () {
                          showRai(ref, mode: RaiMode.instruction);
                          _rai.ask(h);
                        },
                      ),
                  ],
                ]),
              ]);
            }),
          ),
        ),
        // サイドバー (D-214): 左からスライド。外側のタップで閉じる。
        if (s.sidebarOpen)
          Positioned.fill(
            child: GestureDetector(
              key: const ValueKey('rai.sidebar.scrim'),
              behavior: HitTestBehavior.opaque,
              onTap: () => _rai.toggleSidebar(open: false),
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.25)),
            ),
          ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          left: s.sidebarOpen ? 0 : -sidebarWidth - 8,
          top: 0,
          bottom: 0,
          width: sidebarWidth,
          child: RaiSidebar(open: s.sidebarOpen),
        ),
      ]),
    );
  }
}

/// RAi サイドバー (D-214 → D-215): 新しい会話 / 会話の履歴 / アチーブメント(ページへ)/ マクロ(第二期、遷移しない)。
class RaiSidebar extends ConsumerWidget {
  const RaiSidebar({super.key, required this.open});
  final bool open;

  static String _when(DateTime d) => '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final s = ref.watch(raiProvider);
    final n = ref.read(raiProvider.notifier);
    final conversations = ref.watch(raiConversationsProvider);
    final stats = ref.watch(raiStatsProvider);
    final progress = raiAchievementProgress(stats);
    final unlocked = progress.where((p) => p.unlocked).length;
    return ExcludeSemantics(
      excluding: !open,
      child: Material(
        key: const ValueKey('rai.sidebar'),
        color: scheme.surface,
        elevation: 6, // FOW(8)と区別(テストが elevation 8 で FOW を探す)
        child: SafeArea(
          child: ListView(padding: const EdgeInsets.only(bottom: RasqSpacing.xl), children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.xs, 0),
              child: Row(children: [
                const RaiIcon(size: 28),
                const SizedBox(width: RasqSpacing.xs),
                Expanded(child: Text('RAi', style: RasqTypography.title)),
                RasqIconButton(key: const ValueKey('rai.sidebar.close'), icon: Icons.close, size: 20, tooltip: '閉じる', onPressed: () => n.toggleSidebar(open: false)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
              child: FilledButton.icon(
                key: const ValueKey('rai.sidebar.new'),
                onPressed: n.newConversation,
                icon: const Icon(Icons.add_comment_outlined, size: 18),
                label: const Text('新しい会話'),
              ),
            ),
            const RasqSectionHeader(title: '会話の履歴'),
            if (s.log.isNotEmpty)
              RasqListTile(
                key: const ValueKey('rai.sidebar.conv.current'),
                title: s.log.last.query ?? s.log.last.text,
                subtitle: 'いまの会話 · ${s.log.length} 件',
                leading: Icon(Icons.chat_bubble, size: 20, color: RasqColors.accent),
                chevron: false,
                onTap: () {
                  n.toggleHistory(open: true);
                  n.toggleSidebar(open: false);
                },
              ),
            for (final c in conversations)
              if (c.id != s.conversationId)
                RasqListTile(
                  key: ValueKey('rai.sidebar.conv.${c.id}'),
                  title: c.title,
                  subtitle: '${_when(c.startedAt)} · ${c.log.length} 件',
                  leading: Icon(Icons.chat_bubble_outline, size: 20, color: scheme.onSurfaceVariant),
                  trailing: RasqIconButton(key: ValueKey('rai.sidebar.conv.delete.${c.id}'), icon: Icons.delete_outline, size: 18, tooltip: '削除', onPressed: () => ref.read(raiConversationsProvider.notifier).remove(c.id)),
                  chevron: false,
                  onTap: () => n.openConversation(c),
                ),
            if (s.log.isEmpty && conversations.where((c) => c.id != s.conversationId).isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.xs),
                child: Text('まだありません。質問すると、ここに会話が残ります。', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
              ),
            const RasqSectionHeader(title: 'その他'),
            // アチーブメントはページ (D-215)。マクロはまだ遷移しない(第二期)。
            RasqListTile(
              key: const ValueKey('rai.sidebar.achievements'),
              title: 'アチーブメント',
              subtitle: '$unlocked / ${progress.length} 達成',
              leading: Icon(Icons.emoji_events_outlined, size: 20, color: unlocked > 0 ? RasqColors.yellow : scheme.onSurfaceVariant),
              onTap: () {
                n.toggleSidebar(open: false);
                GoRouter.of(context).push(Routes.raiAchievements);
              },
            ),
            RasqListTile(
              key: const ValueKey('rai.sidebar.macros'),
              title: 'マクロ',
              subtitle: '第二期(まだ開けません)',
              leading: Icon(Icons.auto_awesome_outlined, size: 20, color: scheme.onSurfaceVariant),
              chevron: false,
              enabled: false,
            ),
          ]),
        ),
      ),
    );
  }
}
