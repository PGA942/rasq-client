import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';

import '../../app/providers.dart';
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

/// 「リスト」画面等に出す自分のクリップ一覧: ネイティブ + ホスト横断。
final myClipsProvider = Provider.autoDispose<List<ClipInfo>>((ref) {
  final native = ref.watch(myNativeClipsProvider).value ?? const <ClipInfo>[];
  final host = ref.watch(hostClipsProvider).value ?? const <HostClip>[];
  return [...native, for (final c in host) c.info];
});
