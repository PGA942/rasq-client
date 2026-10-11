import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:rasq_models/rasq_models.dart';

import '../../session/sanctions.dart';
import '../trend/example_match.dart';
import '../trend/tendency_profile.dart';
import 'child_safe_api.dart' show ChildSafeGuardianStatus;
import 'child_safe_policy.dart';

/// 子の端末のチャイルドセーフの状態 (D-307)。`childSafeProvider` が持ち、[ChildGate] が読む。
@immutable
class ChildSafeState {
  const ChildSafeState({
    this.managed = false,
    this.state = 'none',
    this.policy,
    this.revision = 0,
    this.parentHandle,
    this.parentDisplayName,
    this.accountId,
    this.guardian = ChildSafeGuardianStatus.none,
    this.offline = false,
    this.error,
  });

  /// 見守られている(一度でも `managed` だった端末は、オンラインで「終わった」と確かめるまで true のまま)。
  final bool managed;

  /// `pending_setup` / `active` / `unverified`(署名を確かめられない)/ `none`。
  final String state;

  /// 最後に署名を確かめた制限。null = まだ無い。
  final ChildSafePolicy? policy;
  final int revision;
  final String? parentHandle;
  final String? parentDisplayName;

  /// 制限が結びついている子のアカウント id(署名の `childAccountId`)。
  final String? accountId;

  /// 自分が保護者として確認済みか(だれでも返る)。
  final ChildSafeGuardianStatus guardian;

  /// 直近の取り直しが届かなかった(前の制限のまま)。
  final bool offline;

  /// 署名が合わない、など(前の制限のまま)。
  final String? error;

  /// 使わせない(保護者が決めるまで / 署名を確かめた制限が無い)。
  bool get locked => managed && (state == 'pending_setup' || policy == null);

  ChildSafeState copyWith({ChildSafeGuardianStatus? guardian, bool? offline, String? error, bool clearError = false}) => ChildSafeState(
        managed: managed,
        state: state,
        policy: policy,
        revision: revision,
        parentHandle: parentHandle,
        parentDisplayName: parentDisplayName,
        accountId: accountId,
        guardian: guardian ?? this.guardian,
        offline: offline ?? this.offline,
        error: clearError ? null : (error ?? this.error),
      );
}

/// 止めたときの決まり文句(RAi の関数など)。
const childSafeBlockedText = '保護者が止めています';

/// コンポーザーの判定の結果: 止めた理由と、印を付ける範囲。
/// [type] = 本文の判定で止めた種類(`stimulus` = 強い言葉 / `topic` = 決められた話題。Central S-102 の種類)。機能 / 1 日の数 /
/// 設定待ちで止めたときは null。種類があるときだけ、種類を Central へ知らせる(本文は送らない、D-462)。
@immutable
class ChildComposeVerdict {
  const ChildComposeVerdict(this.message, {this.start, this.end, this.type});
  final String message;
  final int? start;
  final int? end;
  final String? type;
  bool get hasRange => start != null && end != null && end! > start!;
}

/// 関所 (D-307): 見守りの制限を、面ごとに問い合わせる口。見守られていなければ、どれも素通し。
/// 時刻は作ったとき([now])で固定(`childSafeClockProvider` が切り替わりの時刻に作り直す)。
@immutable
class ChildGate {
  ChildGate({this.state = const ChildSafeState(), DateTime? now}) : now = now ?? DateTime.now();
  final ChildSafeState state;
  final DateTime now;

  static final off = ChildGate();

  bool get supervised => state.managed;
  bool get locked => state.locked;
  ChildSafePolicy? get policy => supervised ? state.policy : null;
  ChildSafeAllow? get allow => policy?.allow;

  /// 見守りの時間の中か。
  bool get inTimeWindow => policy?.time.contains(now) ?? false;
  String get windowLabel => policy == null ? '' : '${policy!.time.start}〜${policy!.time.end}';

  // ── 機能 / 検索 ──

  /// `allow` が無ければ許す。書いていない id は `preset` のプリセットの値(Central と同じ規則)。
  bool featureAllowed(String id) => !supervised || (!locked && (allow == null || (allow!.features?[id] ?? childSafePresetDefault(policy!.preset, 'features', id))));
  bool searchAllowed(String id) => !supervised || (!locked && (allow == null || (allow!.search?[id] ?? childSafePresetDefault(policy!.preset, 'search', id))));

  /// 機能が止まっているときの案内。アカウントの処置 ([RasqSanctions]) が先。止まっていなければ null。
  String? blockedMessage(String feature, [RasqSanctions sanctions = RasqSanctions.none]) {
    final s = sanctions.blockedMessage(feature);
    if (s != null) return s;
    if (!supervised) return null;
    if (locked) return '保護者が設定を決めるまで使えません';
    final label = RasqSanctions.featureLabels[feature] ?? feature;
    if (!featureAllowed(feature)) return '$childSafeBlockedText($label)';
    if (feature == 'dm' && inTimeWindow && policy!.time.hideDirectMessages) return '見守りの時間($windowLabel)は DM を使えません';
    return null;
  }

  /// DM / チャットの TL(`dm:` / `chat:`。`acct:<アカウント>|` で包まれていても)。
  static bool isDirectTimelineKind(String kindId) {
    var k = kindId.trim();
    while (k.startsWith('acct:') && k.contains('|')) {
      k = k.substring(k.indexOf('|') + 1).trim();
    }
    return k.startsWith('dm:') || k.startsWith('chat:');
  }

  /// この TL(kind id)を取りに行けない理由(セキュリティ確認 2026-10-09 の [21])。取れるなら null。
  /// DM / チャットの TL は、画面 (/dm) と同じく DM を止めていれば(見守りの時間の「DM を隠す」も)取らない。
  /// 取得ノード (tl.dm) / RAi の timeline.list / TL の画面の、どの口からでも同じ。
  String? timelineKindBlockReason(String kindId) => isDirectTimelineKind(kindId) ? blockedMessage('dm') : null;

  /// 画面(ルート)を開けない理由。開けるなら null。
  String? routeBlockReason(String loc) {
    if (!supervised) return null;
    bool under(String p) => loc == p || loc.startsWith('$p/');
    // リンクから開く AsTell ルーム (`/astell/<ref>`、D-456) も AsTell。
    if (under('/vc') || under('/astell')) {
      if (!featureAllowed('astell.join')) return '保護者が ASTell を止めています';
      if (inTimeWindow) return '見守りの時間($windowLabel)は ASTell を使えません';
    }
    if (under('/dm')) {
      if (!featureAllowed('dm')) return '保護者が DM を止めています';
      if (inTimeWindow && policy!.time.hideDirectMessages) return '見守りの時間($windowLabel)は DM を使えません';
    }
    if (under('/notifications') && inTimeWindow && policy!.time.hideNotifications) return '見守りの時間($windowLabel)は通知を見られません';
    // SNS 探しの「RAi に聞く」(セキュリティ確認 2026-10-09 の [13]) も RAi。
    if ((under('/rai') || under('/sns-discover/ask')) && !raiEnabled) return '保護者が RAi を止めています';
    if (under('/store') && !under('/store/installed') && !searchAllowed('store')) return '保護者がプラグインストアを止めています';
    if ((under('/search') || under('/trend')) && !const ['posts', 'users', 'trend'].any(searchAllowed)) return '保護者が検索を止めています';
    if (loc.startsWith('/login/') && !canAddAccounts) return '保護者が SNS アカウントの追加を止めています';
    // カスタムプラグインのページ (D-357 / D-451): ページ型をどれも使えないときは画面ごと。1 つずつの可否は中身(マニフェスト)が
    // 分かってから開く側([pluginPageBlockReason])が決める(ルートの id はストアの id で、例 (D-314) の近さも中身が要る)。
    if (under('/custom/page') && !_anyPagePluginAllowed) return '保護者がカスタムプラグインを止めています';
    // WASM 試験画面 (dev、セキュリティ確認 2026-10-09 の [12]): どのプラグインも動かせないときは画面ごと。
    // 1 つずつの可否は読み込む側([devPreviewBlockReason])が決める。
    if (under('/dev/wasm') && !_anyPluginAllowed) return '保護者がプラグインを止めています';
    return null;
  }

  /// プラグインを 1 つでも動かせるか(`none`・`listed` で名指しが無い、なら動かせない)。
  bool get _anyPluginAllowed {
    final pl = allow?.plugins;
    if (locked) return false;
    if (pl == null) return true;
    return pl.ids.isNotEmpty || pl.install == ChildSafeInstall.any || pl.install == ChildSafeInstall.examples;
  }

  /// ページ型のプラグインを 1 つでも使えるか(ページのスロットを切っている / `none`・`listed` で名指しが無い、なら使えない)。
  bool get _anyPagePluginAllowed {
    final pl = allow?.plugins;
    if (locked) return false;
    if (pl == null) return true;
    if (pl.slots[pagePluginSlot] == false) return false;
    return pl.ids.isNotEmpty || pl.install == ChildSafeInstall.any || pl.install == ChildSafeInstall.examples;
  }

  // ── タイムライン / 投稿 ──

  /// 刺激性の見方: 怒り / 嫌悪は少しでも、恐れ / 悲しみは強めのときだけ数える([TendencyScorer.stimulusPenaltyOf])。
  static const stimulusProfile = TendencyProfile(stimulus: {'anger': 0, 'disgust': 0, 'fear': 0.25, 'sadness': 0.5});

  static double stimulusOfText(String text) => tendencyScorer.stimulusPenaltyOf(_textPost(text), stimulusProfile);
  static double stimulusOf(Post p) => tendencyScorer.stimulusPenaltyOf(p.contentWarning == null ? p : _textPost('${p.contentWarning} ${p.body} ${p.quote?.body ?? ''}'), stimulusProfile);

  static Post _textPost(String text) => Post(
        id: '-',
        account: const AccountId(kind: SnsKind.other, instance: 'rasq', handle: '-'),
        author: const UserSummary(id: '-', account: AccountId(kind: SnsKind.other, instance: 'rasq', handle: '-'), displayName: '-'),
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        body: text,
      );

  /// 話題(語やタグ)のどれかに当たるか。当て方はトレンドの「好きではないジャンル」と同じ(特徴語か本文に含まれる)。
  static bool matchesTopic(Post p, List<String> topics) => topics.isNotEmpty && tendencyScorer.isDisliked(p, TendencyProfile(disliked: topics));

  /// 話題の一覧を通るか (D-315): ホワイトリスト = どれかに当たる(空なら何も通らない。もとの形の時間の「空 = 何も流さない」)、
  /// ブラックリスト = どれにも当たらない(空なら全部通る)。
  static bool passesTopics(Post p, ChildSafeTopics t) => t.allow ? matchesTopic(p, t.topics) : !matchesTopic(p, t.topics);

  /// この投稿を見せないか(判定の強さ / タイムラインの話題 / 見守りの時間の話題)。
  bool postHidden(Post p) {
    final pol = policy;
    if (pol == null) return false;
    if (pol.timeline.enabled) {
      if (stimulusOf(p) >= pol.timeline.level.stimulusThreshold) return true;
      if (!passesTopics(p, pol.timeline.topics)) return true;
    }
    if (inTimeWindow && !passesTopics(p, pol.time.topics)) return true;
    return false;
  }

  List<Post> filterPosts(List<Post> posts) => policy == null ? posts : [for (final p in posts) if (!postHidden(p)) p];

  /// 本文だけ分かるもの(RASQ の通知の抜粋など)を見せないか。判定は [postHidden] と同じ (D-454)。
  bool textHidden(String text) => policy != null && text.trim().isNotEmpty && postHidden(_textPost(text));

  /// 通知の投稿を、[postHidden] なら外す(通知そのもの = 誰が何をしたかは残す。投稿を含みうるプラグインの `raw` も外す)
  /// (D-454、セキュリティ確認 2026-10-09 の [9])。
  List<NotificationItem> filterNotifications(List<NotificationItem> items) => policy == null
      ? items
      : [
          for (final n in items)
            n.post == null || !postHidden(n.post!)
                ? n
                : NotificationItem(id: n.id, account: n.account, kind: n.kind, createdAt: n.createdAt, actors: n.actors, reaction: n.reaction, read: n.read, reactionsByActor: n.reactionsByActor, title: n.title, body: n.body),
        ];

  /// 投稿の詳細を開けない理由。開けるなら null。
  String? postDetailBlockReason(Post? p) {
    if (!supervised) return null;
    if (inTimeWindow && policy!.time.hidePostDetail) return '見守りの時間($windowLabel)は投稿の詳細を開けません';
    if (p != null && postHidden(p)) return 'この投稿は表示できません';
    return null;
  }

  /// タイムラインが変わる設定の目印(TL を作り直す判断に使う)。
  String get timelineSignature {
    final pol = policy;
    if (pol == null) return supervised ? 'locked' : '-';
    return '${pol.timeline.enabled}|${pol.timeline.level.wire}|${pol.timeline.topics.signature}|$inTimeWindow|${pol.time.topics.signature}';
  }

  // ── コンポーザー ──

  /// 本文の判定: 強さの閾値以上なら送らない、次に投稿の話題 (D-315。ホワイトリスト = どれかの話題に当たる投稿だけ、
  /// ブラックリスト = 当たる投稿は送らない)。当たった語に印を付ける範囲を返す。通れば null。
  /// 話題は**投稿だけ**に当てる([dm] = DM の本文は強さだけ。話題の一覧は保護者の「投稿」のページのもの)。
  ChildComposeVerdict? judgeText(String text, {bool dm = false}) {
    final pol = policy;
    if (pol == null || !pol.composer.enabled || text.trim().isEmpty) return null;
    return _judgeStimulus(pol, text) ?? (dm ? null : _judgeTopics(pol.composer.topics, text));
  }

  ChildComposeVerdict? _judgeTopics(ChildSafeTopics t, String text) {
    final post = _textPost(text);
    if (t.allow) {
      if (matchesTopic(post, t.topics)) return null;
      final shown = t.topics.take(5).join('・');
      return ChildComposeVerdict(t.topics.isEmpty ? '保護者の設定により、いまは投稿を送れません' : '保護者の設定により、決められた話題($shown${t.topics.length > 5 ? ' など' : ''})の投稿だけ送れます。話題に合うように書いてください', type: 'topic');
    }
    if (!matchesTopic(post, t.topics)) return null;
    // 当たった話題のうち、本文にそのまま出てくる最初のものに印を付ける(特徴語だけで当たったときは印なし)。
    final lower = text.toLowerCase();
    ({String topic, int start, int end})? hit;
    for (final topic in t.topics) {
      final key = topic.replaceFirst(RegExp(r'^#'), '').toLowerCase();
      final i = key.isEmpty || lower.length != text.length ? -1 : lower.indexOf(key);
      if (i >= 0 && (hit == null || i < hit.start)) hit = (topic: topic, start: i, end: i + key.length);
    }
    final label = hit?.topic ?? t.topics.firstWhere((x) => matchesTopic(post, [x]), orElse: () => t.topics.first);
    return ChildComposeVerdict('保護者の設定により、「$label」の話題の投稿は送れません。書き換えてください', start: hit?.start, end: hit?.end, type: 'topic');
  }

  ChildComposeVerdict? _judgeStimulus(ChildSafePolicy pol, String text) {
    if (stimulusOfText(text) < pol.composer.level.stimulusThreshold) return null;
    // 上限を超えた感情の語のうち、先頭のもの。
    final emo = emotionLexiconOf(text);
    final hit = emotionLexiconMatches(text).where((m) => (emo[m.emotion] ?? 0) > stimulusProfile.stimulusCap(m.emotion)).firstOrNull;
    final word = hit == null ? '' : '「${text.substring(hit.start, hit.end)}」';
    return ChildComposeVerdict('保護者の設定(${pol.composer.level.label})により、この表現$wordは送れません。言い換えてください', start: hit?.start, end: hit?.end, type: 'stimulus');
  }

  int? get postsPerDay => policy?.postsPerDay;

  // ── 例 (D-314) ──

  /// 保護者の例(許す例 / 止める例)。無ければ null。
  ContentExamples? get examples => supervised ? allow?.examples : null;

  /// 止める例があるか(クリップ / リストの中身を読んで確かめる価値があるか)。
  bool get hasDenyExamples => (examples?.deny.isNotEmpty ?? false) && !locked;

  /// 中身の文([pieces])と例の近さ。例が無ければ null。
  ExampleScores? _scores(List<String>? pieces) {
    final ex = examples;
    if (ex == null || ex.isEmpty || pieces == null) return null;
    return exampleScoresOf(pieces, ex);
  }

  // ── プラグイン ──

  /// [text] = マニフェストの中身(名前 / 説明 / スロット。`pluginExamplePieces`)。例との近さに使う(無ければ例では決めない)。
  bool pluginAllowed(String pluginId, String slot, {List<String>? text}) {
    if (!supervised) return true;
    if (locked) return false;
    final pl = allow?.plugins;
    final scores = _scores(text);
    // `allow.plugins` が無くても、止める例に近いものは使わない(`any` と同じ扱い)。
    if (pl == null) return !(scores?.nearDeny ?? false);
    return pl.permits(pluginId, slot, scores: scores);
  }

  /// ページ型のスロット(`SlotIds.page`。プラグインの層を読まないよう、ここに同じ値を置く)。
  static const pagePluginSlot = 'page';

  /// カスタムプラグインのページ(ページ型、D-357)を開けない理由 (D-451)。開けるなら null。
  /// 入れているもの / 共有セッション・Swing で一時的に動かすもの、どちらも同じ規則([pluginAllowed] の `page` のスロット)。
  /// [text] はマニフェストの中身(分からないうちは null: 例 (D-314) で決める `examples` では、名指しが無ければ開けない)。
  String? pluginPageBlockReason(String pluginId, {List<String>? text}) {
    if (!supervised) return null;
    if (locked) return '保護者が設定を決めるまで使えません';
    return pluginAllowed(pluginId, pagePluginSlot, text: text) ? null : '保護者がこのプラグインを止めています';
  }

  /// WASM 試験画面 (dev) で動かせない理由(セキュリティ確認 2026-10-09 の [12])。動かせるなら null。**ゲストのコードを動かす前に**聞く。
  /// [pluginId] = 配布物の目次の id(素の .wasm / 同梱のアセットは分からない = null)、[text] = 目次のマニフェストの中身。
  /// どのスロットにも入れずに動かすので、スロットは見ない([ChildSafePluginsAllow.permitsPlugin])。
  /// id の分からないものは、名指し / 例で決める設定(`none`・`listed`・`examples`、止める例がある)では動かさない。
  String? devPreviewBlockReason(String? pluginId, {List<String>? text}) {
    if (!supervised) return null;
    if (locked) return '保護者が設定を決めるまで使えません';
    final pl = allow?.plugins;
    if (pluginId == null) {
      final open = (pl == null || pl.install == ChildSafeInstall.any) && !hasDenyExamples;
      return open ? null : '保護者が選んだプラグインだけ動かせます(この読み込み方では、どのプラグインか確かめられません)';
    }
    final scores = _scores(text);
    final ok = pl == null ? !(scores?.nearDeny ?? false) : pl.permitsPlugin(pluginId, scores: scores);
    return ok ? null : '保護者がこのプラグインを止めています';
  }

  /// インストールできない理由。[text] はマニフェストの中身(ストアから構成を取ったあとに、もう 1 度確かめる)。
  /// `examples` の決めは、中身が分からないうち([text] が null)は通す(構成を取ってから決める)。
  String? installBlockReason(String pluginId, {List<String>? text}) {
    if (!supervised) return null;
    if (locked) return '保護者が設定を決めるまで使えません';
    if (!featureAllowed('store.install')) return '保護者がプラグインのインストールを止めています';
    final pl = allow?.plugins;
    final scores = _scores(text);
    const nearDeny = '保護者が止めている例に近いプラグインです';
    if (pl == null) return (scores?.nearDeny ?? false) ? nearDeny : null;
    if (pl.ids.contains(pluginId)) return pl.install == ChildSafeInstall.none ? '保護者がプラグインのインストールを止めています' : null;
    return switch (pl.install) {
      ChildSafeInstall.none => '保護者がプラグインのインストールを止めています',
      ChildSafeInstall.listed => '保護者が選んだプラグインだけ入れられます',
      ChildSafeInstall.any => (scores?.nearDeny ?? false) ? nearDeny : null,
      ChildSafeInstall.examples => text == null
          ? null
          : scores?.nearDeny ?? false
              ? nearDeny
              : (scores?.nearAllow ?? false)
                  ? null
                  : '保護者が選んだプラグインと、許す例に近いものだけ入れられます',
    };
  }

  // ── クリップ / リスト (D-314) ──

  /// クリップ / リストを出さないか: 中身(名前 + 説明 [meta]、含まれる投稿の本文 [posts])が止める例に近い
  /// ([collectionScoresOf]。近い投稿が 3 割以上か、名前 / 全体が近い)。
  bool collectionHidden(String meta, [List<String> posts = const []]) {
    if (!supervised || !hasDenyExamples) return false;
    return collectionScoresOf(meta: meta, posts: posts, examples: ContentExamples(deny: examples!.deny)).nearDeny;
  }

  /// クリップ / リストの判定が変わる目印(読み直しの判断に使う)。
  String get collectionSignature => !hasDenyExamples ? '-' : [for (final e in examples!.deny) e.key].join('|');

  // ── SNS アカウント ──

  bool sessionVisible(AccountId a) {
    if (!supervised) return true;
    final s = allow?.sns;
    return s == null || s.permits(a.kind.name, a.instance);
  }

  /// `allow.sns.addAccounts` と、機能の `sns.addAccount` のどちらも許しているとき(Central の `PUT /me/sns-accounts` と同じ)。
  bool get canAddAccounts => !supervised || (!locked && featureAllowed('sns.addAccount') && (allow?.sns?.addAccounts ?? true));

  // ── RAi ──

  bool get raiEnabled => !supervised || (!locked && (allow?.rai?.enabled ?? true));

  /// 関数を呼べない理由(「保護者が止めています」)。呼べるなら null。**まとまりの分からない関数は、見守り中は呼ばない。**
  String? raiBlockReason(String fn) => _raiGroupBlocked(fn, raiFunctionGroups[fn]) ? '$childSafeBlockedText($fn)' : null;

  /// まとまり [group] の関数 [fn] を止めているか(実行 [raiBlockReason] と案内 [raiGuideAllowed] で同じ規則)。
  bool _raiGroupBlocked(String fn, String? group) {
    if (!supervised) return false;
    if (locked || group == null) return true;
    if (group == 'rai.web' && !searchAllowed('web')) return true;
    if (fn.startsWith('dm.') && !featureAllowed('dm')) return true;
    if (group == 'rai.astell' && !featureAllowed('astell.join')) return true;
    final r = allow?.rai;
    if (r == null) return false;
    // `deny` はまとまりの id か `<まとまり>.<関数>`(Central が確かめる形)。
    return !r.enabled || r.deny.contains(group) || r.deny.contains('$group.$fn') || !r.groups.contains(group);
  }

  /// RAi の案内 (D-309): リファレンスの関数 [id](まとまり [group]、部品のある画面 [route])を、検索の結果 / 操作の手順に
  /// 出してよいか。実行と同じまとまりの規則([_raiGroupBlocked]。**まとまりの分からない関数は、見守り中は案内しない**)に、
  /// 止めている機能 / 検索([raiGuideRequirementOf])と、開けない画面([raiGuideRouteAllowed])を足す。
  bool raiGuideAllowed(String id, String? group, String? route) {
    if (!supervised) return true;
    if (_raiGroupBlocked(id, group)) return false;
    final req = raiGuideRequirementOf(id, group);
    if (req != null && !_requirementAllowed(req)) return false;
    return route == null || raiGuideRouteAllowed(route);
  }

  bool _requirementAllowed(String req) {
    final i = req.indexOf(':');
    final kind = req.substring(0, i), id = req.substring(i + 1);
    if (kind == 'search') return searchAllowed(id);
    return switch (id) {
      'sns.addAccount' => canAddAccounts,
      // インストールは機能と `allow.plugins.install`(none なら何も入れられない)の両方。
      'store.install' => featureAllowed(id) && allow?.plugins?.install != ChildSafeInstall.none,
      _ => featureAllowed(id),
    };
  }

  /// 案内が開く / 指す画面を開けるか([routeBlockReason] と同じ。SNS アカウントの追加の入口 `/login` そのものも)。
  bool raiGuideRouteAllowed(String route) {
    if (!supervised) return true;
    final path = Uri.tryParse(route)?.path ?? route;
    if (routeBlockReason(path) != null) return false;
    if (path == '/login' && !canAddAccounts) return false;
    return true;
  }

  /// 案内の絞り込みが変わる目印(RAi の索引を絞り直す判断に使う。時計だけ進んでも変わらない)。
  String get raiGuideSignature => !supervised ? '-' : '$locked|$inTimeWindow|${jsonEncode(policy?.toJson())}';

  /// 関数優先の自動化 (D-229) を使えるか(`allow.rai.automation`)。
  bool get raiAutomation => !supervised || (!locked && (allow == null || allow!.rai == null || allow!.rai!.automation));
  bool get raiWeb => raiBlockReason('web.search') == null;

  // ── 表示 ──

  /// 閲覧注意のメディアは、見守り中は必ず隠す(`sns.safety` は読むだけ)。
  bool get forceHideSensitive => supervised;
}
