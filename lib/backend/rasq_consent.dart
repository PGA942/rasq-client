import 'legal_docs.g.dart';
import 'orgate_client.dart';
import '../l10n/l10n.dart';

/// 同意の記録 (D-241 / S-015 `GET /me/consents`, `PUT /me/consents/{kind}`)。
///
/// 同意は**追記のみ**でサーバーに残る(版・日時・撤回)。RASQ アカウントの登録では利用規約 /
/// プライバシーポリシー / 年齢の申告(18 歳未満は保護者の同意)を取る。学習へのデータ提供
/// (`learning`)はこれとは別の任意の同意で、既定は「なし」(登録の同意には含めない)。

/// 文書の版。文書(`assets/settings/about.terms.rrl.json` など)を変えたら上げる。
/// 承諾を求める版 (D-372): 規約・ポリシーの文書の版(`legal_docs.g.dart`、Central の CENTRAL_TERMS_VERSION / CENTRAL_PRIVACY_VERSION と同じ)。
const rasqTermsVersion = rasqLegalVersion;
const rasqPrivacyVersion = rasqLegalVersion;

/// 年齢の申告。RASQ の利用は 13 歳以上。
enum RasqAgeBand {
  teen('13-15'),
  upperTeen('16-17'),
  adult('18+');

  const RasqAgeBand(this.wire);
  final String wire;

  /// 表示の名前(表示の言語)。
  String get label => switch (this) { teen => appL10n.backendAgeTeen, upperTeen => appL10n.backendAgeUpperTeen, adult => appL10n.backendAgeAdult };

  /// 保護者の同意が要る(18 歳未満)。
  bool get needsGuardian => this != adult;
}

/// サーバーが規約の版を断った (`409 terms_version`、D-371 / S-053): アプリに入っている規約が古い。
/// 名前つきの理由で見る (D-503)。古いサーバーは 409 と英語の文。
bool isTermsVersionError(Object e) => e is OrgateException && (e.serverCode == 'terms_version' || (e.code.code == '409' && e.isReason('terms_version', legacyText: 'current version')));

/// 利用規約の承諾が先 (`403 terms_required`)。
bool isTermsRequiredError(Object e) => e is OrgateException && e.isReason('terms_required', legacyText: 'accept the current terms');

/// 登録の FOW で選んだ内容。
class RasqRegisterChoice {
  const RasqRegisterChoice({required this.age, required this.replaceBundle, this.password = ''});
  final RasqAgeBand age;

  /// 登録と同時に設定するパスワード (D-299。必須: ほかの端末 / Web 版から入る手段になる)。
  final String password;

  /// この端末の SNS アカウントを RASQ アカウントのバンドルにする(サーバーの前のバンドルは置き換わる)。
  /// false = 置き換えない(SNS アカウントは「この端末のみ」に残り、サーバーのバンドルも消さない)。
  final bool replaceBundle;

  /// 登録と一緒に送る承諾 (D-371 / S-053): アカウントの作成と同じ処理で残り、版が違えば作成ごと失敗する。
  Map<String, Object?> toConsentsJson() => {
        'termsVersion': rasqTermsVersion,
        'privacyVersion': rasqPrivacyVersion,
        'age': age.wire,
        'guardian': age.needsGuardian,
      };
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

  /// いまの版の利用規約を承諾する(同意待ちのアカウント、D-371)。年齢の申告が無ければ [age] も。
  Future<void> acceptCurrent({RasqAgeBand? age}) async {
    await put('terms', version: rasqTermsVersion, granted: true);
    await put('privacy', version: rasqPrivacyVersion, granted: true);
    if (age != null) {
      await put('age', version: rasqTermsVersion, granted: true, detail: age.wire);
      if (age.needsGuardian) await put('guardian', version: rasqTermsVersion, granted: true);
    }
  }

  /// 登録のときの同意をまとめて記録する(古いサーバー向け。いまは登録と一緒に送る)。
  Future<void> recordRegistration(RasqRegisterChoice c) async {
    await put('terms', version: rasqTermsVersion, granted: true);
    await put('privacy', version: rasqPrivacyVersion, granted: true);
    await put('age', version: rasqTermsVersion, granted: true, detail: c.age.wire);
    if (c.age.needsGuardian) await put('guardian', version: rasqTermsVersion, granted: true);
  }
}
