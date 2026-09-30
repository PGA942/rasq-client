import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import '../../app/router.dart' show routerProvider;
import '../home/timeline_search.dart';
import 'timeline_config_screen.dart';
import 'tl_components.dart' show TlConfig;
import 'tl_config_store.dart';

/// タイムライン一時変更 FOW (D-338) の id。
const timelineTempFowId = 'fow.timeline.temp';

/// 展開モードの高さ。stick の高さは入力欄の高さから決める。
const timelineTempExpandedFactor = 0.6;

const timelineTempStickKey = Key('tl.temp.stick');
const timelineTempHeaderKey = Key('tl.temp.header');

/// タイムライン一時変更 FOW (D-338 → D-341): TL のタブの `↓{タイムライン名}`(選んでいるタブをもう一度押す)で開く。
///
/// AsTell のルーム FOW と同じく、**外側をタップすると閉じずに stick へ変形**する(stick の間は後ろの TL を触れる)。
/// - stick = 検索欄と ✕ だけ(✕ で閉じる。検索欄の右端の ↑↓ でそのまま飛べる)。ハンドル / 空いたところのタップで展開
/// - 展開 = ヘッダー(キャンセル / 決定)+ 検索欄(検索画面と同じ作り + 「近似検索」チップ)+「タイムラインをカスタマイズ」
///   の使い回し([TimelineConfigScreen] の `temporary`)。キャンセル = 展開してからの構成の変更を巻き戻して**閉じる**
///   (D-384。以前は stick)、決定 = そのまま stick。構成の変更は保存せず、その TL にだけ一時的に効く(「この内容で保存」で保存した構成になる)
/// - 探す: TL は絞らない。↑↓ で上下の合う投稿へ飛び、飛んだ先を一瞬ホバーの見た目にする(続きは TL の「投稿を読み込む」)
///
/// [tabs] = FOW のタブ行に並べる TL((スコープ, 名前))、[scope] = 開いたときのタブ。[scopeSync] = ホームのタブと開いている
/// タブを揃える口(FOW を閉じると null に戻す)。もう開いていれば閉じる。閉じると探す語は消える。
Future<void> showTimelineTempFow(WidgetRef ref, {required List<(String, String)> tabs, required String scope, ValueNotifier<String?>? scopeSync}) async {
  final manager = ref.read(overlayManagerProvider);
  if (manager.contains(timelineTempFowId)) {
    manager.close(timelineTempFowId);
    return;
  }
  final search = ref.read(timelineSearchProvider.notifier);
  final sync = scopeSync ?? ValueNotifier<String?>(null);
  final spec = FowSpec(
    type: FowPanelType.widget,
    initialHeightFactor: timelineTempExpandedFactor,
    minHeightFactor: 0.06,
    maxHeightFactor: 0.9,
    dockAboveFooter: true,
    heightStops: const [0.1, timelineTempExpandedFactor],
    freeAboveStops: true,
    stickCollapse: true,
  );
  // 外側タップ → stick(閉じない)。stick の間はバリアを外して後ろの TL を触れるように(AsTell と同じ、D-143)。
  final barrierEnabled = ValueNotifier<bool>(true);
  void syncBarrier() {
    final expanded = !spec.isStick;
    if (barrierEnabled.value != expanded) {
      barrierEnabled.value = expanded;
      manager.requestRebuild();
    }
  }

  spec.heightFactor.addListener(syncBarrier);
  // 別の画面へ移ったら閉じる(返信の stick FOW と同じ作法, D-048)。ホームのタブの切り替えはページ遷移ではないので、閉じずに付いていく。
  final router = ref.read(routerProvider);
  void onNavigate() => manager.close(timelineTempFowId);
  router.routerDelegate.addListener(onNavigate);
  sync.value = scope;
  try {
    await manager.showFow<void>(
      id: timelineTempFowId,
      semanticsLabel: 'タイムラインを一時的に変える',
      spec: spec,
      barrierBehavior: OverlayBarrierBehavior.dismiss,
      onBarrierTap: () => collapseTimelineTempFow(spec),
      barrierEnabled: barrierEnabled,
      builder: (ctx, handle) => TimelineTempFowBody(spec: spec, tabs: tabs, scopeSync: sync, onClose: () => handle.close()),
    );
  } finally {
    router.routerDelegate.removeListener(onNavigate);
    spec.heightFactor.removeListener(syncBarrier);
    barrierEnabled.dispose();
    sync.value = null;
    if (scopeSync == null) sync.dispose();
    search.clearAll();
  }
}

/// stick へ畳む(最小段)。
void collapseTimelineTempFow(FowSpec spec) {
  spec.userResized = false;
  spec.heightFactor.value = spec.heightStops.first;
}

class TimelineTempFowBody extends ConsumerStatefulWidget {
  const TimelineTempFowBody({super.key, required this.spec, required this.tabs, required this.scopeSync, required this.onClose});
  final FowSpec spec;
  final List<(String, String)> tabs;
  final ValueNotifier<String?> scopeSync;
  final VoidCallback onClose;

  @override
  ConsumerState<TimelineTempFowBody> createState() => _TimelineTempFowBodyState();
}

class _TimelineTempFowBodyState extends ConsumerState<TimelineTempFowBody> {
  final _search = TextEditingController();
  final _focus = FocusNode();

  /// 検索欄の ∨ で開いたチップの列。
  bool _chipsOpen = false;

  /// 展開したときの一時変更(キャンセルの巻き戻し先)。
  late Map<String, TlConfig> _snapshot;
  late bool _stick;

  String get _scope => widget.scopeSync.value ?? widget.tabs.first.$1;
  String get _id => _scope.startsWith('tl.') ? _scope.substring(3) : _scope;

  @override
  void initState() {
    super.initState();
    _snapshot = ref.read(tlTemporaryConfigsProvider);
    _stick = widget.spec.isStick;
    _search.text = ref.read(timelineSearchProvider)[_id]?.query ?? '';
    _search.addListener(_onText);
    _focus.addListener(_onFocus);
    widget.scopeSync.addListener(_onScope);
    widget.spec.heightFactor.addListener(_onHeight);
  }

  @override
  void dispose() {
    widget.spec.heightFactor.removeListener(_onHeight);
    widget.scopeSync.removeListener(_onScope);
    _focus.removeListener(_onFocus);
    _search.removeListener(_onText);
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onFocus() => setState(() {});

  void _onText() {
    if (_search.text.trim() == (ref.read(timelineSearchProvider)[_id]?.query ?? '')) return;
    ref.read(timelineSearchProvider.notifier).setQuery(_id, _search.text);
  }

  /// タブが替わったら、そのタブの探す語に。
  void _onScope() {
    if (!mounted) return;
    final q = ref.read(timelineSearchProvider)[_id]?.query ?? '';
    if (_search.text != q) _search.text = q;
    setState(() {});
  }

  void _onHeight() {
    final stick = widget.spec.isStick;
    if (stick == _stick) return;
    // stick → 展開: キャンセルの巻き戻し先を取り直す。
    if (!stick) _snapshot = ref.read(tlTemporaryConfigsProvider);
    if (stick) _focus.unfocus();
    setState(() => _stick = stick);
  }

  /// stick の段を入力欄の高さに合わせる(ハンドル + 上下の余白 + 入力欄)。
  void _syncStickStop(BuildContext context) {
    final host = MediaQuery.sizeOf(context).height;
    if (host <= 0) return;
    final spec = widget.spec;
    final fit = ((kFowHandleHeight + RasqSizes.searchBarHeight + RasqSpacing.sm * 2 + 2) / host).clamp(spec.minHeightFactor, timelineTempExpandedFactor - 0.1);
    final current = spec.heightStops.first;
    if ((fit - current).abs() < 0.002) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final wasStick = (spec.heightFactor.value - current).abs() < 0.01;
      spec.heightStops = [fit, timelineTempExpandedFactor];
      if (wasStick) spec.heightFactor.value = fit;
    });
  }

  void _go(int dir) => ref.read(timelineSearchNavProvider.notifier).go(_id, dir);

  void _confirm() => collapseTimelineTempFow(widget.spec);

  /// キャンセル (D-384): 展開してからの変更を巻き戻して**閉じる**(stick にはしない)。
  void _cancel() {
    ref.read(tlTemporaryConfigsProvider.notifier).restore(_snapshot);
    widget.onClose();
  }

  /// 入力欄の右端: 「i / N」(飛ぶ前は「N 件」)+ ↑↓。
  Widget _navigator() {
    final scheme = Theme.of(context).colorScheme;
    final q = ref.watch(timelineSearchProvider.select((m) => m[_id]));
    final matches = ref.watch(timelineSearchMatchesProvider(_id));
    final cursor = ref.watch(timelineSearchCursorProvider.select((m) => m[_id]));
    final at = cursor == null ? -1 : matches.indexOf(cursor);
    final n = matches.length;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (q != null)
        Text(at >= 0 ? '${at + 1} / $n' : '$n 件', key: const ValueKey('tl.search.count'), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
      RasqIconButton(key: const ValueKey('tl.search.prev'), icon: Icons.keyboard_arrow_up, size: 20, tooltip: '前の該当投稿', onPressed: n > 0 && at != 0 ? () => _go(-1) : null),
      RasqIconButton(key: const ValueKey('tl.search.next'), icon: Icons.keyboard_arrow_down, size: 20, tooltip: '次の該当投稿', onPressed: n > 0 && (at < 0 || at < n - 1) ? () => _go(1) : null),
    ]);
  }

  Widget _searchBox() {
    final fuzzy = ref.watch(timelineSearchProvider.select((m) => m[_id]?.fuzzy)) ?? ref.read(timelineSearchProvider.notifier).fuzzyOf(_id);
    return RasqExpandableSearchBox(
      key: const ValueKey('tl.temp.search'),
      expanded: !_stick && (_chipsOpen || _focus.hasFocus || fuzzy),
      controller: _search,
      focusNode: _focus,
      hintText: 'このタイムラインから探す',
      onSubmitted: (_) => _go(1),
      // stick の ∨ は展開モードへ。
      onDropdownTap: _stick ? widget.spec.expandStick : () => setState(() => _chipsOpen = !_chipsOpen),
      filterChips: [
        RasqFilterChipItem(
          label: '近似検索',
          selected: fuzzy,
          onTap: () {
            ref.read(timelineSearchProvider.notifier).setFuzzy(_id, !fuzzy);
            setState(() {});
          },
        ),
      ],
      barTrailing: _navigator(),
    );
  }

  @override
  Widget build(BuildContext context) {
    _syncStickStop(context);
    final scheme = Theme.of(context).colorScheme;
    if (_stick) {
      return Padding(
        key: timelineTempStickKey,
        padding: const EdgeInsets.fromLTRB(RasqSpacing.sm, 0, RasqSpacing.xs, 0),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _searchBox()),
          RasqIconButton(key: const ValueKey('tl.temp.close'), icon: Icons.close, size: 20, tooltip: '閉じる', onPressed: widget.onClose),
        ]),
      );
    }
    return Column(children: [
      SizedBox(
        key: timelineTempHeaderKey,
        height: 40,
        child: Row(children: [
          TextButton(key: const ValueKey('tl.temp.cancel'), onPressed: _cancel, child: Text('キャンセル', style: TextStyle(color: scheme.onSurfaceVariant))),
          Expanded(child: Center(child: Text('タイムラインを一時変更', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis))),
          TextButton(key: const ValueKey('tl.temp.confirm'), onPressed: _confirm, child: Text('決定', style: TextStyle(color: scheme.primary))),
        ]),
      ),
      Padding(padding: const EdgeInsets.fromLTRB(RasqSpacing.sm, 0, RasqSpacing.sm, RasqSpacing.xs), child: _searchBox()),
      Expanded(child: TimelineConfigScreen(scope: _scope, temporary: true, tabs: widget.tabs, scopeSync: widget.scopeSync)),
    ]);
  }
}
