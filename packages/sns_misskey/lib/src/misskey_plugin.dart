import 'package:http/http.dart' as http;
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'miauth.dart';
import 'misskey_api.dart';
import 'misskey_session.dart';

/// Official Misskey plugin (Dart implementation).
class MisskeyPlugin extends SnsPlugin {
  MisskeyPlugin({this.client, this.appName = 'RASQ', this.iconUrl});

  final http.Client? client;
  final String appName;
  final Uri? iconUrl;

  static const pluginId = 'rasq.official.misskey';

  @override
  SnsKind get kind => SnsKind.misskey;

  @override
  PluginManifest get manifest => const PluginManifest(
        id: pluginId,
        name: 'Misskey Plugin',
        version: '0.1.0',
        kind: PluginKind.sns,
        author: 'RASQ Official',
        description: 'Misskeyに接続するためのプラグイン。',
        supportedSns: [SnsKind.misskey],
        permissions: ['network', 'storage.safe', 'register_action'],
        actions: MisskeySession.defaultActions,
        official: true,
        verified: true,
        termsOfService: '''
## Misskey Plugin の規約

このプラグインの利用にあたって、ユーザーは接続先 Misskey インスタンスの利用規約を遵守して利用するものとします。
アクセストークンは端末内の安全な領域にのみ保存され、RASQ のサーバーへ送信されることはありません。

### 第一項　プラグインの再配布の禁止
''',
      );

  @override
  Future<ServerInfo> inspectServer(String host) async {
    final h = normalizeHost(host);
    final api = MisskeyApi(h, client: client);
    final meta = await api.callMap('meta', {'detail': false});
    return ServerInfo(
      host: h,
      name: (meta['name'] as String?)?.isNotEmpty == true ? meta['name'] as String : h,
      software: 'misskey',
      version: meta['version'] as String?,
      description: meta['description'] as String?,
      iconUrl: meta['iconUrl'] is String ? Uri.tryParse(meta['iconUrl'] as String) : null,
      registrationOpen: meta['disableRegistration'] == null ? null : meta['disableRegistration'] != true,
      maintainer: meta['maintainerName'] as String?,
    );
  }

  @override
  Future<AuthFlow> beginAuth(String host, {Uri? callback}) async => MiAuthFlow(
        host: normalizeHost(host),
        pluginId: pluginId,
        permissions: MiAuthFlow.defaultPermissions,
        appName: appName,
        iconUrl: iconUrl,
        callback: callback,
        client: client,
      );

  @override
  SnsSession open(AccountSession session) => MisskeySession(session, client: client);
}
