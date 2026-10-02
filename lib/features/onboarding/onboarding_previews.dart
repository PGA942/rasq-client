import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rrl_core/rrl_core.dart';
import 'package:rrl_renderer/rrl_renderer.dart';

import '../../backend/server_info_api.dart';
import '../../text/inline_spans.dart';
import '../servers/server_info_tile.dart';

/// オンボーディングの左の小カラム (D-405): 幅の広い画面(≥840dp)だけ。上から
/// - **おすすめの SNS** — SNS プラグインが出す投稿タイルの RRL(SDK のサンプル `post-tile.rrl.json`)を、SNS ごとの見本の
///   投稿で描いた角丸のカード。横に流す。見本なので押しても何も起きない(画像も読まない)。
/// - **サーバー** — サーバー情報タイル (D-345) を横に流す。Central が情報を返したサーバーだけ。1 つも無ければ(接続先が
///   未設定 / インスタンスでない / 取れない)欄ごと出さない。
class OnboardingPreviewColumn extends StatelessWidget {
  const OnboardingPreviewColumn({super.key});

  /// 並べるサーバー(SNS のログインの既定と同じ)。Bluesky のようにインスタンスの無いものは、タイルが出ない。
  static const serverHosts = ['misskey.io', 'mastodon.social'];

  @override
  Widget build(BuildContext context) {
    return ListView(key: const ValueKey('onboarding.previews'), padding: const EdgeInsets.only(bottom: RasqSpacing.xl), children: [
      const RasqSectionHeader(title: 'おすすめの SNS'),
      SizedBox(
        height: 212,
        child: ListView.separated(
          key: const ValueKey('onboarding.previews.sns'),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
          itemCount: snsPreviewSamples.length,
          separatorBuilder: (_, _) => const SizedBox(width: RasqSpacing.sm),
          itemBuilder: (_, i) => _SnsPreviewCard(sample: snsPreviewSamples[i]),
        ),
      ),
      const _ServerPreviews(hosts: serverHosts),
    ]);
  }
}

/// おすすめの SNS の見本 1 つ。
class SnsPreviewSample {
  const SnsPreviewSample({required this.kind, required this.instance, required this.displayName, required this.handle, required this.body, required this.actions});
  final SnsKind kind;
  final String instance;
  final String displayName;
  final String handle;

  /// 本文(MFM / RSL の書き方がそのまま使える。ずっと動く装飾(`$[tada …]` など)は使わない)。
  final String body;

  /// アクションバーの見本: (id, ラベル, アイコン名)。SNS ごとの呼び名に合わせる。
  final List<(String, String, String)> actions;
}

const snsPreviewSamples = [
  SnsPreviewSample(
    kind: SnsKind.misskey,
    instance: 'misskey.io',
    displayName: '投稿の見本',
    handle: 'sample',
    body: '絵文字のリアクションと MFM で、にぎやかに話せる分散型の SNS です。',
    actions: [('reply', '返信', 'subdirectory_arrow_left'), ('renote', 'リノート', 'repeat'), ('reaction', 'リアクション', 'add_reaction_outlined')],
  ),
  SnsPreviewSample(
    kind: SnsKind.mastodon,
    instance: 'mastodon.social',
    displayName: '投稿の見本',
    handle: 'sample',
    body: 'サーバーを選んで参加する分散型の SNS です。#ハッシュタグ で話題を追えます。',
    actions: [('reply', '返信', 'subdirectory_arrow_left'), ('boost', 'ブースト', 'repeat'), ('favourite', 'お気に入り', 'star_border')],
  ),
  SnsPreviewSample(
    kind: SnsKind.bluesky,
    instance: 'bsky.social',
    displayName: '投稿の見本',
    handle: 'sample',
    body: '見るフィードを自分で選べる SNS です。',
    actions: [('reply', '返信', 'subdirectory_arrow_left'), ('repost', 'リポスト', 'repeat'), ('like', 'いいね', 'favorite_border')],
  ),
  SnsPreviewSample(
    kind: SnsKind.mixi2,
    instance: 'mixi.social',
    displayName: '投稿の見本',
    handle: 'sample',
    body: '同じ興味の人と、コミュニティでつながる SNS です。',
    actions: [('reply', '返信', 'subdirectory_arrow_left'), ('repost', 'リポスト', 'repeat'), ('like', 'いいね', 'favorite_border')],
  ),
];

class _SnsPreviewCard extends StatelessWidget {
  const _SnsPreviewCard({required this.sample});
  final SnsPreviewSample sample;

  static final _root = RrlDocument.fromSnapshot((jsonDecode(postTileSampleRrl) as Map).cast<String, Object?>()).root;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = sample;
    final key = '${s.kind.name}:${s.instance}:${s.handle}:sample';
    return Container(
      key: ValueKey('onboarding.previews.sns.${s.kind.name}'),
      width: 264,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(RasqSizes.radiusLg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.md, RasqSpacing.sm, RasqSpacing.md, 0),
          child: Row(children: [
            Expanded(child: Text(s.kind.label, style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
            Text(s.instance, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          ]),
        ),
        // 見本: 押しても何も起きない。はみ出した分はカードの角丸で切る。
        Expanded(
          child: IgnorePointer(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: RrlRenderer(
                node: _root,
                host: RrlHost(
                  // ホストが同梱した見本の木 (D-407): ホストの画面と同じく読む。
                  mediaPolicy: RasqMediaPolicy.unrestricted,
                  instanceScope: 'rasq.onboarding:${s.kind.name}:${s.instance}:${s.handle}:preview',
                  scope: RrlScope({
                    'post': {
                      'id': 'sample',
                      'key': key,
                      'author': {'displayName': s.displayName, 'handle': s.handle, 'kind': s.kind.name, 'instance': s.instance},
                      'createdAt': DateTime.now().subtract(const Duration(minutes: 3)).toIso8601String(),
                      'bodyRSL': s.body,
                      'contentWarning': null,
                      'media': const <Object?>[],
                      'poll': null,
                      'quote': null,
                    },
                    'actions': [for (final (id, label, icon) in s.actions) {'id': id, 'label': label, 'icon': icon}],
                    'actionStates': const <String, Object?>{},
                  }),
                  rslParser: InlineSpans.parse,
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// サーバー情報タイルを横に流す。情報の取れたサーバーが無いあいだは何も出さない(読み込み中も、欄を先に出さない)。
class _ServerPreviews extends ConsumerWidget {
  const _ServerPreviews({required this.hosts});
  final List<String> hosts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shown = [for (final h in hosts) if (ref.watch(serverInfoProvider(h)).value != null) h];
    if (shown.isEmpty) return const SizedBox.shrink();
    return Column(key: const ValueKey('onboarding.previews.servers'), crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      const RasqSectionHeader(title: 'サーバー'),
      SizedBox(
        height: 240,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
          itemCount: shown.length,
          separatorBuilder: (_, _) => const SizedBox(width: RasqSpacing.sm),
          // タイルの高さはサーバーで違う(バナー / 説明)。入らない分は縦に送れる。
          itemBuilder: (_, i) => SizedBox(width: 264, child: SingleChildScrollView(child: ServerInfoTile(host: shown[i], withRai: false))),
        ),
      ),
    ]);
  }
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
