import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../backend/rasq_account.dart';
import '../../../backend/rasq_account_page_api.dart';
import 'header_hint_codec.dart' show headerHintCanEmbed;

/// SNS アカウント [accountKey](`kind:instance:handle`)のヘッダーに書く RASQ のハンドル (D-591)。
///
/// いまの RASQ アカウントの「アカウントを表示」(`showLinksOnSnsProfiles`)がオンで、その SNS アカウントをつないで
/// 公開ページに出している(by-sns が返すのと同じ範囲)ときだけ。ほかは null(書かない)。読めない / Central が無いときも null。
final headerHintTargetProvider = FutureProvider.autoDispose.family<String?, String>((ref, accountKey) async {
  final a = ref.watch(orgateAccountProvider).value;
  if (a == null || !a.showLinksOnSnsProfiles || !headerHintCanEmbed(a.handle)) return null;
  try {
    final links = await ref.watch(currentBundleLinksProvider.future);
    final k = accountKey.toLowerCase();
    return links.any((l) => l.accountKey.toLowerCase() == k && l.visible) ? a.handle : null;
  } catch (_) {
    return null;
  }
});
