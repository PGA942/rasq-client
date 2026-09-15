import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:rrl_core/rrl_core.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../compose/compose_target.dart';
import '../compose/composer_sheet.dart';
import '../settings/settings_dsl.dart';
import '../vc/astell_models.dart';
import '../vc/astell_providers.dart';
import 'rai_reference.dart';
import 'rai_reference_providers.dart';

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

@immutable
class RaiFunctionResult {
  const RaiFunctionResult({required this.name, required this.text, this.fetched = false, this.ok = true});
  final String name;

  /// 注入 / 注記に使う本文。
  final String text;

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
const raiNoAutomationTag = '操作禁止';

/// ホスト(既定)の設定でパスワードが要るキーの印 (D-225): `"p": {"password": true}`。
/// 現状の静的ページには無く、`web.open`(web 版へ逃がす)のタイルは defaults にキーが無いので元から書けない。
const raiPasswordProp = 'password';

/// 設定キーを RAi が書いてよいか (D-225)。ユーザー指定: 既定設定はパスワードの要らない部分、
/// プラグイン設定は操作禁止タグを付けていない部分。判定は spec の RRL ツリーで、そのキー(`k`)を
/// `settings.set` で書くタイルが 1 つ以上あり、かつどのタイルにも [raiPasswordProp] / [raiNoAutomationTag] が
/// 無いこと。理由文は拒否のときだけ。
({bool ok, String reason}) raiSettingsWritable(SettingsPageSpec spec, String key) {
  if (!spec.defaults.containsKey(key)) return (ok: false, reason: '「${spec.area}」に「$key」という設定はありません(ある: ${spec.defaults.keys.join(', ')})');
  final nodes = raiSettingsNodesFor(spec.root, key);
  if (!nodes.any((n) => n.on['change'] == 'settings.set')) return (ok: false, reason: '「$key」は画面から書ける設定ではありません');
  for (final n in nodes) {
    if (n.p[raiPasswordProp] == true) return (ok: false, reason: '「$key」はパスワードが要るので RAi からは書きません');
    final tags = n.p['tags'];
    if (tags is List && tags.contains(raiNoAutomationTag)) return (ok: false, reason: '「$key」は操作禁止タグが付いているので RAi からは書きません');
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
    return switch (v.toLowerCase()) { 'true' || 'on' || 'yes' || '1' || 'オン' || 'はい' => true, 'false' || 'off' || 'no' || '0' || 'オフ' || 'いいえ' => false, _ => null };
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
  if (lines.isEmpty) return '$head: 該当なし';
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
  return '$head ${lines.length} 件中 ${out.length} 件:\n${out.join('\n')}';
}

/// 非対応の日本語化ガード (D-223): Dart 実装の非対応は [UnsupportedError]、wasm 側は
/// [SnsApiException] の C01(プラグイン間受け渡し・未実装)で来る。どちらも同じ短い文にする。
/// ログインしていない (`StateError`) もここで拾う。ほかの例外は [RaiFunctionRunner.run] の外側の
/// catch へ委ねる。
Future<RaiFunctionResult> raiGuard(String name, Future<RaiFunctionResult> Function() body) async {
  try {
    return await body();
  } on UnsupportedError {
    return RaiFunctionResult(name: name, text: 'この SNS では使えません($name)', ok: false);
  } on SnsApiException catch (e) {
    if (e.code.code != 'C01') rethrow;
    return RaiFunctionResult(name: name, text: 'この SNS では使えません($name)', ok: false);
  } on StateError catch (e) {
    return RaiFunctionResult(name: name, text: e.message, ok: false);
  }
}

/// 関数の一覧(system に出す 1 行ずつ)。呼べる範囲は関連する関数をまとめて 1 行にし、system の
/// 肥大化(D-220 の 2500 文字上限)を抑える。
const raiFunctionUsage = <String>[
  'posts.fetch(kind=home|search, keyword=語, sort=new|reactions, limit=数): 投稿本文を取る',
  'reference.get(id=操作か関数の id): リファレンスの詳細を取る',
  'post.create(text=本文): 投稿する。post.compose(text)・post.reply(post, text)・post.quote(post, text)・dm.compose(room, text): 送らずにコンポーザーへ下書きを入れる(送信はユーザー)',
  'post.action(action=アクション id, post=投稿 id): 投稿にアクション(自動化が許可されたものだけ)',
  'astell.rooms(): AsTell のルーム一覧を取る',
  'astell.create(title=題名): AsTell のルームを作る',
  'timeline.list(kind=home|social|local|global|featured|tag:語|list:id, limit)・post.get(id)・post.thread(post, limit): TL や投稿の本文を取る',
  'post.reactions(post, limit)・post.reposters(post, limit)・post.quotes(post, limit): 投稿への反応を取る',
  'favorites.list(limit)・reacted.list(limit): お気に入り/リアクション済みの投稿を取る',
  'me.get()・user.get(id=|handle=@名前)・user.posts(user, filter=posts|replies|media|quotes, limit)・user.search(keyword, limit)・user.follows(user, direction=followers|following, limit)・user.relation(user): ユーザーの情報を取る',
  'moderation.list(kind=muted|blocked|requests): ミュート/ブロック/フォロー申請の一覧を取る',
  'notifications.list(kind=all|reaction|reply|follow|mention, limit)・notifications.read(): 通知を取る/既読にする',
  'trends.tags(limit): トレンドのタグを取る',
  'lists.list()・lists.members(list): リストとメンバーを取る',
  'clips.list(user=)・clips.notes(clip, limit): クリップを取る(Misskey のみ)',
  'feeds.list(keyword=): カスタムフィードを取る(Bluesky のみ、keyword 無しは保存済み)',
  'dm.rooms(): DM ルーム一覧を取る',
  'emoji.find(keyword, limit): keyword を含むカスタム絵文字を探す',
  'follow.set(user, on=true|false): フォローする/外す',
  'list.edit(list, user, add=true|false)・list.create(name): リストにユーザーを足す/外す・作る',
  'clip.edit(clip, post, add=true|false)・clip.create(name): クリップに投稿を足す/外す・作る(Misskey のみ)',
  'settings.get(area, key)・settings.set(area, key, value): 設定を読む/書く(設定ページのキーのみ。書けるのはパスワード不要で操作禁止タグの無いもの)',
  'app.actions(): この SNS で自動化できる投稿アクション一覧を取る',
];

class RaiFunctionRunner {
  RaiFunctionRunner(this.ref, {this.contextTokens = 2048});
  final Ref ref;
  final int contextTokens;

  int get budget => raiInjectionBudgetChars(contextTokens);

  Future<RaiFunctionResult> run(RaiFunctionCall c) async {
    try {
      switch (c.name) {
        case 'posts.fetch':
          return await _postsFetch(c);
        case 'reference.get':
          return await _referenceGet(c);
        case 'post.create':
          return await _postCreate(c);
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
        case 'post.compose':
        case 'post.reply':
        case 'post.quote':
        case 'dm.compose':
          return await _composeFill(c);
        case 'app.actions':
          return await _appActions(c);
      }
      return RaiFunctionResult(name: c.name, text: '知らない関数です: ${c.name}', ok: false);
    } catch (e) {
      return RaiFunctionResult(name: c.name, text: '${c.name} に失敗: $e', ok: false);
    }
  }

  SnsSession _session() {
    final s = ref.read(currentSnsSessionProvider);
    if (s == null) throw StateError('SNS にログインしていません');
    return s;
  }

  static String _line(Post p) {
    final body = p.body.replaceAll(RegExp(r'\s+'), ' ').trim();
    final n = p.reactions.values.fold(0, (a, b) => a + b);
    return '@${p.author.account.handle}: $body${n > 0 ? '(反応 $n)' : ''} [${p.id}]';
  }

  /// ソート / 絞り込み (D-221): kind=home(既定)| search(keyword で検索)、keyword で本文を絞る、
  /// sort=new(既定)| reactions、limit(既定 5)。KV の 4% ぶんで打ち切る。
  Future<RaiFunctionResult> _postsFetch(RaiFunctionCall c) async {
    final s = _session();
    final keyword = c.arg('keyword').trim();
    final limit = int.tryParse(c.arg('limit', '5')) ?? 5;
    final kind = c.arg('kind', 'home');
    final page = kind == 'search' && keyword.isNotEmpty ? await s.searchPosts(keyword, limit: 30) : await s.timeline(TimelineKind.home, limit: 30);
    var posts = [for (final p in page.items) if (keyword.isEmpty || p.body.contains(keyword) || p.author.displayName.contains(keyword)) p];
    if (c.arg('sort') == 'reactions') {
      posts.sort((a, b) => b.reactions.values.fold(0, (x, y) => x + y).compareTo(a.reactions.values.fold(0, (x, y) => x + y)));
    }
    posts = posts.take(limit.clamp(1, 20)).toList();
    if (posts.isEmpty) return RaiFunctionResult(name: c.name, text: '該当する投稿はありませんでした', fetched: true);
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
    return RaiFunctionResult(name: c.name, text: '投稿 ${lines.length} 件(${posts.length} 件中):\n${lines.join('\n')}', fetched: true);
  }

  Future<RaiFunctionResult> _referenceGet(RaiFunctionCall c) async {
    final id = c.arg('id').trim();
    final RaiReferenceIndex index = ref.read(raiReferenceProvider).value ?? await ref.read(raiReferenceProvider.future);
    final op = index.operation(id);
    if (op != null) {
      final steps = index.expand(op);
      return RaiFunctionResult(name: c.name, text: raiTruncate('操作「${op.index}」(${op.id}): ${[for (final (i, s) in steps.indexed) '${i + 1}. ${s.text}'].join(' / ')}', budget), fetched: true);
    }
    final fn = index.function(id);
    if (fn != null) {
      return RaiFunctionResult(name: c.name, text: raiTruncate('関数 ${fn.id}: ${fn.does}${fn.params.isEmpty ? '' : ' 引数: ${fn.params.map((p) => '${p.label}(${p.isInput ? '入力' : '固定=${p.value}'})').join(', ')}'}', budget), fetched: true);
    }
    return RaiFunctionResult(name: c.name, text: 'リファレンスに $id はありません', fetched: true, ok: false);
  }

  Future<RaiFunctionResult> _postCreate(RaiFunctionCall c) async {
    final text = c.arg('text').trim();
    if (text.isEmpty) return RaiFunctionResult(name: c.name, text: '本文がありません', ok: false);
    final p = await _session().createPost(NewPost(text: text));
    return RaiFunctionResult(name: c.name, text: '投稿しました [${p.id}]');
  }

  Future<RaiFunctionResult> _postAction(RaiFunctionCall c) async {
    final s = _session();
    final actionId = c.arg('action').trim();
    final postId = c.arg('post').trim();
    final a = s.actions.where((x) => x.id == actionId).firstOrNull;
    if (a == null) return RaiFunctionResult(name: c.name, text: 'アクション $actionId はありません', ok: false);
    if (!raiCanAutomate(a)) return RaiFunctionResult(name: c.name, text: '「${a.label}」は自動化が許可されていません(RAi からは実行しません)', ok: false);
    final r = await s.performAction(actionId, postId);
    return RaiFunctionResult(name: c.name, text: '${a.label} を実行しました(${r.done ? '済' : '未'})');
  }

  Future<RaiFunctionResult> _astellRooms() async {
    final home = await ref.read(astellClientProvider).home();
    final rooms = [...home.following, ...home.recommended, ...home.trending];
    if (rooms.isEmpty) return const RaiFunctionResult(name: 'astell.rooms', text: 'AsTell のルームはありません', fetched: true);
    final seen = <String>{};
    final lines = [for (final r in rooms) if (seen.add(r.id)) '${r.title} [${r.id}]'];
    return RaiFunctionResult(name: 'astell.rooms', text: raiTruncate('AsTell のルーム: ${lines.join(' / ')}', budget), fetched: true);
  }

  Future<RaiFunctionResult> _astellCreate(RaiFunctionCall c) async {
    final title = c.arg('title').trim();
    if (title.isEmpty) return RaiFunctionResult(name: c.name, text: '題名がありません', ok: false);
    final room = await ref.read(astellClientProvider).createRoom(NewAstellRoom(title: title));
    return RaiFunctionResult(name: c.name, text: 'AsTell「${room.title}」を作りました [${room.id}]');
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
      NotificationKind.reaction => '$who がリアクション${n.reaction == null ? '' : '(${n.reaction})'}',
      NotificationKind.repost => '$who がリノート',
      NotificationKind.quote => '$who が引用',
      NotificationKind.reply => '$who が返信',
      NotificationKind.mention => '$who がメンション',
      NotificationKind.follow => '$who がフォロー',
      NotificationKind.followRequest => '$who がフォロー申請',
      NotificationKind.followAccepted => '$who がフォロー承認',
      NotificationKind.listAdded => '$who がリストに追加',
      NotificationKind.pollEnded => 'アンケート終了',
      NotificationKind.timer => 'タイマー通知',
      NotificationKind.vc => 'AsTell 通知',
      NotificationKind.system => n.title ?? 'システム通知',
      NotificationKind.other => 'その他の通知',
    };
    return '$what${n.read ? '' : '(未読)'} [${n.id}]';
  }

  /// timeline.list(kind, limit): TL を取る (D-223)。
  Future<RaiFunctionResult> _timelineList(RaiFunctionCall c) => raiGuard(c.name, () async {
        final kindArg = c.arg('kind', 'home').trim();
        final limit = _limitOf(c);
        final page = await _session().timeline(_timelineKindOf(kindArg), limit: limit);
        final lines = [for (final p in page.items.take(limit)) _line(p)];
        return RaiFunctionResult(name: c.name, text: raiTruncate(raiFoldLines(lines, budget, head: 'TL($kindArg)'), budget), fetched: true);
      });

  /// post.get(id): 投稿 1 件の本文を取る (D-223)。
  Future<RaiFunctionResult> _postGet(RaiFunctionCall c) => raiGuard(c.name, () async {
        final id = c.arg('id').trim();
        if (id.isEmpty) return RaiFunctionResult(name: c.name, text: '投稿 id (id=) がありません', ok: false);
        final p = await _session().post(id);
        return RaiFunctionResult(name: c.name, text: raiTruncate(_line(p), budget), fetched: true);
      });

  /// post.thread(post, limit): 投稿とその返信を取る (D-223)。
  Future<RaiFunctionResult> _postThread(RaiFunctionCall c) => raiGuard(c.name, () async {
        final id = c.arg('post').trim();
        if (id.isEmpty) return RaiFunctionResult(name: c.name, text: '投稿 id (post=) がありません', ok: false);
        final limit = _limitOf(c);
        final t = await _session().thread(id);
        final lines = [_line(t.post), for (final p in t.descendants.take(limit)) '返信: ${_line(p)}'];
        return RaiFunctionResult(name: c.name, text: raiTruncate(raiFoldLines(lines, budget, head: 'スレッド'), budget), fetched: true);
      });

  /// post.reactions(post, limit): 誰がどう反応したかを絵文字ごとに集計する (D-223)。
  Future<RaiFunctionResult> _postReactions(RaiFunctionCall c) => raiGuard(c.name, () async {
        final id = c.arg('post').trim();
        if (id.isEmpty) return RaiFunctionResult(name: c.name, text: '投稿 id (post=) がありません', ok: false);
        final page = await _session().reactions(id, limit: _limitOf(c, fallback: 30, max: 100));
        final byReaction = <String, int>{};
        for (final r in page.items) {
          byReaction[r.reaction] = (byReaction[r.reaction] ?? 0) + 1;
        }
        final lines = [for (final e in byReaction.entries) '${e.key} × ${e.value}'];
        return RaiFunctionResult(name: c.name, text: raiTruncate(raiFoldLines(lines, budget, head: '反応'), budget), fetched: true);
      });

  /// post.reposters(post, limit): リノートした人を取る (D-223)。
  Future<RaiFunctionResult> _postReposters(RaiFunctionCall c) => raiGuard(c.name, () async {
        final id = c.arg('post').trim();
        if (id.isEmpty) return RaiFunctionResult(name: c.name, text: '投稿 id (post=) がありません', ok: false);
        final page = await _session().reposters(id, limit: _limitOf(c));
        final lines = [for (final u in page.items) _userLine(u)];
        return RaiFunctionResult(name: c.name, text: raiTruncate(raiFoldLines(lines, budget, head: 'リノートした人'), budget), fetched: true);
      });

  /// post.quotes(post, limit): 引用した投稿を取る (D-223)。
  Future<RaiFunctionResult> _postQuotes(RaiFunctionCall c) => raiGuard(c.name, () async {
        final id = c.arg('post').trim();
        if (id.isEmpty) return RaiFunctionResult(name: c.name, text: '投稿 id (post=) がありません', ok: false);
        final page = await _session().quotes(id, limit: _limitOf(c));
        final lines = [for (final p in page.items) _line(p)];
        return RaiFunctionResult(name: c.name, text: raiTruncate(raiFoldLines(lines, budget, head: '引用'), budget), fetched: true);
      });

  /// favorites.list(limit): ブックマーク/お気に入りを取る (D-223)。
  Future<RaiFunctionResult> _favoritesList(RaiFunctionCall c) => raiGuard(c.name, () async {
        final page = await _session().favorites(limit: _limitOf(c));
        final lines = [for (final p in page.items) _line(p)];
        return RaiFunctionResult(name: c.name, text: raiTruncate(raiFoldLines(lines, budget, head: 'お気に入り'), budget), fetched: true);
      });

  /// reacted.list(limit): 自分がリアクションした投稿を取る (D-223)。
  Future<RaiFunctionResult> _reactedList(RaiFunctionCall c) => raiGuard(c.name, () async {
        final page = await _session().reactedPosts(limit: _limitOf(c));
        final lines = [for (final p in page.items) _line(p)];
        return RaiFunctionResult(name: c.name, text: raiTruncate(raiFoldLines(lines, budget, head: 'リアクション済み'), budget), fetched: true);
      });

  /// me.get(): 今のアカウントを取る (D-223)。
  Future<RaiFunctionResult> _meGet(RaiFunctionCall c) => raiGuard(c.name, () async {
        final s = _session();
        final me = await s.me();
        return RaiFunctionResult(name: c.name, text: raiTruncate('自分: ${_userLine(me)} プラグイン=${s.pluginId}', budget), fetched: true);
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
          return RaiFunctionResult(name: c.name, text: 'id= か handle= を指定してください', ok: false);
        }
        if (profile == null) return RaiFunctionResult(name: c.name, text: '見つかりませんでした', ok: false, fetched: true);
        final u = profile.summary;
        final text = '${_userLine(u)}${profile.description == null || profile.description!.isEmpty ? '' : ' — ${profile.description}'}'
            ' フォロワー${profile.followersCount ?? '?'} フォロー${profile.followingCount ?? '?'}';
        return RaiFunctionResult(name: c.name, text: raiTruncate(text, budget), fetched: true);
      });

  /// user.posts(user, filter, limit): ユーザーの投稿を取る (D-223)。
  Future<RaiFunctionResult> _userPosts(RaiFunctionCall c) => raiGuard(c.name, () async {
        final id = c.arg('user').trim();
        if (id.isEmpty) return RaiFunctionResult(name: c.name, text: 'user id (user=) がありません', ok: false);
        final filterArg = c.arg('filter', 'posts');
        UserPostsFilter filter;
        try {
          filter = UserPostsFilter.values.byName(filterArg);
        } catch (_) {
          filter = UserPostsFilter.posts;
        }
        final page = await _session().userPosts(id, limit: _limitOf(c), filter: filter);
        final lines = [for (final p in page.items) _line(p)];
        return RaiFunctionResult(name: c.name, text: raiTruncate(raiFoldLines(lines, budget, head: '投稿($filterArg)'), budget), fetched: true);
      });

  /// user.search(keyword, limit): ユーザーを検索する (D-223)。
  Future<RaiFunctionResult> _userSearch(RaiFunctionCall c) => raiGuard(c.name, () async {
        final keyword = c.arg('keyword').trim();
        if (keyword.isEmpty) return RaiFunctionResult(name: c.name, text: 'keyword がありません', ok: false);
        final page = await _session().searchUsers(keyword, limit: _limitOf(c));
        final lines = [for (final u in page.items) _userLine(u)];
        return RaiFunctionResult(name: c.name, text: raiTruncate(raiFoldLines(lines, budget, head: 'ユーザー検索「$keyword」'), budget), fetched: true);
      });

  /// user.follows(user, direction, limit): フォロワー/フォロー中を取る (D-223)。
  Future<RaiFunctionResult> _userFollows(RaiFunctionCall c) => raiGuard(c.name, () async {
        final id = c.arg('user').trim();
        if (id.isEmpty) return RaiFunctionResult(name: c.name, text: 'user id (user=) がありません', ok: false);
        final dir = c.arg('direction', 'followers');
        final s = _session();
        final page = dir == 'following' ? await s.following(id, limit: _limitOf(c)) : await s.followers(id, limit: _limitOf(c));
        final lines = [for (final u in page.items) _userLine(u)];
        return RaiFunctionResult(name: c.name, text: raiTruncate(raiFoldLines(lines, budget, head: dir == 'following' ? 'フォロー中' : 'フォロワー'), budget), fetched: true);
      });

  /// user.relation(user): 自分との関係を取る (D-223)。
  Future<RaiFunctionResult> _userRelation(RaiFunctionCall c) => raiGuard(c.name, () async {
        final id = c.arg('user').trim();
        if (id.isEmpty) return RaiFunctionResult(name: c.name, text: 'user id (user=) がありません', ok: false);
        final r = await _session().relationship(id);
        final flags = [
          if (r.following) 'フォロー中',
          if (r.followedBy) 'フォローされています',
          if (r.requested) '申請中',
          if (r.muted) 'ミュート中',
          if (r.blocked) 'ブロック中',
          if (r.blockedBy) 'ブロックされています',
        ];
        return RaiFunctionResult(name: c.name, text: raiTruncate('関係: ${flags.isEmpty ? 'なし' : flags.join(' / ')}', budget), fetched: true);
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
            lines = [for (final r in await s.followRequests()) '${_userLine(r.user)} [申請 ${r.id}]'];
        }
        return RaiFunctionResult(name: c.name, text: raiTruncate(raiFoldLines(lines, budget, head: 'モデレーション($kind)'), budget), fetched: true);
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
        return RaiFunctionResult(name: c.name, text: raiTruncate(raiFoldLines(lines, budget, head: '通知(未読 $unread 件)'), budget), fetched: true);
      });

  /// notifications.read(): 通知をまとめて既読にする (D-223)。
  Future<RaiFunctionResult> _notificationsRead(RaiFunctionCall c) => raiGuard(c.name, () async {
        await _session().markNotificationsRead();
        return RaiFunctionResult(name: c.name, text: '通知を既読にしました');
      });

  /// trends.tags(limit): トレンドのタグを取る (D-223)。
  Future<RaiFunctionResult> _trendsTags(RaiFunctionCall c) => raiGuard(c.name, () async {
        final tags = await _session().trendingTags();
        final lines = [for (final t in tags.take(_limitOf(c))) '#${t.tag}(${t.usersCount ?? 0} 人)'];
        return RaiFunctionResult(name: c.name, text: raiTruncate(raiFoldLines(lines, budget, head: 'トレンド'), budget), fetched: true);
      });

  /// lists.list(): リスト一覧を取る (D-223)。
  Future<RaiFunctionResult> _listsList(RaiFunctionCall c) => raiGuard(c.name, () async {
        final lists = await _session().lists();
        final lines = [for (final l in lists) '${l.name} [${l.id}](${l.memberIds.length} 人)'];
        return RaiFunctionResult(name: c.name, text: raiTruncate(raiFoldLines(lines, budget, head: 'リスト'), budget), fetched: true);
      });

  /// lists.members(list): リストのメンバーを取る (D-223)。
  Future<RaiFunctionResult> _listsMembers(RaiFunctionCall c) => raiGuard(c.name, () async {
        final id = c.arg('list').trim();
        if (id.isEmpty) return RaiFunctionResult(name: c.name, text: 'list id (list=) がありません', ok: false);
        final members = await _session().listMembers(id);
        final lines = [for (final u in members) _userLine(u)];
        return RaiFunctionResult(name: c.name, text: raiTruncate(raiFoldLines(lines, budget, head: 'リストのメンバー'), budget), fetched: true);
      });

  /// clips.list(user=): クリップ一覧を取る (D-223、Misskey のみ)。
  Future<RaiFunctionResult> _clipsList(RaiFunctionCall c) => raiGuard(c.name, () async {
        final userId = c.arg('user').trim();
        final clips = await _session().clips(userId: userId.isEmpty ? null : userId);
        final lines = [for (final cl in clips) '${cl.name} [${cl.id}]${cl.notesCount == null ? '' : '(${cl.notesCount} 件)'}'];
        return RaiFunctionResult(name: c.name, text: raiTruncate(raiFoldLines(lines, budget, head: 'クリップ'), budget), fetched: true);
      });

  /// clips.notes(clip, limit): クリップの中身を取る (D-223、Misskey のみ)。
  Future<RaiFunctionResult> _clipsNotes(RaiFunctionCall c) => raiGuard(c.name, () async {
        final id = c.arg('clip').trim();
        if (id.isEmpty) return RaiFunctionResult(name: c.name, text: 'clip id (clip=) がありません', ok: false);
        final page = await _session().clipNotes(id, limit: _limitOf(c));
        final lines = [for (final p in page.items) _line(p)];
        return RaiFunctionResult(name: c.name, text: raiTruncate(raiFoldLines(lines, budget, head: 'クリップの中身'), budget), fetched: true);
      });

  /// feeds.list(keyword=): カスタムフィードを取る (D-223、Bluesky のみ)。keyword 無しは保存済み。
  Future<RaiFunctionResult> _feedsList(RaiFunctionCall c) => raiGuard(c.name, () async {
        final keyword = c.arg('keyword').trim();
        final s = _session();
        final feeds = keyword.isEmpty ? await s.savedFeeds() : await s.searchFeeds(keyword, limit: _limitOf(c));
        final lines = [for (final f in feeds) '${f.name}${f.description == null || f.description!.isEmpty ? '' : ' — ${f.description}'}'];
        return RaiFunctionResult(name: c.name, text: raiTruncate(raiFoldLines(lines, budget, head: 'フィード'), budget), fetched: true);
      });

  /// dm.rooms(): DM ルーム一覧を取る (D-223)。
  Future<RaiFunctionResult> _dmRooms(RaiFunctionCall c) => raiGuard(c.name, () async {
        final rooms = await _session().dmRooms();
        final lines = [for (final r in rooms) '${r.displayTitle}${r.unreadCount > 0 ? '(未読 ${r.unreadCount})' : ''} [${r.id}]'];
        return RaiFunctionResult(name: c.name, text: raiTruncate(raiFoldLines(lines, budget, head: 'DM'), budget), fetched: true);
      });

  /// emoji.find(keyword, limit): keyword を含むカスタム絵文字を探す (D-223)。
  Future<RaiFunctionResult> _emojiFind(RaiFunctionCall c) => raiGuard(c.name, () async {
        final keyword = c.arg('keyword').trim();
        if (keyword.isEmpty) return RaiFunctionResult(name: c.name, text: 'keyword がありません', ok: false);
        final all = await _session().customEmojis();
        final matched = [for (final e in all) if (e.name.contains(keyword) || e.aliases.any((a) => a.contains(keyword))) e];
        final lines = [for (final e in matched.take(_limitOf(c))) ':${e.name}:'];
        return RaiFunctionResult(name: c.name, text: raiTruncate(raiFoldLines(lines, budget, head: '絵文字「$keyword」'), budget), fetched: true);
      });

  /// follow.set(user, on=true|false): フォローする/外す (D-223、実行系)。
  Future<RaiFunctionResult> _followSet(RaiFunctionCall c) => raiGuard(c.name, () async {
        final id = c.arg('user').trim();
        if (id.isEmpty) return RaiFunctionResult(name: c.name, text: 'user id (user=) がありません', ok: false);
        final on = c.arg('on', 'true') != 'false';
        final r = await _session().setFollowing(id, on);
        final text = !on
            ? 'フォローを外しました'
            : r.requested
                ? 'フォロー申請しました'
                : 'フォローしました';
        return RaiFunctionResult(name: c.name, text: text);
      });

  /// list.edit(list, user, add=true|false): リストにユーザーを足す/外す (D-223、実行系)。
  Future<RaiFunctionResult> _listEdit(RaiFunctionCall c) => raiGuard(c.name, () async {
        final listId = c.arg('list').trim();
        final userId = c.arg('user').trim();
        if (listId.isEmpty || userId.isEmpty) return RaiFunctionResult(name: c.name, text: 'list= と user= を指定してください', ok: false);
        final add = c.arg('add', 'true') != 'false';
        final s = _session();
        if (add) {
          await s.addToList(listId, userId);
        } else {
          await s.removeFromList(listId, userId);
        }
        return RaiFunctionResult(name: c.name, text: add ? 'リストに追加しました' : 'リストから外しました');
      });

  /// list.create(name): リストを作る (D-223、実行系)。
  Future<RaiFunctionResult> _listCreate(RaiFunctionCall c) => raiGuard(c.name, () async {
        final name = c.arg('name').trim();
        if (name.isEmpty) return RaiFunctionResult(name: c.name, text: '名前 (name=) がありません', ok: false);
        final l = await _session().createList(name);
        return RaiFunctionResult(name: c.name, text: 'リスト「${l.name}」を作りました [${l.id}]');
      });

  /// clip.edit(clip, post, add=true|false): クリップに投稿を足す/外す (D-223、Misskey のみ、実行系)。
  Future<RaiFunctionResult> _clipEdit(RaiFunctionCall c) => raiGuard(c.name, () async {
        final clipId = c.arg('clip').trim();
        final postId = c.arg('post').trim();
        if (clipId.isEmpty || postId.isEmpty) return RaiFunctionResult(name: c.name, text: 'clip= と post= を指定してください', ok: false);
        final add = c.arg('add', 'true') != 'false';
        final s = _session();
        if (add) {
          await s.addToClip(clipId, postId);
        } else {
          await s.removeFromClip(clipId, postId);
        }
        return RaiFunctionResult(name: c.name, text: add ? 'クリップに追加しました' : 'クリップから外しました');
      });

  /// clip.create(name): クリップを作る (D-223、Misskey のみ、実行系)。
  Future<RaiFunctionResult> _clipCreate(RaiFunctionCall c) => raiGuard(c.name, () async {
        final name = c.arg('name').trim();
        if (name.isEmpty) return RaiFunctionResult(name: c.name, text: '名前 (name=) がありません', ok: false);
        final cl = await _session().createClip(name);
        return RaiFunctionResult(name: c.name, text: 'クリップ「${cl.name}」を作りました [${cl.id}]');
      });

  /// settings.get(area, key): アプリの設定値を読む (D-223、読み取り専用)。ホストの静的ページ
  /// (`appearance.*`) と SNS プラグインのページ(`sns.<短area>`)の両方に対応し、
  /// [settingsPageSpecProvider] の spec に無い area/key は拒否する(勝手に読める設定を増やさない)。
  Future<RaiFunctionResult> _settingsGet(RaiFunctionCall c) async {
    final area = c.arg('area').trim();
    final key = c.arg('key').trim();
    if (area.isEmpty || key.isEmpty) return RaiFunctionResult(name: c.name, text: 'area= と key= を指定してください', ok: false);
    final SettingsPageSpec spec;
    try {
      spec = await ref.read(settingsPageSpecProvider(area).future);
    } catch (e) {
      return RaiFunctionResult(name: c.name, text: '設定ページ「$area」はありません', ok: false);
    }
    if (!spec.defaults.containsKey(key)) {
      return RaiFunctionResult(name: c.name, text: '「$area」に「$key」という設定はありません(ある: ${spec.defaults.keys.join(', ')})', ok: false);
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
    if (area.isEmpty || key.isEmpty || raw.trim().isEmpty) return RaiFunctionResult(name: c.name, text: 'area= と key= と value= を指定してください', ok: false);
    final SettingsPageSpec spec;
    try {
      spec = await ref.read(settingsPageSpecProvider(area).future);
    } catch (e) {
      return RaiFunctionResult(name: c.name, text: '設定ページ「$area」はありません', ok: false);
    }
    final gate = raiSettingsWritable(spec, key);
    if (!gate.ok) return RaiFunctionResult(name: c.name, text: gate.reason, ok: false);
    final value = raiCoerceSettingValue(spec, key, raw);
    if (value == null) return RaiFunctionResult(name: c.name, text: '「$key」に「${raw.trim()}」は入れられません(今の値: ${spec.defaults[key]})', ok: false);
    if (spec.isRemote) {
      await ref.read(remoteSettingsProvider(spec.area).notifier).set(key, value);
    } else {
      await ref.read(settingsAreaProvider(area).notifier).set(key, value);
    }
    return RaiFunctionResult(name: c.name, text: '$area.$key を $value にしました');
  }

  /// post.compose(text) / post.reply(post, text) / post.quote(post, text) / dm.compose(room, text):
  /// 送信 / 返信系は自動化不可 (D-225、ユーザー指定)。代わりに**コンポーザーを開いて本文を入れる**だけにし、
  /// 送るかどうかはユーザーが決める。開いたコンポーザーは待たない(閉じるまで答えが止まらないように)。
  Future<RaiFunctionResult> _composeFill(RaiFunctionCall c) => raiGuard(c.name, () async {
        final text = c.arg('text').trim();
        if (text.isEmpty) return RaiFunctionResult(name: c.name, text: '本文(text=)がありません', ok: false);
        final s = _session();
        final ComposeTarget target;
        switch (c.name) {
          case 'post.reply':
          case 'post.quote':
            final id = c.arg('post').trim();
            if (id.isEmpty) return RaiFunctionResult(name: c.name, text: '投稿 id (post=) がありません', ok: false);
            final p = await s.post(id);
            target = c.name == 'post.reply' ? ComposeReply(p) : ComposeQuote(p);
          case 'dm.compose':
            final id = c.arg('room').trim();
            if (id.isEmpty) return RaiFunctionResult(name: c.name, text: 'ルーム id (room=) がありません', ok: false);
            final room = (await s.dmRooms()).where((r) => r.id == id).firstOrNull;
            if (room == null) return RaiFunctionResult(name: c.name, text: 'DM ルーム $id はありません', ok: false);
            target = ComposeDm(room);
          default:
            target = const ComposeNormal();
        }
        unawaited(showComposerWith(target, manager: ref.read(overlayManagerProvider), router: ref.read(routerProvider), initialText: text));
        return RaiFunctionResult(name: c.name, text: '${target.title}の下書きをコンポーザーに入れました(送信はしていません)');
      });

  /// app.actions(): この SNS で自動化できる投稿アクション一覧を取る (D-223)。モデルが post.action の
  /// action= を当てられるようにする(費用対効果が高い、報告書 §2-4 参照)。
  Future<RaiFunctionResult> _appActions(RaiFunctionCall c) => raiGuard(c.name, () async {
        final s = _session();
        final lines = [for (final a in s.actions) '${a.id}: ${a.label}${raiCanAutomate(a) ? '' : '(自動化不可)'}'];
        return RaiFunctionResult(name: c.name, text: raiTruncate(raiFoldLines(lines, budget, head: 'アクション'), budget), fetched: true);
      });
}
