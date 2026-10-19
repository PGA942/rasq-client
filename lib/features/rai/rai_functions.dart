import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:rrl_core/rrl_core.dart';

import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../backend/rasq_account.dart' show orgateAccountProvider;
import '../../backend/rasq_collections_api.dart';
import '../collections/rasq_list_picker.dart' show importRasqListToHomeWith;
import '../lists/lists_screens.dart' show listsProvider, savedFeedsProvider;
import '../trend/genre_topics.dart';
import '../trend/tendency_profile.dart';
import '../child_safe/child_gate.dart';
import '../child_safe/child_safe_providers.dart';
import '../compose/compose_target.dart';
import '../compose/composer_sheet.dart';
import '../home/timeline_providers.dart';
import '../nodeprog/tl_components.dart';
import '../nodeprog/tl_config_store.dart';
import '../settings/settings_dsl.dart';
import '../vc/astell_models.dart';
import '../vc/astell_providers.dart';
import 'rai_reference.dart';
import 'rai_reference_providers.dart';
import 'rai_web_search.dart';
import 'prompts/rai_prompts.dart';
import '../../l10n/l10n.dart';

/// RAi が呼べる関数 (D-221): LLM の返事の `[[call:<関数>|引数=値|…]]` を実行する。
///
/// 呼べる範囲(ユーザー指定)= FOW を開くもの、プラグインが自動化を許可していないもの**以外**。
/// - `posts.fetch`: ソート / 絞り込みで投稿本文を取る(KV の [raiKvBudgetFraction] ぶんで打ち切り)。
/// - `reference.get`: 操作 / 関数リファレンスの詳細。
/// - `post.create` / `post.action`: SNS プラグインの関数(自動化 = allowed のアクションだけ)。
/// - `astell.rooms` / `astell.create`: AsTell の関数。
/// 取得系(fetch)の結果は [RaiFunctionResult.fetched] で、呼び出し側が**再始動予約**(モデルを解放 → 取得した
/// 情報を注入して答え直す)に使う。
@immutable
class RaiFunctionCall {
  const RaiFunctionCall({required this.name, this.args = const {}});
  final String name;
  final Map<String, String> args;
  String arg(String k, [String fallback = '']) => args[k] ?? fallback;
  @override
  String toString() => '$name(${args.entries.map((e) => '${e.key}=${e.value}').join(', ')})';
}

final _callRe = RegExp(r'\[\[\s*call\s*:\s*([\w.\-]+)((?:\s*\|[^\]|]*)*)\s*\]\]');

List<RaiFunctionCall> raiFunctionCallsIn(String text) => [
      for (final m in _callRe.allMatches(text))
        RaiFunctionCall(
          name: m.group(1)!,
          args: {
            for (final part in (m.group(2) ?? '').split('|'))
              if (part.contains('=')) part.substring(0, part.indexOf('=')).trim(): part.substring(part.indexOf('=') + 1).trim(),
          },
        ),
    ];

String raiStripFunctionCalls(String text) => text.replaceAll(_callRe, '').replaceAll(RegExp(r'[ \t]+\n'), '\n').trim();

/// アカウント / 端末の状態を変える関数 (D-407、セキュリティ指摘 #23)。取得した投稿などを注入して答え直した返事
/// (= 他人の書いた文が混ざった返事)に出てきたら、**すぐには実行せず**ユーザーの「実行する」を待つ。
/// 下書きを入れるだけ(post.compose など。送信はユーザーが押す)と、読むだけの関数は含めない。
const raiMutatingFunctions = <String>{
  'post.action',
  'astell.create',
  'notifications.read',
  'follow.set',
  'list.edit',
  'list.create',
  'clip.edit',
  'clip.create',
  'settings.set',
  'feed.save',
  'timeline.addFeed',
  'timeline.addRasqList',
  'timeline.excludeWord',
  'timeline.filterWord',
  'tendency.seed',
};

bool raiIsMutating(String name) => raiMutatingFunctions.contains(name);

/// 取得した文(投稿の本文など)を、モデルに渡す前に**データとして**無害にする (指摘 #23): 中の
/// `[[call:…]]` / `[[…]]` の書式を崩し、モデルがそのまま写しても呼び出しにならないようにする。
String raiNeutralizeFetched(String text) => text.replaceAll('[[', '[ [').replaceAll(']]', '] ]');

/// 取得結果の候補 1 件 (D-229: 自動化の選択肢に使う。id は次の関数に渡す値、label は表示)。
@immutable
class RaiFunctionItem {
  const RaiFunctionItem({required this.id, required this.label});
  final String id;
  final String label;
  @override
  bool operator ==(Object other) => other is RaiFunctionItem && other.id == id && other.label == label;
  @override
  int get hashCode => Object.hash(id, label);
}

@immutable
class RaiFunctionResult {
  const RaiFunctionResult({required this.name, required this.text, this.fetched = false, this.ok = true, this.items = const []});
  final String name;

  /// 注入 / 注記に使う本文。
  final String text;

  /// 構造化した候補(取得系、D-229)。
  final List<RaiFunctionItem> items;

  /// 取得系(再始動予約の対象)。
  final bool fetched;
  final bool ok;
}

/// 注入に使える文字数 (D-221): コンテキストの [raiKvBudgetFraction](既定 4%)ぶん。日本語は 1 トークン ≒ 1.8 文字で見る。
const raiKvBudgetFraction = 0.04;
int raiInjectionBudgetChars(int contextTokens, {double fraction = raiKvBudgetFraction}) => (contextTokens * fraction * 1.8).round().clamp(80, 4000);

String raiTruncate(String s, int chars) => s.length <= chars ? s : '${s.substring(0, chars)}…';

/// アクションを RAi から自動で実行してよいか(プラグインの宣言に従う)。
bool raiCanAutomate(ActionDescriptor a) => a.automation == AutomationPolicy.allowed && a.fow == FowType.none;

/// 設定ページのノードに付ける「操作禁止」タグ (D-225): `p.tags` に入っていれば RAi は書かない。
/// プラグインの設定ページ(`rasq.settings-page/1`)は JSON なので、`"p": {"tags": ["操作禁止"]}` で宣言する。
const raiNoAutomationTag = '操作禁止'; // l10n-ignore

/// ホスト(既定)の設定でパスワードが要るキーの印 (D-225): `"p": {"password": true}`。
/// 現状の静的ページには無く、`web.open`(web 版へ逃がす)のタイルは defaults にキーが無いので元から書けない。
const raiPasswordProp = 'password';

/// 設定キーを RAi が書いてよいか (D-225)。ユーザー指定: 既定設定はパスワードの要らない部分、
/// プラグイン設定は操作禁止タグを付けていない部分。判定は spec の RRL ツリーで、そのキー(`k`)を
/// `settings.set` で書くタイルが 1 つ以上あり、かつどのタイルにも [raiPasswordProp] / [raiNoAutomationTag] が
/// 無いこと。理由文は拒否のときだけ。
({bool ok, String reason}) raiSettingsWritable(SettingsPageSpec spec, String key) {
  if (!spec.defaults.containsKey(key)) return (ok: false, reason: appL10n.raiFunctionsSettingMissing(spec.area, key, spec.defaults.keys.join(', ')));
  final nodes = raiSettingsNodesFor(spec.root, key);
  if (!nodes.any((n) => n.on['change'] == 'settings.set')) return (ok: false, reason: appL10n.raiFunctionsSettingNotWritable(key));
  for (final n in nodes) {
    if (n.p[raiPasswordProp] == true) return (ok: false, reason: appL10n.raiFunctionsSettingNeedsPassword(key));
    final tags = n.p['tags'];
    if (tags is List && tags.contains(raiNoAutomationTag)) return (ok: false, reason: appL10n.raiFunctionsSettingLocked(key));
  }
  return (ok: true, reason: '');
}

/// ツリーから `k == key` のノードを集める。
List<RrlNode> raiSettingsNodesFor(RrlNode root, String key) => [
      if (root.k == key) root,
      for (final c in root.c) ...raiSettingsNodesFor(c, key),
    ];

/// LLM の文字列引数を設定値の型に合わせる (D-225): 既定値が bool / num / String のどれかで判断し、
/// ラジオの選択肢(`RadioListTile` の `p.value`)やスライダーの範囲(`p.min` / `p.max`)があればそれも見る。
/// 合わなければ null(呼び出し側が理由を添えて断る)。
Object? raiCoerceSettingValue(SettingsPageSpec spec, String key, String raw) {
  final current = spec.defaults[key];
  final v = raw.trim();
  final nodes = raiSettingsNodesFor(spec.root, key);
  final choices = [for (final n in nodes) if (n.t == 'RadioListTile' && n.p.containsKey('value')) n.p['value']];
  if (choices.isNotEmpty) {
    for (final c in choices) {
      if ('$c' == v) return c;
    }
    return null;
  }
  if (current is bool) {
    return switch (v.toLowerCase()) { 'true' || 'on' || 'yes' || '1' || 'オン' || 'はい' => true, 'false' || 'off' || 'no' || '0' || 'オフ' || 'いいえ' => false, _ => null }; // l10n-ignore
  }
  if (current is num) {
    final n = num.tryParse(v.replaceAll('%', ''));
    if (n == null) return null;
    for (final node in nodes) {
      final min = node.p['min'], max = node.p['max'];
      if (min is num && n < min) return null;
      if (max is num && n > max) return null;
    }
    return current is int && n is double && n == n.roundToDouble() ? n.round() : n;
  }
  if (current is String || current == null) return v;
  return null;
}

/// 一覧の行を予算まで積む共有ヘルパー (D-223): [head] の後に「N 件中 M 件」を添え、収まらない分は落とす
/// (最初の 1 行も入らなければ切り詰めて 1 行だけ残す)。空なら「該当なし」。
String raiFoldLines(List<String> lines, int budget, {required String head}) {
  if (lines.isEmpty) return appL10n.raiFunctionsFoldEmpty(head);
  final out = <String>[];
  var used = 0;
  for (final l in lines) {
    if (used + l.length + 1 > budget) {
      if (out.isEmpty) out.add(raiTruncate(l, budget));
      break;
    }
    out.add(l);
    used += l.length + 1;
  }
  return '${appL10n.raiFunctionsFoldHead(head, lines.length, out.length)}\n${out.join('\n')}';
}

/// 非対応の日本語化ガード (D-223): Dart 実装の非対応は [UnsupportedError]、wasm 側は
/// [SnsApiException] の C01(プラグイン間受け渡し・未実装)で来る。どちらも同じ短い文にする。
/// ログインしていない (`StateError`) もここで拾う。ほかの例外は [RaiFunctionRunner.run] の外側の
/// catch へ委ねる。
Future<RaiFunctionResult> raiGuard(String name, Future<RaiFunctionResult> Function() body) async {
  try {
    return await body();
  } on UnsupportedError {
    return RaiFunctionResult(name: name, text: appL10n.raiFunctionsUnsupported(name), ok: false);
  } on SnsApiException catch (e) {
    if (e.code.code != 'C01') rethrow;
    return RaiFunctionResult(name: name, text: appL10n.raiFunctionsUnsupported(name), ok: false);
  } on StateError catch (e) {
    return RaiFunctionResult(name: name, text: e.message, ok: false);
  }
}

/// 関数の一覧(system に出す 1 行ずつ)。呼べる範囲は関連する関数をまとめて 1 行にし、system の
/// 肥大化(D-220 の 2500 文字上限)を抑える。文は表示の言語の表から (D-492: `prompts/rai_prompts_<言語>.dart`)。
List<String> get raiFunctionUsage => raiPrompts.functionUsage;

/// 見守り中 (D-307) に system へ出す関数の一覧: 行の関数が**全部**呼べる行だけ。
List<String> raiFunctionUsageFor(ChildGate gate) {
  if (!gate.supervised) return raiFunctionUsage;
  final name = RegExp(r'(?:^|・)([a-z][\w.]*)\('); // l10n-ignore
  return [
    for (final u in raiFunctionUsage)
      if (name.allMatches(u.split(': ').first).every((m) => gate.raiBlockReason(m.group(1)!) == null)) u,
  ];
}

/// web 検索の行 (D-228): 使えるとき([RaiWebSearch.available])だけ system の一覧に足す。
String get raiWebSearchUsage => raiPrompts.webSearchUsage;

/// 自動化不可の関数 (D-237): 送信 / 返信 / DM の送信はユーザーが押す。呼ばれたらエラーにして、代替
/// (コンポーザーのオートフィル)を代わりに実行して知らせる。
const raiNonAutomatable = <String, String>{
  'post.create': 'post.compose',
  'post.send': 'post.compose',
  'dm.send': 'dm.compose',
  'post.reply.send': 'post.reply',
};

class RaiFunctionRunner {
  RaiFunctionRunner(this.ref, {this.contextTokens = 2048});
  final Ref ref;
  final int contextTokens;

  int get budget => raiInjectionBudgetChars(contextTokens);

  Future<RaiFunctionResult> run(RaiFunctionCall c) async {
    // チャイルドセーフ (D-307): 保護者が許したまとまりの関数だけ。まとまりの分からない関数は、見守り中は呼ばない。
    final blocked = ref.read(childGateProvider).raiBlockReason(c.name);
    if (blocked != null) return RaiFunctionResult(name: c.name, text: blocked, ok: false);
    final alt = raiNonAutomatable[c.name];
    if (alt != null) {
      final r = await run(RaiFunctionCall(name: alt, args: c.args));
      return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsNotAutomatable(c.name, alt, r.text), ok: false);
    }
    try {
      switch (c.name) {
        case 'posts.fetch':
          return await _postsFetch(c);
        case 'reference.get':
          return await _referenceGet(c);
        case 'post.action':
          return await _postAction(c);
        case 'astell.rooms':
          return await _astellRooms();
        case 'astell.create':
          return await _astellCreate(c);
        case 'timeline.list':
          return await _timelineList(c);
        case 'post.get':
          return await _postGet(c);
        case 'post.thread':
          return await _postThread(c);
        case 'post.reactions':
          return await _postReactions(c);
        case 'post.reposters':
          return await _postReposters(c);
        case 'post.quotes':
          return await _postQuotes(c);
        case 'favorites.list':
          return await _favoritesList(c);
        case 'reacted.list':
          return await _reactedList(c);
        case 'me.get':
          return await _meGet(c);
        case 'user.get':
          return await _userGet(c);
        case 'user.posts':
          return await _userPosts(c);
        case 'user.search':
          return await _userSearch(c);
        case 'user.follows':
          return await _userFollows(c);
        case 'user.relation':
          return await _userRelation(c);
        case 'moderation.list':
          return await _moderationList(c);
        case 'notifications.list':
          return await _notificationsList(c);
        case 'notifications.read':
          return await _notificationsRead(c);
        case 'trends.tags':
          return await _trendsTags(c);
        case 'lists.list':
          return await _listsList(c);
        case 'lists.members':
          return await _listsMembers(c);
        case 'clips.list':
          return await _clipsList(c);
        case 'clips.notes':
          return await _clipsNotes(c);
        case 'feeds.list':
          return await _feedsList(c);
        case 'dm.rooms':
          return await _dmRooms(c);
        case 'emoji.find':
          return await _emojiFind(c);
        case 'follow.set':
          return await _followSet(c);
        case 'list.edit':
          return await _listEdit(c);
        case 'list.create':
          return await _listCreate(c);
        case 'clip.edit':
          return await _clipEdit(c);
        case 'clip.create':
          return await _clipCreate(c);
        case 'settings.get':
          return await _settingsGet(c);
        case 'settings.set':
          return await _settingsSet(c);
        case 'feed.save':
          return await _feedSave(c);
        case 'web.search':
          return await _webSearch(c);
        case 'timeline.addFeed':
          return await _timelineAddFeed(c);
        case 'rasqLists.search':
          return await _rasqListsSearch(c);
        case 'timeline.addRasqList':
          return await _timelineAddRasqList(c);
        case 'timeline.excludeWord':
        case 'timeline.filterWord':
          return await _timelineFilterWord(c);
        case 'page.read':
          return await _pageRead(c);
        case 'tendency.seed':
          return await _tendencySeed(c);
        case 'post.compose':
        case 'post.reply':
        case 'post.quote':
        case 'dm.compose':
          return await _composeFill(c);
        case 'app.actions':
          return await _appActions(c);
      }
      return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsUnknown(c.name), ok: false);
    } catch (e) {
      return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsFailed(c.name, '$e'), ok: false);
    }
  }

  SnsSession _session() {
    final s = ref.read(currentSnsSessionProvider);
    if (s == null) throw StateError(appL10n.raiFunctionsNotLoggedInSns);
    return s;
  }

  /// チャイルドセーフ (D-454、セキュリティ確認 2026-10-09 の [9]): 関数で取った投稿にも、ホームと同じ保護者の表示制限を掛ける
  /// (見せない投稿は、モデルにも答えにも渡さない)。見守られていなければ素通し。
  List<Post> _shown(List<Post> posts) => ref.read(childGateProvider).filterPosts(posts);

  /// 投稿 1 件 / スレッドを読ませない理由(見せない投稿 / 見守りの時間に詳細を開かせない設定。画面の詳細と同じ)。読めるなら null。
  String? _detailBlocked(Post p) => ref.read(childGateProvider).postDetailBlockReason(p);

  static String _line(Post p) {
    final body = p.body.replaceAll(RegExp(r'\s+'), ' ').trim();
    final n = p.reactions.values.fold(0, (a, b) => a + b);
    return '@${p.author.account.handle}: $body${n > 0 ? appL10n.raiFunctionsLineReactions(n) : ''} [${p.id}]';
  }

  /// ソート / 絞り込み (D-221): kind=home(既定)| search(keyword で検索)、keyword で本文を絞る、
  /// sort=new(既定)| reactions、limit(既定 5)。KV の 4% ぶんで打ち切る。
  Future<RaiFunctionResult> _postsFetch(RaiFunctionCall c) async {
    final s = _session();
    final keyword = c.arg('keyword').trim();
    final limit = int.tryParse(c.arg('limit', '5')) ?? 5;
    final kind = c.arg('kind', 'home');
    final page = kind == 'search' && keyword.isNotEmpty ? await s.searchPosts(keyword, limit: 30) : await s.timeline(TimelineKind.home, limit: 30);
    var posts = [for (final p in _shown(page.items)) if (keyword.isEmpty || p.body.contains(keyword) || p.author.displayName.contains(keyword)) p];
    if (c.arg('sort') == 'reactions') {
      posts.sort((a, b) => b.reactions.values.fold(0, (x, y) => x + y).compareTo(a.reactions.values.fold(0, (x, y) => x + y)));
    }
    posts = posts.take(limit.clamp(1, 20)).toList();
    if (posts.isEmpty) return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsPostsNone, fetched: true);
    final lines = <String>[];
    var used = 0;
    for (final p in posts) {
      final l = _line(p);
      if (used + l.length > budget) {
        if (lines.isEmpty) lines.add(raiTruncate(l, budget));
        break;
      }
      lines.add(l);
      used += l.length + 1;
    }
    return RaiFunctionResult(name: c.name, text: '${appL10n.raiFunctionsPostsHead(lines.length, posts.length)}\n${lines.join('\n')}', fetched: true);
  }

  Future<RaiFunctionResult> _referenceGet(RaiFunctionCall c) async {
    final id = c.arg('id').trim();
    final RaiReferenceIndex index = ref.read(raiReferenceProvider).value ?? await ref.read(raiReferenceProvider.future);
    final op = index.operation(id);
    if (op != null) {
      final steps = index.expand(op);
      return RaiFunctionResult(name: c.name, text: raiTruncate(appL10n.raiFunctionsReferenceOperation(op.index, op.id, [for (final (i, s) in steps.indexed) '${i + 1}. ${s.text}'].join(' / ')), budget), fetched: true);
    }
    final fn = index.function(id);
    if (fn != null) {
      return RaiFunctionResult(name: c.name, text: raiTruncate('${appL10n.raiFunctionsReferenceFunction(fn.id, fn.does)}${fn.params.isEmpty ? '' : appL10n.raiFunctionsReferenceParams(fn.params.map((p) => '${p.label}(${p.isInput ? appL10n.raiFunctionsReferenceParamInput : appL10n.raiFunctionsReferenceParamFixed('${p.value}')})').join(', '))}', budget), fetched: true);
    }
    return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsReferenceMissing(id), fetched: true, ok: false);
  }

  Future<RaiFunctionResult> _postAction(RaiFunctionCall c) async {
    final s = _session();
    final actionId = c.arg('action').trim();
    final postId = c.arg('post').trim();
    final a = s.actions.where((x) => x.id == actionId).firstOrNull;
    if (a == null) return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsActionMissing(actionId), ok: false);
    if (!raiCanAutomate(a)) return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsActionNotAllowed(a.label), ok: false);
    final r = await s.performAction(actionId, postId);
    return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsActionDone(a.label, r.done ? appL10n.raiFunctionsActionDoneYes : appL10n.raiFunctionsActionDoneNo));
  }

  Future<RaiFunctionResult> _astellRooms() async {
    final home = await ref.read(astellClientProvider).home();
    final rooms = [...home.following, ...home.recommended, ...home.trending];
    if (rooms.isEmpty) return RaiFunctionResult(name: 'astell.rooms', text: appL10n.raiFunctionsAstellNoRooms, fetched: true);
    final seen = <String>{};
    final lines = [for (final r in rooms) if (seen.add(r.id)) '${r.title} [${r.id}]'];
    return RaiFunctionResult(name: 'astell.rooms', text: raiTruncate(appL10n.raiFunctionsAstellRooms(lines.join(' / ')), budget), fetched: true);
  }

  Future<RaiFunctionResult> _astellCreate(RaiFunctionCall c) async {
    final title = c.arg('title').trim();
    if (title.isEmpty) return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsAstellNoTitle, ok: false);
    final room = await ref.read(astellClientProvider).createRoom(NewAstellRoom(title: title));
    return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsAstellCreated(room.title, room.id));
  }

  // --- ここから D-223: 既存 SNS プラグイン関数のラップ(第一弾) ---

  /// limit 引数(既定 [fallback]、1〜[max] に丸める)。
  static int _limitOf(RaiFunctionCall c, {int fallback = 5, int max = 20}) => (int.tryParse(c.arg('limit', '$fallback')) ?? fallback).clamp(1, max);

  static String _userLine(UserSummary u) => '@${u.handle}(${u.displayName}) [${u.id}]';

  /// `kind=` 引数 → [TimelineKind]。`tag:語` / `list:id` は動的 TL、それ以外は既知の定数(無ければ
  /// そのまま id=label にする、プラグインが独自に増やす分もこれで通す)。
  static TimelineKind _timelineKindOf(String raw) {
    if (raw.startsWith('tag:')) return DynamicTimelines.tag(raw.substring(4));
    if (raw.startsWith('list:')) return TimelineKind.list(raw.substring(5), raw);
    return switch (raw) {
      'home' => TimelineKind.home,
      'local' => TimelineKind.local,
      'social' => TimelineKind.social,
      'global' => TimelineKind.global,
      'recommended' => TimelineKind.recommended,
      'featured' => DynamicTimelines.featured,
      _ => TimelineKind(raw, raw),
    };
  }

  /// 通知 1 件の表示行 (D-223)。
  static String _notificationLine(NotificationItem n) {
    final who = n.actors.isEmpty ? '' : '@${n.actors.first.handle}';
    final what = switch (n.kind) {
      NotificationKind.reaction => appL10n.raiFunctionsNotifReaction(who, n.reaction == null ? '' : '(${n.reaction})'),
      NotificationKind.repost => appL10n.raiFunctionsNotifRepost(who),
      NotificationKind.quote => appL10n.raiFunctionsNotifQuote(who),
      NotificationKind.reply => appL10n.raiFunctionsNotifReply(who),
      NotificationKind.mention => appL10n.raiFunctionsNotifMention(who),
      NotificationKind.follow => appL10n.raiFunctionsNotifFollow(who),
      NotificationKind.followRequest => appL10n.raiFunctionsNotifFollowRequest(who),
      NotificationKind.followAccepted => appL10n.raiFunctionsNotifFollowAccepted(who),
      NotificationKind.listAdded => appL10n.raiFunctionsNotifListAdded(who),
      NotificationKind.pollEnded => appL10n.raiFunctionsNotifPollEnded,
      NotificationKind.timer => appL10n.raiFunctionsNotifTimer,
      NotificationKind.vc => appL10n.raiFunctionsNotifVc,
      NotificationKind.system => n.title ?? appL10n.raiFunctionsNotifSystem,
      NotificationKind.other => appL10n.raiFunctionsNotifOther,
    };
    return '$what${n.read ? '' : appL10n.raiFunctionsUnreadMark} [${n.id}]';
  }

  /// timeline.list(kind, limit): TL を取る (D-223)。
  Future<RaiFunctionResult> _timelineList(RaiFunctionCall c) => raiGuard(c.name, () async {
        final kindArg = c.arg('kind', 'home').trim();
        // 見守り (セキュリティ確認 2026-10-09 の [21]): DM / チャットの TL(dm: / chat:)は、dm.* の関数と同じく DM を止めていれば取らない。
        if (ref.read(childGateProvider).timelineKindBlockReason(kindArg) case final blocked?) return RaiFunctionResult(name: c.name, text: blocked, ok: false);
        final limit = _limitOf(c);
        final page = await _session().timeline(_timelineKindOf(kindArg), limit: limit);
        final lines = [for (final p in _shown(page.items).take(limit)) _line(p)];
        return RaiFunctionResult(name: c.name, text: raiTruncate(raiFoldLines(lines, budget, head: 'TL($kindArg)'), budget), fetched: true);
      });

  /// post.get(id): 投稿 1 件の本文を取る (D-223)。
  Future<RaiFunctionResult> _postGet(RaiFunctionCall c) => raiGuard(c.name, () async {
        final id = c.arg('id').trim();
        if (id.isEmpty) return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsMissingPostId, ok: false);
        final p = await _session().post(id);
        final blocked = _detailBlocked(p);
        if (blocked != null) return RaiFunctionResult(name: c.name, text: blocked, ok: false);
        return RaiFunctionResult(name: c.name, text: raiTruncate(_line(p), budget), fetched: true);
      });

  /// post.thread(post, limit): 投稿とその返信を取る (D-223)。
  Future<RaiFunctionResult> _postThread(RaiFunctionCall c) => raiGuard(c.name, () async {
        final id = c.arg('post').trim();
        if (id.isEmpty) return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsMissingPostArg, ok: false);
        final limit = _limitOf(c);
        final t = await _session().thread(id);
        final blocked = _detailBlocked(t.post);
        if (blocked != null) return RaiFunctionResult(name: c.name, text: blocked, ok: false);
        final lines = [_line(t.post), for (final p in _shown(t.descendants).take(limit)) appL10n.raiFunctionsThreadReply(_line(p))];
        return RaiFunctionResult(name: c.name, text: raiTruncate(raiFoldLines(lines, budget, head: appL10n.raiFunctionsHeadThread), budget), fetched: true);
      });

  /// post.reactions(post, limit): 誰がどう反応したかを絵文字ごとに集計する (D-223)。
  Future<RaiFunctionResult> _postReactions(RaiFunctionCall c) => raiGuard(c.name, () async {
        final id = c.arg('post').trim();
        if (id.isEmpty) return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsMissingPostArg, ok: false);
        final page = await _session().reactions(id, limit: _limitOf(c, fallback: 30, max: 100));
        final byReaction = <String, int>{};
        for (final r in page.items) {
          byReaction[r.reaction] = (byReaction[r.reaction] ?? 0) + 1;
        }
        final lines = [for (final e in byReaction.entries) '${e.key} × ${e.value}'];
        return RaiFunctionResult(name: c.name, text: raiTruncate(raiFoldLines(lines, budget, head: appL10n.raiFunctionsHeadReactions), budget), fetched: true);
      });

  /// post.reposters(post, limit): リノートした人を取る (D-223)。
  Future<RaiFunctionResult> _postReposters(RaiFunctionCall c) => raiGuard(c.name, () async {
        final id = c.arg('post').trim();
        if (id.isEmpty) return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsMissingPostArg, ok: false);
        final page = await _session().reposters(id, limit: _limitOf(c));
        final lines = [for (final u in page.items) _userLine(u)];
        return RaiFunctionResult(name: c.name, text: raiTruncate(raiFoldLines(lines, budget, head: appL10n.raiFunctionsHeadReposters), budget), fetched: true);
      });

  /// post.quotes(post, limit): 引用した投稿を取る (D-223)。
  Future<RaiFunctionResult> _postQuotes(RaiFunctionCall c) => raiGuard(c.name, () async {
        final id = c.arg('post').trim();
        if (id.isEmpty) return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsMissingPostArg, ok: false);
        final page = await _session().quotes(id, limit: _limitOf(c));
        final lines = [for (final p in _shown(page.items)) _line(p)];
        return RaiFunctionResult(name: c.name, text: raiTruncate(raiFoldLines(lines, budget, head: appL10n.raiFunctionsHeadQuotes), budget), fetched: true);
      });

  /// favorites.list(limit): ブックマーク/お気に入りを取る (D-223)。
  Future<RaiFunctionResult> _favoritesList(RaiFunctionCall c) => raiGuard(c.name, () async {
        final page = await _session().favorites(limit: _limitOf(c));
        final lines = [for (final p in _shown(page.items)) _line(p)];
        return RaiFunctionResult(name: c.name, text: raiTruncate(raiFoldLines(lines, budget, head: appL10n.raiFunctionsHeadFavorites), budget), fetched: true);
      });

  /// reacted.list(limit): 自分がリアクションした投稿を取る (D-223)。
  Future<RaiFunctionResult> _reactedList(RaiFunctionCall c) => raiGuard(c.name, () async {
        final page = await _session().reactedPosts(limit: _limitOf(c));
        final lines = [for (final p in _shown(page.items)) _line(p)];
        return RaiFunctionResult(name: c.name, text: raiTruncate(raiFoldLines(lines, budget, head: appL10n.raiFunctionsHeadReacted), budget), fetched: true);
      });

  /// me.get(): 今のアカウントを取る (D-223)。
  Future<RaiFunctionResult> _meGet(RaiFunctionCall c) => raiGuard(c.name, () async {
        final s = _session();
        final me = await s.me();
        return RaiFunctionResult(name: c.name, text: raiTruncate(appL10n.raiFunctionsMe(_userLine(me), s.pluginId), budget), fetched: true);
      });

  /// user.get(id=|handle=@名前): プロフィールを取る (D-223)。
  Future<RaiFunctionResult> _userGet(RaiFunctionCall c) => raiGuard(c.name, () async {
        final s = _session();
        final id = c.arg('id').trim();
        final handle = c.arg('handle').trim();
        UserProfile? profile;
        if (id.isNotEmpty) {
          profile = await s.user(id);
        } else if (handle.isNotEmpty) {
          profile = await s.userByHandle(handle.replaceFirst('@', ''));
        } else {
          return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsUserIdOrHandle, ok: false);
        }
        if (profile == null) return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsNotFound, ok: false, fetched: true);
        final u = profile.summary;
        final text = '${_userLine(u)}${profile.description == null || profile.description!.isEmpty ? '' : ' — ${profile.description}'}'
            '${appL10n.raiFunctionsUserCounts('${profile.followersCount ?? '?'}', '${profile.followingCount ?? '?'}')}';
        return RaiFunctionResult(name: c.name, text: raiTruncate(text, budget), fetched: true);
      });

  /// user.posts(user, filter, limit): ユーザーの投稿を取る (D-223)。
  Future<RaiFunctionResult> _userPosts(RaiFunctionCall c) => raiGuard(c.name, () async {
        final id = c.arg('user').trim();
        if (id.isEmpty) return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsMissingUser, ok: false);
        final filterArg = c.arg('filter', 'posts');
        UserPostsFilter filter;
        try {
          filter = UserPostsFilter.values.byName(filterArg);
        } catch (_) {
          filter = UserPostsFilter.posts;
        }
        final page = await _session().userPosts(id, limit: _limitOf(c), filter: filter);
        final lines = [for (final p in _shown(page.items)) _line(p)];
        return RaiFunctionResult(name: c.name, text: raiTruncate(raiFoldLines(lines, budget, head: appL10n.raiFunctionsHeadUserPosts(filterArg)), budget), fetched: true);
      });

  /// user.search(keyword, limit): ユーザーを検索する (D-223)。
  Future<RaiFunctionResult> _userSearch(RaiFunctionCall c) => raiGuard(c.name, () async {
        final keyword = c.arg('keyword').trim();
        if (keyword.isEmpty) return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsMissingKeyword, ok: false);
        final page = await _session().searchUsers(keyword, limit: _limitOf(c));
        final lines = [for (final u in page.items) _userLine(u)];
        return RaiFunctionResult(name: c.name, text: raiTruncate(raiFoldLines(lines, budget, head: appL10n.raiFunctionsHeadUserSearch(keyword)), budget), fetched: true);
      });

  /// user.follows(user, direction, limit): フォロワー/フォロー中を取る (D-223)。
  Future<RaiFunctionResult> _userFollows(RaiFunctionCall c) => raiGuard(c.name, () async {
        final id = c.arg('user').trim();
        if (id.isEmpty) return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsMissingUser, ok: false);
        final dir = c.arg('direction', 'followers');
        final s = _session();
        final page = dir == 'following' ? await s.following(id, limit: _limitOf(c)) : await s.followers(id, limit: _limitOf(c));
        final lines = [for (final u in page.items) _userLine(u)];
        return RaiFunctionResult(name: c.name, text: raiTruncate(raiFoldLines(lines, budget, head: dir == 'following' ? appL10n.raiFunctionsHeadFollowing : appL10n.raiFunctionsHeadFollowers), budget), fetched: true);
      });

  /// user.relation(user): 自分との関係を取る (D-223)。
  Future<RaiFunctionResult> _userRelation(RaiFunctionCall c) => raiGuard(c.name, () async {
        final id = c.arg('user').trim();
        if (id.isEmpty) return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsMissingUser, ok: false);
        final r = await _session().relationship(id);
        final flags = [
          if (r.following) appL10n.raiFunctionsRelFollowing,
          if (r.followedBy) appL10n.raiFunctionsRelFollowedBy,
          if (r.requested) appL10n.raiFunctionsRelRequested,
          if (r.muted) appL10n.raiFunctionsRelMuted,
          if (r.blocked) appL10n.raiFunctionsRelBlocked,
          if (r.blockedBy) appL10n.raiFunctionsRelBlockedBy,
        ];
        return RaiFunctionResult(name: c.name, text: raiTruncate(appL10n.raiFunctionsRelation(flags.isEmpty ? appL10n.raiFunctionsRelNone : flags.join(' / ')), budget), fetched: true);
      });

  /// moderation.list(kind=muted|blocked|requests): ミュート/ブロック/フォロー申請の一覧を取る (D-223)。
  Future<RaiFunctionResult> _moderationList(RaiFunctionCall c) => raiGuard(c.name, () async {
        final s = _session();
        final kind = c.arg('kind', 'requests');
        final List<String> lines;
        switch (kind) {
          case 'muted':
            lines = [for (final u in (await s.mutedUsers(limit: _limitOf(c, fallback: 30, max: 100))).items) _userLine(u)];
          case 'blocked':
            lines = [for (final u in (await s.blockedUsers(limit: _limitOf(c, fallback: 30, max: 100))).items) _userLine(u)];
          default:
            lines = [for (final r in await s.followRequests()) appL10n.raiFunctionsRequestLine(_userLine(r.user), r.id)];
        }
        return RaiFunctionResult(name: c.name, text: raiTruncate(raiFoldLines(lines, budget, head: appL10n.raiFunctionsHeadModeration(kind)), budget), fetched: true);
      });

  /// notifications.list(kind, limit): 通知を取る (D-223)。kind=all(既定)で絞り込まない。
  Future<RaiFunctionResult> _notificationsList(RaiFunctionCall c) => raiGuard(c.name, () async {
        final kindArg = c.arg('kind', 'all');
        final page = await _session().notifications(limit: 30);
        var items = page.items;
        if (kindArg != 'all') {
          NotificationKind? want;
          try {
            want = NotificationKind.values.byName(kindArg);
          } catch (_) {
            want = null;
          }
          if (want != null) items = [for (final n in items) if (n.kind == want) n];
        }
        items = items.take(_limitOf(c)).toList();
        final unread = items.where((n) => !n.read).length;
        final lines = [for (final n in items) _notificationLine(n)];
        return RaiFunctionResult(name: c.name, text: raiTruncate(raiFoldLines(lines, budget, head: appL10n.raiFunctionsHeadNotifications(unread)), budget), fetched: true);
      });

  /// notifications.read(): 通知をまとめて既読にする (D-223)。
  Future<RaiFunctionResult> _notificationsRead(RaiFunctionCall c) => raiGuard(c.name, () async {
        await _session().markNotificationsRead();
        return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsNotificationsRead);
      });

  /// trends.tags(limit): トレンドのタグを取る (D-223)。
  Future<RaiFunctionResult> _trendsTags(RaiFunctionCall c) => raiGuard(c.name, () async {
        final tags = await _session().trendingTags();
        final lines = [for (final t in tags.take(_limitOf(c))) '#${appL10n.raiFunctionsTrendLine(t.tag, t.usersCount ?? 0)}'];
        return RaiFunctionResult(name: c.name, text: raiTruncate(raiFoldLines(lines, budget, head: appL10n.raiFunctionsHeadTrends), budget), fetched: true);
      });

  /// lists.list(): リスト一覧を取る (D-223)。
  Future<RaiFunctionResult> _listsList(RaiFunctionCall c) => raiGuard(c.name, () async {
        final lists = await _session().lists();
        final lines = [for (final l in lists) appL10n.raiFunctionsListLine(l.name, l.id, l.memberIds.length)];
        return RaiFunctionResult(name: c.name, text: raiTruncate(raiFoldLines(lines, budget, head: appL10n.raiFunctionsHeadLists), budget), fetched: true);
      });

  /// lists.members(list): リストのメンバーを取る (D-223)。
  Future<RaiFunctionResult> _listsMembers(RaiFunctionCall c) => raiGuard(c.name, () async {
        final id = c.arg('list').trim();
        if (id.isEmpty) return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsMissingList, ok: false);
        final members = await _session().listMembers(id);
        final lines = [for (final u in members) _userLine(u)];
        return RaiFunctionResult(name: c.name, text: raiTruncate(raiFoldLines(lines, budget, head: appL10n.raiFunctionsHeadListMembers), budget), fetched: true);
      });

  /// clips.list(user=): クリップ一覧を取る (D-223、Misskey のみ)。
  Future<RaiFunctionResult> _clipsList(RaiFunctionCall c) => raiGuard(c.name, () async {
        final userId = c.arg('user').trim();
        final clips = await _session().clips(userId: userId.isEmpty ? null : userId);
        final lines = [for (final cl in clips) '${cl.name} [${cl.id}]${cl.notesCount == null ? '' : appL10n.raiFunctionsClipCount(cl.notesCount!)}'];
        return RaiFunctionResult(name: c.name, text: raiTruncate(raiFoldLines(lines, budget, head: appL10n.raiFunctionsHeadClips), budget), fetched: true);
      });

  /// clips.notes(clip, limit): クリップの中身を取る (D-223、Misskey のみ)。
  Future<RaiFunctionResult> _clipsNotes(RaiFunctionCall c) => raiGuard(c.name, () async {
        final id = c.arg('clip').trim();
        if (id.isEmpty) return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsMissingClip, ok: false);
        final page = await _session().clipNotes(id, limit: _limitOf(c));
        final lines = [for (final p in _shown(page.items)) _line(p)];
        return RaiFunctionResult(name: c.name, text: raiTruncate(raiFoldLines(lines, budget, head: appL10n.raiFunctionsHeadClipNotes), budget), fetched: true);
      });

  /// feeds.list(keyword=): カスタムフィードを取る (D-223、Bluesky のみ)。keyword 無しは保存済み。
  Future<RaiFunctionResult> _feedsList(RaiFunctionCall c) => raiGuard(c.name, () async {
        final keyword = c.arg('keyword').trim();
        final s = _session();
        final feeds = keyword.isEmpty ? await s.savedFeeds() : await s.searchFeeds(keyword, limit: _limitOf(c));
        // uri を添える (D-227): feed.save / timeline.addFeed の feed= に渡せるように。候補 (D-229) は自動化の選択肢に。
        final lines = [for (final f in feeds) '${f.name}${f.description == null || f.description!.isEmpty ? '' : ' — ${f.description}'} [${f.uri}]'];
        return RaiFunctionResult(name: c.name, text: raiTruncate(raiFoldLines(lines, budget, head: appL10n.raiFunctionsHeadFeeds), budget), fetched: true, items: [for (final f in feeds) RaiFunctionItem(id: f.uri, label: f.name)]);
      });

  /// dm.rooms(): DM ルーム一覧を取る (D-223)。
  Future<RaiFunctionResult> _dmRooms(RaiFunctionCall c) => raiGuard(c.name, () async {
        final rooms = await _session().dmRooms();
        final lines = [for (final r in rooms) '${r.displayTitle}${r.unreadCount > 0 ? appL10n.raiFunctionsDmUnread(r.unreadCount) : ''} [${r.id}]'];
        return RaiFunctionResult(name: c.name, text: raiTruncate(raiFoldLines(lines, budget, head: 'DM'), budget), fetched: true);
      });

  /// emoji.find(keyword, limit): keyword を含むカスタム絵文字を探す (D-223)。
  Future<RaiFunctionResult> _emojiFind(RaiFunctionCall c) => raiGuard(c.name, () async {
        final keyword = c.arg('keyword').trim();
        if (keyword.isEmpty) return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsMissingKeyword, ok: false);
        final all = await _session().customEmojis();
        final matched = [for (final e in all) if (e.name.contains(keyword) || e.aliases.any((a) => a.contains(keyword))) e];
        final lines = [for (final e in matched.take(_limitOf(c))) ':${e.name}:'];
        return RaiFunctionResult(name: c.name, text: raiTruncate(raiFoldLines(lines, budget, head: appL10n.raiFunctionsHeadEmoji(keyword)), budget), fetched: true);
      });

  /// follow.set(user, on=true|false): フォローする/外す (D-223、実行系)。
  Future<RaiFunctionResult> _followSet(RaiFunctionCall c) => raiGuard(c.name, () async {
        final id = c.arg('user').trim();
        if (id.isEmpty) return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsMissingUser, ok: false);
        final on = c.arg('on', 'true') != 'false';
        final r = await _session().setFollowing(id, on);
        final text = !on
            ? appL10n.raiFunctionsUnfollowed
            : r.requested
                ? appL10n.raiFunctionsFollowRequested
                : appL10n.raiFunctionsFollowed;
        return RaiFunctionResult(name: c.name, text: text);
      });

  /// list.edit(list, user, add=true|false): リストにユーザーを足す/外す (D-223、実行系)。
  Future<RaiFunctionResult> _listEdit(RaiFunctionCall c) => raiGuard(c.name, () async {
        final listId = c.arg('list').trim();
        final userId = c.arg('user').trim();
        if (listId.isEmpty || userId.isEmpty) return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsListUserArgs, ok: false);
        final add = c.arg('add', 'true') != 'false';
        final s = _session();
        if (add) {
          await s.addToList(listId, userId);
        } else {
          await s.removeFromList(listId, userId);
        }
        return RaiFunctionResult(name: c.name, text: add ? appL10n.raiFunctionsListAdded : appL10n.raiFunctionsListRemoved);
      });

  /// list.create(name): リストを作る (D-223、実行系)。
  Future<RaiFunctionResult> _listCreate(RaiFunctionCall c) => raiGuard(c.name, () async {
        final name = c.arg('name').trim();
        if (name.isEmpty) return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsMissingName, ok: false);
        final l = await _session().createList(name);
        return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsListCreated(l.name, l.id));
      });

  /// clip.edit(clip, post, add=true|false): クリップに投稿を足す/外す (D-223、Misskey のみ、実行系)。
  Future<RaiFunctionResult> _clipEdit(RaiFunctionCall c) => raiGuard(c.name, () async {
        final clipId = c.arg('clip').trim();
        final postId = c.arg('post').trim();
        if (clipId.isEmpty || postId.isEmpty) return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsClipPostArgs, ok: false);
        final add = c.arg('add', 'true') != 'false';
        final s = _session();
        if (add) {
          await s.addToClip(clipId, postId);
        } else {
          await s.removeFromClip(clipId, postId);
        }
        return RaiFunctionResult(name: c.name, text: add ? appL10n.raiFunctionsClipAdded : appL10n.raiFunctionsClipRemoved);
      });

  /// clip.create(name): クリップを作る (D-223、Misskey のみ、実行系)。
  Future<RaiFunctionResult> _clipCreate(RaiFunctionCall c) => raiGuard(c.name, () async {
        final name = c.arg('name').trim();
        if (name.isEmpty) return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsMissingName, ok: false);
        final cl = await _session().createClip(name);
        return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsClipCreated(cl.name, cl.id));
      });

  /// settings.get(area, key): アプリの設定値を読む (D-223、読み取り専用)。ホストの静的ページ
  /// (`appearance.*`) と SNS プラグインのページ(`sns.<短area>`)の両方に対応し、
  /// [settingsPageSpecProvider] の spec に無い area/key は拒否する(勝手に読める設定を増やさない)。
  Future<RaiFunctionResult> _settingsGet(RaiFunctionCall c) async {
    final area = c.arg('area').trim();
    final key = c.arg('key').trim();
    if (area.isEmpty || key.isEmpty) return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsAreaKeyArgs, ok: false);
    final SettingsPageSpec spec;
    try {
      spec = await ref.read(settingsPageSpecProvider(area).future);
    } catch (e) {
      return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsSettingsPageMissing(area), ok: false);
    }
    if (!spec.defaults.containsKey(key)) {
      return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsSettingMissing(area, key, spec.defaults.keys.join(', ')), ok: false);
    }
    final values = spec.isRemote ? await ref.read(remoteSettingsProvider(spec.area).future) : await ref.read(settingsAreaProvider(area).future);
    final value = values[key] ?? spec.defaults[key];
    return RaiFunctionResult(name: c.name, text: raiTruncate('$area.$key = $value', budget), fetched: true);
  }

  /// settings.set(area, key, value): 設定を書く (D-225)。[raiSettingsWritable] で「既定設定はパスワード不要の
  /// 部分 / プラグイン設定は操作禁止タグの無い部分」に絞り、値は [raiCoerceSettingValue] で型 / 選択肢 / 範囲を
  /// 合わせる。書き込み先は画面と同じ([SettingsAreaStore] / [RemoteSettingsStore])なので、プラグインへの
  /// 即時反映(applySettings)やサーバー保存もそのまま効く。
  Future<RaiFunctionResult> _settingsSet(RaiFunctionCall c) async {
    final area = c.arg('area').trim();
    final key = c.arg('key').trim();
    final raw = c.arg('value');
    if (area.isEmpty || key.isEmpty || raw.trim().isEmpty) return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsAreaKeyValueArgs, ok: false);
    final SettingsPageSpec spec;
    try {
      spec = await ref.read(settingsPageSpecProvider(area).future);
    } catch (e) {
      return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsSettingsPageMissing(area), ok: false);
    }
    final gate = raiSettingsWritable(spec, key);
    if (!gate.ok) return RaiFunctionResult(name: c.name, text: gate.reason, ok: false);
    final value = raiCoerceSettingValue(spec, key, raw);
    if (value == null) return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsSettingBadValue(key, raw.trim(), '${spec.defaults[key]}'), ok: false);
    if (spec.isRemote) {
      await ref.read(remoteSettingsProvider(spec.area).notifier).set(key, value);
    } else {
      await ref.read(settingsAreaProvider(area).notifier).set(key, value);
    }
    return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsSettingSet(area, key, '$value'));
  }

  /// post.compose(text) / post.reply(post, text) / post.quote(post, text) / dm.compose(room, text):
  /// 送信 / 返信系は自動化不可 (D-225、ユーザー指定)。代わりに**コンポーザーを開いて本文を入れる**だけにし、
  /// 送るかどうかはユーザーが決める。開いたコンポーザーは待たない(閉じるまで答えが止まらないように)。
  Future<RaiFunctionResult> _composeFill(RaiFunctionCall c) => raiGuard(c.name, () async {
        final text = c.arg('text').trim();
        if (text.isEmpty) return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsMissingText, ok: false);
        final s = _session();
        final ComposeTarget target;
        switch (c.name) {
          case 'post.reply':
          case 'post.quote':
            final id = c.arg('post').trim();
            if (id.isEmpty) return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsMissingPostArg, ok: false);
            final p = await s.post(id);
            target = c.name == 'post.reply' ? ComposeReply(p) : ComposeQuote(p);
          case 'dm.compose':
            final id = c.arg('room').trim();
            if (id.isEmpty) return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsMissingRoom, ok: false);
            final room = (await s.dmRooms()).where((r) => r.id == id).firstOrNull;
            if (room == null) return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsDmRoomMissing(id), ok: false);
            target = ComposeDm(room);
          default:
            target = const ComposeNormal();
        }
        unawaited(showComposerWith(target, manager: ref.read(overlayManagerProvider), router: ref.read(routerProvider), initialText: text));
        return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsComposeFilled(target.title));
      });

  /// feed= を解く (D-227): at:// / bsky.app の URL ならそのまま(検索で 1 件に解決)、語なら検索の先頭。
  Future<FeedInfo?> _resolveFeed(SnsSession s, String feed) async {
    final q = feed.trim();
    if (q.isEmpty) return null;
    final found = await s.searchFeeds(q, limit: 5);
    if (q.startsWith('at://')) {
      final hit = found.where((f) => f.uri == q).firstOrNull;
      if (hit != null) return hit;
      // 保存済みにあれば名前が分かる(検索が uri を解けないプラグイン向け)。
      try {
        final saved = (await s.savedFeeds()).where((f) => f.uri == q).firstOrNull;
        if (saved != null) return saved;
      } catch (_) {}
      return FeedInfo(uri: q, name: q.split('/').last);
    }
    return found.firstOrNull;
  }

  /// Bluesky のセッション (D-227): account= の名義(@handle@instance)があればそれ、無ければ現在のアカウントが
  /// Bluesky ならそれ、それも無ければ最初の Bluesky アカウント。
  (AccountSession, SnsSession)? _blueskySession(String account) {
    final sessions = ref.read(sessionsProvider).value?.sessions ?? const <AccountSession>[];
    final bluesky = [for (final s in sessions) if (s.account.kind == SnsKind.bluesky) s];
    AccountSession? pick;
    if (account.trim().isNotEmpty) {
      final a = account.trim().replaceFirst(RegExp(r'^@'), '');
      pick = bluesky.where((s) => '${s.account}'.replaceFirst(RegExp(r'^@'), '') == a || s.account.handle == a || s.account.key == account.trim()).firstOrNull;
    } else {
      final cur = ref.read(currentAccountSessionProvider);
      pick = cur != null && cur.account.kind == SnsKind.bluesky ? cur : bluesky.firstOrNull;
    }
    if (pick == null) return null;
    try {
      return (pick, ref.read(pluginRegistryProvider).session(pick));
    } catch (_) {
      return null;
    }
  }

  /// feed.save(feed, on): カスタムフィードを保存する / 外す (D-227、Bluesky のみ)。
  Future<RaiFunctionResult> _feedSave(RaiFunctionCall c) => raiGuard(c.name, () async {
        final s = _session();
        final f = await _resolveFeed(s, c.arg('feed'));
        if (f == null) return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsFeedNotFound(c.arg('feed')), ok: false);
        final on = c.arg('on', 'true').toLowerCase() != 'false';
        final saved = await s.saveFeed(f.uri, on: on);
        return RaiFunctionResult(name: c.name, text: on ? appL10n.raiFunctionsFeedSaved(f.name, saved.length) : appL10n.raiFunctionsFeedUnsaved(f.name, saved.length));
      });

  /// timeline.addFeed(feed, account): ホームの TL カスタマイズにカスタムフィードを取り込み元として足す (D-227)。
  /// 画面(TL カスタマイズ → タイムラインを追加 → カスタムフィード)を通らずに、同じ保存先へ書く。
  Future<RaiFunctionResult> _timelineAddFeed(RaiFunctionCall c) => raiGuard(c.name, () async {
        final picked = _blueskySession(c.arg('account'));
        if (picked == null) return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsNoBluesky, ok: false);
        final (acc, s) = picked;
        final f = await _resolveFeed(s, c.arg('feed'));
        if (f == null) return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsFeedNotFound(c.arg('feed')), ok: false);
        final owner = ref.read(currentAccountSessionProvider)?.account.key ?? acc.account.key;
        final added = await addTlSource(ref.container, owner, 'tl.home', TlSourceComponent(tl: 'feed:${f.uri}', account: '${acc.account}', label: f.name));
        if (!added) return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsFeedAlreadyHome(f.name));
        ref.invalidate(timelineProvider(TimelineKind.home));
        return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsFeedAddedHome(f.name, '${acc.account}'));
      });

  /// RASQ リストの候補 (D-348): keyword 無し = 自分のリスト + フォロー中、あれば公開リストの検索。
  Future<List<RasqCollection>> _rasqListCandidates(String keyword) async {
    final api = ref.read(rasqCollectionsApiProvider);
    if (api == null || ref.read(orgateAccountProvider).value == null) throw StateError(appL10n.raiFunctionsNotLoggedInRasq);
    if (keyword.isEmpty) {
      final mine = await api.mine(RasqCollectionKind.list);
      final following = [for (final c in await api.following()) if (c.kind == RasqCollectionKind.list && !mine.any((m) => m.id == c.id)) c];
      return [...mine, ...following];
    }
    return api.search(keyword);
  }

  /// rasqLists.search(keyword=): RASQ リストを探す (D-348)。id を添える(timeline.addRasqList の list= に渡せるように)。
  Future<RaiFunctionResult> _rasqListsSearch(RaiFunctionCall c) => raiGuard(c.name, () async {
        final lists = await _rasqListCandidates(c.arg('keyword').trim());
        String state(RasqCollection l) => l.isOwner ? appL10n.raiFunctionsRasqListMine : (l.canFetch == false && l.canFetchChecked ? appL10n.raiFunctionsRasqListUnfetchable : (l.following ? appL10n.raiFunctionsRasqListFollowing : '@${l.owner.handle}'));
        final lines = [for (final l in lists) '${appL10n.raiFunctionsRasqListLine(l.name, l.itemCount, state(l))}${l.description == null ? '' : ' — ${l.description}'} [${l.id}]'];
        return RaiFunctionResult(name: c.name, text: raiTruncate(raiFoldLines(lines, budget, head: appL10n.raiFunctionsHeadRasqLists), budget), fetched: true, items: [for (final l in lists) if (!(l.canFetch == false && l.canFetchChecked)) RaiFunctionItem(id: l.id, label: l.name)]);
      });

  /// timeline.addRasqList(list=id|語): RASQ リストをホームの TL に取り込む (D-348)。取り込めるのはリスト内の人の情報を取れるものだけ
  /// (画面の「タイムラインに取り込む」D-347 と同じ。作った人でもフォロー中でもなければフォローもする)。
  Future<RaiFunctionResult> _timelineAddRasqList(RaiFunctionCall c) => raiGuard(c.name, () async {
        final q = c.arg('list').trim();
        if (q.isEmpty) return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsMissingListArg, ok: false);
        final own = await _rasqListCandidates('');
        final hit = own.where((l) => l.id == q || l.code == q || l.name == q).firstOrNull ??
            own.where((l) => l.name.contains(q)).firstOrNull ??
            (await _rasqListCandidates(q)).firstOrNull;
        if (hit == null) return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsRasqListNotFound(q), ok: false);
        final (msg, added) = await importRasqListToHomeWith(ref.container, hit);
        final ok = added || msg.contains('もう'); // l10n-ignore
        return RaiFunctionResult(name: c.name, text: msg, ok: ok);
      });

  /// timeline.excludeWord(word, scope) / timeline.filterWord(word, mode=include|exclude, scope): 検索絞り込みを足す (D-227 / D-229)。
  /// excludeWord は mode=exclude の別名。include はそのワードを含む投稿だけ通す。
  Future<RaiFunctionResult> _timelineFilterWord(RaiFunctionCall c) => raiGuard(c.name, () async {
        final word = c.arg('word').trim();
        if (word.isEmpty) return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsMissingWord, ok: false);
        final exclude = c.name == 'timeline.excludeWord' || c.arg('mode', 'exclude').trim() != 'include';
        final scope = switch (c.arg('scope', 'home').trim()) { 'social' => 'tl.social', 'local' => 'tl.local', 'global' => 'tl.global', _ => 'tl.home' };
        final owner = ref.read(currentAccountSessionProvider)?.account.key;
        if (owner == null) return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsNotLoggedIn, ok: false);
        final added = await addTlAlgorithm(ref.container, owner, scope, TlAlgorithmComponent(type: 'queryfilter', query: word, exclude: exclude));
        if (!added) return RaiFunctionResult(name: c.name, text: exclude ? appL10n.raiFunctionsWordExcludeAlready(word) : appL10n.raiFunctionsWordIncludeAlready(word));
        ref.invalidate(timelineProvider(TimelineKind.home));
        return RaiFunctionResult(name: c.name, text: exclude ? appL10n.raiFunctionsWordExcluded(word, scope.substring(3)) : appL10n.raiFunctionsWordIncluded(word, scope.substring(3)));
      });

  /// page.read(filter, tag): いま開いている画面の表示データを取る (D-229: 自動化は画面を押さず、ページへ直接行って
  /// データを関数で読む)。ホーム(フォロー中の TL)/ フィード TL / リスト(リスト + 保存済みフィード)/ 通知 / DM。
  /// filter= は本文 / 名前の部分一致、tag= は `#タグ` の一致。
  Future<RaiFunctionResult> _pageRead(RaiFunctionCall c) => raiGuard(c.name, () async {
        final router = ref.read(routerProvider);
        final loc = visibleLocationOf(router.routerDelegate.currentConfiguration);
        final filter = c.arg('filter').trim().toLowerCase();
        final tag = c.arg('tag').trim().replaceFirst(RegExp(r'^#'), '').toLowerCase();
        bool keep(String text) {
          final t = text.toLowerCase();
          if (filter.isNotEmpty && !t.contains(filter)) return false;
          if (tag.isNotEmpty && !t.contains('#$tag')) return false;
          return true;
        }
        List<String> lines;
        String head;
        List<RaiFunctionItem> items = const [];
        if (loc.startsWith('/feeds/')) {
          final uri = Uri.decodeComponent(loc.substring('/feeds/'.length).split('?').first);
          final page = await _session().timeline(TimelineKind('feed:$uri', appL10n.raiFunctionsFeedKindLabel), limit: 20);
          lines = [for (final p in _shown(page.items)) if (keep(p.body)) _line(p)];
          head = appL10n.raiFunctionsHeadFeedTimeline;
        } else if (loc.startsWith(Routes.lists)) {
          final lists = await ref.read(listsProvider.future);
          List<FeedInfo> feeds = const [];
          try {
            feeds = await ref.read(savedFeedsProvider.future);
          } catch (_) {}
          lines = [for (final l in lists) if (keep(l.name)) appL10n.raiFunctionsPageList(l.name, l.id), for (final f in feeds) if (keep(f.name)) appL10n.raiFunctionsPageFeed(f.name, f.uri)];
          items = [for (final f in feeds) if (keep(f.name)) RaiFunctionItem(id: f.uri, label: f.name)];
          head = appL10n.raiFunctionsHeadListsPage;
        } else if (loc.startsWith(Routes.notifications)) {
          final page = await _session().notifications();
          lines = [for (final n in ref.read(childGateProvider).filterNotifications(page.items)) if (keep('${n.kind.name} ${n.post?.body ?? ''}')) '${n.kind.name}: ${n.actors.map((a) => '@${a.handle}').join(', ')}${n.post == null ? '' : ' — ${raiTruncate(n.post!.body, 60)}'}'];
          head = appL10n.raiFunctionsHeadNotificationsPage;
        } else if (loc.startsWith(Routes.dm)) {
          final rooms = await _session().dmRooms();
          lines = [for (final r in rooms) if (keep(r.displayTitle)) '${r.displayTitle} [${r.id}]'];
          head = 'DM';
        } else {
          final st = ref.read(timelineProvider(TimelineKind.home)).value;
          final posts = st?.posts ?? (await _session().timeline(TimelineKind.home, limit: 20)).items;
          lines = [for (final p in _shown(posts)) if (keep(p.body)) _line(p)];
          head = appL10n.raiFunctionsHeadHomeTimeline;
        }
        return RaiFunctionResult(name: c.name, text: raiTruncate(raiFoldLines(lines, budget, head: '$head($loc)'), budget), fetched: true, items: items);
      });

  /// tendency.seed(source): 取得元の投稿から特徴語を抜き、トレンドの指向性(好きなジャンル)に足す (D-229)。
  /// source = `feed:<uri>` / `list:<id>` / `tag:<語>` / フィード名(検索して先頭)。
  Future<RaiFunctionResult> _tendencySeed(RaiFunctionCall c) => raiGuard(c.name, () async {
        var source = c.arg('source').trim();
        if (source.isEmpty) return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsMissingSource, ok: false);
        final s = _session();
        String label = source;
        if (!source.startsWith('feed:') && !source.startsWith('list:') && !source.startsWith('tag:')) {
          final f = await _resolveFeed(s, source);
          if (f == null) return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsFeedNotFound(source), ok: false);
          source = 'feed:${f.uri}';
          label = f.name;
        } else if (source.startsWith('feed:')) {
          label = source.substring(5).split('/').last;
        }
        final kind = source.startsWith('feed:') ? TimelineKind(source, label) : _timelineKindOf(source);
        final items = _shown((await s.timeline(kind, limit: 40)).items);
        if (items.isEmpty) return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsSeedNoPosts(label), ok: false);
        final topics = topicsOf(items, top: 4);
        final words = <String>{for (final t in topics) ...t.genres.take(3)}.take(8).toList();
        if (words.isEmpty) return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsSeedNoWords(label), ok: false);
        final profile = await ref.read(tendencyProfileProvider.future);
        final merged = {...profile.genres, ...words}.toList();
        await saveTendencyProfile(ref, profile.copyWith(genres: merged, enabled: true));
        return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsSeedAdded(label, words.join(appL10n.raiFunctionsSeedWordSeparator)));
      });

  /// web.search(q, count): Brave Search (D-228)。第一期では無効(有効化と鍵は [RaiWebSearch] 参照)。
  Future<RaiFunctionResult> _webSearch(RaiFunctionCall c) async {
    final q = c.arg('q', c.arg('query')).trim();
    if (q.isEmpty) return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsMissingQuery, ok: false);
    final ws = ref.read(raiWebSearchProvider);
    try {
      final hits = await ws.query(q, count: int.tryParse(c.arg('count', '5')) ?? 5);
      final lines = [for (final h in hits) '${h.title}${h.description.isEmpty ? '' : ' — ${raiTruncate(h.description, ws.mode == RaiWebMode.answers ? budget : 120)}'}${h.url == null ? '' : ' [${h.url}]'}'];
      return RaiFunctionResult(name: c.name, text: raiTruncate(raiFoldLines(lines, budget, head: appL10n.raiFunctionsHeadWeb(q)), budget), fetched: true);
    } on RaiWebSearchException catch (e) {
      return RaiFunctionResult(name: c.name, text: e.message, ok: false);
    }
  }

  /// app.actions(): この SNS で自動化できる投稿アクション一覧を取る (D-223)。モデルが post.action の
  /// action= を当てられるようにする(費用対効果が高い、報告書 §2-4 参照)。
  Future<RaiFunctionResult> _appActions(RaiFunctionCall c) => raiGuard(c.name, () async {
        final s = _session();
        final lines = [for (final a in s.actions) '${a.id}: ${a.label}${raiCanAutomate(a) ? '' : appL10n.raiFunctionsNotAutomatableMark}'];
        return RaiFunctionResult(name: c.name, text: raiTruncate(raiFoldLines(lines, budget, head: appL10n.raiFunctionsHeadActions), budget), fetched: true);
      });
}
