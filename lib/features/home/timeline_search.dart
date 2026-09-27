import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart' show TimelineKind;

import 'timeline_providers.dart';

/// タイムライン本体から探す (D-338 → D-341)。TL の一時変更 FOW の検索欄の語。**TL は絞らない**: 合う投稿へ ↑↓ で
/// 飛び、飛んだ先を一瞬ホバーの見た目にする。
@immutable
class TimelineSearchQuery {
  const TimelineSearchQuery(this.query, {this.fuzzy = false});
  final String query;

  /// 近似検索(ひらがな / カタカナ、全角 / 半角を同じに見て、少しの打ち間違いも拾う)。
  final bool fuzzy;
}

/// TL の id(`home` / `node:…` / `list:…`)→ 探す語。保存しない(一時変更 FOW を閉じると消える)。
class TimelineSearch extends Notifier<Map<String, TimelineSearchQuery>> {
  @override
  Map<String, TimelineSearchQuery> build() => const {};

  void setQuery(String timelineId, String query) {
    final q = query.trim();
    final fuzzy = state[timelineId]?.fuzzy ?? false;
    state = q.isEmpty ? ({...state}..remove(timelineId)) : {...state, timelineId: TimelineSearchQuery(q, fuzzy: fuzzy)};
  }

  /// 近似検索の切り替え。語がまだ無くても覚えておく(空の語は探さない)。
  void setFuzzy(String timelineId, bool fuzzy) {
    _fuzzy[timelineId] = fuzzy;
    final cur = state[timelineId];
    if (cur != null) state = {...state, timelineId: TimelineSearchQuery(cur.query, fuzzy: fuzzy)};
  }

  bool fuzzyOf(String timelineId) => state[timelineId]?.fuzzy ?? _fuzzy[timelineId] ?? false;
  final _fuzzy = <String, bool>{};

  void clearAll() {
    _fuzzy.clear();
    state = const {};
  }
}

final timelineSearchProvider = NotifierProvider<TimelineSearch, Map<String, TimelineSearchQuery>>(TimelineSearch.new);

/// 探すときの見比べ用の形: 小文字、全角英数 → 半角、カタカナ → ひらがな。[squash] = 空白も除く(近似検索)。
String timelineSearchNormalize(String s, {bool squash = false}) {
  final out = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    var c = r;
    if (c >= 0xFF01 && c <= 0xFF5E) c -= 0xFEE0; // 全角英数記号 → 半角
    if (c == 0x3000) c = 0x20; // 全角空白
    if (c >= 0x30A1 && c <= 0x30F6) c -= 0x60; // カタカナ → ひらがな
    if (squash && (c == 0x20 || c == 0x0A || c == 0x09)) continue;
    out.writeCharCode(c);
  }
  return out.toString().toLowerCase();
}

/// [pattern] が [text] のどこかに、編集距離 [maxEdits] 以内で入っているか(Sellers の近似部分一致、O(長さの積))。
bool approxContains(String text, String pattern, int maxEdits) {
  final p = pattern.runes.toList();
  final t = text.runes.toList();
  if (p.isEmpty) return true;
  var prev = List<int>.generate(p.length + 1, (i) => i);
  if (prev.last <= maxEdits) return true;
  for (final c in t) {
    final cur = List<int>.filled(p.length + 1, 0); // 先頭はどこから始めてもよい(0)
    for (var i = 1; i <= p.length; i++) {
      final sub = prev[i - 1] + (p[i - 1] == c ? 0 : 1);
      final del = prev[i] + 1;
      final ins = cur[i - 1] + 1;
      cur[i] = sub < del ? (sub < ins ? sub : ins) : (del < ins ? del : ins);
    }
    if (cur.last <= maxEdits) return true;
    prev = cur;
  }
  return false;
}

/// [query] に合う投稿か。本文・注意書き・名前・ハンドル・リノートした人・引用を見る。空白区切りは全部を含むもの。
/// [fuzzy] = 近似検索: かな / 全角半角を同じに見て、3 文字以上の語は 4 文字に 1 つまでの打ち間違いを許す。
bool timelinePostMatches(Post p, String query, {bool fuzzy = false}) {
  final raw = [
    p.body,
    p.contentWarning ?? '',
    p.author.displayName,
    p.author.handle,
    p.repostedBy?.displayName ?? '',
    p.quote?.body ?? '',
    p.quote?.author.displayName ?? '',
  ].join('\n');
  if (!fuzzy) {
    final hay = raw.toLowerCase();
    return query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).every(hay.contains);
  }
  final hay = timelineSearchNormalize(raw, squash: true);
  return timelineSearchNormalize(query).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).every((w) {
    final len = w.runes.length;
    return hay.contains(w) || (len >= 3 && approxContains(hay, w, (len ~/ 4).clamp(1, 3)));
  });
}

/// 合う投稿のキー(TL の上から順)。
final timelineSearchMatchesProvider = Provider.family<List<String>, String>((ref, timelineId) {
  final q = ref.watch(timelineSearchProvider.select((m) => m[timelineId]));
  if (q == null) return const [];
  final posts = ref.watch(timelineProvider(TimelineKind(timelineId, timelineId))).value?.posts ?? const <Post>[];
  return [for (final p in posts) if (timelinePostMatches(p, q.query, fuzzy: q.fuzzy)) p.key];
});

/// ↑↓ の頼み(FOW → TL の画面)。[dir] = -1 上 / +1 下。
@immutable
class TimelineSearchNav {
  const TimelineSearchNav(this.timelineId, this.dir, this.seq);
  final String timelineId;
  final int dir;
  final int seq;
}

class TimelineSearchNavigator extends Notifier<TimelineSearchNav?> {
  @override
  TimelineSearchNav? build() => null;
  void go(String timelineId, int dir) => state = TimelineSearchNav(timelineId, dir, (state?.seq ?? 0) + 1);
}

final timelineSearchNavProvider = NotifierProvider<TimelineSearchNavigator, TimelineSearchNav?>(TimelineSearchNavigator.new);

/// いま飛んでいる投稿(TL の id → 投稿のキー)。TL の画面が飛んだあとに書く。FOW の「i / N」に出す。
class TimelineSearchCursor extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() {
    // 探す語が変わったら、飛んでいた位置は外す(合う投稿の並びが変わる)。
    ref.listen(timelineSearchProvider, (_, _) => state = const {});
    return const {};
  }

  void set(String timelineId, String key) => state = {...state, timelineId: key};
}

final timelineSearchCursorProvider = NotifierProvider<TimelineSearchCursor, Map<String, String>>(TimelineSearchCursor.new);

/// TL の画面側で ↑↓ を受けて飛ぶ (D-341)。行を [TimelineSearchRow] で包んで登録し、[jump] でスクロールする。
/// 行は遅延で作られるので、まだ作られていない投稿へは、作られている行の高さの平均から見当を付けて近づき、作られたら
/// その行が見えるところまで動かす(TL の中身はそのまま)。
class TimelineJumpController {
  final _rows = <String, BuildContext>{};

  /// 一瞬ホバーの見た目にしている投稿。
  final flashing = ValueNotifier<String?>(null);
  Timer? _flashTimer;

  void _register(String key, BuildContext context) => _rows[key] = context;
  void _unregister(String key, BuildContext context) {
    if (identical(_rows[key], context)) _rows.remove(key);
  }

  void dispose() {
    _flashTimer?.cancel();
    flashing.dispose();
  }

  RenderBox? _box(String key) {
    final ctx = _rows[key];
    if (ctx == null || !ctx.mounted) return null;
    final ro = ctx.findRenderObject();
    return ro is RenderBox && ro.attached && ro.hasSize ? ro : null;
  }

  /// 画面の上端にかかっている(または上端より下で最初の)投稿の位置。作られた行が無ければ null。
  int? _firstVisible(List<String> order, ScrollController scroll) {
    if (!scroll.hasClients) return null;
    final viewport = scroll.position.context.notificationContext?.findRenderObject();
    if (viewport is! RenderBox) return null;
    final top = viewport.localToGlobal(Offset.zero).dy;
    int? best;
    for (final e in _rows.entries) {
      final box = _box(e.key);
      if (box == null) continue;
      final bottom = box.localToGlobal(Offset(0, box.size.height)).dy;
      if (bottom <= top + 1) continue;
      final i = order.indexOf(e.key);
      if (i >= 0 && (best == null || i < best)) best = i;
    }
    return best;
  }

  /// 次(dir = +1)/ 前(-1)の合う投稿のキー。[current] が合う投稿の中に無ければ、いま見えている位置から探す。
  String? pick({required List<String> order, required List<String> matches, required String? current, required int dir, required ScrollController scroll}) {
    if (matches.isEmpty) return null;
    final at = current == null ? -1 : matches.indexOf(current);
    if (at >= 0) {
      final next = at + dir;
      return next >= 0 && next < matches.length ? matches[next] : null;
    }
    final visible = _firstVisible(order, scroll) ?? 0;
    if (dir > 0) return matches.firstWhere((k) => order.indexOf(k) >= visible, orElse: () => matches.last);
    return matches.lastWhere((k) => order.indexOf(k) < visible, orElse: () => matches.first);
  }

  /// [key] の投稿が見えるところまで動かし、一瞬ホバーの見た目にする。見つからなければ false。
  Future<bool> jump(String key, {required List<String> order, required ScrollController scroll}) async {
    final target = order.indexOf(key);
    if (target < 0) return false;
    for (var attempt = 0; attempt < 40; attempt++) {
      final ctx = _rows[key];
      if (ctx != null && ctx.mounted && _box(key) != null) {
        await Scrollable.ensureVisible(ctx, alignment: 0.15, duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
        _flash(key);
        return true;
      }
      if (!scroll.hasClients) return false;
      // まだ作られていない: いちばん近い行と平均の高さから見当を付けて近づく。
      int? nearIndex;
      RenderBox? nearBox;
      var total = 0.0;
      var count = 0;
      for (final e in _rows.entries) {
        final box = _box(e.key);
        final i = order.indexOf(e.key);
        if (box == null || i < 0) continue;
        total += box.size.height;
        count++;
        if (nearIndex == null || (i - target).abs() < (nearIndex - target).abs()) {
          nearIndex = i;
          nearBox = box;
        }
      }
      if (nearBox == null || count == 0) return false;
      final viewport = RenderAbstractViewport.maybeOf(nearBox);
      if (viewport == null) return false;
      final reveal = viewport.getOffsetToReveal(nearBox, 0).offset;
      final pos = scroll.position;
      final guess = (reveal + (target - nearIndex!) * (total / count)).clamp(pos.minScrollExtent, pos.maxScrollExtent);
      if ((guess - pos.pixels).abs() < 1 && attempt > 0) {
        // 端に着いても作られない。
        return false;
      }
      scroll.jumpTo(guess);
      await WidgetsBinding.instance.endOfFrame;
    }
    return false;
  }

  void _flash(String key) {
    _flashTimer?.cancel();
    flashing.value = key;
    _flashTimer = Timer(const Duration(milliseconds: 700), () => flashing.value = null);
  }
}

/// TL の 1 行を [TimelineJumpController] に登録し、飛んだ先になったら一瞬ホバーの見た目(テーマのホバーの色を重ねる)にする。
class TimelineSearchRow extends StatefulWidget {
  const TimelineSearchRow({super.key, required this.controller, required this.postKey, required this.child});
  final TimelineJumpController controller;
  final String postKey;
  final Widget child;

  @override
  State<TimelineSearchRow> createState() => _TimelineSearchRowState();
}

class _TimelineSearchRowState extends State<TimelineSearchRow> {
  @override
  void initState() {
    super.initState();
    widget.controller._register(widget.postKey, context);
  }

  @override
  void didUpdateWidget(TimelineSearchRow old) {
    super.didUpdateWidget(old);
    if (old.postKey != widget.postKey || old.controller != widget.controller) {
      old.controller._unregister(old.postKey, context);
      widget.controller._register(widget.postKey, context);
    }
  }

  @override
  void dispose() {
    widget.controller._unregister(widget.postKey, context);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      widget.child,
      Positioned.fill(
        child: IgnorePointer(
          child: ValueListenableBuilder<String?>(
            valueListenable: widget.controller.flashing,
            builder: (context, key, _) => AnimatedOpacity(
              key: key == widget.postKey ? const ValueKey('tl.search.flash') : null,
              opacity: key == widget.postKey ? 1 : 0,
              duration: Duration(milliseconds: key == widget.postKey ? 60 : 260),
              child: ColoredBox(color: Theme.of(context).hoverColor),
            ),
          ),
        ),
      ),
    ]);
  }
}

/// TL の画面で ↑↓ の頼みを受ける: 合う投稿を選んで飛び、飛んだ位置を覚える。
Future<void> handleTimelineSearchNav(WidgetRef ref, TimelineSearchNav nav, {required TimelineJumpController jumper, required ScrollController scroll, required List<Post> posts, Future<void> Function(String key)? beforeJump}) async {
  final id = nav.timelineId;
  final matches = ref.read(timelineSearchMatchesProvider(id));
  final order = [for (final p in posts) p.key];
  final key = jumper.pick(order: order, matches: matches, current: ref.read(timelineSearchCursorProvider)[id], dir: nav.dir, scroll: scroll);
  if (key == null) return;
  await beforeJump?.call(key);
  ref.read(timelineSearchCursorProvider.notifier).set(id, key);
  await jumper.jump(key, order: order, scroll: scroll);
}
