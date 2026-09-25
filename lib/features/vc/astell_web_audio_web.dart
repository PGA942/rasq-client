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

class _HtmlRemoteAudio implements AstellRemoteAudio {
  _HtmlRemoteAudio(web.MediaStreamTrack track, {required bool muted}) {
    final stream = web.MediaStream()..addTrack(track);
    _el
      ..autoplay = true
      ..muted = muted
      ..setAttribute('playsinline', 'true')
      ..srcObject = stream;
    _container().append(_el);
    _play();
  }

  final web.HTMLAudioElement _el = web.HTMLAudioElement();
  bool _disposed = false;

  void _play() {
    if (_disposed || !_el.paused) return;
    _el.play().toDart.then((_) {}, onError: (Object e) {
      // 自動再生が断られた: 次にページを触ったときに鳴らす。
      debugPrint('astell media: web audio play() was blocked, waiting for a gesture: $e');
      astellOnNextUserGesture(_play);
    });
  }

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
    _el.remove();
  }
}

final List<void Function()> _onGesture = [];
JSFunction? _gestureListener;
const _gestureEvents = ['pointerdown', 'keydown', 'touchend'];

/// 次にページが操作されたとき(タップ / クリック / キー)に [run] を呼ぶ。自動再生の制限で `play()` / `AudioContext` が
/// 断られたものは、ユーザーの操作の中でやり直すと通る。
void astellOnNextUserGesture(void Function() run) {
  _onGesture.add(run);
  if (_gestureListener != null) return;
  final listener = ((web.Event _) {
    final runs = [..._onGesture];
    _onGesture.clear();
    for (final t in _gestureEvents) {
      web.window.removeEventListener(t, _gestureListener, true.toJS);
    }
    _gestureListener = null;
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
