import 'package:meta/meta.dart';

import 'user.dart';

/// クリップ = 名前付きの投稿コレクション (D-032)。Misskey のクリップ相当で、
/// ユーザーページのタブ(ノート/引用/メディア/クリップ)から他ユーザーの
/// 公開クリップも閲覧できる。中身は `SnsSession.clipNotes` で遅延解決する。
///
/// SNS ネイティブのクリップに加えて、ホスト横断クリップ(SNS を跨いで
/// post key を束ねる、端末ローカル)も同じモデルで表す — その場合
/// [isHost] が true で、[id] はホストストレージ上のキー。
@immutable
class ClipInfo {
  const ClipInfo({
    required this.id,
    required this.name,
    this.description,
    this.isPublic = false,
    this.notesCount,
    this.owner,
    this.isHost = false,
  });

  final String id;
  final String name;
  final String? description;

  /// 公開クリップか(他ユーザーから見えるか)。ホスト横断クリップは常に false。
  final bool isPublic;

  /// 中身の件数(取れない SNS は null)。
  final int? notesCount;

  final UserSummary? owner;

  /// true = ホスト横断クリップ(SNS 非依存、端末ローカル。RASQ バッジ表示)。
  final bool isHost;

  ClipInfo copyWith({String? name, String? description, bool? isPublic, int? notesCount}) => ClipInfo(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        isPublic: isPublic ?? this.isPublic,
        notesCount: notesCount ?? this.notesCount,
        owner: owner,
        isHost: isHost,
      );
}
