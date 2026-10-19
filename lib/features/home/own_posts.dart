import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';

/// 自分が投稿した (D-507)。
///
/// コンポーザー(どこから開いても: ＋ / 引用 / 共有 / プラグイン / RASQ への投稿 / 返信)が、送れたときに [OwnPosts.posted] を呼ぶ。
/// TL の画面はこれを見て、**いま見えている TL** をその場で読み直し(上に足す)、隠れている TL は次に見えたときに読み直す。
/// 前は ＋ のボタンが「フォロー中」(`home`)の TL だけを読み直していて、ほかのタブ / 総合表示 / セクションだけの並び / 表示モード
/// (ユーザー・関連)では出ず、「フォロー中」でも中心より上 (D-298) に足すだけで、見えなかった。DM は TL に出ないので知らせない。
@immutable
class OwnPost {
  const OwnPost({required this.seq, this.post, this.rasq = false});

  /// 何回目か(同じ投稿を 2 度知らせても区別する)。
  final int seq;

  /// 送った投稿(サーバーの返した形)。RASQ への投稿は RASQ の投稿から作った形。
  final Post? post;

  /// RASQ アカウントとしての投稿 (D-275)。
  final bool rasq;
}

class OwnPosts extends Notifier<OwnPost?> {
  @override
  OwnPost? build() => null;

  void posted({Post? post, bool rasq = false}) => state = OwnPost(seq: (state?.seq ?? 0) + 1, post: post, rasq: rasq);
}

final ownPostsProvider = NotifierProvider<OwnPosts, OwnPost?>(OwnPosts.new);
