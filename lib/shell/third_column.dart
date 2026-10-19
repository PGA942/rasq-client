import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../app/providers.dart';
import '../app/router.dart';
import '../features/compose/composer_sheet.dart' show composerFowId;
import '../features/child_safe/child_safe_providers.dart' show childGateProvider;
import '../features/child_safe/child_safe_screens.dart' show ChildSafeBlockedView;
import '../features/notifications/notifications_screen.dart';
import '../features/plugins/slot_plugins.dart' show rootMessengerKeyProvider;
import '../features/search/search_screen.dart';
import '../features/settings/settings_dsl.dart';
import '../l10n/l10n.dart';
import 'pane_swipe_back.dart';

/// 第3カラム (M5b/D-056/D-057): タブレット幅(≥840dp)の右カラム。
///
/// **ペインモデル (D-057)** — previous(第2カラム)/current(第3カラム)の
/// 交互モデル。カラム幅は変動する:
/// - 第2カラムからページを開く → 第2カラムの表示はそのまま**検索ホーム幅
///   (狭)**に縮み、新しいページが第3カラム(広)に出る
/// - 第3カラムからページを開く → 第3カラムに居たページが**第2カラム(狭)へ
///   移動**(router へ push)し、新しいページが第3カラムに出る
/// - 第3カラムが空のとき: 検索(既定。KV `thirdColumn.v1` の `empty` で変更可)
///   を**検索ホーム幅**で表示し、第2カラムが広がる
///
/// M5c 以降、FOW の「掴んで第3カラムへ移動」の移動先にもなる。
class ThirdColumnEntry {
  const ThirdColumnEntry({required this.id, required this.title, required this.builder, this.location, this.extra, this.previous});
  final String id;
  final String title;
  final WidgetBuilder builder;

  /// ページ系 entry のルート(第2カラムへ移すとき router へ push する
  /// タブ配下 location)。null = 補助面(FOW 移動など、第2カラムへは移らない)。
  final String? location;
  final Object? extra;

  /// この entry を開いたときに第2カラムへ移したページ (D-058)。あるときは
  /// ヘッダーが ✕ ではなく **<(戻る)** になり、< で取り戻して完結する。
  /// 連続で開くと previous がチェーンする。
  final ThirdColumnEntry? previous;

  ThirdColumnEntry withPrevious(ThirdColumnEntry? prev) => ThirdColumnEntry(id: id, title: title, builder: builder, location: location, extra: extra, previous: prev);
}

class ThirdColumnStore extends Notifier<ThirdColumnEntry?> {
  @override
  ThirdColumnEntry? build() => null;

  void open(ThirdColumnEntry entry) => state = entry;

  void close([String? id]) {
    if (id == null || state?.id == id) state = null;
  }
}

final thirdColumnProvider = NotifierProvider<ThirdColumnStore, ThirdColumnEntry?>(ThirdColumnStore.new);

/// 検索ホーム幅 = 狭いカラム(小型カラム)の既定の幅。設定「カラムの幅」 (D-320) で変えられる(`splitColumns`)。
const double kSearchHomeColumnWidth = 320;

/// 第3カラムの中身に被せる印。ページの open がどのカラム発かを判定する。
class PaneScope extends InheritedWidget {
  const PaneScope({super.key, required this.entry, required super.child});

  /// 第3カラムに表示中の entry(検索フィラーのときは null)。
  final ThirdColumnEntry? entry;

  static PaneScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<PaneScope>();

  @override
  bool updateShouldNotify(PaneScope oldWidget) => oldWidget.entry?.id != entry?.id;
}

/// 第3カラムに開くページ [location] を、ルーターと同じ関所 ([ChildGate.routeBlockReason]) に通す
/// (セキュリティ確認 2026-10-09 の [15]: 第3カラムはルーターを通らない)。止めていれば案内を出して true。
bool _paneBlocked(ProviderContainer container, String location) {
  final blocked = container.read(childGateProvider).routeBlockReason(Uri.parse(location).path);
  if (blocked == null) return false;
  container.read(rootMessengerKeyProvider).currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(blocked)));
  return true;
}

/// タブレットのページオープン規則 (D-057)。処理したら true(呼び出し側は
/// router push しない)。モバイル幅・タブ外ページでは false。
/// 見守りで止めている画面は開かずに案内だけ出す(true。ルーターの関所と同じ、[_paneBlocked])。
bool openPageInPanes(
  BuildContext context, {
  required String id,
  required String title,
  required String location,
  Object? extra,
  required WidgetBuilder builder,
}) {
  if (MediaQuery.sizeOf(context).width < 840) return false;
  final container = ProviderScope.containerOf(context, listen: false);
  if (_paneBlocked(container, location)) return true;
  final store = container.read(thirdColumnProvider.notifier);
  final current = container.read(thirdColumnProvider);
  final scope = PaneScope.maybeOf(context);
  var entry = ThirdColumnEntry(id: id, title: title, location: location, extra: extra, builder: builder);

  if (scope != null && scope.entry?.location != null) {
    // 第3カラムのページから開いた: 居たページを第2カラム(router)へ移す。
    // < で取り戻せるよう previous としてチェーンする (D-058)。
    GoRouter.of(context).push(scope.entry!.location!, extra: scope.entry!.extra);
    entry = entry.withPrevious(scope.entry);
  } else if (current?.location != null && scope == null) {
    // 第2カラムから開き、第3カラムの旧ページは移らず破棄される →
    // そのページに張り付いていた常駐コンポーザーも閉じる。
    container.read(overlayManagerProvider).close(composerFowId);
  }
  store.open(entry);
  return true;
}

/// [entry] から辿れる previous のチェーン(近い順)。< 長押しの
/// 「どこまで戻るか」ドロップダウンに使う。
List<ThirdColumnEntry> paneBackChain(ThirdColumnEntry entry) => [
      for (var p = entry.previous; p != null; p = p.previous) p,
    ];

/// < の戻り処理 (D-058/D-059): [target] まで戻る(null = 全部戻して閉じる =
/// 検索へ)。途中で第2カラムへ移していたページの router 複製は、最深マッチが
/// 一致する間だけ pop する(第2カラム側の < で先に戻られていたら触らない)。
/// ページ自身のヘッダーの < ボタン([RasqPageHeader])から呼ばれる。
void paneBackTo(BuildContext context, ThirdColumnEntry current, {ThirdColumnEntry? target}) {
  final container = ProviderScope.containerOf(context, listen: false);
  final router = container.read(routerProvider);
  var p = current.previous;
  while (p != null) {
    final loc = p.location;
    if (loc != null) {
      // push は uri に反映されないため、最深マッチで判定する。
      final top = router.routerDelegate.currentConfiguration.last.matchedLocation;
      if (top == loc.split('?').first && router.canPop()) router.pop();
    }
    if (identical(p, target)) break;
    p = p.previous;
  }
  if (target != null) {
    container.read(thirdColumnProvider.notifier).open(target);
  } else {
    // 全部戻して閉じる: ページ常駐コンポーザーも一緒に閉じる。
    container.read(overlayManagerProvider).close(composerFowId);
    container.read(thirdColumnProvider.notifier).close();
  }
}

/// 独自の戻るボタンを持つページ(トレンドTL など)の戻り (D-320)。第3カラムのページなら [paneBackTo] で 1 つ前へ
/// (previous が無ければ閉じて検索へ)戻して true。第3カラムの外なら false(呼び出し側が router / Navigator で戻る)。
///
/// 第3カラムのページは Navigator のルートではないので、`Navigator.maybePop` では戻れない(サイドの検索欄から
/// 開いた検索結果が大型のまま閉じられなかった)。[RasqPageHeader] の < と同じ戻り方にそろえる。
bool paneBack(BuildContext context) {
  final entry = context.getInheritedWidgetOfExactType<PaneScope>()?.entry;
  if (entry == null || entry.location == null) return false;
  paneBackTo(context, entry, target: entry.previous);
  return true;
}

/// FOW を開くときの初期カラム (D-062): 第3カラムのページ内から開かれた
/// FOW は第3カラム側にドックする。
///
/// 第3カラムが空のときの検索 / 通知(entry = null)の中から開いたものも第3カラム (D-481)。以前は entry の有無で見ていて、
/// 検索 / 通知に並ぶ投稿のリノート / 引用 / リアクション / 共有などの FOW が第2カラムに出ていた。
/// [takeoverColumnOf](カラムを置き換えて開く画面)と同じ判定。
int fowColumnOf(BuildContext context) => PaneScope.maybeOf(context) != null ? 1 : 0;

/// 第3カラム内での**置き換え**遷移 (D-061: replaceTrend 等)。現在の entry を
/// 第2カラムへ移さず、previous を引き継いだまま差し替える。処理したら true。
bool replacePageInPane(
  BuildContext context, {
  required String id,
  required String title,
  required String location,
  Object? extra,
  required WidgetBuilder builder,
}) {
  final scope = PaneScope.maybeOf(context);
  if (scope?.entry == null) return false;
  final container = ProviderScope.containerOf(context, listen: false);
  if (_paneBlocked(container, location)) return true;
  container.read(thirdColumnProvider.notifier).open(
        ThirdColumnEntry(id: id, title: title, location: location, extra: extra, builder: builder, previous: scope!.entry!.previous),
      );
  return true;
}

/// 第3カラムが空のときに出すもの (D-056 / D-397)。KV `thirdColumn.v1` の `empty`。
List<(String, String)> thirdColumnEmptyChoicesOf(AppLocalizations l) => [('search', l.shellColumnThirdEmptySearch), ('notifications', l.shellColumnThirdEmptyNotifications), ('none', l.shellColumnThirdEmptyNone)];

/// 第3カラムの設定ボタン (D-397): 空のときに何を出すか(検索 / 通知 / 表示しない)を選ぶ。
/// 検索なら検索欄の横、通知なら通知ヘッダーの右端(以前の押せない ↑ の場所)、表示しないなら右上に置く。
class ThirdColumnSettingsButton extends ConsumerWidget {
  const ThirdColumnSettingsButton({super.key, this.size = 18});
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final empty = settingValue(ref, 'thirdColumn', 'empty', 'search') as String? ?? 'search';
    return RasqIconButton(
      key: const ValueKey('thirdColumn.settings'),
      icon: Icons.settings,
      size: size,
      tooltip: context.l10n.shellColumnThirdSettingsTooltip,
      onPressed: () async {
        final box = context.findRenderObject() as RenderBox;
        final anchor = box.localToGlobal(Offset.zero) & box.size;
        final manager = ref.read(overlayManagerProvider);
        final picked = await manager.showDropdown<String>(id: 'thirdColumn.empty', anchor: anchor, dense: true, items: [
          for (final (v, label) in thirdColumnEmptyChoicesOf(context.l10n)) RasqDropdownItem(label, v, checked: v == empty),
        ]);
        if (picked != null) await ref.read(settingsAreaProvider('thirdColumn').notifier).set('empty', picked);
      },
    );
  }
}

/// 第3カラムの中身。empty 設定は設定 DSL と同じ KV 規約(`thirdColumn.v1`)。
class ThirdColumnView extends ConsumerWidget {
  const ThirdColumnView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final entry = ref.watch(thirdColumnProvider);
    // チャイルドセーフ (D-307): 検索 / 通知を止めていれば出さない。開いたあとに止めたページも([15]、ルーターと同じ関所)。
    final gate = ref.watch(childGateProvider);
    final pageBlocked = entry?.location == null ? null : gate.routeBlockReason(Uri.parse(entry!.location!).path);
    if (entry != null && pageBlocked == null) {
      // ページ entry (D-059): カラム専用ヘッダーは出さず全面表示 — 戻りは
      // ページ自身のヘッダーの < に統合される(RasqPageHeader が PaneScope を
      // 見て paneBackTo を呼ぶ。長押しで「どこまで戻るか」)。
      if (entry.location != null) {
        // スワイプで戻る (D-350): 競合する部品(隠れた TL など)が無い位置からの右スワイプは、< と同じ戻り。
        return PaneScope(
          entry: entry,
          child: Builder(builder: (ctx) => PaneSwipeBack(key: ValueKey('pane.swipe.${entry.id}'), onBack: () => paneBack(ctx), child: Builder(builder: entry.builder))),
        );
      }
      // 補助面(FOW 移動など)はタイトル + ✕ のカラムヘッダーを持つ。
      return PaneScope(
        entry: entry,
        child: Column(children: [
          SizedBox(
            height: 40,
            child: Row(children: [
              const SizedBox(width: RasqSpacing.md),
              Expanded(child: Text(entry.title, style: RasqTypography.body.copyWith(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
              RasqIconButton(icon: Icons.close, size: 20, tooltip: context.l10n.shellColumnThirdCloseTooltip, onPressed: () => ref.read(thirdColumnProvider.notifier).close()),
              const SizedBox(width: 4),
            ]),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          Expanded(child: Builder(builder: entry.builder)),
        ]),
      );
    }
    if (entry != null) {
      // 止めているページ ([15]): 中身は作らず、案内と ✕ だけ。
      return PaneScope(
        entry: null,
        child: Column(children: [
          SizedBox(
            height: 40,
            child: Row(children: [
              const Spacer(),
              RasqIconButton(key: const ValueKey('thirdColumn.blocked.close'), icon: Icons.close, size: 20, tooltip: context.l10n.shellColumnThirdCloseTooltip, onPressed: () => ref.read(thirdColumnProvider.notifier).close()),
              const SizedBox(width: 4),
            ]),
          ),
          Expanded(child: ChildSafeBlockedView(message: pageBlocked!)),
        ]),
      );
    }

    final empty = settingValue(ref, 'thirdColumn', 'empty', 'search') as String? ?? 'search';
    // RASQ アカウント / SNS アカウントを切り替えたら、検索 / 通知を作り直す (D-397): 入力中の語やタブの位置も含めて、
    // 前のアカウントのものを残さない(左カラムと同じアカウントで開く)。
    final accountKey = '${ref.watch(currentRasqAccountProvider)?.id}|${ref.watch(currentAccountProvider)?.key}|${ref.watch(bundleViewProvider)}';
    final blocked = switch (empty) {
      'search' => gate.routeBlockReason('/search'),
      'notifications' => gate.routeBlockReason('/notifications'),
      _ => null,
    };
    // アカウントのアイコンは出さない (D-411、左カラムのヘッダーにある)。
    // 設定ボタン (D-397): 検索は検索欄の横、通知は通知ヘッダーの右端。表示しない / 止められているときは右上に置く。
    Widget withCornerButton(Widget body) => Column(children: [
          const SizedBox(height: 32, child: Row(children: [Spacer(), ThirdColumnSettingsButton(), SizedBox(width: 4)])),
          Expanded(child: body),
        ]);
    return PaneScope(
      entry: null,
      child: KeyedSubtree(
        key: ValueKey('thirdColumn.empty.$empty.$accountKey'),
        child: switch (empty) {
          _ when blocked != null => withCornerButton(ChildSafeBlockedView(message: blocked)),
          'none' => withCornerButton(RasqEmptyView(title: context.l10n.shellColumnThirdEmptyTitle, hint: rasqDetail(context, context.l10n.shellColumnThirdEmptyHint, context.l10n.shellColumnThirdEmptyHintDetail))),
          'notifications' => const NotificationsScreen(headerTrailing: ThirdColumnSettingsButton(size: 20)),
          _ => const SearchScreen(inThirdColumn: true, showAccountIcon: false, searchTrailing: ThirdColumnSettingsButton()),
        },
      ),
    );
  }
}
