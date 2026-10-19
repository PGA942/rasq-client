import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';

/// 動画 / 音声のファイルを選ぶ (D-250)。image_picker のギャラリーは音声を出せないので、ファイル選択から。
const mediaVideoExtensions = ['mp4', 'mov', 'm4v', 'webm', 'mkv'];
const mediaAudioExtensions = ['mp3', 'm4a', 'aac', 'wav', 'ogg', 'oga', 'opus', 'flac'];

const _audioMime = {'mp3': 'audio/mpeg', 'm4a': 'audio/mp4', 'aac': 'audio/aac', 'wav': 'audio/wav', 'ogg': 'audio/ogg', 'oga': 'audio/ogg', 'opus': 'audio/opus', 'flac': 'audio/flac'};
const _videoMime = {'mp4': 'video/mp4', 'mov': 'video/quicktime', 'm4v': 'video/x-m4v', 'webm': 'video/webm', 'mkv': 'video/x-matroska'};

/// ファイル名(拡張子)から MIME。選択ダイアログは MIME を返さないことが多い(デスクトップ)。
/// 端末が返した MIME([reported])が動画 / 音声ならそれを優先する。分からなければ null。
String? mediaMimeFor(String name, {String? reported}) {
  if (reported != null && (reported.startsWith('video/') || reported.startsWith('audio/'))) return reported;
  final dot = name.lastIndexOf('.');
  if (dot < 0) return null;
  final ext = name.substring(dot + 1).toLowerCase();
  return _audioMime[ext] ?? _videoMime[ext];
}

/// 選択ダイアログ(テストで差し替える)。
final mediaFilePickerProvider = Provider<Future<XFile?> Function()>((ref) => () => openFile(acceptedTypeGroups: [
      XTypeGroup(label: appL10n.composeMediaPickTypeLabel, extensions: const [...mediaVideoExtensions, ...mediaAudioExtensions], mimeTypes: const ['video/*', 'audio/*'], uniformTypeIdentifiers: const ['public.movie', 'public.audio']),
    ]));
