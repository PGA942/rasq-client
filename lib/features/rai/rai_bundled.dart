import 'dart:io';

import 'rai_llm.dart';

/// 同梱モデル (D-216): ローカルモデルは gzip で `assets/rai_models/<fileName>.gz` に入れておき(git には入れない。
/// `tool/fetch_rai_models.sh` で取得)、ユーザーが「展開」を選んだときだけ `rai_models/` へ伸長する。
/// アセットが無いビルドは従来どおり HF からダウンロードする。
const raiBundledDir = 'assets/rai_models';

String raiBundledAsset(RaiModelSpec m) => '$raiBundledDir/${m.fileName}.gz';

/// デスクトップの flutter_assets の場所(実行ファイルからの相対)。モバイルは null(rootBundle で読む)。
String? flutterAssetsDirOf(String executable, {String? os}) {
  os ??= Platform.operatingSystem;
  final exeDir = File(executable).parent.path;
  return switch (os) {
    'macos' => '${Directory(exeDir).parent.path}/Frameworks/App.framework/Resources/flutter_assets',
    'linux' || 'windows' => '$exeDir/data/flutter_assets',
    _ => null,
  };
}

/// gzip のファイルを流しながら伸長する(メモリに載せない)。進捗は圧縮側のバイト数。
/// 途中で失敗したら `.part` は消す。
Future<void> gunzipToFile(File src, File dst, {void Function(int done, int total)? onProgress}) async {
  final total = await src.length();
  final tmp = File('${dst.path}.part');
  await tmp.parent.create(recursive: true);
  final sink = tmp.openWrite();
  var read = 0;
  try {
    await sink.addStream(src.openRead().map((c) {
      read += c.length;
      onProgress?.call(read, total);
      return c;
    }).transform(gzip.decoder));
    await sink.close();
    await tmp.rename(dst.path);
  } catch (e) {
    try {
      await sink.close();
    } catch (_) {}
    if (await tmp.exists()) await tmp.delete();
    rethrow;
  }
}
