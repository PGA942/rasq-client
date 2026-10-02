import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';

import '../../app/providers.dart';
import '../home/post_duplicates.dart';

/// 投稿を**別のアカウントで**引き直す (D-411、投稿の詳細の浮かべたアカウントのタイル)。見つからなければ null。
///
/// 1. TL で同じ投稿が複数のアカウントに流れてきていれば、そのコピー(D-110 の ↓ と同じ控え)。
/// 2. 同じ SNS・同じサーバーのアカウントなら、同じ id で読む。
/// 3. それ以外は、そのアカウントのサーバーで投稿の URL を検索し(Mastodon は URL で連合先の投稿を引ける)、URL が同じ /
///    中身が同じ(D-110 の同定)ものを使う。
/// SNS に「URL から引く」API が無いぶん、見つからないことがある(呼び出し側はメッセージを出してそのままにする)。
Future<Post?> resolvePostOn(Ref ref, Post post, AccountId target) async {
  if (post.account == target) return post;
  for (final alt in ref.read(postAlternatesProvider)[post.key] ?? const <Post>[]) {
    if (alt.account == target) return alt;
  }
  final state = ref.read(sessionsProvider).value;
  final s = state?.allSessions.where((x) => x.account == target).firstOrNull;
  if (s == null) return null;
  final session = ref.read(pluginRegistryProvider).session(s);
  try {
    if (post.account.kind == target.kind && post.account.instance == target.instance) return await session.post(post.id);
  } catch (e) {
    debugPrint('resolvePostOn(id ${post.id} on $target): $e');
  }
  final url = post.url;
  if (url == null) return null;
  try {
    final page = await session.searchPosts('$url', limit: 10);
    final key = postDupKey(post);
    return page.items.where((p) => p.url == url).firstOrNull ?? page.items.where((p) => postDupKey(p) == key).firstOrNull;
  } catch (e) {
    debugPrint('resolvePostOn(search $url on $target): $e');
    return null;
  }
}

/// [resolvePostOn] を画面から呼ぶ口(`WidgetRef` から)。
final postResolverProvider = Provider<Future<Post?> Function(Post post, AccountId target)>((ref) => (post, target) => resolvePostOn(ref, post, target));
