import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';

import '../../app/providers.dart';
import 'compose_target.dart';

/// Custom emoji of the current instance (絵文字ピッカー「独自の絵文字」).
final customEmojisProvider = FutureProvider<List<EmojiInfo>>((ref) async {
  ref.watch(currentAccountProvider);
  final s = ref.watch(currentSnsSessionProvider);
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
  const ComposeDraft({required this.text, this.cw = '', this.cwOn = false});
  final String text;
  final String cw;
  final bool cwOn;
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
  void save(String key, ComposeDraft d) => state = {...state, key: d};
  void clear(String key) => state = {...state}..remove(key);
}

final composeDraftsProvider = NotifierProvider<ComposeDraftsStore, Map<String, ComposeDraft>>(ComposeDraftsStore.new);

/// リアクション受け入れの選択肢 (Misskey の語彙 → 表示名)。null = 全て。
const reactionAcceptanceLabels = <String?, String>{
  null: '全て',
  'likeOnly': 'いいねのみ',
  'likeOnlyForRemote': '外部からはいいね',
  'nonSensitiveOnly': '非センシティブのみ',
  'nonSensitiveOnlyForLocalLikeOnlyForRemote': '非センシティブ&外部からはいいねのみ',
};

