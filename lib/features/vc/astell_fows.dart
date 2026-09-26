import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../shell/third_column.dart';
import '../home/action_bar_config.dart';
import '../home/action_bar_edit_sheet.dart';
import '../home/action_bundle_fow.dart';
import '../home/plugin_actions.dart';
import '../home/post_row.dart' show PostRow, bundleIconOf;
import '../plugins/slot_plugins.dart';
import '../settings/settings_dsl.dart';
import '../trend/tendency_profile.dart';
import 'astell_actions.dart';
import 'astell_bar.dart';
import 'astell_bookmarks.dart';
import 'astell_call.dart' show astellMeshCap;
import 'astell_links.dart';
import 'astell_media_viewer.dart';
import 'astell_models.dart';
import 'astell_post_share.dart';
import 'astell_providers.dart';
import 'astell_stream.dart';
import 'astell_stream_livekit.dart' show astellNeedsScreenPicker, pickAstellScreenSource;

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
/// 音声は通話(P2P、D-317)、映像(ホストの配信 / 画面共有)は LiveKit(D-317)。
const astellPreviewFowId = 'fow.astell.preview';
const astellRoomFowId = 'fow.astell.room';
const astellCreateFowId = 'fow.astell.create';

/// 作成 FOW のフォーム(縦スクロール)。テストがスクロール先に使う。
const astellCreateFormKey = Key('astell.create.form');

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

/// ホストの行: ルームを作った人の顔 / 名前 / @handle と、いま参加しているか。
/// 参加 FOW とルーム FOW のホームで、「参加メンバー」の上に置く(参加メンバーの行からはホストを除く)。
class AstellHostRow extends StatelessWidget {
  const AstellHostRow({super.key, required this.room, required this.peers});
  final AstellRoom room;
  final List<AstellPeer> peers;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final here = peers.where((p) => p.accountId == room.ownerId).firstOrNull;
    final (label, color) = here != null
        ? ('参加中', RasqColors.accent)
        : room.isScheduled
            ? ('開催前', RasqColors.sub)
            : ('不在', scheme.outline);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.xs),
      child: Row(children: [
        RasqAvatar(
          // 接続中ならピアの顔(最新)、いなければルームのオーナーの顔。
          imageUrl: here?.avatarUrl ?? room.ownerAvatarUrl,
          size: RasqSizes.avatarLg,
          fallbackLabel: room.ownerDisplayName,
          badge: here == null ? null : _StateBadge(icon: here.micOn ? Icons.mic : Icons.volume_up, color: here.micOn ? RasqColors.accent : RasqColors.sub),
        ),
        const SizedBox(width: RasqSpacing.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(room.ownerDisplayName, style: RasqTypography.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('@${room.ownerHandle}', style: RasqTypography.handle.copyWith(color: scheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
        RasqPill(label: label, color: color, textColor: Colors.white),
      ]),
    );
  }
}

/// ホストを除いた参加メンバーと、その人数(`peerCount` はホストを含む)。
(List<AstellPeer>, int?) _guests(AstellRoom room, List<AstellPeer> peers, {int? peerCount}) {
  final guests = [for (final p in peers) if (p.accountId != room.ownerId) p];
  if (peerCount == null) return (guests, null);
  final hostHere = guests.length != peers.length;
  final total = peerCount - (hostHere ? 1 : 0);
  return (guests, total > guests.length ? total : null);
}

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
                badge: _StateBadge(icon: p.speaking ? Icons.graphic_eq : (p.micOn ? Icons.mic : Icons.volume_up), color: p.speaking ? astellSpeakingColor : (p.micOn ? RasqColors.accent : RasqColors.sub)),
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
              ? Image.network(webHtmlElementStrategy: rasqWebImageStrategy, share.thumbnailUrl.toString(), fit: BoxFit.cover, errorBuilder: (_, _, _) => Icon(Icons.desktop_windows, size: 14, color: scheme.onSurfaceVariant))
              : Icon(Icons.desktop_windows, size: 14, color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// 話している印の色 (D-317)。字幕のボタンと同じ緑。
const astellSpeakingColor = Color(0xFF2EBF8F);

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
  const _RoundButton({super.key, required this.icon, required this.tooltip, this.onPressed, this.filled});
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
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$what は今後の対応です')));
}

// ── 参加 FOW ──────────────────────────────────────────────────────

Future<void> openAstellPreviewFow(BuildContext context, WidgetRef ref, AstellRoom room) async {
  final manager = ref.read(overlayManagerProvider);
  await manager.showFow<void>(
    id: astellPreviewFowId,
    spec: _spec(
      title: room.title,
      cancelText: '閉じる',
      // 共有(投稿コンポーザーへリンク転送)/ ブックマーク (D-159/D-160)。
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        RasqIconButton(icon: Icons.ios_share, size: 20, tooltip: '共有', onPressed: () => shareAstellRoom(context, ref, room)),
        AstellBookmarkButton(room: room),
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
          _label(context, 'ホスト'),
          AstellHostRow(room: room, peers: peers),
          _label(context, '参加メンバー'),
          Builder(builder: (context) {
            final (guests, total) = _guests(room, peers, peerCount: room.peerCount);
            return AstellMembersRow(peers: guests, totalCount: total);
          }),
          if (room.locked)
            Padding(
              padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, 0),
              child: Text('運営により新規入室が停止されています(D-151)。', style: RasqTypography.caption.copyWith(color: RasqColors.danger)),
            ),
          // 開催予定 (D-159): 時刻と開始通知の登録。
          if (room.isScheduled)
            RasqListTile(
              title: '開催予定 ${formatAstellSchedule(room.scheduledAt!)}',
              subtitle: ref.watch(astellRemindedProvider(room.id)) ? '開始を通知します' : 'ホストが始めるまで参加できません',
              leading: const Icon(Icons.schedule, color: RasqColors.link),
              trailing: TextButton(onPressed: () => remindAstellRoom(context, ref, room), child: Text(ref.watch(astellRemindedProvider(room.id)) ? '通知を解除' : '開始を通知')),
              chevron: false,
            ),
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

/// 歯車のメニューの先頭の「下段に入りきらないボタン」(D-324)。
const astellOverflowKey = Key('astell.footer.overflow');

/// はみ出したボタンがあるときの歯車の点 (D-324)。
const astellOverflowDotKey = Key('astell.footer.overflow.dot');
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
  static const _chromeHeight = kFowHandleHeight + 12;

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
    // 相手の画面にも下書きを出す (D-311)。送る間隔と、強い言葉の判定は AstellSession の側。
    ref.read(astellSessionProvider.notifier).setDraft(text);
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
          // compact の判定は**目標の高さだけ** (D-178)。以前は実際の制約でも切り替えていたため、
          // キーボードで FOW が縮む / 閉じて伸び戻るアニメーションの間に compact へ変形し、入力欄
          // (TextField)やタブの状態ごと消えてキーボードが一瞬で閉じていた。制約が足りない間は
          // 下の OverflowBox で上を切る。
          final squeezed = constraints.maxHeight < astellRoomTabsCoveredHeight;
          final compact = targetPx < astellRoomTabsCoveredHeight;
          if (!compact) {
            // 展開: 木の形は狭くても同じ(ClipRect > OverflowBox > 本体)にして TextField / タブの
            // 状態を保つ。キーボードで狭い間は最低 300px で組み、足りない分は上を切る(下段の入力欄が見える)。
            return ClipRect(
              child: OverflowBox(
                alignment: Alignment.bottomCenter,
                minHeight: 0,
                maxHeight: squeezed ? astellRoomTabsCoveredHeight : constraints.maxHeight,
                child: _body(context, compact: false),
              ),
            );
          }
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
                  RasqIconButton(icon: Icons.ios_share, size: 20, tooltip: '共有', onPressed: () => shareAstellRoom(context, ref, room)),
                  AstellBookmarkButton(room: room),
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
        else if (s.notice != null)
          Container(
            color: RasqColors.sub.withValues(alpha: 0.10),
            padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.xs),
            child: Text(s.notice!, style: RasqTypography.caption.copyWith(color: RasqColors.sub)),
          )
        else if (!s.connected)
          Container(
            color: scheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.xs),
            child: Text('接続しています…', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          ),
        // 自分が LiveKit に上げている間 (D-317): 画面共有 / ホストの配信。
        if (s.screenShareOn || (s.streaming != null && room.hostStream != null))
          Container(
            color: RasqColors.sub.withValues(alpha: 0.12),
            padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.xs, 0),
            child: Row(children: [
              Icon(s.screenShareOn ? Icons.desktop_windows : Icons.videocam, size: 16, color: RasqColors.sub),
              const SizedBox(width: RasqSpacing.xs),
              Expanded(child: Text(s.screenShareOn ? '画面を共有しています' : (s.streaming == 'screen' ? '画面を配信しています' : 'カメラで配信しています'), style: RasqTypography.caption.copyWith(color: RasqColors.sub))),
              TextButton(
                onPressed: s.screenShareOn ? () => session.toggleScreenShare() : session.stopHostStream,
                child: Text(s.screenShareOn ? '共有をやめる' : '配信を止める', style: RasqTypography.caption.copyWith(color: RasqColors.danger, fontWeight: FontWeight.w700)),
              ),
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
        // ── ホストの配信 (D-145): 動画/画面のプレビュー。映像は LiveKit (D-317) ──
        else if (room.hostStream != null)
          _HostStreamPanel(stream: room.hostStream!, ownerId: room.ownerId, onTap: () => _openStream(context, room)),
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
        // 入力欄の左の丸いボタン (D-324): 設定の並び(ASTell →「ルームのボタン」/ 歯車)で。
        items: _barItems(context, ref, s),
        itemBuilder: _barItemWidget,
        onSendText: _sendText,
        onPickFile: _pickAndShare,
        onSettings: (overflow) => _openSettings(context, s, isOwner, overflow: overflow),
        onExpand: _expand,
        onLeave: leave,
        onOpenShare: (share) => _openShare(context, share),
        onFullscreen: s.viewingPeer == null ? null : () => _openPeerScreen(context, s.viewingPeer!),
      ),
    ]);
  }

  /// 下段のボタンの今の見た目と動き (D-324)。id → ボタン。今は出さないもの(全画面は共有枠が空のとき)は入れない。
  /// **ボタンの種類を足すとき**は、`astell_bar.dart` の [astellBarBuiltinActions] と、ここに 1 つ。
  Map<String, AstellBarButton> _barButtons(BuildContext context, WidgetRef ref, AstellSessionState s) {
    final session = ref.read(astellSessionProvider.notifier);
    final hasPlugins = ref.watch(slotPluginsForProvider(SlotIds.astellAction)).isNotEmpty;
    return {
      AstellBarIds.speaker: AstellBarButton(icon: s.speakerMuted ? Icons.volume_off : Icons.volume_up, tooltip: s.speakerMuted ? 'スピーカーミュート解除' : 'スピーカーミュート', filled: s.speakerMuted ? RasqColors.danger : null, onPressed: session.toggleSpeaker),
      AstellBarIds.mic: s.forceMuted
          ? const AstellBarButton(icon: Icons.mic_off, tooltip: 'モデレーターにミュートされています', filled: RasqColors.danger)
          : AstellBarButton(icon: s.micOn ? Icons.mic : Icons.mic_off, tooltip: s.micOn ? 'マイクオフ' : 'マイクオン', filled: s.micOn ? RasqColors.accent : null, onPressed: session.toggleMic),
      AstellBarIds.screen: AstellBarButton(icon: s.screenShareOn ? Icons.desktop_windows : Icons.desktop_access_disabled_outlined, tooltip: s.screenShareOn ? '画面共有オフ' : '画面共有', filled: s.screenShareOn ? RasqColors.sub : null, onPressed: () => _toggleScreen(context)),
      if (s.viewingPeer case final peer?) AstellBarIds.fullscreen: AstellBarButton(icon: Icons.fullscreen, tooltip: '全画面', onPressed: () => _openPeerScreen(context, peer)),
      // プラグインアクション (D-167): スロット `astell.action` のプラグインを選んで開く。登録が無ければ無効表示。
      AstellBarIds.plugins: AstellBarButton(icon: Icons.extension_outlined, tooltip: hasPlugins ? 'プラグインアクション' : 'プラグインアクション(未登録)', filled: hasPlugins ? RasqColors.sub : null, onPressed: hasPlugins ? () => _openPlugin(context, s) : null),
      AstellBarIds.captions: AstellBarButton(icon: Icons.subtitles_outlined, tooltip: s.captionsOn ? '字幕オフ' : '字幕オン', filled: s.captionsOn ? const Color(0xFF2EBF8F) : null, onPressed: session.toggleCaptions),
      // プラグインのボタン (D-324): 押すとそのプラグインを開く(選ぶシートを挟まない)。
      for (final p in ref.watch(astellPluginActionsProvider))
        p.id: AstellBarButton(icon: PostRow.iconFor(p.decl.icon, Icons.extension_outlined), tooltip: p.decl.label, onPressed: () => ref.read(slotPluginsProvider.notifier).astellOpen(p.plugin, ref.read(astellSessionProvider) ?? s, fowOwner: astellRoomFowId, column: fowColumnOf(context))),
    };
  }

  /// 設定の並び(構成 `astell:room`)+ プラグインのボタン → 下段の並び (D-324)。
  List<AstellBarItem> _barItems(BuildContext context, WidgetRef ref, AstellSessionState s) => resolveAstellBar(
        config: ref.watch(actionBarConfigProvider(astellBarConfigKey)),
        plugins: ref.watch(pluginActionsForProvider(astellBarConfigKey)),
        settings: ref.watch(slotActionSettingsProvider(slotSettingsKeyFor(astellBarConfigKey, ''))),
        prefs: ref.watch(actionButtonPrefsProvider),
        buttons: _barButtons(context, ref, s),
      );

  /// 下段の 1 枠: 単体は丸いボタン、バンドルはバンドルのアイコンの丸いボタン(押すとバンドル FOW、D-210 と同じ)。
  Widget _barItemWidget(AstellBarItem item) => switch (item) {
        AstellBarSingle(:final id, :final button) => _RoundButton(key: ValueKey('astell.bar.$id'), icon: button.icon, tooltip: button.tooltip, filled: button.filled, onPressed: button.onPressed),
        AstellBarBundle(:final list, :final members) => Builder(
            builder: (ctx) => _RoundButton(
              key: ValueKey('astell.bar.${item.key}'),
              icon: bundleIconOf(list, [for (final m in members) m.action]),
              tooltip: list.name,
              onPressed: () async {
                final box = ctx.findRenderObject() as RenderBox;
                final picked = await showBundleMenuFow<String>(
                  ref.read(overlayManagerProvider),
                  id: actionBundleMenuFowId('astell.${list.id}'),
                  title: list.name,
                  anchor: box.localToGlobal(Offset.zero) & box.size,
                  column: fowColumnOf(ctx),
                  items: [for (final m in members) BundleMenuItem(value: m.action.id, label: m.button.tooltip, icon: m.button.icon)],
                );
                members.where((m) => m.action.id == picked).firstOrNull?.button.onPressed?.call();
              },
            ),
          ),
      };

  Future<void> _sendText() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    final isLink = text.startsWith('http://') || text.startsWith('https://');
    ref.read(astellSessionProvider.notifier).clearDraft();
    _input.clear(); // → リスナーが下書き枠を消す
    // SNS の投稿 URL はインラインで共有 (D-166): 自分のアカウントのインスタンスなら
    // プラグイン(トークン)で、そうでなければ Central の公開 API 解決で。取れなければリンク。
    final ref_ = parseSnsPostUrl(text);
    if (isLink && ref_ != null) {
      try {
        final payload = await _resolvePost(text, ref_);
        ref.read(astellSessionProvider.notifier).share('post', payload);
        return;
      } on AstellShareBlocked {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('公開範囲が限定された投稿なので、リンクとして共有します')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('投稿を取れなかったのでリンクとして共有します: $e')));
      }
    }
    ref.read(astellSessionProvider.notifier).share(isLink ? 'link' : 'text', isLink ? {'url': text} : {'text': text});
  }

  Future<Map<String, Object?>> _resolvePost(String url, ({String sns, String instance, String id}) r) async {
    final sessions = ref.read(sessionsProvider).value?.sessions ?? const <AccountSession>[];
    final acct = astellAccountForPost({'sns': r.sns, 'instance': r.instance}, sessions, prefer: ref.read(currentAccountProvider));
    if (acct != null) {
      final session = ref.read(sessionForAccountProvider(acct.key));
      if (session != null) {
        try {
          final post = await session.post(r.id);
          // 自分のトークンでしか読めない投稿は、本文を配らずリンクとして共有する (D-242)。
          if (astellShareBlockReason(post) != null) throw const AstellShareBlocked();
          return astellPostPayloadOf(post);
        } on AstellShareBlocked {
          rethrow;
        } catch (e) {
          debugPrint('astell: plugin post fetch failed, falling back to central: $e');
        }
      }
    }
    return ref.read(astellClientProvider).resolvePost(url);
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

  /// プラグインアクション (D-167): 1 つなら即開く、複数ならシートで選ぶ。
  Future<void> _openPlugin(BuildContext context, AstellSessionState s) async {
    final plugins = ref.read(slotPluginsForProvider(SlotIds.astellAction));
    if (plugins.isEmpty) return;
    var pick = plugins.length == 1 ? plugins.first : null;
    if (pick == null) {
      final manager = ref.read(overlayManagerProvider);
      pick = await manager.showBottomSheet<SlotPlugin>(
        id: 'astell.plugin.pick',
        title: 'プラグインアクション',
        builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
          for (final p in plugins) RasqListTile(title: p.manifest.name, subtitle: p.manifest.description, onTap: () => manager.close('astell.plugin.pick', result: p)),
        ]),
      );
    }
    if (pick == null || !context.mounted) return;
    // プラグインの FOW はルーム FOW の子として同じカラムに (D-169)。
    await ref.read(slotPluginsProvider.notifier).astellOpen(pick, s, fowOwner: astellRoomFowId, column: fowColumnOf(context));
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

  /// ピアの画面共有を全画面(映像は LiveKit、D-317。届くまではサムネイル)。
  Future<void> _openPeerScreen(BuildContext context, AstellPeer peer) {
    final sc = peer.screenShare!;
    return AstellMediaViewer.open(
      context,
      AstellShare(id: 'screen-${peer.peerId}', accountId: peer.accountId, handle: peer.handle, displayName: peer.displayName, kind: 'media',
          payload: {'title': sc.title.isEmpty ? '${peer.displayName} の画面' : sc.title, 'mimeType': 'video/screen', 'thumbnailUrl': sc.thumbnailUrl?.toString()}, createdAt: DateTime.now()),
      liveIdentity: peer.accountId,
      liveScreen: true,
    );
  }

  /// 画面共有の切り替え (D-317)。デスクトップは始める前に画面 / ウィンドウを選ぶ。
  Future<void> _toggleScreen(BuildContext context) async {
    final session = ref.read(astellSessionProvider.notifier);
    final s = ref.read(astellSessionProvider);
    if (s == null) return;
    String? source;
    if (!s.screenShareOn && astellNeedsScreenPicker) {
      source = await pickAstellScreenSource(context);
      if (source == null) return;
    }
    await session.toggleScreenShare(screenSourceId: source);
  }

  /// ホストの配信を始める (D-317): カメラ / 画面。
  Future<void> _startHostStream(BuildContext context, String kind) async {
    String? source;
    if (kind == 'screen' && astellNeedsScreenPicker) {
      source = await pickAstellScreenSource(context);
      if (source == null) return;
    }
    await ref.read(astellSessionProvider.notifier).startHostStream(kind, screenSourceId: source);
  }

  /// 歯車 (D-146): 共有欄の自動表示(メディアタイプ別)と読み上げ音声。
  /// 先頭に、下段の幅に入りきらないボタン([overflow] のキー、D-324)と「下段のボタンの並びを編集」。
  Future<void> _openSettings(BuildContext context, AstellSessionState s, bool isOwner, {List<AstellBarItem> overflow = const []}) async {
    final overflowKeys = {for (final i in overflow) i.key};
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
        // 下段に入りきらないボタン (D-324): バンドルは中身を並べる。押すとメニューを閉じてから動かす。
        final hidden = [
          // 動き(画面の選択 / プラグインの FOW)はルームの context で(このシートは押すと閉じる)。
          for (final i in _barItems(context, ref, ref.watch(astellSessionProvider) ?? s))
            if (overflowKeys.contains(i.key))
              ...switch (i) {
                AstellBarSingle(:final id, :final button) => [(id: id, button: button)],
                AstellBarBundle(:final members) => [for (final m in members) (id: m.action.id, button: m.button)],
              },
        ];
        return ListView(shrinkWrap: true, children: [
          if (hidden.isNotEmpty) ...[
            _label(ctx, '下段に入りきらないボタン'),
            Padding(
              key: astellOverflowKey,
              padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, RasqSpacing.xs),
              child: Wrap(spacing: RasqSpacing.xs, runSpacing: RasqSpacing.sm, children: [
                for (final h in hidden)
                  SizedBox(
                    width: 76,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      _RoundButton(
                        key: ValueKey('astell.bar.overflow.${h.id}'),
                        icon: h.button.icon,
                        tooltip: h.button.tooltip,
                        filled: h.button.filled,
                        onPressed: h.button.onPressed == null
                            ? null
                            : () {
                                ref.read(overlayManagerProvider).close('astell.room.settings');
                                h.button.onPressed!();
                              },
                      ),
                      const SizedBox(height: 2),
                      Text(h.button.tooltip, style: RasqTypography.caption.copyWith(fontSize: 10, color: scheme.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                    ]),
                  ),
              ]),
            ),
          ],
          RasqListTile(
            key: const ValueKey('astell.bar.edit'),
            title: '下段のボタンの並びを編集',
            subtitle: '並べ替え / 表示 / 非表示 / プラグインのボタンを追加',
            leading: const Icon(Icons.dashboard_customize_outlined),
            onTap: () {
              ref.read(overlayManagerProvider).close('astell.room.settings');
              showActionBarEditSheet(ref, surfaces: const [ActionBarSurface.astell], column: fowColumnOf(context));
            },
          ),
          const Divider(height: RasqSpacing.md),
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
          if (isOwner) ...[
            const Divider(height: RasqSpacing.md),
            // ホストの配信 (D-317): LiveKit に上げる。止めるまで `hostStream` が立つ。
            _label(ctx, '配信(ホスト)'),
            if (ref.watch(astellSessionProvider.select((x) => x?.screenShareOn == true ? null : x?.streaming)) case final kind? when room.hostStream != null)
              RasqListTile(
                title: '配信を止める',
                subtitle: kind == 'screen' ? '画面を配信しています' : 'カメラで配信しています',
                titleColor: RasqColors.danger,
                chevron: false,
                leading: const Icon(Icons.stop_circle_outlined, color: RasqColors.danger),
                onTap: () => ref.read(astellSessionProvider.notifier).stopHostStream(),
              )
            else ...[
              RasqListTile(title: 'カメラで配信する', leading: const Icon(Icons.videocam_outlined), chevron: false, onTap: () => _startHostStream(ctx, 'camera')),
              RasqListTile(
                title: '画面を配信する',
                subtitle: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS ? 'iPhone / iPad はこのアプリの画面だけ(ほかのアプリは映りません)' : null,
                leading: const Icon(Icons.desktop_windows_outlined),
                chevron: false,
                onTap: () => _startHostStream(ctx, 'screen'),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.xs),
              child: Text('映像とマイクを配信サーバー(LiveKit)に上げます。参加者は通話の声のまま映像を見られ、通話に入りきらない人($astellMeshCap 人目より後)は配信であなたの声を聞きます。', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
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
            child: Text(isOwner ? 'チャットと共有の読み上げは Central 側で合成します(端末での再生は今後の対応)。' : '読み上げ音声はホストが選びます。', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          ),
          const Divider(height: RasqSpacing.md),
          // 実機で「聞こえない / 映らない」を切り分ける (D-323)。
          _label(ctx, '接続の状態(開発者向け)'),
          RasqListTile(
            title: '通話 / 配信の接続を見る',
            subtitle: 'ICE の状態・候補・送受信の量・受けているトラック',
            leading: const Icon(Icons.network_check),
            onTap: () => _openDiagnostics(),
          ),
        ]);
      }),
    );
  }

  /// 接続の状態(開発者向け、D-323)。1 秒ごとに読み直す。
  Future<void> _openDiagnostics() => ref.read(overlayManagerProvider).showBottomSheet<void>(
        id: 'astell.room.diagnostics',
        title: '接続の状態',
        cancelText: '閉じる',
        builder: (_) => const _AstellDiagnosticsView(),
      );

  /// ホストの配信をタップ → 全画面(映像は LiveKit、D-317。届くまでは静止画)。
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
    return AstellMediaViewer.open(context, share, liveIdentity: room.ownerId, liveScreen: st.isScreen);
  }

  /// タイルのタップ (D-145): メディア = 全画面 / 投稿 = 対応 SNS プラグインがあればアプリ内、
  /// 無ければ Web / リンク = Web。
  Future<void> _openShare(BuildContext context, AstellShare share) async {
    switch (share.kind) {
      case 'media':
        await AstellMediaViewer.open(context, share);
      case 'post':
        // URL が自分のアカウントのインスタンスと一致すれば RASQ 内でスレッド展開、
        // そうでなければブラウザ (D-166)。
        final sessions = ref.read(sessionsProvider).value?.sessions ?? const <AccountSession>[];
        final acct = astellAccountForPost(share.payload, sessions, prefer: ref.read(currentAccountProvider));
        final post = acct == null ? null : postFromSharePayload(share.payload, acct);
        if (post != null) {
          context.pushPost(post);
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
  /// ミュート / フォロー / ブロック / 通報。ミュートは手元だけ(その人の声を鳴らさない、D-317)。
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
      _label(context, 'ホスト'),
      AstellHostRow(room: room, peers: s.peers),
      _label(context, '参加メンバー'),
      AstellMembersRow(peers: _guests(room, s.peers).$1, viewingPeerId: s.viewingPeerId, onViewScreen: (id) => ref.read(astellSessionProvider.notifier).viewScreen(s.viewingPeerId == id ? null : id)),
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
        // ほかの人の下書き (D-311): 書き始めた位置に差し込む。
        for (final d in s.drafts.values) _ChatEntry(at: d.startedAt, author: d.displayName, text: d.text, draft: true, handle: d.handle),
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
            if (e.kind != null && e.kind != 'text') Padding(padding: const EdgeInsets.only(right: RasqSpacing.xs), child: RasqPill(label: switch (e.kind) { 'post' => '投稿', 'media' => 'メディア', 'link' => 'リンク', _ => e.kind! })),
            Expanded(
              // 投稿/リンク/メディアの行はタップで開く (D-166: 投稿は一致するアカウントならアプリ内)。
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: e.id == null || e.transcript || e.kind == null || e.kind == 'text' ? null : () {
                  final sh = s.shares.where((x) => x.id == e.id).firstOrNull;
                  if (sh != null) _openShare(context, sh);
                },
                child: Text.rich(TextSpan(children: [
                TextSpan(text: '${e.author}> ', style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700, color: e.transcript ? scheme.onSurfaceVariant : null)),
                TextSpan(text: e.draft && e.text.isEmpty ? '入力中…' : e.text, style: RasqTypography.bodySmall.copyWith(color: e.draft ? scheme.onSurfaceVariant : null, fontStyle: e.draft ? FontStyle.italic : null)),
                ])),
              ),
            ),
            if (e.draft) Text(e.handle == null ? '下書き' : '入力中', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
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
      for (final (_, p) in [...s.peers.indexed]..sort((a, b) => _rank(s.room, a.$2) != _rank(s.room, b.$2) ? _rank(s.room, a.$2).compareTo(_rank(s.room, b.$2)) : a.$1.compareTo(b.$1)))
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

/// 下段バー (D-148、ユーザー指定の構造 → D-324):
/// `[入力欄の左の丸いボタン] [中央] [共有する/送信完了する] [設定]`
/// - 左端: 設定の並び(既定 = スピーカーミュート / マイクミュート / 画面共有 / (全画面: 共有枠にピアの画面がある時) /
///   プラグインアクション / 字幕、D-324)。**幅に収まる数だけ**並べ、はみ出したら先頭から入るだけと**並びの最後の 1 つ**
///   (入力欄の隣。既定では字幕)を出し、残りは歯車のメニューの先頭へ(歯車に点)。stick は 3 つまで。
/// - stick で共有枠にピアの画面がある時は、左端(並びの最後の 1 つ以外)が**映像そのもの**に置き換わり、
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
    required this.items,
    required this.itemBuilder,
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

  /// 入力欄の左の丸いボタン(設定の並び、今押せるものだけ。D-324)。
  final List<AstellBarItem> items;
  final Widget Function(AstellBarItem item) itemBuilder;
  final VoidCallback onSendText, onPickFile, onExpand, onLeave;

  /// 歯車。はみ出したボタンを先頭に出す。
  final void Function(List<AstellBarItem> overflow) onSettings;

  /// 共有枠のピアの画面を全画面に(共有枠が空なら null)。
  final VoidCallback? onFullscreen;
  final void Function(AstellShare share) onOpenShare;

  static const _button = astellBarButtonSize;
  static const _gap = astellBarGap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = state;
    final viewing = s.viewingPeer;
    // 左右の余白 + 中央の前後の間隔 + 右端のボタン(stick は退出だけ)。
    const pad = RasqSpacing.sm;
    final reserved = pad * 2 + RasqSpacing.sm * 2 + (compact ? _button : _button * 2 + _gap);

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth.isFinite ? constraints.maxWidth : MediaQuery.sizeOf(context).width;
      final split = splitAstellBar(items, astellBarSlots(width, reserved: reserved, compact: compact));

      // ── 左端 ──
      Widget row(List<Widget> children) => Row(mainAxisSize: MainAxisSize.min, children: [
            for (final (i, w) in children.indexed) ...[if (i > 0) const SizedBox(width: _gap), w],
          ]);
      final Widget left;
      if (compact && viewing != null) {
        // stick + 共有枠にピアの画面: ボタン群の代わりに映像(タップで全画面)。並びの最後の 1 つ(入力欄の隣)は残す。
        left = row([
          _StickScreen(key: astellStickScreenKey, peer: viewing, muted: s.isMuted(viewing.peerId) || s.speakerMuted, onTap: onFullscreen),
          if (items.isNotEmpty) itemBuilder(items.last),
        ]);
      } else {
        left = SizedBox(key: astellFooterActionsKey, height: _button, child: row([for (final i in split.shown) itemBuilder(i)]));
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
        padding: EdgeInsets.fromLTRB(pad, compact ? 2 : RasqSpacing.xs, pad, compact ? RasqSpacing.xs : RasqSpacing.sm),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          left,
          const SizedBox(width: RasqSpacing.sm),
          Expanded(child: middle),
          const SizedBox(width: RasqSpacing.sm),
          // ── 右端 ──
          if (compact)
            _RoundButton(icon: Icons.close, tooltip: '退出', onPressed: onLeave)
          else ...[
            _RoundButton(icon: drafting ? Icons.send : Icons.upload, tooltip: drafting ? '送信完了する' : '共有する', filled: scheme.onSurface, onPressed: drafting ? onSendText : onPickFile),
            const SizedBox(width: _gap),
            // はみ出したボタンがあれば歯車に点(押すと先頭に出る)。
            Stack(clipBehavior: Clip.none, children: [
              _RoundButton(icon: Icons.settings, tooltip: '設定', onPressed: () => onSettings(split.overflow)),
              if (split.overflow.isNotEmpty)
                Positioned(
                  right: 2,
                  top: 2,
                  child: IgnorePointer(child: Container(key: astellOverflowDotKey, width: 9, height: 9, decoration: BoxDecoration(color: RasqColors.accent, shape: BoxShape.circle, border: Border.all(color: scheme.surface, width: 1.5)))),
                ),
            ]),
          ],
        ]),
      );
    });
  }
}

/// stick の左端 (D-148): 共有枠にあるピアの画面の映像(LiveKit、D-317。届くまではサムネイル)。タップで全画面。
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
            AstellLiveVideo(
              identity: peer.accountId,
              screen: true,
              fit: BoxFit.cover,
              fallback: sc.thumbnailUrl != null
                  ? Image.network(webHtmlElementStrategy: rasqWebImageStrategy, sc.thumbnailUrl.toString(), fit: BoxFit.cover, errorBuilder: (_, _, _) => Icon(Icons.desktop_windows, size: 18, color: scheme.onSurfaceVariant))
                  : Icon(Icons.desktop_windows, size: 18, color: scheme.onSurfaceVariant),
            ),
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
                  Image.network(webHtmlElementStrategy: rasqWebImageStrategy, thumb.toString(), fit: BoxFit.cover, errorBuilder: (_, _, _) => ColoredBox(color: scheme.surfaceContainerHighest, child: Icon(Icons.movie_outlined, size: 18, color: scheme.onSurfaceVariant))),
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
              Image.network(webHtmlElementStrategy: rasqWebImageStrategy, sh.thumbnailUrl.toString(), fit: BoxFit.cover, errorBuilder: (_, _, _) => ColoredBox(color: scheme.surfaceContainerHighest)),
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
            // 映像は LiveKit (D-317)。届くまではサムネイル。
            ColoredBox(
              color: Colors.black,
              child: AstellLiveVideo(
                identity: peer.accountId,
                screen: true,
                fallback: sc.thumbnailUrl != null
                    ? Image.network(webHtmlElementStrategy: rasqWebImageStrategy, sc.thumbnailUrl.toString(), fit: BoxFit.cover, errorBuilder: (_, _, _) => ColoredBox(color: scheme.surfaceContainerHighest))
                    : ColoredBox(color: scheme.surfaceContainerHighest),
              ),
            ),
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

/// ルームタブの並び: ホスト → モデレーター → ほか(同じ順位の中は入った順のまま。Dart の sort は安定でないので、元の位置で比べる)。
int _rank(AstellRoom room, AstellPeer p) => p.accountId == room.ownerId ? 0 : (room.moderators.contains(p.accountId) ? 1 : 2);

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
          // 話している間 (D-317) は緑の波形。
          badge: _StateBadge(icon: p.speaking && !p.mutedByMod ? Icons.graphic_eq : (p.micOn ? Icons.mic : Icons.mic_off), color: p.mutedByMod ? RasqColors.danger : (p.speaking ? astellSpeakingColor : (p.micOn ? RasqColors.accent : scheme.outline))),
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
                    ? Image.network(webHtmlElementStrategy: rasqWebImageStrategy, p.screenShare!.thumbnailUrl.toString(), fit: BoxFit.cover, errorBuilder: (_, _, _) => Icon(Icons.desktop_windows, size: 18, color: scheme.onSurfaceVariant))
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
/// 通話 / 配信の接続の様子 (D-323)。[AstellSession.diagnostics] を 1 秒ごとに読み直して出す。コピーできる。
class _AstellDiagnosticsView extends ConsumerStatefulWidget {
  const _AstellDiagnosticsView();
  @override
  ConsumerState<_AstellDiagnosticsView> createState() => _AstellDiagnosticsViewState();
}

class _AstellDiagnosticsViewState extends ConsumerState<_AstellDiagnosticsView> {
  List<String> _lines = const [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }

  Future<void> _refresh() async {
    final lines = await ref.read(astellSessionProvider.notifier).diagnostics();
    if (mounted) setState(() => _lines = lines);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = _lines.join('\n');
    return ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.page), children: [
      SelectableText(text, style: RasqTypography.caption.copyWith(fontFamily: 'monospace', color: scheme.onSurface)),
      const SizedBox(height: RasqSpacing.sm),
      Row(children: [
        Expanded(
          child: Text('ブラウザ / Xcode のログにも「astell call:」「astell stream:」で出ます。', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
        ),
        TextButton.icon(
          icon: const Icon(Icons.copy, size: 16),
          label: const Text('コピー'),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: text));
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('コピーしました')));
          },
        ),
      ]),
    ]);
  }
}

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
  const _HostStreamPanel({required this.stream, required this.ownerId, required this.onTap});
  final AstellHostStream stream;

  /// ホスト(LiveKit の identity)。
  final String ownerId;
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
              // 映像は LiveKit (D-317)。届くまではサムネイル + ▶。
              ColoredBox(
                color: Colors.black,
                child: AstellLiveVideo(
                  identity: ownerId,
                  screen: stream.isScreen,
                  fallback: Stack(fit: StackFit.expand, children: [
                    if (stream.thumbnailUrl != null)
                      Image.network(webHtmlElementStrategy: rasqWebImageStrategy, stream.thumbnailUrl.toString(), fit: BoxFit.cover, errorBuilder: (_, _, _) => ColoredBox(color: scheme.surfaceContainerHighest))
                    else
                      ColoredBox(color: scheme.surfaceContainerHighest),
                    const Center(child: Icon(Icons.play_circle_fill, size: 40, color: Colors.white70)),
                  ]),
                ),
              ),
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
              Image.network(webHtmlElementStrategy: rasqWebImageStrategy, stream.thumbnailUrl.toString(), fit: BoxFit.cover, errorBuilder: (_, _, _) => ColoredBox(color: scheme.surfaceContainerHighest))
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
  // ヘッダーの共有アイコン (D-159): オンなら作成後に投稿コンポーザーへリンクを転送。
  final shareAfter = ValueNotifier<bool>(false);
  await manager.showFow<void>(
    id: astellCreateFowId,
    spec: _spec(
      title: 'VC を作成',
      cancelText: 'キャンセル',
      height: 0.7,
      trailing: ValueListenableBuilder<bool>(
        valueListenable: shareAfter,
        builder: (ctx, on, _) => RasqIconButton(
          key: const ValueKey('astell.create.share'),
          icon: Icons.ios_share,
          size: 20,
          color: on ? RasqColors.accent : null,
          tooltip: on ? '作成後に投稿で共有する(オン)' : '作成後に投稿で共有する',
          onPressed: () => shareAfter.value = !on,
        ),
      ),
    ),
    barrierBehavior: OverlayBarrierBehavior.dismissDiscard,
    builder: (ctx, handle) => _CreateBody(onCreated: (room) async {
      handle.close();
      ref.invalidate(astellHomeProvider);
      if (shareAfter.value && context.mounted) await shareAstellRoom(context, ref, room);
      if (!context.mounted) return;
      if (room.isScheduled) {
        // 予約 (D-159): オーナーが接続すると開催になるので、今は入らない。
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('「${room.title}」を ${formatAstellSchedule(room.scheduledAt!)} に予約しました')));
        return;
      }
      await ref.read(astellSessionProvider.notifier).join(room);
      if (context.mounted) await openAstellRoomFow(context, ref);
    }),
  );
  shareAfter.dispose();
}

/// ヘッダーのブックマーク (D-160): 保存済みなら塗り。
class AstellBookmarkButton extends ConsumerWidget {
  const AstellBookmarkButton({super.key, required this.room});
  final AstellRoom room;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(astellBookmarkedProvider(room.id));
    return RasqIconButton(icon: on ? Icons.bookmark : Icons.bookmark_border, size: 20, color: on ? RasqColors.accent : null, tooltip: on ? 'ブックマークから削除' : 'ブックマークに保存', onPressed: () => bookmarkAstellRoom(context, ref, room));
  }
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
  final _genreInput = TextEditingController();
  bool _welcomeOn = false;
  bool _showSummary = true;
  bool _autoGenre = true;
  bool _busy = false;

  /// 開催予約 (D-159)。null = 作成即開催。
  DateTime? _scheduledAt;

  /// 手動のジャンル (D-159): 自動選択オフのときに選定。
  final List<String> _genres = [];

  @override
  void dispose() {
    _title.dispose();
    _welcome.dispose();
    _description.dispose();
    _genreInput.dispose();
    super.dispose();
  }

  /// 予約時刻の日付/時刻を選ぶ。既定は 1 時間後(15 分刻み)。
  Future<void> _pickSchedule({bool date = true}) async {
    final now = DateTime.now();
    final base = _scheduledAt ?? DateTime(now.year, now.month, now.day, now.hour + 1, (now.minute ~/ 15) * 15);
    DateTime next = base;
    if (date) {
      final d = await showDatePicker(context: context, initialDate: base.isBefore(now) ? now : base, firstDate: now, lastDate: now.add(const Duration(days: 90)));
      if (d == null) return;
      next = DateTime(d.year, d.month, d.day, base.hour, base.minute);
    } else {
      final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: base.hour, minute: base.minute));
      if (t == null) return;
      next = DateTime(base.year, base.month, base.day, t.hour, t.minute);
    }
    if (!mounted) return;
    if (!next.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('開催予定は今より後にしてください')));
      return;
    }
    setState(() => _scheduledAt = next);
  }

  void _addGenre(String raw) {
    final g = raw.trim().replaceFirst(RegExp(r'^#'), '');
    if (g.isEmpty || g.length > 30) return;
    if (_genres.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ジャンルは 10 個までです')));
      return;
    }
    setState(() {
      if (!_genres.contains(g)) _genres.add(g);
      _genreInput.clear();
    });
  }

  Future<void> _create() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('タイトルを入力してください')));
      return;
    }
    setState(() => _busy = true);
    try {
      if (_scheduledAt != null && !_scheduledAt!.isAfter(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('開催予定は今より後にしてください')));
        setState(() => _busy = false);
        return;
      }
      final room = await ref.read(astellClientProvider).createRoom(NewAstellRoom(
            title: title,
            description: _description.text.trim(),
            genres: _autoGenre ? const [] : List.of(_genres),
            welcomeMessage: _welcomeOn && _welcome.text.trim().isNotEmpty ? _welcome.text.trim() : null,
            showSummary: _showSummary,
            autoGenre: _autoGenre,
            scheduledAt: _scheduledAt,
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
        child: ListView(key: astellCreateFormKey, padding: EdgeInsets.zero, children: [
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
          // ジャンル選定 (D-159): 自動選択オフのとき、手入力 + 好きなジャンルからの候補。
          if (!_autoGenre) ...[
            _label(context, 'ジャンルを選定(最大 10)'),
            Padding(
              padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.xs),
              child: Row(children: [
                Expanded(child: RasqInput(key: const ValueKey('astell.create.genre.input'), controller: _genreInput, hintText: 'ジャンルを入力', onSubmitted: _addGenre)),
                const SizedBox(width: RasqSpacing.xs),
                RasqIconButton(icon: Icons.add, tooltip: 'ジャンルを追加', onPressed: () => _addGenre(_genreInput.text)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.xs),
              child: Wrap(spacing: RasqSpacing.xs, runSpacing: RasqSpacing.xs, children: [
                for (final g in _genres) RasqTogglePillButton(label: '#$g ✕', activeLabel: '#$g ✕', active: true, onPressed: () => setState(() => _genres.remove(g))),
                // 候補: トレンドプロファイルの好きなジャンル (D-153)。
                for (final g in ref.watch(tendencyProfileProvider).value?.genres ?? const <String>[])
                  if (!_genres.contains(g)) RasqTogglePillButton(label: '+ #$g', activeLabel: '+ #$g', active: false, onPressed: () => _addGenre(g)),
              ]),
            ),
          ],
          const Divider(height: 1),
          // 開催予約 (D-159): オンで日付/時刻。予約中はオーナーが入るまで他の人は参加できない。
          RasqSwitchListTile(
            title: '開催を予約する',
            value: _scheduledAt != null,
            onChanged: (v) {
              if (!v) {
                setState(() => _scheduledAt = null);
                return;
              }
              final now = DateTime.now();
              setState(() => _scheduledAt = DateTime(now.year, now.month, now.day, now.hour + 1, (now.minute ~/ 15) * 15));
            },
          ),
          if (_scheduledAt != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.xs),
              child: Row(children: [
                Expanded(child: OutlinedButton.icon(key: const ValueKey('astell.create.date'), onPressed: () => _pickSchedule(date: true), icon: const Icon(Icons.calendar_today, size: 16), label: Text('${_scheduledAt!.year}/${_scheduledAt!.month}/${_scheduledAt!.day}'))),
                const SizedBox(width: RasqSpacing.xs),
                Expanded(child: OutlinedButton.icon(key: const ValueKey('astell.create.time'), onPressed: () => _pickSchedule(date: false), icon: const Icon(Icons.schedule, size: 16), label: Text(formatAstellSchedule(_scheduledAt!).split(' ').last))),
              ]),
            ),
          if (_scheduledAt != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.xs),
              child: Text('予約中はあなた(とモデレーター)が入るまで他の人は参加できません。近日開催の節と共有リンクから開始通知を登録できます。', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
            ),
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
          Expanded(child: RasqGradientButton(label: _scheduledAt != null ? '予約' : '作成', onPressed: _busy ? null : _create, enabled: !_busy)),
          const SizedBox(width: RasqSpacing.sm),
          _RoundButton(icon: Icons.settings, tooltip: '設定', onPressed: () => _notYet(context, 'VC の設定')),
        ]),
      ),
    ]);
  }
}
