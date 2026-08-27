import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';

import '../../app/providers.dart';
import '../settings/settings_dsl.dart';
import 'host_clips.dart';

/// 自分のネイティブクリップ(SNS 非対応なら空 — タブ/メニューは自動非表示)。
final myNativeClipsProvider = FutureProvider.autoDispose<List<ClipInfo>>((ref) async {
  final s = ref.watch(currentSnsSessionProvider);
  if (s == null) return const [];
  try {
    return await s.clips();
  } on UnsupportedError {
    return const [];
  }
});

/// 指定ユーザーの公開クリップ(ユーザーページのクリップタブ)。
final userClipsProvider = FutureProvider.autoDispose.family<List<ClipInfo>?, String>((ref, userId) async {
  final s = ref.watch(currentSnsSessionProvider);
  if (s == null) return const [];
  try {
    return await s.clips(userId: userId);
  } on UnsupportedError {
    return null; // 非対応 → タブごと隠す判断に使う
  }
});

/// リスト欄の表示設定 KV(D-035 規約: `lists.view.v1`)。
const listsViewArea = 'lists.view';

/// リスト欄に出すクリップ: **公開ネイティブクリップのみが既定**。
/// 非公開はブックマーク欄が置き場(検索ボックスのフィルタで表示に切替可)。
/// ホスト横断クリップは SNS 側に記録されないためリスト欄には出さない。
final listsClipsProvider = Provider.autoDispose<List<ClipInfo>>((ref) {
  final showPrivate = ref.watch(settingsAreaProvider(listsViewArea)).value?['showPrivateClips'] == true;
  final native = ref.watch(myNativeClipsProvider).value ?? const <ClipInfo>[];
  return [for (final c in native) if (c.isPublic || showPrivate) c];
});

/// ブックマーク欄に出すクリップ: RASQ 横断クリップ + 非公開ネイティブ
/// クリップ(どちらも「自分のための保存」なのでブックマークと同じ置き場)。
final bookmarkClipsProvider = Provider.autoDispose<List<ClipInfo>>((ref) {
  final native = ref.watch(myNativeClipsProvider).value ?? const <ClipInfo>[];
  final host = ref.watch(hostClipsProvider).value ?? const <HostClip>[];
  return [for (final c in host) c.info, for (final c in native) if (!c.isPublic) c];
});
