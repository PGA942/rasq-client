import 'dart:typed_data';

import 'package:file_selector/file_selector.dart' as fs;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart' show RasqUiLocale;
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import '../../l10n/l10n.dart';
import '../../l10n/langpack/lang_pack_store.dart';
import '../../l10n/ui_locale.dart';
import '../../shell/headers.dart';

/// アプリの外観 → 言語 (D-484): 「システムに合わせる」か、対応する言語(gen-l10n の一覧から作る)を選ぶ。
/// 端末に保存し(KV `appearance.language.v1`)、すぐ画面に反映する。言語の名前は、その言語の訳の `languageSelfName`。
class LanguageSettingsScreen extends ConsumerWidget {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final setting = ref.watch(uiLocaleSettingProvider);
    final current = ref.watch(uiLocaleProvider);
    // 選んでいる値: 対応する言語のどれか / null(システムに合わせる)。保存値が対応していない言語なら「システム」扱い。
    final chosen = supportedUiLocales.where((s) => s.toLanguageTag() == setting).firstOrNull;
    return Scaffold(
      appBar: RasqPageHeader(title: l.languageSettingsTitle),
      body: ListView(children: [
        RasqCaption(
          l.languageSettingsCaption,
          detail: l.languageSettingsCaptionDetail,
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.md, RasqSpacing.page, 0),
        ),
        RasqSectionHeader(title: l.languageSettingsListHeader),
        RasqRadioListTile<String>(
          key: const ValueKey('language.system'),
          title: l.languageSettingsSystem,
          subtitle: l.languageSettingsSystemCurrent(appL10nFor(current).languageSelfName),
          value: systemLocaleSetting,
          groupValue: chosen == null ? systemLocaleSetting : chosen.toLanguageTag(),
          onChanged: (_) => setUiLocaleSetting(ref, null),
        ),
        for (final locale in supportedUiLocales)
          RasqRadioListTile<String>(
            key: ValueKey('language.${locale.toLanguageTag()}'),
            title: uiLocaleSelfName(locale),
            subtitle: langPackAddedLocales.contains(locale) ? l.langPackAddedLocale : null,
            value: locale.toLanguageTag(),
            groupValue: chosen == null ? systemLocaleSetting : chosen.toLanguageTag(),
            onChanged: (v) => setUiLocaleSetting(ref, v),
          ),
        const LangPackSection(),
      ]),
    );
  }
}

/// 表示の言語をその場で変えるボタン (D-575)。新規登録(オンボーディング)の画面の左上に置く(設定を開く前の人が、読めない言語の
/// まま進まなくてよいように)。中身は設定 → 言語([LanguageSettingsScreen])と同じ: 「システムに合わせる」か対応する言語を選び、
/// 端末に保存してすぐ反映する。ボタンには地球のアイコンと、いまの言語の名前(その言語で)を出す。
class LanguageQuickButton extends ConsumerWidget {
  const LanguageQuickButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final setting = ref.watch(uiLocaleSettingProvider);
    final current = ref.watch(uiLocaleProvider);
    final chosen = supportedUiLocales.where((s) => s.toLanguageTag() == setting).firstOrNull;
    return Builder(
      builder: (ctx) => TextButton.icon(
        key: const ValueKey('language.quick'),
        style: TextButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.sm), visualDensity: VisualDensity.compact),
        icon: const Icon(Icons.language, size: 18),
        label: Text(appL10nFor(current).languageSelfName, style: RasqTypography.bodySmall),
        onPressed: () async {
          final box = ctx.findRenderObject() as RenderBox;
          final picked = await ref.read(overlayManagerProvider).showDropdown<String>(
            id: 'language.quick',
            anchor: box.localToGlobal(Offset.zero) & box.size,
            items: [
              RasqDropdownItem(l.languageSettingsSystem, systemLocaleSetting, checked: chosen == null),
              for (final locale in supportedUiLocales)
                RasqDropdownItem(uiLocaleSelfName(locale), locale.toLanguageTag(), checked: chosen == locale),
            ],
          );
          if (picked == null) return;
          await setUiLocaleSetting(ref, picked == systemLocaleSetting ? null : picked);
        },
      ),
    );
  }
}

/// [locale] の、その言語での名前。言語パックが足した言語は、パックが付けた名前(無ければパックの `languageSelfName`)。
String uiLocaleSelfName(Locale locale) {
  for (final l in ActiveLangPack.current?.addedLocales ?? const <LangPackLocale>[]) {
    if (normLangTag(l.tag) == normLangTag(locale.toLanguageTag()) && (l.name ?? '').isNotEmpty) return l.name!;
  }
  return appL10nFor(locale).languageSelfName;
}

/// 言語パックのファイル(.rasqlang)を選ぶ口(テストで差し替える)。null = やめた。
final langPackPickerProvider = Provider<Future<Uint8List?> Function()>((ref) => () async {
      final f = await fs.openFile(acceptedTypeGroups: [fs.XTypeGroup(label: appL10n.langPackPickerLabel, extensions: const ['rasqlang', 'json'])]);
      return f == null ? null : await f.readAsBytes();
    });

/// 設定 → 言語 の「言語パック」(D-592): いまのパック(公式 / 読み込んだ非公式のパック。非公式はいつも「未審査」)、
/// ファイルから読み込む、外す。読み込んだ結果(差し替えた数・形が合わず捨てた数・知らないキーの数)と、捨てた文の一覧。
class LangPackSection extends ConsumerStatefulWidget {
  const LangPackSection({super.key});

  @override
  ConsumerState<LangPackSection> createState() => _LangPackSectionState();
}

class _LangPackSectionState extends ConsumerState<LangPackSection> {
  String? _error;
  bool _busy = false;
  bool _showIssues = false;

  String _errorText(AppLocalizations l, LangPackException e) => switch (e.error) {
        LangPackError.tooLarge => l.langPackErrorTooLarge,
        LangPackError.notPack => l.langPackErrorNotPack,
        LangPackError.unsupportedVersion => l.langPackErrorUnsupportedVersion,
        LangPackError.badManifest => l.langPackErrorManifest(e.detail),
        LangPackError.noLocales => l.langPackErrorNoLocales,
      };

  Future<void> _import() async {
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final bytes = await ref.read(langPackPickerProvider)();
      if (bytes == null) return;
      final pack = await ref.read(langPackProvider.notifier).install(bytes);
      if (mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(appL10n.langPackLoaded(pack.nameFor(RasqUiLocale.tag)))));
    } on LangPackException catch (e) {
      if (mounted) setState(() => _error = _errorText(context.l10n, e));
    } catch (e) {
      if (mounted) setState(() => _error = context.l10n.langPackErrorFailed('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final pack = ref.watch(langPackProvider).value;
    final caption = RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant);
    final r = pack?.report;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      RasqSectionHeader(title: l.langPackHeader),
      RasqCaption(
        l.langPackCaption,
        detail: l.langPackCaptionDetail,
        padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.xs),
      ),
      if (pack == null)
        RasqListTile(
          key: const ValueKey('langpack.official'),
          leading: const Icon(Icons.verified_outlined),
          title: l.langPackOfficial,
          subtitle: l.langPackOfficialSubtitle,
        )
      else ...[
        RasqListTile(
          key: ValueKey('langpack.active.${pack.id}'),
          leading: const Icon(Icons.translate),
          title: pack.nameFor(RasqUiLocale.tag),
          subtitle: [
            l.langPackSubtitle(pack.version, pack.authors.join(', ')),
            l.langPackUnreviewed,
          ].join(' · '),
          trailing: RasqIconButton(
            key: const ValueKey('langpack.remove'),
            icon: Icons.delete_outline,
            size: 20,
            tooltip: l.langPackRemove,
            onPressed: () => ref.read(langPackProvider.notifier).remove(),
          ),
        ),
        Padding(
          key: const ValueKey('langpack.report'),
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.xs),
          child: Text(
            [
              if (pack.description.isNotEmpty) pack.description,
              l.langPackApplied(r!.applied),
              if (r.rejected.isNotEmpty) l.langPackRejected(r.rejected.length),
              if (r.unknown > 0) l.langPackUnknown(r.unknown),
              if (r.needsNewerApp) l.langPackNeedsNewerApp(pack.appMin ?? ''),
            ].join('\n'),
            style: caption,
          ),
        ),
        if (r.rejected.isNotEmpty) ...[
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page - RasqSpacing.sm),
              child: TextButton(
                key: const ValueKey('langpack.issues'),
                onPressed: () => setState(() => _showIssues = !_showIssues),
                child: Text(_showIssues ? l.langPackHideIssues : l.langPackShowIssues),
              ),
            ),
          ),
          if (_showIssues)
            Padding(
              key: const ValueKey('langpack.issueList'),
              padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.sm),
              // パックを作る人向けの、訳さない短い説明(キーと理由)。
              child: SelectableText(r.rejected.take(200).map((i) => '$i').join('\n'), style: caption.copyWith(fontFamily: 'monospace')),
            ),
        ],
      ],
      RasqListTile(
        key: const ValueKey('langpack.import'),
        leading: _busy ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.file_open_outlined),
        title: l.langPackImport,
        onTap: _busy ? null : _import,
      ),
      if (_error != null)
        Padding(
          key: const ValueKey('langpack.error'),
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.xs),
          child: Text(_error!, style: RasqTypography.caption.copyWith(color: RasqColors.danger)),
        ),
    ]);
  }
}
