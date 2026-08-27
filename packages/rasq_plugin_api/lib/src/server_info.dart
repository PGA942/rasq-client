import 'package:meta/meta.dart';

/// Result of probing an instance host (サーバーの検索 / PDS変更).
@immutable
class ServerInfo {
  const ServerInfo({required this.host, required this.name, this.software, this.version, this.description, this.iconUrl, this.registrationOpen, this.maintainer});
  final String host;
  final String name;
  final String? software;
  final String? version;
  final String? description;
  final Uri? iconUrl;
  final bool? registrationOpen;
  final String? maintainer;
}
