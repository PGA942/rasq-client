import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'fow.dart';
import 'overlay_entry.dart';
import 'overlay_layer.dart';
import 'overlay_manager.dart';
import 'tethered_panel.dart';

/// Renders the content plus every open overlay, honouring layer z-order,
/// scrims and barrier behaviour. Place it once at the root of the app shell.
/// リサイズハンドルの高さ (D-178: 18 → 26。指で掴みやすく)。stick の高さ実測はこれを足す。
const kFowHandleHeight = 26.0;

/// FOW の動き (D-476): 高さの変化(スナップ着地 / stick の展開 / 投稿 FOW のピッタリ追従、D-049)と**開く**動きの長さと曲線。
const kFowMotionDuration = Duration(milliseconds: 180);
const kFowMotionCurve = Curves.easeOutCubic;

/// **閉じる**動き (D-476): 開くより少し短く、加速しながら抜ける。
const kFowExitDuration = Duration(milliseconds: 140);
const kFowExitCurve = Curves.easeInCubic;

/// 開いた / 閉じる動きを始めた印 (D-476)。エントリに付ける(ホストの外側の並びが変わって FOW 群の Element が作り直されても、
/// 開く動きを二度やらない)。
final Expando<bool> _fowEntered = Expando('fowEntered');
final Expando<bool> _fowScrimShown = Expando('fowScrimShown');

bool _reducedMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

class OverlayHost extends StatelessWidget {
  const OverlayHost({super.key, required this.manager, required this.child, this.scrimColor, this.fowDockInset, this.fowColumns, this.fowPinnedWidth = 320, this.fowTopInset, this.fowTopClearance});

  final OverlayManager manager;
  final Widget child;
  final Color? scrimColor;

  /// [FowSpec.dockAboveFooter] な FOW の根本を持ち上げる量(= アプリの
  /// フッターメニュー高さ)。レイアウトを知るアプリ側が供給する (D-047)。
  final double Function(BuildContext context)? fowDockInset;

  /// FOW の列スロット (D-062): タブレット幅のカラム幾何をアプリが供給する。
  /// null/空 = 単一スロット(全幅、1200px 上限で中央寄せ)。FOW はスロットの
  /// 中心に揃い、スロット幅に収まる。
  final List<FowColumnSlot> Function(BuildContext context)? fowColumns;

  /// 壁付けピン (D-063) の幅。両端の壁へ 50px 以上めり込ませた FOW は
  /// 壁側にこの幅・**最大高さ**で張り付く(アプリは検索ホーム幅を渡す)。
  final double fowPinnedWidth;

  /// [FowSpec.attachTop] な FOW の上端 = アプリヘッダーの下辺 (D-065)。
  /// アプリがヘッダー実高さ(ステータスバー込み)を供給する。
  final double Function(BuildContext context)? fowTopInset;

  /// 下端ドック / 壁付けの FOW の上辺をここまでで止める (D-178): ハンドルが画面の上端
  /// (iPad のコントロールセンター等のシステムジェスチャー域)に入らないようにする。
  final double Function(BuildContext context)? fowTopClearance;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: manager,
      builder: (context, _) {
        final entries = manager.entries;
        return PopScope(
          canPop: !manager.fowSwitcherOpen && !entries.any((e) => e.effectiveBarrierBehavior != OverlayBarrierBehavior.none && !manager.isFowSuspended(e)),
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) manager.handleBack();
          },
          child: Stack(
            fit: StackFit.expand,
            children: _layers(context, entries),
          ),
        );
      },
    );
  }

  /// 重ね順に並べる。FOW 群は最初の FOW の位置に 1 回だけ。ただし `aboveSidebar` の FOW があれば、サイドバーの**前**に描く (D-274)。
  List<Widget> _layers(BuildContext context, List<RasqOverlayEntry> entries) {
    final fows = entries.where((x) => x.layer == OverlayLayer.fow).toList();
    // 閉じる動きの途中の FOW (D-476)。モーションの抑制中は写しを撮らせず、残っていても描かない(すぐ消す)。
    manager.fowExitMotion = !_reducedMotion(context);
    final leaving = manager.leavingFows;
    if (leaving.isNotEmpty && _reducedMotion(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final l in leaving) {
          manager.fowLeft(l.entry);
        }
      });
    }
    final showLeaving = _reducedMotion(context) ? const <FowLeaving>[] : leaving;
    final lift = [...fows, for (final l in showLeaving) l.entry].any((e) => e.fow?.aboveSidebar ?? false) && entries.any((e) => e.layer == OverlayLayer.sidebar);
    final out = <Widget>[child];
    var placed = fows.isEmpty && showLeaving.isEmpty;
    // FOW が無ければ、カラムを縮める量 (D-397) も無し。
    if (fows.isEmpty) manager.setFowStickReserve(const {});
    for (final e in entries) {
      if (e.layer == OverlayLayer.fow) {
        if (!placed && !lift) {
          out.addAll(_buildFowGroup(context, fows, showLeaving));
          placed = true;
        }
        continue;
      }
      // サイドバーより後ろのレイヤーに入る直前(= サイドバーの直後)に、持ち上げた FOW 群を置く。
      if (!placed && lift && e.layer.index > OverlayLayer.sidebar.index) {
        out.addAll(_buildFowGroup(context, fows, showLeaving));
        placed = true;
      }
      out.addAll(_buildEntry(context, e));
    }
    if (!placed) out.addAll(_buildFowGroup(context, fows, showLeaving));
    return out;
  }

  List<Widget> _buildEntry(BuildContext context, RasqOverlayEntry e) {
    final widgets = <Widget>[];
    final behavior = e.effectiveBarrierBehavior;
    // 各エントリは id でキー付け (D-205): 前にあるエントリ(FOW / ドロップダウン)の出入りで Stack の並びが
    // ずれても Element が作り直されない(RAi の three_js が毎回作り直されていた)。FOW 群はキー無しのまま
    // (位置で再利用される従来の挙動に AsTell のルーム FOW の高さアニメーションが依存している)。
    if (behavior != OverlayBarrierBehavior.none) {
      widgets.add(Positioned.fill(
        key: ValueKey('ov.${e.id}.barrier'),
        child: Semantics(
          label: behavior == OverlayBarrierBehavior.ignore ? null : '閉じる',
          button: behavior != OverlayBarrierBehavior.ignore,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => manager.barrierTapped(e.id),
            child: e.layer.hasScrim
                ? ColoredBox(color: scrimColor ?? Colors.black.withValues(alpha: 0.35))
                : const SizedBox.expand(),
          ),
        ),
      ));
    }

    final handle = manager.handleFor(e);
    Widget content = Builder(builder: (ctx) => e.builder(ctx, handle));
    if (e.semanticsLabel != null) {
      content = Semantics(label: e.semanticsLabel, container: true, child: content);
    }

    if (e.layer == OverlayLayer.dropdown && e.anchor != null) {
      widgets.add(_AnchoredDropdown(key: ValueKey('ov.${e.id}'), anchor: e.anchor!, child: content));
    } else {
      widgets.add(Positioned.fill(key: ValueKey('ov.${e.id}'), child: Align(alignment: e.alignment, child: content)));
    }
    return widgets;
  }

  /// FOWs dock to the bottom as a bottom-up column: newest at the bottom.
  /// A scrim is painted once, behind the topmost interstitial (if any).
  List<Widget> _buildFowGroup(BuildContext context, List<RasqOverlayEntry> fows, List<FowLeaving> leaving) {
    final widgets = <Widget>[];
    final scrim = scrimColor ?? Colors.black.withValues(alpha: 0.35);
    bool dims(RasqOverlayEntry e) => (e.fow?.blocksContent ?? false) || (e.fow?.dimBehind ?? false);
    // 退避中 (D-169) の FOW はバリアを張らない(Offstage で生かすだけ)。
    final blocking = fows.where((e) => e.effectiveBarrierBehavior != OverlayBarrierBehavior.none && !manager.isFowSuspended(e)).lastOrNull;
    if (blocking != null) {
      // グレーアウト(スクリム)はインタースティシャル(+ボタンの投稿
      // コンポーザー等)のときだけ (D-052)。ピッカー類の「余白クリックで
      // 消失」は**透明バリア**で受ける(背面を暗くしない)。
      final dim = dims(blocking);
      widgets.add(Positioned.fill(
        child: Semantics(
          label: '閉じる',
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => manager.barrierTapped(blocking.id),
            // スクリムは FOW と一緒にフェードインする (D-476。一度出したら作り直されてもそのまま)。
            child: dim ? _FowScrim(entry: blocking, color: scrim) : const SizedBox.expand(),
          ),
        ),
      ));
    }
    // 閉じる動きの間のスクリム (D-476): 暗くしていた FOW が閉じたら、ほかに暗くしている FOW が無ければフェードアウトする(押せない)。
    if (blocking == null || !dims(blocking)) {
      final fading = leaving.map((l) => l.entry).where((e) => dims(e) && e.effectiveBarrierBehavior != OverlayBarrierBehavior.none).lastOrNull;
      if (fading != null) {
        widgets.add(Positioned.fill(
          key: ValueKey('fow.scrim.leave.${fading.id}'),
          child: IgnorePointer(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 1, end: 0),
              duration: kFowExitDuration,
              curve: kFowExitCurve,
              builder: (context, t, _) => ColoredBox(color: scrim.withValues(alpha: scrim.a * t)),
            ),
          ),
        ));
      }
    }
    widgets.add(Positioned.fill(
      // FOW スイッチャー表示中もパネルは Offstage で生かしておく
      // (入力中テキスト等の State を保持する — D-050 の教訓)。
      child: Offstage(
        offstage: manager.fowSwitcherOpen,
        child: _FowColumn(
          dockInset: fowDockInset,
          topClearance: fowTopClearance,
          topInset: fowTopInset,
          columns: fowColumns,
          pinnedWidth: fowPinnedWidth,
          entries: fows,
          leaving: leaving,
          onLeft: manager.fowLeft,
          suspended: manager.isFowSuspended,
          onStickReserve: manager.setFowStickReserve,
          buildContent: (e) {
            final handle = manager.handleFor(e);
            Widget content = Builder(builder: (ctx) => e.builder(ctx, handle));
            if (e.semanticsLabel != null) content = Semantics(label: e.semanticsLabel, container: true, child: content);
            return content;
          },
          onCancel: (e) => manager.close(e.id, reason: OverlayCloseReason.discard),
          onConfirm: (e) => manager.close(e.id, result: true),
          onShowSwitcher: manager.openFowSwitcher,
        ),
      ),
    ));
    if (manager.fowSwitcherOpen) {
      widgets.add(Positioned.fill(child: _FowSwitcher(entries: fows, manager: manager)));
    }
    return widgets;
  }
}

/// FOW スイッチャー (D-065): 背景をブラックアウトし、開いている FOW を
/// リスト形式で表示(APP スイッチャー風)。選択で前面化(親を選ぶと
/// 子 FOW は自動クローズ)、✕ でその FOW を閉じる、余白タップで戻る。
class _FowSwitcher extends StatelessWidget {
  const _FowSwitcher({required this.entries, required this.manager});
  final List<RasqOverlayEntry> entries;
  final OverlayManager manager;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    String labelOf(RasqOverlayEntry e) => e.fow?.title ?? e.semanticsLabel ?? e.id;
    return Semantics(
      label: 'FOW切り替え',
      container: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => manager.setFowSwitcher(false),
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.6),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(24),
                  children: [
                    // 前面の FOW が先頭(entries は back → front)。
                    for (final e in entries.reversed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: scheme.surface,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: scheme.outlineVariant),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => manager.promoteFow(e.id),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                              // プレビュー (D-066): 開く直前のキャプチャを縮小表示。
                              if (e.fow?.switcherPreview != null)
                                Container(
                                  height: 140,
                                  color: scheme.surfaceContainerHighest,
                                  child: RawImage(image: e.fow!.switcherPreview, fit: BoxFit.contain),
                                ),
                              ListTile(
                                leading: const Icon(Icons.layers_outlined),
                                title: Text(labelOf(e), maxLines: 1, overflow: TextOverflow.ellipsis),
                                trailing: IconButton(
                                  tooltip: '閉じる',
                                  icon: const Icon(Icons.close),
                                  onPressed: () => manager.close(e.id, reason: OverlayCloseReason.discard),
                                ),
                                onTap: () => manager.promoteFow(e.id),
                              ),
                            ]),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lays FOW panels out per attachment (D-065): 下端ドック(既定)/
/// アプリヘッダー下付き / アクションボタンへのアンカー / 壁付けピン。
/// 複数の FOW は**重ねて**表示され(最前面のみ影)、切り替えはハンドル
/// クリックの FOW スイッチャーで行う。
class _FowColumn extends StatelessWidget {
  const _FowColumn({required this.entries, this.leaving = const [], this.onLeft, required this.buildContent, required this.onCancel, required this.onConfirm, required this.onShowSwitcher, this.dockInset, this.topInset, this.topClearance, this.columns, this.pinnedWidth = 320, this.suspended, this.onStickReserve});
  final List<RasqOverlayEntry> entries;

  /// 閉じる動きの途中の FOW (D-476)。閉じたときの重ね順の位置に描き、操作は受けない。動き終えたら [onLeft]。
  final List<FowLeaving> leaving;
  final void Function(RasqOverlayEntry entry)? onLeft;

  /// stick の FOW がカラムの下端に占めている高さ(列スロットの index → 高さ)を知らせる口 (D-397)。
  final void Function(Map<int, double> reserve)? onStickReserve;

  /// 退避中 (D-169): Offstage で生かす(レイアウトからは外す)。
  final bool Function(RasqOverlayEntry e)? suspended;
  final Widget Function(RasqOverlayEntry) buildContent;
  final void Function(RasqOverlayEntry) onCancel;
  final void Function(RasqOverlayEntry) onConfirm;
  final VoidCallback onShowSwitcher;
  final double Function(BuildContext context)? dockInset;
  final double Function(BuildContext context)? topInset;
  final double Function(BuildContext context)? topClearance;
  final List<FowColumnSlot> Function(BuildContext context)? columns;
  final double pinnedWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      var insets = MediaQuery.viewInsetsOf(context).bottom;
      // stick FOW (D-047): キーボードが閉じている間はフッターメニューの上に
      // ドックする(キーボードが出たらその上 = 従来どおり)。
      if (insets == 0 && entries.any((e) => e.fow?.dockAboveFooter == true)) {
        insets = dockInset?.call(context) ?? 0;
      }
      final hostH = constraints.maxHeight;
      final avail = hostH - insets;
      final totalW = constraints.maxWidth;
      final topInsetV = topInset?.call(context) ?? 0;
      final topClearV = topClearance?.call(context) ?? 0;
      // 列スロット (D-062): 無指定なら単一スロット(全幅 1200px 上限・中央)。
      final maxW = totalW < 1200 ? totalW : 1200.0;
      final slots = columns?.call(context) ?? const <FowColumnSlot>[];
      final effSlots = slots.isEmpty ? [FowColumnSlot(x: (totalW - maxW) / 2, width: maxW)] : slots;
      // 壁付けスロット (D-063): カラム領域の両端に検索ホーム幅・最大高さで
      // 張り付く(中央への全幅最大化はしない — 元画面を覆わない)。
      final pinW = pinnedWidth < totalW ? pinnedWidth : totalW;
      FowColumnSlot pinSlot(int wall) => wall < 0
          ? FowColumnSlot(x: effSlots.first.x, width: pinW)
          : FowColumnSlot(x: effSlots.last.x + effSlots.last.width - pinW, width: pinW);
      FowColumnSlot slotOf(FowSpec s) {
        if (s.pinnedWall != 0) return pinSlot(s.pinnedWall);
        final slot = effSlots[s.columnIndex.clamp(0, effSlots.length - 1)];
        // カラムが狭すぎるなら、全カラムにまたがる (D-274)。
        final need = s.spanColumnsBelow;
        if (need != null && slot.width < need && effSlots.length > 1) {
          return FowColumnSlot(x: effSlots.first.x, width: effSlots.last.x + effSlots.last.width - effSlots.first.x);
        }
        return slot;
      }
      int nearest(double center) {
        var best = 0;
        var bestD = double.infinity;
        for (var i = 0; i < effSlots.length; i++) {
          final d = (center - (effSlots[i].x + effSlots[i].width / 2)).abs();
          if (d < bestD) {
            bestD = d;
            best = i;
          }
        }
        return best;
      }

      // 離したときの精算 (D-062/D-063/D-065): 横 = 最も近いカラム中心へ
      // スナップ。同カラム最寄りでも**ウィンドウ幅の 1 割以上**動かして
      // いれば隣へ。壁へ 50px 以上めり込ませたらその壁へピン留め(ピン中は
      // 内側へ 1 割以上でカラム揃えへ復帰)。**アンカー FOW は別カラムへ
      // 動かした時点で壁付き表示**(anchor 解除 → pinnedWall)。
      // 縦 = 同じ比率(ウィンドウ高さの 1 割)で付け先を切り替える:
      // アンカー FOW は上付き ⇄ 下付きの反転、通常 FOW はアプリヘッダー
      // 下付き ⇄ フッター上/画面下端。
      final moveThresholdX = totalW * 0.1;
      final moveThresholdY = hostH * 0.1;
      void settle(FowSpec s, double dx, double dy) {
        final cur = slotOf(s);
        final center = cur.x + cur.width / 2 + dx;
        final first = effSlots.first;
        final last = effSlots.last;
        final leftLimit = (first.x + first.width / 2) - first.x - 50;
        final rightLimit = (last.x + last.width / 2) + (totalW - (last.x + last.width)) + 50;
        if (s.pinnedWall != 0) {
          final inward = s.pinnedWall < 0 ? dx : -dx;
          if (inward >= moveThresholdX) {
            s.pinnedWall = 0;
            s.columnIndex = nearest(center);
          }
        } else if (center < leftLimit) {
          s.anchor = null;
          s.pinnedWall = -1;
        } else if (center > rightLimit) {
          s.anchor = null;
          s.pinnedWall = 1;
        } else {
          var best = nearest(center);
          final curIdx = s.columnIndex.clamp(0, effSlots.length - 1);
          if (best == curIdx && dx.abs() >= moveThresholdX) {
            best = (curIdx + (dx > 0 ? 1 : -1)).clamp(0, effSlots.length - 1);
          }
          if (best != curIdx && s.anchor != null) {
            // アンカー FOW は別カラムへ動かした時点で壁付き表示 (D-065)。
            s.anchor = null;
            s.pinnedWall = dx > 0 ? 1 : -1;
          } else {
            s.columnIndex = best;
          }
        }
        if (s.pinnedWall == 0 && dy.abs() >= moveThresholdY) {
          if (s.anchor != null) {
            s.anchorBelow = dy > 0; // 下へ → アンカーの下付き
          } else {
            s.attachTop = dy < 0; // 上へ → アプリヘッダーに下付き
          }
        }
        s.geometryRev.value++;
      }

      return AnimatedBuilder(
        animation: Listenable.merge([
          for (final e in [...entries, for (final l in leaving) l.entry]) ...[e.fow?.heightFactor, e.fow?.geometryRev],
        ].whereType<Listenable>().toList()),
        builder: (context, _) {
          // 重ね表示 (D-065): グループの縦積みをやめ、各 FOW を付け先ごとに
          // 独立配置する。entries は back → front なので後の子が上に描かれ、
          // 埋もれた FOW はハンドルクリックのスイッチャーで前面化する。
          final frontmostEntry = entries.isEmpty ? null : entries.last;
          // 閉じかけ (D-476) は閉じたときの位置に差し込む(後ろの FOW が閉じても前へ飛び出さない)。同じ id が開いていれば描かない。
          final liveIds = {for (final x in entries) x.id};
          final order = <(RasqOverlayEntry, bool)>[for (final x in entries) (x, false)];
          // index は閉じたときの(それより前に閉じたものを除いた)並びの位置なので、閉じた順に、先に閉じて手前の位置にいたぶんずらして戻す
          // (親と一緒に閉じた子は親の前、離れて閉じたものは元の並び)。
          final leavingLive = [...leaving.where((l) => !liveIds.contains(l.entry.id))];
          for (var i = 0; i < leavingLive.length; i++) {
            final l = leavingLive[i];
            final shift = leavingLive.take(i).where((p) => p.index <= l.index).length;
            order.insert((l.index + shift).clamp(0, order.length), (l.entry, true));
          }
          final byId = {for (final l in leavingLive) l.entry.id: l.entry, for (final x in entries) x.id: x};
          final leavingById = {for (final l in leavingLive) l.entry.id: l};
          // 親子 FOW (D-067/D-068): 親の外側(付いている側)を占める子 FOW
          // の最大高さ。親はこのぶん**枠を伸ばし**、FOW ウィジェット内の
          // [FowChildGap](高さ可変 padding)がこの値を受けて内容を子の
          // 反対側へ押し出す — 入力部が被らない。子の heightFactor は
          // AnimatedBuilder が購読済み → リサイズにリアルタイム追従する。
          double liftFor(RasqOverlayEntry p) {
            var lift = 0.0;
            for (final c in entries) {
              if (c.ownerId != p.id) continue;
              final cs = c.fow;
              // ボタンにつながった子は、親を持ち上げるもの([FowTether.liftOwner]、D-517)だけ。
              if (cs == null || cs.pinnedWall != 0 || (cs.anchor != null && cs.tether?.liftOwner != true)) continue;
              final ch = cs.heightFactor.value * avail;
              if (ch > lift) lift = ch;
            }
            return lift;
          }

          final children = <Widget>[];
          // 下にドックした親が子の高さぶん持ち上げた量(id → px、D-068)。持ち上げる子([FowTether.liftOwner])のつなぎ先をずらす。
          final lifted = <String, double>{};
          // stick のぶんカラムを縮める (D-397): 畳まれた stick FOW が下端に置かれていれば、重なるカラムにその高さを知らせる。
          final reserve = <int, double>{};
          final seen = <String>{};
          for (final (e, isLeaving) in order) {
            if (!seen.add(e.id)) continue;
            final s = e.fow ?? FowSpec();
            // 閉じかけは位置だけ借りる: 精算 / 子の隙間 / 置いた矩形 / stick の予約は書かない(開いている FOW のもの)。
            if (!isLeaving) s.settleMove = (dx, dy) => settle(s, dx, dy);
            final pinned = s.pinnedWall != 0;
            var h = (pinned ? 1.0 : s.heightFactor.value) * avail;
            final anchor = pinned ? null : s.anchor;
            // ボタンにつながった形 (D-513): ドックせず、ボタンにつながったパネルを画面いっぱいの層に置く(パネルはボタンの
            // カラムの中に収める、D-481)。閉じる動きの写しは撮らない(閉じたらすぐ消える)。
            final tether = s.tether;
            if (tether != null && anchor != null) {
              if (isLeaving) continue;
              final slot = slotOf(s);
              // 親を持ち上げる子 (D-517): 開いたときに取ったボタンの矩形は持ち上げる前のもの。親の中のボタンは持ち上げたぶん上にある。
              final shift = tether.liftOwner && e.ownerId != null ? (lifted[e.ownerId] ?? 0.0) : 0.0;
              s.laidOut = null;
              children.add(Positioned.fill(
                key: ValueKey('rasqOverlay.fow.${e.id}'),
                child: Offstage(
                  offstage: suspended?.call(e) ?? false,
                  child: _FowTethered(
                    entry: e,
                    tether: tether,
                    anchor: anchor.translate(0, -shift),
                    bounds: Rect.fromLTWH(slot.x, 0, slot.width, hostH),
                    height: s.heightFactor.value * avail,
                    onCancel: () => onCancel(e),
                    onConfirm: () => onConfirm(e),
                    child: buildContent(e),
                  ),
                ),
              ));
              continue;
            }
            // 子 FOW は親の付く方向・カラムに追従する(D-067: 方向は親側
            // 指定 — 親が動けば更新される)。
            final parentSpec = (e.ownerId == null ? null : byId[e.ownerId])?.fow;
            final follow = parentSpec != null && !pinned && anchor == null;
            final slot = follow ? slotOf(parentSpec) : slotOf(s);
            final attachTopEff = follow ? parentSpec.attachTop : s.attachTop;
            final lift = liftFor(e);
            var topSide = false; // 上側基準(ヘッダー下付き / アンカー下付き)
            var padTop = 0.0;
            var padBottom = insets;
            if (anchor != null) {
              final spaceBelow = hostH - insets - anchor.bottom;
              final spaceAbove = anchor.top - topInsetV;
              // 基本は下付き(ボタンの下辺に FOW 上辺)。下の余白が最小段より
              // 小さければ上付きへ反転 (D-052/D-053)。ドラッグ確定が最優先。
              final below = s.anchorBelow ?? (spaceBelow >= s.minHeightFactor * avail || spaceBelow >= spaceAbove);
              if (below) {
                topSide = true;
                padTop = anchor.bottom.clamp(0.0, hostH);
                if (spaceBelow > 0 && h > spaceBelow) h = spaceBelow;
              } else {
                padBottom = (hostH - anchor.top).clamp(0.0, hostH);
                if (spaceAbove > 0 && h > spaceAbove) h = spaceAbove;
              }
            } else if (!pinned && attachTopEff) {
              // アプリヘッダーに下付き (D-065)。子の高さぶん枠を伸ばし、
              // 内容側は FowChildGap が場所を空ける (D-068)。
              topSide = true;
              padTop = topInsetV;
              h += lift;
              final space = hostH - padTop - insets;
              if (space > 0 && h > space) h = space;
            } else if (!pinned) {
              // 下側ドック: 子の高さぶん枠を伸ばす (D-068)。
              h += lift;
              if (!isLeaving) lifted[e.id] = lift;
              final space = hostH - padBottom;
              if (space > 0 && h > space) h = space;
            }
            // 上辺の余白 (D-178): 下側基準(下端ドック / 壁付け / アンカー上付き)の FOW は
            // ハンドルが画面上端のシステムジェスチャー域に入らない高さで止める。
            if (!topSide) {
              final cap = hostH - padBottom - topClearV;
              if (cap > 0 && h > cap) h = cap;
            }
            // FowChildGap への通知 (D-068): 子はいまの付け先の外側(下ドック
            // なら下、ヘッダー付きなら上)に付く。いなければ 0。
            final gapTop = !pinned && anchor == null && attachTopEff ? lift : 0.0;
            final gapBottom = !pinned && anchor == null && !attachTopEff ? lift : 0.0;
            if (!isLeaving && s.childGapTop.value != gapTop) s.childGapTop.value = gapTop;
            if (!isLeaving && s.childGapBottom.value != gapBottom) s.childGapBottom.value = gapBottom;
            // 最大幅 (D-185): 指定があればカラムの中で [FowSpec.hAlign] の側に寄せる(既定は中央)。
            // アンカー付き (D-209) はアンカーの横位置に寄せる(ボタンから出現したように見える)。
            final panelW = s.maxWidth != null && s.maxWidth! < slot.width ? s.maxWidth! : slot.width;
            double left;
            if (panelW >= slot.width) {
              left = slot.x;
            } else if (anchor != null) {
              left = (anchor.center.dx - panelW / 2).clamp(slot.x, slot.x + slot.width - panelW);
            } else {
              left = switch (s.hAlign) {
                FowHAlign.start => slot.x,
                FowHAlign.center => slot.x + (slot.width - panelW) / 2,
                FowHAlign.end => slot.x + slot.width - panelW,
              };
            }
            // 置いた矩形を記録 (D-215): 上側基準なら padTop から、下側基準なら padBottom の上に h。
            if (!isLeaving) s.laidOut = (suspended?.call(e) ?? false) ? null : Rect.fromLTWH(left, topSide ? padTop : hostH - padBottom - h, panelW, h);
            // 下端に置いた stick(壁付け / アンカー / 上付きは除く)。横に重なるカラムぜんぶ(またがって出ていれば両方)。
            if (!isLeaving && !(suspended?.call(e) ?? false) && !pinned && anchor == null && !topSide && s.isStick) {
              for (var i = 0; i < effSlots.length; i++) {
                final sl = effSlots[i];
                final overlap = (left + panelW < sl.x + sl.width ? left + panelW : sl.x + sl.width) - (left > sl.x ? left : sl.x);
                if (overlap > 1 && h > (reserve[i] ?? 0)) reserve[i] = h;
              }
            }
            // 閉じかけ (D-476) は閉じる直前のパネルの写しを描く(中身のウィジェットはもう無い)。
            final shot = isLeaving ? leavingById[e.id] : null;
            children.add(Positioned(
              // id でキー付け (D-476): 閉じかけに変わっても同じ Element のまま動かし、後ろの FOW が閉じても前の FOW の中身を作り直さない。
              key: ValueKey('rasqOverlay.fow.${e.id}'),
              left: left,
              width: panelW,
              top: 0,
              bottom: 0,
              child: Offstage(
                offstage: suspended?.call(e) ?? false,
              child: Padding(
                padding: EdgeInsets.only(top: padTop, bottom: padBottom),
                // OverflowBox: 高さアニメーション(D-049)の過渡期の一時的な
                // はみ出しを反対側へ逃がして overflow にしない。
                child: OverflowBox(
                  alignment: topSide ? Alignment.topCenter : Alignment.bottomCenter,
                  minHeight: 0,
                  maxHeight: double.infinity,
                  // 出入りの動き (D-476): 付け先の側からすべり込み + フェード(アンカーは少し拡大)。閉じかけは押せない。
                  child: _FowMotion(
                    entry: e,
                    leaving: isLeaving,
                    topSide: topSide,
                    anchored: anchor != null,
                    height: h,
                    onLeft: onLeft,
                  child: shot != null
                      ? SizedBox(
                          key: ValueKey('rasqOverlay.fow.leaving.${e.id}'),
                          width: shot.size.width,
                          height: shot.size.height,
                          // 写しの角はパネルと同じ角丸で切る(角の外側が透明で写らない環境でも四角く出ない)。
                          child: ClipRRect(borderRadius: _fowPanelRadius(s, anchored: anchor != null, topSide: topSide), child: RawImage(image: shot.image, fit: BoxFit.fill)),
                        )
                  // パネルのテーマ (D-202): 指定があればクロームごと差し替える(ビューワーのダーク FOW)。
                  : Builder(builder: (ctx) {
                    final panel = _FowPanel(
                      entry: e,
                      height: h,
                      // 最前面(最新)のパネルだけ影付き (D-052: 複数 FOW の判別)。
                      frontmost: identical(e, frontmostEntry),
                      topSide: topSide,
                      anchored: anchor != null,
                      onCancel: () => onCancel(e),
                      onConfirm: () => onConfirm(e),
                      onShowSwitcher: onShowSwitcher,
                      child: buildContent(e),
                    );
                    final theme = s.theme;
                    // 着せ替え (D-337): FOW の面の上の文字色(ハンドル / 見出しも含めて)。FOW 自身のテーマの上に重ねる。
                    final panelTheme = FowPanelSkin.of(ctx)?.theme;
                    if (theme == null && panelTheme == null) return panel;
                    return Builder(builder: (bctx) {
                      final base = theme?.call(bctx) ?? Theme.of(bctx);
                      return Theme(data: panelTheme?.call(bctx, base) ?? base, child: panel);
                    });
                  }),
                  ),
                ),
              ),
              ),
            ));
          }
          onStickReserve?.call(reserve);
          return Stack(children: children);
        },
      );
    });
  }
}

/// ボタンにつながった FOW (D-513)。見出し(FOW と同じ: 左 = headerLeading / キャンセル、真ん中 = タイトル、右 = headerTrailing / 決定)
/// + 中身 + フッター([FowSpec.footer]、D-517)を [TetheredPanel] に入れる。首(元のボタン)を押すと閉じる。
class _FowTethered extends StatelessWidget {
  const _FowTethered({required this.entry, required this.tether, required this.anchor, required this.bounds, required this.height, required this.onCancel, required this.onConfirm, required this.child});
  final RasqOverlayEntry entry;
  final FowTether tether;
  final Rect anchor;
  final Rect bounds;
  final double height;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final spec = entry.fow ?? FowSpec();
    Widget panel(double progress) => Builder(builder: (context) {
          final scheme = Theme.of(context).colorScheme;
          final header = spec.hasHeader
              ? SizedBox(
                  key: const ValueKey('rasqOverlay.fow.header'),
                  height: 40,
                  child: Row(children: [
                    if (spec.headerLeading != null)
                      spec.headerLeading!
                    else if (spec.cancelText != null)
                      TextButton(onPressed: spec.interceptCancel ?? onCancel, child: Text(spec.cancelText!, style: TextStyle(color: scheme.onSurfaceVariant)))
                    else
                      const SizedBox(width: 56),
                    Expanded(child: Center(child: Text(spec.title ?? '', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis))),
                    if (spec.headerTrailing != null)
                      spec.headerTrailing!
                    else if (spec.confirmText != null)
                      TextButton(onPressed: onConfirm, child: Text(spec.confirmText!, style: TextStyle(color: scheme.primary)))
                    else
                      const SizedBox(width: 56),
                  ]),
                )
              : null;
          final body = tether.fitContent
              ? Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [?header, Flexible(child: child), ?spec.footer])
              // 高さの決まった FOW: 空いているぶんまで(入りきらなければ中がスクロールする)。
              : LayoutBuilder(
                  builder: (context, c) => SizedBox(
                    height: math.min(height, c.maxHeight),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [?header, Expanded(child: child), ?spec.footer]),
                  ),
                );
          return TetheredPanel(
            key: ValueKey('rasqOverlay.fow.tether.${entry.id}'),
            anchor: anchor,
            bounds: bounds,
            width: tether.width,
            preferredSide: tether.preferredSide,
            iconExtent: tether.iconExtent,
            anchorChild: tether.anchorChild,
            onAnchorTap: onCancel,
            progress: progress,
            lockSide: tether.liftOwner,
            child: body,
          );
        });
    final theme = spec.theme;
    final panelTheme = FowPanelSkin.of(context)?.theme;
    Widget themed(Widget w) {
      if (theme == null && panelTheme == null) return w;
      return Builder(builder: (bctx) {
        final base = theme?.call(bctx) ?? Theme.of(bctx);
        return Theme(data: panelTheme?.call(bctx, base) ?? base, child: w);
      });
    }

    // 出てくる動き: ボタンの中心から広がる(モーションの抑制中 / motion: false は動かさない)。
    if (_reducedMotion(context) || !spec.motion) return themed(panel(1));
    return themed(TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => panel(t),
    ));
  }
}

BorderRadius _fowPanelRadius(FowSpec spec, {required bool anchored, required bool topSide}) => anchored
    ? BorderRadius.circular(16)
    : topSide
        ? const BorderRadius.vertical(bottom: Radius.circular(16))
        : spec.dockAboveFooter
            ? BorderRadius.circular(16)
            : const BorderRadius.vertical(top: Radius.circular(16));

class _FowPanel extends StatefulWidget {
  const _FowPanel({required this.entry, required this.height, required this.child, required this.onCancel, required this.onConfirm, required this.onShowSwitcher, this.frontmost = true, this.topSide = false, this.anchored = false});
  final RasqOverlayEntry entry;
  final double height;
  final Widget child;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  /// ドラッグハンドルの**その場での長押し** = FOW スイッチャー (D-065 → D-340)。
  final VoidCallback onShowSwitcher;

  /// 最前面(操作対象)のパネルか。FOW の枠はグレーの線で描き、**影の有無で
  /// 最前面かどうかを判別**する (D-052: 複数 FOW を開いたときの識別)。
  final bool frontmost;

  /// 上側基準の配置(アプリヘッダー下付き / アンカー下付き)。ハンドルは
  /// 反対側 = 下端の外縁に出し、リサイズの向きも反転する (D-065)。
  final bool topSide;

  /// アクションボタンへのアンカー配置(角丸は全周)。
  final bool anchored;

  @override
  State<_FowPanel> createState() => _FowPanelState();
}

class _FowPanelState extends State<_FowPanel> {
  /// ドラッグ中は高さを即時反映(追従遅延を出さない)。離したら
  /// [FowSpec.snapToStops] で最寄りの高さ段階へアニメーションで着地 (D-049)。
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final height = widget.height;
    final child = widget.child;
    final onCancel = widget.onCancel;
    final onConfirm = widget.onConfirm;
    final spec = entry.fow ?? FowSpec();
    final scheme = Theme.of(context).colorScheme;
    final hostHeight = MediaQuery.sizeOf(context).height;
    final topSide = widget.topSide;
    // FOW = ドラッグハンドル + **角丸四角形枠**の集合 (D-048)。
    // 角丸は付け先で決まる: アンカー = 全周(浮いている)、ヘッダー下付き =
    // 下側のみ、フッター上にドックする stick = 全周、画面最下端 = 上側のみ。
    final radius = _fowPanelRadius(spec, anchored: widget.anchored, topSide: topSide);
    // ハンドル: その場で長押し = FOW スイッチャー、タップ = stick なら展開モードへ (D-340。以前はタップでスイッチャー、D-065)、
    // 縦ドラッグ = リサイズ(D-062 で横移動はヘッダー/フッターの FowMoveGrip に役割分担)。
    // 上側基準の配置ではハンドルは下端の外縁 → リサイズの向きも反転する。
    final handle = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: widget.onShowSwitcher,
      onTap: spec.canStick
          ? () {
              if (spec.isStick) spec.expandStick();
            }
          : null,
      onVerticalDragStart: spec.resizable ? (_) => setState(() => _dragging = true) : null,
      onVerticalDragUpdate: spec.resizable ? (d) => spec.resizeBy((topSide ? -d.delta.dy : d.delta.dy) / hostHeight) : null,
      onVerticalDragEnd: spec.resizable
          ? (_) {
              setState(() => _dragging = false);
              spec.snapToStops();
            }
          : null,
      onVerticalDragCancel: spec.resizable ? () => setState(() => _dragging = false) : null,
      child: Semantics(
        label: 'サイズ変更ハンドル',
        button: true,
        child: SizedBox(
          height: kFowHandleHeight,
          width: double.infinity,
          child: Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: scheme.onSurface, borderRadius: BorderRadius.circular(2.5)))),
        ),
      ),
    );
    final header = spec.hasHeader
        // FOW 内ヘッダーは掴んで移動できる (D-062 横 / D-065 縦)。
        ? FowMoveGrip(
            spec: spec,
            child: SizedBox(
              height: 40,
              child: Row(children: [
                // ✕/キャンセル: interceptCancel 指定時は閉じずにそれを呼ぶ
                // (プラグインの確認ポップアップ、D-066)。
                if (spec.headerLeading != null)
                  spec.headerLeading!
                else if (spec.cancelText != null)
                  TextButton(onPressed: spec.interceptCancel ?? onCancel, child: Text(spec.cancelText!, style: TextStyle(color: scheme.onSurfaceVariant)))
                else
                  const SizedBox(width: 80),
                Expanded(child: Center(child: Text(spec.title ?? '', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis))),
                // 右側: headerTrailing(D-045: コンポーザーの公開設定など)>
                // 決定ボタン > 空きスペース。
                if (spec.headerTrailing != null)
                  spec.headerTrailing!
                else if (spec.confirmText != null)
                  TextButton(onPressed: onConfirm, child: Text(spec.confirmText!, style: TextStyle(color: scheme.primary)))
                else
                  const SizedBox(width: 80),
              ]),
            ),
          )
        : null;
    // 非リサイズパネル(stick コンポーザー等)は heightFactor 変更を
    // なめらかに(展開時にヘッダー/返信先タイルが「割り込んでくる」動き)。
    // ドラッグリサイズ可能なパネルは追従遅延を避けて即時反映。
    // RepaintBoundary: FOW スイッチャーのプレビュー用キャプチャ点 (D-066)。
    // 着せ替え (D-335): 地の色と背景のレイヤー(FOW 自身のテーマを持つもの = 全画面の暗い FOW などは、その明るさで判定される)。
    final skin = FowPanelSkin.of(context);
    // ⚠ 子にはキーを付ける: アンカー FOW はキーボードで空きが変わると下付き ⇄ 上付きが入れ替わり、ハンドルの位置(先頭 ⇄ 末尾)が
    // 変わる。キーが無いと本体の Element が作り直され、**入力欄のフォーカスが外れてキーボードが閉じる → 元の付け方に戻る**
    // (大きいキーボードで絵文字ピッカーの検索欄が一瞬で閉じていた、D-351)。
    final content = Column(children: [
      if (spec.showHandle && !topSide) KeyedSubtree(key: const ValueKey('rasqOverlay.fow.handle.top'), child: handle),
      if (header != null) KeyedSubtree(key: const ValueKey('rasqOverlay.fow.header'), child: header),
      // 本体も掴んで動かせる (D-161): ListView / 入力欄 / スライダーなど
      // ジェスチャーを取る部品の上では負け(内側の認識器が勝つ)、それ以外の
      // 余白や文字の上では横 = カラム間移動、縦 = ヘッダー/フッターの
      // 付け先切り替え。クローム(ヘッダー行)が無い FOW でも移動できる。
      // stick の空いたところ(ボタンや入力欄の無いところ)のタップで展開モードへ (D-340)。内側の部品が取るタップはそちらが勝つ。
      Expanded(
        key: const ValueKey('rasqOverlay.fow.body'),
        child: _StickExpandTap(spec: spec, child: spec.bodyMove ? FowMoveGrip(spec: spec, child: child) : child),
      ),
      // フッター (D-517): 見出しと同じく掴んで動かせる。
      if (spec.footer != null) KeyedSubtree(key: const ValueKey('rasqOverlay.fow.footerSlot'), child: FowMoveGrip(spec: spec, child: spec.footer!)),
      if (spec.showHandle && topSide) KeyedSubtree(key: const ValueKey('rasqOverlay.fow.handle.bottom'), child: handle),
    ]);
    final panel = FowSnapshotBoundary(
      key: spec.previewBoundaryKey,
      child: Material(
        key: kFowPanelKey,
        color: skin?.color?.call(context) ?? scheme.surface,
        // 最前面のパネルだけ影付き(枠線は全パネル共通のグレー、D-052)。影は浅く、ふちは細い線 (D-479: [kFowElevation] / [fowRimSide])。
        elevation: widget.frontmost ? kFowElevation : 0,
        shape: RoundedRectangleBorder(side: fowRimSide(scheme), borderRadius: radius),
        clipBehavior: Clip.antiAlias,
        child: skin?.decorate?.call(context, content) ?? content,
      ),
    );
    // ドラッグ中は即時反映(duration 0)、それ以外(スナップ着地・stick の
    // 展開/折りたたみ・外部からの heightFactor 変更)はアニメーションで動かす。
    // ⚠ ウィジェット型は常に AnimatedContainer 1 種に固定する: SizedBox と
    // 切り替えると Element が作り直され、**入力中のテキストごと State が
    // 消える**(ハンドル操作で本文消失、D-050 で実測)。
    // 追従 (D-062/D-065): FowMoveGrip(FOW 内ヘッダー/フッター)を掴んで
    // いる間、パネルが縦横についてくる。離すとホストの精算でカラム中心へ
    // スナップ / 壁付けピン / 付け先切り替え(レイアウト側で位置が変わる)。
    return AnimatedBuilder(
      animation: Listenable.merge([spec.moveDx, spec.moveDy, spec.dragging]),
      builder: (context, child) => AnimatedContainer(
        duration: _dragging || spec.dragging.value ? Duration.zero : kFowMotionDuration,
        curve: kFowMotionCurve,
        height: height,
        transform: Matrix4.translationValues(spec.moveDx.value, spec.moveDy.value, 0),
        child: child,
      ),
      child: panel,
    );
  }
}

/// FOW の出入りの動き (D-476)。以前は高さの変化(D-049: 投稿 FOW のピッタリ追従 / stick の展開)だけが動き、開く / 閉じるは
/// 一瞬で出て消えていた。ホストが全 FOW に同じ動きを付ける(個々の FOW は何もしなくてよい):
/// - 開く: [kFowMotionDuration] / [kFowMotionCurve] で、付け先の側(下端ドック = 下、ヘッダー下付き / アンカーの下 = 上)から
///   パネルの高さの 12%(24〜72px)すべり込みながらフェードイン。アンカー付きは 0.94 倍から拡大(ボタンから出てくる)し、移動は 12px。
/// - 閉じる: [kFowExitDuration] / [kFowExitCurve] で逆向き。閉じかけは閉じる直前のパネルの写し(画像)で、押せない([IgnorePointer] = タップは後ろの画面へ)。
/// - 開き直し(同じ id の差し替え)や FOW 群の作り直しでは開く動きを繰り返さない([_fowEntered])。
/// - `MediaQuery.disableAnimations`(端末のアクセシビリティ設定 / 設定 → モーションの抑制)と [FowSpec.motion] = false では動かさない。
/// 部品の形は動きの有無で変えない(中身の State を作り直さない、D-050)。
class _FowMotion extends StatefulWidget {
  const _FowMotion({required this.entry, required this.leaving, required this.topSide, required this.anchored, required this.height, required this.child, this.onLeft});
  final RasqOverlayEntry entry;
  final bool leaving;
  final bool topSide;
  final bool anchored;
  final double height;
  final void Function(RasqOverlayEntry entry)? onLeft;
  final Widget child;

  @override
  State<_FowMotion> createState() => _FowMotionState();
}

class _FowMotionState extends State<_FowMotion> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: kFowMotionDuration, reverseDuration: kFowExitDuration)..addStatusListener(_onStatus);
  bool _started = false;
  bool _left = false;

  /// 閉じる動きを走らせている(その終わりでだけ [_done]。ビルド中に value を 0 にしたときの dismissed では呼ばない)。
  bool _reversing = false;

  bool get _still => _reducedMotion(context) || !(widget.entry.fow?.motion ?? true);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final played = _fowEntered[widget.entry] ?? false;
    _fowEntered[widget.entry] = true;
    if (widget.leaving) {
      _c.value = 1;
      _leave();
    } else if (played || _still) {
      _c.value = 1;
    } else {
      _c.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(_FowMotion old) {
    super.didUpdateWidget(old);
    // 同じ id の差し替え(同じ Element を使い続ける): 開く動きは繰り返さない。
    if (!identical(old.entry, widget.entry)) _fowEntered[widget.entry] = true;
    if (widget.leaving && !old.leaving) {
      _leave();
    } else if (!widget.leaving && old.leaving) {
      _left = false;
      _reversing = false;
      if (_still) {
        _c.value = 1;
      } else {
        _c.forward();
      }
    }
  }

  void _leave() {
    if (_still || _c.value == 0) {
      _reversing = false;
      _c.value = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) => _done());
      return;
    }
    _reversing = true;
    _c.reverse();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && _reversing) {
      _reversing = false;
      _done();
    }
  }

  void _done() {
    if (_left || !mounted || !widget.leaving) return;
    _left = true;
    widget.onLeft?.call(widget.entry);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dir = widget.topSide ? -1.0 : 1.0;
    final travel = widget.anchored ? 12.0 : (widget.height * 0.12).clamp(24.0, 72.0);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        // 閉じるときの曲線は経過時間に掛ける(1 − exit(1 − t)): ゆっくり動き出して加速しながら抜ける。
        final v = _c.status == AnimationStatus.reverse ? 1 - kFowExitCurve.transform(1 - _c.value) : kFowMotionCurve.transform(_c.value);
        final scale = widget.anchored ? 0.94 + 0.06 * v : 1.0;
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          // 開きかけ(透明に近い間)も読み上げ / テストからは見える。
          alwaysIncludeSemantics: true,
          child: Transform(
            alignment: widget.topSide ? Alignment.topCenter : Alignment.bottomCenter,
            transform: Matrix4.translationValues(0, dir * travel * (1 - v), 0)..multiply(Matrix4.diagonal3Values(scale, scale, 1)),
            child: child,
          ),
        );
      },
      child: IgnorePointer(ignoring: widget.leaving, child: widget.child),
    );
  }
}

/// インタースティシャル / dimBehind の FOW のスクリム (D-476): 初めて出すときだけ FOW と一緒にフェードインする。
class _FowScrim extends StatelessWidget {
  const _FowScrim({required this.entry, required this.color});
  final RasqOverlayEntry entry;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final shown = _fowScrimShown[entry] ?? false;
    _fowScrimShown[entry] = true;
    final still = shown || _reducedMotion(context) || !(entry.fow?.motion ?? true);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: still ? 1 : 0, end: 1),
      duration: kFowMotionDuration,
      curve: kFowMotionCurve,
      builder: (context, t, _) => ColoredBox(color: color.withValues(alpha: color.a * t)),
    );
  }
}

/// stick FOW の本体の空いたところをタップすると展開モードへ (D-340)。stick にならない FOW では何もしない(認識器を置かない)。
class _StickExpandTap extends StatelessWidget {
  const _StickExpandTap({required this.spec, required this.child});
  final FowSpec spec;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!spec.canStick) return child;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        if (spec.isStick) spec.expandStick();
      },
      child: child,
    );
  }
}

/// Positions a dropdown next to its anchor, flipping horizontally/vertically
/// when it would overflow (「スクリーン端で位置反転」).
///
/// `LayoutBuilder → Positioned` の形は ParentDataWidget 違反(Positioned は
/// Stack の直下限定)で、開くたびに debug 例外が出ていた —
/// [CustomSingleChildLayout] のデリゲートで座標計算する形に修正 (D-039)。
class _AnchoredDropdown extends StatelessWidget {
  const _AnchoredDropdown({super.key, required this.anchor, required this.child});
  final Rect anchor;
  final Widget child;

  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: CustomSingleChildLayout(delegate: _DropdownLayout(anchor), child: child),
      );
}

class _DropdownLayout extends SingleChildLayoutDelegate {
  const _DropdownLayout(this.anchor);
  final Rect anchor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => BoxConstraints(
        maxWidth: constraints.maxWidth * 0.8,
        maxHeight: constraints.maxHeight * 0.6,
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final openDown = anchor.bottom + 200 <= size.height || anchor.top < size.height / 2;
    final openRight = anchor.left + 220 <= size.width;
    final top = openDown ? anchor.bottom : anchor.top - childSize.height;
    final left = openRight ? anchor.left : anchor.right - childSize.width;
    return Offset(
      left.clamp(0.0, (size.width - childSize.width).clamp(0.0, double.infinity)),
      top.clamp(0.0, (size.height - childSize.height).clamp(0.0, double.infinity)),
    );
  }

  @override
  bool shouldRelayout(_DropdownLayout oldDelegate) => oldDelegate.anchor != anchor;
}

/// stick の FOW のぶんカラムの中身を縮める (D-397)。畳まれた stick FOW がこのカラム([column] = 列スロットの index)の
/// 下端にある間は、中身をその高さだけ上に詰めて残りの場所に並べる(FOW に隠れない)。高さはホストが
/// [OverlayManager.fowStickReserve] に書く。stick を展開したとき / 閉じたときは元に戻る。
class FowStickPadding extends StatelessWidget {
  const FowStickPadding({super.key, required this.manager, this.column = 0, required this.child});
  final OverlayManager manager;
  final int column;
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Map<int, double>>(
        valueListenable: manager.fowStickReserve,
        // 部品の形は変えない(中身の State を作り直さない)。高さは FOW の高さのアニメーションと同じ速さで動かす。
        builder: (context, reserve, child) => AnimatedPadding(
          duration: kFowMotionDuration,
          curve: kFowMotionCurve,
          padding: EdgeInsets.only(bottom: reserve[column] ?? 0),
          child: child,
        ),
        child: child,
      );
}
