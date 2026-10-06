import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rrl_core/rrl_core.dart';
import 'package:rrl_renderer/rrl_renderer.dart';

import '../../app/providers.dart' show overlayManagerProvider;
import '../../app/router.dart';
import '../../shell/column_layout.dart' show swingInColumnProvider;
import '../../shell/column_takeover.dart' show takeoverColumnOf;
import '../../shell/third_column.dart' show openPageInPanes, paneBack;
import '../ads/export_ad.dart';
import '../ads/timeline_ads.dart' show timelineAdsOn;
import '../vc/astell_models.dart' show astellReportReasons;
import '../custom/custom_page.dart';
import '../media/fow_avoid.dart';
import '../media/video_player.dart';
import '../plugins/slot_plugins.dart';
import 'swing_models.dart';
import 'swing_providers.dart';
import 'swing_bar.dart';
import '../../backend/rasq_account_page_api.dart' show rasqAccountPageApiProvider, rasqThreadProvider;
import '../profile/rasq_post_tile.dart' show RasqPostOverlayActions;

/// Swing のビューワー (D-377 / D-379)。全画面、**左右のスワイプ**で次 / 前の Swing(と広告)へ。マウス / トラックパッドの
/// ドラッグでも動く(Mac 版で縦のスワイプが効かなかった)。
///
/// - 並びは [swingViewerQueue](押した人の Swing → ほかの人の見ていないもの)。開いた時点のフィードで並べる。
/// - **時間で次へ**: テキスト / 画像は [displayDuration]、動画は終わったら。プラグインと広告は自分では進まない。
///   **中央をタップで一時停止 / 再開**、左端 / 右端のタップで前 / 次。
/// - **見終えた** = その Swing を離れた / 閉じた / プラグインが `page.end` を呼んだ。Central へ送る(ヘッダーのリングが白になる)。
/// - **広告** (D-445、前は Swing 5 個ごとに固定): 次の Swing へ移るあいだに 1 枚(広告を出せる端末とアカウントだけ)。見終えの記録なし。
///   - いつ: Swing を [adForceAfter] 以上見ていなかった(この起動で初めて含む)なら、**最初の Swing から移るところで必ず**。
///     ほかは [adSwipesMin]〜[adSwipesMax] 回のスワイプに 1 回(数はランダム)。
///   - **両隣が CW / センシティブでない**ところだけ(D-395 の `adSafe` も。危なければ次の安全なところへずらす)。
///   - 置くのは、着いた Swing の**次**(先に並びへ足す)。通り過ぎた広告は並びから外すので、**前の Swing に戻るときは出ない**。
///   - 中身: 移っている間は「広告」の表記だけ(プレビュー)。止まったら、読んでおいた**全画面の動画の広告**を出し、閉じたら
///     次の Swing へ。全画面の広告が無ければ、**縦長のバナー**(高さの 70% まで)。
/// - **CW / センシティブ** (D-395): ぼかして覆い、「表示する」を押すまで中身を出さない。覆っている間は時計を回さず、
///   動画 / プラグインも動かさない。
/// - **通報** (D-395): ヘッダーの旗から理由を選んで `POST /reports {swingId}`。通報した Swing はこの回の間、広告の隣に置かない
///   扱いにする(並びは開いた時点で決めているので、記録するだけ)。
/// - **プラグイン**(ページ型、契約 v0.19。v0.20 / D-424 から親子関係の無いものは swing の宣言なし・shared も。shared は作った人のセッションに入る): 全画面で動かし、その間は**スワイプで移れない**。
///   「全画面から縮小」を押すと、ぼかして止め(`page.event paused`)、スワイプで移れるようにする。縮小したものを押すと
///   全画面に戻る(`resumed`)。
///
/// D-413: **幅の広い画面では第3カラム**に開く([openSwingViewer]。狭い画面は前のとおり全画面)。**Swing の下に返信が続く**
/// (D-389 のスレッド = 返信の一覧と返信の欄。下へスクロールすると出る。左下の欄のハンドル / 入力欄もそこへ送る)。
///
/// D-420: 下の UI を **stick FOW** ([SwingBar]) にまとめた。カラムの下端に付き、シークバー・返信の欄・返信 N・キュー。
/// 返信の欄を押すと FOW が返信のコンポーザー(返信先のタイル付き)に、返信 N でスレッドに広がり、Swing の面は残りへ縮む
/// ([FowAvoidingBox])。D-413 の「Swing の下に続くスレッド」(縦スクロール)はこの FOW のスレッドに置き換えた。
///
/// D-410: [mine] = **自分の Swing**(ヘッダーの自分の顔から)。`GET /me/swings` の並び(古い順)で、広告・見終えの記録・
/// 通報は無し、作った人だけが見られる**見た人の数**(`viewCount`)を出す。
class SwingViewerScreen extends ConsumerStatefulWidget {
  const SwingViewerScreen({super.key, this.startAuthor, this.mine = false});

  /// 作った人の accountId。
  final String? startAuthor;

  /// 自分の Swing を見る (D-410)。
  final bool mine;

  /// 広告の間のスワイプの数 (D-445)。
  static const adSwipesMin = 5;
  static const adSwipesMax = 7;

  /// これ以上 Swing を見ていなければ、最初の Swing から移るところで広告 (D-445)。
  static const adForceAfter = Duration(minutes: 10);

  /// 広告の間のスワイプの数を決める乱数(テストで差し替える)。
  static math.Random adRandom = math.Random();

  /// 最後に Swing を見ていた時刻(この起動の間)。null = この起動ではまだ見ていない。
  static DateTime? lastViewedAt;

  /// 今の時刻(テストで差し替える)。
  static DateTime Function() now = DateTime.now;

  /// 縦長のバナーの高さの上限(画面の高さに対して)。
  static const adBannerHeightFactor = 0.7;

  /// テキスト / 画像を出しておく時間(テストで null = 時間では進まない)。
  static Duration? displayDuration = const Duration(seconds: 6);

  @override
  ConsumerState<SwingViewerScreen> createState() => _SwingViewerScreenState();
}

/// ビューワーの Swing の面(下の FOW のぶん縮む。テストで矩形を測る、D-420)。
const swingViewerMediaKey = ValueKey('swing.viewer.media');

/// 第3カラムに開いた回数(同じ人を開き直したら、並びを作り直す)。
int _paneSerial = 0;

/// Swing のビューワーを開く: 既定は**全画面**のルート (D-437)。「カラムの幅」で「Swing を第3カラムで開く」を選んでいれば、
/// 幅の広い画面では**第3カラム**(D-413。第3カラムのページは第2カラムへ移る、D-057)。[mine] = 自分の Swing (D-410)。
void openSwingViewer(BuildContext context, {String? author, bool mine = false}) {
  final id = 'swing:${mine ? 'me' : author ?? ''}#${++_paneSerial}';
  // 既定は全画面 (D-437)。第3カラムに開くのは「カラムの幅」で選んだときだけ。
  final inColumn = ProviderScope.containerOf(context, listen: false).read(swingInColumnProvider);
  if (inColumn && openPageInPanes(
    context,
    id: id,
    title: 'Swing',
    location: Routes.swingInHome(author: author, mine: mine),
    builder: (_) => SwingViewerScreen(key: ValueKey(id), startAuthor: author, mine: mine),
  )) {
    return;
  }
  context.push(mine ? Routes.mySwings : Routes.swing(author));
}

/// 1 ページ = Swing か広告。
@immutable
class SwingViewerItem {
  const SwingViewerItem.swing(Swing this.swing)
      : ad = false,
        serial = 0;
  const SwingViewerItem.ad(this.serial)
      : swing = null,
        ad = true;
  final Swing? swing;
  final bool ad;

  /// 広告の通し番号(ページの鍵)。
  final int serial;

  Key get key => ad ? ValueKey('swing.ad.$serial') : ValueKey('swing.page.${swing!.id}');
}

/// 広告の隣に置いてよい Swing か (D-395 / D-445): `adSafe`(通報 / 未審査のプラグイン / 運営の止め)に加え、CW もセンシティブも無い。
bool swingAdNeighborSafe(Swing s) => s.adSafe && (s.cw?.trim().isEmpty ?? true) && !s.sensitive;

class _SwingViewerScreenState extends ConsumerState<SwingViewerScreen> with SingleTickerProviderStateMixin {
  late final List<SwingViewerItem> _items;

  // ── 広告 (D-445) ──
  bool _adsOn = false;

  /// 次の広告までのスワイプの数(1 以下なら、着いた Swing の次に置く)。
  int _adCountdown = 0;
  int _adSerial = 0;

  /// 離れた広告(スクロールが止まったら並びから外す)。
  int? _leftAd;

  /// 並びを詰めて飛んだときの onPageChanged を無視する。
  bool _suppressPage = false;

  /// 読んでおいた全画面の広告。
  Future<bool>? _fullscreenReady;
  late final PageController _pages;
  late final AnimationController _clock = AnimationController(vsync: this)..addStatusListener(_onClock);
  int _index = 0;

  /// いまのプラグインが全画面で動いている(スワイプで移れない)。
  bool _locked = false;

  /// 中央のタップで止めている。
  bool _paused = false;

  /// 止めている理由 (D-389 / D-420): 下の FOW を広げている(`reply` = コンポーザー / スレッド)、キューのピッカー(`queue`)、
  /// シークバーを引いている(`seek`)、通報の理由を選んでいる(`report`)。どれかがあれば止める。
  final _holds = <String>{};
  bool get _held => _holds.isNotEmpty;

  /// 閉じる / 移るで見終えを送ったか(カラムから外されたときに送る、D-413)。
  bool _closed = false;
  late final SwingFeed _feed;

  /// 「表示する」を押した CW / センシティブの Swing (D-395)。
  final _revealed = <String>{};

  /// この回で通報した Swing (D-395)。広告の隣に置かない扱い(並びは開いた時点のままなので、記録だけ)。
  final _reported = <String>{};

  bool _coveredNow(Swing s) => s.covered && !_revealed.contains(s.id);

  // ── 下の stick FOW (D-420) ──
  late final SwingBarController _bar = SwingBarController()
    ..onHold = _hold
    ..addListener(_onBarMode);
  OverlayManager? _manager;
  FowSpec? _barSpec;

  /// 動画の Swing の再生(ページが作る。id → 再生)。
  final _seekables = <String, SwingSeekable>{};
  bool _barSyncQueued = false;
  SwingBarMode _barMode = SwingBarMode.compact;

  /// FOW を置く高さ(ウィンドウからキーボードを引いた高さ。FOW の高さの比はこれに対して)。
  double _avail = 0;

  double _bottomPad = 0;

  /// このビューワーの画面がいちばん上にある(上にほかの画面が載っていれば FOW を出さない)。
  bool _routeCurrent = true;

  /// 高さを書いているところ(FOW のハンドルで動かしたのと区別する)。
  bool _settingHeight = false;

  void _registerSeekable(String id, SwingSeekable v, bool alive) {
    if (alive) {
      _seekables[id] = v;
    } else if (identical(_seekables[id], v)) {
      _seekables.remove(id);
    }
    _queueBarSync();
  }

  void _queueBarSync() {
    if (_barSyncQueued || !mounted) return;
    _barSyncQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _barSyncQueued = false;
      _syncBar();
    });
  }

  /// 下の FOW を出す / 閉じる / 中身を書き換える。全画面で動いているプラグイン・広告・ほかの画面が上にあるときは出さない。
  void _syncBar() {
    if (!mounted) return;
    final s = _current;
    final timed = s != null && (s.kind == SwingKind.text || s.kind == SwingKind.image);
    _bar.show(
      swing: s == null || _locked ? null : s,
      reply: s != null && _replyShown(s),
      video: s == null ? null : _seekables[s.id],
      clock: timed ? _clock : null,
    );
    final show = _routeCurrent && _bar.hasContent;
    final manager = ref.read(overlayManagerProvider);
    _manager = manager;
    if (!show) return _closeBar();
    _applyBarHeight();
    if (_barSpec != null && manager.contains(SwingBar.fowId)) return;
    final stops = _barStops();
    final spec = _barSpec = FowSpec(
      type: FowPanelType.widget,
      columnIndex: takeoverColumnOf(context),
      initialHeightFactor: stops.first,
      minHeightFactor: 0.04,
      maxHeightFactor: 0.9,
      heightStops: stops,
      stickCollapse: true,
      bodyMove: false,
      avoidKeyboard: true,
    );
    // stick は自分の形で答える(畳んだ形 = stick。カラムを縮める D-397 もこれを見る)。ハンドル / 空いたところ = スレッドへ。
    spec.stickState = () => _bar.mode == SwingBarMode.compact;
    spec.onExpandStick = () => _bar.setMode(SwingBarMode.thread);
    spec.heightFactor.addListener(_onBarDrag);
    unawaited(manager.showFow<void>(
      id: SwingBar.fowId,
      spec: spec,
      semanticsLabel: 'Swing の返信とシークバー',
      builder: (ctx, handle) => SwingViewerBar(controller: _bar, spec: spec),
    ).whenComplete(() {
      spec.heightFactor.removeListener(_onBarDrag);
      if (identical(_barSpec, spec)) _barSpec = null;
    }));
  }

  void _closeBar() {
    final manager = _manager;
    _barSpec = null;
    if (manager != null && !manager.disposed && manager.contains(SwingBar.fowId)) manager.close(SwingBar.fowId);
  }

  /// 高さの段: [畳んだ形, スレッド]。
  List<double> _barStops() {
    final avail = _avail > 0 ? _avail : 800.0;
    final compact = SwingBar.compactHeight(seek: _bar.hasSeek, reply: _bar.reply) + _bottomPad;
    final c = (compact / avail).clamp(0.04, 0.5);
    return [c, SwingBar.threadFactor < c ? c : SwingBar.threadFactor];
  }

  /// いまの形の高さにする。
  void _applyBarHeight() {
    final spec = _barSpec;
    if (spec == null) return;
    final stops = _barStops();
    final avail = _avail > 0 ? _avail : 800.0;
    spec.heightStops = stops;
    final target = switch (_bar.mode) {
      SwingBarMode.compact => stops.first,
      // コンポーザーが測った高さ (D-421: 添付 / 投票で伸びる)。
      SwingBarMode.compose => ((_bar.composeHeight + _bottomPad) / avail).clamp(stops.first, 0.9),
      SwingBarMode.thread => stops.last,
    };
    if ((spec.heightFactor.value - target).abs() < 0.001) return;
    _settingHeight = true;
    spec.userResized = false;
    spec.heightFactor.value = target;
    _settingHeight = false;
  }

  /// 形が替わった: 広げている間は止め、高さを合わせる。
  void _onBarMode() {
    if (!mounted) return;
    if (_bar.mode == _barMode) {
      // コンポーザーの中身の高さが変わった (D-421)。
      if (_barMode == SwingBarMode.compose) _applyBarHeight();
      return;
    }
    _barMode = _bar.mode;
    _hold('reply', _barMode != SwingBarMode.compact);
    _applyBarHeight();
  }

  /// ハンドルで動かした(離して段に着いた): 下の段 = 畳む、上の段 = スレッド。
  void _onBarDrag() {
    final spec = _barSpec;
    if (_settingHeight || spec == null || spec.heightStops.length < 2) return;
    final v = spec.heightFactor.value;
    if ((v - spec.heightStops.first).abs() < 0.005 && _bar.mode != SwingBarMode.compact) {
      _bar.setMode(SwingBarMode.compact);
    } else if ((v - spec.heightStops.last).abs() < 0.005 && _bar.mode == SwingBarMode.compact) {
      _bar.setMode(SwingBarMode.thread);
    }
  }

  void _reveal(Swing s) {
    setState(() => _revealed.add(s.id));
    if (_current?.id == s.id) _startClock();
    _queueBarSync();
  }

  /// 通報 (D-395): 理由を選んで `POST /reports {swingId}`。選んでいる間は止める。
  Future<void> _report(Swing s) async {
    final api = ref.read(swingApiProvider);
    if (api == null) return;
    _hold('report', true);
    final reason = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text('${s.author.displayName} の Swing を通報します。RASQ の審査で確認します。', style: RasqTypography.bodySmall)),
          for (final r in astellReportReasons)
            ListTile(key: ValueKey('swing.report.${r.id}'), title: Text(r.label), onTap: () => Navigator.of(ctx).pop(r.id)),
        ]),
      ),
    );
    if (!mounted) return;
    _hold('report', false);
    if (reason == null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await api.report(s.id, reason: reason);
      _reported.add(s.id);
      messenger?.showSnackBar(const SnackBar(content: Text('通報しました。審査で確認します')));
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text('通報できませんでした: $e')));
    }
  }

  void _hold(String reason, bool v) {
    if (!mounted || _holds.contains(reason) == v) return;
    final was = _held;
    setState(() => v ? _holds.add(reason) : _holds.remove(reason));
    if (was == _held) return;
    if (_held) {
      _clock.stop();
    } else if (!_paused && _clock.duration != null && _clock.value > 0 && _clock.value < 1) {
      _clock.forward();
    }
  }

  @override
  void initState() {
    super.initState();
    _feed = ref.read(swingFeedProvider.notifier);
    final feed = widget.mine
        ? ([...?ref.read(mySwingsProvider).value]..sort((a, b) => a.createdAt.compareTo(b.createdAt)))
        : swingViewerQueue(ref.read(swingFeedProvider).value ?? const [], startAuthor: widget.startAuthor);
    _items = [for (final s in feed) SwingViewerItem.swing(s)];
    _adsOn = !widget.mine && ref.read(exportAdNetworkProvider) != null && ref.read(exportAdAllowedProvider);
    // しばらく見ていなかったら、最初の Swing から移るところで必ず (D-445)。
    final last = SwingViewerScreen.lastViewedAt;
    final forced = last == null || SwingViewerScreen.now().difference(last) >= SwingViewerScreen.adForceAfter;
    _adCountdown = forced ? 1 : _nextAdCountdown();
    SwingViewerScreen.lastViewedAt = SwingViewerScreen.now();
    _planAd(0);
    _pages = PageController(initialPage: _index);
    _startClock();
    _queueBarSync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 上にほかの画面が載った / 外れた、キーボードの出入り: FOW を出し直す / 高さを合わせる。
    _avail = MediaQuery.sizeOf(context).height - MediaQuery.viewInsetsOf(context).bottom;
    _bottomPad = MediaQuery.paddingOf(context).bottom;
    _routeCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    _queueBarSync();
  }

  @override
  void dispose() {
    // カラムから外された(第3カラムに別のページを開いた など)ときも、見ていたものは見終えにする (D-413)。
    final s = _closed || _index >= _items.length ? null : _items[_index].swing;
    if (s != null && !widget.mine) unawaited(_feed.markSeen(s.id));
    SwingViewerScreen.lastViewedAt = SwingViewerScreen.now();
    // 下の FOW は木を組み直している最中には閉じられないので、このフレームのあと(中身の状態もそのあとで捨てる)。
    final manager = _manager;
    final bar = _bar;
    _barSpec = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (manager != null && !manager.disposed && manager.contains(SwingBar.fowId)) manager.close(SwingBar.fowId);
      bar.dispose();
    });
    bar.onHold = null;
    bar.removeListener(_onBarMode);
    _clock.dispose();
    _pages.dispose();
    super.dispose();
  }

  /// 時間で進むもの(テキスト / 画像)だけ、時計を回す。
  void _startClock() {
    _clock.stop();
    _clock.value = 0;
    final s = _index < _items.length ? _items[_index].swing : null;
    final d = SwingViewerScreen.displayDuration;
    if (s == null || d == null || !(s.kind == SwingKind.text || s.kind == SwingKind.image) || _coveredNow(s)) return;
    _clock.duration = d;
    if (!_paused && !_held) _clock.forward();
  }

  void _onClock(AnimationStatus st) {
    if (st == AnimationStatus.completed && mounted) _next();
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    if (_paused) {
      _clock.stop();
    } else if (_clock.duration != null && _clock.value > 0 && _clock.value < 1) {
      _clock.forward();
    } else {
      _startClock();
    }
  }

  /// スワイプを止める / 戻す。ページが止まりきる前に物理を変えると、ページの途中で止まるので、止まってから。
  void _setLocked(bool v) {
    if (v == _locked) return;
    final pos = _pages.hasClients ? _pages.position : null;
    if (v && pos != null && pos.isScrollingNotifier.value) {
      void once() {
        if (pos.isScrollingNotifier.value) return;
        pos.isScrollingNotifier.removeListener(once);
        if (mounted) _setLocked(true);
      }

      pos.isScrollingNotifier.addListener(once);
      return;
    }
    setState(() => _locked = v);
    _queueBarSync();
  }

  void _seen(int i) {
    final s = (i >= 0 && i < _items.length) ? _items[i].swing : null;
    if (s != null && !widget.mine) unawaited(_feed.markSeen(s.id));
  }

  int _nextAdCountdown() => SwingViewerScreen.adSwipesMin + SwingViewerScreen.adRandom.nextInt(SwingViewerScreen.adSwipesMax - SwingViewerScreen.adSwipesMin + 1);

  /// 着いた Swing [i] の次に広告を置くか決める (D-445)。置いたら全画面の広告を読んでおく。
  void _planAd(int i) {
    if (!_adsOn || _adCountdown > 1 || i < 0 || i + 1 >= _items.length) return;
    final cur = _items[i].swing;
    final next = _items[i + 1].swing;
    // 両隣が危なくないところだけ。危なければ次の Swing で試す(数は 1 のまま)。
    if (cur == null || next == null || !swingAdNeighborSafe(cur) || !swingAdNeighborSafe(next) || _reported.contains(cur.id) || _reported.contains(next.id)) return;
    _items.insert(i + 1, SwingViewerItem.ad(++_adSerial));
    _adCountdown = _nextAdCountdown();
    _fullscreenReady = _loadFullscreen();
  }

  Future<bool> _loadFullscreen() {
    final network = ref.read(exportAdNetworkProvider);
    if (network == null) return Future.value(false);
    return ref.read(exportAdSdkProvider).loadFullscreen(network: network, config: ref.read(exportAdConfigProvider));
  }

  void _onPage(int i) {
    if (_suppressPage) return;
    final prev = _index;
    _seen(prev);
    SwingViewerScreen.lastViewedAt = SwingViewerScreen.now();
    final fromAd = prev < _items.length && _items[prev].ad;
    if (fromAd) _leftAd = prev;
    setState(() {
      _index = i;
      _locked = false;
      _paused = false;
      // 先へ 1 回スワイプして Swing に着いた: 数を減らし、次に広告を置くか決める(広告から着いたときは数えない)。
      if (i > prev && !fromAd && i < _items.length && _items[i].swing != null) {
        _adCountdown--;
        _planAd(i);
      }
    });
    _startClock();
    _queueBarSync();
  }

  /// 自分の Swing を消す (D-446、… の「削除」): 確かめてから Central で消し、手元のフィード / 自分の Swing / この並びから外す。
  /// 残りが無ければ閉じる。
  Future<void> _delete(Swing s) async {
    _hold('delete', true);
    final manager = ref.read(overlayManagerProvider);
    final ok = await manager.showAlert(id: 'swing.delete', title: 'Swing を削除', message: 'この Swing と、付いている返信を削除します。元に戻せません。', confirmText: '削除する', cancelText: 'キャンセル', destructive: true);
    if (!mounted) return;
    _hold('delete', false);
    if (!ok) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await deleteSwing(ref, s.id);
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text('削除できませんでした: $e')));
      return;
    }
    if (!mounted) return;
    messenger?.showSnackBar(const SnackBar(content: Text('Swing を削除しました')));
    final i = _items.indexWhere((x) => x.swing?.id == s.id);
    if (i < 0) return;
    _items.removeAt(i);
    // 広告だけが残る / 何も残らない → 閉じる。
    if (!_items.any((x) => x.swing != null)) {
      _closed = true;
      return _close();
    }
    setState(() {
      if (i < _index || _index >= _items.length) _index = (_index - 1).clamp(0, _items.length - 1);
    });
    if (_pages.hasClients) {
      _suppressPage = true;
      _pages.jumpToPage(_index);
      _suppressPage = false;
    }
    _startClock();
    _queueBarSync();
  }

  /// 離れた広告を並びから外す(スクロールが止まってから。前の Swing に戻るときに出さない、D-445)。
  void _dropLeftAd() {
    final r = _leftAd;
    _leftAd = null;
    if (r == null || r >= _items.length || !_items[r].ad || r == _index) return;
    setState(() {
      _items.removeAt(r);
      if (r < _index) _index--;
    });
    if (!_pages.hasClients) return;
    _suppressPage = true;
    _pages.jumpToPage(_index);
    _suppressPage = false;
  }

  /// 次へ(最後なら閉じる)。
  void _next() {
    if (_index + 1 < _items.length) {
      _pages.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    } else {
      _close();
    }
  }

  void _prev() {
    if (_index > 0) _pages.previousPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
  }

  void _close() {
    _seen(_index);
    _closed = true;
    // 第3カラム (D-413): < と同じ戻り(1 つ前のページへ / 無ければ閉じる)。
    if (paneBack(context)) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    // RASQ アカウントの読み口が変わったら、返信の欄を出し直す。
    ref.listen(rasqAccountPageApiProvider, (_, _) => _queueBarSync());
    return Theme(
      data: RasqTheme.dark(),
      child: Scaffold(
        key: const ValueKey('swing.viewer'),
        backgroundColor: Colors.black,
        body: _items.isEmpty
            ? Stack(children: [
                widget.mine
                    ? const RasqEmptyView(key: ValueKey('swing.viewer.empty'), title: '出している Swing はありません', hint: '＋ を上へスワイプすると Swing を作れます')
                    : const RasqEmptyView(key: ValueKey('swing.viewer.empty'), title: 'Swing はありません', hint: 'フォローしている人や、RASQ リストに入れてくれた人の Swing がここに流れます'),
                Positioned(top: 8, right: 8, child: SafeArea(child: RasqIconButton(icon: Icons.close, tooltip: '閉じる', color: Colors.white, onPressed: _close))),
              ])
            : Stack(children: [
                // Swing の面は、下の FOW(畳んだ形 / コンポーザー / スレッド)の残りへ縮む (D-420)。
                Positioned.fill(child: FowAvoidingBox(
                manager: ref.watch(overlayManagerProvider),
                minFree: 160,
                child: KeyedSubtree(key: swingViewerMediaKey, child: ScrollConfiguration(
                // マウス / トラックパッドのドラッグでもめくれる(既定はタッチだけ)。
                behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad, PointerDeviceKind.stylus}),
                child: NotificationListener<ScrollEndNotification>(
                onNotification: (_) {
                  if (_leftAd != null) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _dropLeftAd() : null);
                  return false;
                },
                child: PageView.builder(
                key: const ValueKey('swing.viewer.pages'),
                controller: _pages,
                physics: _locked ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
                onPageChanged: _onPage,
                itemCount: _items.length,
                // 広告を外して並びが詰まっても、ページの状態(動画 / プラグイン)はそのまま。
                findChildIndexCallback: (key) {
                  final i = _items.indexWhere((x) => x.key == key);
                  return i < 0 ? null : i;
                },
                itemBuilder: (_, i) {
                  final item = _items[i];
                  final s = item.swing;
                  if (s == null) {
                    return _AdPage(
                      key: item.key,
                      active: i == _index,
                      fullscreen: _fullscreenReady,
                      onClose: _close,
                      onDone: () {
                        if (i == _index) _next();
                      },
                    );
                  }
                  return _SwingPage(
                    key: ValueKey('swing.page.${s.id}'),
                    swing: s,
                    active: i == _index,
                    paused: i == _index && (_paused || _held),
                    covered: _coveredNow(s),
                    onSeekable: (v, alive) => _registerSeekable(s.id, v, alive),
                    onReveal: () => _reveal(s),
                    onReport: widget.mine || ref.watch(swingApiProvider) == null ? null : () => _report(s),
                    viewCount: widget.mine ? s.viewCount : null,
                    // 上のアクション (D-445): 全画面表示のアクションバーと同じボタン。返信は下の FOW のコンポーザーへ。
                    actions: s.postId == null || ref.watch(rasqAccountPageApiProvider) == null ? null : _SwingHeaderActions(key: ValueKey('swing.actions.${s.id}'), postId: s.postId!, onReply: () => _bar.compose(), onDelete: () => _delete(s)),
                    clock: _clock,
                    position: '${i + 1} / ${_items.length}',
                    onClose: _close,
                    onTapZone: (zone) => switch (zone) { -1 => _prev(), 1 => _next(), _ => _togglePause() },
                    onLockChanged: (locked) {
                      if (i == _index) _setLocked(locked);
                    },
                    onEnd: () {
                      if (i == _index) _next();
                    },
                  );
                },
              ),
              ))))),
              ]),
      ),
    );
  }

  Swing? get _current => _index < _items.length ? _items[_index].swing : null;

  /// 返信(下の FOW の返信の欄・返信 N・キュー)を出すか。全画面で動いているプラグイン・覆っている Swing・根の無い Swing には出さない。
  bool _replyShown(Swing s) => s.postId != null && !_locked && !_coveredNow(s) && ref.read(rasqAccountPageApiProvider) != null;
}

String swingRemainingLabel(Duration d) {
  if (d.inHours >= 1) return 'あと ${d.inHours} 時間';
  if (d.inMinutes >= 1) return 'あと ${d.inMinutes} 分';
  return 'まもなく消えます';
}

/// 動画の再生ができた([alive] = true)/ 無くなった。
typedef SwingSeekableCallback = void Function(SwingSeekable seek, bool alive);

class _SwingPage extends StatelessWidget {
  const _SwingPage({super.key, required this.swing, required this.active, required this.paused, required this.clock, required this.position, required this.onClose, required this.onTapZone, required this.onLockChanged, required this.onEnd, this.onSeekable, this.covered = false, this.onReveal, this.onReport, this.viewCount, this.actions});

  /// 上のアクション (D-445)。null = 出さない(スレッドの無い Swing / RASQ アカウントが無い)。
  final Widget? actions;

  /// 自分の Swing の見た人の数 (D-410)。null = 出さない(ほかの人の Swing / 古い Central)。
  final int? viewCount;

  /// CW / センシティブで覆っている (D-395)。
  final bool covered;
  final VoidCallback? onReveal;

  /// 通報 (D-395)。null = 出さない(RASQ アカウントが無い)。
  final VoidCallback? onReport;

  /// 動画の再生ができた / 無くなった(下の FOW のシークバーへ、D-420)。
  final SwingSeekableCallback? onSeekable;
  final Swing swing;
  final bool active;
  final bool paused;
  final Animation<double> clock;
  final String position;

  /// -1 = 左端(前へ)、0 = 中央(一時停止)、1 = 右端(次へ)。
  final ValueChanged<int> onTapZone;
  final VoidCallback onClose;
  final ValueChanged<bool> onLockChanged;
  final VoidCallback onEnd;

  /// 1 つの Swing のページ。返信・シークバーは下の FOW (D-420)。
  @override
  Widget build(BuildContext context) {
    // 覆っている間は動画 / プラグインを動かさない。
    final live = active && !covered;
    final body = switch (swing.kind) {
      SwingKind.text => _TextBody(text: swing.text),
      SwingKind.image => _ImageBody(swing: swing),
      SwingKind.video => _VideoBody(swing: swing, active: live, paused: paused, onDone: onEnd, onSeekable: onSeekable),
      SwingKind.plugin => _PluginBody(swing: swing, active: live, onLockChanged: onLockChanged, onEnd: onEnd),
    };
    final timed = swing.kind != SwingKind.plugin;
    return Stack(fit: StackFit.expand, children: [
      body,
      // タップ: 左端 / 中央 / 右端(プラグインはページ自身がタップを使う)。
      if (timed)
        Positioned.fill(
          child: LayoutBuilder(
            builder: (_, box) => GestureDetector(
              key: const ValueKey('swing.tap'),
              behavior: HitTestBehavior.translucent,
              onTapUp: (d) {
                final x = d.localPosition.dx / box.maxWidth;
                onTapZone(x < 0.25 ? -1 : (x > 0.75 ? 1 : 0));
              },
            ),
          ),
        ),
      if (timed && paused && !covered)
        const Center(child: IgnorePointer(child: Icon(Icons.pause_circle_outline, key: ValueKey('swing.paused'), color: Colors.white70, size: 64))),
      if (covered) Positioned.fill(child: _Cover(swing: swing, onReveal: onReveal)),
      // 上: 作った人と残り時間、通報、閉じる(進みは下の FOW のシークバー、D-420)。
      Positioned(
        left: 0,
        right: 0,
        top: 0,
        child: DecoratedBox(
          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black54, Colors.transparent])),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.xs, RasqSpacing.lg),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                RasqAvatar(imageUrl: swing.author.avatarUrl, size: 32, fallbackLabel: swing.author.displayName),
                const SizedBox(width: RasqSpacing.sm),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(swing.author.displayName, key: const ValueKey('swing.author'), style: RasqTypography.bodySmall.copyWith(color: Colors.white, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('${swingRemainingLabel(swing.remaining(DateTime.now()))} ・ $position', style: RasqTypography.caption.copyWith(color: Colors.white70)),
                    if (viewCount != null)
                      Row(key: const ValueKey('swing.viewCount'), mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.visibility_outlined, size: 14, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text('見た人 $viewCount 人', style: RasqTypography.caption.copyWith(color: Colors.white70)),
                      ]),
                  ]),
                ),
                if (onReport != null) RasqIconButton(key: const ValueKey('swing.report'), icon: Icons.flag_outlined, tooltip: '通報', color: Colors.white, onPressed: onReport),
                RasqIconButton(key: const ValueKey('swing.close'), icon: Icons.close, tooltip: '閉じる', color: Colors.white, onPressed: onClose),
              ]),
              // アクション (D-445): 作った人の行の下に、右へ寄せて(狭ければ横に送る)。
              if (actions case final a?)
                Padding(
                  padding: const EdgeInsets.only(top: RasqSpacing.xs, right: RasqSpacing.sm),
                  child: Align(alignment: Alignment.centerRight, child: SingleChildScrollView(scrollDirection: Axis.horizontal, reverse: true, child: a)),
                ),
              ]),
            ),
          ),
        ),
      ),
      // 画像 / 動画に添えた文。
      if (swing.kind != SwingKind.text && swing.kind != SwingKind.plugin && swing.text.isNotEmpty && !covered)
        Positioned(
          left: RasqSpacing.page,
          right: RasqSpacing.page,
          bottom: RasqSpacing.lg,
          child: Text(swing.text, key: const ValueKey('swing.caption'), style: RasqTypography.body.copyWith(color: Colors.white, shadows: const [Shadow(blurRadius: 6)])),
        ),
    ]);
  }
}

/// Swing の上のアクション (D-445): Swing のスレッドの根の投稿に、全画面表示のアクションバーと同じボタン(…に共有 / 保存は無し)。
class _SwingHeaderActions extends ConsumerWidget {
  const _SwingHeaderActions({super.key, required this.postId, required this.onReply, required this.onDelete});
  final String postId;
  final VoidCallback onReply;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = ref.watch(rasqThreadProvider(postId)).value?.post;
    if (post == null) return const SizedBox.shrink();
    return RasqPostOverlayActions(post: post, onReply: onReply, onDelete: onDelete, onChanged: () => ref.invalidate(rasqThreadProvider(postId)));
  }
}

/// CW / センシティブの覆い (D-395): ぼかして暗くし、CW の文か「センシティブな内容」と「表示する」。スワイプでは移れる。
class _Cover extends StatelessWidget {
  const _Cover({required this.swing, this.onReveal});
  final Swing swing;
  final VoidCallback? onReveal;

  @override
  Widget build(BuildContext context) => ClipRect(
        key: const ValueKey('swing.cover'),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 32, sigmaY: 32),
          child: ColoredBox(
            color: Colors.black.withValues(alpha: 0.7),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(RasqSpacing.xxl),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.visibility_off_outlined, color: Colors.white70, size: 40),
                  const SizedBox(height: RasqSpacing.sm),
                  Text(swing.cw ?? 'センシティブな内容', key: const ValueKey('swing.cover.text'), textAlign: TextAlign.center, style: RasqTypography.title.copyWith(color: Colors.white)),
                  if (swing.cw != null && swing.sensitive) Text('センシティブな内容', style: RasqTypography.caption.copyWith(color: Colors.white70)),
                  const SizedBox(height: RasqSpacing.md),
                  FilledButton.tonal(key: const ValueKey('swing.cover.reveal'), onPressed: onReveal, child: const Text('表示する')),
                ]),
              ),
            ),
          ),
        ),
      );
}

class _TextBody extends StatelessWidget {
  const _TextBody({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [RasqColors.main, RasqColors.link])),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(RasqSpacing.xxl),
            child: Text(text, key: const ValueKey('swing.text'), textAlign: TextAlign.center, style: RasqTypography.title.copyWith(color: Colors.white, fontSize: 26, height: 1.4)),
          ),
        ),
      );
}

class _ImageBody extends StatelessWidget {
  const _ImageBody({required this.swing});
  final Swing swing;

  @override
  Widget build(BuildContext context) {
    final url = swing.mediaUrl;
    if (url == null) return const _Missing();
    return Image.network(
      url.toString(),
      key: const ValueKey('swing.image'),
      webHtmlElementStrategy: rasqWebImageStrategy,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const _Missing(),
    );
  }
}

class _Missing extends StatelessWidget {
  const _Missing();
  @override
  Widget build(BuildContext context) => const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white38, size: 48));
}

class _VideoBody extends ConsumerStatefulWidget {
  const _VideoBody({required this.swing, required this.active, this.paused = false, this.onDone, this.onSeekable});
  final Swing swing;
  final bool active;
  final bool paused;

  /// 終わりまで再生した(次へ)。
  final VoidCallback? onDone;

  /// 再生ができた / 無くなった(下の FOW のシークバー、D-420)。
  final SwingSeekableCallback? onSeekable;

  @override
  ConsumerState<_VideoBody> createState() => _VideoBodyState();
}

class _VideoBodyState extends ConsumerState<_VideoBody> {
  VideoSession? _session;
  SwingSeekable? _seek;

  @override
  void initState() {
    super.initState();
    final fake = ref.read(swingVideoSeekOverrideProvider);
    final url = widget.swing.mediaUrl;
    if (fake != null) {
      _seek = fake(widget.swing);
    } else if (url != null) {
      final s = _session = VideoSession(MediaItem(id: widget.swing.id, type: MediaType.video, url: url), autoplay: widget.active)..addListener(_hook);
      _seek = VideoSessionSeekable(s);
    }
    final seek = _seek;
    if (seek != null) WidgetsBinding.instance.addPostFrameCallback((_) => widget.onSeekable?.call(seek, true));
  }

  @override
  void didUpdateWidget(_VideoBody old) {
    super.didUpdateWidget(old);
    // 別のページへ移ったら止める。
    final c = _session?.controller;
    if (c != null && (old.active && !widget.active || !old.paused && widget.paused)) c.pause();
    if (c != null && widget.active && !widget.paused && (!old.active || old.paused)) c.play();
  }

  bool _done = false;
  bool _hooked = false;

  /// 再生器ができたら、終わりを見張る(1 回だけ)。
  void _hook() {
    final c = _session?.controller;
    if (c == null || _hooked) return;
    _hooked = true;
    c.addListener(_watchEnd);
  }

  void _watchEnd() {
    final c = _session?.controller;
    if (c == null || _done || !widget.active) return;
    final v = c.value;
    if (v.isInitialized && v.duration > Duration.zero && v.position >= v.duration && !v.isPlaying) {
      _done = true;
      widget.onDone?.call();
    }
  }

  @override
  void dispose() {
    final cb = widget.onSeekable;
    final seek = _seek;
    if (seek != null && cb != null) WidgetsBinding.instance.addPostFrameCallback((_) => cb(seek, false));
    _session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;
    if (s == null) return _seek != null ? const ColoredBox(key: ValueKey('swing.video'), color: Colors.black) : const _Missing();
    // 再生 / 一時停止は中央のタップ(ビューワー)、位置は下の FOW のシークバー (D-420)。
    return RasqVideoView(key: const ValueKey('swing.video'), session: s, tapToggles: false);
  }
}

/// プラグインの Swing: 全画面で動かす。「全画面から縮小」でぼかして止め、スワイプで移れるように。
class _PluginBody extends ConsumerStatefulWidget {
  const _PluginBody({required this.swing, required this.active, required this.onLockChanged, required this.onEnd});
  final Swing swing;
  final bool active;
  final ValueChanged<bool> onLockChanged;
  final VoidCallback onEnd;

  @override
  ConsumerState<_PluginBody> createState() => _PluginBodyState();
}

class _PluginBodyState extends ConsumerState<_PluginBody> {
  CustomPageController? _c;
  bool _shrunk = false;

  @override
  void initState() {
    super.initState();
    // 画面の大きさ(MediaQuery)を読むので、最初のフレームのあとに起こす。
    if (widget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.active && _c == null) _start();
      });
    }
  }

  @override
  void didUpdateWidget(_PluginBody old) {
    super.didUpdateWidget(old);
    // 見えたときに起こす。離れたら閉じる(page.close)。
    if (widget.active && _c == null) _start();
    if (!widget.active && _c != null) _stop();
  }

  void _start() {
    final p = widget.swing.plugin!;
    final c = CustomPageController(
      ProviderScope.containerOf(context, listen: false),
      CustomPageArgs(
        pluginId: p.id,
        version: p.version,
        surface: PluginPageDecl.surfaceSwing,
        // shared のカスタムプラグイン (D-424 / Central S-079): 作った人のセッションに入る(入れていなければ同意のうえ一時的に)。
        sessionId: p.unreviewed ? null : p.sessionId,
        // 未審査 (D-379): 作った人が上げた入れ物を、同意のうえ制限モード(通信なし、GPU だけ可)で一時的に動かす。
        package: p.unreviewed && p.packageUrl != null ? () => ref.read(swingPackageFetcherProvider)(p.packageUrl!) : null,
        packageSource: p.unreviewed ? '$swingSlotSourcePrefix${widget.swing.id}' : null,
        context: {
          'swingId': widget.swing.id,
          'data': ?p.data,
          'author': {'accountId': widget.swing.authorAccountId, 'handle': widget.swing.author.account.handle, 'displayName': widget.swing.author.displayName},
        },
      ),
      // 第3カラムに開いたときは、カラムの大きさ (D-413)。
      size: switch (context.findRenderObject()) { final RenderBox b when b.hasSize => b.size, _ => MediaQuery.sizeOf(context) },
    );
    c.onEnd = widget.onEnd;
    c.addListener(_changed);
    _c = c;
    _shrunk = false;
    unawaited(c.start());
  }

  void _stop() {
    final c = _c;
    _c = null;
    c?.removeListener(_changed);
    c?.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    widget.onLockChanged(_running && !_shrunk);
  }

  bool get _running => _c?.phase == CustomPagePhase.ready;

  void _setShrunk(bool v) {
    final c = _c;
    if (c == null) return;
    setState(() => _shrunk = v);
    v ? c.pause() : c.resume();
    widget.onLockChanged(_running && !v);
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final scheme = Theme.of(context).colorScheme;
    if (c == null || c.phase == CustomPagePhase.resolving || c.phase == CustomPagePhase.loading) {
      // プラグインの Swing を読み込んでいる間(遷移中)は広告も (D-438)。
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5)),
          if (timelineAdsOn(ref)) const Padding(key: ValueKey('swing.loading.ad'), padding: EdgeInsets.only(top: RasqSpacing.md), child: ExportAdSlot(onDark: true)),
        ]),
      );
    }
    switch (c.phase) {
      case CustomPagePhase.needsConsent when !widget.swing.plugin!.unreviewed:
        // 入れていない shared のプラグインの Swing (D-424): 審査済みのストアの版を、同意のうえこの Swing の間だけ動かす(作った人のセッションに入る)。
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(RasqSpacing.page),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.groups_outlined, color: Colors.white70, size: 40),
              const SizedBox(height: RasqSpacing.sm),
              Text(c.detail?.name ?? widget.swing.plugin!.id, style: RasqTypography.title.copyWith(color: Colors.white)),
              const SizedBox(height: RasqSpacing.sm),
              Text('${widget.swing.author.displayName} さんのページにみんなで入ります。インストールせずに、この Swing を見ている間だけ動かします。',
                  key: const ValueKey('swing.plugin.join.note'), textAlign: TextAlign.center, style: RasqTypography.bodySmall.copyWith(color: Colors.white70)),
              const SizedBox(height: RasqSpacing.md),
              FilledButton(key: const ValueKey('swing.plugin.join'), onPressed: c.acceptTemporary, child: const Text('参加する')),
            ]),
          ),
        );
      case CustomPagePhase.needsConsent:
        // 未審査のプラグイン (D-379)。
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(RasqSpacing.page),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.extension_outlined, color: Colors.white70, size: 40),
              const SizedBox(height: RasqSpacing.sm),
              Text(widget.swing.plugin!.id, style: RasqTypography.title.copyWith(color: Colors.white)),
              const SizedBox(height: RasqSpacing.sm),
              const RasqNotice.warning(
                key: ValueKey('swing.plugin.consent'),
                text: '審査されていないプラグインです。通信はできない状態で、この Swing を見ている間だけ動かします。',
                detail: 'D-379 / S-057。制限モード(network / storage.unsafe / interstitial・system の FOW / URL を開くなどは閉、GPU は可)。子プラグインを持たない 1 つだけ。',
              ),
              const SizedBox(height: RasqSpacing.md),
              FilledButton(key: const ValueKey('swing.plugin.run'), onPressed: c.acceptTemporary, child: const Text('動かす')),
            ]),
          ),
        );
      case CustomPagePhase.needsInstall:
        return RasqEmptyView(
          key: const ValueKey('swing.plugin.needsInstall'),
          title: '${c.detail?.name ?? widget.swing.plugin!.id} を入れると見られます',
          hint: 'プラグインの Swing です。ストアからインストールしてください',
          action: FilledButton(onPressed: () => context.push(Routes.storePlugin(widget.swing.plugin!.id)), child: const Text('ストアで見る')),
        );
      case CustomPagePhase.failed:
        return RasqEmptyView(key: const ValueKey('swing.plugin.failed'), title: '開けませんでした', hint: c.error);
      default:
        break;
    }
    final p = c.plugin!;
    final controller = p.runtime.view;
    final page = RrlRenderer(
      node: c.root ?? RrlNode.fromJson(const {'t': 'Column'}),
      host: RrlHost(instanceScope: controller.document?.scope ?? p.id, scope: RrlScope({}), geometry: controller.geometry, mediaPolicy: p.mediaPolicy, onEvent: c.onRrlEvent),
    );
    final full = Container(
      key: const ValueKey('swing.plugin.page'),
      color: scheme.surface,
      child: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 56, RasqSpacing.page, RasqSpacing.page), child: page)),
    );
    if (_shrunk) {
      // 縮小: ぼかして止め、押すと全画面に戻る。
      return GestureDetector(
        key: const ValueKey('swing.plugin.shrunk'),
        onTap: () => _setShrunk(false),
        child: Center(
          child: FractionallySizedBox(
            widthFactor: 0.78,
            heightFactor: 0.7,
            child: Stack(fit: StackFit.expand, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(RasqSizes.radiusLg),
                child: AbsorbPointer(child: ImageFiltered(imageFilter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8), child: full)),
              ),
              Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.play_circle_outline, color: Colors.white, size: 48),
                  const SizedBox(height: RasqSpacing.xs),
                  Text('押すと全画面に戻ります', style: RasqTypography.caption.copyWith(color: Colors.white)),
                  Text('上下にスワイプで次の Swing へ', style: RasqTypography.caption.copyWith(color: Colors.white70)),
                ]),
              ),
            ]),
          ),
        ),
      );
    }
    return Stack(fit: StackFit.expand, children: [
      full,
      Positioned(
        right: RasqSpacing.sm,
        bottom: RasqSpacing.lg,
        child: SafeArea(
          child: FilledButton.tonalIcon(
            key: const ValueKey('swing.plugin.shrink'),
            onPressed: () => _setShrunk(true),
            icon: const Icon(Icons.close_fullscreen, size: 18),
            label: const Text('全画面から縮小'),
          ),
        ),
      ),
    ]);
  }
}

/// 広告の 1 枚 (D-445)。移っている間([active] でない)は「広告」の表記だけ(プレビュー)。止まったら、読んでおいた全画面の
/// 動画の広告を出し、閉じたら [onDone](次の Swing へ)。全画面の広告が無ければ、縦長のバナー(高さの 70% まで)。
/// バナーも読めなければ [onDone]。
class _AdPage extends ConsumerStatefulWidget {
  const _AdPage({super.key, required this.active, required this.onClose, required this.onDone, this.fullscreen});
  final bool active;
  final Future<bool>? fullscreen;
  final VoidCallback onClose;
  final VoidCallback onDone;

  @override
  ConsumerState<_AdPage> createState() => _AdPageState();
}

class _AdPageState extends ConsumerState<_AdPage> {
  /// 全画面の広告を出すか決めた(true = バナーにした)。
  bool _banner = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    if (widget.active) WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void didUpdateWidget(_AdPage old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _start();
  }

  Future<void> _start() async {
    if (_started || !mounted) return;
    _started = true;
    final ready = await (widget.fullscreen ?? Future.value(false)).timeout(const Duration(milliseconds: 1500), onTimeout: () => false);
    if (!mounted) return;
    if (ready && await ref.read(exportAdSdkProvider).showFullscreen()) {
      if (mounted) widget.onDone();
      return;
    }
    if (mounted) setState(() => _banner = true);
  }

  @override
  Widget build(BuildContext context) {
    final label = Center(
      child: Container(
        key: const ValueKey('swing.ad.preview'),
        padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.lg, vertical: RasqSpacing.sm),
        decoration: BoxDecoration(border: Border.all(color: Colors.white54), borderRadius: BorderRadius.circular(RasqSizes.radiusMd)),
        child: Text('広告', style: RasqTypography.title.copyWith(color: Colors.white)),
      ),
    );
    return Stack(children: [
      if (!_banner)
        label
      else
        LayoutBuilder(
          builder: (context, c) => Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ExportAdSlot(key: const ValueKey('swing.ad.banner'), onDark: true, maxHeight: c.maxHeight * SwingViewerScreen.adBannerHeightFactor, onFailed: widget.onDone),
              const SizedBox(height: RasqSpacing.md),
              Text('スワイプで次の Swing へ', style: RasqTypography.caption.copyWith(color: Colors.white54)),
            ]),
          ),
        ),
      Positioned(top: 8, right: 8, child: SafeArea(child: RasqIconButton(icon: Icons.close, tooltip: '閉じる', color: Colors.white, onPressed: widget.onClose))),
    ]);
  }
}
