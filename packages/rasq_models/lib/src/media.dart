import 'package:meta/meta.dart';

enum MediaType { image, video, gif, file }

/// One tile of a MediaGrid. Sensitive state is managed **per tile**
/// (原典: UI_Elements「センシティブ状態: タイル単位で独立管理」).
@immutable
class MediaItem {
  const MediaItem({
    required this.id,
    required this.type,
    required this.url,
    this.thumbnailUrl,
    this.alt,
    this.sensitive = false,
    this.duration,
    this.fileName,
    this.width,
    this.height,
  });

  final String id;
  final MediaType type;
  final Uri url;
  final Uri? thumbnailUrl;
  final String? alt;
  final bool sensitive;

  /// For [MediaType.video].
  final Duration? duration;

  /// For [MediaType.file] (non-displayable formats).
  final String? fileName;
  final int? width;
  final int? height;

  double? get aspectRatio => (width != null && height != null && height! > 0) ? width! / height! : null;

  MediaItem copyWith({bool? sensitive, String? alt}) => MediaItem(
        id: id,
        type: type,
        url: url,
        thumbnailUrl: thumbnailUrl,
        alt: alt ?? this.alt,
        sensitive: sensitive ?? this.sensitive,
        duration: duration,
        fileName: fileName,
        width: width,
        height: height,
      );

  @override
  bool operator ==(Object other) => other is MediaItem && other.id == id && other.sensitive == sensitive && other.alt == alt;

  @override
  int get hashCode => Object.hash(id, sensitive, alt);
}
