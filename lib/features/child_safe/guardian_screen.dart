import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../backend/orgate_client.dart';
import '../../shell/headers.dart';
import '../plugins/slot_plugins.dart';
import '../store/store_providers.dart' show installedPluginsProvider;
import '../trend/example_match.dart';
import '../trend/example_picker.dart';
import '../trend/example_sources.dart';
import 'child_gate.dart';
import 'child_safe_api.dart';
import 'child_safe_links.dart';
import 'child_safe_policy.dart';
import 'child_safe_screens.dart' show childSafeSummaryLines;

/// 保護者の画面 (D-307): 確認の状態 / 見守っている子 / 子のアカウントを作る / コードでつなぐ / 子ごとの設定・要約・終わり。
/// **許す / 止めるの一覧の編集はアプリだけ**(Web コンソールは確認 / つなぐ / 終える / 読むだけの要約)。

final childSafeGuardianProvider = FutureProvider.autoDispose<ChildSafeGuardianInfo>((ref) async {
  final api = ref.watch(childSafeApiProvider);
  if (api == null) throw StateError('RASQ Central の接続先が未設定です');
  return api.guardian();
});

/// カタログ(取れなければ控え)。
final childSafeCatalogProvider = FutureProvider.autoDispose<ChildSafeCatalog>((ref) async {
  final api = ref.watch(childSafeApiProvider);
  if (api == null) return ChildSafeCatalog.fallback;
  try {
    return await api.catalog();
  } on OrgateException catch (e) {
    debugPrint('child-safe: catalog unavailable (${e.code.code})');
    return ChildSafeCatalog.fallback;
  }
});

final childSafeChildDetailProvider = FutureProvider.autoDispose.family<ChildSafeChildDetail, String>((ref, handle) async {
  final api = ref.watch(childSafeApiProvider);
  if (api == null) throw StateError('RASQ Central の接続先が未設定です');
  return api.child(handle);
});

Widget _pad(Widget child) => Padding(padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, RasqSpacing.xs), child: child);

String _stateLabel(ChildSafeChildRow c) => c.pending ? '設定待ち' : (c.applied ? '見守り中(端末に届いています)' : '見守り中(設定 ${c.revision} はまだ端末に届いていません)');
String _fmt(DateTime? t) {
  if (t == null) return '';
  final l = t.toLocal();
  return '${l.month}/${l.day} ${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

/// Web コンソールの保護者の確認 (`/console/child/verify`) を外のブラウザで開く。
Future<void> openGuardianVerification(WidgetRef ref) async {
  final base = ref.read(centralBaseUrlProvider);
  if (base == null) return;
  await launchUrl(base.replace(path: '${base.path}/console/child/verify'), mode: LaunchMode.externalApplication);
}

/// マイナンバーカード (JPKI) での確認: 誓約に同意してもらってから `POST …/guardian/jpki/start {country: JP, pledgeVersion}`、
/// 返った URL(デジタル認証アプリへ / 開発用のダミーは Central の相対パス)を外のブラウザで開く。
/// 誓約の版がアプリの知っている版と違えば、Web コンソールへ回す。
Future<void> startJpkiVerification(WidgetRef ref, ChildSafeGuardianInfo g) async {
  if (g.pledgeVersion != childSafePledgeVersion) return openGuardianVerification(ref);
  final ok = await ref.read(overlayManagerProvider).showAlert(
        id: 'childSafe.pledge',
        title: '保護者の誓約(版 $childSafePledgeVersion)',
        message: '${[for (final l in childSafePledge) '・$l'].join('\n')}\n\n同意すると、マイナンバーカード(デジタル認証アプリ)での確認に進みます(日本にお住まいの方)。',
        confirmText: '同意して進む',
        cancelText: 'キャンセル',
      );
  final api = ref.read(childSafeApiProvider);
  final base = ref.read(centralBaseUrlProvider);
  if (!ok || api == null || base == null) return;
  final url = await api.jpkiStart(pledgeVersion: childSafePledgeVersion);
  if (url == null || url.isEmpty) return;
  final target = url.startsWith('/') ? base.replace(path: '${base.path.replaceFirst(RegExp(r'/$'), '')}${Uri.parse(url).path}', query: Uri.parse(url).query) : Uri.parse(url);
  await launchUrl(target, mode: LaunchMode.externalApplication);
}

/// `/child-safe/guardian`。
class GuardianScreen extends ConsumerStatefulWidget {
  const GuardianScreen({super.key});
  @override
  ConsumerState<GuardianScreen> createState() => _GuardianScreenState();
}

class _GuardianScreenState extends ConsumerState<GuardianScreen> {
  final _handle = TextEditingController();
  final _name = TextEditingController();
  String _band = '13-15';
  bool _creating = false;
  bool _busy = false;
  String? _error;

  /// 1 度だけ見せるもの(ログインのコード / つなぐコード)。
  ({String title, String code, DateTime? expiresAt, String? link})? _shown;

  @override
  void dispose() {
    _handle.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function(ChildSafeApi api) action) async {
    final api = ref.read(childSafeApiProvider);
    if (api == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action(api);
      ref.invalidate(childSafeGuardianProvider);
    } catch (e) {
      if (mounted) setState(() => _error = childSafeErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final caption = RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant);
    final info = ref.watch(childSafeGuardianProvider);
    return Scaffold(
      appBar: const RasqPageHeader(title: '見守る(保護者)'),
      body: info.when(
        loading: () => const RasqLoading(),
        error: (e, _) => RasqEmptyView(title: '読み込めませんでした', hint: childSafeErrorMessage(e), action: TextButton(onPressed: () => ref.invalidate(childSafeGuardianProvider), child: const Text('再読み込み'))),
        data: (g) {
          final verified = g.status.verified;
          return ListView(padding: const EdgeInsets.only(bottom: RasqSpacing.xl), children: [
            const RasqSectionHeader(title: '保護者の確認'),
            RasqValueListTile(
              key: const ValueKey('guardian.verified'),
              title: verified ? '確認済み' : 'まだ確認していません',
              value: verified ? '${g.status.methodLabel}${g.status.country == null ? '' : '・${g.status.country}'}${g.status.verifiedAt == null ? '' : '・${_fmt(g.status.verifiedAt)}'}' : '',
            ),
            if (!verified) ...[
              _pad(Text('子のアカウントを作る / つなぐ前に、保護者の確認をします(日本はマイナンバーカード (JPKI)、ほかの国は Web コンソールでの自己申告)。', style: caption)),
              if (g.jpkiAvailable)
                RasqListTile(
                  key: const ValueKey('guardian.verify.jpki'),
                  title: 'マイナンバーカードで確認する',
                  subtitle: '日本にお住まいの方。誓約に同意してから、外のブラウザで開きます${g.jpkiMode == 'dummy' ? '(開発用のダミー)' : ''}',
                  enabled: !_busy,
                  onTap: () => _run((_) => startJpkiVerification(ref, g)),
                ),
              RasqListTile(key: const ValueKey('guardian.verify'), title: 'Web コンソールで確認する', subtitle: '外のブラウザで開きます', onTap: () => openGuardianVerification(ref)),
            ],
            RasqSectionHeader(title: '見守っている子(${g.children.length} / 8)'),
            if (g.children.isEmpty) _pad(Text('まだいません。', style: caption)),
            for (final c in g.children)
              RasqListTile(
                key: ValueKey('guardian.child.${c.handle}'),
                title: '${c.displayName.isEmpty ? c.handle : c.displayName}  @${c.handle}',
                subtitle: '${_stateLabel(c)}・${c.ageBand}${c.createdByGuardian ? '・保護者が作成' : ''}',
                onTap: () => context.push('/child-safe/guardian/${Uri.encodeComponent(c.handle)}'),
              ),
            if (_shown != null) _OneTimeCode(title: _shown!.title, code: _shown!.code, expiresAt: _shown!.expiresAt, link: _shown!.link, onClose: () => setState(() => _shown = null)),
            if (_error != null) _pad(Text(_error!, key: const ValueKey('guardian.error'), style: caption.copyWith(color: scheme.error))),
            const RasqSectionHeader(title: '子を足す'),
            RasqListTile(
              key: const ValueKey('guardian.create'),
              title: '子のアカウントを作る',
              subtitle: 'ハンドル / 名前 / 年齢の帯を決めると、子の端末でログインするためのコードが 1 度だけ出ます',
              enabled: verified && !_busy,
              chevron: false,
              onTap: () => setState(() => _creating = !_creating),
            ),
            if (_creating && verified) ...[
              _pad(RasqInput(key: const ValueKey('guardian.create.handle'), controller: _handle, hintText: 'ハンドル(英数字)')),
              _pad(RasqInput(key: const ValueKey('guardian.create.name'), controller: _name, hintText: '表示名')),
              _pad(SegmentedButton<String>(
                key: const ValueKey('guardian.create.band'),
                segments: [for (final b in childSafeChildBands) ButtonSegment(value: b, label: Text(b))],
                selected: {_band},
                onSelectionChanged: (s) => setState(() => _band = s.first),
              )),
              _pad(FilledButton(
                key: const ValueKey('guardian.create.submit'),
                onPressed: _busy
                    ? null
                    : () => _run((api) async {
                          final r = await api.createChild(handle: _handle.text.trim().replaceFirst('@', ''), displayName: _name.text.trim(), ageBand: _band);
                          setState(() {
                            _creating = false;
                            _handle.clear();
                            _name.clear();
                            _shown = (title: '@${r.handle} のログインのコード(子の端末の「保護者からのコードでログイン」に入れるか、子の端末のカメラで QR を読む)', code: r.loginCode, expiresAt: r.expiresAt, link: r.link ?? childSafeLoginLink(r.loginCode));
                          });
                        }),
                child: const Text('作る'),
              )),
            ],
            RasqListTile(
              key: const ValueKey('guardian.pair'),
              title: 'コードでつなぐ',
              subtitle: '子がもう持っている RASQ アカウントを、子の端末の「チャイルドモード」でつなぎます(10 分・1 回だけ)',
              enabled: verified && !_busy,
              chevron: false,
              onTap: () => _run((api) async {
                final r = await api.createPairing();
                setState(() => _shown = (title: 'つなぐコード(子の端末の「チャイルドモード」に入れるか、子の端末のカメラで QR を読む)', code: r.code, expiresAt: r.expiresAt, link: r.link ?? childSafePairLink(r.code)));
              }),
            ),
          ]);
        },
      ),
    );
  }
}

/// 1 度だけ見せるコード(コピーできる)と、その QR (D-309)。QR の中身はリンク(`rasq://child-safe/pair?code=…` /
/// `…/login?code=…`)。子の端末のカメラアプリで読むと、コード入りの画面が開く(Android / iOS)。
/// 暗い外観でも読めるよう、QR は白地に黒で描く。
class _OneTimeCode extends StatelessWidget {
  const _OneTimeCode({required this.title, required this.code, this.expiresAt, this.link, required this.onClose});
  final String title;
  final String code;
  final DateTime? expiresAt;
  final String? link;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: const ValueKey('guardian.code'),
      margin: const EdgeInsets.all(RasqSpacing.page),
      child: Padding(
        padding: const EdgeInsets.all(RasqSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: RasqTypography.bodySmall),
          const SizedBox(height: RasqSpacing.sm),
          SelectableText(code, key: const ValueKey('guardian.code.value'), style: RasqTypography.title.copyWith(letterSpacing: 3, fontFeatures: const [FontFeature.tabularFigures()])),
          if (expiresAt != null) Text('${_fmt(expiresAt)} まで。この画面を閉じると、もう出せません(出し直すと前のコードは使えなくなります)。', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          if (link != null) ...[
            const SizedBox(height: RasqSpacing.sm),
            Center(
              child: Container(
                padding: const EdgeInsets.all(RasqSpacing.sm),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                child: QrImageView(
                  key: const ValueKey('guardian.code.qr'),
                  data: link!,
                  size: 200,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
                  semanticsLabel: 'コードの QR',
                ),
              ),
            ),
            const SizedBox(height: RasqSpacing.xs),
            SelectableText(link!, key: const ValueKey('guardian.code.link'), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          ],
          // 狭い画面でもはみ出さないよう、折り返す。
          Wrap(spacing: RasqSpacing.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
            TextButton.icon(onPressed: () => Clipboard.setData(ClipboardData(text: code)), icon: const Icon(Icons.copy, size: 16), label: const Text('コピー')),
            if (link != null) TextButton.icon(key: const ValueKey('guardian.code.copyLink'), onPressed: () => Clipboard.setData(ClipboardData(text: link!)), icon: const Icon(Icons.link, size: 16), label: const Text('リンクをコピー')),
            TextButton(onPressed: onClose, child: const Text('閉じる')),
          ]),
        ]),
      ),
    );
  }
}

/// `/child-safe/guardian/:handle`: 子ごとの設定(オンボーディングのような順)/ 14 日の要約 / 見守りを終える。
class GuardianChildScreen extends ConsumerStatefulWidget {
  const GuardianChildScreen({super.key, required this.handle});
  final String handle;
  @override
  ConsumerState<GuardianChildScreen> createState() => _GuardianChildScreenState();
}

class _GuardianChildScreenState extends ConsumerState<GuardianChildScreen> {
  ChildSafePolicy? _draft;
  int _step = 0;
  bool _busy = false;
  String? _error;

  /// 出し直したログインのコード(1 度だけ見せる)。
  ({String code, DateTime? expiresAt, String link})? _loginCode;
  final _blocked = TextEditingController();
  final _allowed = TextEditingController();
  final _posts = TextEditingController();
  final _startAt = TextEditingController();
  final _endAt = TextEditingController();

  static const _steps = ['強さ', 'TL と投稿', '時間', 'バンドルから選ぶ', '確認'];

  @override
  void dispose() {
    for (final c in [_blocked, _allowed, _posts, _startAt, _endAt]) {
      c.dispose();
    }
    super.dispose();
  }

  void _load(ChildSafePolicy p) {
    _draft = p;
    _blocked.text = p.timeline.blockedTopics.join(', ');
    _allowed.text = p.time.allowedTopics.join(', ');
    _posts.text = p.postsPerDay?.toString() ?? '';
    _startAt.text = p.time.start;
    _endAt.text = p.time.end;
  }

  /// `9:00` → `09:00`(Central は `HH:MM` の 2 桁だけを受け付ける)。読めなければそのまま。
  static String _clock(String s) {
    final m = ChildSafeTime.minutesOf(s);
    return m == null ? s.trim() : '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  }

  static List<String> _words(String s) => [for (final w in s.split(RegExp(r'[,、\s]+'))) if (w.trim().isNotEmpty) w.trim()];

  /// 入力欄の値を下書きへ写す。
  ChildSafePolicy _collect() {
    final d = _draft!;
    final ppd = int.tryParse(_posts.text.trim());
    return d.copyWith(
      timeline: d.timeline.copyWith(blockedTopics: _words(_blocked.text)),
      time: d.time.copyWith(allowedTopics: _words(_allowed.text), start: _clock(_startAt.text), end: _clock(_endAt.text)),
      postsPerDay: ppd,
      clearPostsPerDay: ppd == null,
    );
  }

  void _set(ChildSafePolicy Function(ChildSafePolicy d) f) => setState(() => _draft = f(_collect()));
  ChildSafeAllow get _allow => _draft!.allow ?? const ChildSafeAllow();
  void _setAllow(ChildSafeAllow Function(ChildSafeAllow a) f) => _set((d) => d.copyWith(allow: f(d.allow ?? const ChildSafeAllow())));

  Future<void> _save() async {
    final api = ref.read(childSafeApiProvider);
    if (api == null || _busy) return;
    final policy = _collect();
    if (ChildSafeTime.minutesOf(policy.time.start) == null || ChildSafeTime.minutesOf(policy.time.end) == null) return setState(() => _error = '時刻は HH:MM で入れてください');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final revision = await api.putSettings(widget.handle, policy);
      ref.invalidate(childSafeChildDetailProvider(widget.handle));
      ref.invalidate(childSafeGuardianProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('保存しました(設定 $revision)。子の端末に届くと「届いています」になります')));
      }
    } catch (e) {
      if (mounted) setState(() => _error = childSafeErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reissueLoginCode() async {
    final api = ref.read(childSafeApiProvider);
    if (api == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await api.reissueLoginCode(widget.handle);
      if (mounted) setState(() => _loginCode = (code: r.loginCode, expiresAt: r.expiresAt, link: r.link ?? childSafeLoginLink(r.loginCode)));
    } catch (e) {
      if (mounted) setState(() => _error = childSafeErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _end() async {
    final ok = await ref.read(overlayManagerProvider).showAlert(
          id: 'childSafe.end.confirm',
          title: '見守りを終える',
          message: '@${widget.handle} の制限をすべて外します。子の端末は、次に Central に届いたときに外れます。元に戻すには、もう一度つなぎます。',
          confirmText: '終える',
          cancelText: 'キャンセル',
          destructive: true,
        );
    final api = ref.read(childSafeApiProvider);
    if (!ok || api == null || !mounted) return;
    try {
      await api.end(widget.handle);
      ref.invalidate(childSafeGuardianProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) setState(() => _error = childSafeErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(childSafeChildDetailProvider(widget.handle));
    final catalog = ref.watch(childSafeCatalogProvider).value ?? ChildSafeCatalog.fallback;
    return Scaffold(
      appBar: RasqPageHeader(title: '@${widget.handle}'),
      body: detail.when(
        loading: () => const RasqLoading(),
        error: (e, _) => RasqEmptyView(title: '読み込めませんでした', hint: childSafeErrorMessage(e)),
        data: (d) {
          if (_draft == null) _load(d.settings ?? catalog.presetFor(d.row.ageBand));
          return ListView(padding: const EdgeInsets.only(bottom: RasqSpacing.xl), children: [
            RasqValueListTile(title: d.row.displayName.isEmpty ? d.row.handle : d.row.displayName, value: '${_stateLabel(d.row)}・${d.row.ageBand}'),
            const RasqSectionHeader(title: '設定(アプリだけで変えられます)'),
            _pad(Wrap(spacing: 4, runSpacing: 4, children: [
              for (var i = 0; i < _steps.length; i++)
                ChoiceChip(key: ValueKey('guardian.step.$i'), label: Text('${i + 1}. ${_steps[i]}'), selected: _step == i, onSelected: (_) => setState(() => _step = i)),
            ])),
            ..._stepBody(context, d, catalog),
            if (_error != null) _pad(Text(_error!, key: const ValueKey('guardian.child.error'), style: RasqTypography.caption.copyWith(color: Theme.of(context).colorScheme.error))),
            _pad(Row(children: [
              if (_step > 0) OutlinedButton(key: const ValueKey('guardian.step.back'), onPressed: () => setState(() => _step--), child: const Text('戻る')),
              const Spacer(),
              if (_step < _steps.length - 1)
                FilledButton(
                  key: const ValueKey('guardian.step.next'),
                  onPressed: () => setState(() {
                    _draft = _collect();
                    _step++;
                  }),
                  child: const Text('次へ'),
                )
              else
                FilledButton(key: const ValueKey('guardian.save'), onPressed: _busy ? null : _save, child: const Text('保存して子の端末へ送る')),
            ])),
            const RasqSectionHeader(title: '最近の発信内容の要約(14 日)'),
            ..._summary(context, d.summary),
            if (d.row.createdByGuardian) ...[
              const RasqSectionHeader(title: '子の端末のログイン'),
              RasqListTile(
                key: const ValueKey('guardian.loginCode'),
                title: 'コードを出し直す',
                subtitle: '子の端末の「保護者からのコードでログイン」に入れるコード(10 分・1 回だけ。前のコードは使えなくなります)',
                enabled: !_busy,
                chevron: false,
                onTap: _reissueLoginCode,
              ),
              if (_loginCode != null) _OneTimeCode(title: '@${widget.handle} のログインのコード', code: _loginCode!.code, expiresAt: _loginCode!.expiresAt, link: _loginCode!.link, onClose: () => setState(() => _loginCode = null)),
            ],
            const RasqSectionHeader(title: '見守りを終える'),
            RasqListTile(key: const ValueKey('guardian.end'), title: '見守りを終える', subtitle: '制限をすべて外します', chevron: false, titleColor: Theme.of(context).colorScheme.error, onTap: _end),
          ]);
        },
      ),
    );
  }

  List<Widget> _summary(BuildContext context, ChildSafeSummary s) {
    final caption = RasqTypography.caption.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    if (s.days.isEmpty) return [_pad(Text('まだ報告はありません(子の端末は、終わった日の数を 1 日 1 回送ります)。', style: caption))];
    return [
      _pad(Text('送った数 / 止めた数 / 話題の見出しだけです(投稿の本文は届きません)。', style: caption)),
      for (final day in s.days.take(14))
        RasqValueListTile(key: ValueKey('guardian.summary.${day.date}'), title: day.date, value: '送った ${day.posts}・止めた ${day.blocked}${day.topics.isEmpty ? '' : '・${day.topics.join('、')}'}'),
    ];
  }

  List<Widget> _stepBody(BuildContext context, ChildSafeChildDetail d, ChildSafeCatalog catalog) {
    final caption = RasqTypography.caption.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    final p = _draft!;
    switch (_step) {
      case 0:
        return [
          _pad(Text('年齢の帯 ${d.row.ageBand} の既定から始めます。強さを選ぶと、タイムラインと投稿の判定の強さがそろいます。', style: caption)),
          _pad(SegmentedButton<ChildSafeLevel>(
            key: const ValueKey('guardian.preset'),
            segments: [for (final l in ChildSafeLevel.values) ButtonSegment(value: l, label: Text(l.label))],
            selected: {ChildSafeLevel.fromWire(p.preset ?? p.timeline.level.wire)},
            onSelectionChanged: (s) => _set((d) => d.withPreset(s.first)),
          )),
          RasqListTile(key: const ValueKey('guardian.preset.reset'), title: '${d.row.ageBand} の既定に戻す', chevron: false, onTap: () => setState(() => _load(catalog.presetFor(d.row.ageBand)))),
        ];
      case 1:
        DropdownButton<ChildSafeLevel> level(ChildSafeLevel v, ValueChanged<ChildSafeLevel> on) => DropdownButton(value: v, items: [for (final l in ChildSafeLevel.values) DropdownMenuItem(value: l, child: Text(l.label))], onChanged: (x) => x == null ? null : on(x));
        return [
          RasqSwitchListTile(key: const ValueKey('guardian.timeline.enabled'), title: 'タイムラインを絞る', subtitle: '強い言葉の投稿を見せない', value: p.timeline.enabled, onChanged: (v) => _set((d) => d.copyWith(timeline: d.timeline.copyWith(enabled: v)))),
          _pad(Row(children: [const Text('タイムラインの強さ'), const Spacer(), level(p.timeline.level, (l) => _set((d) => d.copyWith(timeline: d.timeline.copyWith(level: l))))])),
          _pad(RasqInput(key: const ValueKey('guardian.timeline.blocked'), controller: _blocked, hintText: '見せない話題(語やタグを「,」で区切る)')),
          RasqSwitchListTile(key: const ValueKey('guardian.composer.enabled'), title: '投稿を判定する', subtitle: '強い言葉は送らない(当たった語に印を付けて止める)', value: p.composer.enabled, onChanged: (v) => _set((d) => d.copyWith(composer: d.composer.copyWith(enabled: v)))),
          _pad(Row(children: [const Text('投稿の強さ'), const Spacer(), level(p.composer.level, (l) => _set((d) => d.copyWith(composer: d.composer.copyWith(level: l))))])),
          _pad(RasqInput(key: const ValueKey('guardian.postsPerDay'), controller: _posts, hintText: '1 日に送れる投稿の数(空 = 決めない、0〜1000)', keyboardType: TextInputType.number)),
        ];
      case 2:
        return [
          RasqSwitchListTile(key: const ValueKey('guardian.time.enabled'), title: '見守りの時間', subtitle: 'その間は、許した話題だけが流れる 1 本のタイムラインになります(子の端末の時計)', value: p.time.enabled, onChanged: (v) => _set((d) => d.copyWith(time: d.time.copyWith(enabled: v)))),
          _pad(Row(children: [
            Expanded(child: RasqInput(key: const ValueKey('guardian.time.start'), controller: _startAt, hintText: '始まり 21:00')),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('〜')),
            Expanded(child: RasqInput(key: const ValueKey('guardian.time.end'), controller: _endAt, hintText: '終わり 06:00')),
          ])),
          _pad(RasqInput(key: const ValueKey('guardian.time.allowed'), controller: _allowed, hintText: 'その間に流す話題(「,」で区切る。空 = 何も流さない)')),
          RasqSwitchListTile(title: '通知を隠す', value: p.time.hideNotifications, onChanged: (v) => _set((d) => d.copyWith(time: d.time.copyWith(hideNotifications: v)))),
          RasqSwitchListTile(title: '投稿の詳細を開かせない', value: p.time.hidePostDetail, onChanged: (v) => _set((d) => d.copyWith(time: d.time.copyWith(hidePostDetail: v)))),
          RasqSwitchListTile(title: 'DM を隠す', value: p.time.hideDirectMessages, onChanged: (v) => _set((d) => d.copyWith(time: d.time.copyWith(hideDirectMessages: v)))),
        ];
      case 3:
        return _bundleStep(context, catalog);
      default:
        final lines = childSafeSummaryLines(ChildGate(state: ChildSafeState(managed: true, state: 'active', policy: p)));
        return [
          _pad(Text('子の端末には、Central が署名した設定が届きます(端末で確かめてから当てはめます)。', style: caption)),
          for (final l in lines) _pad(Text('・$l', style: RasqTypography.bodySmall)),
        ];
    }
  }

  /// 例で決める (D-314): 許す例 / 止める例の数と一覧(✕で外す)、「例を選ぶ」で共通の FOW(自分の最近のアクション /
  /// プラグイン / クリップ / リストと、ストアの掲載)を開く。
  List<Widget> _examplesSection(BuildContext context) {
    final caption = RasqTypography.caption.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    final ex = _allow.examples ?? ContentExamples.none;
    Widget chip(ContentExample e, bool allow, int i) => InputChip(
          key: ValueKey('guardian.example.${allow ? 'allow' : 'deny'}.$i'),
          avatar: Icon(allow ? Icons.check_circle_outline : Icons.block, size: 16),
          deleteIcon: const Icon(Icons.close, size: 16),
          deleteButtonTooltipMessage: '外す',
          label: Text('${e.kind.label}: ${e.shortLabel}'),
          onDeleted: () => _setAllow((x) => x.copyWith(examples: (x.examples ?? ContentExamples.none).without(e))),
        );
    return [
      const RasqSectionHeader(title: '例で決める'),
      _pad(Text(
        'id の一覧で全部を決めるかわりに、「こういうものは許す / 止める」を例で選びます。子の端末は、プラグイン(名前・説明)/ クリップ / リストの中身が例に近いかで決めます。'
        '止める例に近いものは「自由」でも使えません。「例に近いもの」にすると、選んだものと許す例に近いものを使えます(選んだものは、止める例に近くても使えます)。',
        style: caption,
      )),
      RasqListTile(
        key: const ValueKey('guardian.examples.pick'),
        title: '例を選ぶ',
        subtitle: '許す例 ${ex.allow.length} / 止める例 ${ex.deny.length}(あなたの最近のアクション / プラグイン / クリップ / リスト、ストアから)',
        onTap: _pickExamples,
      ),
      if (ex.isNotEmpty)
        _pad(Wrap(spacing: 4, runSpacing: 4, children: [
          for (final (i, e) in ex.allow.indexed) chip(e, true, i),
          for (final (i, e) in ex.deny.indexed) chip(e, false, i),
        ])),
    ];
  }

  Future<void> _pickExamples() async {
    final before = _allow.examples ?? ContentExamples.none;
    final decisions = await openExamplePickFow(
      context,
      ref,
      id: 'guardian.examples',
      title: '例で選ぶ(@${widget.handle})',
      sources: [...ownExampleSources(ref), storeExampleSource(ref)],
      initial: before,
      allowLabel: '許す例',
      denyLabel: '止める例',
      intro: '中身を見て、子に「許す例」/「止める例」を選びます(右 / 左スワイプでも)。子の端末は、新しいプラグイン / クリップ / リストを例との近さで分けます。',
    );
    if (decisions == null || !mounted) return;
    _setAllow((x) {
      var ex = x.examples ?? ContentExamples.none;
      for (final d in decisions) {
        ex = ex.withExample(d.candidate.example, allow: d.allow);
      }
      return x.copyWith(examples: ex);
    });
  }

  /// バンドルから選ぶ: SNS(自分のバンドルの種類 / サーバー)/ プラグイン(自分が入れたもの、スロットごと)/ 機能 / 検索 / RAi。
  List<Widget> _bundleStep(BuildContext context, ChildSafeCatalog catalog) {
    final caption = RasqTypography.caption.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    final a = _allow;
    final sns = a.sns ?? const ChildSafeSnsAllow();
    final plugins = a.plugins ?? const ChildSafePluginsAllow();
    final rai = a.rai ?? const ChildSafeRaiAllow(groups: ['rai.guide', 'rai.read', 'rai.compose']);
    final sessions = ref.watch(sessionsProvider).value?.allSessions ?? const [];
    final kinds = {...sns.kinds, for (final s in sessions) s.account.kind.name}.toList()..sort();
    final instances = {...sns.instances, for (final s in sessions) s.account.instance.toLowerCase()}.toList()..sort();
    final installed = ref.watch(installedPluginsProvider);
    final registered = {for (final sp in ref.watch(slotPluginsProvider)) sp.id: sp};
    final slots = <String>{
      for (final id in plugins.ids)
        for (final s in registered[id]?.manifest.slots ?? const <String>[]) s,
    }.toList()
      ..sort();
    Widget chip(String label, bool on, ValueChanged<bool> f, {Key? key}) => FilterChip(key: key, label: Text(label), selected: on, onSelected: f);
    List<String> toggle(List<String> l, String v, bool on) => on ? {...l, v}.toList() : [for (final x in l) if (x != v) x];
    return [
      const RasqSectionHeader(title: 'SNS'),
      _pad(Text('子が使ってよい SNS の種類とサーバー(あなたのバンドルから)。サーバーを選ばなければ、その種類ならどこでも。保護者の SNS のログインは貸しません。', style: caption)),
      _pad(Wrap(spacing: 4, children: [for (final k in kinds) chip(k, sns.kinds.contains(k), (v) => _setAllow((x) => x.copyWith(sns: sns.copyWith(kinds: toggle(sns.kinds, k, v)))), key: ValueKey('guardian.sns.kind.$k'))])),
      _pad(Wrap(spacing: 4, children: [for (final i in instances) chip(i, sns.instances.contains(i), (v) => _setAllow((x) => x.copyWith(sns: sns.copyWith(instances: toggle(sns.instances, i, v)))), key: ValueKey('guardian.sns.instance.$i'))])),
      RasqSwitchListTile(key: const ValueKey('guardian.sns.add'), title: '子が SNS アカウントを足せる', value: sns.addAccounts, onChanged: (v) => _setAllow((x) => x.copyWith(sns: sns.copyWith(addAccounts: v)))),
      const RasqSectionHeader(title: 'プラグイン'),
      if (installed.isEmpty) _pad(Text('あなたが入れたプラグインはありません。', style: caption)),
      for (final ip in installed)
        RasqSwitchListTile(key: ValueKey('guardian.plugin.${ip.id}'), title: ip.name.isEmpty ? ip.id : ip.name, subtitle: registered[ip.id]?.manifest.slots.join(' / ') ?? ip.id, value: plugins.ids.contains(ip.id), onChanged: (v) => _setAllow((x) => x.copyWith(plugins: plugins.copyWith(ids: toggle(plugins.ids, ip.id, v))))),
      for (final s in slots)
        RasqSwitchListTile(key: ValueKey('guardian.slot.$s'), title: 'スロット $s', subtitle: '選んだプラグインのうち、ここに出すもの', value: plugins.slots[s] != false, onChanged: (v) => _setAllow((x) => x.copyWith(plugins: plugins.copyWith(slots: {...plugins.slots, s: v})))),
      _pad(Wrap(key: const ValueKey('guardian.plugins.install'), spacing: 4, runSpacing: 4, children: [
        for (final m in ChildSafeInstall.values)
          ChoiceChip(key: ValueKey('guardian.plugins.install.${m.wire}'), label: Text(m.label), selected: plugins.install == m, onSelected: (_) => _setAllow((x) => x.copyWith(plugins: plugins.copyWith(install: m)))),
      ])),
      ..._examplesSection(context),
      const RasqSectionHeader(title: '機能'),
      for (final f in catalog.features)
        RasqSwitchListTile(key: ValueKey('guardian.feature.${f.id}'), title: f.label, value: a.features?[f.id] ?? childSafePresetDefault(_draft!.preset, 'features', f.id), onChanged: (v) => _setAllow((x) => x.copyWith(features: {...?x.features, f.id: v}))),
      const RasqSectionHeader(title: '検索'),
      for (final f in catalog.search)
        RasqSwitchListTile(key: ValueKey('guardian.search.${f.id}'), title: f.label, value: a.search?[f.id] ?? childSafePresetDefault(_draft!.preset, 'search', f.id), onChanged: (v) => _setAllow((x) => x.copyWith(search: {...?x.search, f.id: v}))),
      const RasqSectionHeader(title: 'RAi'),
      RasqSwitchListTile(key: const ValueKey('guardian.rai.enabled'), title: 'RAi を使える', value: rai.enabled, onChanged: (v) => _setAllow((x) => x.copyWith(rai: rai.copyWith(enabled: v)))),
      for (final g in catalog.raiGroups)
        RasqSwitchListTile(
          key: ValueKey('guardian.rai.${g.id}'),
          title: g.label,
          subtitle: g.phase > 1 ? '第二期(いまは効きません)' : g.id,
          value: rai.groups.contains(g.id),
          onChanged: (v) => _setAllow((x) => x.copyWith(rai: rai.copyWith(groups: toggle(rai.groups, g.id, v)))),
        ),
      RasqSwitchListTile(key: const ValueKey('guardian.rai.automation'), title: '関数での自動化', subtitle: 'オフなら、案内(指差し)だけで進めます', value: rai.automation, onChanged: (v) => _setAllow((x) => x.copyWith(rai: rai.copyWith(automation: v)))),
    ];
  }
}
