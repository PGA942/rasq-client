/// 開発 / デモ用の SNS の接続先の差し替え (D-359)。
///
/// `--dart-define=RASQ_DEV_SNS_BASE=misskey.rasq.test=http://127.0.0.1:9101,mstdn.rasq.test=http://127.0.0.1:9102`
/// のように「インスタンスのホスト=基底 URL」を並べると、そのインスタンスへの通信だけを基底 URL へ向ける
/// (プレビュー録画用のダミー SNS サーバー、http / ポート付き可)。アカウントの表示・保存はインスタンスのホストのまま。
/// 指定が無ければ何も変わらない(常に `https://<host>`)。
library;

const _raw = String.fromEnvironment('RASQ_DEV_SNS_BASE');

final Map<String, Uri> _fromDefine = parseDevSnsBase(_raw);
Map<String, Uri> _runtime = const {};

/// インスタンスのホスト(小文字)→ 基底 URL。dart-define の上に、アプリの設定「テスト用の接続先」(実行時)を重ねる。
Map<String, Uri> get devSnsBaseUrls => {..._fromDefine, ..._runtime};

/// 実行時の差し替え(設定 → RASQ サーバー →「テスト用の接続先」)。空文字で外す。
void setRuntimeDevSnsBase(String raw) => _runtime = parseDevSnsBase(raw);

Map<String, Uri> parseDevSnsBase(String raw) {
  final out = <String, Uri>{};
  for (final part in raw.split(',')) {
    final i = part.indexOf('=');
    if (i <= 0) continue;
    final host = part.substring(0, i).trim().toLowerCase();
    final base = Uri.tryParse(part.substring(i + 1).trim());
    if (host.isEmpty || base == null || !(base.isScheme('http') || base.isScheme('https')) || base.host.isEmpty) continue;
    out[host] = base;
  }
  return out;
}

/// [host] の差し替え先(無ければ null)。
Uri? devSnsBaseFor(String host) => devSnsBaseUrls[host.trim().toLowerCase()];

/// インスタンスへの URL。差し替えがあれば基底 URL の上に、無ければ `https://<host><path>`。
Uri snsUri(String host, String path, [Map<String, String>? query]) {
  final base = devSnsBaseFor(host);
  if (base == null) return Uri.https(host, path, query);
  final prefix = base.path.endsWith('/') ? base.path.substring(0, base.path.length - 1) : base.path;
  return base.replace(path: '$prefix$path', queryParameters: query);
}
