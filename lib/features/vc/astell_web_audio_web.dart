import 'dart:js_interop';

import 'package:dart_webrtc/dart_webrtc.dart' show MediaStreamTrackWeb;
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' show MediaStreamTrack;
import 'package:web/web.dart' as web;

import 'astell_media.dart';

/// Web 版の通話の声 (D-318)。
///
/// ブラウザは、受けた WebRTC の音声を**メディア要素に繋がないと鳴らさない**。前は flutter_webrtc の `RTCVideoRenderer` に
/// `ontrack` の `streams.first` を入れていたが、こちらの接続は `addTransceiver` + `replaceTrack` で送るので、SDP の
/// `a=msid` にストリームが無く(`-`)、受けた側の `streams` は空 — 繋ぐ先が無いまま鳴らなかった(ネイティブは繋がなくても
/// 鳴るので、iPad では聞こえていた)。ここでは受けたトラックそのものから `MediaStream` を作って `<audio>` に入れる。
///
/// 自動再生の制限: `play()` が断られたら(まだページが操作されていない / Safari で別の操作の後など)、次にページを
/// 触ったときにもう一度 `play()` する。
///
/// Safari (D-323): Chrome は「このページが一度でも操作された」で自動再生を許すが、Safari(WebKit)は**要素ごと**で、
/// その `<audio>` が操作の中で `play()` されたことがあるか(か、ページがマイクを使っているか)を見る。声は offer / answer の
/// 途中(操作の外)で届くので、聞くだけの人は毎回止められていた。ルームに入ったら、次の操作のときに `<audio>` を何本か
/// 操作の中で `play()` しておき([astellPrimeAudioOnGesture])、届いた声はそれに繋ぐ(閉じた要素も使い回す)。
AstellRemoteAudio? playAstellRemoteAudio(MediaStreamTrack track, {required bool muted}) {
  if (track is! MediaStreamTrackWeb) return null;
  return _HtmlRemoteAudio(track.jsTrack, muted: muted);
}

/// `window.isSecureContext`(https / localhost なら true)。
bool? astellBrowserSecureContext() => web.window.isSecureContext;

const _containerId = 'rasq_astell_audio';

web.HTMLElement _container() {
  final have = web.document.getElementById(_containerId);
  if (have != null) return have as web.HTMLElement;
  final div = web.HTMLDivElement()
    ..id = _containerId
    ..style.display = 'none';
  web.document.body?.append(div);
  return div;
}

/// 操作の中で `play()` 済みの `<audio>`(Safari はこの要素なら以後の再生を許す)。
final List<web.HTMLAudioElement> _primed = [];
const _primedTarget = 8;
bool _primeWanted = false;

web.HTMLAudioElement _newAudio() {
  final el = web.HTMLAudioElement()
    ..autoplay = true
    ..setAttribute('playsinline', 'true');
  _container().append(el);
  return el;
}

/// 次の操作のときに、声を鳴らす `<audio>` を操作の中で `play()` しておく (D-323)。ルームに入ったとき / 使って減ったときに呼ぶ。
void astellPrimeAudioOnGesture() {
  if (_primed.length >= _primedTarget) return;
  _primeWanted = true;
  _listen();
}

void _prime() {
  while (_primed.length < _primedTarget) {
    final el = _newAudio();
    // 中身が無いので鳴らない。操作の中で呼んだことだけが残る(断られても構わない)。
    el.play().toDart.then((_) {}, onError: (Object _) {});
    el.pause();
    _primed.add(el);
  }
}

web.HTMLAudioElement _takeAudio() {
  if (_primed.isEmpty) {
    astellPrimeAudioOnGesture();
    return _newAudio();
  }
  final el = _primed.removeAt(0);
  if (_primed.length < _primedTarget ~/ 2) astellPrimeAudioOnGesture();
  return el;
}

class _HtmlRemoteAudio implements AstellRemoteAudio {
  _HtmlRemoteAudio(web.MediaStreamTrack track, {required bool muted}) : _el = _takeAudio() {
    final stream = web.MediaStream()..addTrack(track);
    _el
      ..muted = muted
      ..srcObject = stream;
    _play();
  }

  final web.HTMLAudioElement _el;
  bool _disposed = false;
  bool _blocked = false;

  void _play() {
    if (_disposed || !_el.paused) return;
    _el.play().toDart.then((_) {
      if (_blocked) debugPrint('astell media: web audio is playing now');
      _blocked = false;
    }, onError: (Object e) {
      // 自動再生が断られた: 次にページを触ったときに鳴らす。
      debugPrint('astell media: web audio play() was blocked, waiting for a gesture: $e');
      _blocked = true;
      astellOnNextUserGesture(_play);
    });
  }

  @override
  String get state => _disposed
      ? 'closed'
      : _blocked
          ? 'blocked'
          : _el.muted
              ? 'muted'
              : _el.paused
                  ? 'paused'
                  : 'playing';

  @override
  void setMuted(bool muted) {
    _el.muted = muted;
    if (!muted) _play();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _el.pause();
    _el.srcObject = null;
    // 操作の中で鳴らしたことのある要素は、次の声のために取っておく。
    if (_primed.length < _primedTarget) {
      _el.muted = false;
      _primed.add(_el);
    } else {
      _el.remove();
    }
  }
}

final List<void Function()> _onGesture = [];
JSFunction? _gestureListener;

/// 操作とみなされるイベント。ブラウザによって「ユーザーの操作」に数える種類が違う(Safari はマウスの `pointerdown`
/// を数えないことがある)ので広めに取る。1 回目で通らなければ、`play()` が断られたところでまた待つ(同じクリックの
/// `mouseup` / `click` でやり直せる)(D-323)。
const _gestureEvents = ['pointerdown', 'pointerup', 'mousedown', 'mouseup', 'click', 'keydown', 'touchend'];

/// 自動再生の制限で止められ、次の操作を待っている音があるか (D-323)。ルームの画面が「タップすると鳴ります」を出す。
final ValueNotifier<bool> astellAudioAwaitingGesture = ValueNotifier(false);

/// 次にページが操作されたとき(タップ / クリック / キー)に [run] を呼ぶ。自動再生の制限で `play()` / `AudioContext` が
/// 断られたものは、ユーザーの操作の中でやり直すと通る。
void astellOnNextUserGesture(void Function() run) {
  _onGesture.add(run);
  astellAudioAwaitingGesture.value = true;
  _listen();
}

void _listen() {
  if (_gestureListener != null) return;
  final listener = ((web.Event _) {
    final runs = [..._onGesture];
    _onGesture.clear();
    for (final t in _gestureEvents) {
      web.window.removeEventListener(t, _gestureListener, true.toJS);
    }
    _gestureListener = null;
    astellAudioAwaitingGesture.value = false;
    if (_primeWanted) {
      _primeWanted = false;
      _prime();
    }
    for (final r in runs) {
      try {
        r();
      } catch (e) {
        debugPrint('astell media: gesture: $e');
      }
    }
  }).toJS;
  _gestureListener = listener;
  for (final t in _gestureEvents) {
    web.window.addEventListener(t, listener, true.toJS);
  }
}
