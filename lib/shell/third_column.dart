import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../app/providers.dart';
import '../app/router.dart';
import '../features/compose/composer_sheet.dart' show composerFowId;
import '../features/search/search_screen.dart';
import '../features/settings/settings_dsl.dart';

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

/// 検索ホーム幅 = 狭いカラムの幅。
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

/// タブレットのページオープン規則 (D-057)。処理したら true(呼び出し側は
/// router push しない)。モバイル幅・タブ外ページでは false。
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

/// [entry] から辿れる previous のチェーン(近い順)。
List<ThirdColumnEntry> _chainOf(ThirdColumnEntry entry) => [
      for (var p = entry.previous; p != null; p = p.previous) p,
    ];

/// < の戻り処理 (D-058): [target] まで戻る(null = 全部戻して閉じる = 検索へ)。
/// 途中で第2カラムへ移していたページの router 複製は、最深マッチが一致する
/// 間だけ pop する(第2カラム側の < で先に戻られていたら触らない)。
void _backTo(WidgetRef ref, ThirdColumnEntry current, {ThirdColumnEntry? target}) {
  final router = ref.read(routerProvider);
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
    ref.read(thirdColumnProvider.notifier).open(target);
  } else {
    // 全部戻して閉じる: ページ常駐コンポーザーも一緒に閉じる。
    ref.read(overlayManagerProvider).close(composerFowId);
    ref.read(thirdColumnProvider.notifier).close();
  }
}

/// 第3カラムの中身。empty 設定は設定 DSL と同じ KV 規約(`thirdColumn.v1`)。
class ThirdColumnView extends ConsumerWidget {
  const ThirdColumnView({super.key});

  static const _emptyChoices = <(String, String)>[('search', '検索'), ('none', '表示しない')];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final entry = ref.watch(thirdColumnProvider);
    if (entry != null) {
      return PaneScope(
        entry: entry,
        child: Column(children: [
          SizedBox(
            height: 40,
            child: Row(children: [
              // ページ entry (D-058): ✕ は出さず、小画面モードと同じく <(戻る)
              // で完結する。previous が無ければ「戻る」= 閉じて検索へ。
              // **長押し**で「どこまで戻るか」のドロップダウン。
              if (entry.location != null)
                Builder(builder: (ctx) {
                  return RasqActionButton.icon(
                    icon: Icons.arrow_back,
                    tooltip: '戻る(長押しで一覧)',
                    onTap: () => _backTo(ref, entry, target: entry.previous),
                    onLongPress: () async {
                      final box = ctx.findRenderObject() as RenderBox;
                      final anchor = box.localToGlobal(Offset.zero) & box.size;
                      final manager = ref.read(overlayManagerProvider);
                      final picked = await manager.showDropdown<(ThirdColumnEntry?,)>(id: 'thirdColumn.back', anchor: anchor, dense: true, items: [
                        for (final p in _chainOf(entry)) RasqDropdownItem(p.title, (p,)),
                        const RasqDropdownItem('閉じる', (null,)),
                      ]);
                      if (picked != null) _backTo(ref, entry, target: picked.$1);
                    },
                  );
                })
              else
                const SizedBox(width: RasqSpacing.md),
              Expanded(child: Text(entry.title, style: RasqTypography.body.copyWith(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
              // 補助面(FOW 移動など)だけ ✕ を持つ。ページは < で完結。
              if (entry.location == null)
                RasqIconButton(icon: Icons.close, size: 20, tooltip: '閉じる', onPressed: () => ref.read(thirdColumnProvider.notifier).close()),
              const SizedBox(width: 4),
            ]),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          Expanded(child: Builder(builder: entry.builder)),
        ]),
      );
    }

    final empty = settingValue(ref, 'thirdColumn', 'empty', 'search') as String? ?? 'search';
    return PaneScope(
      entry: null,
      child: Column(children: [
        SizedBox(
          height: 32,
          child: Row(children: [
            const Spacer(),
            Builder(builder: (ctx) {
              return RasqIconButton(
                icon: Icons.settings,
                size: 18,
                tooltip: '第3カラムの設定',
                onPressed: () async {
                  final box = ctx.findRenderObject() as RenderBox;
                  final anchor = box.localToGlobal(Offset.zero) & box.size;
                  final manager = ref.read(overlayManagerProvider);
                  final picked = await manager.showDropdown<String>(id: 'thirdColumn.empty', anchor: anchor, dense: true, items: [
                    for (final (v, label) in _emptyChoices) RasqDropdownItem(label, v, checked: v == empty),
                  ]);
                  if (picked != null) await ref.read(settingsAreaProvider('thirdColumn').notifier).set('empty', picked);
                },
              );
            }),
            const SizedBox(width: 4),
          ]),
        ),
        Expanded(
          child: switch (empty) {
            'none' => const RasqEmptyView(title: '第3カラム', hint: 'FOW をここへ移動できます(M5c)'),
            _ => const SearchScreen(),
          },
        ),
      ]),
    );
  }
}
