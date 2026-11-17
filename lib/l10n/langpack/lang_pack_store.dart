import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_localizations/flutter_localizations.dart' show kMaterialSupportedLanguages;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rasq_design/rasq_design.dart' show RasqDesignLocalizationsOverlay;
import 'package:rasq_models/rasq_models.dart' show RasqLangOverride, RasqModelsLocalizationsOverlay;
import 'package:rasq_plugin_api/rasq_plugin_api.dart' show RasqPluginApiLocalizationsOverlay;
import 'package:sns_misskey/sns_misskey.dart' show SnsMisskeyLocalizationsOverlay;

import '../../features/rai/prompts/rai_prompts.dart' show RaiPromptsJa, raiPromptParams;
import '../app_localizations_overlay.g.dart';
import '../gen/app_localizations.dart';
import 'lang_pack.dart';

export 'lang_pack.dart';

/// このアプリが同梱している文言の形(言語パックを確かめる基準)。
LangPackSchema get appLangPackSchema => LangPackSchema(
      icuDomains: const {
        AppLocalizationsOverlay.domain: AppLocalizationsOverlay.placeholders,
        RasqDesignLocalizationsOverlay.domain: RasqDesignLocalizationsOverlay.placeholders,
        RasqModelsLocalizationsOverlay.domain: RasqModelsLocalizationsOverlay.placeholders,
        RasqPluginApiLocalizationsOverlay.domain: RasqPluginApiLocalizationsOverlay.placeholders,
        SnsMisskeyLocalizationsOverlay.domain: SnsMisskeyLocalizationsOverlay.placeholders,
      },
      raiParams: raiPromptParams,
      raiFunctionNames: [for (final l in const RaiPromptsJa().functionUsage) raiUsageNames(l)],
      bundledLocales: [for (final l in AppLocalizations.supportedLocales) l.toString()],
      canAddLanguage: kMaterialSupportedLanguages.contains,
    );

/// このアプリの版(パックの `app.min` と比べる)。pubspec.yaml の `version` の `+` より前。
const appVersionForLangPacks = '0.1.0';

/// いま効いている言語パック(画面の外からも引けるように写しを持つ)。[apply] が `RasqLangOverride` に差し込む。
abstract final class ActiveLangPack {
  static LangPack? _pack;

  /// いまのパック(null = 公式の文言だけ)。
  static LangPack? get current => _pack;

  /// [pack] を効かせる(null = 外す)。
  static void apply(LangPack? pack) {
    _pack = pack;
    if (pack == null) {
      RasqLangOverride.clear();
      return;
    }
    RasqLangOverride.lookup = pack.lookup;
    RasqLangOverride.baseTagOf = pack.baseTagOf;
    RasqLangOverride.pluginStrings = pack.pluginStrings;
    RasqLangOverride.revision++;
  }
}

/// 置き場(テストで差し替える)。読み込んだパックは 1 つだけ `active.rasqlang` に置く。
final langPackDirProvider = Provider<Future<Directory> Function()>((ref) => () async {
      final base = await getApplicationSupportDirectory();
      return Directory('${base.path}/langpacks');
    });

/// 読み込んだ言語パック (D-592)。null = 公式(同梱)の文言だけ。同時に効くのは 1 つ。
///
/// ファイルから読み込んだパックはいつも**未審査**(パックの `official` は信用しない)。起動のたびに置き場のファイルを
/// 読み直して確かめる(アプリが新しくなってキーが変わっても、足りないキーは同梱の文言になる)。読めなくなったファイルは使わない。
class LangPackNotifier extends AsyncNotifier<LangPack?> {
  static const fileName = 'active.rasqlang';

  @override
  Future<LangPack?> build() async {
    try {
      final f = File('${(await ref.read(langPackDirProvider)()).path}/$fileName');
      if (!f.existsSync()) return _set(null);
      return _set(LangPack.parse(await f.readAsBytes(), appLangPackSchema, appVersion: appVersionForLangPacks));
    } catch (_) {
      return _set(null);
    }
  }

  LangPack? _set(LangPack? p) {
    ActiveLangPack.apply(p);
    return p;
  }

  /// [bytes](`.rasqlang`)を確かめて保存し、効かせる。読めなければ [LangPackException](いまのパックはそのまま)。
  Future<LangPack> install(Uint8List bytes) async {
    final pack = LangPack.parse(bytes, appLangPackSchema, appVersion: appVersionForLangPacks);
    final dir = await ref.read(langPackDirProvider)();
    await dir.create(recursive: true);
    await File('${dir.path}/$fileName').writeAsBytes(bytes, flush: true);
    state = AsyncData(_set(pack));
    return pack;
  }

  /// 外す(公式の文言に戻す)。
  Future<void> remove() async {
    try {
      final f = File('${(await ref.read(langPackDirProvider)()).path}/$fileName');
      if (f.existsSync()) await f.delete();
    } catch (_) {
      // 消せなくても、外すのは効かせる(次の起動で読み直すので、消えていなければまた効く)。
    }
    state = AsyncData(_set(null));
  }
}

final langPackProvider = AsyncNotifierProvider<LangPackNotifier, LangPack?>(LangPackNotifier.new);
