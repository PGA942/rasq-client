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
/// - しまったとき: バーもタブ行も無くし、TL の上に左のアイコン・**新着**(AsTell / Swing、どちらも届いてから 1 分だけ)・
///   右端の **↓**(出す)だけを浮かべる。しまったかは設定 `home.header` の `collapsed`(端末に残る)。

const homeHeaderArea = 'home.header';

final homeHeaderCollapsedProvider = Provider<bool>((ref) => ref.watch(settingsAreaProvider(homeHeaderArea)).value?['collapsed'] == true);

Future<void> setHomeHeaderCollapsed(WidgetRef ref, bool v) => ref.read(settingsAreaProvider(homeHeaderArea).notifier).set('collapsed', v);

/// Swing を出している人のバンドルの色(AsTell の黄色と見分ける)。
const swingBundleColor = RasqColors.link;

/// 新着 1 つ。
@immutable
class HeaderArrival {
  const HeaderArrival.astell(AstellRoom this.room, this.at) : swing = null;
  const HeaderArrival.swing(Swing this.swing, this.at) : room = null;
  final AstellRoom? room;
  final Swing? swing;
  final DateTime at;

  String get key => room != null ? 'astell:${room!.id}' : 'swing:${swing!.authorAccountId}';
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

/// 出しているヘッダーの真ん中: AsTell(下にルーム名)+ Swing(**1 人だけ**、D-378)。Swing は見ていないものがある人のうち
/// いちばん新しく出した人(誰も無ければ、見終えた人のうちいちばん新しい人)の、リング付きの顔。押すとビューワー。
class HomeHeaderStrip extends ConsumerWidget {
  const HomeHeaderStrip({super.key, this.astell = true, this.max = 4});

  /// AsTell を並べる(設定 / 見守りで止めていれば false)。
  final bool astell;
  final int max;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authors = ref.watch(swingApiProvider) != null ? ref.watch(swingAuthorsProvider) : const <SwingAuthorEntry>[];
    final trailing = [if (authors.isNotEmpty) SwingAuthorBundle(swing: authors.first.first, unseen: authors.first.unseen > 0)];
    if (astell) return AstellHeaderStrip(max: max, trailing: trailing, showTitles: true);
    if (trailing.isEmpty) return const SizedBox.shrink();
    return trailing.single;
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
                  : SwingAuthorBundle(swing: a.swing!, unseen: !a.swing!.seen),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ]),
    );
  }
}

