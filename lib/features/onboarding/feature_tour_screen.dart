import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart' show SnsKind;

import '../../app/router.dart';
import '../child_safe/child_gate.dart';
import '../child_safe/child_safe_providers.dart' show childGateProvider;
import '../rai/rai_widgets.dart' show RaiIcon;
import '../trend/tendency_fows.dart' show openTendencyFow;
import '../trend/tendency_profile.dart';
import 'feature_tour.dart';

/// RASQ の機能の紹介 (D-471): 見出し + 1〜2 文 + 小さな絵(アプリの部品で描く。外の画像は使わない)のページを 5〜7 枚。
///
/// - 初めて見る人には「スキップ」を出さない(「次へ」で進み、「戻る」はできる)。見たことがある人([canSkip])と、
///   設定 / RAi から開いた人([again])には「スキップ」。
/// - 「トレンドと Today」のページから、刺激性の既定(恐れ / 嫌悪 / 怒り 45%、D-470)の設定([openTendencyFow])を開ける。
///   閉じるとツアーの同じページに戻る。
/// - 見守り中 (D-307) は、使えない機能のページを外す([featureTourPages])。
class FeatureTourScreen extends ConsumerStatefulWidget {
  const FeatureTourScreen({super.key, this.canSkip = false, this.again = false});

  final bool canSkip;
  final bool again;

  @override
  ConsumerState<FeatureTourScreen> createState() => _FeatureTourScreenState();
}

/// 1 ページ。
@immutable
class FeatureTourPage {
  const FeatureTourPage({required this.id, required this.title, required this.body, this.note, required this.picture});

  /// 絵の種類と、テストの印(`tour.page.<id>`)。
  final String id;
  final String title;
  final String body;

  /// 小さく添える一言(任意)。
  final String? note;

  /// 絵の説明(読み上げ)。
  final String picture;
}

/// 見せるページ。見守り中は、使えない機能のページを外し、刺激性のページに一言足す。
List<FeatureTourPage> featureTourPages(ChildGate gate) {
  final supervised = gate.supervised;
  return [
    const FeatureTourPage(
      id: 'sns',
      title: 'いくつもの SNS を、ひとつの場所で',
      body: 'Misskey・Mastodon・Bluesky などのアカウントを、まとめて使えます。RASQ アカウントがあれば、設定やアカウントのまとまりを、ほかの端末でも使えます。',
      picture: 'Bluesky・Misskey・mixi2・Mastodon が RASQ にまとまる絵',
    ),
    const FeatureTourPage(
      id: 'timeline',
      title: 'タイムラインは、ノードで組み立てる',
      body: 'ホームの TL は、ノードを並べて自分好みに組み立てられます。トレンドや Today も、ノードとして TL に置けます。',
      note: 'TL の歯車から変えられます。',
      picture: '「SNS タイムライン」「トレンドを取得」「Today」のノードが縦に並んだ絵',
    ),
    if (gate.featureAllowed('trend'))
      FeatureTourPage(
        id: 'trend',
        title: 'トレンドと Today',
        body: 'いま話題の言葉と投稿を、トレンドと Today で見られます。はじめは恐れ・嫌悪・怒りを 45% までに抑えているので、強い怒りや嫌悪の投稿は、おすすめ / トレンド / Today / 関連 TL で下がるか、出なくなります。',
        note: supervised ? 'この上限はいつでも変えられます。見守り中は、保護者の設定でさらに抑えます。' : 'この上限はいつでも変えられます。',
        picture: '刺激性のレーダー',
      ),
    if (gate.featureAllowed('astell.join'))
      const FeatureTourPage(
        id: 'astell',
        title: 'ASTell で、声でつながる',
        body: 'ASTell は、声で話せるルームです。聞くだけの参加もでき、下の ASTell のタブから入れます。',
        picture: 'ASTell のアンテナと、話している印の波形',
      ),
    // Swing は見守り中は出していない(swing_providers.dart)。
    if (!supervised)
      const FeatureTourPage(
        id: 'swing',
        title: 'Swing で、気軽に流す',
        body: 'Swing は、時間がたつと消える投稿です。フォロワーや RASQ リストの人に届き、1〜24 時間で消えます。',
        note: 'RASQ アカウントで使えます。',
        picture: 'Swing の丸いアイコンが並んだ絵',
      ),
    if (gate.raiEnabled)
      const FeatureTourPage(
        id: 'rai',
        title: '迷ったら RAi に',
        body: 'RAi は RASQ のアシスタントです。やりたいことを聞くと、ボタンの場所まで案内したり、代わりに操作したりします。',
        picture: 'RAi と吹き出し',
      ),
    if (gate.routeBlockReason('/store') == null)
      const FeatureTourPage(
        id: 'plugins',
        title: 'プラグインで、広げる',
        body: 'SNS も、表示も、機能も、プラグインで足せます。プラグインストアで探して入れられます。',
        picture: 'プラグインのタイルが並んだ絵',
      ),
  ];
}

class _FeatureTourScreenState extends ConsumerState<FeatureTourScreen> {
  final _controller = PageController();
  int _index = 0;
  bool _closing = false;

  bool get _skippable => widget.canSkip || widget.again;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int i) {
    setState(() => _index = i);
    if (_controller.hasClients) {
      unawaited(_controller.animateToPage(i, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic));
    }
  }

  /// 見終えた / スキップした: 印を付けて閉じる。
  Future<void> _finish() async {
    if (_closing) return;
    _closing = true;
    await ref.read(featureTourProvider.notifier).markSeen();
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = featureTourPages(ref.watch(childGateProvider));
    final index = _index.clamp(0, pages.length - 1);
    final last = index == pages.length - 1;
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      // 端末の戻る: 2 ページ目からは 1 つ戻る。最初のページで、見たことがあればスキップと同じ(初めての人は閉じない)。
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (index > 0) {
          _goTo(index - 1);
        } else if (_skippable) {
          unawaited(_finish());
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          centerTitle: false,
          title: Text('RASQ の使い方', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          actions: [
            if (_skippable) TextButton(key: const ValueKey('tour.skip'), onPressed: _finish, child: const Text('スキップ')),
            const SizedBox(width: RasqSpacing.sm),
          ],
        ),
        body: SafeArea(
          child: Column(children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => _TourPageView(page: pages[i], number: i + 1, total: pages.length),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Row(children: [
                  SizedBox(
                    width: 96,
                    child: index == 0
                        ? const SizedBox.shrink()
                        : TextButton(key: const ValueKey('tour.back'), onPressed: () => _goTo(index - 1), child: const Text('戻る')),
                  ),
                  Expanded(
                    child: Semantics(
                      label: '${index + 1} / ${pages.length} ページ',
                      excludeSemantics: true,
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        for (var i = 0; i < pages.length; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: i == index ? 18 : 7,
                            height: 7,
                            decoration: BoxDecoration(color: i == index ? scheme.primary : scheme.outlineVariant, borderRadius: BorderRadius.circular(RasqSizes.radiusPill)),
                          ),
                      ]),
                    ),
                  ),
                  SizedBox(
                    width: 112,
                    child: FilledButton(
                      key: const ValueKey('tour.next'),
                      onPressed: last ? _finish : () => _goTo(index + 1),
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(RasqSizes.minTap)),
                      child: Text(last ? 'はじめる' : '次へ'),
                    ),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// 1 ページの中身。広い画面(タブレット)は絵と文を横に、狭い画面は縦に。大きな文字でもはみ出さないよう、縦にスクロールできる。
class _TourPageView extends ConsumerWidget {
  const _TourPageView({required this.page, required this.number, required this.total});
  final FeatureTourPage page;
  final int number;
  final int total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Semantics(header: true, child: Text(page.title, key: ValueKey('tour.title.${page.id}'), style: RasqTypography.title.copyWith(fontSize: 22, height: 1.3))),
      const SizedBox(height: RasqSpacing.md),
      Text(page.body, style: RasqTypography.body.copyWith(fontSize: 16, height: 1.6)),
      if (page.note != null) ...[
        const SizedBox(height: RasqSpacing.sm),
        Text(page.note!, style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant)),
      ],
      if (page.id == 'trend') ...[
        const SizedBox(height: RasqSpacing.md),
        OutlinedButton.icon(
          key: const ValueKey('tour.openTendency'),
          // 刺激性の設定 (D-470) をツアーの上に開く。閉じると同じページに戻る。
          onPressed: () => openTendencyFow(context, ref),
          icon: const Icon(Icons.tune, size: 18),
          label: const Text('いま設定を見る'),
        ),
      ],
    ]);
    final picture = Semantics(label: page.picture, image: true, excludeSemantics: true, child: _TourPicture(id: page.id));
    return Semantics(
      key: ValueKey('tour.page.${page.id}'),
      label: '$number / $total ページ',
      container: true,
      child: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= RasqSizes.tabletBreakpoint;
        final content = wide
            ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Expanded(flex: 5, child: Center(child: picture)),
                const SizedBox(width: RasqSpacing.xxl),
                Expanded(flex: 6, child: text),
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                Center(child: picture),
                const SizedBox(height: RasqSpacing.xl),
                text,
              ]);
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: wide ? RasqSpacing.xxl * 2 : RasqSpacing.xl, vertical: RasqSpacing.xl),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: (c.maxHeight - RasqSpacing.xl * 2).clamp(0, double.infinity)),
            child: Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: wide ? 960 : 560), child: content)),
          ),
        );
      }),
    );
  }
}

/// 絵(アプリの部品で小さく描く)。
class _TourPicture extends ConsumerWidget {
  const _TourPicture({required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    Widget card(Widget child) => Container(
          width: 300,
          padding: const EdgeInsets.all(RasqSpacing.lg),
          decoration: BoxDecoration(color: scheme.surfaceContainerHighest.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(RasqSizes.radiusLg), border: Border.all(color: scheme.outlineVariant)),
          child: child,
        );
    Widget dot(SnsKind k) => Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: RasqSnsPill.colorOf(k), shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(k.label.characters.first, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
        );
    Widget node(String label, IconData icon, {bool accent = false}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.md, vertical: RasqSpacing.sm),
          decoration: BoxDecoration(
            color: accent ? scheme.primary.withValues(alpha: 0.12) : scheme.surface,
            borderRadius: BorderRadius.circular(RasqSizes.radiusMd),
            border: Border.all(color: accent ? scheme.primary : scheme.outlineVariant),
          ),
          child: Row(children: [
            Icon(icon, size: 20, color: accent ? scheme.primary : scheme.onSurfaceVariant),
            const SizedBox(width: RasqSpacing.sm),
            Expanded(child: Text(label, style: RasqTypography.listTile)),
            Icon(Icons.drag_indicator, size: 18, color: scheme.outline),
          ]),
        );
    switch (id) {
      case 'sns':
        return card(Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [for (final k in const [SnsKind.bluesky, SnsKind.misskey, SnsKind.mixi2, SnsKind.mastodon]) dot(k)]),
          const SizedBox(height: RasqSpacing.sm),
          Icon(Icons.south, color: scheme.outline),
          const SizedBox(height: RasqSpacing.sm),
          const RasqLogo(height: 40),
        ]));
      case 'timeline':
        return card(Column(mainAxisSize: MainAxisSize.min, children: [
          node('SNS タイムライン', Icons.dynamic_feed_outlined),
          Icon(Icons.add, size: 18, color: scheme.outline),
          node('トレンドを取得', Icons.trending_up, accent: true),
          Icon(Icons.add, size: 18, color: scheme.outline),
          node('Today', Icons.today_outlined, accent: true),
        ]));
      case 'trend':
        final profile = ref.watch(tendencyProfileProvider).value ?? const TendencyProfile();
        final capped = [for (final e in TendencyProfile.emotions) if (profile.stimulusCap(e) < 1.0) e];
        return card(Column(mainAxisSize: MainAxisSize.min, children: [
          RasqRadarChart(
            key: const ValueKey('tour.radar'),
            size: 200,
            axes: TendencyProfile.emotions,
            values: {for (final e in TendencyProfile.emotions) e: profile.stimulusCap(e)},
            labels: TendencyProfile.emotionLabels,
          ),
          const SizedBox(height: RasqSpacing.sm),
          // 抑えている感情(いまの設定。既定は恐れ / 嫌悪 / 怒り 45%)。
          Wrap(spacing: RasqSpacing.xs, runSpacing: RasqSpacing.xs, alignment: WrapAlignment.center, children: [
            for (final e in capped)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.sm, vertical: 2),
                decoration: BoxDecoration(color: RasqColors.danger, borderRadius: BorderRadius.circular(RasqSizes.radiusPill)),
                child: Text('${TendencyProfile.emotionLabels[e]} ${(profile.stimulusCap(e) * 100).round()}%', style: RasqTypography.bodySmall.copyWith(color: Colors.white)),
              ),
          ]),
        ]));
      case 'astell':
        return card(Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.settings_input_antenna, size: 56, color: scheme.primary),
          const SizedBox(height: RasqSpacing.md),
          Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (final h in const [10.0, 22.0, 34.0, 18.0, 28.0, 12.0, 24.0])
              Container(width: 7, height: h, margin: const EdgeInsets.symmetric(horizontal: 3), decoration: BoxDecoration(color: RasqColors.inVc, borderRadius: BorderRadius.circular(4))),
          ]),
        ]));
      case 'swing':
        return card(Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          for (final (i, c) in const [Color(0xFFFF6B3D), Color(0xFF6364FF), Color(0xFF86B300), Color(0xFF1185FE)].indexed)
            Container(
              width: 52,
              height: 52,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: i == 3 ? scheme.outlineVariant : c, width: 3)),
              child: Container(decoration: BoxDecoration(shape: BoxShape.circle, color: c.withValues(alpha: 0.25)), child: Icon(Icons.bolt, color: c)),
            ),
        ]));
      case 'rai':
        return card(Row(children: [
          const RaiIcon(size: 64),
          const SizedBox(width: RasqSpacing.md),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(RasqSpacing.sm),
              decoration: BoxDecoration(color: scheme.surface, borderRadius: BorderRadius.circular(RasqSizes.radiusMd), border: Border.all(color: scheme.outlineVariant)),
              child: Text('TL にリストを足したい', style: RasqTypography.bodySmall),
            ),
          ),
        ]));
      default:
        return card(Wrap(alignment: WrapAlignment.center, spacing: RasqSpacing.md, runSpacing: RasqSpacing.md, children: [
          for (final icon in const [Icons.extension_outlined, Icons.palette_outlined, Icons.translate, Icons.trending_up])
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(RasqSizes.radiusMd)),
              child: Icon(icon, color: scheme.primary, size: 28),
            ),
        ]));
    }
  }
}
