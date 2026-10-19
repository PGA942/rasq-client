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
import '../../l10n/l10n.dart';
import '../../shell/headers.dart';
import '../compose_policy/compose_policy.dart' show composeTypeLabels;
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
  if (api == null) throw StateError(appL10n.childSafeNoServer);
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
  if (api == null) throw StateError(appL10n.childSafeNoServer);
  return api.child(handle);
});

Widget _pad(Widget child) => Padding(padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, RasqSpacing.xs), child: child);

String _stateLabel(ChildSafeChildRow c) {
  final l = appL10n;
  return c.pending ? l.childSafeStatePending : (c.applied ? l.childSafeGuardianStateApplied : l.childSafeGuardianStateNotApplied(c.revision));
}
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
  final l = appL10n;
  final ok = await ref.read(overlayManagerProvider).showAlert(
        id: 'childSafe.pledge',
        title: l.childSafeGuardianPledgeTitle(childSafePledgeVersion),
        message: l.childSafeGuardianPledgeMessage([for (final line in childSafePledge) l.childSafeBullet(line)].join('\n')),
        confirmText: l.childSafeGuardianPledgeConfirm,
        cancelText: l.childSafeGuardianCancel,
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
    final l = context.l10n;
    return Scaffold(
      appBar: RasqPageHeader(title: l.childSafeWatchAsGuardian),
      body: info.when(
        loading: () => const RasqLoading(),
        error: (e, _) => RasqEmptyView(title: l.childSafeGuardianLoadError, hint: childSafeErrorMessage(e), action: TextButton(onPressed: () => ref.invalidate(childSafeGuardianProvider), child: Text(l.childSafeGuardianReload))),
        data: (g) {
          final verified = g.status.verified;
          return ListView(padding: const EdgeInsets.only(bottom: RasqSpacing.xl), children: [
            RasqSectionHeader(title: l.childSafeGuardianVerifySection),
            RasqValueListTile(
              key: const ValueKey('guardian.verified'),
              title: verified ? l.childSafeGuardianVerified : l.childSafeGuardianNotVerified,
              value: verified ? [g.status.methodLabel, ?g.status.country, if (g.status.verifiedAt != null) _fmt(g.status.verifiedAt)].join(l.childSafeListSeparator) : '',
            ),
            if (!verified) ...[
              _pad(Text(rasqDetail(context, l.childSafeGuardianVerifyIntro, l.childSafeGuardianVerifyIntroDetail), style: caption)),
              if (g.jpkiAvailable)
                RasqListTile(
                  key: const ValueKey('guardian.verify.jpki'),
                  title: l.childSafeGuardianVerifyJpki,
                  subtitle: l.childSafeGuardianVerifyJpkiSubtitle,
                  enabled: !_busy,
                  onTap: () => _run((_) => startJpkiVerification(ref, g)),
                ),
              RasqListTile(key: const ValueKey('guardian.verify'), title: l.childSafeGuardianVerifyWeb, subtitle: l.childSafeGuardianOpensInBrowser, onTap: () => openGuardianVerification(ref)),
            ],
            RasqSectionHeader(title: l.childSafeGuardianChildrenSection(g.children.length, 8)),
            if (g.children.isEmpty) _pad(Text(l.childSafeGuardianNoChildren, style: caption)),
            for (final c in g.children)
              RasqListTile(
                key: ValueKey('guardian.child.${c.handle}'),
                title: '${c.displayName.isEmpty ? c.handle : c.displayName}  @${c.handle}',
                subtitle: '${_stateLabel(c)}${l.childSafeListSeparator}${c.ageBand}${c.createdByGuardian ? l.childSafeGuardianCreatedByGuardian : ''}',
                onTap: () => context.push('/child-safe/guardian/${Uri.encodeComponent(c.handle)}'),
              ),
            if (_shown != null) _OneTimeCode(title: _shown!.title, code: _shown!.code, expiresAt: _shown!.expiresAt, link: _shown!.link, onClose: () => setState(() => _shown = null)),
            if (_error != null) _pad(Text(_error!, key: const ValueKey('guardian.error'), style: caption.copyWith(color: scheme.error))),
            RasqSectionHeader(title: l.childSafeGuardianAddSection),
            RasqListTile(
              key: const ValueKey('guardian.create'),
              title: l.childSafeGuardianCreate,
              subtitle: l.childSafeGuardianCreateSubtitle,
              enabled: verified && !_busy,
              chevron: false,
              onTap: () => setState(() => _creating = !_creating),
            ),
            if (_creating && verified) ...[
              _pad(RasqInput(key: const ValueKey('guardian.create.handle'), controller: _handle, hintText: l.childSafeGuardianHandleHint)),
              _pad(RasqInput(key: const ValueKey('guardian.create.name'), controller: _name, hintText: l.childSafeGuardianNameHint)),
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
                            _shown = (title: l.childSafeGuardianNewLoginCodeTitle(r.handle), code: r.loginCode, expiresAt: r.expiresAt, link: r.link ?? childSafeLoginLink(r.loginCode));
                          });
                        }),
                child: Text(l.childSafeGuardianCreateButton),
              )),
            ],
            RasqListTile(
              key: const ValueKey('guardian.pair'),
              title: l.childSafeGuardianPair,
              subtitle: l.childSafeGuardianPairSubtitle,
              enabled: verified && !_busy,
              chevron: false,
              onTap: () => _run((api) async {
                final r = await api.createPairing();
                setState(() => _shown = (title: l.childSafeGuardianPairCodeTitle, code: r.code, expiresAt: r.expiresAt, link: r.link ?? childSafePairLink(r.code)));
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
    final l = context.l10n;
    return Card(
      key: const ValueKey('guardian.code'),
      margin: const EdgeInsets.all(RasqSpacing.page),
      child: Padding(
        padding: const EdgeInsets.all(RasqSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: RasqTypography.bodySmall),
          const SizedBox(height: RasqSpacing.sm),
          SelectableText(code, key: const ValueKey('guardian.code.value'), style: RasqTypography.title.copyWith(letterSpacing: 3, fontFeatures: const [FontFeature.tabularFigures()])),
          if (expiresAt != null) Text(l.childSafeGuardianCodeExpires(_fmt(expiresAt)), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
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
                  semanticsLabel: l.childSafeGuardianCodeQr,
                ),
              ),
            ),
            const SizedBox(height: RasqSpacing.xs),
            SelectableText(link!, key: const ValueKey('guardian.code.link'), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          ],
          // 狭い画面でもはみ出さないよう、折り返す。
          Wrap(spacing: RasqSpacing.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
            TextButton.icon(onPressed: () => Clipboard.setData(ClipboardData(text: code)), icon: const Icon(Icons.copy, size: 16), label: Text(l.childSafeGuardianCopy)),
            if (link != null) TextButton.icon(key: const ValueKey('guardian.code.copyLink'), onPressed: () => Clipboard.setData(ClipboardData(text: link!)), icon: const Icon(Icons.link, size: 16), label: Text(l.childSafeGuardianCopyLink)),
            TextButton(onPressed: onClose, child: Text(l.childSafeGuardianClose)),
          ]),
        ]),
      ),
    );
  }
}

/// 保護者の設定のページ (D-315)。AsTell のルームのタブ(`RasqTabs`)と同じ見た目で並べる(順に進める「次へ / 戻る」は無い)。
enum GuardianPage {
  timeline,
  composer,
  astell,
  plugins,
  sns,
  screenTime,
  other;

  String get label => switch (this) {
        timeline => appL10n.childSafeGuardianPageTimeline,
        composer => appL10n.childSafeGuardianPageComposer,
        astell => appL10n.childSafeGuardianPageAstell,
        plugins => appL10n.childSafeGuardianPagePlugins,
        sns => appL10n.childSafeGuardianPageSns,
        screenTime => appL10n.childSafeGuardianPageScreenTime,
        other => appL10n.childSafeGuardianPageOther,
      };

  /// 話題の一覧の面([childSafeTopicErrors] のキー)→ ページ。
  static GuardianPage ofTopicSection(String section) => switch (section) {
        'timeline' => timeline,
        'composer' => composer,
        _ => screenTime,
      };
}

/// 機能のスイッチを置くページ (D-315)。カタログの id で決め、知らない id は「その他」(どれも落とさない)。
GuardianPage guardianPageOfFeature(String id) => switch (id) {
      _ when id.startsWith('astell.') => GuardianPage.astell,
      'dm' || 'sns.addAccount' => GuardianPage.sns,
      'store.install' || 'store.review' => GuardianPage.plugins,
      _ => GuardianPage.other,
    };

/// 例のチップを出すページ (D-315): プラグイン(ストアの掲載もプラグイン)は「プラグイン」、投稿 / クリップ / リスト / ことばは「TL」。
bool guardianPluginExample(ContentExample e) => e.kind == ExampleKind.plugin;

/// ページのタブを上に留める(rasq_design `RasqCollapsibleTabScaffold` の留め方と同じ)。
class _PinnedTabs extends SliverPersistentHeaderDelegate {
  _PinnedTabs(this.tabs, this.background);
  final RasqTabs tabs;
  final Color background;
  @override
  double get minExtent => tabs.preferredSize.height + 1;
  @override
  double get maxExtent => tabs.preferredSize.height + 1;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => ColoredBox(color: background, child: Column(children: [tabs, const Divider(height: 1)]));
  @override
  bool shouldRebuild(_PinnedTabs old) => true;
}

/// マニフェストの `id` の形(Central `allow.plugins.ids` と同じ)。
final _pluginIdShape = RegExp(r'^[a-z0-9]+(\.[a-z0-9_-]+)+$');

/// `/child-safe/guardian/:handle`: 子ごとの設定(ページのタブ)/ 14 日の要約 / 見守りを終える。
/// 上から: 子の行 → 強さ(プリセット)と「設定をインポート」→ ページのタブ → そのページ。保存は下のボタン 1 つ(どのページからでも)。
class GuardianChildScreen extends ConsumerStatefulWidget {
  const GuardianChildScreen({super.key, required this.handle});
  final String handle;
  @override
  ConsumerState<GuardianChildScreen> createState() => _GuardianChildScreenState();
}

class _GuardianChildScreenState extends ConsumerState<GuardianChildScreen> with SingleTickerProviderStateMixin {
  ChildSafePolicy? _draft;
  late final TabController _tabs;
  bool _busy = false;
  String? _error;

  /// 保存しようとして見つかった、有効な面の空のホワイトリスト(面 → 文)。その面を直すと消える。
  Map<String, String> _topicErrors = const {};

  /// 読み込んだ設定の時間が、もとの形の「空 = その間は何も流さない」だった(新しい形では書けないので、案内を出す)。
  bool _legacyNothingAtNight = false;

  /// 「id で足す」の形の誤り(入力欄のすぐ下に出す)。
  String? _pluginIdError;

  /// 出し直したログインのコード(1 度だけ見せる)。
  ({String code, DateTime? expiresAt, String link})? _loginCode;
  final _tlTopics = TextEditingController();
  final _composerTopics = TextEditingController();
  final _timeTopics = TextEditingController();
  final _posts = TextEditingController();
  final _startAt = TextEditingController();
  final _endAt = TextEditingController();
  final _pluginId = TextEditingController();

  final _scroll = ScrollController();

  /// タブより上(子の行と強さ)。ページを切り替えたとき、タブの位置から見せるために高さを測る。
  final _headerKey = GlobalKey();
  int _shownPage = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: GuardianPage.values.length, vsync: this)..addListener(_onTab);
  }

  void _onTab() {
    if (!mounted || _tabs.index == _shownPage) return;
    _shownPage = _tabs.index;
    // 下まで送っていたら、新しいページはタブ(上に留まる)のすぐ下から見せる。
    final header = (_headerKey.currentContext?.findRenderObject() as RenderBox?)?.size.height;
    if (header != null && _scroll.hasClients && _scroll.offset > header) _scroll.jumpTo(header);
    setState(() {});
  }

  @override
  void dispose() {
    _tabs.dispose();
    _scroll.dispose();
    for (final c in [_tlTopics, _composerTopics, _timeTopics, _posts, _startAt, _endAt, _pluginId]) {
      c.dispose();
    }
    super.dispose();
  }

  GuardianPage get _page => GuardianPage.values[_tabs.index];

  void _load(ChildSafePolicy p) {
    _draft = p;
    _topicErrors = const {};
    _legacyNothingAtNight = p.time.enabled && p.time.topics.legacy && p.time.topics.isEmptyWhitelist;
    _tlTopics.text = p.timeline.topics.topics.join(', ');
    _composerTopics.text = p.composer.topics.topics.join(', ');
    _timeTopics.text = p.time.topics.topics.join(', ');
    _posts.text = p.postsPerDay?.toString() ?? '';
    _startAt.text = p.time.start;
    _endAt.text = p.time.end;
  }

  /// `9:00` → `09:00`(Central は `HH:MM` の 2 桁だけを受け付ける)。読めなければそのまま。
  static String _clock(String s) {
    final m = ChildSafeTime.minutesOf(s);
    return m == null ? s.trim() : '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  }

  static List<String> _words(String s) => [for (final w in s.split(RegExp(r'[,、\s]+'))) if (w.trim().isNotEmpty) w.trim()]; // l10n-ignore: 話題の入力の区切り(照合のデータ)

  /// 入力欄の値を下書きへ写す(話題はいつも新しい形 `topicMode` + `topics` で書く。D-315)。
  ChildSafePolicy _collect() {
    final d = _draft!;
    final ppd = int.tryParse(_posts.text.trim());
    return d.copyWith(
      timeline: d.timeline.copyWith(topics: d.timeline.topics.copyWith(topics: _words(_tlTopics.text))),
      composer: d.composer.copyWith(topics: d.composer.topics.copyWith(topics: _words(_composerTopics.text))),
      time: d.time.copyWith(topics: d.time.topics.copyWith(topics: _words(_timeTopics.text)), start: _clock(_startAt.text), end: _clock(_endAt.text)),
      postsPerDay: ppd,
      clearPostsPerDay: ppd == null,
    );
  }

  void _set(ChildSafePolicy Function(ChildSafePolicy d) f) => setState(() => _draft = f(_collect()));
  ChildSafeAllow get _allow => _draft!.allow ?? const ChildSafeAllow();
  void _setAllow(ChildSafeAllow Function(ChildSafeAllow a) f) => _set((d) => d.copyWith(allow: f(d.allow ?? const ChildSafeAllow())));

  /// 面 [section] の話題を変える(その面の「空のホワイトリスト」の知らせは消す)。
  void _setTopics(String section, ChildSafePolicy Function(ChildSafePolicy d) f) {
    _topicErrors = {..._topicErrors}..remove(section);
    _set(f);
  }

  /// 保存: 入力を確かめ(時刻 / 有効な面の空のホワイトリスト → そのページを開いて知らせ、送らない)、要約のシートで確かめてから送る。
  Future<void> _confirmAndSave() async {
    if (ref.read(childSafeApiProvider) == null || _busy || _draft == null) return;
    final policy = _collect();
    setState(() => _draft = policy);
    if (ChildSafeTime.minutesOf(policy.time.start) == null || ChildSafeTime.minutesOf(policy.time.end) == null) {
      setState(() => _error = context.l10n.childSafeGuardianTimeFormatError);
      _tabs.animateTo(GuardianPage.screenTime.index);
      return;
    }
    final errors = childSafeTopicErrors(policy);
    setState(() {
      _topicErrors = errors;
      _error = null;
    });
    if (errors.isNotEmpty) {
      _tabs.animateTo(GuardianPage.ofTopicSection(errors.keys.first).index);
      return;
    }
    final lines = childSafeSummaryLines(ChildGate(state: ChildSafeState(managed: true, state: 'active', policy: policy)));
    final l = context.l10n;
    final ok = await ref.read(overlayManagerProvider).showBottomSheet<bool>(
          id: 'guardian.confirm',
          title: l.childSafeGuardianConfirmTitle,
          confirmText: l.childSafeGuardianConfirmSend,
          builder: (context) => SingleChildScrollView(
            key: const ValueKey('guardian.confirm'),
            padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, RasqSpacing.md),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(rasqDetail(context, l.childSafeGuardianConfirmIntro(widget.handle), l.childSafeGuardianConfirmIntroDetail(widget.handle)), style: RasqTypography.caption.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: RasqSpacing.sm),
              for (final line in lines) Padding(padding: const EdgeInsets.only(bottom: 2), child: Text(l.childSafeBullet(line), style: RasqTypography.bodySmall)),
            ]),
          ),
        );
    if (ok == true && mounted) await _save(policy);
  }

  Future<void> _save(ChildSafePolicy policy) async {
    final api = ref.read(childSafeApiProvider);
    if (api == null || _busy) return;
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
          ..showSnackBar(SnackBar(content: Text(context.l10n.childSafeGuardianSaved(revision))));
      }
    } catch (e) {
      if (mounted) setState(() => _error = childSafeErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 「設定をインポート」: 年齢の帯の既定 / ほかの子の設定(設定が済んでいる子がいるときだけ)。読み込むのは下書きだけ(保存は別)。
  Future<void> _importMenu(BuildContext anchorContext, ChildSafeChildDetail d, ChildSafeCatalog catalog, List<ChildSafeChildRow> others) async {
    final box = anchorContext.findRenderObject() as RenderBox?;
    final anchor = box == null ? const Rect.fromLTWH(0, 120, 1, 1) : box.localToGlobal(Offset.zero) & box.size;
    final l = context.l10n;
    final pick = await ref.read(overlayManagerProvider).showDropdown<String>(id: 'guardian.import', anchor: anchor, items: [
      RasqDropdownItem(l.childSafeGuardianImportPreset(d.row.ageBand), 'preset'),
      if (others.isNotEmpty) RasqDropdownItem(l.childSafeGuardianImportCopy, 'copy'),
    ]);
    if (!mounted) return;
    switch (pick) {
      case 'preset':
        setState(() {
          _load(catalog.presetFor(d.row.ageBand));
          _error = null;
        });
        _loaded(l.childSafeGuardianImportedPreset(d.row.ageBand));
      case 'copy':
        await _copyFrom(others);
    }
  }

  /// ほかの子のいまの設定を、子の詳細 (`GET /me/child-safe/children/{handle}`) から読んで下書きにする。
  Future<void> _copyFrom(List<ChildSafeChildRow> others) async {
    final from = others.length == 1
        ? others.single.handle
        : await ref.read(overlayManagerProvider).showChoiceAlert<String>(
            id: 'guardian.import.child',
            title: context.l10n.childSafeGuardianCopyWhich,
            choices: [for (final c in others) RasqAlertChoice('${c.displayName.isEmpty ? c.handle : c.displayName}  @${c.handle}', c.handle, key: ValueKey('guardian.import.child.${c.handle}'))],
          );
    final api = ref.read(childSafeApiProvider);
    if (from == null || api == null || !mounted) return;
    try {
      final settings = (await api.child(from)).settings;
      if (!mounted) return;
      if (settings == null) return setState(() => _error = context.l10n.childSafeGuardianNotSetUp(from));
      setState(() {
        _load(settings);
        _error = null;
      });
      _loaded(context.l10n.childSafeGuardianCopied(from));
    } catch (e) {
      if (mounted) setState(() => _error = childSafeErrorMessage(e));
    }
  }

  void _loaded(String what) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(context.l10n.childSafeGuardianNotSavedYet(what))));

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
    final l = context.l10n;
    final ok = await ref.read(overlayManagerProvider).showAlert(
          id: 'childSafe.end.confirm',
          title: l.childSafeGuardianEnd,
          message: rasqDetail(context, l.childSafeGuardianEndMessage(widget.handle), l.childSafeGuardianEndMessageDetail(widget.handle)),
          confirmText: l.childSafeGuardianEndConfirm,
          cancelText: l.childSafeGuardianCancel,
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
    // コピーできるのは、ほかの見守っている子のうち設定が済んでいる子(設定待ちの子には写すものが無い)。
    final others = [for (final c in ref.watch(childSafeGuardianProvider).value?.children ?? const <ChildSafeChildRow>[]) if (c.handle != widget.handle && !c.pending) c];
    final loaded = detail.value;
    if (_draft == null && loaded != null) _load(loaded.settings ?? catalog.presetFor(loaded.row.ageBand));
    final l = context.l10n;
    return Scaffold(
      appBar: RasqPageHeader(title: '@${widget.handle}'),
      body: detail.when(
        loading: () => const RasqLoading(),
        error: (e, _) => RasqEmptyView(title: l.childSafeGuardianLoadError, hint: childSafeErrorMessage(e)),
        // 子の行と強さは流れて消え、ページのタブは上に留まる(RasqCollapsibleTabScaffold と同じ並び。ページは 1 本の縦の流れ)。
        data: (d) => CustomScrollView(controller: _scroll, slivers: [
          SliverToBoxAdapter(
            child: Column(key: _headerKey, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              RasqValueListTile(title: d.row.displayName.isEmpty ? d.row.handle : d.row.displayName, value: '${_stateLabel(d.row)}${l.childSafeListSeparator}${d.row.ageBand}'),
              _presetArea(context, d, catalog, others),
            ]),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _PinnedTabs(
              RasqTabs(
                key: const ValueKey('guardian.tabs'),
                controller: _tabs,
                items: [
                  for (final pg in GuardianPage.values)
                    RasqTabItem(pg.label, id: pg.name, icon: _topicErrors.keys.any((k) => GuardianPage.ofTopicSection(k) == pg) ? Icons.error_outline : null),
                ],
                // 7 ページあるので、狭い画面では横に流す(見た目は AsTell のルームのタブと同じ部品)。
                mode: RasqTabsMode.extensible,
                showChevron: false,
              ),
              Theme.of(context).colorScheme.surface,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: RasqSpacing.xl),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                KeyedSubtree(key: ValueKey('guardian.page.${_page.name}'), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _pageBody(context, _page, d, catalog))),
                if (_error != null) _pad(Text(_error!, key: const ValueKey('guardian.child.error'), style: RasqTypography.caption.copyWith(color: Theme.of(context).colorScheme.error))),
                RasqSectionHeader(title: l.childSafeGuardianSummarySection),
                ..._summary(context, d.summary),
                if (d.row.createdByGuardian) ...[
                  RasqSectionHeader(title: l.childSafeGuardianLoginSection),
                  RasqListTile(
                    key: const ValueKey('guardian.loginCode'),
                    title: l.childSafeGuardianReissue,
                    subtitle: l.childSafeGuardianReissueSubtitle,
                    enabled: !_busy,
                    chevron: false,
                    onTap: _reissueLoginCode,
                  ),
                  if (_loginCode != null) _OneTimeCode(title: l.childSafeGuardianLoginCodeTitle(widget.handle), code: _loginCode!.code, expiresAt: _loginCode!.expiresAt, link: _loginCode!.link, onClose: () => setState(() => _loginCode = null)),
                ],
                RasqSectionHeader(title: l.childSafeGuardianEnd),
                RasqListTile(key: const ValueKey('guardian.end'), title: l.childSafeGuardianEnd, subtitle: l.childSafeGuardianEndSubtitle, chevron: false, titleColor: Theme.of(context).colorScheme.error, onTap: _end),
              ]),
            ),
          ),
        ]),
      ),
      // 保存はどのページからでも(下に 1 つ)。送る前に要約のシートで確かめる。
      bottomNavigationBar: loaded == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, RasqSpacing.sm),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(key: const ValueKey('guardian.save'), onPressed: _busy ? null : _confirmAndSave, child: Text(l.childSafeGuardianSaveButton)),
                ),
              ),
            ),
    );
  }

  /// 子の行の下: 強さ(プリセット)と、丸い「設定をインポート」。
  Widget _presetArea(BuildContext context, ChildSafeChildDetail d, ChildSafeCatalog catalog, List<ChildSafeChildRow> others) {
    final p = _draft!;
    final caption = RasqTypography.caption.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Padding(
      key: const ValueKey('guardian.presetArea'),
      padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, RasqSpacing.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: SegmentedButton<ChildSafeLevel>(
              key: const ValueKey('guardian.preset'),
              showSelectedIcon: false,
              segments: [for (final l in ChildSafeLevel.values) ButtonSegment(value: l, label: Text(l.label))],
              selected: {ChildSafeLevel.fromWire(p.preset ?? p.timeline.level.wire)},
              onSelectionChanged: (s) => _set((d) => d.withPreset(s.first)),
            ),
          ),
          const SizedBox(width: RasqSpacing.sm),
          Builder(
            builder: (anchor) => IconButton.filledTonal(
              key: const ValueKey('guardian.import'),
              tooltip: context.l10n.childSafeGuardianImportTooltip,
              icon: const Icon(Icons.download_outlined),
              onPressed: () => _importMenu(anchor, d, catalog, others),
            ),
          ),
        ]),
        const SizedBox(height: RasqSpacing.xs),
        Text(context.l10n.childSafeGuardianPresetCaption(d.row.ageBand), style: caption),
      ]),
    );
  }

  List<Widget> _summary(BuildContext context, ChildSafeSummary s) {
    final caption = RasqTypography.caption.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    final l = context.l10n;
    if (s.days.isEmpty) return [_pad(Text(l.childSafeGuardianSummaryEmpty, style: caption))];
    return [
      _pad(Text(l.childSafeGuardianSummaryCaption, style: caption)),
      for (final day in s.days.take(14))
        RasqValueListTile(
            key: ValueKey('guardian.summary.${day.date}'),
            title: day.date,
            value: l.childSafeGuardianSummaryDay(
                day.posts,
                day.blocked,
                day.trips.isEmpty
                    ? ''
                    : l.childSafeGuardianSummaryTrips([for (final e in day.trips.entries) '${composeTypeLabels[e.key] ?? e.key} ${e.value}'].join(l.childSafeGuardianSummaryTripsSeparator)))),
    ];
  }

  List<Widget> _pageBody(BuildContext context, GuardianPage page, ChildSafeChildDetail d, ChildSafeCatalog catalog) => switch (page) {
        GuardianPage.timeline => _timelinePage(context),
        GuardianPage.composer => _composerPage(context),
        GuardianPage.astell => _astellPage(context, catalog),
        GuardianPage.plugins => _pluginsPage(context, d, catalog),
        GuardianPage.sns => _snsPage(context, catalog),
        GuardianPage.screenTime => _screenTimePage(context),
        GuardianPage.other => _otherPage(context, catalog),
      };

  TextStyle _caption(BuildContext context) => RasqTypography.caption.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);

  Widget _levelRow(String label, ChildSafeLevel value, ValueChanged<ChildSafeLevel> onChanged, {Key? key}) => _pad(Row(children: [
        Text(label),
        const Spacer(),
        DropdownButton<ChildSafeLevel>(key: key, value: value, items: [for (final l in ChildSafeLevel.values) DropdownMenuItem(value: l, child: Text(l.label))], onChanged: (x) => x == null ? null : onChanged(x)),
      ]));

  /// 話題の一覧 (D-315): ホワイトリスト / ブラックリストの切り替えと、「,」区切りの話題。空のホワイトリストの知らせもここに出す。
  List<Widget> _topicsEditor(
    BuildContext context, {
    required String section,
    required String label,
    required ChildSafeTopics topics,
    required TextEditingController controller,
    required String allowHint,
    required String denyHint,
    required String allowNote,
    required String denyNote,
    required ChildSafePolicy Function(ChildSafePolicy d, ChildSafeTopicMode m) withMode,
  }) {
    final caption = _caption(context);
    final error = _topicErrors[section];
    return [
      _pad(Row(children: [
        Expanded(child: Text(label)),
        DropdownButton<ChildSafeTopicMode>(
          key: ValueKey('guardian.$section.topicMode'),
          value: topics.mode,
          items: [for (final m in ChildSafeTopicMode.values) DropdownMenuItem(value: m, child: Text(m.label))],
          onChanged: (m) => m == null ? null : _setTopics(section, (d) => withMode(d, m)),
        ),
      ])),
      _pad(RasqInput(
        key: ValueKey('guardian.$section.topics'),
        controller: controller,
        hintText: topics.allow ? allowHint : denyHint,
        onChanged: error == null ? null : (_) => setState(() => _topicErrors = {..._topicErrors}..remove(section)),
      )),
      _pad(Text(topics.allow ? allowNote : denyNote, style: caption)),
      if (error != null) _pad(Text(error, key: ValueKey('guardian.$section.topics.error'), style: caption.copyWith(color: Theme.of(context).colorScheme.error))),
    ];
  }

  Widget _featureSwitch(ChildSafeCatalogItem f) => RasqSwitchListTile(
        key: ValueKey('guardian.feature.${f.id}'),
        title: f.label,
        value: _allow.features?[f.id] ?? childSafePresetDefault(_draft!.preset, 'features', f.id),
        onChanged: (v) => _setAllow((x) => x.copyWith(features: {...?x.features, f.id: v})),
      );

  /// そのページの機能のスイッチ(カタログの順)。「その他」には、カタログに無いが設定にある id も出す(落とさない)。
  List<Widget> _featuresOn(ChildSafeCatalog catalog, GuardianPage page) => [
        for (final f in catalog.features)
          if (guardianPageOfFeature(f.id) == page) _featureSwitch(f),
        if (page == GuardianPage.other)
          for (final id in (_allow.features ?? const <String, bool>{}).keys)
            if (!catalog.features.any((f) => f.id == id) && guardianPageOfFeature(id) == page) _featureSwitch(ChildSafeCatalogItem(id, id)),
      ];

  List<Widget> _timelinePage(BuildContext context) {
    final p = _draft!;
    final l = context.l10n;
    return [
      RasqSwitchListTile(key: const ValueKey('guardian.timeline.enabled'), title: l.childSafeGuardianTimelineEnabled, subtitle: l.childSafeGuardianTimelineEnabledSubtitle, value: p.timeline.enabled, onChanged: (v) => _set((d) => d.copyWith(timeline: d.timeline.copyWith(enabled: v)))),
      _levelRow(l.childSafeGuardianTimelineLevel, p.timeline.level, (l) => _set((d) => d.copyWith(timeline: d.timeline.copyWith(level: l)))),
      ..._topicsEditor(
        context,
        section: 'timeline',
        label: l.childSafeGuardianTimelineTopics,
        topics: p.timeline.topics,
        controller: _tlTopics,
        allowHint: l.childSafeGuardianTimelineAllowHint,
        denyHint: l.childSafeGuardianTimelineDenyHint,
        allowNote: l.childSafeGuardianTimelineAllowNote,
        denyNote: l.childSafeGuardianTimelineDenyNote,
        withMode: (d, m) => d.copyWith(timeline: d.timeline.copyWith(topics: d.timeline.topics.copyWith(mode: m))),
      ),
      ..._examplesSection(context, plugins: false),
    ];
  }

  List<Widget> _composerPage(BuildContext context) {
    final p = _draft!;
    final l = context.l10n;
    return [
      RasqSwitchListTile(key: const ValueKey('guardian.composer.enabled'), title: l.childSafeGuardianComposerEnabled, subtitle: l.childSafeGuardianComposerEnabledSubtitle, value: p.composer.enabled, onChanged: (v) => _set((d) => d.copyWith(composer: d.composer.copyWith(enabled: v)))),
      _levelRow(l.childSafeGuardianComposerLevel, p.composer.level, (l) => _set((d) => d.copyWith(composer: d.composer.copyWith(level: l)))),
      _pad(RasqInput(key: const ValueKey('guardian.postsPerDay'), controller: _posts, hintText: l.childSafeGuardianPostsPerDayHint, keyboardType: TextInputType.number)),
      ..._topicsEditor(
        context,
        section: 'composer',
        label: l.childSafeGuardianComposerTopics,
        topics: p.composer.topics,
        controller: _composerTopics,
        allowHint: l.childSafeGuardianComposerAllowHint,
        denyHint: l.childSafeGuardianComposerDenyHint,
        allowNote: l.childSafeGuardianComposerAllowNote,
        denyNote: l.childSafeGuardianComposerDenyNote,
        withMode: (d, m) => d.copyWith(composer: d.composer.copyWith(topics: d.composer.topics.copyWith(mode: m))),
      ),
    ];
  }

  List<Widget> _astellPage(BuildContext context, ChildSafeCatalog catalog) => [
        _pad(Text(context.l10n.childSafeGuardianAstellCaption, style: _caption(context))),
        ..._featuresOn(catalog, GuardianPage.astell),
      ];

  List<Widget> _pluginsPage(BuildContext context, ChildSafeChildDetail d, ChildSafeCatalog catalog) {
    final caption = _caption(context);
    final plugins = _allow.plugins ?? const ChildSafePluginsAllow();
    final installed = {for (final ip in ref.watch(installedPluginsProvider)) if (ip.name.isNotEmpty) ip.id: ip.name};
    String nameOf(String id) => d.pluginNames[id] ?? installed[id] ?? id;
    final l = context.l10n;
    return [
      ..._featuresOn(catalog, GuardianPage.plugins),
      RasqSectionHeader(title: l.childSafeGuardianInstallSection),
      _pad(Text(l.childSafeGuardianInstallCaption, style: caption)),
      _pad(Wrap(key: const ValueKey('guardian.plugins.install'), spacing: 4, runSpacing: 4, children: [
        for (final m in ChildSafeInstall.values)
          ChoiceChip(key: ValueKey('guardian.plugins.install.${m.wire}'), label: Text(m.label), selected: plugins.install == m, onSelected: (_) => _setAllow((x) => x.copyWith(plugins: plugins.copyWith(install: m)))),
      ])),
      RasqSectionHeader(title: l.childSafeGuardianNamedSection),
      _pad(Text(plugins.ids.isEmpty ? l.childSafeGuardianNamedNone : l.childSafeGuardianNamedCaption, style: caption)),
      if (plugins.ids.isNotEmpty)
        _pad(Wrap(spacing: 4, runSpacing: 4, children: [
          for (final id in plugins.ids)
            InputChip(
              key: ValueKey('guardian.plugin.id.$id'),
              label: Text(nameOf(id)),
              tooltip: id,
              deleteIcon: const Icon(Icons.close, size: 16),
              deleteButtonTooltipMessage: l.childSafeGuardianRemove,
              onDeleted: () => _setAllow((x) => x.copyWith(plugins: plugins.copyWith(ids: [for (final i in plugins.ids) if (i != id) i]))),
            ),
        ])),
      _pad(Row(children: [
        Expanded(child: RasqInput(key: const ValueKey('guardian.plugins.addId'), controller: _pluginId, hintText: l.childSafeGuardianAddIdHint, onSubmitted: (_) => _addPluginId())),
        TextButton(key: const ValueKey('guardian.plugins.addId.submit'), onPressed: _addPluginId, child: Text(l.childSafeGuardianAddIdButton)),
      ])),
      if (_pluginIdError != null) _pad(Text(_pluginIdError!, key: const ValueKey('guardian.plugins.addId.error'), style: caption.copyWith(color: Theme.of(context).colorScheme.error))),
      ..._examplesSection(context, plugins: true),
    ];
  }

  /// id で足す(子がサイドロードしたものも。Central は形だけを確かめる)。
  void _addPluginId() {
    final id = _pluginId.text.trim();
    if (id.isEmpty) return;
    if (!_pluginIdShape.hasMatch(id)) return setState(() => _pluginIdError = context.l10n.childSafeGuardianIdShapeError);
    final plugins = _allow.plugins ?? const ChildSafePluginsAllow();
    _pluginId.clear();
    _pluginIdError = null;
    _setAllow((x) => x.copyWith(plugins: plugins.copyWith(ids: plugins.ids.contains(id) ? plugins.ids : [...plugins.ids, id])));
  }

  List<Widget> _snsPage(BuildContext context, ChildSafeCatalog catalog) {
    final sns = _allow.sns ?? const ChildSafeSnsAllow();
    final sessions = ref.watch(sessionsProvider).value?.allSessions ?? const [];
    final kinds = {...sns.kinds, for (final s in sessions) s.account.kind.name}.toList()..sort();
    final instances = {...sns.instances, for (final s in sessions) s.account.instance.toLowerCase()}.toList()..sort();
    Widget chip(String label, bool on, ValueChanged<bool> f, {Key? key}) => FilterChip(key: key, label: Text(label), selected: on, onSelected: f);
    List<String> toggle(List<String> l, String v, bool on) => on ? {...l, v}.toList() : [for (final x in l) if (x != v) x];
    final l = context.l10n;
    return [
      _pad(Text(l.childSafeGuardianSnsCaption, style: _caption(context))),
      _pad(Wrap(spacing: 4, children: [for (final k in kinds) chip(k, sns.kinds.contains(k), (v) => _setAllow((x) => x.copyWith(sns: sns.copyWith(kinds: toggle(sns.kinds, k, v)))), key: ValueKey('guardian.sns.kind.$k'))])),
      _pad(Wrap(spacing: 4, children: [for (final i in instances) chip(i, sns.instances.contains(i), (v) => _setAllow((x) => x.copyWith(sns: sns.copyWith(instances: toggle(sns.instances, i, v)))), key: ValueKey('guardian.sns.instance.$i'))])),
      RasqSwitchListTile(key: const ValueKey('guardian.sns.add'), title: l.childSafeGuardianSnsAdd, value: sns.addAccounts, onChanged: (v) => _setAllow((x) => x.copyWith(sns: sns.copyWith(addAccounts: v)))),
      ..._featuresOn(catalog, GuardianPage.sns),
    ];
  }

  List<Widget> _screenTimePage(BuildContext context) {
    final p = _draft!;
    final l = context.l10n;
    return [
      RasqSwitchListTile(key: const ValueKey('guardian.time.enabled'), title: l.childSafeGuardianTimeEnabled, subtitle: l.childSafeGuardianTimeEnabledSubtitle, value: p.time.enabled, onChanged: (v) => _set((d) => d.copyWith(time: d.time.copyWith(enabled: v)))),
      _pad(Row(children: [
        Expanded(child: RasqInput(key: const ValueKey('guardian.time.start'), controller: _startAt, hintText: l.childSafeGuardianTimeStartHint)),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text(l.childSafeGuardianTimeRangeSeparator)),
        Expanded(child: RasqInput(key: const ValueKey('guardian.time.end'), controller: _endAt, hintText: l.childSafeGuardianTimeEndHint)),
      ])),
      if (_legacyNothingAtNight)
        _pad(Text(l.childSafeGuardianTimeLegacyNote,
            key: const ValueKey('guardian.time.legacyNote'), style: _caption(context))),
      ..._topicsEditor(
        context,
        section: 'time',
        label: l.childSafeGuardianTimeTopics,
        topics: p.time.topics,
        controller: _timeTopics,
        allowHint: l.childSafeGuardianTimeAllowHint,
        denyHint: l.childSafeGuardianTimeDenyHint,
        allowNote: l.childSafeGuardianTimeAllowNote,
        denyNote: l.childSafeGuardianTimeDenyNote,
        withMode: (d, m) => d.copyWith(time: d.time.copyWith(topics: d.time.topics.copyWith(mode: m))),
      ),
      RasqSwitchListTile(key: const ValueKey('guardian.time.hideNotifications'), title: l.childSafeGuardianHideNotifications, value: p.time.hideNotifications, onChanged: (v) => _set((d) => d.copyWith(time: d.time.copyWith(hideNotifications: v)))),
      RasqSwitchListTile(key: const ValueKey('guardian.time.hidePostDetail'), title: l.childSafeGuardianHidePostDetail, value: p.time.hidePostDetail, onChanged: (v) => _set((d) => d.copyWith(time: d.time.copyWith(hidePostDetail: v)))),
      RasqSwitchListTile(key: const ValueKey('guardian.time.hideDirectMessages'), title: l.childSafeGuardianHideDm, value: p.time.hideDirectMessages, onChanged: (v) => _set((d) => d.copyWith(time: d.time.copyWith(hideDirectMessages: v)))),
    ];
  }

  /// その他: RAi / 検索 / ほかのページに属さない機能(カタログに無い id も)。
  List<Widget> _otherPage(BuildContext context, ChildSafeCatalog catalog) {
    final a = _allow;
    final rai = a.rai ?? const ChildSafeRaiAllow(groups: ['rai.guide', 'rai.read', 'rai.compose']);
    List<String> toggle(List<String> list, String v, bool on) => on ? {...list, v}.toList() : [for (final x in list) if (x != v) x];
    final l = context.l10n;
    return [
      const RasqSectionHeader(title: 'RAi'),
      RasqSwitchListTile(key: const ValueKey('guardian.rai.enabled'), title: l.childSafeGuardianRaiEnabled, value: rai.enabled, onChanged: (v) => _setAllow((x) => x.copyWith(rai: rai.copyWith(enabled: v)))),
      for (final g in catalog.raiGroups)
        RasqSwitchListTile(
          key: ValueKey('guardian.rai.${g.id}'),
          title: g.label,
          subtitle: g.phase > 1 ? l.childSafeGuardianRaiComingSoon : null,
          detail: g.phase > 1 ? l.childSafeGuardianRaiComingSoon : g.id,
          value: rai.groups.contains(g.id),
          onChanged: (v) => _setAllow((x) => x.copyWith(rai: rai.copyWith(groups: toggle(rai.groups, g.id, v)))),
        ),
      RasqSwitchListTile(key: const ValueKey('guardian.rai.automation'), title: l.childSafeGuardianRaiAutomation, subtitle: l.childSafeGuardianRaiAutomationSubtitle, value: rai.automation, onChanged: (v) => _setAllow((x) => x.copyWith(rai: rai.copyWith(automation: v)))),
      RasqSectionHeader(title: l.childSafeGuardianSearchSection),
      for (final f in catalog.search)
        RasqSwitchListTile(key: ValueKey('guardian.search.${f.id}'), title: f.label, value: a.search?[f.id] ?? childSafePresetDefault(_draft!.preset, 'search', f.id), onChanged: (v) => _setAllow((x) => x.copyWith(search: {...?x.search, f.id: v}))),
      RasqSectionHeader(title: l.childSafeGuardianFeaturesSection),
      ..._featuresOn(catalog, GuardianPage.other),
    ];
  }

  /// 例で決める (D-314): ページごとに自分の種類だけ(プラグインのページ = プラグイン / ストア、TL のページ = 最近のアクション /
  /// クリップ / リスト)。許す例 / 止める例の数と一覧(✕で外す)、「例を選ぶ」で共通の FOW を開く。
  List<Widget> _examplesSection(BuildContext context, {required bool plugins}) {
    final caption = _caption(context);
    final l = context.l10n;
    final scope = plugins ? 'plugins' : 'tl';
    final ex = _allow.examples ?? ContentExamples.none;
    final allow = [for (final e in ex.allow) if (guardianPluginExample(e) == plugins) e];
    final deny = [for (final e in ex.deny) if (guardianPluginExample(e) == plugins) e];
    Widget chip(ContentExample e, bool isAllow, int i) => InputChip(
          key: ValueKey('guardian.example.$scope.${isAllow ? 'allow' : 'deny'}.$i'),
          avatar: Icon(isAllow ? Icons.check_circle_outline : Icons.block, size: 16),
          deleteIcon: const Icon(Icons.close, size: 16),
          deleteButtonTooltipMessage: l.childSafeGuardianRemove,
          label: Text('${e.kind.label}: ${e.shortLabel}'),
          onDeleted: () => _setAllow((x) => x.copyWith(examples: (x.examples ?? ContentExamples.none).without(e))),
        );
    return [
      RasqSectionHeader(title: plugins ? l.childSafeGuardianExamplesTitlePlugins : l.childSafeGuardianExamplesTitleTl),
      _pad(Text(
        plugins ? l.childSafeGuardianExamplesCaptionPlugins : l.childSafeGuardianExamplesCaptionTl,
        style: caption,
      )),
      RasqListTile(
        key: ValueKey('guardian.examples.pick.$scope'),
        title: plugins ? l.childSafeGuardianPickPlugins : l.childSafeGuardianPickTl,
        subtitle: l.childSafeGuardianPickCounts(allow.length, deny.length),
        onTap: () => _pickExamples(plugins: plugins),
      ),
      if (allow.isNotEmpty || deny.isNotEmpty)
        _pad(Wrap(spacing: 4, runSpacing: 4, children: [
          for (final (i, e) in allow.indexed) chip(e, true, i),
          for (final (i, e) in deny.indexed) chip(e, false, i),
        ])),
    ];
  }

  Future<void> _pickExamples({required bool plugins}) async {
    final all = _allow.examples ?? ContentExamples.none;
    final mine = ContentExamples(allow: [for (final e in all.allow) if (guardianPluginExample(e) == plugins) e], deny: [for (final e in all.deny) if (guardianPluginExample(e) == plugins) e]);
    final own = ownExampleSources(ref);
    final l = context.l10n;
    final decisions = await openExamplePickFow(
      context,
      ref,
      id: 'guardian.examples.${plugins ? 'plugins' : 'tl'}',
      title: plugins ? l.childSafeGuardianPickTitlePlugins(widget.handle) : l.childSafeGuardianPickTitleTl(widget.handle),
      sources: plugins ? [...own.where((s) => s.id == 'plugins'), storeExampleSource(ref)] : [...own.where((s) => s.id != 'plugins')],
      initial: mine,
      allowLabel: l.childSafeGuardianAllowLabel,
      denyLabel: l.childSafeGuardianDenyLabel,
      intro: plugins ? l.childSafeGuardianPickIntroPlugins : l.childSafeGuardianPickIntroTl,
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
}
