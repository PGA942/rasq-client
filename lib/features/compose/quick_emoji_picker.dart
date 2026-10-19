import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import '../../l10n/l10n.dart';
import '../../shell/headers.dart';
import '../home/reaction_history.dart';
import '../settings/settings_dsl.dart';
import 'compose_providers.dart';
import 'emoji_picker_fow.dart';

/// すぐ選べる絵文字 (D-512)。リアクションのボタン / コンポーザーの絵文字のボタンを**長押し**すると、ボタンにつながったパネル
/// ([HoldSlidePicker]、検索欄なし)に「設定のプリセット + 最近使った絵文字」が並ぶ。指を離さずに滑らせて、離したところの絵文字を
/// 付ける(入れる)。見出しには指の下の絵文字の `:名前:` を薄く出す。最後のマスの「その他」でピッカー全体([openEmojiPicker])。
///
/// プリセットは設定 → SNS → すぐ選べる絵文字(KV `plugins.reaction.v1` の [quickEmojisSettingsKey]。保存が無ければ
/// [defaultQuickEmojis])。カスタム絵文字(`:name:`)は、そのアカウントのサーバーにあるものだけ並べる(D-282 の履歴と同じ)。

/// 設定の項目(リアクションの設定のエリア [reactionSettingsArea] の中)。値は絵文字の文字列の配列(`😀` / `:name:`)。
const quickEmojisSettingsKey = 'quickEmojis';

/// 保存が無いときのプリセット。
const defaultQuickEmojis = ['👍', '❤️', '😂', '🎉', '🙏', '🤔', '👀', '🔥'];

/// プリセットの上限(パネルが大きくなりすぎないように)。
const quickEmojisMax = 24;

/// 最近使った絵文字を足す数。
const quickEmojisRecent = 6;

/// 「その他」のマスの値(絵文字とぶつからない)。
const quickEmojiMoreValue = '\u0000more';

/// いまのプリセット。
final quickEmojisProvider = Provider<List<String>>((ref) {
  final v = ref.watch(settingsAreaProvider(reactionSettingsArea)).value?[quickEmojisSettingsKey];
  if (v is List) return [for (final e in v) if (e is String && e.isNotEmpty) e];
  return defaultQuickEmojis;
});

/// プリセットを保存する(null = 既定に戻す)。
Future<void> setQuickEmojis(WidgetRef ref, List<String>? emojis) => ref.read(settingsAreaProvider(reactionSettingsArea).notifier).set(quickEmojisSettingsKey, emojis);

/// 見出しに出す名前: カスタム絵文字は `:name:`(@host は落とす)、Unicode は知っているものだけ `:shortcode:`、知らなければ絵文字そのもの。
String emojiShortName(String e) {
  if (e.length > 2 && e.startsWith(':') && e.endsWith(':')) return ':${e.substring(1, e.length - 1).split('@').first}:';
  final name = _unicodeNames[e] ?? _unicodeNames[e.replaceAll('️', '')];
  return name == null ? e : ':$name:';
}

/// ピッカーの「デフォルト」(EmojiPanel.unicode)と [defaultQuickEmojis] の短い名前(GitHub / Slack と同じ書き方)。
const _unicodeNames = <String, String>{
  '😀': 'grinning', '😂': 'joy', '🥹': 'face_holding_back_tears', '😍': 'heart_eyes', '🤔': 'thinking', '😭': 'sob', '😡': 'rage', '🥳': 'partying_face',
  '😴': 'sleeping', '🙏': 'pray', '👍': 'thumbsup', '👎': 'thumbsdown', '👏': 'clap', '🙌': 'raised_hands', '💪': 'muscle', '❤': 'heart',
  '💔': 'broken_heart', '🔥': 'fire', '✨': 'sparkles', '🎉': 'tada', '🚀': 'rocket', '🌙': 'crescent_moon', '☀': 'sunny', '🌸': 'cherry_blossom',
  '🍣': 'sushi', '🍜': 'ramen', '☕': 'coffee', '🍺': 'beer', '🐱': 'cat', '🐶': 'dog', '🐟': 'fish', '🦀': 'crab', '💡': 'bulb', '📌': 'pushpin',
  '✅': 'white_check_mark', '❌': 'x', '⚠': 'warning', '💯': '100', '🆗': 'ok', '🔁': 'repeat', '👀': 'eyes', '😆': 'laughing', '🤣': 'rofl',
  '😊': 'blush', '🥰': 'smiling_face_with_three_hearts', '😇': 'innocent', '🫡': 'saluting_face', '🤯': 'exploding_head', '😱': 'scream', '🙇': 'bow',
};

/// 並べる絵文字: プリセット → 最近使ったもの(ピッカーの履歴 → リアクションの履歴の多い順)。重複なし。
/// [custom] = そのアカウントのカスタム絵文字(null = 読めていない → カスタム絵文字は並べない)。
List<String> quickEmojiCandidates({required List<String> presets, required List<String> recent, required Map<String, int> history, required List<EmojiInfo>? custom}) {
  final names = custom == null ? null : {for (final c in custom) c.name};
  bool usable(String e) {
    if (!e.startsWith(':')) return true;
    if (names == null) return false;
    return names.contains(e.substring(1, e.length - 1).split('@').first);
  }

  final out = <String>[];
  for (final e in presets) {
    if (out.length >= quickEmojisMax) break;
    if (usable(e) && !out.contains(e)) out.add(e);
  }
  final byCount = history.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  var added = 0;
  for (final e in [...recent, for (final h in byCount) h.key]) {
    if (added >= quickEmojisRecent) break;
    if (usable(e) && !out.contains(e)) {
      out.add(e);
      added++;
    }
  }
  return out;
}

Uri? _urlOf(String e, List<EmojiInfo>? custom) {
  if (!e.startsWith(':') || custom == null) return null;
  final name = e.substring(1, e.length - 1).split('@').first;
  return custom.where((c) => c.name == name).firstOrNull?.url;
}

/// すぐ選べる絵文字のパネルを [anchor] のボタンにつなげて開く。選んだら [onPick](最近使った絵文字にも積む)、「その他」なら [onMore]。
/// [holding] = 長押しのまま開いた(指を滑らせて離して選ぶ)。
Future<void> openQuickEmojiPicker(
  WidgetRef ref, {
  required String id,
  required Rect anchor,
  required ValueChanged<String> onPick,
  VoidCallback? onMore,
  String? accountKey,
  int column = 0,
  Widget? anchorChild,
  TetherSide preferredSide = TetherSide.below,
  String? ownerId,
  bool holding = true,
}) async {
  final manager = ref.read(overlayManagerProvider);
  // カスタム絵文字の一覧: 読めていればそのまま。まだなら読み始めるだけで待たない(長押しの直後に出す。指はまだ画面の上)。
  // 読めていない間は、カスタム絵文字のプリセット / 履歴を並べない(Unicode と「その他」だけ)。
  final custom = ref.read(customEmojisForProvider(accountKey)).value;
  if (custom == null) unawaited(ref.read(customEmojisForProvider(accountKey).future).then<void>((_) {}, onError: (_) {}));
  final emojis = quickEmojiCandidates(
    presets: ref.read(quickEmojisProvider),
    recent: ref.read(recentEmojiProvider),
    history: ref.read(reactionHistoryProvider).value ?? const {},
    custom: custom,
  );
  final l = appL10n;
  final picked = await manager.showHoldSlidePicker<String>(
    id: id,
    anchor: anchor,
    title: l.quickPickEmojiTitle,
    holding: holding,
    layout: HoldSlideLayout.grid,
    column: column,
    ownerId: ownerId,
    width: 300,
    preferredSide: preferredSide,
    anchorChild: anchorChild,
    items: [
      for (final e in emojis)
        HoldSlideItem<String>(
          key: ValueKey('quickEmoji.$e'),
          value: e,
          label: emojiShortName(e),
          semanticsLabel: emojiShortName(e),
          builder: (context, on) => FittedBox(fit: BoxFit.scaleDown, child: RasqCustomEmoji(url: _urlOf(e, custom), fallbackText: e, height: 28)),
        ),
      if (onMore != null)
        HoldSlideItem<String>(
          key: const ValueKey('quickEmoji.more'),
          value: quickEmojiMoreValue,
          label: l.quickPickEmojiMore,
          builder: (context, on) => Icon(Icons.add_reaction_outlined, size: 24, color: on ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant),
        ),
    ],
    headerBuilder: (context, hi) {
      final scheme = Theme.of(context).colorScheme;
      final style = Theme.of(context).textTheme.labelLarge;
      if (hi == null) return Text(l.quickPickEmojiTitle, key: ValueKey('$id.header.text'), style: style?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant));
      // 絵文字は `:名前:` を薄く(「その他」はふつうの名前)。
      final faint = hi.value != quickEmojiMoreValue;
      return Text(
        hi.label,
        key: ValueKey('$id.header.text'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: (faint ? RasqTypography.caption.copyWith(fontSize: 13) : style?.copyWith(fontWeight: FontWeight.w700))?.copyWith(color: faint ? scheme.onSurfaceVariant.withValues(alpha: 0.75) : scheme.onSurface),
      );
    },
  );
  if (picked == null) return;
  if (picked == quickEmojiMoreValue) return onMore?.call();
  ref.read(recentEmojiProvider.notifier).push(picked);
  onPick(picked);
}

/// 設定 → すぐ選べる絵文字 (D-512)。並べ替え(掴んで動かす)/ 外す / 追加(ピッカー全体から選ぶ)/ 既定に戻す。
class QuickEmojiSettingsScreen extends ConsumerWidget {
  const QuickEmojiSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final emojis = ref.watch(quickEmojisProvider);
    final custom = ref.watch(customEmojisProvider).value;
    final saved = ref.watch(settingsAreaProvider(reactionSettingsArea)).value?[quickEmojisSettingsKey] != null;
    return Scaffold(
      appBar: RasqPageHeader(title: l.quickPickEmojiTitle),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        RasqCaption(l.quickPickSettingsCaption, padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.md, RasqSpacing.page, RasqSpacing.sm)),
        Expanded(
          child: emojis.isEmpty
              ? Padding(padding: const EdgeInsets.all(RasqSpacing.page), child: Text(l.quickPickSettingsEmpty, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)))
              : ReorderableListView(
                  key: const ValueKey('quickEmoji.settings.list'),
                  onReorderItem: (from, to) {
                    final next = [...emojis];
                    final e = next.removeAt(from);
                    next.insert(to, e);
                    setQuickEmojis(ref, next);
                  },
                  children: [
                    for (final e in emojis)
                      ListTile(
                        key: ValueKey('quickEmoji.settings.$e'),
                        leading: SizedBox(width: 32, child: Center(child: RasqCustomEmoji(url: _urlOf(e, custom), fallbackText: e, height: 26))),
                        title: Text(emojiShortName(e), style: RasqTypography.body.copyWith(color: scheme.onSurfaceVariant)),
                        trailing: IconButton(
                          key: ValueKey('quickEmoji.settings.remove.$e'),
                          icon: const Icon(Icons.remove_circle_outline),
                          tooltip: l.quickPickSettingsRemove(emojiShortName(e)),
                          onPressed: () => setQuickEmojis(ref, [for (final x in emojis) if (x != e) x]),
                        ),
                      ),
                  ],
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(RasqSpacing.page),
          child: Row(children: [
            Expanded(
              child: FilledButton.icon(
                key: const ValueKey('quickEmoji.settings.add'),
                icon: const Icon(Icons.add_reaction_outlined),
                label: Text(l.quickPickSettingsAdd),
                onPressed: emojis.length >= quickEmojisMax
                    ? null
                    : () => openEmojiPicker(ref, title: l.quickPickSettingsAdd, onPick: (e) {
                          final now = ref.read(quickEmojisProvider);
                          if (!now.contains(e) && now.length < quickEmojisMax) unawaited(setQuickEmojis(ref, [...now, e]));
                        }),
              ),
            ),
            if (saved) ...[
              const SizedBox(width: RasqSpacing.sm),
              TextButton(key: const ValueKey('quickEmoji.settings.reset'), onPressed: () => setQuickEmojis(ref, null), child: Text(l.quickPickSettingsReset)),
            ],
          ]),
        ),
      ]),
    );
  }
}
