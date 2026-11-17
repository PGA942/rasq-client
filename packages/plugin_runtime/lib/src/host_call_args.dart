import 'package:rasq_models/rasq_models.dart' show RasqLangOverride, RasqUiLocale;

/// ホストがプラグインの**毎回の** `call` の args に載せる予約の項目 (D-484)。ここ 1 か所で足す
/// ([WasmPluginController.invoke] / [AsyncWasmPluginController.invoke] — SNS・スロット・カスタム・タイムラインの
/// プラグインの呼び出しは、どれもこの 2 つを通る)。
///
/// - `locale`: アプリの表示の言語(BCP-47、例 `ja` / `en-US`)。プラグインが自分の文言(設定ページ・トースト・
///   FOW の見出し)や、SNS の API に渡す言語を選ぶのに使う。値は [RasqUiLocale.tag](アプリの設定 → 言語から決まる)。
///   args に `locale` が入っていても(RRL のイベントの payload など)、**ホストの値で上書きする**。
///   wasm ABI v1 には起動時の init / config の口が無いので、起動時には送らない(毎回の call だけ)。
///   値が無い / 空ならプラグインは `ja` として扱う。
///
/// 契約: rasq-sdk-sample の PROTOCOL.md §4.6(契約 v0.24、`agent/plugin-i18n`)。名前を変えるときは SDK と揃えること。
const hostLocaleArgKey = 'locale';

/// 言語パック (D-592) の、そのプラグインの文の表(`{キー: 文}`、`locale` の言語)。利用者が読み込んだ非公式の言語パックに
/// そのプラグインの文があるときだけ載せる。プラグイン(rasq-plugin-kit の `i18n`)は自分の表より先にこちらを引く
/// (差し込み `{name}` が自分の表と違う文は使わない)。args に同じ名前があっても、ホストの値で上書き(無ければ消す)。
///
/// 契約: rasq-sdk-sample の PROTOCOL.md §4.6(契約 v0.26、`claude/langpack-locale-strings`)。
const hostLocaleStringsArgKey = 'localeStrings';

/// [args] にホストの予約の項目を足したもの。[pluginId] が分かれば、言語パックのそのプラグインの文の表も載せる。
Map<String, Object?> withHostCallArgs(Map<String, Object?> args, {String? pluginId}) {
  final tag = RasqUiLocale.tag;
  final strings = pluginId == null ? null : RasqLangOverride.pluginStrings?.call(pluginId, tag);
  return {
    for (final e in args.entries)
      if (e.key != hostLocaleStringsArgKey) e.key: e.value,
    hostLocaleArgKey: tag,
    if (strings != null && strings.isNotEmpty) hostLocaleStringsArgKey: strings,
  };
}
