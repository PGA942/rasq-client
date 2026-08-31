import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../shell/app_overlay_root.dart';
import '../../text/inline_spans.dart';
import 'compose_providers.dart';
import 'compose_target.dart';
import 'emoji_picker_fow.dart';
import 'mfm_picker_fow.dart';
import 'poll_editor.dart';

/// Opens the composer as an interstitial FOW (docked, resizable). Child FOWs
/// (絵文字ピッカー) are owned by it and closed with it.
/// Resolves with the created post, or null on cancel.
const composerFowId = 'fow.composer';

/// [resident] (D-050): スレッド/DM ページ下部の**常駐 stick** — ページを開くと
/// 縮小状態で置かれ、送信しても閉じずに(下書きをリセットして)残る。✕ は
/// 折りたたみ。消えるのはページ遷移のときだけ。[onPosted] は送信毎に呼ばれる
/// (スレッド/ルームの再読込用)。
Future<Post?> showComposer(WidgetRef ref, ComposeTarget target, {bool resident = false, ValueChanged<Post>? onPosted, int column = 0}) async {
  final manager = ref.read(overlayManagerProvider);
  // 返信 / ダイレクト投稿は **stick FOW** (D-047): ヘッダー無しで根本が
  // フッターメニュー/キーボードの上に貼り付き、タップ(フォーカス)すると
  // ヘッダーと返信先タイルが上から割り込んでくる(書き込み領域とアクション
  // バーはシームレスなまま)。通常/引用は従来のインタースティシャル。
  final stick = target is ComposeReply || target is ComposeDm;
  final spec = stick
      ? FowSpec(
          type: FowPanelType.widget,
          confirmMode: FowConfirmMode.stick,
          initialHeightFactor: _ComposerBodyState.stickCollapsedFactor,
          minHeightFactor: 0.10,
          maxHeightFactor: 0.8,
          dockAboveFooter: true,
          columnIndex: column,
          // 高さの段階 (D-049): 折りたたみ/全部ピッタリの 2 段(実測が入ると
          // 本体が差し替える)。最上段より上はシームレス、最下段で止まる。
          heightStops: const [_ComposerBodyState.stickCollapsedFactor, _ComposerBodyState.stickExpandedFactor],
          freeAboveStops: true,
        )
      : FowSpec(
          // 同手法化 (D-051): 通常/引用も stick と同じ角丸枠 + パネル内
          // ヘッダー + フッター上ドック + ピッタリ高さ段階。ただしこちらは
          // インタースティシャル(スクリムあり)で、**余白クリックで自動的に
          // 下書きへ入って消失**する(ポップアップは出ない)。
          type: FowPanelType.interstitial,
          confirmMode: FowConfirmMode.saveDiscard,
          initialHeightFactor: 0.45,
          minHeightFactor: 0.2,
          maxHeightFactor: 0.9,
          dockAboveFooter: true,
          columnIndex: column,
          heightStops: const [0.45],
          freeAboveStops: true,
        );
  // stick は特定の返信/DM ページに張り付くもの (D-048): ページ遷移(戻る・
  // タブ切替・別投稿へ移動)を検知したら自動で消滅する。
  final router = stick ? ref.read(routerProvider) : null;
  void onNavigate() => manager.close(composerFowId, reason: OverlayCloseReason.discard);
  router?.routerDelegate.addListener(onNavigate);
  try {
    final res = await manager.showFow<Post>(
      id: composerFowId,
      spec: spec,
      builder: (ctx, handle) => _ComposerBody(
        target: target,
        spec: spec,
        resident: resident,
        // 常駐は送信で閉じない(本体が下書きをリセットして残る)。
        onSent: resident ? (p) => onPosted?.call(p) : (p) => handle.close(result: p),
        onClose: () => handle.close(),
      ),
    );
    return res;
  } finally {
    router?.routerDelegate.removeListener(onNavigate);
    manager.closeOwnedBy(composerFowId);
  }
}

/// FOW ヘッダー右側のコントロール群 (D-045)。状態は [composeOptionsProvider]
/// (本文側と共有、アプリ起動中は前回値を記憶)。
class ComposerHeaderControls extends ConsumerWidget {
  const ComposerHeaderControls({super.key});

  Rect _anchorOf(BuildContext ctx) {
    final box = ctx.findRenderObject() as RenderBox;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opts = ref.watch(composeOptionsProvider);
    final store = ref.read(composeOptionsProvider.notifier);
    final manager = ref.read(overlayManagerProvider);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Builder(builder: (ctx) {
          final (icon, label) = switch (opts.visibility) {
            'home' => (Icons.home_outlined, 'ホーム'),
            'followers' => (Icons.lock_outline, 'フォロワー'),
            _ => (Icons.public, 'パブリック'),
          };
          return RasqActionButton.icon(
            icon: icon,
            tooltip: '公開範囲: $label',
            onTap: () async {
              final picked = await manager.showDropdown<String>(id: 'composer.visibility', ownerId: composerFowId, anchor: _anchorOf(ctx), dense: true, items: const [
                RasqDropdownItem('パブリック', 'public'),
                RasqDropdownItem('ホーム', 'home'),
                RasqDropdownItem('フォロワー', 'followers'),
              ]);
              if (picked != null) store.setVisibility(picked);
            },
          );
        }),
      RasqActionButton.icon(
        icon: Icons.rocket_launch_outlined,
        doneIcon: Icons.public_off,
        done: opts.localOnly,
        tooltip: opts.localOnly ? '連合なし(このサーバーのみ)' : '連合あり(タップで連合なしに)',
        onTap: () => store.setLocalOnly(!opts.localOnly),
      ),
      Builder(builder: (ctx) {
        return RasqActionButton.icon(
          icon: Icons.add_reaction_outlined,
          doneIcon: Icons.add_reaction,
          done: opts.reactionAcceptance != null,
          tooltip: 'リアクションの受け入れ: ${reactionAcceptanceLabels[opts.reactionAcceptance]}',
          onTap: () async {
            final picked = await manager.showDropdown<(String?,)>(id: 'composer.reaction', ownerId: composerFowId, anchor: _anchorOf(ctx), dense: true, items: [
              for (final e in reactionAcceptanceLabels.entries) RasqDropdownItem(e.value, (e.key,)),
            ]);
            if (picked != null) store.setReactionAcceptance(picked.$1);
          },
        );
      }),
      const SizedBox(width: 4),
    ]);
  }
}

class _Attachment {
  _Attachment({required this.bytes, required this.name, this.mimeType});
  final Uint8List bytes;
  final String name;
  final String? mimeType;
  bool sensitive = false;
  MediaItem? uploaded;
}

class _ComposerBody extends ConsumerStatefulWidget {
  const _ComposerBody({required this.target, required this.onSent, this.spec, this.onClose, this.resident = false});
  final ComposeTarget target;
  final ValueChanged<Post> onSent;

  /// stick モード (D-047) の高さ調整用(展開/折りたたみで heightFactor を動かす)。
  final FowSpec? spec;
  final VoidCallback? onClose;

  /// ページ常駐 stick (D-050): 縮小状態で開き、送信後も閉じずに残る。
  final bool resident;
  @override
  ConsumerState<_ComposerBody> createState() => _ComposerBodyState();
}

class _ComposerBodyState extends ConsumerState<_ComposerBody> {
  final _text = TextEditingController();
  final _cw = TextEditingController();
  final _focus = FocusNode();
  bool _cwOn = false;
  PollDraft? _poll;
  final List<_Attachment> _files = [];
  bool _busy = false;
  String? _error;
  String? _progress;

  // stick FOW (D-047/D-049) の高さ: 折りたたみ = 入力行 + ツールバーだけ、
  // 展開 = ヘッダー + 返信先タイルが割り込む。定数は実測が入るまでの初期値で、
  // レイアウト後に「全部をピッタリ表示できる」段階を計算して差し替える。
  static const stickCollapsedFactor = 0.15;
  static const stickExpandedFactor = 0.44;

  Post? get _replyTo => switch (widget.target) { ComposeReply(to: final p) => p, _ => null };
  Post? get _quoteOf => switch (widget.target) { ComposeQuote(of: final p) => p, _ => null };

  /// ダイレクト投稿への返信 = 公開範囲をダイレクト(specified)に固定 (D-047)。
  bool get _directReply => _replyTo?.isDirect ?? false;

  /// 縮小状態を持つのはページ常駐 stick だけ (D-051: 通常/引用は常に展開)。
  bool get _collapsible => widget.resident;

  bool get _stickExpanded => _focus.hasFocus || _text.text.trim().isNotEmpty || _files.isNotEmpty || _poll != null || _cwOn;

  /// ヘッダー(キャンセル/タイトル/下書き)と対象タイルを見せるか。
  bool get _expandedView => !_collapsible || _stickExpanded;

  /// ヘッダー中央のタイトル (D-052: 「投稿/返信」)。
  String get _headerTitle => switch (widget.target) {
        ComposeNormal() => '投稿',
        ComposeReply() => '返信',
        ComposeQuote() => '引用',
        ComposeDm() => '→ ${widget.target.title}',
      };

  /// 下書きに保存できる内容があるか(D-052 の「下書き」ボタン)。
  bool get _canDraft => _text.text.trim().isNotEmpty || _cw.text.trim().isNotEmpty;

  void _saveAsDraftAndClose() {
    _saveDraft();
    _skipDraftOnDispose = true;
    widget.onClose?.call();
  }

  // ---- 高さ段階の実測 (D-049) ------------------------------------------
  final _stickContentKey = GlobalKey();
  final _stickToolbarKey = GlobalKey();
  // 割り込みヘッダー: AnimatedSize(アニメ中の見かけの高さ)と中身
  // (自然な高さ)。fit = content − 見かけ + 自然、でアニメ非依存に測れる。
  final _stickHeaderAnimKey = GlobalKey();
  final _stickHeaderInnerKey = GlobalKey();
  bool? _wasExpanded;
  double? _fitCollapsed;
  double? _fitExpanded;

  void _syncStickHeight() {
    if (!mounted) return;
    setState(() {});
  }

  /// FOW 内ヘッダー/フッターを「掴んで左右カラム間移動」のグリップにする
  /// (D-062。ハンドルは縦リサイズ専用の役割分担)。
  Widget _grip(Widget child) => widget.spec == null ? child : FowMoveGrip(spec: widget.spec!, child: child);

  /// 子 FOW(絵文字/MFM ピッカー)はコンポーザーと同じカラムに開く。
  int get _column => widget.spec?.columnIndex ?? 0;

  /// build 毎に呼ぶ(冪等)。レイアウト後に「全部をピッタリ表示できる」
  /// 高さを実測し、高さ段階(heightStops)と現在高さへ反映する。
  void _scheduleStickFit() {
    final spec = widget.spec;
    if (spec == null) return;
    if (_wasExpanded != _expandedView) {
      _wasExpanded = _expandedView;
      spec.userResized = false; // 段階が変わったら自動フィットを再開
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureStickFit());
  }

  void _measureStickFit() {
    if (!mounted) return;
    final spec = widget.spec;
    if (spec == null) return;
    final content = _stickContentKey.currentContext?.size?.height;
    final toolbar = _stickToolbarKey.currentContext?.size?.height;
    if (content == null || toolbar == null) return;
    final headerAnim = _stickHeaderAnimKey.currentContext?.size?.height ?? 0;
    final headerInner = _stickHeaderInnerKey.currentContext?.size?.height ?? 0;
    // パネルが実際に使える高さ = ホスト − キーボード(無ければフッタードック)。
    final mq = MediaQuery.of(context);
    final avail = mq.size.height - (mq.viewInsets.bottom > 0 ? mq.viewInsets.bottom : fowDockInsetOf(context, ref.read(routerProvider)));
    if (avail <= 0) return;
    // 内訳: コンテンツ(割り込みヘッダーはアニメ後の自然高さに補正)+
    // ツールバー + ハンドル 18 + スクロール上パディング + 予備。
    final px = (content - headerAnim + headerInner) + toolbar + 18 + RasqSpacing.sm + 2;
    final fit = (px / avail).clamp(spec.minHeightFactor, spec.maxHeightFactor).toDouble();
    if (_expandedView) {
      _fitExpanded = fit;
    } else {
      _fitCollapsed = fit;
    }
    // 縮小状態を持たない通常/引用は「ピッタリ」1 段だけ (D-051)。
    final lo = _collapsible ? (_fitCollapsed ?? stickCollapsedFactor) : fit;
    final hi = math.max(lo, _fitExpanded ?? stickExpandedFactor);
    spec.heightStops = (hi - lo).abs() < 0.005 ? [lo] : [lo, hi];
    // 全部をピッタリ表示: ユーザーがハンドルで調整していない限り、現在段階の
    // フィット高さへ追従する(はみ出す分はスクロールで読めるので強制しない)。
    if (!spec.userResized && (spec.heightFactor.value - fit).abs() > 0.005) {
      spec.heightFactor.value = fit;
    }
  }

  // 返信の下書きプリセット。常駐 stick (D-050) では縮小状態を保つため、
  // 最初のフォーカスまで適用を遅らせる(送信後も次の返信用に再アーム)。
  String? _mentionPrefill;
  String? _cwPrefill;
  bool _prefillPending = false;

  /// 下書き (D-051): 閉じるときに保存済みなら復元する。
  /// (notifier は dispose 中に ref が使えないためフィールドに保持する。)
  String get _draftKey => draftKeyOf(widget.target);
  bool _skipDraftOnDispose = false;
  late final ComposeDraftsStore _drafts;

  @override
  void initState() {
    super.initState();
    _drafts = ref.read(composeDraftsProvider.notifier);
    _focus.addListener(_onFocusChanged);
    final t = widget.target;
    if (t is ComposeReply) {
      final a = t.to.author;
      final me = ref.read(currentAccountProvider);
      final mention = a.account.instance == me?.instance ? '@${a.handle}' : '@${a.handle}@${a.account.instance}';
      _mentionPrefill = '$mention ';
      final cw = t.to.contentWarning;
      _cwPrefill = (cw != null && cw.isNotEmpty) ? cw : null;
      if (widget.resident) {
        _prefillPending = true;
      } else {
        _applyPrefill();
      }
    }
    // 保存済み下書きの復元(プリセットより優先)。
    final d = ref.read(composeDraftsProvider)[_draftKey];
    if (d != null) {
      _text.text = d.text;
      _text.selection = TextSelection.collapsed(offset: _text.text.length);
      _cwOn = d.cwOn;
      _cw.text = d.cw;
      _prefillPending = false;
    }
  }

  void _applyPrefill() {
    if (_mentionPrefill != null && _text.text.isEmpty) {
      _text.text = _mentionPrefill!;
      _text.selection = TextSelection.collapsed(offset: _text.text.length);
    }
    if (_cwPrefill != null) {
      _cwOn = true;
      _cw.text = _cwPrefill!;
    }
    _prefillPending = false;
  }

  void _onFocusChanged() {
    if (_focus.hasFocus && _prefillPending) _applyPrefill();
    _syncStickHeight();
  }

  /// 意味のある入力があるか(自動入力のメンション/CW だけなら「無し」扱い)。
  bool get _hasDraftContent {
    final t = _text.text.trim();
    final mentionOnly = t.isEmpty || t == (_mentionPrefill?.trim() ?? '');
    final cwCustom = _cwOn && _cw.text.trim().isNotEmpty && _cw.text.trim() != (_cwPrefill ?? '');
    return !mentionOnly || _files.isNotEmpty || _poll != null || cwCustom;
  }

  void _saveDraft() {
    if (_text.text.trim().isEmpty && _cw.text.trim().isEmpty) return; // テキストの無い下書きは残さない
    _drafts.save(_draftKey, ComposeDraft(text: _text.text, cw: _cw.text, cwOn: _cwOn));
  }

  /// ✕ / 余白クリック等での閉じ方 (D-051):
  /// - 常駐 stick: 自動入力のメンションだけなら黙って閉じる。入力がある場合は
  ///   「下書きに保存 / 破棄」をポップアップで確認してから閉じる。
  /// - 通常/引用: 確認なしで閉じる(dispose で自動的に下書きへ入る)。
  Future<void> _handleClose() async {
    if (!widget.resident || !_hasDraftContent) {
      if (!_hasDraftContent) _skipDraftOnDispose = true; // メンションだけなら下書きも残さない
      widget.onClose?.call();
      return;
    }
    final manager = ref.read(overlayManagerProvider);
    final action = await manager.showBottomSheet<String>(
      id: 'composer.close',
      title: '書きかけの投稿があります',
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        RasqListTile(title: '下書きに保存して閉じる', onTap: () => manager.close('composer.close', result: 'save')),
        RasqDestructiveListTile(title: '破棄して閉じる', onTap: () => manager.close('composer.close', result: 'discard')),
      ]),
    );
    if (!mounted || action == null) return;
    if (action == 'save') _saveDraft();
    _skipDraftOnDispose = true; // 保存済み or 破棄 — dispose では触らない
    widget.onClose?.call();
  }

  @override
  void dispose() {
    // 余白クリック/ページ遷移などで閉じたときの自動下書き (D-051)。
    // unmount 中は provider を変更できないためマイクロタスクへ遅延する。
    if (!_skipDraftOnDispose && _hasDraftContent && (_text.text.trim().isNotEmpty || _cw.text.trim().isNotEmpty)) {
      final drafts = _drafts;
      final key = _draftKey;
      final d = ComposeDraft(text: _text.text, cw: _cw.text, cwOn: _cwOn);
      Future.microtask(() {
        try {
          drafts.save(key, d);
        } catch (_) {/* アプリ終了などで store ごと破棄済みなら諦める */}
      });
    }
    _focus.removeListener(_onFocusChanged);
    _text.dispose();
    _cw.dispose();
    _focus.dispose();
    _poll?.dispose();
    super.dispose();
  }

  /// 常駐 stick (D-050): 送信後に下書きをリセットして縮小状態へ戻る。
  void _resetDraft() {
    _text.clear();
    _cw.clear();
    _cwOn = false;
    _files.clear();
    _poll?.dispose();
    _poll = null;
    _error = null;
    if (widget.target is ComposeReply) _prefillPending = true; // 次の返信用に再アーム
    _focus.unfocus();
  }

  /// 選択範囲を [prefix]…[suffix] で包む。カーソルは中身部分(サフィックス
  /// 直前)へ — MFM 挿入後にそのまま本文を打てる (D-045)。
  void _wrapSelection(String prefix, String suffix) {
    final v = _text.value;
    final sel = v.selection.isValid ? v.selection : TextSelection.collapsed(offset: v.text.length);
    final selected = v.text.substring(sel.start, sel.end);
    final next = v.text.replaceRange(sel.start, sel.end, '$prefix$selected$suffix');
    _text.value = TextEditingValue(text: next, selection: TextSelection.collapsed(offset: sel.start + prefix.length + selected.length));
    setState(() {});
  }

  /// 投稿先アカウント (D-089): アカウントバンドルタイルで選ぶ。null は
  /// 現在アカウント。通常投稿(ComposeNormal)のみ — 返信/引用/DM は対象の
  /// 投稿が属するアカウント文脈に固定する。
  AccountSession? _postAs;
  bool _targetsOpen = false;

  SnsSession? get _session {
    final t = _postAs;
    if (t != null) return ref.read(pluginRegistryProvider).session(t);
    return ref.read(currentSnsSessionProvider);
  }

  /// 投稿先のカスタマイズ (D-089/D-090): ノードプログラミング画面
  /// (チャイルドセーフティーや投稿内容による投稿アカウントのソートを組む口)。
  void _openTargetCustomize() => ref.read(routerProvider).push(Routes.nodes('composer'));

  /// アカウントバンドルタイル (D-089): RASQ アカウントの顔 + ^ で投稿先
  /// リストの開閉。サイドバー(D-087)と同じ作法(バンドル=素の @handle、
  /// 個別=handle@instance)。
  Widget _bundleTile(ColorScheme scheme, RasqTokens tokens) {
    final rasq = ref.watch(rasqAccountProvider);
    final sessions = ref.watch(sessionsProvider).value?.sessions ?? const <AccountSession>[];
    final selectedKey = (_postAs ?? ref.watch(currentAccountSessionProvider))?.account.key;
    return Container(
      margin: const EdgeInsets.only(bottom: RasqSpacing.sm),
      decoration: BoxDecoration(border: Border.all(color: scheme.outlineVariant), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _targetsOpen = !_targetsOpen),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.md, vertical: 6),
            child: Row(children: [
              RasqAvatar(imageUrl: rasq.avatarUrl, size: RasqSizes.avatarSm, fallbackLabel: rasq.displayName),
              const SizedBox(width: RasqSpacing.sm),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(rasq.displayName, style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                  Text('@${rasq.account.handle}', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant), overflow: TextOverflow.ellipsis),
                ]),
              ),
              Icon(_targetsOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 20),
            ]),
          ),
        ),
        if (_targetsOpen) ...[
          for (final s in sessions)
            InkWell(
              onTap: () => setState(() {
                _postAs = s;
                _targetsOpen = false;
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.md, vertical: 6),
                child: Row(children: [
                  RasqSnsPill(account: s.account, showLabel: false, dotSize: 14),
                  const SizedBox(width: RasqSpacing.sm),
                  Expanded(child: Text('${s.account}', style: RasqTypography.bodySmall.copyWith(fontWeight: s.account.key == selectedKey ? FontWeight.w700 : null), overflow: TextOverflow.ellipsis)),
                  if (s.account.key == selectedKey) Icon(Icons.check, size: 16, color: tokens.link),
                ]),
              ),
            ),
          InkWell(
            // 投稿先のカスタマイズ(ノードプログラミング)。チャイルド
            // セーフティーや投稿内容による投稿アカウントのソートを組む口。
            onTap: _openTargetCustomize,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.md, vertical: 8),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.settings, size: 16, color: tokens.link),
                const SizedBox(width: 6),
                Text('投稿先のカスタマイズ', style: RasqTypography.bodySmall.copyWith(color: tokens.link)),
              ]),
            ),
          ),
        ],
      ]),
    );
  }

  bool get _isDm => widget.target is ComposeDm;
  int get _max => _session?.maxPostLength ?? 500;

  void _insert(String s) {
    final v = _text.value;
    final sel = v.selection.isValid ? v.selection : TextSelection.collapsed(offset: v.text.length);
    final next = v.text.replaceRange(sel.start, sel.end, s);
    _text.value = TextEditingValue(text: next, selection: TextSelection.collapsed(offset: sel.start + s.length));
    setState(() {});
  }

  Future<void> _pick({bool camera = false}) async {
    final picker = ImagePicker();
    try {
      final files = camera ? [await picker.pickImage(source: ImageSource.camera)].whereType<XFile>().toList() : await picker.pickMultiImage();
      for (final f in files.take(4 - _files.length)) {
        _files.add(_Attachment(bytes: await f.readAsBytes(), name: f.name, mimeType: f.mimeType));
      }
      setState(() {});
    } catch (e) {
      if (camera) return _pick();
      setState(() => _error = '画像を選択できませんでした: $e');
    }
  }

  bool get _canSend {
    if (_busy || _session == null) return false;
    final hasText = _text.text.trim().isNotEmpty;
    final hasMedia = _files.isNotEmpty;
    final pollOk = _poll == null || _poll!.isValid;
    if (_poll != null && !_poll!.isValid) return false;
    if (_text.text.length > _max) return false;
    return (hasText || hasMedia || (_poll != null && pollOk)) && !(_isDm && _files.length > 1);
  }

  Future<void> _send() async {
    final session = _session;
    if (session == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ids = <String>[];
      for (var i = 0; i < _files.length; i++) {
        final f = _files[i];
        setState(() => _progress = 'アップロード中 ${i + 1}/${_files.length}');
        f.uploaded ??= await session.uploadMedia(f.bytes, f.name, mimeType: f.mimeType, sensitive: f.sensitive);
        ids.add(f.uploaded!.id);
      }
      setState(() => _progress = '送信中…');
      // 投稿オプション (D-045: FOW ヘッダーの公開設定/連合/リアクション受け入れ)。
      final opts = ref.read(composeOptionsProvider);
      final replyTo = _replyTo;
      final quoteOf = switch (widget.target) { ComposeQuote(of: final p) => p, _ => null };
      final parent = replyTo ?? quoteOf;
      // ダイレクトモード (D-047): ダイレクト投稿への返信は specified 固定 +
      // 宛先継承(それ以外だとサーバーがエラーを返す)。連合可視性も親より
      // 広げられない(連合なしの親 → 返信/引用も連合なし)。
      final direct = !_isDm && (replyTo?.isDirect ?? false);
      final myId = ref.read(currentUserProvider).id;
      final draft = NewPost(
        text: _text.text.trim(),
        contentWarning: _cwOn && _cw.text.trim().isNotEmpty ? _cw.text.trim() : null,
        replyToId: replyTo?.id,
        quoteOfId: quoteOf?.id,
        visibility: _isDm ? null : (direct ? 'specified' : opts.visibility),
        localOnly: !_isDm && ((parent?.localOnly ?? false) || (!direct && opts.localOnly)),
        reactionAcceptance: (_isDm || direct) ? null : opts.reactionAcceptance,
        directToIds: direct ? {replyTo!.author.id, ...replyTo.directToIds}.where((id) => id != myId).toList() : const [],
        mediaIds: ids,
        poll: _poll == null ? null : NewPoll(choices: _poll!.texts, multiple: _poll!.multiple, expiresAfter: _poll!.expiresAfter),
      );
      final post = switch (widget.target) {
        ComposeDm(room: final r) => await session.sendDm(r, draft),
        _ => await session.createPost(draft),
      };
      _drafts.clear(_draftKey); // 送信済み → 下書き破棄
      _skipDraftOnDispose = true;
      widget.onSent(post);
      if (widget.resident && mounted) {
        _skipDraftOnDispose = false; // 常駐は続投するので自動下書きを再開
        setState(_resetDraft);
      }
    } on SnsApiException catch (e) {
      setState(() => _error = '${e.code.display}${e.code.message == null ? '' : '\n${e.code.message}'}');
    } catch (e) {
      setState(() => _error = '送信に失敗しました: $e');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = RasqTokens.of(context);
    // 投稿先 (D-089): バンドルタイルで選んだアカウントの顔で書く。
    final postAs = _postAs;
    final me = postAs == null
        ? ref.watch(currentUserProvider)
        : UserSummary(id: '-', account: postAs.account, displayName: postAs.displayName ?? postAs.account.handle, avatarUrl: postAs.avatarUrl);
    final emojis = ref.watch(emojiCacheProvider);
    final target = widget.target;
    final count = _text.text.length;
    final over = count > _max;
    _scheduleStickFit(); // 高さ段階の実測 (D-049/D-051: 全ターゲット共通)

    return Column(mainAxisSize: MainAxisSize.min, children: [
      Flexible(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
          child: Column(key: _stickContentKey, crossAxisAlignment: CrossAxisAlignment.start, children: [
            // パネル内ヘッダー (D-047/D-051): タイトル + 投稿オプション + ✕ と
            // 対象タイル。常駐 stick ではフォーカスで上から割り込んでくる。
            AnimatedSize(
              key: _stickHeaderAnimKey,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: !_expandedView
                  ? const SizedBox(width: double.infinity)
                  : Column(key: _stickHeaderInnerKey, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // ヘッダー (D-052): キャンセル(左)/ タイトル(太字・中央)/
                      // 下書き(青文字・右)。投稿オプションは下部ツールバーへ。
                      // FOW 内ヘッダー = 掴んで左右カラム間移動 (D-062)。
                      _grip(Row(children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: _busy ? null : _handleClose,
                              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32), alignment: Alignment.centerLeft),
                              child: Text('キャンセル', style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant)),
                            ),
                          ),
                        ),
                        // 文字サイズは絵文字ピッカー(FOW ヘッダー)に合わせる (D-053)。
                        Text(_headerTitle, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _busy || !_canDraft ? null : _saveAsDraftAndClose,
                              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32), alignment: Alignment.centerRight),
                              child: Text('下書き', style: RasqTypography.bodySmall.copyWith(color: _canDraft ? tokens.link : scheme.onSurfaceVariant.withValues(alpha: 0.5))),
                            ),
                          ),
                        ),
                      ])),
                      if (_directReply) Padding(padding: const EdgeInsets.only(bottom: 2), child: Text('ダイレクト投稿への返信(相手にだけ届きます)', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant))),
                      if (_replyTo != null || _quoteOf != null) Padding(padding: const EdgeInsets.only(bottom: RasqSpacing.sm), child: _TargetPreview(post: (_replyTo ?? _quoteOf)!, emojis: emojis)),
                    ]),
            ),
            // アカウントバンドルタイル (D-089): 通常投稿の投稿先を選ぶ。
            // 短押しで開閉、行タップで投稿先切替。設定リンクはノード
            // プログラミング(投稿先のカスタマイズ)の入口。
            if (widget.target is ComposeNormal) _bundleTile(scheme, tokens),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              RasqAvatar(imageUrl: me.avatarUrl, size: RasqSizes.avatarMd, fallbackLabel: me.displayName),
              const SizedBox(width: RasqSpacing.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (_cwOn)
                    Row(children: [
                      Icon(Icons.visibility_outlined, size: 18, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(child: TextField(controller: _cw, decoration: const InputDecoration(hintText: '注釈..', isDense: true), style: RasqTypography.bodySmall)),
                      RasqIconButton(icon: Icons.cancel, size: 20, tooltip: '注釈を外す', onPressed: () => setState(() => _cwOn = false)),
                    ]),
                  TextField(
                    controller: _text,
                    focusNode: _focus,
                    // 常駐 stick は縮小状態で置かれる(タップで展開)。
                    autofocus: !widget.resident,
                    // stick の折りたたみ時は 1 行の書き込みバー(展開で伸びる)。
                    minLines: _expandedView ? 3 : 1,
                    maxLines: 10,
                    // 文字サイズは絵文字ピッカー(検索欄 = bodySmall)に合わせる (D-053)。
                    style: RasqTypography.bodySmall,
                    decoration: InputDecoration(hintText: _isDm ? 'メッセージを入力..' : 'いいことがありますように！', border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none),
                    onChanged: (_) => _syncStickHeight(),
                  ),
                ]),
              ),
            ]),
            if (_files.isNotEmpty)
              SizedBox(
                height: 88,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _files.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => _AttachmentTile(a: _files[i], onRemove: () => setState(() => _files.removeAt(i)), onToggleSensitive: () => setState(() => _files[i].sensitive = !_files[i].sensitive)),
                ),
              ),
            if (_poll != null) PollEditor(draft: _poll!, onRemove: () => setState(() => _poll = null)),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: RasqSpacing.sm),
                child: Text(_error!, style: RasqTypography.bodySmall.copyWith(color: tokens.danger)),
              ),
            if (_progress != null) Padding(padding: const EdgeInsets.only(top: RasqSpacing.sm), child: Text(_progress!, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant))),
          ]),
        ),
      ),
      // 子 FOW の回避伸縮 (D-068): アクションバーの**前後**に高さ可変
      // padding を置く。子ピッカーが付いている側の padding が子の高さに
      // 伸びて(いなければ 0px)、入力部・バーが子に被らない。
      if (widget.spec != null) FowChildGap(spec: widget.spec!, top: true),
      // Toolbar (コンポーザーツールバー = アクションバーの左寄せバリエーション)
      // FOW 内フッター = 掴んで左右カラム間移動 (D-062)。
      _grip(Container(
        key: _stickToolbarKey,
        decoration: BoxDecoration(border: Border(top: BorderSide(color: scheme.outlineVariant))),
        padding: const EdgeInsets.fromLTRB(RasqSpacing.sm, 4, RasqSpacing.sm, 4),
        child: Row(children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                RasqActionButton.icon(icon: Icons.photo_camera_outlined, tooltip: 'カメラ', onTap: _busy ? null : () => _pick(camera: true)),
                RasqActionButton.icon(icon: Icons.image_outlined, tooltip: '画像', onTap: _busy || _files.length >= 4 ? null : () => _pick()),
                RasqActionButton.icon(icon: Icons.visibility_outlined, doneIcon: Icons.visibility, done: _cwOn, tooltip: '隠す(注釈)', onTap: () => setState(() => _cwOn = !_cwOn)),
                if (!_isDm) RasqActionButton.icon(icon: Icons.poll_outlined, doneIcon: Icons.poll, done: _poll != null, tooltip: '投票', onTap: () => setState(() => _poll = _poll == null ? PollDraft() : null)),
                RasqActionButton.icon(
                  icon: Icons.emoji_emotions_outlined,
                  tooltip: '絵文字',
                  onTap: () => openEmojiPicker(ref, ownerId: composerFowId, column: _column, predictionContext: _text.text, onPick: (e) {
                    _insert(e);
                    _focus.requestFocus();
                  }),
                ),
                // MFM/Markdown ピッカー (D-045/D-046: 起動ボタンはツールバー側)。
                Builder(builder: (context) {
                  final mfm = ref.watch(currentAccountProvider)?.kind == SnsKind.misskey;
                  return RasqActionButton.icon(
                    icon: Icons.code,
                    tooltip: mfm ? 'MFM' : 'Markdown',
                    onTap: () => openMfmPicker(ref, ownerId: composerFowId, mfm: mfm, column: _column, onApply: (p, s) {
                      _wrapSelection(p, s);
                      _focus.requestFocus();
                    }),
                  );
                }),
                // 投稿オプション (D-052: ヘッダーからツールバーへ移動)。
                if (!_isDm && !_directReply) const ComposerHeaderControls(),
              ]),
            ),
          ),
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: over ? tokens.danger : scheme.primary, width: 1.5)),
            child: Text('$count', style: RasqTypography.caption.copyWith(color: over ? tokens.danger : scheme.primary, fontSize: 10)),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _canSend ? _send : null,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 16)),
            child: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Text(switch (target) { ComposeReply() => '返信', ComposeDm() => '送信', _ => '送信' }),
          ),
        ]),
      )),
      // 子 FOW の回避伸縮 (D-068): バー後ろ側の可変 padding(下ドック時は
      // こちらが伸びて、バーが子ピッカーの上辺に載る)。
      if (widget.spec != null) FowChildGap(spec: widget.spec!),
    ]);
  }
}

class _TargetPreview extends StatelessWidget {
  const _TargetPreview({required this.post, required this.emojis});
  final Post post;
  final Map<String, Uri?> emojis;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(RasqSpacing.sm),
      decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(RasqSizes.radiusSm)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        RasqAvatar(imageUrl: post.author.avatarUrl, size: RasqSizes.avatarSm, fallbackLabel: post.author.displayName),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(post.author.displayName, style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700)),
            RasqRichText(InlineSpans.parse(post.body, emojis: emojis), style: RasqTypography.bodySmall, maxLines: 3, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]),
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({required this.a, required this.onRemove, required this.onToggleSensitive});
  final _Attachment a;
  final VoidCallback onRemove;
  final VoidCallback onToggleSensitive;
  @override
  Widget build(BuildContext context) => Stack(children: [
        ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(a.bytes, width: 88, height: 88, fit: BoxFit.cover)),
        Positioned(right: 0, top: 0, child: RasqIconButton(icon: Icons.cancel, size: 18, color: Colors.white, onPressed: onRemove, tooltip: '削除')),
        Positioned(
          left: 0,
          bottom: 0,
          child: IconButton(
            onPressed: onToggleSensitive,
            tooltip: a.sensitive ? 'センシティブ解除' : 'センシティブにする',
            icon: Icon(a.sensitive ? Icons.visibility_off : Icons.visibility_outlined, size: 18, color: Colors.white),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ),
      ]);
}
