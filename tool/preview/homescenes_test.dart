// rasq-central のホームページの「アプリの中の動き」(D-466、Central S-107 のプレイヤーと対)を、実物のアプリで撮る。
//
// 節ごとに **シーン**(コマの列)を撮り、build/homescenes/ に書く:
//   - コマ: <シーン>/<端末>/<nn>.png(端末の物理 px。tool/preview/homescenes.sh が WebP に直して置き場へ)
//   - 台本: scenes.json(schema `rasq.home-scenes/1`。コマごとの表示時間、入り方(アプリの画面遷移と同じ種類・長さ・動く範囲)、
//     タッチの位置、画面の中の RAi の位置と動き、画面共有のライブ映像を描く場所、説明)
//
// | シーン | 端末 | 中身 |
// |---|---|---|
// | rai | phone / tablet | 案内「TL にリストを設定」(操作 `tl-list`)→ アシスタントとの会話「ハロー、RAi さん」(操作の索引なし) |
// | client | tabletWide / phone | サイドバー → リスト(メンバーを追加 / 外す)→ クリップ → 検索 |
// | account | tablet / phone | RASQ アカウントページのタブを順に → カスタムプラグイン「みんなで落書き」(sample.paint をサイドロード)→ SVG の編集画面で描く → 完了でボードに載る |
// | astell | tablet / phone | ルームで聞いている(カスタムプラグインなし)。画面共有のタイルはプレイヤーがライブ映像を描く(`video.rect`)。字幕と話している人が動く |
//
// RAi のマスコットはコマに描かない([raiMascotHiddenProvider] を true に): プレイヤーがページ側の 3D の RAi を、台本の `rai` の位置へ
// 正射影で重ねる。`rai` の位置・大きさ・腕・移動の長さは、アプリの RAi の動き(rai_overlay.dart の RaiMascotLayer が
// rai_motion.dart / rai_space.dart で決めたもの)を、そのコントローラーから毎フレーム読んで書く。
//
// 実行(WebP への変換と置き場まで)は tool/preview/homescenes.sh。手で回すなら:
//   RASQ_PREVIEW_FONT=/path/to/NotoSansJP.ttf RASQ_PAINT_RSPKG=/path/to/sample.paint-0.1.0.rspkg flutter test tool/preview/homescenes_test.dart
// RASQ_PAINT_RSPKG が無ければ ../plugin-sample/custom-plugin-paint/dist/ の .rspkg、それも無ければ同梱の wasm
// (assets/plugins/custom_plugin_paint.wasm、同じもの)をサイドロードする。フォント未指定ならスキップ(ほかのプレビューと同じ)。
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Page;
import 'package:flutter/rendering.dart' show OffsetLayer;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/backend/rasq_account.dart';
import 'package:rasq_client/features/custom/custom_client.dart';
import 'package:rasq_client/features/custom/custom_models.dart';
import 'package:rasq_client/features/nodeprog/timeline_config_screen.dart' show TimelineConfigScreen;
import 'package:rasq_client/features/plugins/slot_plugins.dart';
import 'package:rasq_client/features/rai/rai_embedding_model.dart';
import 'package:rasq_client/features/rai/rai_face.dart';
import 'package:rasq_client/features/rai/rai_llm.dart';
import 'package:rasq_client/features/rai/rai_mascot_3d.dart';
import 'package:rasq_client/features/rai/rai_motion.dart';
import 'package:rasq_client/features/rai/rai_overlay.dart' show RaiMascotLayer;
import 'package:rasq_client/features/rai/rai_providers.dart';
import 'package:rasq_client/features/rai/rai_reference.dart' show RaiReferenceIndex, raiSituationSystem;
import 'package:rasq_client/features/rai/rai_reference_providers.dart';
import 'package:rasq_client/features/search/search_filter_bar_view.dart' show SearchFilterBox;
import 'package:rasq_client/features/vc/astell_client.dart';
import 'package:rasq_client/features/vc/astell_media.dart';
import 'package:rasq_client/features/vc/astell_providers.dart';
import 'package:rasq_client/features/vc/astell_stream.dart' show AstellLiveVideo;
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/notify/local_notifier.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_client/shell/headers.dart' show RasqHeaderAvatarButton;
import 'package:rasq_client/shell/sidebar.dart' show RasqSidebar;
import 'package:rasq_design/rasq_design.dart' show RasqUserRow;
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:rrl_renderer/rrl_renderer.dart' show SvgLiteView;

import '../../test/support/fake_rai_embedding_model.dart';
import '../../test/support/fake_rai_llm.dart';
import '../../test/support/fakes.dart';

/// 置き場(テストの作業ディレクトリ = rasq-client からの相対)。
const _outDir = 'build/homescenes';

/// 端末(ホームページの端末の画面。名前は台本の `device`)。
enum SceneDevice {
  /// スマホの縦: 390×844 論理 px の 2 倍。
  phone('phone', 390, 844, 2),

  /// タブレットの縦向き: 800×1280 の 1.5 倍(幅が 840 未満なのでアプリは 1 カラム)。
  tablet('tablet', 800, 1280, 1.5),

  /// タブレットの横向き: 1280×800 の 1.5 倍(レール + 2 カラム)。
  tabletWide('tabletWide', 1280, 800, 1.5);

  const SceneDevice(this.id, this.w, this.h, this.dpr);
  final String id;
  final double w;
  final double h;
  final double dpr;

  Size get size => Size(w, h);

  void apply(WidgetTester tester) {
    tester.view.physicalSize = Size(w * dpr, h * dpr);
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
  }
}

/// 台本の並び(ホームページのモード: スマホは phone、タブレットは start / client が tabletWide、account / astell / rai が tablet)。
const _sceneOrder = ['rai/phone', 'rai/tablet', 'client/tabletWide', 'client/phone', 'account/tablet', 'account/phone', 'astell/tablet', 'astell/phone'];

/// 画面遷移の種類と長さ(アプリと同じ)。
///
/// - MaterialPage の push / pop(go_router の既定のページ、Android の [PredictiveBackPageTransitionsBuilder] →
///   FadeForwardsPageTransitionsBuilder): 450ms。
/// - タブ(TabBarView)の切り替え: kTabScrollDuration = 300ms。
/// - SVG の編集画面(pro_media_editor_screen.dart の openSvgPaintEditor、狭い画面は FadeTransition の PageRouteBuilder): 300ms。
/// - FOW / サイドバー / ボトムシート / ドロップダウン(rasq_overlay): 出入りのアニメーションは無い(その場で出る)→ replace 0ms。
/// - 第3カラムに開くページ(third_column.dart): 中身はその場で替わり、カラムの幅が 200ms で動く → replace 200ms。
/// - ボトムナビ / レールのタブ(StatefulShellRoute.indexedStack): その場で替わる → replace 0ms。
const _pushMs = 450;
const _tabMs = 300;
const _fadeMs = 300;
const _paneMs = 200;

/// 1 つのシーン(1 端末)の台本とコマ。
class SceneRecorder {
  SceneRecorder(this.id, this.device);
  final String id;
  final SceneDevice device;
  final steps = <Map<String, Object?>>[];
  int _frames = 0;

  static final _all = <String, SceneRecorder>{};

  /// 同じシーン / 端末は続きから(rai は案内と会話を 2 つのテストで撮って 1 本にする)。
  static SceneRecorder of(String id, SceneDevice device) => _all.putIfAbsent('$id/${device.id}', () => SceneRecorder(id, device));

  double nx(double x) => _r(x / device.w);
  double ny(double y) => _r(y / device.h);
  static double _r(double v) => (v.clamp(0.0, 1.0) * 10000).roundToDouble() / 10000;
  List<double> rect(Rect r) => [nx(r.left), ny(r.top), nx(r.right), ny(r.bottom)];
  Map<String, double> point(Offset p) => {'x': nx(p.dx), 'y': ny(p.dy)};

  /// いまの画面を 1 コマ撮る。台本でのパス(.webp)を返す。
  Future<String> capture(WidgetTester tester) async {
    final n = (_frames++).toString().padLeft(2, '0');
    final rel = '$id/${device.id}/$n';
    await tester.pump();
    var ro = find.byType(RasqApp).evaluate().single.renderObject!;
    while (!ro.isRepaintBoundary) {
      ro = ro.parent!;
    }
    final layer = ro.debugLayer! as OffsetLayer;
    final bounds = ro.paintBounds;
    await tester.runAsync(() async {
      final image = await layer.toImage(bounds);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      File('$_outDir/$rel.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    return '$rel.webp';
  }

  void step({required String frame, required int hold, Map<String, Object?>? enter, Offset? tap, Map<String, Object?>? rai, Map<String, Object?>? video, String? caption}) {
    steps.add({
      'frame': frame,
      'hold': hold,
      'enter': enter ?? const {'type': 'none', 'ms': 0},
      'tap': ?(tap == null ? null : point(tap)),
      'rai': ?rai,
      'video': ?video,
      'caption': ?caption,
    });
  }

  Map<String, Object?> toJson() => {'id': id, 'device': device.id, 'loop': true, 'steps': steps};

  // ── 入り方 ──
  Map<String, Object?> push([Rect? region, int ms = _pushMs]) => {'type': 'push', 'ms': ms, 'region': rect(region ?? Offset.zero & device.size)};
  Map<String, Object?> pop([Rect? region, int ms = _pushMs]) => {'type': 'pop', 'ms': ms, 'region': rect(region ?? Offset.zero & device.size)};
  Map<String, Object?> fade([Rect? region, int ms = _fadeMs]) => {'type': 'fade', 'ms': ms, 'region': rect(region ?? Offset.zero & device.size)};
  Map<String, Object?> replace([Rect? region, int ms = 0]) => {'type': 'replace', 'ms': ms, 'region': rect(region ?? Offset.zero & device.size)};
  Map<String, Object?> sheetUp(Rect region, [int ms = 180]) => {'type': 'sheetUp', 'ms': ms, 'region': rect(region)};
  Map<String, Object?> sheetDown(Rect region, [int ms = 180]) => {'type': 'sheetDown', 'ms': ms, 'region': rect(region)};

  /// 書き出し: 撮ったシーンを scenes.json へ(前の実行の別のシーンは残す)。
  static void writeManifest() {
    final file = File('$_outDir/scenes.json');
    final byKey = <String, Map<String, Object?>>{};
    if (file.existsSync()) {
      try {
        final old = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
        for (final s in (old['scenes'] as List? ?? const [])) {
          final m = (s as Map).cast<String, Object?>();
          byKey['${m['id']}/${m['device']}'] = m;
        }
      } catch (_) {}
    }
    for (final e in _all.entries) {
      if (e.value.steps.isNotEmpty) byKey[e.key] = e.value.toJson();
    }
    final keys = byKey.keys.toList()..sort((a, b) => _rank(a).compareTo(_rank(b)));
    final manifest = {
      'schema': 'rasq.home-scenes/1',
      'devices': {for (final d in SceneDevice.values) d.id: {'w': d.w.round(), 'h': d.h.round(), 'dpr': d.dpr}},
      'scenes': [for (final k in keys) byKey[k]],
      // 任意の欄の説明(schema にない足した欄はどれも任意。無ければ無視してよい)。
      'notes': _notes,
    };
    file
      ..createSync(recursive: true)
      ..writeAsStringSync(const JsonEncoder.withIndent(' ').convert(manifest));
  }

  static int _rank(String key) {
    final i = _sceneOrder.indexOf(key);
    return i < 0 ? _sceneOrder.length : i;
  }
}

/// 台本の読み方(プレイヤー向けの注記。rasq-client D-466 / rasq-central S-107)。
const _notes = {
  'coordinates': '座標はどれもコマ(画面)に対する 0..1。region = 遷移で動く範囲(外側のバー / ナビはひとつ前のコマのまま)',
  'enter':
      'none = コマごと即座に切り替え / replace = region だけを ms で切り替え(0 = その場で。FOW・サイドバー・ボトムシート・ボトムナビのタブはアプリでも出入りのアニメーションが無い。'
          '第3カラムに開くページは中身がその場で替わり、カラムの幅が 200ms で動く)/ push = region の中へ次のページが右から入る(pop は逆、前のページが左から戻る。'
          'ページは Android の FadeForwardsPageTransitionsBuilder の 450ms、アカウントページのタブは TabBarView の 300ms)/ fade = region をクロスフェード(SVG の編集画面、300ms)/'
          ' sheetUp・sheetDown = region の FOW の高さが伸びる / 縮む(180ms)',
  'tap': 'この段に入るきっかけのタッチ(enter の前に出す)',
  'rai': 'x / y = 画面の中の RAi の体の中心、scale = 体の高さ ÷ 画面の高さ。pose = run / walk の段は、前の段の位置からこの段の位置へ hold のあいだに移動する'
      '(run = 長い移動: run_start → run → run_stop、walk = 短い移動: run_start_short → run_short → run_stop_short。from = 出発点、approach = 移動の中ほどで手前に寄ったときの scale)。'
      'point = 部品を指して静止(pointTo = 指す部品の中心、arm = 上げる腕 left / right)。idle = 腕を下ろして静止。hidden / visible: false = 出さない。'
      'opacity = 薄く出す(アシスタントのチャットの背景)、spin = 縦軸まわりに spin 秒で 1 回転。face = eyes / closed(faceFrame = 顔のシート assets/rai/face.png の枠番号)。'
      'rai の無い段は RAi を出さない',
  'video': 'rect = 画面共有のライブ映像を描く場所(コマでは空のタイル)、radius = 角丸。overlays = 映像の上にコマから描き戻す部品(LIVE の札・アイコン・…・題名)',
};

/// 返事を 1 字ずつ時間をかけて流す偽の端末内 LLM(homeshots_test.dart と同じ: 会話の見本で「流れている途中」を撮る)。
class _SlowRaiLlm extends FakeRaiLlm {
  _SlowRaiLlm({required String answer}) : super(phase: RaiLlmPhase.ready, reply: answer);
  static const firstDelay = Duration(milliseconds: 900);
  static const perChar = Duration(milliseconds: 40);

  @override
  Stream<String> chat(String prompt, {String? system, int? maxTokens}) async* {
    if (system == raiSituationSystem) {
      yield 'RAi にあいさつしている';
      return;
    }
    if (system == RaiController.raiPlanSystem) {
      yield '- あいさつを返す';
      return;
    }
    await Future<void>.delayed(firstDelay);
    await for (final ch in super.chat(prompt, system: system, maxTokens: maxTokens)) {
      await Future<void>.delayed(perChar);
      yield ch;
    }
  }
}

// ── クライアントの見本の SNS(リストのメンバーとクリップを持つ)──

class _SceneSnsPlugin extends FakeSnsPlugin {
  _SceneSnsPlugin() : super(posts: MockData.timeline);
  @override
  SnsSession open(AccountSession session) {
    final s = _SceneSnsSession(session, posts(session.account));
    opened.add(s);
    return s;
  }
}

/// リストのメンバーを本当に足す / 外す(アプリの「メンバーを追加」と「外す」がそのまま効く)。
class _SceneSnsSession extends FakeSnsSession {
  _SceneSnsSession(super.session, super.posts);
  static final _people = [MockData.douglas, MockData.animalPoll, MockData.jikoAppeal, MockData.tivard];
  final _members = <String, List<UserSummary>>{
    'l-fedi': [MockData.douglas, MockData.jikoAppeal],
    'l-space': [MockData.douglas, MockData.tivard],
  };
  static const _names = {'l-fedi': 'Fediverse Banner', 'l-space': '宇宙クラスタ'};

  @override
  Future<List<UserListInfo>> lists() async => [
        for (final e in _names.entries) UserListInfo(id: e.key, name: e.value, memberIds: [for (final u in _members[e.key]!) u.id], isPublic: true),
      ];
  @override
  Future<UserListInfo> listInfo(String listId) async => (await lists()).firstWhere((l) => l.id == listId);
  @override
  Future<List<UserSummary>> listMembers(String listId) async => [...?_members[listId]];
  @override
  Future<void> addToList(String listId, String userId) async {
    final u = _people.where((p) => p.id == userId).firstOrNull;
    final list = _members[listId];
    if (u != null && list != null && !list.any((m) => m.id == userId)) list.add(u);
  }

  @override
  Future<void> removeFromList(String listId, String userId) async => _members[listId]?.removeWhere((m) => m.id == userId);
  @override
  Future<Page<UserSummary>> following(String id, {String? cursor, int limit = 20}) async => Page(items: _people);
  @override
  Future<List<ClipInfo>> clips({String? userId}) async => const [
        ClipInfo(id: 'c-launch', name: '打ち上げの記録', description: 'カウントダウンから軌道投入まで', isPublic: true, notesCount: 2),
        ClipInfo(id: 'c-later', name: 'あとで読む', isPublic: true, notesCount: 1),
      ];
  @override
  Future<Page<Post>> clipNotes(String clipId, {String? cursor, int limit = 20}) async {
    if (cursor != null) return Page.empty();
    final ids = clipId == 'c-launch' ? ['p1', 'p3'] : ['p2'];
    return Page(items: [for (final id in ids) await post(id)]);
  }
}

// ── ASTell: 話している印を出すための偽の通話(声の大きさだけ)──

class _SceneMedia implements AstellMedia {
  final links = <String, _SceneLink>{};
  @override
  bool get available => true;
  @override
  AstellMediaIssue? get micBlocked => null;
  @override
  bool get micOpen => false;
  @override
  Future<void> openMic() async {}
  @override
  void setMicEnabled(bool enabled) {}
  @override
  Future<AstellPeerLink> createLink(String peerId, {required bool offerer, required List<Map<String, Object?>> iceServers, required AstellLinkHandlers handlers}) async => links[peerId] = _SceneLink(peerId);
  @override
  Future<void> dispose() async {}
}

class _SceneLink implements AstellPeerLink {
  _SceneLink(this.peerId);
  @override
  final String peerId;
  double level = 0;
  var _state = 'stable';
  bool _remote = false;
  @override
  String get signalingState => _state;
  @override
  bool get hasRemoteDescription => _remote;
  @override
  Future<Map<String, Object?>> createOffer({bool iceRestart = false}) async {
    _state = 'have-local-offer';
    return {'sdp': 'offer-$peerId', 'type': 'offer'};
  }

  @override
  Future<Map<String, Object?>> createAnswer() async => {'sdp': 'answer-$peerId', 'type': 'answer'};
  @override
  Future<void> setRemoteDescription(Map<String, Object?> description) async {
    _remote = true;
    _state = 'stable';
  }

  @override
  Future<void> rollback() async => _state = 'stable';
  @override
  Future<void> addIceCandidate(Map<String, Object?> candidate) async {}
  @override
  void setPlayback(bool on) {}
  @override
  Future<double> remoteAudioLevel() async => level;
  @override
  Future<AstellLinkDiagnostics> diagnostics() async => AstellLinkDiagnostics(peerId: peerId, connectionState: 'connected', signalingState: _state);
  @override
  Future<void> close() async {}
}

// ── カスタムプラグイン: 実物の wasm を同じ isolate で動かす ──

/// スロットのプラグインを、ワーカー isolate ではなくテストの isolate の同期コントローラで動かす
/// (testWidgets の FakeAsync ではワーカーとのやり取りが進まない)。ホスト関数の中継はアプリと同じく後回しで届ける。
class _InProcessSlotRuntime implements SlotRuntime {
  _InProcessSlotRuntime(this.controller);
  final WasmPluginController controller;
  @override
  WasmPluginViewModel get view => controller;
  @override
  Future<Map<String, dynamic>> invoke(String fn, Map<String, Object?> args) async => controller.invoke(fn, args);
  @override
  set onAppFn(AppFnRelay? relay) => controller.env.onAppFn = relay == null ? null : (fn, args) => scheduleMicrotask(() => relay(fn, args));
  @override
  Stream<Map<String, Object?>> get fetchShapes => controller.fetchShapes;
  @override
  void dispose() => controller.dispose();
}

Future<SlotRuntime> _inProcessLoader(Uint8List bytes, {required String source, required Set<String> fowPermissions, required Set<String> appFns, required Set<String> permissions, required int? fuelPerCall, required Set<String> fetchHosts, required bool gpuCompute}) async {
  final env = RasqHostEnvironment(fowPermissions: fowPermissions, appFns: appFns, permissions: permissions, fetchHosts: fetchHosts, gpuCompute: gpuCompute);
  final c = WasmPluginController(wasmBytes: bytes, env: env, fuelPerCall: fuelPerCall)..load();
  if (c.lastError != null && c.document == null) {
    c.dispose();
    throw StateError(c.lastError!);
  }
  return _InProcessSlotRuntime(c);
}

/// サイドロードする「みんなで落書き」の配布物: (登録元のパス, バイト列)。
(String, Uint8List) _paintPackage() {
  for (final path in [Platform.environment['RASQ_PAINT_RSPKG'], '../plugin-sample/custom-plugin-paint/dist/sample.paint-0.1.0.rspkg']) {
    if (path != null && File(path).existsSync()) return (File(path).absolute.path, File(path).readAsBytesSync());
  }
  const bundled = 'assets/plugins/custom_plugin_paint.wasm';
  return (File(bundled).absolute.path, File(bundled).readAsBytesSync());
}

/// ボードに先に描いてあるもの(viewBox 0 0 300 400、編集画面が返す消毒済みの形と同じ: path だけ、塗りなし、丸い線端)。
String _svg(List<(String, String)> paths) =>
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 400">${[for (final (d, color) in paths) '<path d="$d" fill="none" stroke="$color" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/>'].join()}</svg>';

/// 円(3 次ベジエ 4 つ)。
String _circle(double cx, double cy, double r) {
  final k = 0.5523 * r;
  String p(double x, double y) => '${x.round()} ${y.round()}';
  return 'M${p(cx, cy - r)}C${p(cx + k, cy - r)} ${p(cx + r, cy - k)} ${p(cx + r, cy)}C${p(cx + r, cy + k)} ${p(cx + k, cy + r)} ${p(cx, cy + r)}'
      'C${p(cx - k, cy + r)} ${p(cx - r, cy + k)} ${p(cx - r, cy)}C${p(cx - r, cy - k)} ${p(cx - k, cy - r)} ${p(cx, cy - r)}';
}

final _rocketSvg = _svg([
  ('M150 50C192 100 198 190 186 280L114 280C102 190 108 100 150 50Z', '#1E88E5'),
  (_circle(150, 150, 22), '#1E88E5'),
  ('M114 236L78 300L116 286M186 236L222 300L184 286', '#1E88E5'),
  ('M128 292Q150 372 172 292', '#FB8C00'),
]);

final _catSvg = _svg([
  (_circle(150, 230, 92), '#8E24AA'),
  ('M80 172L94 92L132 140M220 172L206 92L168 140', '#8E24AA'),
  ('M112 214L126 214M174 214L188 214', '#212121'),
  ('M142 246L158 246L150 256Z', '#E53935'),
  ('M56 246L118 252M56 268L118 262M244 246L182 252M244 268L182 262', '#6D4C41'),
]);

void main() {
  final fontPath = Platform.environment['RASQ_PREVIEW_FONT'];
  if (fontPath == null || !File(fontPath).existsSync()) {
    test('preview harness needs RASQ_PREVIEW_FONT', () {}, skip: 'RASQ_PREVIEW_FONT を日本語フォント(.ttf)へ向けるとシーンを撮る');
    return;
  }
  setUpAll(() async {
    final bytes = File(fontPath).readAsBytesSync();
    // homeshots_test.dart と同じ: テーマを通らない文字も □ にしない。
    for (final family in ['Roboto', 'NotoSansJP', '.SF UI Text', '.SF UI Display', 'FlutterTest']) {
      final loader = FontLoader(family)..addFont(Future.value(ByteData.view(bytes.buffer)));
      await loader.load();
    }
    const inSdk = 'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
    var icons = Platform.environment['RASQ_PREVIEW_ICONS'] ?? '${Platform.environment['FLUTTER_ROOT'] ?? ''}/$inSdk';
    for (var d = File(Platform.resolvedExecutable).parent; !File(icons).existsSync() && d.path != d.parent.path; d = d.parent) {
      icons = '${d.path}/$inSdk';
    }
    if (File(icons).existsSync()) {
      final loader = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.view(File(icons).readAsBytesSync().buffer)));
      await loader.load();
    } else {
      // ignore: avoid_print
      print('homescenes: Material Icons のフォントが見つかりません ($icons)。アイコンは □ になります');
    }
  });
  tearDownAll(SceneRecorder.writeManifest);

  http.Response json(Object body, [int code = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), code, headers: {'content-type': 'application/json'});

  MemorySessionStorage loggedIn() => MemorySessionStorage({
        SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
      });

  /// 時計を [ms] だけ進める(RAi / ASTell の動きは止まらないので pumpAndSettle は使わない)。
  Future<void> run(WidgetTester tester, [int ms = 1500]) async {
    for (var i = 0; i < ms ~/ 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// [f] が出るまで進める。
  Future<void> until(WidgetTester tester, Finder f, {int ms = 8000}) async {
    for (var t = 0; t < ms && f.evaluate().isEmpty; t += 100) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(f, findsWidgets);
  }

  Rect rectOf(WidgetTester tester, Finder f) => tester.getRect(f);

  /// [ok] になるまで 50ms ずつ進める。
  Future<void> waitUntil(WidgetTester tester, bool Function() ok, {int ms = 8000}) async {
    for (var t = 0; t < ms && !ok(); t += 50) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// いちばん手前の FOW(パネル)の画面上の矩形。
  Rect? fowRect(WidgetTester tester) {
    Rect? union;
    for (final k in ['rasqOverlay.fow.handle.top', 'rasqOverlay.fow.header', 'rasqOverlay.fow.body', 'rasqOverlay.fow.handle.bottom']) {
      final f = find.byKey(ValueKey(k));
      if (f.evaluate().isEmpty) continue;
      final r = tester.getRect(f.last);
      union = union == null ? r : union.expandToInclude(r);
    }
    return union;
  }

  ProviderContainer containerOf(WidgetTester tester) => ProviderScope.containerOf(tester.element(find.byType(RasqApp)));

  // ── RAi の位置と動き ──

  RaiMascot3dController? raiCtrl(WidgetTester tester) {
    final f = find.byType(RaiMascotLayer);
    if (f.evaluate().isEmpty) return null;
    final Object st = tester.state(f);
    return (st as dynamic).controller3d as RaiMascot3dController; // ignore: avoid_dynamic_calls, State は private
  }

  /// いまの RAi(静止の姿勢)。出ていなければ hidden。
  Map<String, Object?> raiNow(WidgetTester tester, SceneRecorder rec) {
    final c = raiCtrl(tester);
    if (c == null || c.opacity <= 0) return const {'visible': false, 'pose': 'hidden'};
    final s = containerOf(tester).read(raiProvider);
    final target = s.mode == RaiMode.instruction ? s.target : null;
    final pointing = c.arm != RaiArm.none && target != null;
    return {
      'visible': true,
      ...rec.point(c.screenPos),
      'scale': SceneRecorder._r(c.sizePx / rec.device.h),
      'pose': pointing ? 'point' : 'idle',
      if (pointing) 'pointTo': rec.point(target.center),
      'arm': c.arm.name,
      'face': c.face == RaiFace.blink ? 'closed' : 'eyes',
      'faceFrame': c.face,
      if (c.opacity < 1) 'opacity': SceneRecorder._r(c.opacity),
      if (c.spinSpeed > 0) 'spin': (2 * math.pi / c.spinSpeed).round(),
    };
  }

  /// RAi が止まるまで進め、その間の移動(出発点 → 到着点、長い / 短い、かかった時間、手前に寄った大きさ)を返す。
  Future<List<Map<String, Object?>>> settleRai(WidgetTester tester, SceneRecorder rec, {int maxMs = 12000, int quietMs = 700}) async {
    final moves = <Map<String, Object?>>[];
    Offset? last;
    ({Offset from, bool long, int t0, double maxSize})? cur;
    var quiet = 0;
    for (var t = 0; t < maxMs; t += 50) {
      await tester.pump(const Duration(milliseconds: 50));
      final c = raiCtrl(tester);
      final plan = c?.plan;
      if (c != null && plan != null) {
        cur ??= (from: last ?? c.screenPos, long: plan.long, t0: t, maxSize: c.sizePx);
        if (c.sizePx > cur.maxSize) cur = (from: cur.from, long: cur.long, t0: cur.t0, maxSize: c.sizePx);
      } else if (cur != null && c != null) {
        moves.add({
          'visible': true,
          ...rec.point(c.screenPos),
          'scale': SceneRecorder._r(c.sizePx / rec.device.h),
          'pose': cur.long ? 'run' : 'walk',
          'from': rec.point(cur.from),
          'approach': SceneRecorder._r(cur.maxSize / rec.device.h),
          'arm': c.arm.name,
          'face': 'eyes',
          'ms': t - cur.t0 + 50,
        });
        cur = null;
      }
      final busy = containerOf(tester).read(raiProvider).busy;
      quiet = plan == null && !busy ? quiet + 50 : 0;
      if (quiet >= quietMs) break;
      last = c?.screenPos;
    }
    return moves;
  }

  /// 操作のあと: RAi が動けば「移動の段」(hold = 移動の時間)を先に、そのあと止まった姿で 1 段。
  /// [enterOf] は落ち着いてから読む(FOW の大きさは出たあとで決まる)。
  Future<String> beat(WidgetTester tester, SceneRecorder rec, {required int hold, Map<String, Object?> Function()? enterOf, Offset? tap, String? caption}) async {
    final moves = await settleRai(tester, rec);
    final frame = await rec.capture(tester);
    final enter = enterOf?.call();
    var first = true;
    for (final m in moves) {
      final ms = m.remove('ms')! as int;
      rec.step(frame: frame, hold: ms, enter: first ? enter : null, tap: first ? tap : null, rai: m, caption: caption);
      first = false;
    }
    rec.step(frame: frame, hold: hold, enter: first ? enter : null, tap: first ? tap : null, rai: raiNow(tester, rec), caption: caption);
    return frame;
  }

  /// RAi の見本の土台(homeshots_test.dart の pumpRaiHome と同じ。マスコットは描かない)。
  Future<ProviderContainer> pumpRaiHome(WidgetTester tester, SceneDevice device, RaiLlm llm, {bool withIndex = true}) async {
    device.apply(tester);
    rootBundle.clear();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(loggedIn()),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline))),
        localNotifierProvider.overrideWithValue(MemoryLocalNotifier()),
        raiLlmProvider.overrideWithValue(llm),
        raiEmbeddingModelProvider.overrideWithValue(FakeRaiEmbeddingModel()),
        deviceRamReaderProvider.overrideWithValue(() async => (totalMb: 8192, availableMb: 4096)),
        raiMascotHiddenProvider.overrideWithValue(true),
        if (!withIndex) raiReferenceProvider.overrideWith((ref) => Future<RaiReferenceIndex>.error(StateError('会話の見本では操作の索引を使わない'))),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    final c = containerOf(tester);
    if (withIndex) await tester.runAsync(() => c.read(raiReferenceProvider.future));
    await tester.pumpAndSettle();
    c.read(routerProvider).push(Routes.rai);
    await run(tester, 2000);
    return c;
  }

  // ── rai(a): 案内「TL にリストを設定」──
  Future<void> raiGuide(WidgetTester tester, SceneDevice device) async {
    final rec = SceneRecorder.of('rai', device);
    const cap = '案内「TL にリストを設定」';
    final c = await pumpRaiHome(tester, device, FakeRaiLlm());
    final n = c.read(raiProvider.notifier);
    // バーのトグルでインストラクションへ(RAi のページが閉じる = pop、ホームのタイムラインに戻る)。
    final toggle = tester.getCenter(find.byKey(const ValueKey('rai.toggle')));
    await tester.tap(find.byKey(const ValueKey('rai.toggle')));
    await run(tester);
    expect(c.read(raiProvider).mode, RaiMode.instruction);
    await tester.enterText(find.byKey(const ValueKey('rai.input')), 'TL にリストを設定');
    await run(tester, 600);
    final f0 = await rec.capture(tester);
    rec.step(frame: f0, hold: 1600, enter: rec.pop(), tap: toggle, rai: raiNow(tester, rec), caption: '$cap: 質問を入れる');
    // 質問する → RAi が出て、選んでいるタブの ∨ へ走って指す。
    final ask = tester.getCenter(find.byKey(const ValueKey('rai.ask')));
    await tester.tap(find.byKey(const ValueKey('rai.ask')));
    await run(tester, 300);
    if (c.read(raiProvider).lastOperation != 'tl-list' && !c.read(raiProvider).busy) {
      // 索引の引き方が変わって別の操作に当たっても、見本は同じ案内にする(テストの偽物の埋め込みは n-gram)。
      n.dismissBubble();
      unawaited(n.runInstruction('tl-list'));
    }
    await beat(tester, rec, hold: 2000, enterOf: () => rec.replace(), tap: ask, caption: '$cap: RAi が「∨」を指す');
    expect(c.read(raiProvider).lastOperation, 'tl-list', reason: '「TL にリストを設定」は操作 tl-list の案内になる');
    expect(c.read(raiProvider).stepIndex, 0);
    // 指した部品を押す → 一時変更の FOW が出る。
    var at = c.read(raiProvider).target!.center;
    await tester.tapAt(at);
    await waitUntil(tester, () => c.read(raiProvider).stepIndex == 1);
    expect(c.read(raiProvider).stepIndex, 1);
    await beat(tester, rec, hold: 1400, enterOf: () => rec.replace(fowRect(tester)), tap: at, caption: '$cap: 一時変更の FOW');
    // 「タイムラインを追加」は FOW の下のほう。送って見えるようにしてから RAi に取り直させる(人が送るのと同じ)。
    final config = find.descendant(of: find.byType(TimelineConfigScreen), matching: find.byType(Scrollable)).first;
    final dragFrom = tester.getCenter(config);
    await tester.scrollUntilVisible(find.descendant(of: find.byType(TimelineConfigScreen), matching: find.text('タイムラインを追加')), 120, scrollable: config);
    await tester.drag(config, const Offset(0, -80));
    await run(tester, 800);
    unawaited(n.relocate());
    await beat(tester, rec, hold: 2000, enterOf: () => rec.replace(fowRect(tester)), tap: dragFrom, caption: '$cap: 送って「タイムラインを追加」を指す');
    expect(c.read(raiProvider).target, isNotNull);
    at = c.read(raiProvider).target!.center;
    await tester.tapAt(at);
    await waitUntil(tester, () => c.read(raiProvider).stepIndex == 2);
    expect(c.read(raiProvider).stepIndex, 2);
    await beat(tester, rec, hold: 1800, enterOf: () => rec.replace(fowRect(tester)), tap: at, caption: '$cap: 「リストTL」を選ぶ');
    // 人の操作: リストTL → 取得のノード → リストを選ぶ。
    for (final label in ['リストTL', 'リストTLを取得']) {
      at = tester.getCenter(find.text(label).last);
      await tester.tap(find.text(label).last);
      await run(tester);
      await beat(tester, rec, hold: 1200, enterOf: () => rec.replace(fowRect(tester)), tap: at, caption: '$cap: 「$label」');
    }
    at = tester.getCenter(find.text('Fediverse Banner').last);
    await tester.tap(find.text('Fediverse Banner').last);
    await run(tester, 1000);
    await beat(tester, rec, hold: 1800, enterOf: () => rec.replace(fowRect(tester)), tap: at, caption: '$cap: リストを選ぶ');
    at = tester.getCenter(find.text('決定').last);
    // ノードの設定の FOW が閉じる(閉じた FOW のところが替わる)。
    final closing = fowRect(tester);
    await tester.tap(find.text('決定').last);
    await run(tester);
    unawaited(n.next());
    await waitUntil(tester, () => c.read(raiProvider).stepIndex == 3);
    await beat(tester, rec, hold: 2000, enterOf: () => rec.replace(closing), tap: at, caption: '$cap: そのタブにリストの投稿が流れる');
    expect(c.read(raiProvider).stepIndex, 3);
    unawaited(n.next());
    await waitUntil(tester, () => c.read(raiProvider).stepIndex == 4);
    await beat(tester, rec, hold: 2000, caption: '$cap: RAi が「決定」を指す');
    expect(c.read(raiProvider).stepIndex, 4);
    at = c.read(raiProvider).target!.center;
    final before = fowRect(tester);
    await tester.tapAt(at);
    await waitUntil(tester, () => c.read(raiProvider).bubble == null);
    expect(c.read(raiProvider).bubble, isNull, reason: '最後の手順の部品を押すと案内は閉じる');
    // 決定すると一時変更の FOW は stick に畳まれる(高さが縮む = sheetDown、180ms)。
    await beat(tester, rec, hold: 1200, enterOf: () => rec.sheetDown(before ?? Offset.zero & device.size), tap: at, caption: '$cap: 「決定」を押す');
    // stick に畳んだ一時変更を ✕ で閉じる(一時変更はそのタブに残る)。
    final close = tester.getCenter(find.byKey(const ValueKey('tl.temp.close')));
    await tester.tap(find.byKey(const ValueKey('tl.temp.close')));
    await run(tester, 2000);
    final last = await rec.capture(tester);
    rec.step(frame: last, hold: 2400, enter: rec.replace(), tap: close, rai: raiNow(tester, rec), caption: '$cap: 決定したタイムライン');
  }

  // ── rai(b): アシスタントとの会話「ハロー、RAi さん」──
  const raiChatAnswer = 'ハロー！RAi です。タイムラインの整え方や ASTell のルーム探し、投稿の下書きまで、RASQ のことなら何でも聞いてくださいね。';

  Future<void> raiChat(WidgetTester tester, SceneDevice device) async {
    final rec = SceneRecorder.of('rai', device);
    const cap = 'アシスタント「ハロー、RAi さん」';
    final c = await pumpRaiHome(tester, device, _SlowRaiLlm(answer: raiChatAnswer), withIndex: false);
    expect(c.read(raiProvider).mode, RaiMode.assistant);
    final f0 = await rec.capture(tester);
    // RAi のページはサイドバーの「RAi」から push(MaterialPage)。
    rec.step(frame: f0, hold: 1600, enter: rec.push(), rai: raiNow(tester, rec), caption: '$cap: RAi のホーム');
    await tester.enterText(find.byKey(const ValueKey('rai.input')), 'ハロー、RAi さん');
    await run(tester, 600);
    final f1 = await rec.capture(tester);
    rec.step(frame: f1, hold: 1400, tap: tester.getCenter(find.byKey(const ValueKey('rai.input'))), rai: raiNow(tester, rec), caption: '$cap: 話しかける');
    final ask = tester.getCenter(find.byKey(const ValueKey('rai.ask')));
    await tester.tap(find.byKey(const ValueKey('rai.ask')));
    await run(tester, 500);
    expect(c.read(raiProvider).busy, isTrue);
    final f2 = await rec.capture(tester);
    rec.step(frame: f2, hold: 1000, tap: ask, rai: raiNow(tester, rec), caption: '$cap: 考え中');
    Future<void> wait(bool Function() ok) async {
      for (var k = 0; k < 200 && !ok(); k++) {
        await tester.pump(const Duration(milliseconds: 40));
      }
    }

    String bubble() => c.read(raiProvider).bubble ?? '';
    await wait(() => bubble().length >= raiChatAnswer.length ~/ 3);
    rec.step(frame: await rec.capture(tester), hold: 700, rai: raiNow(tester, rec), caption: '$cap: 返事が流れる');
    await wait(() => bubble().length >= raiChatAnswer.length * 2 ~/ 3);
    rec.step(frame: await rec.capture(tester), hold: 700, rai: raiNow(tester, rec), caption: '$cap: 返事が流れる');
    await wait(() => !c.read(raiProvider).busy);
    await run(tester, 1000);
    expect(c.read(raiProvider).bubble, raiChatAnswer);
    rec.step(frame: await rec.capture(tester), hold: 3200, rai: raiNow(tester, rec), caption: '$cap: 返事');
  }

  // ── client: サイドバー → リスト → クリップ → 検索 ──
  Future<void> client(WidgetTester tester, SceneDevice device) async {
    final rec = SceneRecorder.of('client', device);
    final wide = device == SceneDevice.tabletWide;
    device.apply(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(loggedIn()),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(_SceneSnsPlugin())),
        localNotifierProvider.overrideWithValue(MemoryLocalNotifier()),
        raiMascotHiddenProvider.overrideWithValue(true),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    final full = Offset.zero & device.size;
    Future<String> shot(int hold, {Map<String, Object?>? enter, Offset? tap, String? caption}) async {
      await run(tester, 600);
      final f = await rec.capture(tester);
      rec.step(frame: f, hold: hold, enter: enter, tap: tap, caption: caption);
      return f;
    }

    Future<Offset> tapOn(Finder f) async {
      final at = tester.getCenter(f);
      await tester.tap(f);
      return at;
    }

    await shot(1600, caption: 'RASQ クライアント: ホームのタイムライン');
    // サイドバー(アカウントのアイコン)。サイドバーは rasq_overlay の sidebar 層 = その場で出る。
    var at = await tapOn(wide ? find.byKey(const ValueKey('rail.avatar')) : find.byType(RasqHeaderAvatarButton).first);
    await run(tester, 300);
    await shot(1600, enter: rec.replace(rectOf(tester, find.byType(RasqSidebar))), tap: at, caption: 'サイドバーを開く');
    // リスト(全画面のページ = push)。
    at = await tapOn(find.descendant(of: find.byType(RasqSidebar), matching: find.text('リスト')));
    await tester.pumpAndSettle();
    await shot(2000, enter: rec.push(full), tap: at, caption: 'リスト・クリップ');
    at = await tapOn(find.byKey(const ValueKey('lists.list.l-fedi')));
    await tester.pumpAndSettle();
    await shot(1800, enter: rec.push(full), tap: at, caption: 'リスト「Fediverse Banner」のメンバー');
    // メンバーを追加(フォロー中から選ぶ FOW)。
    at = await tapOn(find.byKey(const ValueKey('lists.members.add')));
    await run(tester, 1000);
    await until(tester, find.byKey(ValueKey('lists.members.chip.sns:${MockData.animalPoll.id}')));
    await shot(1600, enter: rec.replace(fowRect(tester)), tap: at, caption: 'メンバーを追加: フォロー中から選ぶ');
    at = await tapOn(find.byKey(ValueKey('lists.members.chip.sns:${MockData.animalPoll.id}')));
    await run(tester, 300);
    await shot(1400, enter: rec.replace(fowRect(tester)), tap: at, caption: '「動物Poll」を選ぶ');
    final sheet = fowRect(tester);
    at = await tapOn(find.text('追加').last);
    await run(tester, 800);
    await shot(1800, enter: rec.replace(sheet), tap: at, caption: 'リストに追加しました');
    // 外す(事故アピール)。
    at = await tapOn(find.descendant(of: find.ancestor(of: find.text('事故アピール'), matching: find.byType(RasqUserRow)), matching: find.text('外す')));
    await run(tester, 800);
    final listArea = rectOf(tester, find.byType(TabBarView).last);
    await shot(1800, enter: rec.replace(listArea), tap: at, caption: '「事故アピール」を外す');
    // 戻ってクリップ。
    at = await tapOn(find.byTooltip('戻る').hitTestable().first);
    await tester.pumpAndSettle();
    await shot(1400, enter: rec.pop(full), tap: at, caption: 'リスト・クリップ');
    at = await tapOn(find.byKey(const ValueKey('lists.clip.c-launch')));
    await tester.pumpAndSettle();
    await shot(2000, enter: rec.push(full), tap: at, caption: 'クリップ「打ち上げの記録」');
    // ホームへ戻って検索。
    at = await tapOn(find.byTooltip('戻る').hitTestable().first);
    await tester.pumpAndSettle();
    await shot(900, enter: rec.pop(full), tap: at, caption: 'リスト・クリップ');
    at = await tapOn(find.byTooltip('戻る').hitTestable().first);
    await tester.pumpAndSettle();
    await shot(1000, enter: rec.pop(full), tap: at, caption: 'ホーム');
    Rect content;
    if (!wide) {
      // ボトムナビの「検索」(StatefulShellRoute のタブ = その場で替わる。ボトムナビは動かない)。
      final nav = rectOf(tester, find.byType(NavigationBar));
      content = Rect.fromLTRB(0, 0, device.w, nav.top);
      at = await tapOn(find.byTooltip('検索').hitTestable().first);
      await tester.pumpAndSettle();
      await shot(1400, enter: rec.replace(content), tap: at, caption: '検索とトレンド');
    } else {
      content = full;
    }
    final box = find.descendant(of: find.byType(SearchFilterBox).last, matching: find.byType(TextField));
    at = await tapOn(box);
    await tester.pump();
    await tester.enterText(box, '打上会');
    await run(tester, 400);
    await shot(1400, enter: rec.replace(rectOf(tester, find.byType(SearchFilterBox).last).inflate(8)), tap: at, caption: '検索: 「打上会」');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    // 狭い画面はタブの中のページ(ボトムナビの上で push)、広い画面は第3カラムに開く(その場で替わり、カラムの幅が動く)。
    await shot(2600, enter: wide ? rec.replace(Rect.fromLTRB(72, 0, device.w, device.h), _paneMs) : rec.push(content), caption: '検索結果(#打上会)');
  }

  // ── account: アカウントページのタブ → みんなで落書き ──
  Future<void> account(WidgetTester tester, SceneDevice device) async {
    final rec = SceneRecorder.of('account', device);
    device.apply(tester);
    const author = {'id': 'acc-1', 'handle': 'hana', 'displayName': 'はな'};
    const owner = {'id': 'acc-1', 'handle': 'hana', 'displayName': 'はな'};
    Map<String, Object?> collection(String id, String kind, String name, String description, int items) => {
          'id': id, 'code': id.toUpperCase(), 'kind': kind, 'name': name, 'description': description, 'visibility': 'public', 'owner': owner,
          'itemCount': items, 'followerCount': 3, 'instances': ['misskey.io', 'mastodon.social'], 'updatedAt': '2026-10-01T00:00:00Z',
        };
    final mock = MockClient((req) async {
      final path = req.url.path.replaceFirst('/api/v1', '');
      switch ('${req.method} $path') {
        case 'GET /accounts/hana':
          return json({
            'id': 'acc-1', 'handle': 'hana', 'displayName': 'はな', 'bio': '写真と宇宙の話をします。ASTell で夜の雑談もやっています。', 'location': '東京', 'birthday': '', 'createdAt': '2026-09-01T00:00:00Z',
            'links': [{'label': 'サイト', 'url': 'https://example.com/'}],
            'snsAccounts': [
              {'accountKey': 'misskey:misskey.io:hana', 'kind': 'misskey', 'instance': 'misskey.io', 'handle': 'hana', 'displayName': 'はな', 'serverName': 'Misskey.io', 'visibility': 'auto', 'autoVisible': true, 'visible': true},
              {'accountKey': 'mastodon:mastodon.social:hana', 'kind': 'mastodon', 'instance': 'mastodon.social', 'handle': 'hana', 'displayName': 'hana', 'serverName': 'Mastodon', 'visibility': 'auto', 'autoVisible': true, 'visible': true},
            ],
            'plugins': [
              {'id': 'sample.paint', 'name': 'みんなで落書き', 'summary': '1 人 1 マスの落書きボード。プロフィールやルームに置けます'},
              {'id': 'sample.board', 'name': 'みんなのボード', 'summary': '付箋を貼って集まった人と共有'},
            ],
            'reviews': [
              {'pluginId': 'sample.timeline', 'pluginName': 'Unicode 順のタイムライン', 'rating': 4, 'title': '並びが面白い', 'body': '文字の順に並ぶので、知らない投稿に出会えます。'},
            ],
          });
        case 'GET /accounts/hana/posts':
          return json({
            'source': 'rasq', 'limit': 3,
            'posts': [
              {'id': 'p1', 'author': author, 'body': '今夜 21 時から ASTell で「夜の雑談」をやります。写真の話をゆるく。', 'images': <Object>[], 'createdAt': '2026-10-09T12:00:00Z', 'replyCount': 3, 'rebroadCount': 2, 'rebroaded': false, 'queues': <Object>[]},
              {'id': 'p2', 'author': author, 'body': 'ロケットの打ち上げ、無事に成功しました。おめでとうございます！ #打上会', 'images': <Object>[], 'createdAt': '2026-10-08T09:30:00Z', 'replyCount': 1, 'rebroadCount': 5, 'rebroaded': false, 'queues': <Object>[]},
              {'id': 'p3', 'author': author, 'body': 'RASQ アカウントを作りました。SNS のアカウントを束ねて使っています。', 'images': <Object>[], 'createdAt': '2026-09-01T00:00:00Z', 'replyCount': 0, 'rebroadCount': 0, 'rebroaded': false, 'queues': <Object>[]},
            ],
          });
        case 'GET /accounts/hana/rasq-collections':
          return json(req.url.queryParameters['kind'] == 'clip'
              ? [collection('rc-photo', 'clip', '夜空の写真', '撮った星空と、見つけた夜景', 18)]
              : [collection('rc-space', 'list', '宇宙の人たち', 'Misskey / Mastodon / Bluesky の宇宙クラスタ', 24), collection('rc-cam', 'list', 'カメラ仲間', '', 9)]);
        case 'GET /accounts/hana/md-pages':
          return json([{'id': 'about', 'title': 'はなのこと', 'updatedAt': '2026-10-01T00:00:00Z'}]);
        case 'GET /accounts/hana/sideload-pages':
          return json(<Object>[]);
      }
      return json({'error': {'code': '404', 'message': 'not found'}}, 404);
    });
    // 共有のボード(モックの Central): はなのプロフィールのセッション。訪れた「あなた」は参加者(持ち主ははな)。
    final custom = MockCustomSessionClient(me: const CustomParticipant(accountId: 'me', handle: 'tester', displayName: 'テスター'));
    final created = await custom.create(pluginId: 'sample.paint', version: '0.1.0', scope: 'profile');
    custom.sessions[created.id] = CustomSession(id: created.id, pluginId: 'sample.paint', version: '0.1.0', scope: created.scope, title: 'みんなで落書き', ownerAccountId: 'acc-1', ownerHandle: 'hana', createdAt: created.createdAt);
    custom.seedPage('hana', const CustomProfilePage(pluginId: 'sample.paint', version: '0.1.0', name: 'みんなで落書き', icon: 'brush', mode: 'shared'));
    final now = DateTime.now().millisecondsSinceEpoch;
    custom.others[created.id] = const [CustomParticipant(accountId: 'acc-1', handle: 'hana', displayName: 'はな'), CustomParticipant(accountId: 'douglas', handle: 'douglas', displayName: 'ダグラス')];
    custom.vars[created.id] = {
      '@acc-1.paint': CustomVar(value: {'svg': _catSvg, 'updatedAt': now - 3600000, 'ttl': 86400, 'name': 'はな'}, rev: 1, by: 'acc-1', expiresAt: now + 82800000),
      '@douglas.paint': CustomVar(value: {'svg': _rocketSvg, 'updatedAt': now - 600000, 'ttl': 259200, 'name': 'ダグラス'}, rev: 1, by: 'douglas', expiresAt: now + 258600000),
    };
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(loggedIn()),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline))),
        localNotifierProvider.overrideWithValue(MemoryLocalNotifier()),
        orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: mock, tokenProvider: () => ref.read(orgateTokenHolderProvider).token)),
        centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
        orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
        customSessionClientProvider.overrideWithValue(custom),
        slotRuntimeLoaderProvider.overrideWithValue(_inProcessLoader),
        raiMascotHiddenProvider.overrideWithValue(true),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    final c = containerOf(tester);
    // カスタムプラグイン「みんなで落書き」をサイドロード(ファイルから。署名が無いので制限モード = 通信なし。描画と共有セッションは使える)。
    final (source, bytes) = _paintPackage();
    final plugin = await tester.runAsync(() => c.read(slotPluginsProvider.notifier).register(source, bytes: bytes, persist: false));
    expect(plugin?.manifest.id, 'sample.paint', reason: c.read(slotPluginsNoticeProvider));
    c.read(routerProvider).push(Routes.rasqAccount('hana'));
    await tester.pumpAndSettle();
    final full = Offset.zero & device.size;
    Future<String> shot(int hold, {Map<String, Object?>? enter, Offset? tap, String? caption}) async {
      await run(tester, 500);
      final f = await rec.capture(tester);
      rec.step(frame: f, hold: hold, enter: enter, tap: tap, caption: caption);
      return f;
    }

    // 最初の段: 前の周回の終わり(落書きのページ)から戻ってくる = pop。
    await shot(2000, enter: rec.pop(full), caption: 'RASQ アカウント(QuickView): 投稿');
    // 横に送れるタブの行で、画面の外のタブを見えるところへ(人がタブの行を送るのと同じ。ensureVisible は縦のページまで送ってしまう)。
    Future<void> showTab(Finder tab) async {
      for (var i = 0; i < 6; i++) {
        final r = tester.getRect(tab);
        if (r.left >= 0 && r.right <= device.w) break;
        await tester.drag(find.byType(TabBar), Offset(r.right > device.w ? -160 : 160, 0));
        await tester.pumpAndSettle();
      }
    }

    // タブを順に(TabBarView の横送り)。
    for (final (tab, hold, caption) in [
      ('メディア', 1100, 'メディア'),
      ('ページ', 1600, 'ページ: カスタムプラグインと Markdown のページ'),
      ('リスト', 1400, 'RASQ リスト'),
      ('クリップ', 1300, 'RASQ クリップ'),
      ('プラグイン', 1400, '公開したプラグイン'),
      ('レビュー', 1400, 'レビュー'),
    ]) {
      final tabFinder = find.widgetWithText(Tab, tab);
      await showTab(tabFinder);
      final at = tester.getCenter(tabFinder);
      await tester.tap(tabFinder);
      await tester.pumpAndSettle();
      await shot(hold, enter: rec.push(rectOf(tester, find.byType(TabBarView).first), _tabMs), tap: at, caption: caption);
    }
    // ページのタブへ戻ってカスタムプラグインを開く。
    final pagesTab = find.widgetWithText(Tab, 'ページ');
    await showTab(pagesTab);
    var at = tester.getCenter(pagesTab);
    await tester.tap(pagesTab);
    await tester.pumpAndSettle();
    await shot(1200, enter: rec.pop(rectOf(tester, find.byType(TabBarView).first), _tabMs), tap: at, caption: 'ページ');
    final tile = find.byKey(const ValueKey('rasqPage.custom.sample.paint'));
    at = tester.getCenter(tile);
    await tester.tap(tile);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await until(tester, find.text('✏️ タップして描く'));
    await run(tester, 600);
    await shot(2200, enter: rec.push(full), tap: at, caption: 'カスタムプラグイン「みんなで落書き」: 1 人 1 マスのボード');
    // 自分のマス → ホストの SVG 編集画面(media.editor.open)。
    final mine = find.text('✏️ タップして描く');
    at = tester.getCenter(mine);
    await tester.tap(mine);
    await until(tester, find.byKey(const ValueKey('svgpaint.canvas')));
    await run(tester, 400);
    await shot(1400, enter: rec.fade(full), tap: at, caption: '自分のマスを押すと SVG の編集画面');
    // 描く: 顔(橙)→ 目(黒)→ 口(赤)。指でなぞる。
    final canvas = tester.getRect(find.byKey(const ValueKey('svgpaint.canvas')));
    Offset p(double x, double y) => canvas.topLeft + Offset(canvas.width * x, canvas.height * y);
    Future<Offset> stroke(List<Offset> points) async {
      final g = await tester.startGesture(points.first);
      for (final q in points.skip(1)) {
        await g.moveTo(q);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await tester.pump();
      return points.last;
    }

    Future<void> color(int i) async {
      await tester.tap(find.byKey(ValueKey('svgpaint.color.$i')));
      await tester.pump();
    }

    await color(2);
    final face = [for (var i = 0; i <= 36; i++) p(0.5 + 0.34 * math.cos(-math.pi / 2 + i * math.pi / 18), 0.47 + 0.26 * math.sin(-math.pi / 2 + i * math.pi / 18))];
    at = await stroke(face);
    await shot(1100, enter: rec.replace(canvas), tap: at, caption: '指でなぞって描く');
    await color(0);
    await stroke([p(0.38, 0.38), p(0.38, 0.40), p(0.38, 0.43)]);
    at = await stroke([p(0.62, 0.38), p(0.62, 0.40), p(0.62, 0.43)]);
    await color(1);
    at = await stroke([for (var i = 0; i <= 12; i++) p(0.34 + 0.32 * i / 12, 0.54 + 0.09 * math.sin(i * math.pi / 12))]);
    await shot(1300, enter: rec.replace(canvas), tap: at, caption: '色を替えて描き足す');
    // 完了 → 編集画面が閉じ(フェード)、プラグインが共有変数へ書く(shared.set me.paint + ttl)→ ボードのマスに絵が出る。
    final before = find.byType(SvgLiteView).evaluate().length;
    final done = find.byKey(const ValueKey('svgpaint.done'));
    at = tester.getCenter(done);
    await tester.tap(done);
    for (var i = 0; i < 40 && find.byType(SvgLiteView).evaluate().length <= before; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(SvgLiteView).evaluate().length, greaterThan(before), reason: '自分のマスに落書き');
    final v = custom.vars[created.id]!['@me.paint'];
    expect(v, isNotNull, reason: '共有変数に書いた');
    await run(tester, 600);
    await shot(2800, enter: rec.fade(full), tap: at, caption: '「完了」でみんなのボードに投稿(期限つきで共有)');
  }

  // ── astell: ルームで聞いている(画面共有のライブ映像はプレイヤーが描く)──
  Future<void> astell(WidgetTester tester, SceneDevice device) async {
    final rec = SceneRecorder.of('astell', device);
    device.apply(tester);
    final client = MockAstellClient();
    final media = _SceneMedia();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(loggedIn()),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline))),
        localNotifierProvider.overrideWithValue(MemoryLocalNotifier()),
        astellClientProvider.overrideWithValue(client),
        astellMediaFactoryProvider.overrideWithValue(() => media),
        astellLevelIntervalProvider.overrideWithValue(null),
        raiMascotHiddenProvider.overrideWithValue(true),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    final c = containerOf(tester);
    final room = (await c.read(astellClientProvider).room('r-launch'))!;
    await c.read(astellSessionProvider.notifier).join(room);
    await tester.pumpAndSettle();
    final nav = rectOf(tester, find.byType(NavigationBar));
    var at = tester.getCenter(find.byTooltip('ASTell'));
    await tester.tap(find.byTooltip('ASTell'));
    await tester.pumpAndSettle();
    Map<String, Object?>? video() {
      final f = find.byType(AstellLiveVideo).hitTestable();
      if (f.evaluate().isEmpty) return null;
      final r = tester.getRect(f.first);
      final frame = find.ancestor(of: f.first, matching: find.byType(Stack)).first;
      final overlays = <Rect>[];
      // 札(LIVE)・種類のアイコン・…(丸い下地ごと)・題名。
      for (final (part, pad) in [(find.text('LIVE'), 6.0), (find.byIcon(Icons.desktop_windows), 6.0), (find.byIcon(Icons.more_horiz), 7.0), (find.textContaining('TiVard の画面'), 3.0)]) {
        final hit = find.descendant(of: frame, matching: part);
        if (hit.evaluate().isEmpty) continue;
        overlays.add(tester.getRect(hit.first).inflate(pad).intersect(r));
      }
      return {'rect': rec.rect(r), 'radius': 12, 'overlays': [for (final o in overlays) rec.rect(o)]};
    }

    Future<void> shot(int hold, {Map<String, Object?>? enter, Offset? tap, String? caption}) async {
      await run(tester, 500);
      final f = await rec.capture(tester);
      rec.step(frame: f, hold: hold, enter: enter, tap: tap, video: video(), caption: caption);
    }

    await shot(1500, enter: rec.replace(Rect.fromLTRB(0, 0, device.w, nav.top)), tap: at, caption: 'ASTell: 参加中のルーム');
    at = tester.getCenter(find.textContaining('参加中: '));
    await tester.tap(find.textContaining('参加中: '));
    await tester.pumpAndSettle();
    final fow = fowRect(tester)!;
    await shot(2200, enter: rec.replace(fow), tap: at, caption: 'ルーム「打ち上げの打ち上げ」を聞いている: TiVard が画面を共有中');
    // ルームの動き: 話している人(声の大きさ)と、字幕の文字起こし。
    final session = c.read(astellSessionProvider.notifier);
    var seq = 10;
    Future<void> say(String peerId, String accountId, String name, String text) async {
      for (final l in media.links.values) {
        l.level = l.peerId == peerId ? 0.4 : 0;
      }
      await tester.runAsync(() async => session.mesh?.pollLevels()); // ignore: invalid_use_of_visible_for_testing_member, 話している印は通話の声の大きさから
      client.emit('r-launch', {
        'type': 'transcript',
        'transcript': {'id': 't${seq++}', 'accountId': accountId, 'handle': accountId, 'displayName': name, 'text': text, 'lang': 'ja', 'pinned': false, 'createdAt': DateTime(2026, 9, 6, 20, seq).toIso8601String()},
      });
      await run(tester, 600);
    }

    await say('p1', 'douglas', 'ダグラス', '第 2 段の分離、映像で見るとほんとにきれい');
    await shot(2000, enter: rec.replace(fow), caption: 'ダグラスが話している(字幕が流れる)');
    await say('p2', 'tivard', 'TiVard', 'いま映してるのがフェアリング開くところ');
    await shot(2000, enter: rec.replace(fow), caption: '画面を共有している TiVard が話す');
    await say('p3', 'yamahaya', '山ハヤ', 'スタビライザー、ここで効いてるね');
    await shot(2000, enter: rec.replace(fow), caption: '山ハヤが話す');
    for (final l in media.links.values) {
      l.level = 0;
    }
    await tester.runAsync(() async => session.mesh?.pollLevels()); // ignore: invalid_use_of_visible_for_testing_member, 話している印は通話の声の大きさから
    await shot(1600, enter: rec.replace(fow), caption: 'ルームで聞いている');
  }

  // ── テスト ──
  testWidgets('rai (phone): guide', (tester) => raiGuide(tester, SceneDevice.phone));
  testWidgets('rai (phone): chat', (tester) => raiChat(tester, SceneDevice.phone));
  testWidgets('rai (tablet): guide', (tester) => raiGuide(tester, SceneDevice.tablet));
  testWidgets('rai (tablet): chat', (tester) => raiChat(tester, SceneDevice.tablet));
  testWidgets('client (tabletWide)', (tester) => client(tester, SceneDevice.tabletWide));
  testWidgets('client (phone)', (tester) => client(tester, SceneDevice.phone));
  testWidgets('account (tablet)', (tester) => account(tester, SceneDevice.tablet));
  testWidgets('account (phone)', (tester) => account(tester, SceneDevice.phone));
  testWidgets('astell (tablet)', (tester) => astell(tester, SceneDevice.tablet));
  testWidgets('astell (phone)', (tester) => astell(tester, SceneDevice.phone));
}
