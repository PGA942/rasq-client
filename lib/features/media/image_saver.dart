import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart' as fs;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:rasq_models/rasq_models.dart';

import '../../l10n/l10n.dart';
import '../settings/settings_dsl.dart';

/// 画像 / 動画の保存先 (D-213 → D-334)。設定 → アプリの外観 →「画像・動画の保存先」(`media.save` の `destination`)。
///
/// - [ask] = 保存するたびに選ぶ(既定。選べる先が 1 つしかない端末では聞かない)
/// - [photos] = 写真(iPhone / iPad の「写真」、Android のギャラリー、macOS の「写真」)。アルバム「RASQ」に入る(gal)
/// - [files] = ファイル。iPhone / iPad は「ファイル」App の「このiPad(このiPhone)› RASQ › 保存」(書類フォルダを見せている)、
///   デスクトップは保存先を選ぶダイアログ(最初はダウンロード)。Android はギャラリーに入れる(アプリの書類は「ファイル」から見えないため)
enum MediaSaveDestination {
  ask,
  photos,
  files;

  /// 選択肢の名前(表示の言語)。
  String get label => switch (this) {
        ask => appL10n.mediaSaveAsk,
        photos => appL10n.mediaSavePhotos,
        files => appL10n.mediaSaveFiles,
      };
}

/// 保存できなかった理由 (利用者に見せる文)。`toString` は文だけ(スナックバーに `$e` で出ても「Bad state: 」が付かない)。
class MediaSaveException implements Exception {
  const MediaSaveException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// iPhone / iPad で保存する書類フォルダの下のフォルダーの名前(端末の上の名前なので、表示の言語に依らず同じ)。
const _iosSaveFolder = '保存'; // l10n-ignore

const mediaSaveSettingsArea = 'media.save';

final mediaSaveDestinationProvider = Provider<MediaSaveDestination>((ref) {
  final v = ref.watch(settingsAreaProvider(mediaSaveSettingsArea)).value?['destination'];
  return MediaSaveDestination.values.where((d) => d.name == v).firstOrNull ?? MediaSaveDestination.ask;
});

/// この端末で選べる保存先(聞くときの候補)。
List<MediaSaveDestination> mediaSaveDestinationsHere() {
  if (kIsWeb) return const [];
  final photos = Platform.isIOS || Platform.isAndroid || Platform.isMacOS;
  final files = !Platform.isAndroid;
  return [if (photos) MediaSaveDestination.photos, if (files) MediaSaveDestination.files];
}

/// この端末で選べる保存先(テストで差し替える)。
final mediaSaveDestinationsHereProvider = Provider<List<MediaSaveDestination>>((ref) => mediaSaveDestinationsHere());

/// 実際に使う保存先: 選べない先は選べるほうへ寄せる。null = 聞く。
MediaSaveDestination? resolveMediaSaveDestination(MediaSaveDestination setting, List<MediaSaveDestination> here) {
  if (here.isEmpty) return MediaSaveDestination.files;
  if (setting == MediaSaveDestination.ask) return here.length == 1 ? here.single : null;
  return here.contains(setting) ? setting : here.first;
}

/// 保存する。戻りはスナックバーの文。保存先を選ぶダイアログでやめたら null。
typedef MediaSaver = Future<String?> Function(MediaItem item, MediaSaveDestination destination);

/// 保存するファイル名。SNS が付けた名前 ([MediaItem.fileName]) は**相手のサーバーが決めた文字列**なので、
/// そのままパスにしない (D-407、セキュリティ指摘 #25): [sanitizeMediaFileName] で 1 つのファイル名に直す。
String mediaSaveFileName(MediaItem item) {
  final ext = _extOf(item);
  final given = item.fileName == null ? null : sanitizeMediaFileName(item.fileName!, fallbackExt: ext);
  if (given != null) return given;
  return 'rasq_${_safeId(item.id)}.$ext';
}

String _safeId(String id) {
  final s = id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  return s.isEmpty ? 'media' : (s.length > 64 ? s.substring(0, 64) : s);
}

String _extOf(MediaItem item) {
  final last = item.url.pathSegments.isNotEmpty ? item.url.pathSegments.last : '';
  final ext = last.contains('.') ? last.split('.').last.toLowerCase() : '';
  return RegExp(r'^[a-z0-9]{1,8}$').hasMatch(ext) ? ext : (item.type == MediaType.video ? 'mp4' : 'jpg');
}

/// 相手が付けたファイル名を、保存先のフォルダーの中の 1 つの名前に直す (指摘 #25)。パス区切り(`/` `\`)の前は捨てて
/// 最後の部分だけ、制御文字 / Windows で使えない字は `_`、先頭の `.` は落とす(`..` / 隠しファイルにしない)、長さは 120 字まで。
/// 拡張子は英数字 8 字までのものだけ残し、無ければ [fallbackExt]。名前が残らなければ null(アプリが名前を作る)。
@visibleForTesting
String? sanitizeMediaFileName(String raw, {required String fallbackExt}) {
  var name = raw.split(RegExp(r'[/\\]')).last;
  name = name.replaceAll(RegExp(r'[\x00-\x1f\x7f<>:"|?*]'), '_').trim();
  name = name.replaceFirst(RegExp(r'^\.+'), '');
  if (name.isEmpty || name == '.' || name == '..') return null;
  final dot = name.lastIndexOf('.');
  var base = dot > 0 ? name.substring(0, dot) : name;
  var ext = dot > 0 ? name.substring(dot + 1).toLowerCase() : '';
  if (!RegExp(r'^[a-z0-9]{1,8}$').hasMatch(ext)) {
    base = name;
    ext = fallbackExt;
  }
  base = base.replaceAll(RegExp(r'\.+$'), '').trim();
  if (base.isEmpty) return null;
  if (base.length > 120) base = base.substring(0, 120);
  return '$base.$ext';
}

/// [dir] の中に [name] で新しく書く (指摘 #25): 名前は 1 つのファイル名であること、書く先が [dir] の直下であることを確かめ、
/// 既にあれば ` (2)` などを付けて**上書きしない**(排他的に作る)。戻りは書いたファイル。
@visibleForTesting
Future<File> writeMediaFileExclusive(Directory dir, String name, List<int> bytes) async {
  if (name.isEmpty || name == '.' || name == '..' || name.contains('/') || name.contains('\\')) throw ArgumentError.value(name, 'name', appL10n.mediaSaveBadFileName);
  final dot = name.lastIndexOf('.');
  final base = dot > 0 ? name.substring(0, dot) : name, ext = dot > 0 ? name.substring(dot) : '';
  final root = dir.absolute.path;
  for (var i = 1; i < 1000; i++) {
    final file = File('$root${Platform.pathSeparator}${i == 1 ? name : '$base ($i)$ext'}');
    if (file.parent.absolute.path != root) throw MediaSaveException(appL10n.mediaSaveOutsideFolder);
    try {
      await file.create(exclusive: true);
    } on FileSystemException {
      continue; // もうある(上書きしない)
    }
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
  throw MediaSaveException(appL10n.mediaSaveTooManySameName);
}

/// 画像 / 動画を保存する(D-334)。テストでは差し替える。
final imageSaverProvider = Provider<MediaSaver>((ref) => (item, destination) async {
      final res = await http.get(item.url).timeout(const Duration(minutes: 2));
      if (res.statusCode != 200) throw MediaSaveException('HTTP ${res.statusCode}');
      final name = mediaSaveFileName(item);
      if (destination == MediaSaveDestination.photos || (!kIsWeb && Platform.isAndroid)) {
        if (!await Gal.hasAccess(toAlbum: true) && !await Gal.requestAccess(toAlbum: true)) throw MediaSaveException(appL10n.mediaSavePhotosDenied);
        if (item.type == MediaType.video) {
          // 動画はファイルから入れる。一時ファイルの名前はアプリが作る(相手の付けた名前を使わない、指摘 #25)。
          final tmp = await writeMediaFileExclusive(await getTemporaryDirectory(), 'rasq_${DateTime.now().microsecondsSinceEpoch}_${_safeId(item.id)}.${_extOf(item)}', res.bodyBytes);
          try {
            await Gal.putVideo(tmp.path, album: 'RASQ');
          } finally {
            unawaited(tmp.delete().then((_) {}, onError: (_) {}));
          }
        } else {
          await Gal.putImageBytes(res.bodyBytes, album: 'RASQ', name: name.contains('.') ? name.substring(0, name.lastIndexOf('.')) : name);
        }
        return appL10n.mediaSavedToPhotos;
      }
      if (!kIsWeb && Platform.isIOS) {
        // 「ファイル」App の このiPad(このiPhone)› RASQ › 保存(書類フォルダ。Info.plist の UIFileSharingEnabled + LSSupportsOpeningDocumentsInPlace)。
        final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/$_iosSaveFolder');
        await dir.create(recursive: true);
        final saved = await writeMediaFileExclusive(dir, name, res.bodyBytes);
        return appL10n.mediaSavedToFilesApp(_iosSaveFolder, saved.uri.pathSegments.last);
      }
      // デスクトップ: 保存先を選ぶダイアログ(最初はダウンロード)。
      final downloads = await getDownloadsDirectory();
      final loc = await fs.getSaveLocation(suggestedName: name, initialDirectory: downloads?.path);
      if (loc == null) return null;
      await File(loc.path).writeAsBytes(res.bodyBytes, flush: true);
      return appL10n.mediaSavedToPath(loc.path);
    });
