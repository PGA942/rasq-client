import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';

/// 複数アカウントに同じ投稿が流れてきたときの同定 (D-110)。
///
/// 投稿タイルの RRL タグ相当の中身比較: **著者(id+ドメイン)+ 本文ハッシュ +
/// 添付数 + 投票有無 + リノート主**。一致したコピーは表示から隠し、
/// タイルの ↓(アカウント選択)で切り替えられる。画像の imagehash(pHash)
/// での使い分けは端末実装が入ってからの拡張(現状はテキスト hash + 添付数)。
String postDupKey(Post p) {
  final body = p.body.replaceAll(RegExp(r'\s+'), ' ').trim();
  return '${p.author.account.key}|${p.repostedBy?.account.key ?? ''}|${body.hashCode}|${p.media.length}|${p.poll != null}';
}

/// 隠した重複コピー(残したコピーの post.key → 他アカウントのコピー)。
/// アクションバー右横の ↓ がここから選択肢を出す (D-110)。
class PostAlternates extends Notifier<Map<String, List<Post>>> {
  @override
  Map<String, List<Post>> build() => const {};

  void recordAll(Map<String, List<Post>> pairs) {
    if (pairs.isEmpty) return;
    final next = {...state};
    pairs.forEach((keptKey, dropped) {
      final list = [...(next[keptKey] ?? const <Post>[])];
      for (final d in dropped) {
        if (d.key != keptKey && !list.any((x) => x.account == d.account)) list.add(d);
      }
      next[keptKey] = list;
    });
    state = next;
  }
}

final postAlternatesProvider = NotifierProvider<PostAlternates, Map<String, List<Post>>>(PostAlternates.new);
