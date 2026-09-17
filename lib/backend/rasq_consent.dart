import 'orgate_client.dart';

/// 同意の記録 (D-241 / S-015 `GET /me/consents`, `PUT /me/consents/{kind}`)。
///
/// 同意は**追記のみ**でサーバーに残る(版・日時・撤回)。RASQ アカウントの登録では利用規約 /
/// プライバシーポリシー / 年齢の申告(18 歳未満は保護者の同意)を取る。学習へのデータ提供
/// (`learning`)はこれとは別の任意の同意で、既定は「なし」(登録の同意には含めない)。

/// 文書の版。文書(`assets/settings/about.terms.rrl.json` など)を変えたら上げる。
const rasqTermsVersion = '2026-09-17-draft';
const rasqPrivacyVersion = '2026-09-17-draft';

/// 年齢の申告。RASQ の利用は 13 歳以上。
enum RasqAgeBand {
  teen('13-15', '13〜15 歳'),
  upperTeen('16-17', '16〜17 歳'),
  adult('18+', '18 歳以上');

  const RasqAgeBand(this.wire, this.label);
  final String wire;
  final String label;

  /// 保護者の同意が要る(18 歳未満)。
  bool get needsGuardian => this != adult;
}

/// 登録の FOW で選んだ内容。
class RasqRegisterChoice {
  const RasqRegisterChoice({required this.age, required this.replaceBundle});
  final RasqAgeBand age;

  /// この端末の SNS アカウントを RASQ アカウントのバンドルにする(サーバーの前のバンドルは置き換わる)。
  /// false = 置き換えない(SNS アカウントは「この端末のみ」に残り、サーバーのバンドルも消さない)。
  final bool replaceBundle;
}

class RasqConsent {
  const RasqConsent({required this.kind, required this.version, required this.granted, this.detail, required this.at});
  final String kind;
  final String version;
  final bool granted;
  final String? detail;
  final DateTime at;

  factory RasqConsent.fromJson(Map<String, Object?> j) => RasqConsent(
        kind: j['kind'] as String? ?? '',
        version: j['version'] as String? ?? '',
        granted: j['granted'] == true,
        detail: j['detail'] as String?,
        at: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
}

class RasqConsentApi {
  const RasqConsentApi(this._client);
  final OrgateClient _client;

  Future<List<RasqConsent>> list() async => [
        for (final e in await _client.getList('/me/consents'))
          if (e is Map) RasqConsent.fromJson(e.cast<String, Object?>()),
      ];

  Future<void> put(String kind, {required String version, required bool granted, String? detail}) =>
      _client.putJson('/me/consents/$kind', {'version': version, 'granted': granted, 'detail': ?detail});

  /// 登録のときの同意をまとめて記録する。
  Future<void> recordRegistration(RasqRegisterChoice c) async {
    await put('terms', version: rasqTermsVersion, granted: true);
    await put('privacy', version: rasqPrivacyVersion, granted: true);
    await put('age', version: rasqTermsVersion, granted: true, detail: c.age.wire);
    if (c.age.needsGuardian) await put('guardian', version: rasqTermsVersion, granted: true);
  }
}
