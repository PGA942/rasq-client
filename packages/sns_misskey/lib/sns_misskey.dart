/// Misskey adapter (phase-1 first SNS, D-010 — MiAuth).
///
/// This is the Dart twin of `ORGATE-question/misskey-wasm-sample`: it fulfils
/// the `SnsPlugin` / `SnsSession` contract so the app can run end-to-end while
/// the WASM boundary is being designed.
library;

export 'src/misskey_api.dart';
export 'src/misskey_plugin.dart';
export 'src/misskey_session.dart';
export 'src/miauth.dart';
export 'src/mappers.dart';
export 'src/settings_pages.dart' show MisskeyAccountSettings;
export 'src/l10n.dart' show snsMisskeyL10n, SnsMisskeyLocalizations, lookupSnsMisskeyLocalizations;
