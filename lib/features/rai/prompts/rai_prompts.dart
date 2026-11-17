import 'package:rasq_models/rasq_models.dart' show RasqLangOverride, RasqUiLocale;

import 'rai_prompts.g.dart';

export 'rai_prompts.g.dart';

/// RAi が LLM / 検索に渡す文(指示・見出し・関数の一覧)の表 (D-492)。
///
/// - 表示の言語([RasqUiLocale.tag])ごとに 1 つ。RAi はその言語で考え、その言語で答える。
/// - 画面に出す文言(ARB の部品 `lib/l10n/parts/rai*.<言語>.arb`)とは分けて持つ。指示の文は長く、何行にもまたがり、
///   訳す人は「モデルへの指示」として訳す(言い回し・長さの上限・書式の約束を崩さない)必要があるため。
/// - 文は**表**(`parts/rai.<言語>.json`、正本は言語パックのリポジトリ orgate-question/langpack の `packs/official/rai`)に書き、
///   tool/l10n_merge.dart が rai_prompts.g.dart(言語ごとの [TableRaiPrompts])を作る (D-592)。言語を足すときは表を足して
///   [raiPromptCatalogs] に足す(docs/I18N.md「RAi の指示の文」)。無い言語は日本語に倒す。
/// - 利用者が読み込んだ言語パック(D-592)に `rai` の領域があれば、その言語のキーを先に引く([raiPromptsFor])。
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

  /// インストラクションで操作リファレンスに当たらなかったとき (D-585): 閾値には届かないが近い操作を添え、**画面に無い
  /// ボタン・設定を作らない**よう頼む。[operations] は `- 見出し: 手順 → 手順` の行(空なら近いものが無い)。先頭は改行。
  String instructionNearBlock(List<String> operations);

  /// 関数の一覧(system に出す 1 行ずつ)。行の形と関数名・引数名は全言語で同じ。
  List<String> get functionUsage;

  /// web 検索の行 (D-228)。
  String get webSearchUsage;

  /// Brave Answers に送る質問(system を受けないので、指示を質問に添える)。
  String webAnswerQuestion(String question);
}

/// 表([RaiPrompts] の項目 → 文)で答える [RaiPrompts] (D-592)。一覧の引数の並べ方は言語に依らず同じ(書式の約束)で、
/// 表には並べたあとの文を `{名前}` で差し込む: `plan` = ` / ` でつなぐ(答え直しの計画は `1. …` を空白でつなぐ)、
/// `operations` = 改行でつなぐ、`usage` = `- …` を改行でつなぐ、`ids` = `, ` でつなぐ。`functionUsage` は改行で区切った行。
/// `instructionNearBlock` は近い操作が無ければ `instructionNearBlockEmpty`。
///
/// [overrideLocale] があれば、言語パックの上書き(`RasqLangOverride` の領域 `rai`)を先に引く。
class TableRaiPrompts extends RaiPrompts {
  const TableRaiPrompts(this.tag, this.table, {this.overrideLocale});

  @override
  final String tag;

  /// 同梱の表(キー → 文)。
  final Map<String, String> table;

  /// 言語パックの上書きを引く言語(null = 引かない)。
  final String? overrideLocale;

  static final _slot = RegExp(r'\{(\w+)\}');

  String _t(String key, [Map<String, String> args = const {}]) {
    final o = overrideLocale;
    if (o != null) {
      final v = RasqLangOverride.text(o, 'rai', key, args);
      if (v != null) return v;
    }
    final s = table[key] ?? raiPromptTables[RasqUiLocale.defaultTag]![key] ?? '';
    return args.isEmpty ? s : s.replaceAllMapped(_slot, (m) => args[m[1]] ?? m[0]!);
  }

  @override
  String get languageName => _t('languageName');

  @override
  String get assistantSystem => _t('assistantSystem');

  @override
  String get planSystem => _t('planSystem');

  @override
  String get instructionSystem => _t('instructionSystem');

  @override
  String get situationSystem => _t('situationSystem');

  @override
  String planLine(List<String> plan) => _t('planLine', {'plan': plan.join(' / ')});

  @override
  String operationsBlock(List<String> operations) => _t('operationsBlock', {'operations': operations.join('\n')});

  @override
  String functionsBlock(List<String> usage) => _t('functionsBlock', {'usage': usage.map((u) => '- $u').join('\n')});

  @override
  String restartPlanLine(List<String> plan) => _t('restartPlanLine', {'plan': [for (final (i, p) in plan.indexed) '${i + 1}. $p'].join(' ')});

  @override
  String restartFetched(String digest, String fetched) => _t('restartFetched', {'digest': digest, 'fetched': fetched});

  @override
  String excludedOperations(List<String> ids) => _t('excludedOperations', {'ids': ids.join(', ')});

  @override
  String eventSummary(String conversation) => _t('eventSummary', {'conversation': conversation});

  @override
  String get learnabilitySystem => _t('learnabilitySystem');

  @override
  String learnabilityInput({required String bio, required String fields, required String posts}) => _t('learnabilityInput', {'bio': bio, 'fields': fields, 'posts': posts});

  @override
  String get referenceContextHeading => _t('referenceContextHeading');

  @override
  String instructionNearBlock(List<String> operations) =>
      operations.isEmpty ? _t('instructionNearBlockEmpty') : _t('instructionNearBlock', {'operations': operations.join('\n')});

  @override
  List<String> get functionUsage => _t('functionUsage').split('\n');

  @override
  String get webSearchUsage => _t('webSearchUsage');

  @override
  String webAnswerQuestion(String question) => _t('webAnswerQuestion', {'question': question});
}

/// 言語 → 表。言語を足すときはここに足す。キーは表の [RaiPrompts.tag](中国語は字体で分ける: `zh` = 簡体字、`zh-Hant` = 繁体字)。
const Map<String, RaiPrompts> raiPromptCatalogs = {
  'ja': RaiPromptsJa(),
  'en': RaiPromptsEn(),
  'zh': RaiPromptsZh(),
  'zh-Hant': RaiPromptsZhHant(),
  'ko': RaiPromptsKo(),
};

/// [tag](BCP-47)の表: 同じタグ → 親のタグ(`zh-Hant-TW` → `zh-Hant` → `zh`、大文字小文字と `_` / `-` は区別しない)→ 日本語。
/// 中国語で字体の無いタグは地域で決める(`zh-TW` / `zh-HK` / `zh-MO` → 繁体字、`zh-CN` / `zh-SG` / `zh` → 簡体字)。
/// 言語パック (D-592) が読み込まれていれば、その言語の `rai` のキーを先に引く(パックが足した言語は、パックの決めた同梱の言語の表に倒す)。
RaiPrompts raiPromptsFor(String tag) {
  final bundled = _bundledFor(RasqLangOverride.baseTag(tag));
  if (!RasqLangOverride.active || bundled is! TableRaiPrompts) return bundled;
  final added = RasqLangOverride.baseTag(tag) != tag;
  return TableRaiPrompts(added ? tag : bundled.tag, bundled.table, overrideLocale: tag);
}

RaiPrompts _bundledFor(String tag) {
  final parts = [for (final p in tag.trim().replaceAll('_', '-').split('-')) if (p.isNotEmpty) p.toLowerCase()];
  if (parts.length > 1 && parts.first == 'zh' && const {'tw', 'hk', 'mo'}.contains(parts[1])) {
    parts.insert(1, 'hant');
  }
  final byNorm = {for (final e in raiPromptCatalogs.entries) e.key.toLowerCase(): e.value};
  for (var n = parts.length; n > 0; n--) {
    if (byNorm[parts.take(n).join('-')] case final p?) return p;
  }
  return raiPromptCatalogs[RasqUiLocale.defaultTag]!;
}

/// いまの表示の言語の表。
RaiPrompts get raiPrompts => raiPromptsFor(RasqUiLocale.tag);
