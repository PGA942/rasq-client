import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../settings/settings_dsl.dart';
import 'astell_media_viewer.dart';
import 'astell_models.dart';
import 'astell_providers.dart';

/// AsTell の 3 つの FOW (D-139、ワイヤーフレーム p.3):
///
/// - [openAstellPreviewFow] 参加 FOW — タイトル / 共有・ブックマーク / 参加メンバー /
///   ざっくり要約 / ジャンル / 下段(マイク・字幕・**参加**・歯車)
/// - [openAstellRoomFow] ルーム FOW(参加後)— 共有欄 / 参加メンバー / 設定トグル /
///   ジャンル編集 / 文字起こしのティッカー + 入力 / 下段(マイク・画面・字幕・共有・歯車)、
///   ヘッダー右は **退出**
/// - [openAstellCreateFow] 作成 FOW — タイトル / フォロワーを招待 / ウェルカム
///   メッセージ / トグル 2 つ / 下段(**作成**)
///
/// 音声・映像(WebRTC)はまだ繋がない — マイク/画面のボタンは状態表示だけ。
const astellPreviewFowId = 'fow.astell.preview';
const astellRoomFowId = 'fow.astell.room';
const astellCreateFowId = 'fow.astell.create';

FowSpec _spec({required String title, String? cancelText, Widget? trailing, double height = 0.6}) => FowSpec(
      type: FowPanelType.widget,
      initialHeightFactor: height,
      minHeightFactor: 0.35,
      maxHeightFactor: 0.92,
      title: title,
      cancelText: cancelText,
      headerTrailing: trailing,
      dockAboveFooter: true,
    );

Widget _label(BuildContext context, String text) => Padding(
      padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 2),
      child: Text(text, style: RasqTypography.caption.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );

/// 参加メンバー行: アバター(マイク/スピーカーのバッジ)+ 名前、3 人まで + 「他N人」。
/// 画面共有中のピアは**マイク表示の左に画面共有枠**(D-146)。タップで共有枠に表示。
class AstellMembersRow extends StatelessWidget {
  const AstellMembersRow({super.key, required this.peers, this.totalCount, this.viewingPeerId, this.onViewScreen});
  final List<AstellPeer> peers;
  final int? totalCount;
  final String? viewingPeerId;
  final void Function(String peerId)? onViewScreen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shown = peers.take(3).toList();
    final total = totalCount ?? peers.length;
    final rest = total - shown.length;
    if (peers.isEmpty) {
      return Padding(padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page), child: Text('まだ誰もいません', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.xs),
      child: Row(children: [
        for (final p in shown) ...[
          Column(mainAxisSize: MainAxisSize.min, children: [
            Stack(clipBehavior: Clip.none, children: [
              RasqAvatar(
                imageUrl: p.avatarUrl,
                size: RasqSizes.avatarXl,
                fallbackLabel: p.displayName,
                // マイク/スピーカーは背景色の縁取りつき円の内側に (D-142: 素のアイコンは見づらい)。
                badge: _StateBadge(icon: p.micOn ? Icons.mic : Icons.volume_up, color: p.micOn ? RasqColors.accent : RasqColors.sub),
              ),
              // 画面共有枠: マイク表示の左(左下)。タップで共有枠に表示(選択中は強調)。
              if (p.screenShare != null)
                Positioned(
                  left: -6,
                  bottom: -2,
                  child: _ScreenFrame(
                    share: p.screenShare!,
                    selected: viewingPeerId == p.peerId,
                    onTap: onViewScreen == null ? null : () => onViewScreen!(p.peerId),
                  ),
                ),
            ]),
            const SizedBox(height: 2),
            SizedBox(width: RasqSizes.avatarXl + 8, child: Text(p.displayName, style: RasqTypography.caption, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)),
          ]),
          const SizedBox(width: RasqSpacing.md),
        ],
        if (rest > 0) Text('他$rest人', style: RasqTypography.body),
      ]),
    );
  }
}

/// 参加者タイルの画面共有枠 (D-146): 小さなサムネイル + 枠線。選択中はリンク色。
class _ScreenFrame extends StatelessWidget {
  const _ScreenFrame({required this.share, required this.selected, this.onTap});
  final AstellScreenShare share;
  final bool selected;
  final VoidCallback? onTap;
  static const width = 34.0;
  static const height = 24.0;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Tooltip(
        message: selected ? '共有枠に表示中' : '画面共有を表示',
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border.all(color: selected ? RasqColors.link : scheme.surface, width: 2),
            borderRadius: BorderRadius.circular(4),
            boxShadow: const [BoxShadow(blurRadius: 2, color: Colors.black26)],
          ),
          clipBehavior: Clip.antiAlias,
          child: share.thumbnailUrl != null
              ? Image.network(share.thumbnailUrl.toString(), fit: BoxFit.cover, errorBuilder: (_, _, _) => Icon(Icons.desktop_windows, size: 14, color: scheme.onSurfaceVariant))
              : Icon(Icons.desktop_windows, size: 14, color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// アバター右下の状態バッジ: 色つきの円 + 背景色の縁取り、アイコンは白で内側に。
class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.icon, required this.color});
  final IconData icon;
  final Color color;
  static const size = 22.0;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: scheme.surface, width: 2)),
      child: Icon(icon, size: size * 0.55, color: Colors.white),
    );
  }
}

/// ジャンルのチップ列(先頭が選択色、横スクロール)。
class AstellGenreChips extends StatelessWidget {
  const AstellGenreChips({super.key, required this.genres});
  final List<String> genres;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (genres.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 32,
      child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page), children: [
        for (final (i, g) in genres.indexed)
          Padding(
            padding: const EdgeInsets.only(right: RasqSpacing.xs),
            child: RasqPill(label: g, dense: false, color: i == 0 ? RasqColors.lightBlue : scheme.surfaceContainerHighest, textColor: i == 0 ? RasqColors.navy : scheme.onSurface),
          ),
      ]),
    );
  }
}

/// 下段の丸ボタン(マイク / 字幕 / 画面 / 歯車)。
class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, this.onPressed, this.filled});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? filled;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: filled ?? Colors.transparent,
        shape: CircleBorder(side: filled == null ? BorderSide(color: scheme.onSurface, width: 1.5) : BorderSide.none),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 22, color: filled != null ? Colors.white : (onPressed == null ? scheme.onSurfaceVariant : scheme.onSurface))),
        ),
      ),
    );
  }
}

Future<void> _notYet(BuildContext context, String what) async {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$what は M5 後段(WebRTC 接続)で入ります')));
}

// ── 参加 FOW ──────────────────────────────────────────────────────

Future<void> openAstellPreviewFow(BuildContext context, WidgetRef ref, AstellRoom room) async {
  final manager = ref.read(overlayManagerProvider);
  await manager.showFow<void>(
    id: astellPreviewFowId,
    spec: _spec(
      title: room.title,
      cancelText: '閉じる',
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        RasqIconButton(icon: Icons.ios_share, size: 20, tooltip: '共有', onPressed: () {}),
        RasqIconButton(icon: Icons.bookmark, size: 20, tooltip: 'ブックマーク', onPressed: () {}),
      ]),
    ),
    barrierBehavior: OverlayBarrierBehavior.dismissDiscard,
    builder: (ctx, handle) => _PreviewBody(room: room, onJoin: () async {
      handle.close();
      await ref.read(astellSessionProvider.notifier).join(room);
      if (context.mounted) await openAstellRoomFow(context, ref);
    }),
  );
}

class _PreviewBody extends ConsumerWidget {
  const _PreviewBody({required this.room, required this.onJoin});
  final AstellRoom room;
  final Future<void> Function() onJoin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final peers = ref.watch(astellPeersProvider(room.id)).value ?? const <AstellPeer>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        child: ListView(padding: EdgeInsets.zero, children: [
          _label(context, '参加メンバー'),
          AstellMembersRow(peers: peers, totalCount: room.peerCount > peers.length ? room.peerCount : null),
          const Divider(height: RasqSpacing.md),
          _label(context, 'ざっくり要約'),
          Padding(
            padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, RasqSpacing.sm),
            child: Text(room.showSummary ? room.summaryText : 'このルームはざっくり要約を公開していません。', style: RasqTypography.body.copyWith(color: room.description.isEmpty ? scheme.onSurfaceVariant : null)),
          ),
          AstellGenreChips(genres: room.genres),
          if (room.welcomeMessage != null && room.welcomeMessage!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
              child: Text('ようこそ: ${room.welcomeMessage}', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
            ),
        ]),
      ),
      const Divider(height: 1),
      Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.sm, RasqSpacing.sm, RasqSpacing.sm, RasqSpacing.sm),
        child: Row(children: [
          _RoundButton(icon: Icons.mic_off, tooltip: 'マイク(参加後に切替)', onPressed: null),
          const SizedBox(width: RasqSpacing.sm),
          _RoundButton(icon: Icons.subtitles_outlined, tooltip: '字幕', filled: room.showSummary ? const Color(0xFF2EBF8F) : scheme.outline, onPressed: () {}),
          const SizedBox(width: RasqSpacing.sm),
          Expanded(child: RasqGradientButton(label: '参加', onPressed: onJoin)),
          const SizedBox(width: RasqSpacing.sm),
          _RoundButton(icon: Icons.settings, tooltip: '設定', onPressed: () => _notYet(context, 'VC の設定')),
        ]),
      ),
    ]);
  }
}

// ── ルーム FOW(参加後) ────────────────────────────────────────────

/// stick の 2 段 (D-142 / D-143): 最小 = コンパクトバーだけ / 展開。
const astellRoomCollapsedFactor = 0.13;
const astellRoomExpandedFactor = 0.75;

/// 展開レイアウトに要る最小高さ(ヘッダー + 共有 + タブ + 下段)。これより
/// 低い = **タブ選択欄が隠れる**タイミングで stick に変形する (D-143)。
const astellRoomTabsCoveredHeight = 300.0;

const astellRoomCompactKey = Key('astell.room.compact');
const astellStickPagerKey = Key('astell.room.stick.pager');
const astellFooterActionsKey = Key('astell.footer.actions');
const astellStickScreenKey = Key('astell.stick.screen');
const astellRoomHeaderKey = Key('astell.room.header');

Future<void> openAstellRoomFow(BuildContext context, WidgetRef ref) async {
  final manager = ref.read(overlayManagerProvider);
  final room = ref.read(astellSessionProvider)?.room;
  if (room == null) return;
  // ヘッダーは FOW のクロームではなく本体側で描く(stick 化で消すため)。
  final spec = FowSpec(
    type: FowPanelType.widget,
    initialHeightFactor: astellRoomExpandedFactor,
    minHeightFactor: 0.12,
    maxHeightFactor: 0.92,
    dockAboveFooter: true,
    heightStops: const [astellRoomCollapsedFactor, astellRoomExpandedFactor],
    freeAboveStops: true,
  );
  // 外側タップ → stick(閉じない)。stick 中はバリアを外して背面を触れるように。
  final barrierEnabled = ValueNotifier<bool>(true);
  void syncBarrier() {
    final expanded = spec.heightFactor.value >= (astellRoomCollapsedFactor + astellRoomExpandedFactor) / 2;
    if (barrierEnabled.value != expanded) {
      barrierEnabled.value = expanded;
      manager.requestRebuild();
    }
  }
  spec.heightFactor.addListener(syncBarrier);
  await manager.showFow<void>(
    id: astellRoomFowId,
    spec: spec,
    semanticsLabel: room.title,
    barrierBehavior: OverlayBarrierBehavior.dismiss,
    onBarrierTap: () {
      spec.userResized = false;
      spec.heightFactor.value = astellRoomCollapsedFactor;
    },
    barrierEnabled: barrierEnabled,
    builder: (ctx, handle) => AstellRoomBody(spec: spec),
  );
  spec.heightFactor.removeListener(syncBarrier);
  barrierEnabled.dispose();
}

class AstellRoomBody extends ConsumerStatefulWidget {
  const AstellRoomBody({super.key, this.spec});

  /// 高さ(stick の段)を読む/書くための FOW 仕様。null なら常に展開表示。
  final FowSpec? spec;
  @override
  ConsumerState<AstellRoomBody> createState() => _AstellRoomBodyState();
}

/// ルーム FOW のタブ (D-141): 共有欄の下に 4 つ。
enum AstellRoomTab {
  home('ホーム'),
  chat('チャット'),
  toc('目次'),
  room('ルーム');

  const AstellRoomTab(this.label);
  final String label;
}

/// チャット欄の 1 行: 文字起こし / 共有コンテンツ / 入力中の下書き。時刻順。
class _ChatEntry {
  const _ChatEntry({required this.at, required this.author, required this.text, this.kind, this.transcript = false, this.draft = false, this.id, this.pinned = false, this.handle});
  final DateTime at;
  final String author;

  /// 発言者のハンドル(「…」のミュート等で参加者に引き当てる)。下書きは null。
  final String? handle;
  final String text;
  final String? kind;
  final bool transcript;
  final bool draft;
  final String? id;
  final bool pinned;
}

/// 共有欄の 1 件: 共有(チャットのメッセージ)か文字起こし。
class _SharedItem {
  const _SharedItem({this.share, this.transcript});
  final AstellShare? share;
  final AstellTranscript? transcript;
  DateTime get at => share?.createdAt ?? transcript!.createdAt;
  String get id => share?.id ?? transcript!.id;
  bool get pinned => share?.pinned ?? transcript!.pinned;
}

const _kAnim = Duration(milliseconds: 220);

class _AstellRoomBodyState extends ConsumerState<AstellRoomBody> {
  bool _sharesExpanded = false;
  final _input = TextEditingController();
  final _footerKey = GlobalKey();

  /// FOW のクローム(ハンドル + 余白)ぶん。最小段 = バーの実測 + これ。
  static const _chromeHeight = 30.0;

  /// stick の最小段をバーの実測高さに合わせる(コンポーザー D-049 と同じ作法)。
  void _syncCollapsedStop(BuildContext context) {
    final spec = widget.spec;
    if (spec == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _footerKey.currentContext?.findRenderObject() as RenderBox?;
      final host = MediaQuery.sizeOf(context).height;
      if (box == null || !box.hasSize || host <= 0) return;
      final fit = ((box.size.height + _chromeHeight) / host).clamp(spec.minHeightFactor, astellRoomExpandedFactor - 0.05);
      final current = spec.heightStops.isEmpty ? astellRoomCollapsedFactor : spec.heightStops.first;
      if ((fit - current).abs() < 0.003) return;
      spec.heightStops = [fit, astellRoomExpandedFactor];
      if ((spec.heightFactor.value - current).abs() < 0.01) spec.heightFactor.value = fit;
    });
  }

  /// 入力開始時刻 (D-141): 下書き枠はこの時刻の位置に差し込まれ、送信で
  /// その時刻の発言になる。入力を全部消すと消える。
  DateTime? _draftStartedAt;

  @override
  void initState() {
    super.initState();
    _input.addListener(_onInputChanged);
  }

  void _onInputChanged() {
    final text = _input.text;
    setState(() {
      if (text.isEmpty) {
        _draftStartedAt = null;
      } else {
        _draftStartedAt ??= DateTime.now();
      }
    });
  }

  @override
  void dispose() {
    _input.removeListener(_onInputChanged);
    _input.dispose();
    super.dispose();
  }

  bool get _drafting => _draftStartedAt != null;

  void _expand() {
    final spec = widget.spec;
    if (spec == null) return;
    spec.heightFactor.value = astellRoomExpandedFactor;
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    if (spec == null) return _body(context, compact: false);
    // タブ選択欄が隠れる高さで変形 (D-143)。目標(heightFactor)と実際の制約の
    // どちらでも判定し、アニメーション中に詰め込まれてはみ出さないようにする。
    return ValueListenableBuilder<double>(
      valueListenable: spec.heightFactor,
      builder: (context, h, _) => LayoutBuilder(
        builder: (context, constraints) {
          final targetPx = h * MediaQuery.sizeOf(context).height;
          final compact = targetPx < astellRoomTabsCoveredHeight || constraints.maxHeight < astellRoomTabsCoveredHeight;
          if (!compact) return _body(context, compact: false);
          _syncCollapsedStop(context);
          // 変形中(高さが縮む途中)は下端に寄せてクリップし、はみ出させない。
          return ClipRect(
            child: OverflowBox(
              alignment: Alignment.bottomCenter,
              minHeight: 0,
              maxHeight: double.infinity,
              child: _body(context, compact: true),
            ),
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context, {required bool compact}) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = RasqTokens.of(context);
    final s = ref.watch(astellSessionProvider);
    if (s == null) return const RasqEmptyView(title: '退出しました');
    final session = ref.read(astellSessionProvider.notifier);
    final room = s.room;
    final me = ref.watch(rasqAccountProvider);
    // 役割 (D-149): welcome の accountId で判定(モックは 'me')。
    final isOwner = s.isOwner;

    Future<void> leave() async {
      await session.leave();
      ref.read(overlayManagerProvider).close(astellRoomFowId);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // ── ヘッダー(展開時のみ。stick で消える) ──
      AnimatedSize(
        duration: _kAnim,
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: compact
            ? const SizedBox(width: double.infinity)
            : Padding(
                key: astellRoomHeaderKey,
                padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.xs, 0),
                child: Row(children: [
                  Expanded(child: Text(room.title, style: RasqTypography.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  RasqIconButton(icon: Icons.ios_share, size: 20, tooltip: '共有', onPressed: () {}),
                  RasqIconButton(icon: Icons.bookmark, size: 20, tooltip: 'ブックマーク', onPressed: () {}),
                  TextButton(onPressed: leave, child: Text('退出', style: TextStyle(color: tokens.danger, fontWeight: FontWeight.w700))),
                ]),
              ),
      ),
      if (!compact) ...[
        if (s.error != null)
          Container(
            color: tokens.danger.withValues(alpha: 0.08),
            padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.xs),
            child: Text(s.error!, style: RasqTypography.caption.copyWith(color: tokens.danger)),
          )
        else if (!s.connected)
          Container(
            color: scheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.xs),
            child: Text('接続しています…', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          ),
        if (s.screenShareOn)
          Container(
            color: RasqColors.sub.withValues(alpha: 0.12),
            padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.xs),
            child: Row(children: [
              const Icon(Icons.desktop_windows, size: 16, color: RasqColors.sub),
              const SizedBox(width: RasqSpacing.xs),
              Expanded(child: Text('画面共有モード(映像の送出は M5 後段)', style: RasqTypography.caption.copyWith(color: RasqColors.sub))),
            ]),
          ),
        // ── 共有枠 (D-146): ピン留め/クリックしたピアの画面共有 ──
        if (s.viewingPeer != null)
          _ViewingScreenPanel(
            peer: s.viewingPeer!,
            muted: s.isMuted(s.viewingPeer!.peerId),
            onFullscreen: () => _openPeerScreen(context, s.viewingPeer!),
            onMore: (rect) => _peerMenu(context, s, s.viewingPeer!, rect, pinned: true),
          )
        // ── ホストの配信 (D-145): 動画/画面のプレビュー ──
        else if (room.hostStream != null)
          _HostStreamPanel(stream: room.hostStream!, onTap: () => _openStream(context, room)),
        // ── 共有 = チャットからピン留めしたもの + 自動表示の種類 (D-146) ──
        _SharesSection(
          items: _sharedItems(s),
          myHandle: me.account.handle,
          isOwner: isOwner,
          expanded: _sharesExpanded,
          onToggle: () => setState(() => _sharesExpanded = !_sharesExpanded),
          onOpen: (share) => _openShare(context, share),
          onUnpin: (item) => item.share != null ? session.pinShare(item.share!.id, false) : session.pinTranscript(item.transcript!.id, false),
          onMore: (share, rect) => _shareMenu(context, share, rect, isOwner: isOwner, mine: share.handle == me.account.handle || share.accountId == 'me'),
        ),
        const Divider(height: RasqSpacing.sm),
        // ── タブ (D-141) ──
        Expanded(
          child: DefaultTabController(
            length: AstellRoomTab.values.length,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              RasqTabs(items: [for (final t in AstellRoomTab.values) RasqTabItem(t.label)], mode: RasqTabsMode.fixed, showChevron: false),
              Expanded(
                child: TabBarView(children: [
                  _homeTab(context, s, isOwner),
                  _chatTab(context, s, me.account.handle),
                  _indexTab(context, s),
                  _roomTab(context, s),
                ]),
              ),
            ]),
          ),
        ),
        const Divider(height: 1),
      ],
      // ── 下段バー: 展開 ⇄ stick で変形 (D-143) ──
      _Footer(
        key: _footerKey,
        compact: compact,
        state: s,
        pinned: _sharedItems(s),
        input: _input,
        drafting: _drafting,
        onSpeaker: session.toggleSpeaker,
        onMic: session.toggleMic,
        onScreen: session.toggleScreenShare,
        onCaptions: session.toggleCaptions,
        onSendText: _sendText,
        onPickFile: _pickAndShare,
        onSettings: () => _openSettings(context, s, isOwner),
        onExpand: _expand,
        onLeave: leave,
        onOpenShare: (share) => _openShare(context, share),
        onFullscreen: s.viewingPeer == null ? null : () => _openPeerScreen(context, s.viewingPeer!),
      ),
    ]);
  }

  void _sendText() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    final isLink = text.startsWith('http://') || text.startsWith('https://');
    ref.read(astellSessionProvider.notifier).share(isLink ? 'link' : 'text', isLink ? {'url': text} : {'text': text});
    _input.clear(); // → リスナーが下書き枠を消す
  }

  /// 「共有する」= ファイル選択 → media として共有(D-142)。アップロード先
  /// (Central のアセット置き場)は未整備なので、今はファイル名とサイズだけを流す。
  Future<void> _pickAndShare() async {
    final pick = ref.read(astellMediaPickerProvider);
    try {
      final file = await pick();
      if (file == null) return;
      final size = await file.length();
      // XFile.fromData は name が空になる実装がある → path の末尾 → 既定名。
      final name = file.name.isNotEmpty ? file.name : (file.path.isNotEmpty ? file.path.split('/').last : 'ファイル');
      final mime = file.mimeType ?? _guessMime(name);
      // Central へアップロード (D-145: zstd 圧縮 — コーデックが無ければ無圧縮)して URL を共有に載せる。
      final s = ref.read(astellSessionProvider);
      if (s == null) return;
      final codec = ref.read(astellAssetCodecProvider);
      final asset = await ref.read(astellClientProvider).uploadAsset(s.room.id, codec.encode(await file.readAsBytes()), name: name, contentType: mime, encoding: codec.encoding);
      ref.read(astellSessionProvider.notifier).share('media', {
        'name': name,
        'title': name,
        'mimeType': mime,
        'sizeBytes': size,
        'assetId': asset.id,
        'url': asset.url.toString(),
        if (mime.startsWith('image/')) 'thumbnailUrl': asset.url.toString(),
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ファイルを選択できませんでした: $e')));
    }
  }

  /// 共有欄に出すもの (D-146): ピン留め(共有・文字起こし)+ 自動表示の種類に該当する共有。
  List<_SharedItem> _sharedItems(AstellSessionState s) {
    final auto = ref.watch(astellAutoShareProvider);
    final items = <_SharedItem>[
      for (final sh in s.shares)
        if (sh.pinned || (auto[sh.mediaClass] ?? false)) _SharedItem(share: sh),
      for (final t in s.transcripts)
        if (t.pinned || (auto['transcript'] ?? false)) _SharedItem(transcript: t),
    ]..sort((a, b) => a.at.compareTo(b.at));
    return items;
  }

  /// ピアの画面共有を全画面(映像は M5 後段、今はサムネイル)。
  Future<void> _openPeerScreen(BuildContext context, AstellPeer peer) {
    final sc = peer.screenShare!;
    return AstellMediaViewer.open(
      context,
      AstellShare(id: 'screen-${peer.peerId}', accountId: peer.accountId, handle: peer.handle, displayName: peer.displayName, kind: 'media',
          payload: {'title': sc.title.isEmpty ? '${peer.displayName} の画面' : sc.title, 'mimeType': 'video/screen', 'thumbnailUrl': sc.thumbnailUrl?.toString()}, createdAt: DateTime.now()),
    );
  }

  /// 歯車 (D-146): 共有欄の自動表示(メディアタイプ別)と読み上げ音声。
  Future<void> _openSettings(BuildContext context, AstellSessionState s, bool isOwner) async {
    final manager = ref.read(overlayManagerProvider);
    final voices = await ref.read(astellClientProvider).ttsVoices();
    if (!context.mounted) return;
    await manager.showBottomSheet<void>(
      id: 'astell.room.settings',
      title: 'VC の設定',
      builder: (ctx) => Consumer(builder: (ctx, ref, _) {
        final auto = ref.watch(astellAutoShareProvider);
        final room = ref.watch(astellSessionProvider)?.room ?? s.room;
        final scheme = Theme.of(ctx).colorScheme;
        return ListView(shrinkWrap: true, children: [
          _label(ctx, 'チャットの内容を自動で共有欄に出す(ピン留めしなくても)'),
          for (final c in astellShareClasses)
            RasqSwitchListTile(
              title: c.label,
              value: auto[c.id] ?? false,
              onChanged: (v) => ref.read(settingsAreaProvider(astellSettingsArea).notifier).set('auto.${c.id}', v),
            ),
          if (isOwner) ...[
            const Divider(height: RasqSpacing.md),
            _label(ctx, 'モデレーション(オーナー)'),
            _label(ctx, '参加できる人'),
            for (final p in astellJoinPolicies)
              RasqRadioListTile<String>(title: p.label, subtitle: p.hint, value: p.id, groupValue: room.joinPolicy, onChanged: (_) => _patch({'joinPolicy': p.id})),
            _label(ctx, '共有(チャットへの投稿)できる人'),
            for (final p in astellSharePolicies) RasqRadioListTile<String>(title: p.label, value: p.id, groupValue: room.sharePolicy, onChanged: (_) => _patch({'sharePolicy': p.id})),
            _label(ctx, 'モデレーター(${room.moderators.length})— 付与はメンバー行の「…」から'),
            for (final m in room.moderators)
              RasqListTile(
                title: s.peers.where((p) => p.accountId == m).firstOrNull?.displayName ?? m,
                subtitle: s.peers.where((p) => p.accountId == m).firstOrNull?.handle.let((h) => '@$h'),
                chevron: false,
                trailing: RasqIconButton(icon: Icons.person_remove_outlined, size: 20, tooltip: 'モデレーターを外す', onPressed: () => _guard(ctx, () => ref.read(astellSessionProvider.notifier).setModerator(m, false))),
              ),
            _BanList(roomId: room.id),
            _label(ctx, '発信傾向'),
            RasqSwitchListTile(title: '発信傾向で入室を絞る(ダミー判定)', value: room.tendencyFilter, onChanged: (v) => _patch({'tendencyFilter': v})),
            Padding(
              padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.xs),
              child: Text('本命は rasq-judge の GoEmotion(発信の感情傾向)で、学習が要るので今はサーバーのダミー判定(表示名に hostile / 荒らし を含む人だけ敵対的)。オンにすると敵対的と判定された人は入室できません。メンバー行の「…」から判定結果を見られます。', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
            ),
          ],
          const Divider(height: RasqSpacing.md),
          _label(ctx, '自動再生'),
          RasqSwitchListTile(
            title: '画面共有が始まったら共有枠に出す',
            value: ref.watch(astellAutoPlayProvider),
            onChanged: (v) => ref.read(settingsAreaProvider(astellSettingsArea).notifier).set('autoplay.screen', v),
          ),
          const Divider(height: RasqSpacing.md),
          _label(ctx, '読み上げ(${voices.model}、プリセット音声)${voices.enabled ? '' : ' — サーバー未設定'}'),
          RasqRadioListTile<String?>(title: '読み上げなし', value: null, groupValue: room.ttsVoice, onChanged: isOwner ? (_) => _patch({'ttsVoice': null}) : null),
          for (final v in voices.voices) RasqRadioListTile<String?>(title: v.label, value: v.id, groupValue: room.ttsVoice, onChanged: isOwner ? (_) => _patch({'ttsVoice': v.id}) : null),
          Padding(
            padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, RasqSpacing.page),
            child: Text(isOwner ? 'チャットと共有の読み上げは Central 側で合成します(端末での再生は M5 後段)。' : '読み上げ音声はホストが選びます。', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          ),
        ]);
      }),
    );
  }

  /// ホストの配信をタップ → 全画面(再生は M5 後段、今は静止画)。
  Future<void> _openStream(BuildContext context, AstellRoom room) {
    final st = room.hostStream!;
    final share = AstellShare(
      id: 'stream',
      accountId: room.ownerId,
      handle: room.ownerHandle,
      displayName: room.ownerDisplayName,
      kind: 'media',
      payload: {'title': st.title.isEmpty ? '${room.ownerDisplayName} の配信' : st.title, 'mimeType': st.isScreen ? 'video/screen' : 'video/stream', 'thumbnailUrl': st.thumbnailUrl?.toString()},
      createdAt: st.startedAt ?? room.createdAt,
    );
    return AstellMediaViewer.open(context, share);
  }

  /// タイルのタップ (D-145): メディア = 全画面 / 投稿 = 対応 SNS プラグインがあればアプリ内、
  /// 無ければ Web / リンク = Web。
  Future<void> _openShare(BuildContext context, AstellShare share) async {
    switch (share.kind) {
      case 'media':
        await AstellMediaViewer.open(context, share);
      case 'post':
        final sessions = ref.read(sessionsProvider).value?.sessions ?? const [];
        final current = ref.read(currentAccountProvider);
        final matches = share.snsKind != null && share.postId != null && current != null && current.kind.name == share.snsKind && (share.instance == null || current.instance == share.instance);
        if (matches && sessions.isNotEmpty) {
          context.push('/post/${Uri.encodeComponent(share.postId!)}');
        } else if (share.url != null) {
          await launchUrl(share.url!, mode: LaunchMode.externalApplication); // Web 表示(アプリ内 WebView は未導入)
        } else {
          _notYet(context, 'この投稿の表示(対応 SNS プラグインが未導入)');
        }
      case 'link':
        if (share.url != null) await launchUrl(share.url!, mode: LaunchMode.externalApplication);
      default:
        break;
    }
  }

  Future<void> _shareMenu(BuildContext context, AstellShare share, Rect anchor, {required bool isOwner, required bool mine}) async {
    final manager = ref.read(overlayManagerProvider);
    final url = share.payload['url'] as String?;
    final pick = await manager.showDropdown<String>(id: 'astell.share.more', anchor: anchor, dense: true, items: [
      RasqDropdownItem('開く', 'open', enabled: url != null),
      const RasqDropdownItem('リンクをコピー', 'copy'),
      RasqDropdownItem('削除', 'delete', destructive: true, enabled: mine || isOwner),
      RasqDropdownItem('報告', 'report', destructive: true, enabled: !mine),
    ]);
    if (!context.mounted) return;
    switch (pick) {
      case 'open':
        if (url != null) await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      case 'copy':
        await Clipboard.setData(ClipboardData(text: url ?? share.headline));
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('コピーしました')));
      case 'delete':
        await ref.read(astellSessionProvider.notifier).removeShare(share.id);
      case 'report':
        await showAstellReportSheet(context, ref, shareId: share.id, roomId: ref.read(astellSessionProvider)?.room.id, targetAccountId: share.accountId == 'me' ? null : share.accountId, what: '共有「${share.headline}」');
      default:
        break;
    }
  }

  /// ピアの「…」(D-147、ワイヤーフレーム右下): 共有枠のピン留め/解除 / 全画面 /
  /// ミュート / フォロー / ブロック / 通報。ミュートは手元だけ(音声は M5 後段)。
  Future<void> _peerMenu(BuildContext context, AstellSessionState s, AstellPeer peer, Rect anchor, {required bool pinned}) async {
    final manager = ref.read(overlayManagerProvider);
    final session = ref.read(astellSessionProvider.notifier);
    final muted = s.isMuted(peer.peerId);
    final following = ref.read(astellFollowingProvider).value?.contains(peer.accountId) ?? false;
    final blocked = ref.read(astellBlocksProvider).value?.contains(peer.accountId) ?? false;
    final isOwnerPeer = peer.accountId == s.room.ownerId;
    final isModPeer = s.room.moderators.contains(peer.accountId);
    // モデレーション (D-149): キック / 全員向けミュートはモデレーター(オーナーには効かない、
    // モデレーター同士はオーナーだけ)。付与 / BAN はオーナー。
    final canModerate = s.isModerator && !isOwnerPeer && (!isModPeer || s.isOwner);
    final pick = await manager.showDropdown<String>(id: 'astell.peer.more', anchor: anchor, dense: true, items: [
      if (peer.screenShare != null) RasqDropdownItem(pinned ? 'ピン留めを外す' : '共有枠に表示', 'pin', accent: !pinned),
      if (peer.screenShare != null) const RasqDropdownItem('全画面', 'fullscreen'),
      RasqDropdownItem(following ? 'フォロー解除' : 'フォロー', 'follow'),
      RasqDropdownItem(muted ? 'ミュート解除' : 'ミュート', 'mute', accent: true),
      if (canModerate) RasqDropdownItem(peer.mutedByMod ? '全員向けミュートを解除' : '全員向けにミュート', 'modmute', accent: true),
      if (canModerate) const RasqDropdownItem('キック', 'kick', destructive: true),
      if (s.isOwner && !isOwnerPeer) RasqDropdownItem(isModPeer ? 'モデレーターを外す' : 'モデレーターにする', 'moderator'),
      if (s.isOwner && !isOwnerPeer) const RasqDropdownItem('BAN', 'ban', destructive: true),
      if (s.isModerator) const RasqDropdownItem('発信傾向を見る(ダミー判定)', 'tendency'),
      RasqDropdownItem(blocked ? 'ブロック解除' : 'ブロック', 'block', destructive: !blocked),
      const RasqDropdownItem('通報', 'report', destructive: true),
    ]);
    if (!context.mounted) return;
    switch (pick) {
      case 'pin':
        session.viewScreen(pinned ? null : peer.peerId);
      case 'fullscreen':
        await _openPeerScreen(context, peer);
      case 'mute':
        session.toggleMute(peer.peerId);
      case 'modmute':
        await _guard(context, () => session.mutePeer(peer.peerId, !peer.mutedByMod));
      case 'kick':
        await _guard(context, () => session.kick(peer.peerId));
      case 'moderator':
        await _guard(context, () => session.setModerator(peer.accountId, !isModPeer));
      case 'ban':
        await _guard(context, () => session.ban(peer.accountId));
      case 'follow':
        await _guard(context, () => session.follow(peer.accountId, !following));
      case 'tendency':
        await _guard(context, () async {
          final t = await ref.read(astellClientProvider).tendency(peer.accountId);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${peer.displayName} の発信傾向(${t.source}): ${t.summary}${t.hostile ? ' — 敵対的' : ''}')));
          }
        });
      case 'block':
        await _guard(context, () => session.block(peer.accountId, !blocked));
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(blocked ? '${peer.displayName} のブロックを解除しました' : '${peer.displayName} をブロックしました(発言を隠し、あなたのルームには入れません)')));
      case 'report':
        await showAstellReportSheet(context, ref, targetAccountId: peer.accountId, roomId: s.room.id, what: peer.displayName);
      default:
        break;
    }
  }

  /// サーバーの 403 などを SnackBar に流す。
  Future<void> _guard(BuildContext context, Future<void> Function() run) async {
    try {
      await run();
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('できませんでした: $e')));
    }
  }

  /// チャット行の「…」(D-147、ワイヤーフレーム左下): 共有欄にピン留め / フォロー /
  /// ミュート / ブロック / 通報。発言者はハンドルで参加者に引き当てる。
  Future<void> _chatMenu(BuildContext context, AstellSessionState s, _ChatEntry e, Rect anchor) async {
    final manager = ref.read(overlayManagerProvider);
    final session = ref.read(astellSessionProvider.notifier);
    final peer = e.handle == null ? null : s.peers.where((p) => p.handle == e.handle && p.peerId != s.myPeerId).firstOrNull;
    final muted = peer != null && s.isMuted(peer.peerId);
    final following = peer != null && (ref.read(astellFollowingProvider).value?.contains(peer.accountId) ?? false);
    final blocked = peer != null && (ref.read(astellBlocksProvider).value?.contains(peer.accountId) ?? false);
    final canModerate = peer != null && s.isModerator && peer.accountId != s.room.ownerId && (!s.room.moderators.contains(peer.accountId) || s.isOwner);
    final pick = await manager.showDropdown<String>(id: 'astell.chat.more', anchor: anchor, dense: true, items: [
      if (e.id != null) RasqDropdownItem(e.pinned ? 'ピン留めを外す' : '共有欄にピン留め', 'pin', accent: !e.pinned, enabled: s.isModerator),
      RasqDropdownItem(following ? 'フォロー解除' : 'フォロー', 'follow', enabled: peer != null),
      RasqDropdownItem(muted ? 'ミュート解除' : 'ミュート', 'mute', accent: true, enabled: peer != null),
      if (canModerate) RasqDropdownItem(peer.mutedByMod ? '全員向けミュートを解除' : '全員向けにミュート', 'modmute', accent: true),
      if (canModerate) const RasqDropdownItem('キック', 'kick', destructive: true),
      if (peer != null && s.isOwner && peer.accountId != s.room.ownerId) const RasqDropdownItem('BAN', 'ban', destructive: true),
      RasqDropdownItem(blocked ? 'ブロック解除' : 'ブロック', 'block', destructive: !blocked, enabled: peer != null),
      RasqDropdownItem('通報', 'report', destructive: true, enabled: peer != null || e.id != null),
    ]);
    if (!context.mounted) return;
    switch (pick) {
      case 'pin':
        await _guard(context, () => e.transcript ? session.pinTranscript(e.id!, !e.pinned) : session.pinShare(e.id!, !e.pinned));
      case 'mute':
        if (peer != null) session.toggleMute(peer.peerId);
      case 'modmute':
        if (peer != null) await _guard(context, () => session.mutePeer(peer.peerId, !peer.mutedByMod));
      case 'kick':
        if (peer != null) await _guard(context, () => session.kick(peer.peerId));
      case 'ban':
        if (peer != null) await _guard(context, () => session.ban(peer.accountId));
      case 'follow':
        if (peer != null) await _guard(context, () => session.follow(peer.accountId, !following));
      case 'block':
        if (peer != null) await _guard(context, () => session.block(peer.accountId, !blocked));
      case 'report':
        await showAstellReportSheet(context, ref, targetAccountId: peer?.accountId, roomId: s.room.id, shareId: e.transcript ? null : e.id, what: '${e.author} の発言');
      default:
        break;
    }
  }

  // ── ホーム: 参加メンバー / トグル / ジャンル(ワイヤーフレームの中段) ──
  Widget _homeTab(BuildContext context, AstellSessionState s, bool isOwner) {
    final room = s.room;
    return ListView(padding: EdgeInsets.zero, children: [
      _label(context, '参加メンバー'),
      AstellMembersRow(peers: s.peers, viewingPeerId: s.viewingPeerId, onViewScreen: (id) => ref.read(astellSessionProvider.notifier).viewScreen(s.viewingPeerId == id ? null : id)),
      const Divider(height: RasqSpacing.md),
      RasqSwitchListTile(title: 'プレビューにざっくり要約を表示する', value: room.showSummary, enabled: isOwner, onChanged: isOwner ? (v) => _patch({'showSummary': v}) : null),
      RasqSwitchListTile(title: 'ジャンルを自動選択する', value: room.autoGenre, enabled: isOwner, onChanged: isOwner ? (v) => _patch({'autoGenre': v}) : null),
      _label(context, isOwner ? '自動選択されたジャンルを編集' : 'ジャンル'),
      AstellGenreChips(genres: room.genres),
      const SizedBox(height: RasqSpacing.xxl),
    ]);
  }

  // ── チャット: 文字起こしと共有コンテンツを時刻順に。入力中は下書き枠 (D-141)。 ──
  List<_ChatEntry> _chatEntries(AstellSessionState s, String myHandle) => <_ChatEntry>[
        for (final t in s.transcripts) _ChatEntry(at: t.createdAt, author: t.displayName, text: t.text, transcript: true, id: t.id, pinned: t.pinned, handle: t.handle),
        for (final sh in s.shares) _ChatEntry(at: sh.createdAt, author: sh.handle == myHandle || sh.accountId == 'me' ? 'あなた' : sh.displayName, text: sh.headline, kind: sh.kind, id: sh.id, pinned: sh.pinned, handle: sh.handle),
        if (_draftStartedAt != null) _ChatEntry(at: _draftStartedAt!, author: 'あなた', text: _input.text, draft: true),
      ]..sort((a, b) => a.at.compareTo(b.at));

  Widget _chatTab(BuildContext context, AstellSessionState s, String myHandle) {
    final scheme = Theme.of(context).colorScheme;
    // ブロックした人の発言は隠す (D-150)。
    final blocks = ref.watch(astellBlocksProvider).value ?? const <String>{};
    final blockedHandles = {for (final p in s.peers) if (blocks.contains(p.accountId)) p.handle};
    final all = _chatEntries(s, myHandle);
    final entries = [for (final e in all) if (e.handle == null || !blockedHandles.contains(e.handle)) e];
    final hidden = all.length - entries.length;
    if (entries.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(RasqSpacing.page), child: Text('発話の文字起こしと、下の入力から送ったメッセージ・共有コンテンツがここに時刻順で並びます。', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant), textAlign: TextAlign.center)));
    }
    return ListView(padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.xs), children: [
      if (hidden > 0) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text('ブロック中のユーザーの発言 $hidden 件を隠しています', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant))),
      for (final e in entries)
        Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.sm, vertical: RasqSpacing.xs),
          decoration: e.draft
              ? BoxDecoration(border: Border.all(color: scheme.outline), borderRadius: BorderRadius.circular(RasqSizes.radiusSm))
              : (e.transcript ? null : BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(RasqSizes.radiusSm))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 40, child: Text(_hhmm(e.at), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant))),
            if (e.kind != null && e.kind != 'text') Padding(padding: const EdgeInsets.only(right: RasqSpacing.xs), child: RasqPill(label: e.kind!)),
            Expanded(
              child: Text.rich(TextSpan(children: [
                TextSpan(text: '${e.author}> ', style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700, color: e.transcript ? scheme.onSurfaceVariant : null)),
                TextSpan(text: e.draft && e.text.isEmpty ? '入力中…' : e.text, style: RasqTypography.bodySmall.copyWith(color: e.draft ? scheme.onSurfaceVariant : null, fontStyle: e.draft ? FontStyle.italic : null)),
              ])),
            ),
            if (e.draft) Text('下書き', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
            // ピン留め (D-146): 共有欄へ出す/外す。モデレーターだけ (D-149)。
            if (e.id != null && s.isModerator)
              RasqIconButton(
                icon: e.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                size: 16,
                color: e.pinned ? RasqColors.link : scheme.onSurfaceVariant,
                tooltip: e.pinned ? 'ピン留めを外す' : '共有欄にピン留め',
                onPressed: () => e.transcript ? ref.read(astellSessionProvider.notifier).pinTranscript(e.id!, !e.pinned) : ref.read(astellSessionProvider.notifier).pinShare(e.id!, !e.pinned),
              ),
            // 「…」(D-147): フォロー / ミュート / ブロック / 通報。
            if (!e.draft)
              Builder(builder: (ctx) => RasqIconButton(
                icon: Icons.more_horiz,
                size: 16,
                color: scheme.onSurfaceVariant,
                tooltip: 'チャットの操作',
                onPressed: () {
                  final box = ctx.findRenderObject() as RenderBox;
                  _chatMenu(context, s, e, box.localToGlobal(Offset.zero) & box.size);
                },
              )),
          ]),
        ),
      const SizedBox(height: RasqSpacing.xxl),
    ]);
  }

  // ── 目次: 共有と文字起こしの区切り(時刻)を並べる。要約からの見出しは M5 後段。 ──
  Widget _indexTab(BuildContext context, AstellSessionState s) {
    final scheme = Theme.of(context).colorScheme;
    final items = <(DateTime, String, IconData)>[
      (s.room.createdAt, '開始: ${s.room.title}', Icons.flag_outlined),
      for (final sh in s.shares) (sh.createdAt, '${sh.displayName} が ${sh.kind} を共有: ${sh.headline}', Icons.upload_outlined),
      for (final (i, t) in s.transcripts.indexed)
        if (i % 10 == 0) (t.createdAt, t.text, Icons.subtitles_outlined),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    return ListView(padding: EdgeInsets.zero, children: [
      Padding(padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0), child: Text('共有と文字起こしの区切り。ざっくり要約からの見出しは M5 後段で入ります。', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant))),
      for (final it in items)
        RasqListTile(
          title: it.$2,
          subtitle: _hhmm(it.$1),
          leading: Icon(it.$3, size: 18),
          chevron: false,
          onTap: () => DefaultTabController.of(context).animateTo(AstellRoomTab.chat.index),
        ),
      const SizedBox(height: RasqSpacing.xxl),
    ]);
  }

  // ── ルーム: 参加メンバー全員(とカスタムプラグイン) ──
  Widget _roomTab(BuildContext context, AstellSessionState s) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(padding: EdgeInsets.zero, children: [
      _label(context, '参加メンバー(${s.peers.length})'),
      // ワイヤーフレーム右下 (D-147): アバター(マイク)+ 名前/@handle + 画面共有枠 +
      // スピーカー(ミュート切替)+ 「…」。
      for (final p in s.peers)
        _MemberRow(
          peer: p,
          self: p.peerId == s.myPeerId,
          role: p.accountId == s.room.ownerId ? 'ホスト' : (s.room.moderators.contains(p.accountId) ? 'モデレーター' : null),
          muted: s.isMuted(p.peerId),
          viewing: s.viewingPeerId == p.peerId,
          onViewScreen: () => ref.read(astellSessionProvider.notifier).viewScreen(s.viewingPeerId == p.peerId ? null : p.peerId),
          onMute: () => ref.read(astellSessionProvider.notifier).toggleMute(p.peerId),
          onMore: (rect) => _peerMenu(context, s, p, rect, pinned: s.viewingPeerId == p.peerId),
        ),
      if (s.peers.isEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page), child: Text('まだ誰もいません', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant))),
      const Divider(height: RasqSpacing.md),
      _label(context, 'カスタムプラグイン'),
      Padding(padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page), child: Text('このルームで動くプラグインはまだありません(カスタムプラグインホストは M5 後段)。', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant))),
      const SizedBox(height: RasqSpacing.xxl),
    ]);
  }

  Future<void> _patch(Map<String, Object?> patch) async {
    final s = ref.read(astellSessionProvider);
    if (s == null) return;
    try {
      final updated = await ref.read(astellClientProvider).updateRoom(s.room.id, patch);
      ref.read(astellSessionProvider.notifier).applyRoom(updated);
      ref.invalidate(astellHomeProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('設定を更新できませんでした: $e')));
    }
  }
}

/// 下段バー (D-148、ユーザー指定の構造):
/// `[左端ボタン群] [字幕] [中央] [共有する/送信完了する] [設定]`
/// - 左端: スピーカーミュート / マイクミュート / 画面共有 / (全画面: 共有枠にピアの画面がある時) /
///   (プラグインアクション: 今は無効)。横向き ListView で、**画面幅が狭い or stick は 2 つまで**表示。
/// - stick で共有枠にピアの画面がある時は、左端(字幕ボタン以外)が**映像そのもの**に置き換わり、
///   タップでそのまま全画面。
/// - 字幕: 有効時は右側(中央)に字幕、無効時は「共有する」(stick では画面共有以外のピン留めのタイル)。
/// - 右端: 共有する(入力中は 送信完了する)+ 設定。stick では 設定 → 退出、共有するは消える。
class _Footer extends StatelessWidget {
  const _Footer({
    super.key,
    required this.compact,
    required this.state,
    required this.pinned,
    required this.input,
    required this.drafting,
    required this.onSpeaker,
    required this.onMic,
    required this.onScreen,
    required this.onCaptions,
    required this.onSendText,
    required this.onPickFile,
    required this.onSettings,
    required this.onExpand,
    required this.onLeave,
    required this.onOpenShare,
    this.onFullscreen,
  });
  final bool compact;
  final AstellSessionState state;

  /// 共有欄の中身(ピン留め + 自動表示)。stick の中央(字幕オフ)に出す。
  final List<_SharedItem> pinned;
  final TextEditingController input;
  final bool drafting;
  final VoidCallback onSpeaker, onMic, onScreen, onCaptions, onSendText, onPickFile, onSettings, onExpand, onLeave;

  /// 共有枠のピアの画面を全画面に(共有枠が空なら null)。
  final VoidCallback? onFullscreen;
  final void Function(AstellShare share) onOpenShare;

  /// 左端ボタン群を 2 つに絞る画面幅。
  static const narrowWidth = 600.0;
  static const _button = 44.0;
  static const _gap = RasqSpacing.xs;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = state;
    final viewing = s.viewingPeer;
    final narrow = compact || MediaQuery.sizeOf(context).width < narrowWidth;

    // ── 左端 ──
    final actions = <Widget>[
      _RoundButton(icon: s.speakerMuted ? Icons.volume_off : Icons.volume_up, tooltip: s.speakerMuted ? 'スピーカーミュート解除' : 'スピーカーミュート', filled: s.speakerMuted ? RasqColors.danger : null, onPressed: onSpeaker),
      s.forceMuted
          ? const _RoundButton(icon: Icons.mic_off, tooltip: 'モデレーターにミュートされています', filled: RasqColors.danger, onPressed: null)
          : _RoundButton(icon: s.micOn ? Icons.mic : Icons.mic_off, tooltip: s.micOn ? 'マイクオフ' : 'マイクオン(音声は M5 後段)', filled: s.micOn ? RasqColors.accent : null, onPressed: onMic),
      _RoundButton(icon: s.screenShareOn ? Icons.desktop_windows : Icons.desktop_access_disabled_outlined, tooltip: s.screenShareOn ? '画面共有オフ' : '画面共有', filled: s.screenShareOn ? RasqColors.sub : null, onPressed: onScreen),
      if (viewing != null) _RoundButton(icon: Icons.fullscreen, tooltip: '全画面', onPressed: onFullscreen),
      const _RoundButton(icon: Icons.extension_outlined, tooltip: 'プラグインアクション(未対応)', onPressed: null),
    ];
    final Widget left;
    if (compact && viewing != null) {
      // stick + 共有枠にピアの画面: ボタン群の代わりに映像。タップで全画面。
      left = _StickScreen(key: astellStickScreenKey, peer: viewing, muted: s.isMuted(viewing.peerId) || s.speakerMuted, onTap: onFullscreen);
    } else {
      final visible = narrow ? 2 : actions.length;
      left = SizedBox(
        width: visible * _button + (visible - 1) * _gap,
        height: _button,
        child: ListView.separated(
          key: astellFooterActionsKey,
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.zero,
          physics: const ClampingScrollPhysics(),
          itemCount: actions.length,
          separatorBuilder: (_, _) => const SizedBox(width: _gap),
          itemBuilder: (_, i) => actions[i],
        ),
      );
    }

    // ── 中央 ──
    final Widget middle;
    if (compact) {
      middle = GestureDetector(
        key: astellRoomCompactKey,
        behavior: HitTestBehavior.opaque,
        onTap: onExpand,
        // 字幕オン: 文字起こし(3 行)。オフ: 画面共有以外のピン留めを上下スワイプで。
        child: s.captionsOn ? Align(alignment: Alignment.centerLeft, child: _Ticker(state: s, compact: true, lines: 3)) : _StickPager(state: s, items: pinned, onOpenShare: onOpenShare),
      );
    } else if (s.captionsOn) {
      middle = Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        _Ticker(state: s),
        RasqInput(controller: input, hintText: 'input..', onSubmitted: (_) => onSendText()),
      ]);
    } else {
      middle = OutlinedButton.icon(
        onPressed: onPickFile,
        icon: const Icon(Icons.upload, size: 18),
        label: const Text('共有する'),
        style: OutlinedButton.styleFrom(shape: const StadiumBorder(), minimumSize: const Size.fromHeight(40)),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(RasqSpacing.sm, compact ? 2 : RasqSpacing.xs, RasqSpacing.sm, compact ? RasqSpacing.xs : RasqSpacing.sm),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        left,
        const SizedBox(width: _gap),
        _RoundButton(icon: Icons.subtitles_outlined, tooltip: s.captionsOn ? '字幕オフ' : '字幕オン', filled: s.captionsOn ? const Color(0xFF2EBF8F) : null, onPressed: onCaptions),
        const SizedBox(width: RasqSpacing.sm),
        Expanded(child: middle),
        const SizedBox(width: RasqSpacing.sm),
        // ── 右端 ──
        if (compact)
          _RoundButton(icon: Icons.close, tooltip: '退出', onPressed: onLeave)
        else ...[
          _RoundButton(icon: drafting ? Icons.send : Icons.upload, tooltip: drafting ? '送信完了する' : '共有する', filled: scheme.onSurface, onPressed: drafting ? onSendText : onPickFile),
          const SizedBox(width: _gap),
          _RoundButton(icon: Icons.settings, tooltip: '設定', onPressed: onSettings),
        ],
      ]),
    );
  }
}

/// stick の左端 (D-148): 共有枠にあるピアの画面の映像(今はサムネイル)。タップで全画面。
class _StickScreen extends StatelessWidget {
  const _StickScreen({super.key, required this.peer, required this.muted, this.onTap});
  final AstellPeer peer;
  final bool muted;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sc = peer.screenShare!;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Tooltip(
        message: '${peer.displayName} の画面(タップで全画面)',
        child: Container(
          width: 92,
          height: 44,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: RasqColors.link, width: 1.5), color: scheme.surfaceContainerHighest),
          clipBehavior: Clip.antiAlias,
          child: Stack(fit: StackFit.expand, children: [
            if (sc.thumbnailUrl != null)
              Image.network(sc.thumbnailUrl.toString(), fit: BoxFit.cover, errorBuilder: (_, _, _) => Icon(Icons.desktop_windows, size: 18, color: scheme.onSurfaceVariant))
            else
              Icon(Icons.desktop_windows, size: 18, color: scheme.onSurfaceVariant),
            if (muted) const Positioned(right: 2, bottom: 2, child: Icon(Icons.volume_off, size: 12, color: Colors.white, shadows: [Shadow(blurRadius: 3, color: Colors.black)])),
          ]),
        ),
      ),
    );
  }
}

String _hhmm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// stick の中央(字幕オフ、D-144/D-148): ホストの配信の印と、**画面共有以外のピン留め**
/// (共有欄の中身)のタイルを縦の PageView で。上下スライドで前後へ(新しい順)。
class _StickPager extends StatelessWidget {
  const _StickPager({required this.state, required this.items, required this.onOpenShare});
  final AstellSessionState state;
  final List<_SharedItem> items;
  final void Function(AstellShare share) onOpenShare;

  @override
  Widget build(BuildContext context) {
    final host = state.room.hostStream;
    final scheme = Theme.of(context).colorScheme;
    final pages = <Widget>[
      if (host != null) _HostStreamTile(stream: host, room: state.room),
      // メディア / 投稿 / リンクはタップで開く (D-145)。テキストと文字起こしはバーのタップ = 展開に任せる。
      for (final it in items.reversed)
        if (it.share case final sh?)
          (sh.kind == 'text' ? _ShareTile(share: sh) : GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => onOpenShare(sh), child: _ShareTile(share: sh)))
        else
          _ShareTile(share: _transcriptAsShare(it.transcript!)),
      if (host == null && items.isEmpty)
        Align(alignment: Alignment.centerLeft, child: Text('ピン留めした共有がここに出ます', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant))),
    ];
    return SizedBox(
      height: 56,
      child: PageView(
        key: astellStickPagerKey,
        scrollDirection: Axis.vertical,
        children: pages,
      ),
    );
  }

  /// 文字起こしをテキストのタイルとして出すための詰め替え。
  static AstellShare _transcriptAsShare(AstellTranscript t) => AstellShare(id: t.id, accountId: t.accountId, handle: t.handle, displayName: t.displayName, kind: 'text', payload: {'text': t.text}, pinned: t.pinned, createdAt: t.createdAt);
}

/// 共有コンテンツのタイル (D-144、ワイヤーフレーム右): アバター + 作者名 + 種別ピル /
/// 本文。メディアはサムネイル(動画は ▶)。
class _ShareTile extends StatelessWidget {
  const _ShareTile({required this.share});
  final AstellShare share;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final thumb = share.thumbnailUrl;
    return Container(
      decoration: BoxDecoration(border: Border.all(color: scheme.onSurface, width: 1.2), borderRadius: BorderRadius.circular(RasqSizes.radiusSm)),
      padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.sm, vertical: 2),
      clipBehavior: Clip.hardEdge,
      child: Row(children: [
        if (thumb != null)
          Padding(
            padding: const EdgeInsets.only(right: RasqSpacing.sm),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 56,
                height: 40,
                child: Stack(fit: StackFit.expand, children: [
                  Image.network(thumb.toString(), fit: BoxFit.cover, errorBuilder: (_, _, _) => ColoredBox(color: scheme.surfaceContainerHighest, child: Icon(Icons.movie_outlined, size: 18, color: scheme.onSurfaceVariant))),
                  if (share.isVideo) const Center(child: Icon(Icons.play_circle_fill, size: 22, color: Colors.white)),
                ]),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(right: RasqSpacing.sm),
            child: RasqAvatar(imageUrl: share.authorAvatarUrl, size: RasqSizes.avatarSm, fallbackLabel: share.authorName),
          ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(child: Text(share.authorName, style: RasqTypography.caption.copyWith(fontWeight: FontWeight.w700, height: 1.2), maxLines: 1, overflow: TextOverflow.ellipsis)),
              RasqPill(label: share.kindLabel, color: RasqColors.link, textColor: Colors.white),
            ]),
            Text(share.headline, style: RasqTypography.caption.copyWith(fontSize: 10, height: 1.15), maxLines: 2, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]),
    );
  }
}

/// 下段の「文字起こし / 共有コンテンツ」(D-142: 入力欄の代わり)。
class _Ticker extends StatelessWidget {
  const _Ticker({required this.state, this.compact = false, this.lines = 2});
  final AstellSessionState state;
  final bool compact;

  /// 文字起こしの行数。
  final int lines;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lines = <String>[
      if (state.captionsOn) for (final t in state.transcripts.reversed.take(this.lines).toList().reversed) '${t.displayName}>${t.text}',
      if (state.shares.isNotEmpty && !compact) '共有: ${state.shares.last.headline}',
    ];
    if (lines.isEmpty) {
      lines.add(state.captionsOn ? (state.room.showSummary ? '文字起こしはまだありません' : '文字起こしは無効(要約非公開)') : '字幕オフ');
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      for (final l in lines) Text(l, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
    ]);
  }
}

/// 共有欄 (D-146): **チャットからピン留めしたもの**(文字起こし含む)と、設定で自動表示に
/// した種類。見出し「共有 (N)」+ ↓/↑、畳んでいれば直近 1 件、各カードに … / ピン解除。
class _SharesSection extends StatelessWidget {
  const _SharesSection({required this.items, required this.myHandle, required this.isOwner, required this.expanded, required this.onToggle, required this.onMore, required this.onOpen, required this.onUnpin});
  final List<_SharedItem> items;
  final String myHandle;
  final bool isOwner;
  final bool expanded;
  final VoidCallback onToggle;
  final void Function(AstellShare share, Rect anchor) onMore;
  final void Function(AstellShare share) onOpen;
  final void Function(_SharedItem item) onUnpin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shown = expanded ? items.reversed.toList() : [if (items.isNotEmpty) items.last];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.xs, 0),
        child: Row(children: [
          Text(items.isEmpty ? '共有' : '共有 (${items.length})', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          const Spacer(),
          if (items.length > 1)
            RasqIconButton(icon: expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 20, tooltip: expanded ? '共有を畳む' : '共有をすべて表示', onPressed: onToggle),
        ]),
      ),
      if (items.isEmpty)
        Padding(padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.xs), child: Text('チャットの 📌 でピン留めしたものがここに並びます(自動表示の種類は歯車で)。', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant))),
      for (final it in shown)
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 2, RasqSpacing.page, 2),
          child: Material(
            color: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RasqSizes.radiusMd), side: BorderSide(color: scheme.outline)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: it.share == null ? null : () => onOpen(it.share!),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(RasqSpacing.md, RasqSpacing.xs, RasqSpacing.xs, RasqSpacing.xs),
                child: it.share != null ? _shareRow(context, it) : _transcriptRow(context, it),
              ),
            ),
          ),
        ),
    ]);
  }

  Widget _shareRow(BuildContext context, _SharedItem it) {
    final scheme = Theme.of(context).colorScheme;
    final sh = it.share!;
    return Row(children: [
      if (sh.thumbnailUrl != null)
        Padding(
          padding: const EdgeInsets.only(right: RasqSpacing.sm),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(width: 48, height: 36, child: Stack(fit: StackFit.expand, children: [
              Image.network(sh.thumbnailUrl.toString(), fit: BoxFit.cover, errorBuilder: (_, _, _) => ColoredBox(color: scheme.surfaceContainerHighest)),
              if (sh.isVideo) const Center(child: Icon(Icons.play_circle_fill, size: 18, color: Colors.white)),
            ])),
          ),
        ),
      RasqPill(label: sh.kindLabel),
      const SizedBox(width: RasqSpacing.xs),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(sh.headline, style: RasqTypography.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
          Text('${sh.accountId == 'me' || sh.handle == myHandle ? 'あなた' : sh.displayName} が共有${sh.pinned ? ' ・ 📌' : ' ・ 自動表示'}', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
        ]),
      ),
      if (sh.pinned) RasqIconButton(icon: Icons.push_pin, size: 16, color: RasqColors.link, tooltip: 'ピン留めを外す', onPressed: () => onUnpin(it)),
      Builder(
        builder: (ctx) => RasqIconButton(
          icon: Icons.more_horiz,
          size: 18,
          tooltip: '共有の操作',
          onPressed: () {
            final box = ctx.findRenderObject() as RenderBox;
            onMore(sh, box.localToGlobal(Offset.zero) & box.size);
          },
        ),
      ),
    ]);
  }

  Widget _transcriptRow(BuildContext context, _SharedItem it) {
    final scheme = Theme.of(context).colorScheme;
    final t = it.transcript!;
    return Row(children: [
      const RasqPill(label: '文字起こし'),
      const SizedBox(width: RasqSpacing.xs),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.text, style: RasqTypography.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
          Text('${t.displayName} ・ ${_hhmm(t.createdAt)}${t.pinned ? ' ・ 📌' : ' ・ 自動表示'}', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
        ]),
      ),
      if (t.pinned) RasqIconButton(icon: Icons.push_pin, size: 16, color: RasqColors.link, tooltip: 'ピン留めを外す', onPressed: () => onUnpin(it)),
    ]);
  }
}

/// 共有枠 (D-146): ピン留め/クリックしたピアの画面共有。16:7 のプレビュー + 名前 + 閉じる/全画面。
class _ViewingScreenPanel extends StatelessWidget {
  const _ViewingScreenPanel({required this.peer, required this.muted, required this.onFullscreen, required this.onMore});
  final AstellPeer peer;
  final bool muted;
  final VoidCallback onFullscreen;

  /// 「…」(D-147): ピン解除 / 全画面 / ミュート / フォロー / ブロック / 通報。
  final void Function(Rect anchor) onMore;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sc = peer.screenShare!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(RasqSizes.radiusMd),
        child: AspectRatio(
          aspectRatio: 16 / 7,
          child: Stack(fit: StackFit.expand, children: [
            if (sc.thumbnailUrl != null)
              Image.network(sc.thumbnailUrl.toString(), fit: BoxFit.cover, errorBuilder: (_, _, _) => ColoredBox(color: scheme.surfaceContainerHighest))
            else
              ColoredBox(color: scheme.surfaceContainerHighest),
            Positioned(left: 8, top: 8, child: Row(mainAxisSize: MainAxisSize.min, children: [
              RasqPill(label: '画面共有', color: RasqColors.sub, textColor: Colors.white),
              if (muted) ...[const SizedBox(width: 4), RasqPill(label: 'ミュート中', color: RasqColors.danger, textColor: Colors.white)],
            ])),
            Positioned(right: 4, top: 4, child: Row(mainAxisSize: MainAxisSize.min, children: [
              RasqIconButton(icon: Icons.fullscreen, color: Colors.white, tooltip: '全画面', onPressed: onFullscreen),
              Builder(builder: (ctx) => RasqIconButton(
                icon: Icons.more_horiz,
                color: Colors.white,
                tooltip: '共有枠の操作',
                onPressed: () {
                  final box = ctx.findRenderObject() as RenderBox;
                  onMore(box.localToGlobal(Offset.zero) & box.size);
                },
              )),
            ])),
            Positioned(
              left: 8,
              right: 8,
              bottom: 6,
              child: Text('${peer.displayName} の画面${sc.title.isEmpty ? '' : ' — ${sc.title}'}',
                  style: RasqTypography.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700, shadows: const [Shadow(blurRadius: 4, color: Colors.black)]), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ]),
        ),
      ),
    );
  }
}

/// ルームタブの参加メンバー行 (D-147、ワイヤーフレーム右下): アバター(マイクのバッジ)+
/// 名前 / @handle + 画面共有枠(タップで共有枠に表示)+ スピーカー(ミュート切替)+ 「…」。
class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.peer, required this.self, this.role, required this.muted, required this.viewing, required this.onViewScreen, required this.onMute, required this.onMore});
  final AstellPeer peer;
  final bool self;

  /// 役割のピル (D-149): ホスト / モデレーター。
  final String? role;
  final bool muted;
  final bool viewing;
  final VoidCallback onViewScreen;
  final VoidCallback onMute;
  final void Function(Rect anchor) onMore;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = peer;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.sm),
      child: Row(children: [
        RasqAvatar(
          imageUrl: p.avatarUrl,
          size: RasqSizes.avatarLg,
          fallbackLabel: p.displayName,
          // 全員向けミュート (D-149) は赤のマイクオフ。
          badge: _StateBadge(icon: p.micOn ? Icons.mic : Icons.mic_off, color: p.mutedByMod ? RasqColors.danger : (p.micOn ? RasqColors.accent : scheme.outline)),
        ),
        const SizedBox(width: RasqSpacing.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 4, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(self ? '${p.displayName}(あなた)' : p.displayName, style: RasqTypography.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
              if (role != null) RasqPill(label: role!, color: role == 'ホスト' ? RasqColors.accent : RasqColors.sub, textColor: Colors.white),
              if (p.mutedByMod) const RasqPill(label: '強制ミュート', color: RasqColors.danger, textColor: Colors.white),
            ]),
            Text('@${p.handle}', style: RasqTypography.handle.copyWith(color: scheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
        // 画面共有枠: マイク表示(スピーカー)の左。
        if (p.screenShare != null) ...[
          GestureDetector(
            onTap: onViewScreen,
            child: Tooltip(
              message: viewing ? '共有枠に表示中' : '画面共有を表示',
              child: Container(
                width: 72,
                height: 44,
                decoration: BoxDecoration(
                  border: Border.all(color: viewing ? RasqColors.link : scheme.outlineVariant, width: viewing ? 2 : 1),
                  borderRadius: BorderRadius.circular(RasqSizes.radiusSm),
                  color: scheme.surfaceContainerHighest,
                ),
                clipBehavior: Clip.antiAlias,
                child: p.screenShare!.thumbnailUrl != null
                    ? Image.network(p.screenShare!.thumbnailUrl.toString(), fit: BoxFit.cover, errorBuilder: (_, _, _) => Icon(Icons.desktop_windows, size: 18, color: scheme.onSurfaceVariant))
                    : Icon(Icons.desktop_windows, size: 18, color: scheme.onSurfaceVariant),
              ),
            ),
          ),
          const SizedBox(width: RasqSpacing.sm),
        ] else
          Padding(
            padding: const EdgeInsets.only(right: RasqSpacing.sm),
            child: Icon(Icons.desktop_access_disabled_outlined, size: 20, color: scheme.outline),
          ),
        // スピーカー: 青 = 聞こえる / 赤 = ミュート。自分には出さない。
        if (!self) ...[
          RasqIconButton(
            icon: muted ? Icons.volume_off : Icons.volume_up,
            size: 20,
            color: muted ? RasqColors.danger : RasqColors.link,
            tooltip: muted ? 'ミュート解除' : 'ミュート',
            onPressed: onMute,
          ),
          Builder(builder: (ctx) => RasqIconButton(
            icon: Icons.more_horiz,
            size: 20,
            tooltip: 'メンバーの操作',
            onPressed: () {
              final box = ctx.findRenderObject() as RenderBox;
              onMore(box.localToGlobal(Offset.zero) & box.size);
            },
          )),
        ],
      ]),
    );
  }
}

/// 設定シートの BAN 一覧 (D-149): オーナーが解除できる。
class _BanList extends ConsumerStatefulWidget {
  const _BanList({required this.roomId});
  final String roomId;
  @override
  ConsumerState<_BanList> createState() => _BanListState();
}

class _BanListState extends ConsumerState<_BanList> {
  late Future<List<AstellBan>> _bans = ref.read(astellClientProvider).bans(widget.roomId);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<List<AstellBan>>(
      future: _bans,
      builder: (context, snap) {
        final bans = snap.data ?? const <AstellBan>[];
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _label(context, 'BAN(${bans.length})— メンバー行の「…」から'),
          if (snap.hasError) Padding(padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page), child: Text('BAN 一覧を読めませんでした: ${snap.error}', style: RasqTypography.caption.copyWith(color: scheme.error))),
          for (final b in bans)
            RasqListTile(
              title: b.displayName,
              subtitle: '@${b.handle}${b.reason == null ? '' : ' — ${b.reason}'}',
              chevron: false,
              trailing: RasqIconButton(
                icon: Icons.lock_open_outlined,
                size: 20,
                tooltip: 'BAN を解除',
                onPressed: () async {
                  await ref.read(astellClientProvider).unban(widget.roomId, b.accountId);
                  if (!mounted) return;
                  final next = ref.read(astellClientProvider).bans(widget.roomId);
                  setState(() {
                    _bans = next;
                  });
                },
              ),
            ),
        ]);
      },
    );
  }
}

extension<T extends Object> on T {
  R let<R>(R Function(T it) f) => f(this);
}

/// 通報シート (D-150): 理由(スパム / 嫌がらせ / 違法 / その他)+ 補足 → `POST /reports`。
/// rasq-judge が確認する。参加者・共有・チャット行・VC タイルから開く。
Future<void> showAstellReportSheet(BuildContext context, WidgetRef ref, {String? targetAccountId, String? roomId, String? shareId, required String what}) async {
  final manager = ref.read(overlayManagerProvider);
  final note = TextEditingController();
  var reason = astellReportReasons.first.id;
  var sent = false;
  await manager.showBottomSheet<void>(
    id: 'astell.report',
    title: '通報',
    builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
      final scheme = Theme.of(ctx).colorScheme;
      return ListView(shrinkWrap: true, children: [
        Padding(padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0), child: Text('$what を通報します。rasq-judge(審査)が確認します。', style: RasqTypography.bodySmall)),
        for (final r in astellReportReasons) RasqRadioListTile<String>(title: r.label, value: r.id, groupValue: reason, onChanged: (v) => setSheet(() => reason = v)),
        Padding(padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page), child: RasqInput(controller: note, hintText: '補足(任意)', maxLines: 3)),
        Padding(
          padding: const EdgeInsets.all(RasqSpacing.page),
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: scheme.error),
            onPressed: () async {
              try {
                await ref.read(astellClientProvider).report(targetAccountId: targetAccountId, roomId: roomId, shareId: shareId, reason: reason, note: note.text.trim().isEmpty ? null : note.text.trim());
                sent = true;
                manager.close('astell.report');
              } catch (e) {
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('通報できませんでした: $e')));
              }
            },
            child: const Text('通報する'),
          ),
        ),
      ]);
    }),
  );
  note.dispose();
  if (sent && context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('通報しました。rasq-judge が確認します')));
}

/// 作成 FOW の招待チップ (D-150): アバター + 名前、選択中はチェックの縁取り。
class _InviteeChip extends StatelessWidget {
  const _InviteeChip({required this.entry, required this.selected, required this.onTap});
  final AstellFollowEntry entry;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Tooltip(
        message: selected ? '${entry.displayName} の招待をやめる' : '${entry.displayName} を招待',
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(clipBehavior: Clip.none, children: [
            Container(
              width: RasqSizes.avatarXl,
              height: RasqSizes.avatarXl,
              // 縁取りは前景に描いて大きさを変えない(横並びの高さを揃える)。
              foregroundDecoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: selected ? RasqColors.link : Colors.transparent, width: 2.5)),
              child: RasqAvatar(imageUrl: entry.avatarUrl, size: RasqSizes.avatarXl, fallbackLabel: entry.displayName),
            ),
            if (selected) const Positioned(right: -2, bottom: -2, child: _StateBadge(icon: Icons.check, color: RasqColors.link)),
          ]),
          const SizedBox(height: 2),
          SizedBox(width: RasqSizes.avatarXl + 8, child: Text(entry.displayName, style: RasqTypography.caption, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)),
        ]),
      ),
    );
  }
}

/// ホストの配信パネル(展開時、共有欄の上): 16:9 のプレビュー + LIVE + タイトル。
class _HostStreamPanel extends StatelessWidget {
  const _HostStreamPanel({required this.stream, required this.onTap});
  final AstellHostStream stream;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, 0),
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(RasqSizes.radiusMd),
          child: AspectRatio(
            aspectRatio: 16 / 7,
            child: Stack(fit: StackFit.expand, children: [
              if (stream.thumbnailUrl != null)
                Image.network(stream.thumbnailUrl.toString(), fit: BoxFit.cover, errorBuilder: (_, _, _) => ColoredBox(color: scheme.surfaceContainerHighest))
              else
                ColoredBox(color: scheme.surfaceContainerHighest),
              const Center(child: Icon(Icons.play_circle_fill, size: 40, color: Colors.white70)),
              Positioned(left: 8, top: 8, child: RasqPill(label: 'LIVE', color: RasqColors.live, textColor: Colors.white)),
              Positioned(
                left: 8,
                right: 8,
                bottom: 6,
                child: Text(
                  '${stream.isScreen ? '画面共有' : '配信'}: ${stream.title}',
                  style: RasqTypography.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700, shadows: const [Shadow(blurRadius: 4, color: Colors.black)]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// stick の先頭ページ: ホストの配信の印(サムネイル + LIVE + タイトル)。
class _HostStreamTile extends StatelessWidget {
  const _HostStreamTile({required this.stream, required this.room});
  final AstellHostStream stream;
  final AstellRoom room;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          width: 64,
          height: 44,
          child: Stack(fit: StackFit.expand, children: [
            if (stream.thumbnailUrl != null)
              Image.network(stream.thumbnailUrl.toString(), fit: BoxFit.cover, errorBuilder: (_, _, _) => ColoredBox(color: scheme.surfaceContainerHighest))
            else
              ColoredBox(color: scheme.surfaceContainerHighest),
            const Center(child: Icon(Icons.play_circle_fill, size: 20, color: Colors.white70)),
            Positioned(
              left: 3,
              top: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(color: RasqColors.live, borderRadius: BorderRadius.circular(3)),
                child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800, height: 1.0)),
              ),
            ),
          ]),
        ),
      ),
      const SizedBox(width: RasqSpacing.sm),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('${room.ownerDisplayName} が${stream.isScreen ? '画面共有' : '配信'}中', style: RasqTypography.caption.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(stream.title, style: RasqTypography.caption.copyWith(fontSize: 10, color: scheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
    ]);
  }
}

String _guessMime(String name) {
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  return switch (ext) {
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'mp4' || 'm4v' => 'video/mp4',
    'mov' => 'video/quicktime',
    'webm' => 'video/webm',
    _ => 'application/octet-stream',
  };
}

// ── 作成 FOW ──────────────────────────────────────────────────────

Future<void> openAstellCreateFow(BuildContext context, WidgetRef ref) async {
  final manager = ref.read(overlayManagerProvider);
  await manager.showFow<void>(
    id: astellCreateFowId,
    spec: _spec(title: 'VC を作成', cancelText: 'キャンセル', height: 0.7),
    barrierBehavior: OverlayBarrierBehavior.dismissDiscard,
    builder: (ctx, handle) => _CreateBody(onCreated: (room) async {
      handle.close();
      ref.invalidate(astellHomeProvider);
      await ref.read(astellSessionProvider.notifier).join(room);
      if (context.mounted) await openAstellRoomFow(context, ref);
    }),
  );
}

class _CreateBody extends ConsumerStatefulWidget {
  const _CreateBody({required this.onCreated});
  final Future<void> Function(AstellRoom room) onCreated;
  @override
  ConsumerState<_CreateBody> createState() => _CreateBodyState();
}

class _CreateBodyState extends ConsumerState<_CreateBody> {
  /// 招待する RASQ アカウント (D-150): フォロワーのチップと「検索して追加」で選ぶ。
  final Map<String, AstellFollowEntry> _invitees = {};
  final _title = TextEditingController();
  final _welcome = TextEditingController();
  final _description = TextEditingController();
  bool _welcomeOn = false;
  bool _showSummary = true;
  bool _autoGenre = true;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _welcome.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('タイトルを入力してください')));
      return;
    }
    setState(() => _busy = true);
    try {
      final room = await ref.read(astellClientProvider).createRoom(NewAstellRoom(
            title: title,
            description: _description.text.trim(),
            welcomeMessage: _welcomeOn && _welcome.text.trim().isNotEmpty ? _welcome.text.trim() : null,
            showSummary: _showSummary,
            autoGenre: _autoGenre,
          ));
      // 招待 (D-150): 作成後にまとめて送る(失敗しても作成は成立)。
      if (_invitees.isNotEmpty) {
        try {
          await ref.read(astellClientProvider).invite(room.id, _invitees.keys.toList());
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('招待を送れませんでした: $e')));
        }
      }
      await widget.onCreated(room);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('作成できませんでした: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 「検索して追加」: RASQ アカウントのハンドルで探して招待に足す (D-150)。
  Future<void> _searchInvitee() async {
    final manager = ref.read(overlayManagerProvider);
    final input = TextEditingController();
    String? error;
    await manager.showBottomSheet<void>(
      id: 'astell.create.invite',
      title: '検索して追加',
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        final scheme = Theme.of(ctx).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.page),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            RasqInput(controller: input, hintText: '@handle(RASQ アカウント)', autofocus: true),
            if (error != null) Padding(padding: const EdgeInsets.only(top: RasqSpacing.xs), child: Text(error!, style: RasqTypography.caption.copyWith(color: scheme.error))),
            const SizedBox(height: RasqSpacing.sm),
            FilledButton(
              onPressed: () async {
                final found = await ref.read(astellClientProvider).lookupAccount(input.text);
                if (!ctx.mounted) return;
                if (found == null) {
                  setSheet(() => error = '見つかりませんでした: ${input.text}');
                  return;
                }
                setState(() => _invitees[found.id] = found);
                manager.close('astell.create.invite');
              },
              child: const Text('招待に追加'),
            ),
          ]),
        );
      }),
    );
    input.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final me = ref.watch(rasqAccountProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        child: ListView(padding: EdgeInsets.zero, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
            child: RasqInput(controller: _title, hintText: 'タイトル', autofocus: true),
          ),
          _label(context, 'フォロワーを招待${_invitees.isEmpty ? '' : '(${_invitees.length})'}'),
          // あなた / フォロワー(タップで選択)/ 検索して追加 を横に並べる (D-150)。
          SizedBox(
            height: RasqSizes.avatarXl + 24,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.xs),
              children: [
                Column(mainAxisSize: MainAxisSize.min, children: [
                  RasqAvatar(imageUrl: me.avatarUrl, size: RasqSizes.avatarXl, fallbackLabel: me.displayName),
                  const SizedBox(height: 2),
                  Text('あなた', style: RasqTypography.caption),
                ]),
                const SizedBox(width: RasqSpacing.md),
                for (final f in ref.watch(astellFollowersProvider).value ?? const <AstellFollowEntry>[]) ...[
                  _InviteeChip(entry: f, selected: _invitees.containsKey(f.id), onTap: () => setState(() => _invitees.containsKey(f.id) ? _invitees.remove(f.id) : _invitees[f.id] = f)),
                  const SizedBox(width: RasqSpacing.md),
                ],
                for (final f in _invitees.values)
                  if (!(ref.watch(astellFollowersProvider).value ?? const <AstellFollowEntry>[]).any((x) => x.id == f.id)) ...[
                    _InviteeChip(entry: f, selected: true, onTap: () => setState(() => _invitees.remove(f.id))),
                    const SizedBox(width: RasqSpacing.md),
                  ],
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Material(
                    shape: CircleBorder(side: BorderSide(color: scheme.onSurface, width: 1.5)),
                    color: Colors.transparent,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _searchInvitee,
                      child: SizedBox(width: RasqSizes.avatarXl, height: RasqSizes.avatarXl, child: Tooltip(message: '検索して追加', child: Icon(Icons.add, size: 28, color: scheme.onSurface))),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('検索して追加', style: RasqTypography.caption),
                ]),
              ],
            ),
          ),
          const Divider(height: RasqSpacing.md),
          RasqSwitchListTile(title: '参加時にウェルカムメッセージを表示する', value: _welcomeOn, onChanged: (v) => setState(() => _welcomeOn = v)),
          if (_welcomeOn)
            Padding(
              padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.sm),
              child: RasqInput(controller: _welcome, hintText: 'ウェルカムメッセージを設定..'),
            ),
          const Divider(height: 1),
          RasqSwitchListTile(title: 'プレビューにざっくり要約を表示する', value: _showSummary, onChanged: (v) => setState(() => _showSummary = v)),
          const Divider(height: 1),
          RasqSwitchListTile(title: 'ジャンルを自動選択する', value: _autoGenre, onChanged: (v) => setState(() => _autoGenre = v)),
          Padding(
            padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, RasqSpacing.sm),
            child: RasqInput(controller: _description, hintText: 'ざっくり要約(任意。空なら端末側で自動生成)', maxLines: 2),
          ),
        ]),
      ),
      const Divider(height: 1),
      Padding(
        padding: const EdgeInsets.all(RasqSpacing.sm),
        child: Row(children: [
          _RoundButton(icon: Icons.mic_off, tooltip: 'マイク(作成後に切替)', onPressed: null),
          const SizedBox(width: RasqSpacing.sm),
          _RoundButton(icon: Icons.subtitles_outlined, tooltip: '字幕', filled: _showSummary ? const Color(0xFF2EBF8F) : scheme.outline, onPressed: () => setState(() => _showSummary = !_showSummary)),
          const SizedBox(width: RasqSpacing.sm),
          Expanded(child: RasqGradientButton(label: '作成', onPressed: _busy ? null : _create, enabled: !_busy)),
          const SizedBox(width: RasqSpacing.sm),
          _RoundButton(icon: Icons.settings, tooltip: '設定', onPressed: () => _notYet(context, 'VC の設定')),
        ]),
      ),
    ]);
  }
}
