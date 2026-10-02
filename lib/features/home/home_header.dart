import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../app/router.dart';
import '../settings/settings_dsl.dart';
import '../swing/swing_models.dart';
import '../swing/swing_providers.dart';
import '../vc/astell_actions.dart';
import '../vc/astell_models.dart';
import '../vc/astell_providers.dart';

/// ホームのヘッダー (D-377)。
///
/// - 出しているとき: 左のアイコン / AsTell とSwing のバンドル(大きな角丸四角形は無し)/ 右上の **↑**(しまう)。
/// - しまったとき: バーもタブ行も無くし、TL の上に左のアイコンと**新着**(AsTell / Swing、どちらも届いてから 1 分だけ)だけを
///   浮かべる。D-410: 右端の ↓ は無くし、**浮かべたアイコンを押すとヘッダーを戻す**。しまったかは設定 `home.header` の
///   `collapsed`(端末に残る)。
/// - D-410: Swing の並びの先頭に**自分の Swing**(自分の顔 + 印、押すと自分の Swing のビューワー、見た人の数つき)。

const homeHeaderArea = 'home.header';

final homeHeaderCollapsedProvider = Provider<bool>((ref) => ref.watch(settingsAreaProvider(homeHeaderArea)).value?['collapsed'] == true);

Future<void> setHomeHeaderCollapsed(WidgetRef ref, bool v) => ref.read(settingsAreaProvider(homeHeaderArea).notifier).set('collapsed', v);

/// Swing を出している人のバンドルの色(AsTell の黄色と見分ける)。
const swingBundleColor = RasqColors.link;

/// 新着 1 つ。
@immutable
class HeaderArrival {
  const HeaderArrival.astell(AstellRoom this.room, this.at)
      : swing = null,
        mine = false;
  const HeaderArrival.swing(Swing this.swing, this.at, {this.mine = false}) : room = null;
  final AstellRoom? room;
  final Swing? swing;
  final DateTime at;

  /// 自分の Swing (D-410)。作ってから 1 分だけ、ほかの人の新着と同じに浮かべる。
  final bool mine;

  String get key => room != null ? 'astell:${room!.id}' : (mine ? 'swing:me' : 'swing:${swing!.authorAccountId}');
}

/// 新着の AsTell(フォロー中のホスト / 招待)と Swing(作った人ごと)。届いてから [window] だけ。
/// 起動して最初に読めたものは「前からあった」扱い(ただし作られて [window] 以内なら新着)。
class HeaderArrivals extends Notifier<List<HeaderArrival>> {
  static Duration window = const Duration(minutes: 1);

  /// テストで時計を差し替える。
  static DateTime Function() now = DateTime.now;

  final _known = <String>{};
  bool _astellBase = false;
  bool _swingBase = false;
  bool _mineBase = false;
  Timer? _prune;

  /// いまの新着(build の中の listen からも触るので、state とは別に持つ)。
  var _cur = <HeaderArrival>[];
  bool _built = false;

  void _set(List<HeaderArrival> next) {
    _cur = next;
    if (_built) state = next;
  }

  @override
  List<HeaderArrival> build() {
    _built = false;
    ref.onDispose(() => _prune?.cancel());
    ref.listen(astellHomeProvider, (_, next) {
      final home = next.value;
      if (home != null) _rooms([...home.following, ...home.invited]);
    }, fireImmediately: true);
    ref.listen(swingFeedProvider, (_, next) {
      final feed = next.value;
      if (feed != null) _swings(feed);
    }, fireImmediately: true);
    ref.listen(mySwingsProvider, (_, next) {
      final mine = next.value;
      if (mine != null) _mine(mine);
    }, fireImmediately: true);
    _built = true;
    return _cur;
  }

  bool _fresh(DateTime created) => now().difference(created) < window;

  void _rooms(List<AstellRoom> rooms) {
    final add = <HeaderArrival>[];
    for (final r in rooms) {
      if (!r.isOpen) continue;
      if (_known.add('astell:${r.id}') && (_astellBase || _fresh(r.createdAt))) add.add(HeaderArrival.astell(r, now()));
    }
    _astellBase = true;
    _add(add);
  }

  void _swings(List<Swing> feed) {
    final add = <HeaderArrival>[];
    for (final s in feed) {
      if (_known.add('swing:${s.id}') && (_swingBase || _fresh(s.createdAt)) && !add.any((a) => a.swing?.authorAccountId == s.authorAccountId)) {
        add.add(HeaderArrival.swing(s, now()));
      }
    }
    _swingBase = true;
    _add(add);
  }

  /// 自分の Swing (D-410): 新しく出したもの(いちばん新しい 1 つ)を 1 分だけ。
  void _mine(List<Swing> mine) {
    HeaderArrival? add;
    for (final s in mine) {
      if (_known.add('swing:${s.id}') && (_mineBase || _fresh(s.createdAt)) && (add == null || s.createdAt.isAfter(add.swing!.createdAt))) {
        add = HeaderArrival.swing(s, now(), mine: true);
      }
    }
    _mineBase = true;
    _add([?add]);
  }

  void _add(List<HeaderArrival> add) {
    final keep = [for (final a in _cur) if (!add.any((b) => b.key == a.key)) a];
    _set([...keep, ...add].where((a) => now().difference(a.at) < window).toList());
    _schedule();
  }

  void _schedule() {
    _prune?.cancel();
    if (_cur.isEmpty) return;
    final first = _cur.map((a) => a.at).reduce((x, y) => x.isBefore(y) ? x : y);
    final wait = first.add(window).difference(now());
    _prune = Timer(wait.isNegative ? Duration.zero : wait + const Duration(milliseconds: 10), () {
      _set([for (final a in _cur) if (now().difference(a.at) < window) a]);
      _schedule();
    });
  }
}

final headerArrivalsProvider = NotifierProvider<HeaderArrivals, List<HeaderArrival>>(HeaderArrivals.new);

/// Swing を出している人 (D-379): アカウントのアイコンの外側にリング。**見ていないものがあれば青、見終えたら白**。
/// タップでビューワー(その人から)。
class SwingAuthorBundle extends StatelessWidget {
  const SwingAuthorBundle({super.key, required this.swing, this.unseen = true, this.size = 34});
  final Swing swing;
  final bool unseen;
  final double size;

  /// 見終えたあとのリングの色。暗い背景でも見えるよう、明るいモードでは薄い灰色の縁を足す。
  static const seenRing = Colors.white;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const ring = 3.0;
    return Tooltip(
      message: unseen ? '${swing.author.displayName} の Swing' : '${swing.author.displayName} の Swing(見終えました)',
      child: InkResponse(
        key: ValueKey('swing.bundle.${swing.authorAccountId}'),
        onTap: () => context.push(Routes.swing(swing.authorAccountId)),
        radius: size / 2 + ring + 2,
        child: Container(
          key: ValueKey('swing.ring.${unseen ? 'unseen' : 'seen'}'),
          width: size + ring * 2 + 2,
          height: size + ring * 2 + 2,
          padding: const EdgeInsets.all(1),
          decoration: BoxDecoration(shape: BoxShape.circle, color: unseen ? swingBundleColor : scheme.outlineVariant),
          child: Container(
            padding: const EdgeInsets.all(ring - 1),
            decoration: BoxDecoration(shape: BoxShape.circle, color: unseen ? swingBundleColor : seenRing),
            child: ClipOval(child: RasqAvatar(imageUrl: swing.author.avatarUrl, size: size, fallbackLabel: swing.author.displayName)),
          ),
        ),
      ),
    );
  }
}

/// 自分の Swing (D-410): 自分の顔のまわりに**緑のリング**と、右下に出している数の印。押すと自分の Swing のビューワー
/// (見た人の数つき)。
class MySwingBundle extends StatelessWidget {
  const MySwingBundle({super.key, required this.swings, this.size = 34});

  /// 出している Swing(1 つ以上)。
  final List<Swing> swings;
  final double size;

  static const ringColor = RasqColors.inVc;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final me = swings.first.author;
    const ring = 3.0;
    final outer = size + ring * 2 + 2;
    return Tooltip(
      message: '自分の Swing(${swings.length} 個)',
      child: Semantics(
        button: true,
        label: '自分の Swing',
        child: InkResponse(
          key: const ValueKey('swing.bundle.me'),
          onTap: () => context.push(Routes.mySwings),
          radius: size / 2 + ring + 2,
          child: SizedBox(
            width: outer,
            height: outer,
            child: Stack(clipBehavior: Clip.none, children: [
              Container(
                key: const ValueKey('swing.ring.me'),
                width: outer,
                height: outer,
                padding: const EdgeInsets.all(ring),
                decoration: const BoxDecoration(shape: BoxShape.circle, color: ringColor),
                child: Container(
                  padding: const EdgeInsets.all(1),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.surface),
                  child: ClipOval(child: RasqAvatar(imageUrl: me.avatarUrl, size: size - 2, fallbackLabel: me.displayName)),
                ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  key: const ValueKey('swing.me.count'),
                  constraints: const BoxConstraints(minWidth: 16),
                  height: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: ringColor, borderRadius: BorderRadius.circular(8), border: Border.all(color: scheme.surface, width: 1.5)),
                  child: Text('${swings.length}', style: RasqTypography.caption.copyWith(color: Colors.white, fontSize: 10, height: 1, fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// 出しているヘッダーの真ん中: AsTell(下にルーム名)+ Swing(自分 → ほかの人は **1 人だけ**、D-378)。Swing は見ていないものがある人のうち
/// いちばん新しく出した人(誰も無ければ、見終えた人のうちいちばん新しい人)の、リング付きの顔。押すとビューワー。
class HomeHeaderStrip extends ConsumerWidget {
  const HomeHeaderStrip({super.key, this.astell = true, this.max = 4});

  /// AsTell を並べる(設定 / 見守りで止めていれば false)。
  final bool astell;
  final int max;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(swingApiProvider) != null;
    final authors = api ? ref.watch(swingAuthorsProvider) : const <SwingAuthorEntry>[];
    // D-410: 自分の Swing を先頭に。
    final mine = api ? (ref.watch(mySwingsProvider).value ?? const <Swing>[]) : const <Swing>[];
    final trailing = [
      if (mine.isNotEmpty) MySwingBundle(swings: mine),
      if (authors.isNotEmpty) SwingAuthorBundle(swing: authors.first.first, unseen: authors.first.unseen > 0),
    ];
    // D-388: チップを大きく(30 → 40)、名前はアイコンの下辺に載せる。
    if (astell) return AstellHeaderStrip(max: max, size: 40, trailing: trailing, showTitles: true);
    if (trailing.isEmpty) return const SizedBox.shrink();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (final (i, w) in trailing.indexed) ...[if (i > 0) const SizedBox(width: 8), w],
    ]);
  }
}

/// しまったヘッダーの新着(浮かべる)。AsTell はタップで参加 FOW、Swing はビューワー。
class HomeHeaderArrivals extends ConsumerWidget {
  const HomeHeaderArrivals({super.key, this.astell = true});
  final bool astell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arrivals = [for (final a in ref.watch(headerArrivalsProvider)) if (astell || a.room == null) a];
    if (arrivals.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      key: const ValueKey('home.header.arrivals'),
      scrollDirection: Axis.horizontal,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final a in arrivals) ...[
          Material(
            key: ValueKey('home.header.arrival.${a.key}'),
            color: scheme.surface,
            elevation: 3,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: a.room != null
                  ? RasqAvatarBundle(user: a.room!.owner, count: a.room!.peerCount, faces: a.room!.bundleFaces, live: a.room!.live, size: 34, onTap: () => openAstellRoomTile(context, ref, a.room!))
                  : a.mine
                      ? MySwingBundle(swings: [...?ref.watch(mySwingsProvider).value].isEmpty ? [a.swing!] : ref.watch(mySwingsProvider).value!)
                      : SwingAuthorBundle(swing: a.swing!, unseen: !a.swing!.seen),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ]),
    );
  }
}

