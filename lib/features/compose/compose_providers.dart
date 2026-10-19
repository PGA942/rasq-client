import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';

import '../../app/providers.dart';
import '../../l10n/l10n.dart';
import 'compose_target.dart';

/// Custom emoji of the current instance (絵文字ピッカー「独自の絵文字」).
final customEmojisProvider = FutureProvider<List<EmojiInfo>>((ref) async {
  ref.watch(currentAccountProvider);
  final s = ref.watch(currentSnsSessionProvider);
  if (s == null) return const [];
  return s.customEmojis();
});

/// あるアカウントのカスタム絵文字 (D-278): コンポーザーで投稿するアカウントを切り替えているとき / 別のアカウントとして
/// リアクションするときに、**そのアカウントのサーバーの絵文字**を出す。null = いま表示しているアカウント。
final customEmojisForProvider = FutureProvider.family<List<EmojiInfo>, String?>((ref, accountKey) async {
  if (accountKey == null) return ref.watch(customEmojisProvider.future);
  final s = ref.watch(sessionForAccountProvider(accountKey)) ?? ref.watch(currentSnsSessionProvider);
  if (s == null) return const [];
  return s.customEmojis();
});

/// Recently used emoji (「履歴」) — in-memory for now (persist in M2 settings).
class RecentEmojiStore extends Notifier<List<String>> {
  @override
  List<String> build() => const [];
  void push(String e) => state = [e, ...state.where((x) => x != e)].take(24).toList();
}

final recentEmojiProvider = NotifierProvider<RecentEmojiStore, List<String>>(RecentEmojiStore.new);

/// 投稿オプション (D-045: FOW ヘッダー右側のコントロール)。
/// アプリ起動中は前回の選択を記憶する(Misskey 本家と同じ感覚)。
class ComposeOptions {
  const ComposeOptions({this.visibility = 'public', this.localOnly = false, this.reactionAcceptance});

  /// public / home / followers(DM は sendDm 側で specified 固定)。
  final String visibility;

  /// 連合なし(このサーバー内のみ)。
  final bool localOnly;

  /// リアクションの受け入れ。null = 全て(Misskey の語彙をそのまま保持)。
  final String? reactionAcceptance;

  ComposeOptions copyWith({String? visibility, bool? localOnly, String? Function()? reactionAcceptance}) => ComposeOptions(
        visibility: visibility ?? this.visibility,
        localOnly: localOnly ?? this.localOnly,
        reactionAcceptance: reactionAcceptance == null ? this.reactionAcceptance : reactionAcceptance(),
      );
}

class ComposeOptionsStore extends Notifier<ComposeOptions> {
  @override
  ComposeOptions build() => const ComposeOptions();
  void setVisibility(String v) => state = state.copyWith(visibility: v);
  void setLocalOnly(bool v) => state = state.copyWith(localOnly: v);
  void setReactionAcceptance(String? v) => state = state.copyWith(reactionAcceptance: () => v);
}

final composeOptionsProvider = NotifierProvider<ComposeOptionsStore, ComposeOptions>(ComposeOptionsStore.new);

/// コンポーザーの下書き (D-051)。ターゲット毎(通常/返信先/引用先/DM ルーム)
/// に 1 件、アプリ起動中はメモリに保持する。閉じるときに保存され、同じ
/// ターゲットのコンポーザーを開くと復元される(送信で消える)。
/// 添付画像・投票は対象外(テキストと注釈のみ)。
class ComposeDraft {
  const ComposeDraft({required this.text, this.cw = '', this.cwOn = false, this.files = const [], this.id = '', this.targetKey = 'normal', this.createdAt});
  final String text;
  final String cw;
  final bool cwOn;

  /// 添付 (D-174): 下書きはメモリ内なのでバイトごと持つ(閉じて開き直しても画像が消えない)。
  final List<ComposerInitialFile> files;

  /// 下書き FOW (D-176): 複数の下書きを id で持つ。`targetKey` = [draftKeyOf](投稿 / 返信 / 引用 / DM)。
  final String id;
  final String targetKey;
  final DateTime? createdAt;

  bool get isLinked => id.startsWith('linked:');

  /// 一覧の見出し(1 行目)。
  String get title {
    final t = text.trim();
    if (t.isNotEmpty) return t.split('\n').first;
    if (cw.trim().isNotEmpty) return '[${cw.trim()}]';
    return files.isNotEmpty ? appL10n.composeDraftTitleAttachments(files.length) : appL10n.composeDraftTitleEmpty;
  }

  /// 対象の種類(投稿 / 返信 / 引用 / DM)。
  String get targetLabel => targetKey.startsWith('reply:')
      ? appL10n.composeDraftTargetReply
      : targetKey.startsWith('quote:')
          ? appL10n.composeDraftTargetQuote
          : targetKey.startsWith('dm:')
              ? 'DM'
              : appL10n.composeDraftTargetPost;

  ComposeDraft copyWith({String? id, DateTime? createdAt}) => ComposeDraft(text: text, cw: cw, cwOn: cwOn, files: files, id: id ?? this.id, targetKey: targetKey, createdAt: createdAt ?? this.createdAt);
}

/// コンポーザーに最初から載せる添付 (D-170: 共有プラグインの `composer.open`、D-174: 下書きの復元)。
class ComposerInitialFile {
  const ComposerInitialFile({required this.bytes, required this.name, this.mimeType, this.sensitive = false});
  final Uint8List bytes;
  final String name;
  final String? mimeType;
  final bool sensitive;

  bool get isVideo => (mimeType ?? '').startsWith('video/');
}

String draftKeyOf(ComposeTarget t) => switch (t) {
      ComposeNormal() => 'normal',
      ComposeReply(to: final p) => 'reply:${p.key}',
      ComposeQuote(of: final p) => 'quote:${p.key}',
      ComposeDm(room: final r) => 'dm:${r.id}',
    };

class ComposeDraftsStore extends Notifier<Map<String, ComposeDraft>> {
  @override
  Map<String, ComposeDraft> build() => const {};

  /// id(`linked:<account>` は連動投稿の特別枠)で保存。id 無しの [d] は [key] を id にする。
  void save(String key, ComposeDraft d) => state = {...state, key: d.id == key ? d : d.copyWith(id: key)};
  void clear(String key) => state = {...state}..remove(key);
  void clearAll(Iterable<String> keys) => state = {...state}..removeWhere((k, _) => keys.contains(k));

  /// 新しい id。
  static String newId() => 'd-${DateTime.now().microsecondsSinceEpoch}';

  /// 一覧(連動枠を除く、新しい順)。
  List<ComposeDraft> get list => [for (final d in state.values) if (!d.isLinked) d]..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));

  /// この対象の最新の下書き(コンポーザーを開いたときの復元用)。
  ComposeDraft? latestFor(String targetKey) => list.where((d) => d.targetKey == targetKey).firstOrNull;
}

final composeDraftsProvider = NotifierProvider<ComposeDraftsStore, Map<String, ComposeDraft>>(ComposeDraftsStore.new);

/// リアクション受け入れの選択肢 (Misskey の語彙 → 表示名、いまの表示の言語)。null = 全て。
Map<String?, String> get reactionAcceptanceLabels => <String?, String>{
  null: appL10n.composeReactionAcceptanceAll,
  'likeOnly': appL10n.composeReactionAcceptanceLikeOnly,
  'likeOnlyForRemote': appL10n.composeReactionAcceptanceLikeOnlyForRemote,
  'nonSensitiveOnly': appL10n.composeReactionAcceptanceNonSensitiveOnly,
  'nonSensitiveOnlyForLocalLikeOnlyForRemote': appL10n.composeReactionAcceptanceNonSensitiveOnlyForLocalLikeOnlyForRemote,
};

