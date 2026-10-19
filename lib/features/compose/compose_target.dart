import 'package:rasq_models/rasq_models.dart';

import '../../l10n/l10n.dart';

/// What the composer is for. One composer, three entry points
/// (＋ボタン / 詳細画面の返信バー / DMルーム下部).
sealed class ComposeTarget {
  const ComposeTarget();
  String get title;
}

class ComposeNormal extends ComposeTarget {
  const ComposeNormal();
  @override
  String get title => appL10n.composeTargetNormalTitle;
}

class ComposeReply extends ComposeTarget {
  const ComposeReply(this.to);
  final Post to;
  @override
  String get title => appL10n.composeTargetReplyTitle;
}

class ComposeQuote extends ComposeTarget {
  const ComposeQuote(this.of);
  final Post of;
  @override
  String get title => appL10n.composeTargetQuoteTitle;
}

class ComposeDm extends ComposeTarget {
  const ComposeDm(this.room);
  final DmRoom room;
  @override
  String get title => room.displayTitle;
}
