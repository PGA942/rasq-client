import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/providers.dart';
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

/// 関数の一覧(system に出す 1 行ずつ)。
const raiFunctionUsage = <String>[
  'posts.fetch(kind=home|search, keyword=語, sort=new|reactions, limit=数): 投稿本文を取る',
  'reference.get(id=操作か関数の id): リファレンスの詳細を取る',
  'post.create(text=本文): 投稿する',
  'post.action(action=アクション id, post=投稿 id): 投稿にアクション(自動化が許可されたものだけ)',
  'astell.rooms(): AsTell のルーム一覧を取る',
  'astell.create(title=題名): AsTell のルームを作る',
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
}
