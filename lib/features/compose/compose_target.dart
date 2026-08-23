import 'package:rasq_models/rasq_models.dart';

/// What the composer is for. One composer, three entry points
/// (＋ボタン / 詳細画面の返信バー / DMルーム下部).
sealed class ComposeTarget {
  const ComposeTarget();
  String get title;
}

class ComposeNormal extends ComposeTarget {
  const ComposeNormal();
  @override
  String get title => 'ノートの作成';
}

class ComposeReply extends ComposeTarget {
  const ComposeReply(this.to);
  final Post to;
  @override
  String get title => '返信';
}

class ComposeQuote extends ComposeTarget {
  const ComposeQuote(this.of);
  final Post of;
  @override
  String get title => '引用';
}

class ComposeDm extends ComposeTarget {
  const ComposeDm(this.room);
  final DmRoom room;
  @override
  String get title => room.displayTitle;
}
