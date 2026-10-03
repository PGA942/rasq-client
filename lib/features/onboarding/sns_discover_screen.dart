import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../backend/onboarding_discover_api.dart';
import '../../backend/server_info_api.dart';
import '../../notify/local_notifier.dart';
import '../../shell/headers.dart';
import '../child_safe/child_safe_providers.dart' show childGateProvider;
import '../collections/rasq_collections.dart' show hasRasqAccountProvider;
import '../collections/rasq_list_picker.dart' show importRasqListToHomeWith;
import '../rai/rai_widgets.dart' show RaiIcon;
import 'onboarding_previews.dart' show signupFromList;
import 'screen_glimpse.dart';
import 'server_signup.dart';

/// SNS サービスを探す画面 (D-414)。オンボーディングの ③ と、SNS のログインの「サービスを探してログイン」から開く。
///
/// 入口は 4 つ(Central の口は CONTRACT §2〜§6、どれも匿名で呼べる):
/// - **好きな画像やコンテンツから探す** — 画像を選ぶ(端末の画像の選択だけ)/ いつものブラウザで見て、通知のタップで画面を 3 秒だけ読み取る
///   (D-415、[ScreenGlimpse])/ アプリの中のブラウザで見て「この画面から探す」(本文 + URL)→ §2
/// - **有力なユーザー / インフルエンサーから探す** — 名前や分野 → §3(まず RASQ リストの中、Brave は最終手段で既定は無効)
/// - **外部 SNS のエクスポートデータから探す** — 準備中(押せない)
/// - **RAi に聞く** — クラウドの RAi との会話 → §5(端末に RAi のデータが無くてよい)
/// 結果のサーバー → D-412 の登録(WebView + RAi の案内 → ログイン)/ ログイン、RASQ リスト → SNS アカウントがあれば開いて取り込む
/// (D-347)、無ければリストの人がいるサーバーへ登録してから。RASQ アカウントは ①② で作ってあるので、D-413 のポップアップは頼まない。

/// 画面で読み取ったもの(画像 / 画面のコマ / 本文 / URL のどれか)。
@immutable
class DiscoverCapture {
  const DiscoverCapture({this.image, this.frames = const [], this.source, this.capturedAt, this.text, this.url});
  final Uint8List? image;

  /// 画面の読み取りのコマ(時刻順、D-416。CONTRACT §2 の追記の `frames`)。[image] とは併用しない。
  final List<Uint8List> frames;

  /// `screen` / `picker` / `browser`(CONTRACT §2 の追記、任意)。
  final String? source;

  /// 読み取った時刻(コマのとき)。
  final DateTime? capturedAt;
  final String? text;
  final Uri? url;
  bool get isEmpty => image == null && frames.isEmpty && (text?.trim().isEmpty ?? true) && url == null;

  /// 画面に出す画像の数(単一の画像なら 1)。
  int get pictureCount => image != null ? 1 : frames.length;

  /// [i] 番目の画像(単一の画像なら 0 番だけ)。
  Uint8List? picture(int i) => image ?? (i >= 0 && i < frames.length ? frames[i] : null);
}

/// 切り抜きがどのコマのものか (S-074: `frame` は送ったコマの番号)。無い / 範囲の外なら最後のコマに付ける。
int discoverCropFrame(DiscoverCrop crop, int pictureCount) {
  final last = pictureCount <= 0 ? 0 : pictureCount - 1;
  final f = crop.frame;
  return f == null || f < 0 || f > last ? last : f;
}

/// 最初に見せるコマ: 切り抜きのいちばん多いコマ(同数なら後ろ、切り抜きが無ければ最後)。
int discoverInitialFrame(List<DiscoverCrop> crops, int pictureCount) {
  if (pictureCount <= 1) return 0;
  final counts = List<int>.filled(pictureCount, 0);
  for (final c in crops) {
    counts[discoverCropFrame(c, pictureCount)]++;
  }
  var best = pictureCount - 1;
  for (var i = pictureCount - 1; i >= 0; i--) {
    if (counts[i] > counts[best]) best = i;
  }
  return best;
}

/// カメラで撮れる端末か。
bool get discoverCameraSupported => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

/// 画像を選ぶ口(テストで差し替える)。長辺 2048px・JPEG 品質 85 に縮めて、10 MiB に収める。
final discoverImagePickerProvider = Provider<Future<Uint8List?> Function({required bool camera})>((ref) => ({required bool camera}) async {
      final x = await ImagePicker().pickImage(source: camera ? ImageSource.camera : ImageSource.gallery, maxWidth: 2048, maxHeight: 2048, imageQuality: 85);
      return x?.readAsBytes();
    });

/// 端末のブラウザでページを開く口(テストで差し替える)。
final discoverExternalBrowserProvider = Provider<Future<bool> Function(Uri)>((ref) => (url) async {
      try {
        return await launchUrl(url, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('discover external browser: $e');
        return false;
      }
    });

/// 探す画面の入口。
class SnsDiscoverScreen extends ConsumerWidget {
  const SnsDiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final raiOk = ref.watch(childGateProvider).raiEnabled;
    return Scaffold(
      appBar: const RasqPageHeader(title: 'SNS サービスを探す', showMore: false),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(key: const ValueKey('discover.list'), children: [
              Padding(
                padding: const EdgeInsets.all(RasqSpacing.page),
                child: Text('好きなものから、合いそうな SNS のサーバーと RASQ リスト(SNS をまたいだ人のリスト)を探します。', style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant)),
              ),
              RasqListTile(
                key: const ValueKey('discover.content'),
                leading: const Icon(Icons.image_search),
                title: '好きな画像やコンテンツから探す',
                subtitle: '画像を選ぶか、ブラウザで見ているページから',
                onTap: () => context.push(Routes.snsDiscoverContent),
              ),
              RasqListTile(
                key: const ValueKey('discover.people'),
                leading: const Icon(Icons.person_search),
                title: '有力なユーザー / インフルエンサーから探す',
                subtitle: '好きな人の名前や分野から',
                onTap: () => context.push(Routes.snsDiscoverPeople),
              ),
              const RasqListTile(
                key: ValueKey('discover.export'),
                leading: Icon(Icons.file_open_outlined),
                title: '外部 SNS のエクスポートデータから探す',
                subtitle: '準備中',
                enabled: false,
                chevron: false,
              ),
              RasqListTile(
                key: const ValueKey('discover.ask'),
                leading: const RaiIcon(size: 24),
                title: 'RAi に聞く',
                subtitle: raiOk ? 'どんな SNS が合うか、話しながら探します' : '保護者が RAi を止めています',
                enabled: raiOk,
                onTap: raiOk ? () => context.push(Routes.snsDiscoverAsk) : null,
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 結果(RASQ リスト / サーバー)と、その先

/// サーバーの候補から: 登録(D-412 の WebView + RAi の案内)/ ログイン。
Future<void> openServerHit(BuildContext context, WidgetRef ref, ServerHit hit, {bool login = false}) async {
  RasqServerInfo? info;
  try {
    info = await ref.read(serverInfoProvider(hit.host).future);
  } catch (_) {}
  final software = info?.software ?? (hit.kind.isEmpty ? null : hit.kind);
  final kind = signupKindOf(software) ?? signupKindOf(hit.kind);
  if (!context.mounted) return;
  if (kind == null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${hit.host} には、アプリから${login ? 'ログイン' : '登録'}できません')));
    return;
  }
  final target = ServerSignupTarget(
    host: hit.host,
    kind: kind,
    software: software,
    name: info?.name ?? (hit.name.isEmpty ? null : hit.name),
    registrationOpen: info?.registrationOpen,
    nudgeRasqAccount: false,
  );
  if (login) {
    if (!ref.read(childGateProvider).canAddAccounts) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保護者が SNS アカウントの追加を止めています')));
      return;
    }
    unawaited(context.push(target.loginLocation));
    return;
  }
  startServerSignup(context, ref, target);
}

/// RASQ リストの候補から: SNS アカウントがあれば、リストを開いて取り込む (D-347)。無ければ、リストの人がいるサーバーに登録してから。
Future<void> openListHit(BuildContext context, WidgetRef ref, ListHit hit) async {
  final loggedIn = ref.read(sessionsProvider).value?.isLoggedIn ?? false;
  final list = hit.toCollection();
  if (!loggedIn) {
    await signupFromList(context, ref, list, nudgeRasqAccount: false);
    return;
  }
  final c = ProviderScope.containerOf(context, listen: false);
  final messenger = ScaffoldMessenger.of(context);
  unawaited(context.push(Routes.rasqCollection(hit.id)));
  if (ref.read(hasRasqAccountProvider)) {
    final (message, _) = await importRasqListToHomeWith(c, list);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

/// 結果の一覧(RASQ リスト → サーバー)。
class DiscoverResultsView extends ConsumerWidget {
  const DiscoverResultsView({super.key, required this.result});
  final DiscoverResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final caption = RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      if (result.mode == 'dummy') Padding(padding: const EdgeInsets.only(bottom: RasqSpacing.xs), child: Text('見本の結果です(サーバーの外部サービスが未設定)', key: const ValueKey('discover.dummy'), style: caption)),
      if (result.lists.isNotEmpty) ...[
        Text('RASQ リスト', style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: RasqSpacing.xs),
        for (final l in result.lists) Padding(padding: const EdgeInsets.only(bottom: RasqSpacing.xs), child: ListHitCard(hit: l)),
      ],
      if (result.servers.isNotEmpty) ...[
        const SizedBox(height: RasqSpacing.xs),
        Text('サーバー', style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: RasqSpacing.xs),
        for (final s in result.servers) Padding(padding: const EdgeInsets.only(bottom: RasqSpacing.xs), child: ServerHitCard(hit: s)),
      ],
    ]);
  }
}

Widget _card(BuildContext context, {required Key key, required List<Widget> children}) {
  final scheme = Theme.of(context).colorScheme;
  return Container(
    key: key,
    padding: const EdgeInsets.all(RasqSpacing.sm),
    decoration: BoxDecoration(color: scheme.surface, borderRadius: BorderRadius.circular(RasqSizes.radiusMd), border: Border.all(color: scheme.outlineVariant)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: children),
  );
}

class ListHitCard extends ConsumerWidget {
  const ListHitCard({super.key, required this.hit});
  final ListHit hit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final caption = RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant);
    final loggedIn = ref.watch(sessionsProvider).value?.isLoggedIn ?? false;
    return _card(context, key: ValueKey('discover.listHit.${hit.id}'), children: [
      Row(children: [
        const Icon(Icons.groups_outlined, size: 18),
        const SizedBox(width: RasqSpacing.xs),
        Expanded(child: Text(hit.name, style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)),
        Text('${hit.memberCount} 人', style: caption),
      ]),
      if (hit.ownerHandle.isNotEmpty) Text('@${hit.ownerHandle} のリスト', style: caption),
      if (hit.description.isNotEmpty) Text(hit.description, style: RasqTypography.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
      if (hit.reason.isNotEmpty) Text(hit.reason, style: caption, maxLines: 2, overflow: TextOverflow.ellipsis),
      if (hit.sampleHosts.isNotEmpty) Text('サーバー: ${hit.sampleHosts.take(4).join('、')}', style: caption, maxLines: 1, overflow: TextOverflow.ellipsis),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          key: ValueKey('discover.listHit.${hit.id}.open'),
          onPressed: () => openListHit(context, ref, hit),
          child: Text(loggedIn ? 'リストを開いて取り込む' : 'リストの人のサーバーに登録'),
        ),
      ),
    ]);
  }
}

class ServerHitCard extends ConsumerWidget {
  const ServerHitCard({super.key, required this.hit});
  final ServerHit hit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final caption = RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant);
    return _card(context, key: ValueKey('discover.serverHit.${hit.host}'), children: [
      Row(children: [
        const Icon(Icons.dns_outlined, size: 18),
        const SizedBox(width: RasqSpacing.xs),
        Expanded(child: Text(hit.name.isEmpty ? hit.host : hit.name, style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)),
        if (hit.kind.isNotEmpty) Text(hit.kind, style: caption),
      ]),
      Text(hit.host, style: caption),
      if (hit.reason.isNotEmpty) Text(hit.reason, style: caption, maxLines: 2, overflow: TextOverflow.ellipsis),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        TextButton(key: ValueKey('discover.serverHit.${hit.host}.login'), onPressed: () => openServerHit(context, ref, hit, login: true), child: const Text('ログイン')),
        FilledButton.tonal(key: ValueKey('discover.serverHit.${hit.host}.signup'), onPressed: () => openServerHit(context, ref, hit), child: const Text('登録する')),
      ]),
    ]);
  }
}

String _errorText(Object e) => e is ArgumentError ? '${e.message}' : 'うまく探せませんでした。時間をおいて、もう一度試してください';

// ---------------------------------------------------------------------------
// a. 好きな画像やコンテンツから探す

class DiscoverContentScreen extends ConsumerStatefulWidget {
  const DiscoverContentScreen({super.key, this.initial, this.startGlimpse = false, this.glimpseResultId});
  final DiscoverCapture? initial;

  /// 画面の読み取りの通知をタップして開いた (D-415、`?glimpse=1`): 開いたらすぐ読み取る。
  final bool startGlimpse;

  /// Android で読み取り終えた結果の id (D-416、`?glimpse=done&id=…`): 開いたらコマを送る。
  final String? glimpseResultId;
  @override
  ConsumerState<DiscoverContentScreen> createState() => _DiscoverContentScreenState();
}

class _DiscoverContentScreenState extends ConsumerState<DiscoverContentScreen> {
  DiscoverCapture? _capture;
  ui.Size? _imageSize;

  /// いま見せているコマ(画面の読み取りで何枚もあるとき)。
  int _frame = 0;
  bool _busy = false;
  String? _error;
  ContentDiscoverResult? _result;

  /// 画面の読み取り (D-415): 通知を出して待っている / 読み取っている(経過)/ 送ったコマの数。
  bool _glimpseArmed = false;
  Duration? _glimpseElapsed;
  int? _glimpseFrames;
  late final DiscoverGlimpseRequests _glimpseRequests = ref.read(discoverGlimpseRequestsProvider);

  /// Android の読み取り (D-416): 端末からの知らせと、扱った読み取りの id(done と通知のタップの両方で来るので 1 度だけ)。
  late final ScreenGlimpse _glimpser = ref.read(screenGlimpseProvider);
  StreamSubscription<GlimpseEvent>? _glimpseEvents;
  static final _handledGlimpses = <String>{};

  @override
  void initState() {
    super.initState();
    _glimpseRequests.addListener(_onGlimpseTap);
    if (_glimpser.native) _glimpseEvents = _glimpser.events.listen(_onGlimpseEvent);
    final i = widget.initial;
    final resultId = widget.glimpseResultId;
    if (resultId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _sendGlimpseResult(resultId));
    } else if (widget.startGlimpse) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _glimpse());
    } else if (i != null && !i.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _search(i));
    }
  }

  @override
  void dispose() {
    _glimpseRequests.removeListener(_onGlimpseTap);
    unawaited(_glimpseEvents?.cancel());
    super.dispose();
  }

  /// 通知をタップした(この画面を開いたまま)。id つきなら Android で読み取り終えた結果。
  void _onGlimpseTap() {
    if (!mounted) return;
    final id = _glimpseRequests.takeId();
    unawaited(id == null ? _glimpse() : _sendGlimpseResult(id));
  }

  /// 端末からの知らせ (D-416)。
  void _onGlimpseEvent(GlimpseEvent e) {
    if (!mounted) return;
    switch (e.type) {
      case 'done':
        // この画面を開いたまま読み取り終えた(RASQ は後ろにいる): すぐ送っておく。通知のタップで戻ると結果が出ている。
        if (e.id != null) unawaited(_sendGlimpseResult(e.id!));
      case 'stopped':
        final why = switch (e.reason) {
          'cancel' => null,
          'system' => '画面の読み取りが止められました(端末の「共有を停止」や画面のロック)。もう一度「いつものブラウザで見て探す」から始めてください',
          'timeout' => '10 分たったので、画面の読み取りの準備を止めました',
          'killed' => '画面の読み取りが端末に止められました。もう一度始めてください',
          'empty' => '画面を読み取れませんでした(写しが取れませんでした)',
          _ => '画面を読み取れませんでした',
        };
        setState(() {
          _glimpseArmed = false;
          if (why != null) _error = why;
        });
    }
  }

  /// 「いつものブラウザで見て探す」: Android は同意 → 端末の通知(読み取りのボタン)、ほかは RASQ の通知。そのあと端末のブラウザを開く。
  Future<void> _armGlimpse() async {
    if (_glimpser.native) {
      final status = await _glimpser.start();
      if (!mounted) return;
      final error = switch (status) {
        GlimpseStartStatus.started || GlimpseStartStatus.busy => null,
        GlimpseStartStatus.denied => '画面の読み取りが許可されませんでした。読み取るには、もう一度押して「開始」を選んでください(読み取るのはボタンを押したあとの 3 秒だけです)',
        GlimpseStartStatus.notificationsDenied => '通知を出せませんでした。読み取りのボタンは通知に出るので、端末の設定で RASQ の通知を許可してください',
        GlimpseStartStatus.unavailable => 'この端末では画面を読み取れません。画像を選ぶか、アプリの中のブラウザで探してください',
      };
      if (error != null) {
        setState(() => _error = error);
        return;
      }
      setState(() {
        _glimpseArmed = true;
        _error = null;
      });
      await ref.read(discoverExternalBrowserProvider)(discoverBrowserHome);
      return;
    }
    final ok = await showDiscoverGlimpseNotification(ref.read(localNotifierProvider));
    if (!mounted) return;
    if (!ok) {
      setState(() => _error = '通知を出せませんでした。端末の設定で RASQ の通知を許可してください');
      return;
    }
    setState(() {
      _glimpseArmed = true;
      _error = null;
    });
    await ref.read(discoverExternalBrowserProvider)(discoverBrowserHome);
  }

  Future<void> _disarmGlimpse() async {
    if (_glimpser.native) {
      await _glimpser.cancel();
    } else {
      await ref.read(localNotifierProvider).cancel(discoverGlimpseNotificationId);
    }
    if (mounted) setState(() => _glimpseArmed = false);
  }

  /// 画面を 3 秒だけ読み取って送る。
  Future<void> _glimpse() async {
    if (_glimpseElapsed != null || _busy) return;
    setState(() {
      _glimpseArmed = false;
      _glimpseElapsed = Duration.zero;
      _glimpseFrames = null;
      _error = null;
      _result = null;
    });
    GlimpseFrames? frames;
    try {
      frames = await ref.read(screenGlimpseProvider).capture(
            duration: discoverGlimpseDuration,
            onProgress: (d) {
              if (mounted) setState(() => _glimpseElapsed = d);
            },
          );
    } catch (e) {
      debugPrint('discover glimpse: $e');
    }
    unawaited(ref.read(localNotifierProvider).cancel(discoverGlimpseNotificationId));
    if (!mounted) return;
    setState(() => _glimpseElapsed = null);
    if (frames == null || frames.isEmpty) {
      setState(() => _error = '画面を読み取れませんでした');
      return;
    }
    _glimpseFrames = frames.frames.length;
    await _search(DiscoverCapture(frames: frames.frames, source: 'screen', capturedAt: frames.capturedAt, text: frames.text, url: frames.url));
  }

  /// Android で読み取り終えたコマを送る (D-416)。送ったら(うまくいかなくても)コマを消す。
  Future<void> _sendGlimpseResult(String id) async {
    if (!_handledGlimpses.add(id)) return;
    if (_handledGlimpses.length > 32) _handledGlimpses.remove(_handledGlimpses.first);
    setState(() {
      _glimpseArmed = false;
      _error = null;
    });
    final frames = await _glimpser.takeResult(id);
    if (!mounted) {
      await _glimpser.discard(id);
      return;
    }
    if (frames == null || frames.frames.isEmpty) {
      await _glimpser.discard(id);
      if (mounted) setState(() => _error = '読み取った画面が見つかりませんでした(時間がたって消えたか、もう送りました)');
      return;
    }
    _glimpseFrames = frames.frames.length;
    try {
      await _search(DiscoverCapture(frames: frames.frames.take(discoverFramesMax).toList(), source: 'screen', capturedAt: frames.capturedAt));
    } finally {
      await _glimpser.discard(id);
    }
  }

  Future<void> _pick({required bool camera}) async {
    final bytes = await ref.read(discoverImagePickerProvider)(camera: camera);
    if (bytes == null || !mounted) return;
    _glimpseFrames = null;
    await _search(DiscoverCapture(image: bytes));
  }

  Future<void> _browse() async {
    final cap = await context.push<DiscoverCapture>(Routes.snsDiscoverBrowse);
    if (cap != null && !cap.isEmpty && mounted) {
      _glimpseFrames = null;
      await _search(cap);
    }
  }

  Future<void> _search(DiscoverCapture cap) async {
    final api = ref.read(onboardingDiscoverApiProvider);
    var c = cap;
    if (c.frames.isNotEmpty) {
      // 送れないコマ(形式 / 大きさ)は外し、合計 24 MiB に収まるよう新しい方を残す。
      final ok = [for (final f in c.frames) if (discoverImageMime(f) != null && f.length <= discoverImageMaxBytes) f];
      final kept = <Uint8List>[];
      var total = 0;
      for (final f in ok.reversed) {
        if (kept.length >= discoverFramesMax || total + f.length > discoverFramesMaxTotalBytes) break;
        kept.insert(0, f);
        total += f.length;
      }
      c = DiscoverCapture(frames: kept, source: c.source, capturedAt: c.capturedAt, text: c.text, url: c.url);
      if (c.isEmpty) {
        setState(() => _error = '画面を読み取れませんでした');
        return;
      }
    }
    final img = c.image;
    if (img != null && (discoverImageMime(img) == null || img.length > discoverImageMaxBytes)) {
      // 送れない画像(形式 / 大きさ)。本文 / URL があればそれだけで探す。
      c = DiscoverCapture(text: c.text, url: c.url);
      if (c.isEmpty) {
        setState(() => _error = 'JPEG / PNG / WebP の 10 MiB までの画像を選んでください');
        return;
      }
    }
    setState(() {
      _capture = c;
      _imageSize = null;
      _frame = c.pictureCount > 0 ? c.pictureCount - 1 : 0;
      _busy = true;
      _error = null;
      _result = null;
    });
    final shown = c.picture(_frame);
    if (shown != null) unawaited(_measure(shown));
    try {
      if (api == null) throw ArgumentError('RASQ Central の接続先が未設定です');
      final r = await api.content(image: c.image, frames: c.frames, source: c.source, capturedAt: c.capturedAt, text: c.text, url: c.url);
      if (mounted) {
        setState(() => _result = r);
        if (c.pictureCount > 1) _showFrame(discoverInitialFrame(r.query.crops, c.pictureCount));
      }
    } catch (e) {
      debugPrint('discover content: $e');
      if (mounted) setState(() => _error = _errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 画素で返った切り抜きを重ねるために、画像の大きさを知る(割合なら要らない)。
  Future<void> _measure(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final size = ui.Size(frame.image.width.toDouble(), frame.image.height.toDouble());
      frame.image.dispose();
      if (mounted && identical(_capture?.picture(_frame), bytes)) setState(() => _imageSize = size);
    } catch (_) {}
  }

  /// コマを切り替える(切り抜きはそのコマの分だけ重ねる)。
  void _showFrame(int i) {
    final bytes = _capture?.picture(i);
    if (bytes == null || i == _frame) return;
    setState(() {
      _frame = i;
      _imageSize = null;
    });
    unawaited(_measure(bytes));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final caption = RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant);
    final cap = _capture;
    final r = _result;
    final elapsed = _glimpseElapsed;
    final idle = !_busy && elapsed == null;
    final glimpseDummy = ref.watch(screenGlimpseProvider).isDummy;
    return Scaffold(
      appBar: const RasqPageHeader(title: '好きな画像やコンテンツから探す', showMore: false),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(key: const ValueKey('discover.content.list'), padding: const EdgeInsets.all(RasqSpacing.page), children: [
              Text('好きな画像や、見ていたページから、探す言葉を RAi が作ります。画像はサーバーに保存しません(探し終えたら捨てます)。', style: caption),
              const SizedBox(height: RasqSpacing.sm),
              Wrap(spacing: RasqSpacing.xs, runSpacing: RasqSpacing.xs, children: [
                FilledButton.icon(key: const ValueKey('discover.content.pick'), onPressed: idle ? () => _pick(camera: false) : null, icon: const Icon(Icons.photo_library_outlined, size: 18), label: const Text('画像を選ぶ')),
                if (discoverCameraSupported)
                  OutlinedButton.icon(key: const ValueKey('discover.content.camera'), onPressed: idle ? () => _pick(camera: true) : null, icon: const Icon(Icons.photo_camera_outlined, size: 18), label: const Text('写真を撮る')),
                OutlinedButton.icon(key: const ValueKey('discover.content.glimpse'), onPressed: idle ? _armGlimpse : null, icon: const Icon(Icons.open_in_browser, size: 18), label: const Text('いつものブラウザで見て探す')),
                TextButton.icon(key: const ValueKey('discover.content.browse'), onPressed: idle ? _browse : null, icon: const Icon(Icons.public, size: 18), label: const Text('アプリの中のブラウザで探す')),
              ]),
              if (_glimpseArmed)
                _GlimpseCard(
                  key: const ValueKey('discover.content.glimpse.armed'),
                  icon: Icons.notifications_active_outlined,
                  text: '通知を出しました。ブラウザで探したい画面を開いてから、通知をタップしてください。タップすると、その画面を 3 秒だけ読み取ります。',
                  dummy: glimpseDummy,
                  action: TextButton(key: const ValueKey('discover.content.glimpse.cancel'), onPressed: _disarmGlimpse, child: const Text('やめる')),
                ),
              if (elapsed != null)
                _GlimpseCard(
                  key: const ValueKey('discover.content.glimpse.capturing'),
                  icon: Icons.center_focus_strong,
                  text: '画面を読み取っています(${elapsed.inSeconds} / ${discoverGlimpseDuration.inSeconds} 秒)',
                  dummy: glimpseDummy,
                  progress: elapsed.inMilliseconds / discoverGlimpseDuration.inMilliseconds,
                ),
              if (_glimpseFrames != null && elapsed == null)
                Padding(
                  padding: const EdgeInsets.only(top: RasqSpacing.sm),
                  child: Text('画面を ${discoverGlimpseDuration.inSeconds} 秒読み取りました(${_glimpseFrames!} コマ)${glimpseDummy ? '。いまは試作のため、ダミーの写しです' : ''}', key: const ValueKey('discover.content.glimpse.done'), style: caption),
                ),
              if (cap != null) ...[
                const SizedBox(height: RasqSpacing.md),
                if (cap.picture(_frame) != null)
                  _CropPreview(
                    image: cap.picture(_frame)!,
                    crops: [for (final c in r?.query.crops ?? const <DiscoverCrop>[]) if (discoverCropFrame(c, cap.pictureCount) == _frame) c],
                    imageSize: _imageSize,
                  ),
                if (cap.pictureCount > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: RasqSpacing.xs),
                    child: Wrap(spacing: RasqSpacing.xs, children: [
                      for (var i = 0; i < cap.pictureCount; i++)
                        ChoiceChip(
                          key: ValueKey('discover.content.frame.$i'),
                          label: Text('${i + 1} コマ目'),
                          selected: i == _frame,
                          visualDensity: VisualDensity.compact,
                          onSelected: (_) => _showFrame(i),
                        ),
                    ]),
                  ),
                if (cap.url != null) Text(cap.url.toString(), key: const ValueKey('discover.content.url'), style: caption, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
              if (_busy) const Padding(padding: EdgeInsets.all(RasqSpacing.md), child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: RasqSpacing.sm), child: Text(_error!, key: const ValueKey('discover.content.error'), style: RasqTypography.bodySmall.copyWith(color: scheme.error))),
              if (r != null) ...[
                const SizedBox(height: RasqSpacing.md),
                Text('探す言葉', style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700)),
                if (r.query.text.isNotEmpty) Text(r.query.text, key: const ValueKey('discover.content.query'), style: RasqTypography.bodySmall),
                const SizedBox(height: RasqSpacing.xs),
                Wrap(spacing: RasqSpacing.xs, runSpacing: RasqSpacing.xs, children: [
                  for (final k in r.query.keywords) Chip(key: ValueKey('discover.keyword.$k'), label: Text(k), visualDensity: VisualDensity.compact),
                  for (final c in r.query.crops)
                    if (c.label.isNotEmpty) Chip(avatar: const Icon(Icons.crop, size: 14), label: Text(c.label), visualDensity: VisualDensity.compact),
                ]),
                const SizedBox(height: RasqSpacing.sm),
                if (r.isEmpty) Text('合うリストやサーバーは見つかりませんでした', key: const ValueKey('discover.content.empty'), style: caption) else DiscoverResultsView(result: r),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

/// 画面の読み取りの案内 (D-415): 通知を待っている / 読み取っている。
class _GlimpseCard extends StatelessWidget {
  const _GlimpseCard({super.key, required this.icon, required this.text, this.dummy = false, this.action, this.progress});
  final IconData icon;
  final String text;
  final bool dummy;
  final Widget? action;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: RasqSpacing.sm),
      child: DecoratedBox(
        decoration: BoxDecoration(color: scheme.surfaceContainerHighest.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(RasqSizes.radiusLg), border: Border.all(color: scheme.outlineVariant)),
        child: Padding(
          padding: const EdgeInsets.all(RasqSpacing.sm),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, size: 20, color: scheme.primary),
              const SizedBox(width: RasqSpacing.sm),
              Expanded(child: Text(text, style: RasqTypography.bodySmall)),
              ?action,
            ]),
            if (progress != null) ...[
              const SizedBox(height: RasqSpacing.xs),
              LinearProgressIndicator(value: progress!.clamp(0.0, 1.0)),
            ],
            if (dummy)
              Padding(
                padding: const EdgeInsets.only(top: RasqSpacing.xs),
                child: Text('いまは試作のため、画面は読まずにダミーの写しを送ります', key: const ValueKey('discover.content.glimpse.dummy'), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
              ),
          ]),
        ),
      ),
    );
  }
}

/// 選んだ画像の上に、RAi が切り抜くべきとした部分の枠を重ねる。
class _CropPreview extends StatelessWidget {
  const _CropPreview({required this.image, required this.crops, this.imageSize});
  final Uint8List image;
  final List<DiscoverCrop> crops;
  final ui.Size? imageSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 320),
      child: Center(
        child: Stack(key: const ValueKey('discover.content.image'), children: [
          Image.memory(image, fit: BoxFit.contain, errorBuilder: (_, _, _) => SizedBox(height: 120, child: Center(child: Icon(Icons.image_outlined, color: scheme.onSurfaceVariant)))),
          Positioned.fill(
            child: LayoutBuilder(builder: (context, c) {
              return Stack(children: [
                for (final (i, crop) in crops.indexed)
                  if (crop.fractional || imageSize != null)
                    () {
                      final sx = crop.fractional ? c.maxWidth : c.maxWidth / imageSize!.width;
                      final sy = crop.fractional ? c.maxHeight : c.maxHeight / imageSize!.height;
                      return Positioned(
                        key: ValueKey('discover.crop.$i'),
                        left: crop.x * sx,
                        top: crop.y * sy,
                        width: crop.w * sx,
                        height: crop.h * sy,
                        child: IgnorePointer(
                          child: DecoratedBox(decoration: BoxDecoration(border: Border.all(color: RasqColors.sub, width: 2), borderRadius: BorderRadius.circular(4))),
                        ),
                      );
                    }(),
              ]);
            }),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// a'. アプリの中のブラウザで見て「この画面から探す」

/// 見ているページを読み取る口(テストではフェイク)。
abstract interface class DiscoverPageCapturer {
  void load(Uri url);
  Future<DiscoverCapture> capture();
}

/// ブラウザの部分(テストで差し替える)。[attach] = 読み取りの口ができた。
typedef DiscoverBrowserBuilder = Widget Function(BuildContext context, Uri initial, ValueChanged<DiscoverPageCapturer> attach);

final discoverBrowserProvider = Provider<DiscoverBrowserBuilder>(
  (ref) => (context, initial, attach) => inAppSignupWebViewSupported ? _InAppDiscoverBrowser(initial: initial, attach: attach) : const _ManualCapturePanel(),
);

/// 最初に開くページ(検索)。
final discoverBrowserHome = Uri.parse('https://duckduckgo.com/');

/// アドレス欄の文字 → 開く URL(URL でなければ検索)。
Uri discoverAddressToUrl(String input) {
  final t = input.trim();
  final u = Uri.tryParse(t);
  if (u != null && (u.scheme == 'https' || u.scheme == 'http') && u.host.contains('.')) return u;
  if (!t.contains(' ') && RegExp(r'^[\w-]+(\.[\w-]+)+(/.*)?$').hasMatch(t)) return Uri.parse('https://$t');
  return Uri.https('duckduckgo.com', '/', {'q': t});
}

/// `runJavaScriptReturningResult` の文字列(Android は JSON の文字列で返る、iOS / macOS はそのまま)。
String webJsString(Object? r) {
  if (r is! String) return r?.toString() ?? '';
  if (r.length >= 2 && r.startsWith('"') && r.endsWith('"')) {
    try {
      return jsonDecode(r) as String;
    } catch (_) {}
  }
  return r;
}

/// ページの本文を読む JavaScript(見出し + 本文、4000 字まで)。
const discoverPageTextScript = "(function(){var t=(document.title||'')+'\\n'+((document.body&&document.body.innerText)||'');return t.slice(0,4000);})()";

class DiscoverBrowseScreen extends ConsumerStatefulWidget {
  const DiscoverBrowseScreen({super.key});
  @override
  ConsumerState<DiscoverBrowseScreen> createState() => _DiscoverBrowseScreenState();
}

class _DiscoverBrowseScreenState extends ConsumerState<DiscoverBrowseScreen> {
  final _address = TextEditingController();
  DiscoverPageCapturer? _capturer;
  bool _busy = false;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _captureAndReturn() async {
    final c = _capturer;
    if (c == null) return;
    setState(() => _busy = true);
    try {
      final cap = await c.capture();
      if (mounted) context.pop(cap);
    } catch (e) {
      debugPrint('discover capture: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('この画面を読み取れませんでした')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final area = ref.watch(discoverBrowserProvider)(context, discoverBrowserHome, (c) {
      if (!identical(_capturer, c)) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? setState(() => _capturer = c) : null);
    });
    return Scaffold(
      appBar: const RasqPageHeader(title: 'アプリの中のブラウザで探す', showMore: false),
      body: SafeArea(
        top: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (_capturer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(RasqSpacing.sm, RasqSpacing.xs, RasqSpacing.sm, RasqSpacing.xs),
              child: TextField(
                key: const ValueKey('discover.browse.address'),
                controller: _address,
                textInputAction: TextInputAction.go,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(isDense: true, prefixIcon: Icon(Icons.search, size: 18), hintText: '調べたい言葉 / URL'),
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty) _capturer?.load(discoverAddressToUrl(v));
                },
              ),
            ),
          Expanded(child: area),
          if (_capturer != null)
            Padding(
              padding: const EdgeInsets.all(RasqSpacing.sm),
              child: FilledButton.icon(
                key: const ValueKey('discover.browse.capture'),
                onPressed: _busy ? null : _captureAndReturn,
                icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.center_focus_strong, size: 18),
                label: const Text('この画面から探す'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
              ),
            ),
        ]),
      ),
    );
  }
}

/// アプリの中のブラウザ(Android / iOS / macOS)。「この画面から探す」= **本文 + URL だけ**(CONTRACT §2 の text / url)。
/// 画面の写しは送らない (D-415): 画像は端末の画像の選択だけ、画面は「いつものブラウザで見て探す」の通知から読み取る([ScreenGlimpse])。
class _InAppDiscoverBrowser extends StatefulWidget {
  const _InAppDiscoverBrowser({required this.initial, required this.attach});
  final Uri initial;
  final ValueChanged<DiscoverPageCapturer> attach;
  @override
  State<_InAppDiscoverBrowser> createState() => _InAppDiscoverBrowserState();
}

class _InAppDiscoverBrowserState extends State<_InAppDiscoverBrowser> implements DiscoverPageCapturer {
  late final WebViewController _controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setNavigationDelegate(NavigationDelegate(
      onNavigationRequest: (r) {
        final u = Uri.tryParse(r.url);
        if (u == null || u.scheme == 'https' || u.scheme == 'http' || u.scheme == 'about') return NavigationDecision.navigate;
        return NavigationDecision.prevent;
      },
    ))
    ..loadRequest(widget.initial);

  @override
  void initState() {
    super.initState();
    widget.attach(this);
  }

  @override
  void load(Uri url) => unawaited(_controller.loadRequest(url));

  @override
  Future<DiscoverCapture> capture() async {
    final url = Uri.tryParse(await _controller.currentUrl() ?? '');
    String? text;
    try {
      text = webJsString(await _controller.runJavaScriptReturningResult(discoverPageTextScript)).trim();
    } catch (_) {}
    return DiscoverCapture(text: text, url: url);
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(key: const ValueKey('discover.webview'), controller: _controller);
}

/// アプリの中でブラウザを開けない端末(Linux / Windows / Web): 外のブラウザで見て、URL と気になった文を貼ってもらう。
class _ManualCapturePanel extends StatefulWidget {
  const _ManualCapturePanel();
  @override
  State<_ManualCapturePanel> createState() => _ManualCapturePanelState();
}

class _ManualCapturePanelState extends State<_ManualCapturePanel> {
  final _url = TextEditingController();
  final _text = TextEditingController();

  @override
  void dispose() {
    _url.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final u = Uri.tryParse(_url.text.trim());
    final url = u != null && (u.scheme == 'https' || u.scheme == 'http') && u.host.isNotEmpty ? u : null;
    final ok = url != null || _text.text.trim().isNotEmpty;
    return ListView(padding: const EdgeInsets.all(RasqSpacing.page), children: [
      Text('この端末では、アプリの中でブラウザを開けません。いつものブラウザで見て、ページの URL と気になった文を貼り付けてください。',
          style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant)),
      const SizedBox(height: RasqSpacing.sm),
      OutlinedButton.icon(
        onPressed: () => launchUrl(discoverBrowserHome, mode: LaunchMode.externalApplication),
        icon: const Icon(Icons.open_in_new, size: 18),
        label: const Text('ブラウザを開く'),
      ),
      TextField(key: const ValueKey('discover.manual.url'), controller: _url, keyboardType: TextInputType.url, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'ページの URL')),
      TextField(
        key: const ValueKey('discover.manual.text'),
        controller: _text,
        minLines: 3,
        maxLines: 8,
        maxLength: discoverTextMaxChars,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(labelText: '気になった文(任意)'),
      ),
      FilledButton(
        key: const ValueKey('discover.manual.submit'),
        onPressed: ok ? () => context.pop(DiscoverCapture(url: url, text: _text.text.trim())) : null,
        child: const Text('この内容で探す'),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// b. 有力なユーザー / インフルエンサーから探す

class DiscoverPeopleScreen extends ConsumerStatefulWidget {
  const DiscoverPeopleScreen({super.key});
  @override
  ConsumerState<DiscoverPeopleScreen> createState() => _DiscoverPeopleScreenState();
}

class _DiscoverPeopleScreenState extends ConsumerState<DiscoverPeopleScreen> {
  final _query = TextEditingController();
  bool _busy = false;
  String? _error;
  PeopleDiscoverResult? _result;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.isEmpty) return;
    final api = ref.read(onboardingDiscoverApiProvider);
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      if (api == null) throw ArgumentError('RASQ Central の接続先が未設定です');
      final r = await api.people(q);
      if (mounted) setState(() => _result = r);
    } catch (e) {
      debugPrint('discover people: $e');
      if (mounted) setState(() => _error = _errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final caption = RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant);
    final r = _result;
    return Scaffold(
      appBar: const RasqPageHeader(title: '有力なユーザー / インフルエンサーから探す', showMore: false),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(key: const ValueKey('discover.people.list'), padding: const EdgeInsets.all(RasqSpacing.page), children: [
              Text('好きな人の名前や、気になる分野を入れてください。まず公開の RASQ リストの中から探します。', style: caption),
              const SizedBox(height: RasqSpacing.sm),
              TextField(
                key: const ValueKey('discover.people.query'),
                controller: _query,
                maxLength: discoverPeopleMaxChars,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: '人の名前 / 分野', hintText: '例: 鉄道写真、イラストレーター'),
              ),
              FilledButton.icon(
                key: const ValueKey('discover.people.search'),
                onPressed: _busy || _query.text.trim().isEmpty ? null : _search,
                icon: const Icon(Icons.search, size: 18),
                label: const Text('探す'),
              ),
              if (_busy) const Padding(padding: EdgeInsets.all(RasqSpacing.md), child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: RasqSpacing.sm), child: Text(_error!, style: RasqTypography.bodySmall.copyWith(color: scheme.error))),
              if (r != null && r.notFound) ...[
                // 3 の追記: RASQ リストに無く、Web 検索(Brave)も使わなかった。ほかの入口を勧める。
                const SizedBox(height: RasqSpacing.md),
                Text('RASQ リストでは見つかりませんでした', key: const ValueKey('discover.people.notFound'), style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: RasqSpacing.xs),
                Text('好きな画像やページから探すか、RAi に聞いてみてください。', style: caption),
                const SizedBox(height: RasqSpacing.xs),
                Wrap(spacing: RasqSpacing.xs, runSpacing: RasqSpacing.xs, children: [
                  OutlinedButton.icon(
                    key: const ValueKey('discover.people.tryContent'),
                    onPressed: () => context.pushReplacement(Routes.snsDiscoverContent),
                    icon: const Icon(Icons.image_search, size: 18),
                    label: const Text('画像やコンテンツから探す'),
                  ),
                  if (ref.watch(childGateProvider).raiEnabled)
                    OutlinedButton.icon(
                      key: const ValueKey('discover.people.tryAsk'),
                      onPressed: () => context.pushReplacement(Routes.snsDiscoverAsk),
                      icon: const RaiIcon(size: 18),
                      label: const Text('RAi に聞く'),
                    ),
                ]),
                if (r.servers.isNotEmpty) ...[const SizedBox(height: RasqSpacing.md), DiscoverResultsView(result: DiscoverResult(servers: r.servers, mode: r.mode))],
              ] else if (r != null) ...[
                const SizedBox(height: RasqSpacing.md),
                if (r.source == 'brave') Text('RASQ リストに無かったので、Web 検索から見つけた候補です', key: const ValueKey('discover.people.brave'), style: caption),
                for (final (i, p) in r.people.indexed) Padding(padding: const EdgeInsets.only(bottom: RasqSpacing.xs), child: _PersonCard(key: ValueKey('discover.person.$i'), person: p)),
                const SizedBox(height: RasqSpacing.xs),
                DiscoverResultsView(result: r),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({super.key, required this.person});
  final PersonHit person;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final caption = RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant);
    final p = person;
    return _card(context, key: ValueKey('discover.personCard.${p.address}'), children: [
      Row(children: [
        RasqAvatar(size: 28, fallbackLabel: p.name.isEmpty ? p.handle : p.name),
        const SizedBox(width: RasqSpacing.xs),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name.isEmpty ? p.address : p.name, style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
            if (p.address.isNotEmpty) Text(p.address, style: caption, maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
        if (p.profileUrl != null)
          IconButton(
            tooltip: 'プロフィールをブラウザで開く',
            icon: const Icon(Icons.open_in_new, size: 18),
            onPressed: () => launchUrl(p.profileUrl!, mode: LaunchMode.externalApplication),
          ),
      ]),
      if (p.snippet.isNotEmpty) Text(p.snippet, style: RasqTypography.bodySmall, maxLines: 3, overflow: TextOverflow.ellipsis),
      if (p.lists.isNotEmpty) ...[
        const SizedBox(height: RasqSpacing.xs),
        Text('この人が入っている RASQ リスト', style: caption),
        for (final l in p.lists) Padding(padding: const EdgeInsets.only(top: RasqSpacing.xs), child: ListHitCard(hit: l)),
      ],
    ]);
  }
}

// ---------------------------------------------------------------------------
// d. RAi に聞く(クラウドの RAi)

@immutable
class _AskTurn {
  const _AskTurn.user(this.text) : fromUser = true, result = null, failed = false;
  const _AskTurn.rai(AskDiscoverResult this.result) : fromUser = false, text = '', failed = false;
  const _AskTurn.failed() : fromUser = false, text = '', result = null, failed = true;
  final bool fromUser;
  final String text;
  final AskDiscoverResult? result;
  final bool failed;
  String get body => fromUser ? text : (result?.answer ?? '');
}

class DiscoverAskScreen extends ConsumerStatefulWidget {
  const DiscoverAskScreen({super.key});
  @override
  ConsumerState<DiscoverAskScreen> createState() => _DiscoverAskScreenState();
}

class _DiscoverAskScreenState extends ConsumerState<DiscoverAskScreen> {
  final _input = TextEditingController();
  final _turns = <_AskTurn>[];
  bool _busy = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    final api = ref.read(onboardingDiscoverApiProvider);
    if (text.isEmpty || _busy) return;
    setState(() {
      _turns.add(_AskTurn.user(text));
      _input.clear();
      _busy = true;
    });
    try {
      if (api == null) throw StateError('no central');
      final messages = [for (final t in _turns) if (!t.failed && t.body.isNotEmpty) DiscoverChatMessage(fromUser: t.fromUser, text: t.body)];
      final r = await api.ask(messages);
      if (mounted) setState(() => _turns.add(_AskTurn.rai(r)));
    } catch (e) {
      debugPrint('discover ask: $e');
      if (mounted) setState(() => _turns.add(const _AskTurn.failed()));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final caption = RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant);
    return Scaffold(
      appBar: const RasqPageHeader(title: 'RAi に聞く', showMore: false),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                child: ListView(key: const ValueKey('discover.ask.list'), padding: const EdgeInsets.all(RasqSpacing.page), children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const RaiIcon(size: 28),
                    const SizedBox(width: RasqSpacing.xs),
                    Expanded(child: Text('好きなこと・見たいもの・どんな人とつながりたいかを教えてください。合いそうな SNS のサーバーと RASQ リストを探します。', style: RasqTypography.bodySmall)),
                  ]),
                  const SizedBox(height: RasqSpacing.xs),
                  Text('会話は RASQ のサーバーの RAi(クラウド)に送ります。', style: caption),
                  for (final (i, t) in _turns.indexed) ...[
                    const SizedBox(height: RasqSpacing.sm),
                    if (t.fromUser)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          key: ValueKey('discover.ask.turn.$i'),
                          constraints: const BoxConstraints(maxWidth: 440),
                          padding: const EdgeInsets.all(RasqSpacing.sm),
                          decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(RasqSizes.radiusMd)),
                          child: Text(t.text, style: RasqTypography.bodySmall),
                        ),
                      )
                    else
                      Container(
                        key: ValueKey('discover.ask.turn.$i'),
                        padding: const EdgeInsets.all(RasqSpacing.sm),
                        decoration: BoxDecoration(border: Border.all(color: scheme.outlineVariant), borderRadius: BorderRadius.circular(RasqSizes.radiusMd)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Row(children: [const RaiIcon(size: 20), const SizedBox(width: RasqSpacing.xs), Text('RAi', style: caption)]),
                          const SizedBox(height: RasqSpacing.xs),
                          if (t.failed)
                            Text('うまく答えられませんでした。時間をおいて、もう一度聞いてください', style: RasqTypography.bodySmall.copyWith(color: scheme.error))
                          else ...[
                            Text(t.result!.answer, style: RasqTypography.bodySmall),
                            if (!t.result!.isEmpty) ...[const SizedBox(height: RasqSpacing.sm), DiscoverResultsView(result: t.result!)],
                          ],
                        ]),
                      ),
                  ],
                  if (_busy) const Padding(padding: EdgeInsets.all(RasqSpacing.md), child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, RasqSpacing.sm),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('discover.ask.input'),
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: discoverAskMaxChars,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(hintText: 'RAi に聞く', counterText: ''),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('discover.ask.send'),
                    tooltip: '送る',
                    icon: const Icon(Icons.send),
                    onPressed: _busy || _input.text.trim().isEmpty ? null : _send,
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
