import 'package:rasq_models/rasq_models.dart' show RasqUiLocale;

import 'rai_prompts_ja.dart';

export 'rai_prompts_ja.dart';

/// RAi が LLM / 検索に渡す文(指示・見出し・関数の一覧)の表 (D-492)。
///
/// - 表示の言語([RasqUiLocale.tag])ごとに 1 つ。RAi はその言語で考え、その言語で答える。
/// - 画面に出す文言(ARB の部品 `lib/l10n/parts/rai*.<言語>.arb`)とは分けて持つ。指示の文は長く、何行にもまたがり、
///   訳す人は「モデルへの指示」として訳す(言い回し・長さの上限・書式の約束を崩さない)必要があるため。
/// - 言語を足すとき: `rai_prompts_<言語>.dart` に [RaiPrompts] の実装を書き、[raiPromptCatalogs] に足す
///   (docs/I18N.md「RAi の指示の文」)。無い言語は日本語に倒す。
/// - **書式の約束は言語に依らず同じ**: `[[instruction:<id>|…]]` / `[[call:<関数>|引数=値|…]]`、関数の名前と引数の名前
///   (`posts.fetch(kind=home|search, …)` の英字の部分)、一覧の行の「`名前(…)・名前(…): 説明`」の形
///   (`raiFunctionUsageFor` が `: ` と `・` で読む)。test/rai_prompts_test.dart が全部の言語で確かめる。
abstract class RaiPrompts {
  const RaiPrompts();

  /// BCP-47 の言語(`ja`)。
  String get tag;

  /// 答える言語のその言語での名前(`日本語` / `English`)。答えの言語を指定する指示はこの名前を含む(テストで確かめる)。
  String get languageName;

  /// 答えの system(アシスタント)。
  String get assistantSystem;

  /// 箇条書きの計画の system (D-220)。
  String get planSystem;

  /// 操作を教える(操作モード)の system。
  String get instructionSystem;

  /// 発言を「何をしたい状況か」(シチュエーション)の一文に言い換える system。
  String get situationSystem;

  /// 計画を添える行(先頭に改行)。
  String planLine(List<String> plan);

  /// 案内できる操作の一覧と、案内の呼び出し `[[instruction:<id>|…]]` の説明(先頭に改行)。
  String operationsBlock(List<String> operations);

  /// 使える関数の一覧と、関数の呼び出し `[[call:<関数>|…]]` の説明(先頭に改行)。[usage] は一覧の行。
  String functionsBlock(List<String> usage);

  /// 答え直し (D-221) で添える計画の行(先頭に改行)。
  String restartPlanLine(List<String> plan);

  /// 答え直しで添える、ここまでのダイジェストと取得した情報(データ)。先頭に改行。
  String restartFetched(String digest, String fetched);

  /// 「これじゃない」と言われた操作 (D-222) の行。
  String excludedOperations(List<String> ids);

  /// 関連 TL の会話のまとまりを 1 文に要約させる指示 (D-528)。[conversation] は「名前: 本文」の行を改行でつないだもの。
  String eventSummary(String conversation);

  /// 学習への提供の端末の下見 (D-363) の system: 書き手が AI の学習への利用を断っているかを JSON 1 行で答えさせる。
  /// 答えの形(`{"verdict":"allow|deny|unsure","reason":"…"}`)と verdict の値は全言語で同じ。
  String get learnabilitySystem;

  /// 学習への提供の端末の下見に渡す書き手の情報。[bio] は自己紹介(切り詰め済み)、[fields] は項目を並べたもの、
  /// [posts] は投稿の見本を並べたもの。
  String learnabilityInput({required String bio, required String fields, required String posts});

  /// 推論サーバーへ添えるリファレンスの見出し (D-216)。
  String get referenceContextHeading;

  /// 関数の一覧(system に出す 1 行ずつ)。行の形と関数名・引数名は全言語で同じ。
  List<String> get functionUsage;

  /// web 検索の行 (D-228)。
  String get webSearchUsage;

  /// Brave Answers に送る質問(system を受けないので、指示を質問に添える)。
  String webAnswerQuestion(String question);
}

/// 言語 → 表。言語を足すときはここに足す。
const Map<String, RaiPrompts> raiPromptCatalogs = {
  'ja': RaiPromptsJa(),
};

/// [tag](BCP-47)の表: 同じタグ → 言語の部分(`en-US` → `en`)→ 日本語。
RaiPrompts raiPromptsFor(String tag) {
  final t = tag.trim().replaceAll('_', '-');
  return raiPromptCatalogs[t] ?? raiPromptCatalogs[t.split('-').first.toLowerCase()] ?? raiPromptCatalogs[RasqUiLocale.defaultTag]!;
}

/// いまの表示の言語の表。
RaiPrompts get raiPrompts => raiPromptsFor(RasqUiLocale.tag);
