import 'dart:io' show Directory, File, Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_selector/file_selector.dart' as fs;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/error_journal.dart';
import '../../app/providers.dart';
import '../../l10n/l10n.dart';
import '../../shell/headers.dart';
import '../plugins/slot_plugins.dart' show rootMessengerKeyProvider;

/// バグレポート (D-570): 端末に残った例外([ErrorJournalRecorder])を見せて、全文をコピー / ファイルに保存する。
/// 設定 → RASQ について → バグレポート。
///
/// 当面はベータ版の利用者に**スクリーンショットで送ってもらう**ので、画面は 1〜2 枚に要点が収まる形にする:
/// 上から 端末(版 / 組み立て / OS / 端末 / 画面)→ 最初の例外(時刻 / 型 / 要約 / 場所 / 部品の経路の先頭 / スタックの先頭 3 行)→
/// 直近の例外(1 行ずつ)。全文(ほかの起動・スタック 10 行)はコピー / 保存で。記録は伏せたあとのもの(投稿の本文・トークン・
/// ハンドル・URL・端末の名前は入らない)。

/// 端末の情報(版 / OS / 端末の型 / 画面 / 言語)。端末の名前(「〇〇の iPad」)は読まない。
@immutable
class BugReportEnv {
  const BugReportEnv({required this.appVersion, required this.buildMode, required this.os, required this.device, this.screen, this.locale, this.gitSha});
  final String appVersion;
  final String buildMode;
  final String os;
  final String device;
  final String? screen;
  final String? locale;
  final String? gitSha;
}

/// 端末の型(iPad14,5 など)。テストで差し替える。
final bugReportDeviceModelProvider = FutureProvider<String>((ref) async {
  if (kIsWeb) return 'web';
  try {
    final info = DeviceInfoPlugin();
    if (Platform.isIOS) {
      final i = await info.iosInfo;
      return '${i.model} (${i.utsname.machine})';
    }
    if (Platform.isAndroid) {
      final a = await info.androidInfo;
      return '${a.manufacturer} ${a.model} (SDK ${a.version.sdkInt})';
    }
    if (Platform.isMacOS) return (await info.macOsInfo).model;
  } catch (_) {}
  return defaultTargetPlatform.name;
});

BugReportEnv bugReportEnvOf(BuildContext context, {required String device}) {
  final mq = MediaQuery.maybeOf(context);
  final size = mq?.size;
  final dpr = mq?.devicePixelRatio ?? 1;
  return BugReportEnv(
    appVersion: rasqAppVersion,
    buildMode: rasqBuildMode,
    os: currentOsDescription(),
    device: device,
    screen: size == null ? currentScreenSize() : '${size.width.round()}×${size.height.round()} @${dpr.toStringAsFixed(dpr == dpr.roundToDouble() ? 0 : 2)}x',
    locale: Localizations.maybeLocaleOf(context)?.toLanguageTag(),
    gitSha: rasqGitSha.isEmpty ? null : rasqGitSha,
  );
}

String _ts(DateTime t) {
  final l = t.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}:${two(l.second)}';
}

/// 全文(コピー / 保存)。読むのは開発者なので、見出しは言語に依らず英語で固定する。
String buildBugReportText(ErrorJournal journal, BugReportEnv env, {DateTime? now}) {
  final b = StringBuffer()
    ..writeln('RASQ bug report') // l10n-ignore
    ..writeln('generated: ${_ts(now ?? DateTime.now())}') // l10n-ignore
    ..writeln('app: ${env.appVersion} (${env.buildMode})${env.gitSha == null ? '' : ' ${env.gitSha}'}') // l10n-ignore
    ..writeln('os: ${env.os}') // l10n-ignore
    ..writeln('device: ${env.device}') // l10n-ignore
    ..writeln('screen: ${env.screen ?? '?'}') // l10n-ignore
    ..writeln('locale: ${env.locale ?? '?'}'); // l10n-ignore
  if (journal.isEmpty) {
    b.writeln('\n(no errors recorded)'); // l10n-ignore
    return b.toString();
  }
  void record(String label, ErrorRecord r) {
    b
      ..writeln('\n-- $label @ ${_ts(r.at)} [${r.source}${r.library == null ? '' : ' / ${r.library}'}]') // l10n-ignore
      ..writeln('type: ${r.type}') // l10n-ignore
      ..writeln('summary: ${r.summary}'); // l10n-ignore
    if (r.context != null) b.writeln('where: ${r.context}'); // l10n-ignore
    if (r.screen != null) b.writeln('screen at error: ${r.screen}'); // l10n-ignore
    if (r.widgetPath.isNotEmpty) {
      b.writeln('widget path:'); // l10n-ignore
      for (final l in r.widgetPath) {
        b.writeln('  $l');
      }
    }
    if (r.stack.isNotEmpty) {
      b.writeln('stack:'); // l10n-ignore
      for (final l in r.stack) {
        b.writeln('  $l');
      }
    }
  }

  for (final (i, l) in journal.launches.indexed) {
    b.writeln('\n==== launch ${i + 1}: started ${_ts(l.startedAt)}, ${l.count} error(s) ===='); // l10n-ignore
    record('FIRST', l.first); // l10n-ignore
    for (final (j, r) in l.recent.indexed) {
      record('recent ${j + 1}', r); // l10n-ignore
    }
  }
  return b.toString();
}

/// ファイル名(時刻入り)。
String bugReportFileName(DateTime now) {
  String two(int v) => v.toString().padLeft(2, '0');
  return 'rasq-bug-report-${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}${two(now.second)}.txt';
}

/// iPhone / iPad で保存するフォルダー(「ファイル」App の このiPad › RASQ の下。端末の上の名前なので言語に依らない)。
const _iosReportFolder = 'バグレポート'; // l10n-ignore

/// 保存できる端末か(iOS = 「ファイル」App の書類フォルダ、デスクトップ = 保存先を選ぶ)。Android / Web はコピーだけ。
bool get bugReportCanSave => !kIsWeb && (Platform.isIOS || Platform.isMacOS || Platform.isWindows || Platform.isLinux);

/// 全文をファイルに書く。書いた場所(画面に出す)/ やめたら null。テストで差し替える。
final bugReportSaverProvider = Provider<Future<String?> Function(String name, String text)>((ref) => (name, text) async {
      if (Platform.isIOS) {
        final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/$_iosReportFolder');
        await dir.create(recursive: true);
        await File('${dir.path}/$name').writeAsString(text, flush: true);
        return '$_iosReportFolder/$name';
      }
      final downloads = await getDownloadsDirectory();
      final loc = await fs.getSaveLocation(suggestedName: name, initialDirectory: downloads?.path);
      if (loc == null) return null;
      await File(loc.path).writeAsString(text, flush: true);
      return loc.path;
    });

const bugReportCopyKey = ValueKey('bugReport.copy');
const bugReportSaveKey = ValueKey('bugReport.save');
const bugReportClearKey = ValueKey('bugReport.clear');
const bugReportFirstKey = ValueKey('bugReport.first');

class BugReportScreen extends ConsumerWidget {
  const BugReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final recorder = ref.watch(errorJournalProvider);
    final device = ref.watch(bugReportDeviceModelProvider).value ?? '…';
    return Scaffold(
      appBar: RasqPageHeader(title: l.bugReportTitle),
      body: ListenableBuilder(
        listenable: recorder,
        builder: (context, _) {
          final journal = recorder.journal;
          final env = bugReportEnvOf(context, device: device);
          final latest = journal.latest;
          final scheme = Theme.of(context).colorScheme;
          final mono = RasqTypography.caption.copyWith(fontFamily: 'Menlo', fontFamilyFallback: const ['Courier', 'monospace'], fontSize: 11, color: scheme.onSurfaceVariant);
          Widget kv(String k, String v) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 96, child: Text(k, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant))),
                  Expanded(child: SelectableText(v, style: RasqTypography.bodySmall)),
                ]),
              );
          Widget card(List<Widget> children, {Key? key}) => Container(
                key: key,
                margin: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.sm),
                padding: const EdgeInsets.all(RasqSpacing.md),
                decoration: BoxDecoration(border: Border.all(color: scheme.outlineVariant), borderRadius: BorderRadius.circular(12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
              );
          return ListView(padding: const EdgeInsets.only(bottom: RasqSpacing.xl), children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.sm),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(l.bugReportIntro, style: RasqTypography.bodySmall),
                const SizedBox(height: 4),
                Text(l.bugReportPrivacyNote, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
              ]),
            ),
            // 端末 = 1 枚目の上。
            RasqSectionHeader(title: l.bugReportDeviceHeader),
            card([
              kv(l.bugReportAppVersion, '${env.appVersion} (${env.buildMode})${env.gitSha == null ? '' : ' · ${env.gitSha}'}'),
              kv(l.bugReportOs, env.os),
              kv(l.bugReportDevice, env.device),
              kv(l.bugReportScreen, env.screen ?? '?'),
              kv(l.bugReportLocale, env.locale ?? '?'),
              kv(l.bugReportNow, _ts(DateTime.now())),
            ]),
            if (latest == null)
              Padding(padding: const EdgeInsets.all(RasqSpacing.page), child: Text(l.bugReportEmpty, key: const ValueKey('bugReport.empty'), style: RasqTypography.bodySmall))
            else ...[
              RasqSectionHeader(title: l.bugReportFirstHeader),
              card(key: bugReportFirstKey, [
                Text(l.bugReportFirstCaption(_ts(latest.startedAt), latest.count), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 6),
                kv(l.bugReportTime, _ts(latest.first.at)),
                kv(l.bugReportType, '${shortErrorType(latest.first.type)} · ${latest.first.source}${latest.first.library == null ? '' : ' / ${latest.first.library}'}'),
                Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(latest.first.summary, maxLines: 5, overflow: TextOverflow.ellipsis, style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w600))),
                if (latest.first.context != null) kv(l.bugReportWhere, latest.first.context!),
                if (latest.first.screen != null) kv(l.bugReportScreen, latest.first.screen!),
                if (latest.first.widgetPath.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(l.bugReportWidgetPath, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
                  for (final p in latest.first.widgetPath.take(4)) Text(p, maxLines: 2, overflow: TextOverflow.ellipsis, style: mono),
                ],
                if (latest.first.stack.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(l.bugReportStack, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
                  for (final p in latest.first.stack.take(3)) Text(p, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono),
                ],
              ]),
              if (latest.recent.isNotEmpty) ...[
                RasqSectionHeader(title: l.bugReportRecentHeader),
                card([
                  for (final r in latest.recent)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('${_ts(r.at).substring(11)}  ${shortErrorType(r.type)}: ${r.summary.split('\n').first}', maxLines: 2, overflow: TextOverflow.ellipsis, style: RasqTypography.caption),
                    ),
                ]),
              ],
              if (journal.launches.length > 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
                  child: Text(l.bugReportOlderLaunches(journal.launches.length - 1), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
                ),
            ],
            const SizedBox(height: RasqSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
              child: Wrap(spacing: RasqSpacing.sm, runSpacing: RasqSpacing.sm, children: [
                FilledButton.icon(key: bugReportCopyKey, onPressed: () => _copy(ref, buildBugReportText(journal, env)), icon: const Icon(Icons.copy_all_outlined, size: 18), label: Text(l.bugReportCopyButton)),
                if (bugReportCanSave) OutlinedButton.icon(key: bugReportSaveKey, onPressed: () => _save(ref, buildBugReportText(journal, env)), icon: const Icon(Icons.save_alt, size: 18), label: Text(l.bugReportSaveButton)),
                if (!journal.isEmpty) TextButton(key: bugReportClearKey, onPressed: () => _clear(ref), child: Text(l.bugReportClearButton)),
              ]),
            ),
          ]);
        },
      ),
    );
  }

  void _snack(WidgetRef ref, String m) => ref.read(rootMessengerKeyProvider).currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  Future<void> _copy(WidgetRef ref, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    _snack(ref, appL10n.bugReportCopied);
  }

  Future<void> _save(WidgetRef ref, String text) async {
    try {
      final where = await ref.read(bugReportSaverProvider)(bugReportFileName(DateTime.now()), text);
      if (where != null) _snack(ref, appL10n.bugReportSaved(where));
    } catch (e) {
      _snack(ref, appL10n.bugReportSaveFailed(redactReportText('$e')));
    }
  }

  Future<void> _clear(WidgetRef ref) async {
    final ok = await ref.read(overlayManagerProvider).showAlert(
          id: 'bugReport.clear.confirm',
          title: appL10n.bugReportClearConfirmTitle,
          message: appL10n.bugReportClearConfirmMessage,
          confirmText: appL10n.bugReportClearButton,
          cancelText: appL10n.bugReportCancel,
          destructive: true,
        );
    if (!ok) return;
    await ref.read(errorJournalProvider).clear();
    _snack(ref, appL10n.bugReportCleared);
  }
}
