import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' show MediaStreamTrack;

import 'astell_media.dart';

/// ネイティブ: 受けた音声は `<audio>` に繋がなくても鳴る。
AstellRemoteAudio? playAstellRemoteAudio(MediaStreamTrack track, {required bool muted}) => null;

/// ネイティブ: ブラウザの安全なコンテキストの考えは無い。
bool? astellBrowserSecureContext() => null;

/// ネイティブ: 自動再生の制限は無い。
void astellOnNextUserGesture(void Function() run) {}

/// ネイティブ: 前もって鳴らしておく `<audio>` は無い。
void astellPrimeAudioOnGesture() {}

/// ネイティブ: 操作を待つ音は無い。
final ValueNotifier<bool> astellAudioAwaitingGesture = ValueNotifier(false);
