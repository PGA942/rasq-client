import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart' as fs;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:rasq_models/rasq_models.dart';

import '../settings/settings_dsl.dart';

/// 画像 / 動画の保存先 (D-213 → D-334)。設定 → アプリの外観 →「画像・動画の保存先」(`media.save` の `destination`)。
///
/// - [ask] = 保存するたびに選ぶ(既定。選べる先が 1 つしかない端末では聞かない)
/// - [photos] = 写真(iPhone / iPad の「写真」、Android のギャラリー、macOS の「写真」)。アルバム「RASQ」に入る(gal)
/// - [files] = ファイル。iPhone / iPad は「ファイル」App の「このiPad(このiPhone)› RASQ › 保存」(書類フォルダを見せている)、
///   デスクトップは保存先を選ぶダイアログ(最初はダウンロード)。Android はギャラリーに入れる(アプリの書類は「ファイル」から見えないため)
enum MediaSaveDestination {
  ask('保存するたびに選ぶ'),
  photos('写真(カメラロール)'),
  files('ファイル');

  const MediaSaveDestination(this.label);
  final String label;
}

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

String mediaSaveFileName(MediaItem item) {
  if (item.fileName?.isNotEmpty == true) return item.fileName!;
  final last = item.url.pathSegments.isNotEmpty ? item.url.pathSegments.last : '';
  final ext = last.contains('.') ? last.split('.').last.toLowerCase() : (item.type == MediaType.video ? 'mp4' : 'jpg');
  return 'rasq_${item.id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}.$ext';
}

/// 画像 / 動画を保存する(D-334)。テストでは差し替える。
final imageSaverProvider = Provider<MediaSaver>((ref) => (item, destination) async {
      final res = await http.get(item.url).timeout(const Duration(minutes: 2));
      if (res.statusCode != 200) throw StateError('HTTP ${res.statusCode}');
      final name = mediaSaveFileName(item);
      if (destination == MediaSaveDestination.photos || (!kIsWeb && Platform.isAndroid)) {
        if (!await Gal.hasAccess(toAlbum: true) && !await Gal.requestAccess(toAlbum: true)) throw StateError('写真への保存が許可されていません(設定 App で許可してください)');
        if (item.type == MediaType.video) {
          // 動画はファイルから入れる。
          final tmp = File('${(await getTemporaryDirectory()).path}/$name');
          await tmp.writeAsBytes(res.bodyBytes, flush: true);
          await Gal.putVideo(tmp.path, album: 'RASQ');
          unawaited(tmp.delete().then((_) {}, onError: (_) {}));
        } else {
          await Gal.putImageBytes(res.bodyBytes, album: 'RASQ', name: name.contains('.') ? name.substring(0, name.lastIndexOf('.')) : name);
        }
        return '写真(アルバム「RASQ」)に保存しました';
      }
      if (!kIsWeb && Platform.isIOS) {
        // 「ファイル」App の このiPad(このiPhone)› RASQ › 保存(書類フォルダ。Info.plist の UIFileSharingEnabled + LSSupportsOpeningDocumentsInPlace)。
        final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/保存');
        await dir.create(recursive: true);
        await File('${dir.path}/$name').writeAsBytes(res.bodyBytes, flush: true);
        return '「ファイル」App の RASQ › 保存 に保存しました($name)';
      }
      // デスクトップ: 保存先を選ぶダイアログ(最初はダウンロード)。
      final downloads = await getDownloadsDirectory();
      final loc = await fs.getSaveLocation(suggestedName: name, initialDirectory: downloads?.path);
      if (loc == null) return null;
      await File(loc.path).writeAsBytes(res.bodyBytes, flush: true);
      return '保存しました: ${loc.path}';
    });
