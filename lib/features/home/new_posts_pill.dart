import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';

import '../../l10n/l10n.dart';

/// TL を更新して新しい投稿が届いたときの「{顔}{顔} 新しい投稿」(D-506)。
///
/// TL の上(ヘッダーのすぐ下)に浮かべ、押すといちばん上へ送って新しい投稿を見せる。[NewPostsPillController.duration] たつか、
/// いちばん上まで送ると消える。ヘッダーをしまっている間は出さない(しまったヘッダーには D-449 の新着 = Swing / ASTell を浮かべる)。
/// 出す / 出さないは設定「タイムラインの表示」の `newPostsPill`([timelineNewPostsPillProvider]、既定は出す)。
class NewPostsPillController extends ChangeNotifier {
  /// 出しておく時間(テストで短く)。
  static Duration duration = const Duration(seconds: 10);

  /// 顔を出す人の数。
  static const maxFaces = 3;

  List<UserSummary> _authors = const [];
  Timer? _timer;

  /// いま出している人(新しい順、同じ人は 1 回)。空なら出していない。
  List<UserSummary> get authors => _authors;
  bool get showing => _authors.isNotEmpty;

  /// [fresh](新しく届いた投稿、新しい順)を足して出す。出ていれば顔を前に足し、時間を数え直す。
  void show(List<Post> fresh) {
    if (fresh.isEmpty) return;
    final seen = <String>{};
    final next = <UserSummary>[];
    for (final u in [for (final p in fresh) p.repostedBy ?? p.author, ..._authors]) {
      if (seen.add(u.key)) next.add(u);
    }
    _authors = next.take(maxFaces).toList();
    _timer?.cancel();
    _timer = Timer(duration, hide);
    notifyListeners();
  }

  void hide() {
    _timer?.cancel();
    _timer = null;
    if (_authors.isEmpty) return;
    _authors = const [];
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// 「{顔}{顔} 新しい投稿」の丸い札。
class NewPostsPill extends StatelessWidget {
  const NewPostsPill({super.key, required this.authors, required this.onTap});
  final List<UserSummary> authors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const face = 22.0;
    const step = 14.0;
    return Semantics(
      button: true,
      label: context.l10n.homeNewPostsPillSemantics,
      child: Material(
        color: scheme.primary,
        elevation: 3,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 14, 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.arrow_upward, size: 16, color: scheme.onPrimary),
              const SizedBox(width: 4),
              // 顔は少しずつ重ねる(左がいちばん新しい人)。
              SizedBox(
                width: face + step * (authors.length - 1),
                height: face,
                child: Stack(children: [
                  for (var i = authors.length - 1; i >= 0; i--)
                    Positioned(
                      left: step * i,
                      child: Container(
                        key: ValueKey('tl.newPosts.face.${authors[i].key}'),
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: scheme.primary, width: 1.5)),
                        child: RasqAvatar(imageUrl: authors[i].avatarUrl, size: face - 3, fallbackLabel: authors[i].displayName),
                      ),
                    ),
                ]),
              ),
              const SizedBox(width: 6),
              Text(context.l10n.homeNewPostsPill, style: RasqTypography.caption.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ),
    );
  }
}
