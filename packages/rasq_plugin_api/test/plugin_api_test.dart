import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:test/test.dart';

void main() {
  test('ActionRef round-trips with colon-bearing account keys', () {
    const ref = ActionRef(pluginId: 'rasq.official.misskey', accountKey: 'misskey:misskey.io:yamada', pluginVersion: '0.1.0', fn: 'renote');
    expect(ref.fq, 'rasq.official.misskey:misskey:misskey.io:yamada:0.1.0:renote');
    expect(ActionRef.tryParse(ref.fq), ref);
    expect(ActionRef.tryParse('broken'), isNull);
  });

  test('automation policy derives from confirmMode and forbidden flag', () {
    expect(const ActionDescriptor(id: 'a', genreTag: 'Repost', label: 'a').automation, AutomationPolicy.allowed);
    expect(const ActionDescriptor(id: 'a', genreTag: 'Repost', label: 'a', confirmMode: ConfirmMode.confirm).automation, AutomationPolicy.humanGate);
    expect(const ActionDescriptor(id: 'a', genreTag: 'Repost', label: 'a', autoHookForbidden: true).automation, AutomationPolicy.forbidden);
  });

  test('manifest json round-trip', () {
    const m = PluginManifest(id: 'x', name: 'X', version: '1.0.0', kind: PluginKind.sns, actions: [ActionDescriptor(id: 'like', genreTag: 'Reaction', label: 'like')]);
    final back = PluginManifest.fromJson(m.toJson());
    expect(back.actions.single.genreTag, 'Reaction');
    expect(back.kind, PluginKind.sns);
  });

  test('SnsPlugin.normalizeHost', () {
    final p = _P();
    expect(p.normalizeHost(' https://Misskey.io/ '), 'misskey.io');
    expect(p.normalizeHost('misskey.io/@user'), 'misskey.io');
  });
}

class _P extends SnsPlugin {
  @override
  PluginManifest get manifest => throw UnimplementedError();
  @override
  Future<AuthFlow> beginAuth(String host, {Uri? callback}) => throw UnimplementedError();
  @override
  Future<ServerInfo> inspectServer(String host) => throw UnimplementedError();
  @override
  get kind => throw UnimplementedError();
  @override
  SnsSession open(AccountSession session) => throw UnimplementedError();
}
