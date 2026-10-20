import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_angle/flutter_angle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/rai/rai_diagnostics.dart';
import 'package:rasq_client/features/rai/rai_mascot_3d.dart';

/// GPU の無い flutter_angle (D-520): 初期化 / テクスチャを作るところで投げる・止まる・待たれない Future で投げる。
class _FakeAngle implements FlutterAngle {
  _FakeAngle({this.initError, this.strayError = false, this.hangInit = false});
  final Error? initError;

  /// 待たれない Future で投げてから止まる(three_js / flutter_angle の中で例外が捨てられる場合の代わり)。
  final bool strayError;
  final bool hangInit;
  final calls = <String>[];
  AngleOptions? options;

  @override
  Future<void> init([bool useDebugContext = false, bool useAngle = true]) async {
    calls.add('init useAngle=$useAngle');
    if (strayError) unawaited(Future<void>.error(StateError('stray EGL error (fake)')));
    if (hangInit || strayError) await Completer<void>().future;
    if (initError != null) throw initError!;
  }

  @override
  Future<FlutterAngleTexture> createTexture(AngleOptions options) async {
    this.options = options;
    calls.add('createTexture');
    throw StateError('no GPU in tests');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Recorder {
  final stages = <String>[];
  final details = <String?>[];
  final errors = <(String, Object)>[];
  var frames = 0;
  Rai3dHooks get hooks => Rai3dHooks(
        stage: (s, [d]) {
          stages.add(s);
          details.add(d);
        },
        error: (s, e, _) => errors.add((s, e)),
        firstFrame: () => frames++,
      );
}

RaiThreeJS _three(_Recorder r, _FakeAngle angle, {bool deviceGles = true}) {
  final t = RaiThreeJS(onSetupComplete: () {}, setup: () async {}, hooks: r.hooks, deviceGles: deviceGles)
    ..angle = angle
    ..screenSize = const Size(100, 200);
  t.setResolution(2);
  return t;
}

void main() {
  group('準備の段階の記録 (Rai3dStages)', () {
    test('段階の名前と開始からの経過を残し、要約は最後の段階', () {
      final log = <String>[];
      final s = Rai3dStages(log.add);
      expect(s.current, 'created');
      s.mark('angle init start');
      s.mark('texture done', 'id=3');
      expect(log, hasLength(2));
      expect(log[0], matches(RegExp(r'^stage angle init start \+\d+ms$')));
      expect(log[1], matches(RegExp(r'^stage texture done \+\d+ms: id=3$')));
      expect(s.current, 'texture done');
      expect(s.summary, startsWith('last stage: texture done at +'));
    });

    test('raiStage は start / done を残し、値の詳細を付ける', () async {
      final log = <String>[];
      final s = Rai3dStages(log.add);
      final v = await raiStage(s, 'glb bytes', () async => 42, detail: (v) => '$v bytes');
      expect(v, 42);
      expect(log.first, startsWith('stage glb bytes start'));
      expect(log.last, endsWith(': 42 bytes'));
      expect(s.current, 'glb bytes done');
    });

    test('raiStage は待ち時間を過ぎたら段階の名前入りで失敗し、段階は start のまま', () async {
      final log = <String>[];
      final s = Rai3dStages(log.add);
      await expectLater(
        raiStage(s, 'glb parse', () => Completer<int>().future, timeout: const Duration(milliseconds: 10)),
        throwsA(isA<TimeoutException>().having((e) => e.message, 'message', contains('glb parse'))),
      );
      expect(s.current, 'glb parse start');
    });

    test('raiStage の例外はそのまま投げる(段階は start のまま)', () async {
      final s = Rai3dStages((_) {});
      await expectLater(raiStage(s, 'face sheet', () async => throw StateError('decode')), throwsStateError);
      expect(s.current, 'face sheet start');
    });
  });

  group('Android の 3D の設定 (D-520)', () {
    test('テクスチャの解像度は 1.5 倍まで(小さい端末はそのまま)', () {
      expect(raiAndroidTextureDpr(2.75), raiAndroidMaxTextureDpr);
      expect(raiAndroidTextureDpr(1.0), 1.0);
    });
    test('「準備ができた」を最初の 1 枚まで待つのは Android だけ', () {
      expect(raiMascot3dReadyOnFirstFrame(TargetPlatform.android), isTrue);
      expect(raiMascot3dReadyOnFirstFrame(TargetPlatform.iOS), isFalse);
      expect(raiMascot3dReadyOnFirstFrame(TargetPlatform.macOS), isFalse);
    });
  });

  group('RaiThreeJS: three_js の準備の段階と例外 (D-520)', () {
    test('Android(端末の GLES)は ANGLE を使わずに初期化し、テクスチャの大きさを記録する。テクスチャの失敗は段階付きで届く', () async {
      final r = _Recorder();
      final angle = _FakeAngle();
      await _three(r, angle).initPlatformState();
      expect(angle.calls, ['init useAngle=false', 'createTexture']);
      expect(angle.options!.dpr, 2);
      expect(r.stages, ['angle init start', 'angle init done', 'texture start']);
      expect(r.details[0], 'device GLES');
      expect(r.details[2], contains('200x400px'));
      expect(r.errors.single.$1, 'texture start');
      expect(r.errors.single.$2, isStateError);
      expect(r.frames, 0);
    });

    test('Android 以外は今までどおり(ANGLE の既定)で初期化する', () async {
      final r = _Recorder();
      final angle = _FakeAngle(initError: StateError('eglInitialize failed (fake)'));
      await _three(r, angle, deviceGles: false).initPlatformState();
      expect(angle.calls, ['init useAngle=true']);
      expect(r.errors.single.$1, 'angle init start');
      expect('${r.errors.single.$2}', contains('eglInitialize failed'));
    });

    test('待たれない Future の例外もゾーンで拾い、止まったままにしない', () async {
      final r = _Recorder();
      final angle = _FakeAngle(strayError: true);
      // init は終わらないが、捨てられた例外で失敗として返る。
      await _three(r, angle).initPlatformState().timeout(const Duration(seconds: 5));
      expect(r.errors.single.$1, 'angle init start');
      expect('${r.errors.single.$2}', contains('stray EGL error'));
    });

    test('止まったときは例外を作らない(見張りが最後の段階を理由にする)', () async {
      final r = _Recorder();
      final t = _three(r, _FakeAngle(hangInit: true));
      unawaited(t.initPlatformState());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(r.stages, ['angle init start']);
      expect(r.errors, isEmpty);
    });
  });
}
