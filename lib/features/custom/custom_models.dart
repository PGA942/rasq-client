import 'package:flutter/foundation.dart';

/// カスタムプラグインの共有セッション(rasq-central S-048、D-357)。
/// scope = `room:<roomId>`(AsTell のルームにデプロイ)/ `profile:<accountId>`(RASQ アカウントのページ)/ `link:<id>`(招待)。
@immutable
class CustomSession {
  const CustomSession({
    required this.id,
    required this.pluginId,
    required this.version,
    required this.scope,
    required this.title,
    this.ownerAccountId,
    this.ownerHandle,
    this.inviteCode,
    required this.createdAt,
    this.participantCount = 0,
  });
  final String id;
  final String pluginId;
  final String version;
  final String scope;
  final String title;
  final String? ownerAccountId;
  final String? ownerHandle;
  final String? inviteCode;
  final DateTime createdAt;
  final int participantCount;

  String get scopeKind => scope.split(':').first;
  String? get roomId => scope.startsWith('room:') ? scope.substring(5) : null;
  String? get profileAccountId => scope.startsWith('profile:') ? scope.substring(8) : null;

  CustomSession copyWith({int? participantCount}) => CustomSession(
        id: id,
        pluginId: pluginId,
        version: version,
        scope: scope,
        title: title,
        ownerAccountId: ownerAccountId,
        ownerHandle: ownerHandle,
        inviteCode: inviteCode,
        createdAt: createdAt,
        participantCount: participantCount ?? this.participantCount,
      );

  factory CustomSession.fromJson(Map<String, Object?> j) => CustomSession(
        id: '${j['id']}',
        pluginId: '${j['pluginId'] ?? ''}',
        version: '${j['version'] ?? ''}',
        scope: '${j['scope'] ?? ''}',
        title: '${j['title'] ?? j['pluginId'] ?? ''}',
        ownerAccountId: j['ownerAccountId'] as String?,
        ownerHandle: j['ownerHandle'] as String?,
        inviteCode: j['inviteCode'] as String?,
        createdAt: DateTime.tryParse('${j['createdAt']}') ?? DateTime.fromMillisecondsSinceEpoch(0),
        participantCount: (j['participantCount'] as num?)?.toInt() ?? 0,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'pluginId': pluginId,
        'version': version,
        'scope': scope,
        'title': title,
        'ownerAccountId': ?ownerAccountId,
        'ownerHandle': ?ownerHandle,
        'inviteCode': ?inviteCode,
        'createdAt': createdAt.toIso8601String(),
        'participantCount': participantCount,
      };
}

/// セッションの参加者。
@immutable
class CustomParticipant {
  const CustomParticipant({required this.accountId, required this.handle, this.displayName});
  final String accountId;
  final String handle;
  final String? displayName;

  factory CustomParticipant.fromJson(Map<String, Object?> j) => CustomParticipant(accountId: '${j['accountId']}', handle: '${j['handle'] ?? ''}', displayName: j['displayName'] as String?);
  Map<String, Object?> toJson() => {'accountId': accountId, 'handle': handle, 'displayName': ?displayName};
}

/// サーバー変数 1 つ(値と版、最後に書いた人、期限)。
@immutable
class CustomVar {
  const CustomVar({required this.value, required this.rev, this.by, this.expiresAt});
  final Object? value;
  final int rev;
  final String? by;

  /// 期限(エポックミリ秒、契約 v0.22 / D-465)。期限の無いキーは null。
  final int? expiresAt;

  factory CustomVar.fromJson(Map<String, Object?> j) => CustomVar(value: j['value'], rev: (j['rev'] as num?)?.toInt() ?? 0, by: j['by'] as String?, expiresAt: (j['expiresAt'] as num?)?.toInt());
  Map<String, Object?> toJson() => {'value': value, 'rev': rev, 'by': ?by, 'expiresAt': ?expiresAt};
}

/// RASQ アカウントのページに置いたカスタムプラグイン(`GET /accounts/{handle}/pages`)。
@immutable
class CustomProfilePage {
  const CustomProfilePage({required this.pluginId, this.version, required this.name, this.icon, this.mode = 'solo', this.sessionId});
  final String pluginId;
  final String? version;
  final String name;
  final String? icon;
  final String mode;
  final String? sessionId;

  bool get isShared => mode == 'shared';

  factory CustomProfilePage.fromJson(Map<String, Object?> j) => CustomProfilePage(
        pluginId: '${j['pluginId']}',
        version: j['version'] as String?,
        name: '${j['name'] ?? j['pluginId']}',
        icon: j['icon'] as String?,
        mode: j['mode'] == 'shared' ? 'shared' : 'solo',
        sessionId: j['sessionId'] as String?,
      );
}

/// ルームの共有 `kind: "plugin"` の payload(参加者の「このプラグインを使いたい」提案、D-357)。
@immutable
class CustomPluginProposal {
  const CustomPluginProposal({required this.pluginId, this.version, required this.name, this.mode = 'shared', this.icon});
  final String pluginId;
  final String? version;
  final String name;
  final String mode;
  final String? icon;

  static CustomPluginProposal? fromPayload(Map<String, Object?> p) {
    final id = p['pluginId'];
    if (id is! String || id.isEmpty) return null;
    return CustomPluginProposal(pluginId: id, version: p['version'] as String?, name: '${p['name'] ?? id}', mode: p['mode'] == 'solo' ? 'solo' : 'shared', icon: p['icon'] as String?);
  }

  Map<String, Object?> toPayload() => {'pluginId': pluginId, 'version': ?version, 'name': name, 'mode': mode, 'icon': ?icon};
}
