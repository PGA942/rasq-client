import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';

import '../../backend/rasq_collections_api.dart';
import '../../backend/server_info_api.dart';
import '../collections/rasq_collection_tile.dart';
import '../servers/server_info_tile.dart';
import 'server_signup.dart';
import 'showcase_genres.dart';
import 'showcase_providers.dart';

/// オンボーディングの見本の欄 (D-405 → D-412)。幅の広い画面は左の小カラム、狭い画面は「サーバーを見てみる」のページ。上から
/// - **サーバー** — サーバー情報タイル (D-345) の下に、そのサーバーの**ジャンルの分かる強い公開の投稿**を 3 件まで(Central S-072 +
///   端末のジャンル判定、[serverShowcasePicksProvider])。Central が情報を返したサーバーだけ、横に流す。
/// - **RASQ リスト** — 公開リストの人気順。リストの情報の下に、公開のスナップショットから同じ選び方で 3 件まで。
/// タイルをタップすると、そのサーバーに登録する([startServerSignup]: アプリの中の登録ページ + RAi の案内 → ログイン → タップした投稿へ)。
///
/// D-405 の「おすすめの SNS」(SNS プラグインの投稿タイルの RRL の見本)は、分かりにくかったので外した (D-412)。
class OnboardingPreviewColumn extends StatelessWidget {
  const OnboardingPreviewColumn({super.key});

  /// 並べるサーバー(SNS のログインの既定と同じ)。Bluesky のようにインスタンスの無いものは、タイルが出ない。
  static const serverHosts = ['misskey.io', 'mastodon.social'];

  @override
  Widget build(BuildContext context) {
    return ListView(key: const ValueKey('onboarding.previews'), padding: const EdgeInsets.only(bottom: RasqSpacing.xl), children: const [
      _ServerPreviews(hosts: serverHosts),
      _ListPreviews(),
    ]);
  }
}

/// 狭い画面の入口から開く、見本の欄のページ (D-412)。
class OnboardingShowcaseScreen extends StatelessWidget {
  const OnboardingShowcaseScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18), tooltip: '戻る', onPressed: () => context.pop()),
          title: const Text('サーバーとリストを見てみる'),
          centerTitle: false,
        ),
        body: const SafeArea(child: OnboardingPreviewColumn()),
      );
}

/// タイルの幅と、横に流す欄の高さ。
const _tileWidth = 280.0;
const _rowHeight = 470.0;

/// サーバーのタイルを横に流す。情報の取れたサーバーが無いあいだは何も出さない(読み込み中も、欄を先に出さない)。
class _ServerPreviews extends ConsumerWidget {
  const _ServerPreviews({required this.hosts});
  final List<String> hosts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shown = [for (final h in hosts) if (ref.watch(serverInfoProvider(h)).value != null) h];
    if (shown.isEmpty) return const SizedBox.shrink();
    return Column(key: const ValueKey('onboarding.previews.servers'), crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      const RasqSectionHeader(title: 'サーバー'),
      _hint(context, 'タップすると、そのサーバーに登録できます'),
      SizedBox(
        height: _rowHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
          itemCount: shown.length,
          separatorBuilder: (_, _) => const SizedBox(width: RasqSpacing.sm),
          // タイルの高さはサーバーで違う(バナー / 説明 / 投稿)。入らない分は縦に送れる。
          itemBuilder: (_, i) => SizedBox(width: _tileWidth, child: SingleChildScrollView(child: ServerShowcaseTile(host: shown[i]))),
        ),
      ),
    ]);
  }
}

Widget _hint(BuildContext context, String text) => Padding(
      padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.xs),
      child: Text(text, style: RasqTypography.caption.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );

/// サーバーのタイル (D-412): サーバー情報タイル + その下に見本の投稿。タイル / 投稿のタップ = そのサーバーに登録。
class ServerShowcaseTile extends ConsumerWidget {
  const ServerShowcaseTile({super.key, required this.host});
  final String host;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(serverInfoProvider(host)).value;
    if (info == null) return const SizedBox.shrink();
    final picks = ref.watch(serverShowcasePicksProvider(host)).value ?? const <ShowcasePick>[];
    final target = signupTargetFor(info);
    void signup([Post? post]) {
      final t = signupTargetFor(info, post: post);
      if (t != null) startServerSignup(context, ref, t);
    }

    return Column(key: ValueKey('onboarding.server.$host'), crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      ServerInfoTile(host: host, withRai: false, openLabel: target == null ? 'サーバーを開く' : 'このサーバーに登録', onOpen: target == null ? null : signup),
      for (final p in picks)
        Padding(
          padding: const EdgeInsets.only(top: RasqSpacing.xs),
          child: ShowcasePostCard(pick: p, onTap: target == null ? null : () => signup(p.post)),
        ),
    ]);
  }
}

/// RASQ リストのタイルを横に流す(公開リストが無ければ欄ごと出さない)。
class _ListPreviews extends ConsumerWidget {
  const _ListPreviews();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(onboardingRasqListsProvider).value ?? const <RasqCollection>[];
    if (lists.isEmpty) return const SizedBox.shrink();
    return Column(key: const ValueKey('onboarding.previews.lists'), crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      const RasqSectionHeader(title: 'RASQ リスト'),
      _hint(context, 'SNS をまたいだ人のリストです。タップすると、リストの人がいるサーバーに登録できます'),
      SizedBox(
        height: _rowHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
          itemCount: lists.length,
          separatorBuilder: (_, _) => const SizedBox(width: RasqSpacing.sm),
          itemBuilder: (_, i) => SizedBox(width: _tileWidth, child: SingleChildScrollView(child: RasqListShowcaseTile(collection: lists[i]))),
        ),
      ),
    ]);
  }
}

/// RASQ リストのタイル (D-412): リストの情報 (D-345 の `RasqCollectionTile`) + その下に見本の投稿。
/// タップ = リストの人がいるサーバーに登録(サーバーが複数なら選ぶ)。投稿のタップ = その投稿のサーバーに登録 → ログインしたら投稿へ。
/// リストのタップから登録したときは、ログインしたらリストを開いて取り込む (D-347)。
class RasqListShowcaseTile extends ConsumerWidget {
  const RasqListShowcaseTile({super.key, required this.collection});
  final RasqCollection collection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = collection;
    final picks = ref.watch(rasqListShowcasePicksProvider(c.id)).value ?? const <ShowcasePick>[];
    return Column(key: ValueKey('onboarding.list.${c.id}'), crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      RasqCollectionTile(collection: c, openLabel: '登録する', onOpen: () => signupFromList(context, ref, c)),
      for (final p in picks)
        Padding(
          padding: const EdgeInsets.only(top: RasqSpacing.xs),
          child: ShowcasePostCard(pick: p, onTap: () => _signupForPost(context, ref, p.post)),
        ),
    ]);
  }

  Future<void> _signupForPost(BuildContext context, WidgetRef ref, Post post) async {
    final info = await ref.read(serverInfoProvider(post.author.account.instance).future);
    final t = info == null ? null : signupTargetFor(info, post: post);
    if (!context.mounted) return;
    if (t == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${post.author.account.instance} には、アプリから登録できません')));
      return;
    }
    startServerSignup(context, ref, t);
  }
}

/// RASQ リストから登録: リストの人がいるサーバーのうち、アプリから登録できるもの。1 つならそこ、複数なら選ぶ。
/// 探す画面 (D-414) からも使う(そのときは [nudgeRasqAccount] = false)。
Future<void> signupFromList(BuildContext context, WidgetRef ref, RasqCollection list, {bool nudgeRasqAccount = true}) async {
  final targets = <ServerSignupTarget>[];
  for (final host in list.instances) {
    final info = await ref.read(serverInfoProvider(host).future);
    final t = info == null ? null : signupTargetFor(info, list: list, nudgeRasqAccount: nudgeRasqAccount);
    if (t != null) targets.add(t);
  }
  if (!context.mounted) return;
  if (targets.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('このリストのサーバーには、アプリから登録できません')));
    return;
  }
  final picked = targets.length == 1
      ? targets.single
      : await showModalBottomSheet<ServerSignupTarget>(
          context: context,
          builder: (sheet) => SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(padding: const EdgeInsets.all(RasqSpacing.page), child: Text('どのサーバーに登録しますか?', style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700))),
              for (final t in targets)
                RasqListTile(
                  key: ValueKey('onboarding.list.server.${t.host}'),
                  title: t.displayName,
                  subtitle: '${t.host} ・ ${t.kind.label}',
                  leading: const Icon(Icons.dns_outlined),
                  onTap: () => Navigator.of(sheet).pop(t),
                ),
            ]),
          ),
        );
  if (picked != null && context.mounted) startServerSignup(context, ref, picked);
}

/// 見本の投稿 1 件(小さく: アイコン・名前・ジャンル・本文 4 行まで・反応の数)。画像は読まない(枚数だけ)。
class ShowcasePostCard extends StatelessWidget {
  const ShowcasePostCard({super.key, required this.pick, this.onTap});
  final ShowcasePick pick;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = pick.post;
    final reactions = [...p.counts.entries.where((e) => e.key.contains('reaction') || e.key.contains('like') || e.key.contains('fav')).map((e) => e.value), ...p.reactions.values].fold<int>(0, (a, b) => a + b);
    final renotes = p.counts.entries.where((e) => e.key.contains('renote') || e.key.contains('repost') || e.key.contains('reblog') || e.key.contains('boost')).fold<int>(0, (a, e) => a + e.value);
    final caption = [
      if (reactions > 0) '♡ $reactions',
      if (renotes > 0) '↻ $renotes',
      if (p.media.isNotEmpty) '画像 ${p.media.length} 枚',
    ].join('  ');
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RasqSizes.radiusMd), side: BorderSide(color: scheme.outlineVariant)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('onboarding.post.${p.key}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(RasqSpacing.sm),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              RasqAvatar(imageUrl: p.author.avatarUrl, size: 20, fallbackLabel: p.author.displayName),
              const SizedBox(width: RasqSpacing.xs),
              Expanded(
                child: Text('${showcasePlainText(p.author.displayName)} @${p.author.account.handle}',
                    style: RasqTypography.caption.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: RasqSpacing.xs),
              Container(
                key: ValueKey('onboarding.post.genre.${pick.genre.genre.id}'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: RasqColors.sub.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                child: Text(pick.genre.genre.label, style: RasqTypography.caption.copyWith(color: RasqColors.sub)),
              ),
            ]),
            const SizedBox(height: RasqSpacing.xs),
            Text(showcasePlainText(p.body), style: RasqTypography.bodySmall, maxLines: 4, overflow: TextOverflow.ellipsis),
            if (caption.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(caption, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ]),
        ),
      ),
    );
  }
}

/// 本文を見本用の文字だけに: MFM の関数 `$[x.y 中身]` は中身だけ、`<small>` などのタグと `:絵文字:` の名前は外す。
String showcasePlainText(String s) {
  var t = s;
  for (var i = 0; i < 4; i++) {
    final next = t.replaceAllMapped(RegExp(r'\$\[[\w.=,-]+ ([^\[\]]*)\]'), (m) => m.group(1)!);
    if (next == t) break;
    t = next;
  }
  return t.replaceAll(RegExp(r'</?[a-z]+>'), '').replaceAll(RegExp(r':[A-Za-z_][A-Za-z0-9_+-]*:'), '').replaceAll(RegExp(r'[ \t]+'), ' ').trim();
}

/// `rasq-sdk-sample/examples/post-tile.rrl.json` — WASM の SNS プラグインが出す投稿タイルの snapshot
/// (PROTOCOL.md §3.1)。コンポーネントカタログとオンボーディングの見本 (D-405) で描く。
const postTileSampleRrl = '''
{
  "schema": "rasq.boundary/1",
  "scope": "rasq.official.misskey:misskey:misskey.io:yamada:0.1.0:tl-home",
  "type": "snapshot",
  "rev": 1,
  "root": {
    "t": "PostTile", "k": "post-{{post.id}}", "role": "contentBody",
    "p": { "post": "\$.post", "variant": "normal" },
    "c": [
      { "t": "Avatar", "k": "avatar", "p": { "user": "\$.post.author" }, "on": { "tap": "openUser" } },
      { "t": "Row", "k": "header", "c": [
        { "t": "RichText", "k": "name", "tag": "user_name", "p": { "source": "\$.post.author.displayName" } },
        { "t": "Text", "k": "handle", "tag": "user_handle", "p": { "text": "\$.post.author.handle" } },
        { "t": "Timestamp", "k": "time", "tag": "time", "p": { "time": "\$.post.createdAt" } }
      ]},
      { "t": "If", "k": "cw?", "p": { "cond": "\$.post.contentWarning" }, "c": [
        { "t": "Text", "k": "cw", "tag": "cw", "p": { "text": "\$.post.contentWarning" } }
      ]},
      { "t": "RichText", "k": "body", "tag": "main_text", "p": { "source": "\$.post.bodyRSL" } },
      { "t": "MediaGrid", "k": "media", "p": { "items": "\$.post.media" }, "on": { "tap": "openViewer" } },
      { "t": "If", "k": "poll?", "p": { "cond": "\$.post.poll" }, "c": [
        { "t": "PollWidget", "k": "poll", "tag": "vote", "p": { "poll": "\$.post.poll" }, "on": { "confirm": "vote" } }
      ]},
      { "t": "ActionBar", "k": "actions", "role": "actionBar", "p": { "actions": "\$.actions", "states": "\$.actionStates[post.key]" }, "on": { "tap": "performAction", "longPress": "pickReaction" } }
    ]
  }
}
''';
