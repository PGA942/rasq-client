import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../session/sanctions.dart';
import '../child_safe/child_safe_providers.dart' show childComposeVerdict, childComposeSent;
import '../../app/router.dart';
import '../../shell/app_overlay_root.dart';
import '../../text/inline_spans.dart';
import '../home/plugin_actions.dart';
import '../home/post_row.dart' show PostRow;
import '../home/timeline_providers.dart' show resolveNodeFetch;
import '../nodeprog/node_executor.dart';
import '../nodeprog/node_graph.dart';
import '../nodeprog/node_tabs.dart';
import '../nodeprog/tl_components.dart';
import '../settings/settings_dsl.dart';
import 'composer_learning.dart';
import 'compose_providers.dart';
export 'compose_providers.dart' show ComposerInitialFile;
import 'account_select.dart';
import '../home/account_affinity.dart';
import 'kana_romaji.dart';
import 'compose_target.dart';
import 'media_file_pick.dart';
import 'drafts_fow.dart';
import 'emoji_picker_fow.dart';
import 'mfm_picker_fow.dart';
import '../../backend/orgate_client.dart';
import '../../backend/rasq_account.dart';
import '../../backend/rasq_account_page_api.dart';
import '../plugins/slot_plugins.dart';
import 'poll_editor.dart';

/// Opens the composer as an interstitial FOW (docked, resizable). Child FOWs
/// (絵文字ピッカー) are owned by it and closed with it.
/// Resolves with the created post, or null on cancel.
const composerFowId = 'fow.composer';

/// [resident] (D-050): スレッド/DM ページ下部の**常駐 stick** — ページを開くと
/// 縮小状態で置かれ、送信しても閉じずに(下書きをリセットして)残る。✕ は
/// 折りたたみ。消えるのはページ遷移のときだけ。[onPosted] は送信毎に呼ばれる
/// (スレッド/ルームの再読込用)。
/// [initialText] は本文の初期値(AsTell の共有リンク転送 D-159 など)。下書きが
/// 残っていればそちらを優先する。
/// [postAs] は投稿先アカウントの初期値(共有 FOW で選んだアカウント、D-170)。
/// [rasqTarget] = RASQ 指定で開く (D-275。アカウントページの「RASQ に投稿」から)。
Future<Post?> showComposer(WidgetRef ref, ComposeTarget target, {bool resident = false, ValueChanged<Post>? onPosted, int column = 0, String? initialText, AccountSession? postAs, List<ComposerInitialFile>? initialFiles, bool rasqTarget = false}) =>
    showComposerWith(manager: ref.read(overlayManagerProvider), router: ref.read(routerProvider), target, resident: resident, onPosted: onPosted, column: column, initialText: initialText, postAs: postAs, initialFiles: initialFiles, rasqTarget: rasqTarget);

/// [showComposer] の本体 (D-225): Widget の外(RAi の関数 `post.reply` などのオートフィル)からも
/// 開けるよう、[OverlayManager] と [GoRouter] を直接受ける。
Future<Post?> showComposerWith(ComposeTarget target, {required OverlayManager manager, required GoRouter router, bool resident = false, ValueChanged<Post>? onPosted, int column = 0, String? initialText, AccountSession? postAs, List<ComposerInitialFile>? initialFiles, bool rasqTarget = false}) async {
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
  void onNavigate() => manager.close(composerFowId, reason: OverlayCloseReason.discard);
  if (stick) router.routerDelegate.addListener(onNavigate);
  try {
    final res = await manager.showFow<Post>(
      id: composerFowId,
      spec: spec,
      builder: (ctx, handle) => _ComposerBody(
        target: target,
        spec: spec,
        resident: resident,
        initialText: initialText,
        initialPostAs: postAs,
        initialFiles: initialFiles,
        initialRasqTarget: rasqTarget,
        // 常駐は送信で閉じない(本体が下書きをリセットして残る)。
        onSent: resident ? (p) => onPosted?.call(p) : (p) => handle.close(result: p),
        onClose: () => handle.close(),
      ),
    );
    return res;
  } finally {
    if (stick) router.routerDelegate.removeListener(onNavigate);
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
  const _ComposerBody({required this.target, required this.onSent, this.spec, this.onClose, this.resident = false, this.initialText, this.initialPostAs, this.initialFiles, this.initialRasqTarget = false});
  final ComposeTarget target;

  /// 本文の初期値(下書きが無いときだけ)。
  final String? initialText;
  final AccountSession? initialPostAs;
  final List<ComposerInitialFile>? initialFiles;

  /// RASQ 指定で開く (D-275)。
  final bool initialRasqTarget;
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

  /// テキスト加工プラグイン (D-167): 本文変化のデバウンスと入力欄トークン。
  Timer? _textPluginTimer;
  late final String _textToken = 'composer-${identityHashCode(this)}';
  SlotPluginsNotifier? _slots; // dispose で ref を触らないための写し

  /// テキスト加工プラグインの ON / OFF(契約 v0.14 §2.3 temp、D-305): ActionKey → このコンポーザーでの状態(面ローカル、保存しない)。
  /// 最初に見たとき初期状態(利用者の上書き → 審査済みの宣言 auto → 既定 ON)で埋める。オフのあいだ `text.changed` は送らない。
  final Map<String, bool> _textPluginOn = {};
  String? _error;
  String? _progress;
  bool _textPluginIsOn(PluginAction a) => _textPluginOn.putIfAbsent(a.id, () => a.effectiveAuto(ref.read(actionButtonPrefsProvider)));

  /// 入力欄の上のチップ行: switch がオンの `composer.text` プラグインごとに ON / OFF。長押しで「次からも自動でオン / オフ」。
  Widget _textPluginChips(List<PluginAction> actions) => Padding(
        padding: const EdgeInsets.only(bottom: RasqSpacing.xs),
        child: Wrap(spacing: RasqSpacing.xs, runSpacing: 2, children: [
          for (final a in actions)
            Builder(
              builder: (ctx) => GestureDetector(
                onLongPress: () {
                  final box = ctx.findRenderObject() as RenderBox;
                  showActionTempMenu(ref, anchor: box.localToGlobal(Offset.zero) & box.size, action: a, ownerId: composerFowId);
                },
                child: FilterChip(
                  key: ValueKey('composer.textPlugin.${a.plugin.id}'),
                  avatar: Icon(PostRow.iconFor(a.decl.icon, Icons.extension_outlined), size: 16),
                  label: Text(a.decl.label, style: RasqTypography.caption),
                  tooltip: '${a.plugin.manifest.name}(テキスト加工)',
                  selected: _textPluginIsOn(a),
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onSelected: (on) => setState(() {
                    _textPluginOn[a.id] = on;
                    if (on) _scheduleTextPlugins();
                  }),
                ),
              ),
            ),
        ]),
      );

  // stick FOW (D-047/D-049) の高さ: 折りたたみ = 入力行 + ツールバーだけ、
  // 展開 = ヘッダー + 返信先タイルが割り込む。定数は実測が入るまでの初期値で、
  // レイアウト後に「全部をピッタリ表示できる」段階を計算して差し替える。
  // 実測が入るまでの初期値 (D-178: ハンドル 26px + ツールバー 57px が 600px 高でも入るよう 0.15 → 0.17)。
  static const stickCollapsedFactor = 0.17;
  static const stickExpandedFactor = 0.44;

  Post? get _replyTo => switch (widget.target) { ComposeReply(to: final p) => p, _ => null };
  Post? get _quoteOf => switch (widget.target) { ComposeQuote(of: final p) => p, _ => null };

  /// RASQ の投稿の引用 (D-276): 投稿先は RASQ に固定(SNS には引用できない)。
  bool get _rasqQuote => _quoteOf != null && isRasqPost(_quoteOf!);

  /// RASQ の投稿への返信 (D-292): SNS の返信と同じコンポーザー(スレッド画面の常駐コンポーザーも)で、投稿先は RASQ に固定。
  /// 返信は文字だけ(500 文字まで)。
  bool get _rasqReply => _replyTo != null && isRasqPost(_replyTo!);

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
  bool get _canDraft => _text.text.trim().isNotEmpty || _cw.text.trim().isNotEmpty || _files.isNotEmpty;

  /// 添付を下書きに(D-174: バイトごとメモリに残す)。
  List<ComposerInitialFile> get _draftFiles => [for (final f in _files) ComposerInitialFile(bytes: f.bytes, name: f.name, mimeType: f.mimeType, sensitive: f.sensitive)];

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
    // ツールバー + ハンドル + スクロール上パディング + 予備。
    final px = (content - headerAnim + headerInner) + toolbar + kFowHandleHeight + RasqSpacing.sm + 2;
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
    // 差はピクセルで見る (D-178): 比率 0.005 だと 3px 余りの不足を見逃して本体が数 px はみ出す。
    if (!spec.userResized && (spec.heightFactor.value - fit).abs() * avail > 0.5) {
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

  /// 開いている下書きの id (D-176): 復元 / 保存で決まる。null なら保存時に新規。
  String? _draftId;
  bool _skipDraftOnDispose = false;
  late final ComposeDraftsStore _drafts;

  @override
  void initState() {
    super.initState();
    _drafts = ref.read(composeDraftsProvider.notifier);
    _focus.addListener(_onFocusChanged);
    // ハンドル / 空いたところのタップで展開 (D-340): 常駐 stick はフォーカスで展開する(ヘッダーと返信先が割り込む)。
    if (widget.spec case final spec?) {
      spec.stickState = () => _collapsible && !_stickExpanded;
      spec.onExpandStick = _focus.requestFocus;
    }
    final t = widget.target;
    // ↓ で別アカウントのコピーから開いた返信/引用 (D-155): 対象の投稿が属する
    // アカウントを投稿先にする(現在と違い、ログイン中なら)。
    final targetPost = switch (t) { ComposeReply(to: final p) => p, ComposeQuote(of: final p) => p, _ => null };
    if (targetPost != null && targetPost.account != ref.read(currentAccountProvider)) {
      final s = ref.read(sessionsProvider).value?.sessions.where((x) => x.account == targetPost.account).firstOrNull;
      if (s != null) _postAs = s;
    }
    if (t is ComposeReply) {
      final a = t.to.author;
      final me = ref.read(currentAccountProvider);
      // RASQ の投稿への返信 (D-292) は、RASQ のハンドルだけ(`@handle`)。
      final mention = isRasqPost(t.to) || a.account.instance == me?.instance ? '@${a.handle}' : '@${a.handle}@${a.account.instance}';
      // 自分の RASQ の投稿への返信には、自分へのメンションを入れない。
      final selfRasq = isRasqPost(t.to) && a.handle.toLowerCase() == ref.read(orgateAccountProvider).value?.handle.toLowerCase();
      _mentionPrefill = selfRasq ? null : '$mention ';
      final cw = t.to.contentWarning;
      _cwPrefill = (cw != null && cw.isNotEmpty) ? cw : null;
      if (widget.resident) {
        _prefillPending = true;
      } else {
        _applyPrefill();
      }
    }
    if (widget.initialText != null && widget.initialText!.isNotEmpty) {
      _text.text = widget.initialText!;
      _text.selection = TextSelection.collapsed(offset: _text.text.length);
    }
    // 共有 FOW で選んだアカウント / プラグインが添えた画像 (D-170)。
    if (widget.initialPostAs != null) _postAs = widget.initialPostAs;
    if ((widget.initialRasqTarget && widget.target is ComposeNormal) || _rasqQuote || _rasqReply) _rasqTarget = true;
    for (final f in widget.initialFiles ?? const <ComposerInitialFile>[]) {
      _files.add(_Attachment(bytes: f.bytes, name: f.name, mimeType: f.mimeType)..sensitive = f.sensitive);
    }
    // 下書きは自動では入れない (D-177): 開くときは空で、下書き FOW(「下書き」)から選んで開く。
    _scheduleTargetEval(); // ポスト先ノード (D-116): 開いた時点の内容で初回評価
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

  ComposeDraft _draftNow(String id) => ComposeDraft(id: id, targetKey: _draftKey, createdAt: DateTime.now(), text: _text.text, cw: _cw.text, cwOn: _cwOn, files: _draftFiles);

  void _saveDraft({bool asNew = false}) {
    if (_text.text.trim().isEmpty && _cw.text.trim().isEmpty && _files.isEmpty) return; // 中身の無い下書きは残さない
    final id = asNew ? ComposeDraftsStore.newId() : (_draftId ?? ComposeDraftsStore.newId());
    _draftId = id;
    _drafts.save(id, _draftNow(id));
  }

  /// 「下書き」(D-176): 下書き FOW — 保存して閉じる / 別の下書きを開く / 消す。
  Future<void> _openDrafts() async {
    final r = await showDraftsFow(ref, currentDraftId: _draftId, hasContent: _canDraft, column: _column, ownerId: composerFowId);
    if (!mounted || r == null) return;
    switch (r) {
      case DraftsSaveAndClose(asNew: final asNew):
        _saveDraft(asNew: asNew);
        _skipDraftOnDispose = true;
        widget.onClose?.call();
      case DraftsLoad(draft: final d):
        // 書きかけがあれば自分の下書きとして残してから差し替える。
        if (_canDraft && d.id != _draftId) _saveDraft();
        setState(() {
          _draftId = d.id;
          _text.text = d.text;
          _text.selection = TextSelection.collapsed(offset: _text.text.length);
          _cwOn = d.cwOn;
          _cw.text = d.cw;
          _files
            ..clear()
            ..addAll([for (final f in d.files) _Attachment(bytes: f.bytes, name: f.name, mimeType: f.mimeType)..sensitive = f.sensitive]);
        });
    }
  }

  /// ✕ / 余白クリック等での閉じ方 (D-051):
  /// - 常駐 stick: 自動入力のメンションだけなら黙って閉じる。入力がある場合は
  ///   「下書きに保存 / 破棄」をポップアップで確認してから閉じる。
  /// - 通常/引用: 確認なしで閉じる(dispose で自動的に下書きへ入る)。
  Future<void> _handleClose() async {
    if (!_hasDraftContent) {
      _skipDraftOnDispose = true; // メンションだけなら下書きも残さない
      widget.onClose?.call();
      return;
    }
    // メンション以外の入力があるときのキャンセル (D-176 改 / D-177): ポップアップ
    // 「下書きに保存しますか」= 保存 / 変更を破棄 / キャンセル(編集に戻る)、
    // 開いている下書きなら「下書きを上書きしますか」= 上書き / 新規保存 / 変更を破棄 / キャンセル。
    final manager = ref.read(overlayManagerProvider);
    final editing = _draftId != null;
    final pick = await manager.showChoiceAlert<_CloseChoice>(
      id: 'composer.close',
      title: editing ? '下書きを上書きしますか' : '下書きに保存しますか',
      message: editing ? '開いている下書きを今の内容で上書きして閉じます。' : '今の内容を下書きに残して閉じます。',
      choices: [
        if (editing) ...[
          const RasqAlertChoice('上書き', _CloseChoice.overwrite, primary: true, key: ValueKey('composer.close.overwrite')),
          const RasqAlertChoice('新規保存', _CloseChoice.saveNew, key: ValueKey('composer.close.saveNew')),
        ] else
          const RasqAlertChoice('保存', _CloseChoice.overwrite, primary: true, key: ValueKey('composer.close.save')),
        const RasqAlertChoice('変更を破棄', _CloseChoice.discard, destructive: true, key: ValueKey('composer.close.discard')),
      ],
      cancelText: 'キャンセル',
    );
    if (!mounted || pick == null) return;
    switch (pick) {
      case _CloseChoice.overwrite:
        _saveDraft();
      case _CloseChoice.saveNew:
        _saveDraft(asNew: true);
      case _CloseChoice.discard:
        break; // 保存済みの下書きは元のまま、今の変更は捨てる
    }
    _skipDraftOnDispose = true; // dispose では触らない
    widget.onClose?.call();
  }

  /// 添付をメディア加工プラグインへ (D-167、CONTRACT §2.2)。
  Future<void> _editAttachment(_Attachment a) async {
    if (!_files.contains(a)) return;
    // 加工 (D-173): 基本動作は pro_image_editor、プラグイン(wasm / ONNX / アセットに無いフィルター)は
    // その下段バーからメディアエディター (D-169) へバイパス。結果(本サイズ)で添付を差し替える。
    final result = await context.pushProMediaEditor(bytes: a.bytes, name: a.name, mimeType: a.mimeType ?? 'image/png');
    if (!mounted || result == null) return;
    final i = _files.indexOf(a);
    if (i < 0) return;
    setState(() => _files[i] = _Attachment(bytes: result.bytes, name: result.name ?? a.name, mimeType: result.mimeType)..sensitive = a.sensitive);
  }

  /// 本文の変化をテキスト加工プラグインへ (D-167、CONTRACT §2.3)。200ms デバウンス。
  /// switch がオンで、このコンポーザーでオン(チップ)のプラグインだけ (契約 v0.14)。
  void _scheduleTextPlugins() {
    final plugins = [for (final a in ref.read(composerTextPluginsProvider)) if (_textPluginIsOn(a)) a.plugin];
    if (plugins.isEmpty) return;
    _slots ??= ref.read(slotPluginsProvider.notifier);
    _textPluginTimer?.cancel();
    _textPluginTimer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      final sel = _text.selection;
      for (final p in plugins) {
        ref.read(slotPluginsProvider.notifier).textChanged(
          p,
          token: _textToken,
          text: _text.text,
          selectionStart: sel.isValid ? sel.start : _text.text.length,
          selectionEnd: sel.isValid ? sel.end : _text.text.length,
          // インライン FOW (D-169): MFM ピッカーと同じく、コンポーザーの子として同じカラムに。
          fowOwner: composerFowId,
          column: _column,
          onReplace: (start, end, text) {
            if (!mounted) return;
            final cur = _text.text;
            if (start < 0 || end < start || end > cur.length) return;
            _text.value = TextEditingValue(text: cur.replaceRange(start, end, text), selection: TextSelection.collapsed(offset: start + text.length));
            _syncStickHeight();
          },
        );
      }
    });
  }

  @override
  void dispose() {
    _textPluginTimer?.cancel();
    _mentionTimer?.cancel();
    _slots?.textDone(_textToken);
    // 余白クリック/ページ遷移などで閉じたときの自動下書き (D-051)。
    // unmount 中は provider を変更できないためマイクロタスクへ遅延する。
    if (!_skipDraftOnDispose && _hasDraftContent && (_text.text.trim().isNotEmpty || _cw.text.trim().isNotEmpty || _files.isNotEmpty)) {
      final drafts = _drafts;
      final key = _draftId ?? ComposeDraftsStore.newId();
      final d = _draftNow(key);
      Future.microtask(() {
        try {
          drafts.save(key, d);
        } catch (_) {/* アプリ終了などで store ごと破棄済みなら諦める */}
      });
    }
    _targetEval?.cancel();
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
    _suggestedPostAs = null; // 下書きが消えたのでサジェストも仕切り直し (D-116)
    _suggestedFallback = null;
    _matchedTargets = const [];
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

  /// RASQ 指定 (D-271): バンドルタイルの RASQ アカウントの行を**長押し**すると、SNS ではなく RASQ アカウントとして投稿する
  /// (アカウントページの「投稿」に出る。本文 1000 文字 + 画像 4 枚、第一期は 3 件まで)。通常の新規投稿のときだけ。
  bool _rasqTarget = false;

  /// RASQ 指定を、ポスト先ノードの一致で自動で入れたか (D-283)。手で入り切りしたら false。
  bool _rasqSuggested = false;

  /// 添付の上限: SNS は 4 つ、RASQ は 6 つ (S-023 / D-276: RASQ も動画・音声を付けられる)。
  int get _maxFiles => _rasqTarget ? rasqPostMaxImages : 4;

  /// 複数選択モード (D-128): アカウントごとに 非選択(0)→ 通常投稿(1)→
  /// **ノードを通した連動投稿**(2, ポスト先グラフにそのアカウントの
  /// ノード設定がある場合のみ)を循環する。選択分は送信時に連動投稿される。
  bool _multiSelect = false;
  final Map<String, int> _multiSel = {};
  static const _selNone = 0, _selNormal = 1, _selLinked = 2;

  /// composercfg(アカウント別のポスト先設定, D-125/D-129/D-130)。
  Future<Map<String, ComposerAccountFilter>> _composerAccountCfg() async {
    try {
      final accKey = ref.read(currentAccountProvider)?.key;
      final area = await ref.read(settingsAreaProvider(nodeprogAreaFor(accKey, 'composer')).future);
      final raw = area['composercfg'];
      if (raw is! String) return const {};
      final out = <String, ComposerAccountFilter>{};
      (jsonDecode(raw) as Map).cast<String, Object?>().forEach((k, v) => out[k] = ComposerAccountFilter.fromJson((v as Map).cast<String, Object?>()));
      return out;
    } catch (_) {
      return const {};
    }
  }

  /// 連動の絞り込み (D-131): composer.linkgate を下書きで評価する。
  Future<Map<String, bool>> _linkGates() async {
    try {
      final accKey = ref.read(currentAccountProvider)?.key;
      final raw = await readNodeGraphRaw((a) => ref.read(settingsAreaProvider(a).future), accKey, 'composer');
      if (raw == null) return const {};
      final graph = NodeGraph.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
      final me = ref.read(currentUserProvider);
      final draft = Post(id: 'draft', account: me.account, author: me, createdAt: DateTime.now(), body: _text.text);
      final session = ref.read(currentSnsSessionProvider);
      SnsSession? sessionForAccount(String label) {
        final s = ref.read(sessionsProvider).value?.sessions.where((x) => '${x.account}' == label || x.account.key == label).firstOrNull;
        return s == null ? null : ref.read(pluginRegistryProvider).session(s);
      }

      return await composerLinkGates(
        graph,
        draft,
        fetch: session == null ? null : (kid) => resolveNodeFetch(session, kid, sessionFor: sessionForAccount, rasqMine: _rasqMine),
      );
    } catch (_) {
      return const {};
    }
  }

  /// 投稿加工(正規表現, D-130)のルール。ポスト先グラフの composer.regex から。
  Future<List<(String, String, String)>> _regexRules() async {
    try {
      final accKey = ref.read(currentAccountProvider)?.key;
      final raw = await readNodeGraphRaw((a) => ref.read(settingsAreaProvider(a).future), accKey, 'composer');
      if (raw == null) return const [];
      return composerRegexRules(NodeGraph.fromJson((jsonDecode(raw) as Map).cast<String, Object?>()));
    } catch (_) {
      return const [];
    }
  }

  /// ポスト先グラフにノード設定(ポスト先/フォールバック)があるアカウント。
  Future<Set<String>> _linkedCapableAccounts() async {
    try {
      final accKey = ref.read(currentAccountProvider)?.key;
      final raw = await readNodeGraphRaw((a) => ref.read(settingsAreaProvider(a).future), accKey, 'composer');
      if (raw == null) return const {};
      final graph = NodeGraph.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
      return {
        for (final n in graph.nodes)
          if (n.type == 'composer.target' || n.type == 'composer.fallback')
            if ((n.inputs.where((i) => i.label == 'アカウント').firstOrNull?.value ?? '').trim().isNotEmpty)
              n.inputs.where((i) => i.label == 'アカウント').firstOrNull!.value!.trim(),
      };
    } catch (_) {
      return const {};
    }
  }

  Set<String> _linkable = const {};

  /// RASQ としての自分の投稿(ポスト先の絞り込みで、RASQ のタブの「自分の投稿」と比べる。D-286)。
  Future<List<Post>> _rasqMine() async {
    final api = ref.read(rasqAccountPageApiProvider);
    final me = ref.read(orgateAccountProvider).value;
    if (api == null || me == null) return const [];
    try {
      return [for (final p in (await api.posts(me.handle)).posts) if (p.rebroadedBy == null) p.toPost()];
    } catch (_) {
      return const [];
    }
  }

  /// RASQ への連動投稿 (D-286)。設定「投稿コンポーザー → RASQ アカウントへも連動投稿する」(既定 off)+ RASQ にログイン中のときだけ。
  bool get _rasqLinkEnabled => ref.read(orgateAccountProvider).value != null && (ref.read(settingsAreaProvider('composer.prefs')).value ?? const {})['rasqLinked'] == true;

  /// 連動の計画は [AccountSession] で持つので、RASQ は仮のセッション(pluginId = [rasqLinkPluginId])で表す。
  /// 送るときに見分けて、SNS のプラグインではなく Central へ投稿する。
  AccountSession get _rasqLinkSession {
    final rasq = ref.read(rasqAccountProvider);
    return AccountSession(account: rasq.account, pluginId: rasqLinkPluginId, token: '', createdAt: DateTime.fromMillisecondsSinceEpoch(0), displayName: rasq.displayName, avatarUrl: rasq.avatarUrl);
  }

  Future<void> _cycleMulti(String label) async {
    if (_linkable.isEmpty) _linkable = await _linkedCapableAccounts();
    if (!mounted) return;
    setState(() {
      final cur = _multiSel[label] ?? _selNone;
      _multiSel[label] = cur == _selNone
          ? _selNormal
          : cur == _selNormal
              ? (_linkable.contains(label) ? _selLinked : _selNone)
              : _selNone;
    });
  }

  /// ポスト先ノードの実行 (D-116): 下書き内容で `composer` スコープの条件を
  /// 評価して投稿先をサジェストする。手動選択(_postAs)が常に優先。
  AccountSession? _suggestedPostAs;
  List<String> _matchedTargets = const [];

  /// 代わりのフォーマットで投稿 (D-126): サジェストがフォールバック経由の
  /// とき、送信時に適用するフォーマット({'format': ..., 'cw': ...})。
  Map<String, String>? _suggestedFallback;
  Timer? _targetEval;

  AccountSession? get _effectivePostAs => _postAs ?? _suggestedPostAs;

  SnsSession? get _session {
    final t = _effectivePostAs;
    if (t != null) return ref.read(pluginRegistryProvider).session(t);
    return ref.read(currentSnsSessionProvider);
  }

  void _scheduleTargetEval() {
    if (widget.target is! ComposeNormal) return;
    _targetEval?.cancel();
    _targetEval = Timer(const Duration(milliseconds: 400), _evalComposerTargets);
  }

  /// 下書きでポスト先グラフを評価した選択肢(通常 → フォールバック,
  /// D-116/D-126/D-128)。グラフ未設定/失敗は空。
  Future<List<(String, Map<String, String>?)>> _composerChoices() async {
    try {
      final accKey = ref.read(currentAccountProvider)?.key;
      final raw = await readNodeGraphRaw((a) => ref.read(settingsAreaProvider(a).future), accKey, 'composer');
      if (raw == null || !mounted) return const [];
      final graph = NodeGraph.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
      final me = ref.read(currentUserProvider);
      // 条件評価用の下書き投稿(本文/注釈/添付数が条件タグの対象)。
      final draft = Post(
        id: 'draft',
        account: me.account,
        author: me,
        createdAt: DateTime.now(),
        body: _text.text,
        contentWarning: _cwOn && _cw.text.trim().isNotEmpty ? _cw.text.trim() : null,
        media: [for (var i = 0; i < _files.length; i++) MediaItem(id: 'draft$i', type: MediaType.image, url: Uri.parse('draft:$i'))],
      );
      final storageArea = storageSafeAreaFor(accKey);
      // 基準取得 (D-125): 絞り込みの基準(そのアカウントの投稿/リアクション/
      // 返信)を各アカウントのセッションから引けるようにする。
      final session = ref.read(currentSnsSessionProvider);
      SnsSession? sessionForAccount(String label) {
        final s = ref.read(sessionsProvider).value?.sessions.where((x) => '${x.account}' == label || x.account.key == label).firstOrNull;
        return s == null ? null : ref.read(pluginRegistryProvider).session(s);
      }

      // フォールバック込みの選択 (D-126): 通常候補 → 代替フォーマット候補。
      return await composerTargetChoices(
        graph,
        draft,
        fetch: session == null ? null : (kid) => resolveNodeFetch(session, kid, sessionFor: sessionForAccount, rasqMine: _rasqMine),
        storageRead: (slot) async => (await ref.read(settingsAreaProvider(storageArea).future))[slot],
      );
    } catch (_) {
      return const []; // グラフ未設定/読めない → サジェストなし
    }
  }

  Future<void> _evalComposerTargets() async {
    if (!mounted) return;
    final choices = await _composerChoices();
    if (!mounted) return;
    final sessions = ref.read(sessionsProvider).value?.sessions ?? const <AccountSession>[];
    AccountSession? find(String label) =>
        label.isEmpty || label == '現在のアカウント' ? null : sessions.where((s) => '${s.account}' == label || s.account.key == label).firstOrNull;
    // 投稿アカウントの自動選択 (D-131: その他の設定 → 投稿コンポーザー)。
    // オフでも一致マーク/並び替えは出す(自動で顔は切り替えない)。
    final autoAccount = (ref.read(settingsAreaProvider('composer.prefs')).value ?? const {})['autoAccount'] != false;
    // RASQ アカウントのポスト先ノード (D-283): いちばんに一致したら、RASQ 指定にする(手で選んでいないとき、通常の投稿だけ)。
    // 一致しなくなったら、自動で入れたぶんだけ戻す。
    final rasqLabel = ref.read(orgateAccountProvider).value == null ? null : '${ref.read(rasqAccountProvider).account}';
    final rasqFirst = autoAccount && rasqLabel != null && choices.isNotEmpty && choices.first.$1 == rasqLabel && widget.target is ComposeNormal && _postAs == null;
    setState(() {
      if (rasqFirst && !_rasqTarget) {
        _rasqTarget = true;
        _rasqSuggested = true;
      } else if (!rasqFirst && _rasqSuggested) {
        _rasqTarget = false;
        _rasqSuggested = false;
      }
      _matchedTargets = [for (final c in choices) c.$1];
      _suggestedPostAs = !autoAccount || choices.isEmpty ? null : find(choices.first.$1);
      _suggestedFallback = !autoAccount || choices.isEmpty ? null : choices.first.$2;
    });
  }

  /// ポスト先ノードの条件に一致した順位(タイルのソート用)。不一致は末尾。
  int _targetRank(AccountSession s) {
    final i = _matchedTargets.indexWhere((l) => l == '${s.account}' || l == s.account.key);
    return i < 0 ? _matchedTargets.length : i;
  }

  /// 投稿先のカスタマイズ (D-089/D-126): 完全に別ページ(アカウントごと
  /// タブ選択形式。グラフでの編集は … メニューの「グラフで編集」)。
  void _openTargetCustomize() => ref.read(routerProvider).push(Routes.composerConfig);

  /// アカウントバンドルタイル (D-089/D-091): アバタータップで出てくる。
  /// RASQ アカウントの顔 + 投稿先リスト。サイドバー(D-087)と同じ作法
  /// (バンドル=素の @handle、個別=handle@instance)。ヘッダー行タップで閉じる。
  Widget _bundleTile(ColorScheme scheme, RasqTokens tokens) {
    final rasq = ref.watch(rasqAccountProvider);
    final sessions = ref.watch(sessionsProvider).value?.sessions ?? const <AccountSession>[];
    final selectedKey = (_effectivePostAs ?? ref.watch(currentAccountSessionProvider))?.account.key;
    // ポスト先ノードの条件に一致したアカウントを上へ (D-116: 投稿内容による
    // 投稿アカウントのソート)。一致なし/グラフなしなら元の並びのまま。
    final ordered = [...sessions]
      ..sort((a, b) {
        final r = _targetRank(a).compareTo(_targetRank(b));
        return r != 0 ? r : sessions.indexOf(a).compareTo(sessions.indexOf(b)); // 安定
      });
    return Container(
      margin: const EdgeInsets.only(bottom: RasqSpacing.sm),
      decoration: BoxDecoration(border: Border.all(color: scheme.outlineVariant), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          key: const ValueKey('composer.rasqRow'),
          borderRadius: BorderRadius.circular(12),
          // 複数選択モード (D-286): SNS の行と同じく、タップで 非選択 → 通常投稿 → ノード連動(設定で有効のとき)。
          onTap: () => _multiSelect && _rasqLinkEnabled && !_rasqTarget ? _cycleMulti('${rasq.account}') : setState(() => _targetsOpen = false),
          // 長押し = RASQ 指定の入り切り (D-271)。
          onLongPress: widget.target is! ComposeNormal || ref.read(orgateAccountProvider).value == null
              ? null
              : () {
                  setState(() {
                    _rasqTarget = !_rasqTarget;
                    _rasqSuggested = false;
                    _targetsOpen = false;
                    _error = null;
                  });
                  // 連動の下書き (D-129 / D-286: delivery=draft): RASQ 宛の下書きがあれば、空のコンポーザーに復元して消費する。
                  final key = 'linked:${rasq.account.key}';
                  final linked = ref.read(composeDraftsProvider)[key];
                  if (_rasqTarget && linked != null && _text.text.trim().isEmpty) {
                    _text.text = linked.text;
                    _text.selection = TextSelection.collapsed(offset: _text.text.length);
                    _cwOn = linked.cwOn;
                    _cw.text = linked.cw;
                    _drafts.clear(key);
                    setState(() {});
                  }
                },
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
              if (_multiSelect && _rasqLinkEnabled && !_rasqTarget)
                Padding(
                  key: const ValueKey('composer.rasqRow.multi'),
                  padding: const EdgeInsets.only(right: 4),
                  child: switch (_multiSel['${rasq.account}'] ?? _selNone) {
                    _selNormal => Text('通常投稿', style: RasqTypography.caption.copyWith(color: tokens.link)),
                    _selLinked => Text('ノード連動', style: RasqTypography.caption.copyWith(color: tokens.link)),
                    _ => Icon(Icons.radio_button_unchecked, size: 16, color: scheme.onSurfaceVariant.withValues(alpha: 0.4)),
                  },
                ),
              if (_rasqTarget) Padding(padding: const EdgeInsets.only(right: 4), child: Text('RASQ に投稿', style: RasqTypography.caption.copyWith(color: tokens.link))),
              if (_rasqTarget) Icon(Icons.check, size: 16, color: tokens.link),
              const Icon(Icons.keyboard_arrow_up, size: 20),
            ]),
          ),
        ),
        ...[
          for (final s in ordered)
            InkWell(
              // 複数選択モード (D-128): 行タップで 非選択 → 通常投稿 →
              // ノード連動投稿(設定があれば)を循環。通常モードは投稿先切替。
              onTap: () {
                if (_multiSelect) {
                  _cycleMulti('${s.account}');
                } else {
                  setState(() {
                    _postAs = s;
                    _rasqTarget = _rasqQuote || _rasqReply;
                    _targetsOpen = false;
                  });
                  // 連動の下書き (D-129: delivery=draft): このアカウント宛の
                  // 下書きがあれば、空のコンポーザーに復元して消費する。
                  final linked = ref.read(composeDraftsProvider)['linked:${s.account.key}'];
                  if (linked != null && _text.text.trim().isEmpty) {
                    _text.text = linked.text;
                    _text.selection = TextSelection.collapsed(offset: _text.text.length);
                    _cwOn = linked.cwOn;
                    _cw.text = linked.cw;
                    _drafts.clear('linked:${s.account.key}');
                    setState(() {});
                  }
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.md, vertical: 6),
                child: Row(children: [
                  RasqSnsPill(account: s.account, showLabel: false, dotSize: 14),
                  const SizedBox(width: RasqSpacing.sm),
                  Expanded(child: Text('${s.account}', style: RasqTypography.bodySmall.copyWith(fontWeight: s.account.key == selectedKey ? FontWeight.w700 : null), overflow: TextOverflow.ellipsis)),
                  // ポスト先ノードの条件に一致 (D-116)。
                  if (_targetRank(s) < _matchedTargets.length)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Tooltip(message: 'ポスト先ノードの条件に一致', child: Icon(Icons.auto_awesome, size: 14, color: scheme.onSurfaceVariant)),
                    ),
                  if (_multiSelect) ...[
                    switch (_multiSel['${s.account}'] ?? _selNone) {
                      _selNormal => Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('通常投稿', style: RasqTypography.caption.copyWith(color: tokens.link)),
                          const SizedBox(width: 4),
                          Icon(Icons.check_circle_outline, size: 16, color: tokens.link),
                        ]),
                      _selLinked => Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('ノード連動', style: RasqTypography.caption.copyWith(color: tokens.link)),
                          const SizedBox(width: 4),
                          Icon(Icons.alt_route, size: 16, color: tokens.link),
                        ]),
                      _ => Icon(Icons.radio_button_unchecked, size: 16, color: scheme.onSurfaceVariant.withValues(alpha: 0.4)),
                    },
                  ] else if (s.account.key == selectedKey)
                    Icon(Icons.check, size: 16, color: tokens.link),
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
          // 複数選択モード (D-128): 選んだアカウントへ同時に投稿する
          // (通常 = 同内容 / ノード連動 = ポスト先グラフを通して成立時のみ)。
          if (widget.target is ComposeNormal)
            InkWell(
              onTap: () async {
                final linkable = await _linkedCapableAccounts();
                if (!mounted) return;
                setState(() {
                  _linkable = linkable;
                  _multiSelect = !_multiSelect;
                  if (!_multiSelect) _multiSel.clear();
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.md, vertical: 8),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                  Icon(_multiSelect ? Icons.checklist_rtl : Icons.checklist, size: 16, color: tokens.link),
                  const SizedBox(width: 6),
                  Text(_multiSelect ? '複数選択を解除' : '複数選択モード', style: RasqTypography.bodySmall.copyWith(color: tokens.link)),
                ]),
              ),
            ),
        ],
      ]),
    );
  }

  /// 連動投稿の計画 (D-128/D-129): (セッション, フォールバック, 届け方)。
  /// 通常投稿は常に auto。ノード連動はポスト先グラフの成立分だけ +
  /// composercfg の届け方(auto/confirm/draft)。
  Future<List<(AccountSession, Map<String, String>?, String)>> _buildMultiPlan() async {
    if (!_multiSelect || widget.target is! ComposeNormal || !_multiSel.values.any((v) => v != _selNone)) return const [];
    final sessions = ref.read(sessionsProvider).value?.sessions ?? const <AccountSession>[];
    final primaryKey = (_effectivePostAs ?? ref.read(currentAccountSessionProvider))?.account.key;
    List<(String, Map<String, String>?)> choices = const [];
    Map<String, bool> gates = const {};
    if (_multiSel.values.contains(_selLinked)) {
      choices = await _composerChoices();
      gates = await _linkGates(); // 連動の絞り込み (D-131)
    }
    final cfg = await _composerAccountCfg();
    final primaryLabel = '${(_effectivePostAs ?? ref.read(currentAccountSessionProvider))?.account ?? ''}';
    final plan = <(AccountSession, Map<String, String>?, String)>[];
    // RASQ も連動先にできる (D-286)。RASQ 指定で投稿しているとき(= 主投稿先が RASQ)は、RASQ 自身には連動しない。
    for (final s in [...sessions, if (_rasqLinkEnabled && !_rasqTarget) _rasqLinkSession]) {
      final label = '${s.account}';
      final mode = _multiSel[label] ?? _selNone;
      if (mode == _selNone || s.account.key == primaryKey) continue;
      if (mode == _selLinked) {
        // 連動元のアカウント選択 (D-131): 主投稿先が許可リストにあるときだけ。
        if (!(cfg[label]?.linkAllowedFrom(primaryLabel) ?? true)) continue;
        // 連動の絞り込み (D-131: F_target): 関門があるなら通過が必要。
        if (gates.containsKey(label) && gates[label] != true) continue;
        final hit = choices.where((c) => c.$1 == label || c.$1 == s.account.key).firstOrNull;
        if (hit == null) continue; // ノード不成立 → このアカウントには連動しない
        plan.add((s, hit.$2, cfg[label]?.delivery ?? 'auto'));
      } else {
        plan.add((s, null, 'auto'));
      }
    }
    return plan;
  }

  /// confirm (D-129): 投稿前に連動先を**チェック済み状態で表示**して確認。
  /// 戻り値 null = 送信自体を中止。チェックを外した連動先は計画から外す。
  Future<(List<(AccountSession, Map<String, String>?, String)>, List<String>)?> _confirmLinked(List<(AccountSession, Map<String, String>?, String)> plan) async {
    final targets = [for (final e in plan) if (e.$3 == 'confirm') e];
    if (targets.isEmpty) return (plan, const <String>[]);
    final manager = ref.read(overlayManagerProvider);
    final checked = {for (final e in targets) e.$1.account.key: true};
    final ok = await manager.showBottomSheet<bool>(
      id: 'composer.linked.confirm',
      title: '連動投稿の確認',
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final e in targets)
            RasqSwitchListTile(
              title: '${e.$1.account}',
              subtitle: e.$2 == null ? '同内容で連動投稿' : '代わりのフォーマットで連動投稿',
              value: checked[e.$1.account.key] ?? true,
              onChanged: (v) => setLocal(() => checked[e.$1.account.key] = v),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.sm),
            child: FilledButton(onPressed: () => manager.close('composer.linked.confirm', result: true), child: const Text('この内容で投稿する')),
          ),
        ]);
      }),
    );
    if (ok != true) return null; // シートを閉じた = 送信中止
    // チェックを外した連動先 = リレーションの負例 (D-132: 学習データの分離)。
    return (
      [
        for (final e in plan)
          if (e.$3 != 'confirm' || (checked[e.$1.account.key] ?? true)) e,
      ],
      [for (final e in targets) if (checked[e.$1.account.key] != true) '${e.$1.account}'],
    );
  }

  /// 計画の実行 (D-128/D-129/D-130): auto/confirm 済み = 投稿、draft =
  /// そのアカウント宛の下書き(次にそのアカウントを投稿先に選ぶと復元)。
  /// 失敗したアカウント表記を返す(本体は落とさない)。
  Future<(List<String>, List<String>)> _executeMultiPlan(
      List<(AccountSession, Map<String, String>?, String)> plan, NewPost base, List<(String, String, String)> regexRules) async {
    final registry = ref.read(pluginRegistryProvider);
    final errors = <String>[];
    final posted = <String>[]; // 連動の正例 (D-132)
    for (final (s, fb, delivery) in plan) {
      final label = '${s.account}';
      var cw = base.contentWarning;
      var visibility = base.visibility;
      var localOnly = base.localOnly;
      // フォールバック経由 (D-126) は代替フォーマットを適用。
      switch (fb?['format']) {
        case 'cw':
          cw ??= (fb!['cw']?.isNotEmpty ?? false) ? fb['cw'] : '別フォーマット';
        case 'followers':
          visibility = 'followers';
        case 'localOnly':
          localOnly = true;
      }
      // 投稿加工(正規表現, D-130): 送信先アカウントごとに本文へ適用。
      final text = applyComposerRegex(base.text, label, regexRules);
      if (delivery == 'draft') {
        // 下書きだけ作る (D-129): 次にそのアカウントを投稿先に選ぶと復元。
        _drafts.save('linked:${s.account.key}', ComposeDraft(text: text, cw: cw ?? '', cwOn: cw != null));
        continue;
      }
      // RASQ への連動 (D-286): SNS のプラグインではなく、Central へ。RASQ に無いもの(指名 / 連合なし)は近いものへ寄せ、上限を超える分は送らない。
      if (s.pluginId == rasqLinkPluginId) {
        try {
          final api = ref.read(rasqAccountPageApiProvider);
          if (api == null) throw StateError('RASQ のサーバーが設定されていません');
          if (text.length > rasqPostMaxChars || _files.length > rasqPostMaxImages || (base.poll?.choices.length ?? 0) > rasqPostMaxPollChoices) throw StateError('RASQ の上限を超えています');
          await api.createPost(
            text,
            images: [for (final f in _files) (bytes: f.bytes as List<int>, contentType: f.mimeType ?? 'image/jpeg', sensitive: f.sensitive)],
            cw: cw ?? '',
            visibility: const {'public', 'home', 'followers'}.contains(visibility) ? visibility! : (visibility == null ? 'public' : 'followers'),
            likeOnly: base.reactionAcceptance == 'likeOnly',
            poll: base.poll == null ? null : (choices: base.poll!.choices, multiple: base.poll!.multiple, expiresAfter: base.poll!.expiresAfter),
          );
          final me = ref.read(orgateAccountProvider).value;
          if (me != null) ref.invalidate(rasqAccountPageProvider(me.handle));
          posted.add(label);
        } catch (e) {
          errors.add(label);
          debugPrint('連動投稿 $label: $e');
        }
        continue;
      }
      try {
        final session = registry.session(s);
        // メディアは各アカウントのサーバーへ上げ直す(id は流用できない)。
        final ids = <String>[];
        for (final f in _files) {
          ids.add((await session.uploadMedia(f.bytes, f.name, mimeType: f.mimeType, sensitive: f.sensitive)).id);
        }
        await session.createPost(NewPost(
            text: text, contentWarning: cw, visibility: visibility, localOnly: localOnly, reactionAcceptance: base.reactionAcceptance, mediaIds: ids, poll: base.poll));
        posted.add(label);
      } catch (e) {
        errors.add(label);
        debugPrint('連動投稿 $label: $e');
      }
    }
    return (errors, posted);
  }

  /// 学習ループ (D-132): 確定ラベルをプロファイルへ EMA 追加(手動切替は
  /// 強く学習)+ 連動 (A→B) の正例/負例の記録。送信は落とさない。
  Future<void> _recordLearning({required String primaryLabel, required bool corrected, required List<String> posted, required List<String> removed}) async {
    try {
      final accKey = ref.read(currentAccountProvider)?.key;
      final area = storageSafeAreaFor(accKey);
      final slot = composerLearnSlot(primaryLabel);
      final existing = (await ref.read(settingsAreaProvider(area).future))[slot];
      final updated = composerLearnUpdate(existing is Map ? existing.cast<String, Object?>() : null, _text.text.trim(), weight: corrected ? 3.0 : 1.0);
      await ref.read(settingsAreaProvider(area).notifier).set(slot, updated);
      if (posted.isNotEmpty || removed.isNotEmpty) {
        var relations = ((await ref.read(settingsAreaProvider('composer.learn').future))['relations'] as Map?)?.cast<String, Object?>() ?? const <String, Object?>{};
        for (final b in posted) {
          relations = composerRelationBump(relations, primaryLabel, b, positive: true);
        }
        for (final b in removed) {
          relations = composerRelationBump(relations, primaryLabel, b, positive: false);
        }
        await ref.read(settingsAreaProvider('composer.learn').notifier).set('relations', relations);
      }
    } catch (e) {
      debugPrint('学習ループ: $e');
    }
  }

  bool get _isDm => widget.target is ComposeDm;
  int get _max => _session?.maxPostLength ?? 500;

  // ── @ 補完 (D-285) ──
  List<({String insert, String name, Uri? avatarUrl})> _mentionHits = const [];
  Timer? _mentionTimer;
  int _mentionSeq = 0;

  /// キャレットの直前の `@…`(打っている途中のメンション)。無ければ null。戻り = (@ の位置, 打った文字)。
  (int, String)? get _mentionAtCaret {
    final v = _text.value;
    if (!v.selection.isValid || !v.selection.isCollapsed) return null;
    return mentionQueryAt(v.text, v.selection.start);
  }

  void _scheduleMentionSearch() {
    _mentionTimer?.cancel();
    final q = _mentionAtCaret;
    if (q == null || q.$2.isEmpty) {
      if (_mentionHits.isNotEmpty) setState(() => _mentionHits = const []);
      return;
    }
    _mentionTimer = Timer(const Duration(milliseconds: 250), () => _searchMentions(q.$2));
  }

  /// 候補を引く: RASQ 指定なら Central のアカウント検索、そうでなければ投稿するアカウントの SNS のユーザー検索
  /// (全 SNS プラグイン共通の `searchUsers`)。別のサーバーの人は `@handle@host` で入れる。
  Future<void> _searchMentions(String q) async {
    final seq = ++_mentionSeq;
    final hits = <({String insert, String name, Uri? avatarUrl})>[];
    // 打ったままの文字(表示名に当たる)と、かなをローマ字に読み替えたもの(ハンドルに当たる。D-289)の両方で引いて、合わせる。
    final romaji = kanaToRomaji(q);
    for (final term in [q, if (romaji != null && romaji != q.toLowerCase()) romaji]) {
      try {
        if (_rasqTarget) {
          final api = ref.read(rasqAccountPageApiProvider);
          hits.addAll([for (final a in await api?.searchAccounts(term) ?? const <RasqPostAuthor>[]) (insert: '@${a.handle}', name: a.label, avatarUrl: a.avatarUrl)]);
        } else {
          final session = _session;
          final me = session?.account;
          final page = await session?.searchUsers(term, limit: 8);
          hits.addAll([
            for (final u in page?.items ?? const <UserSummary>[])
              (insert: u.account.instance == me?.instance ? '@${u.handle}' : '@${u.handle}@${u.account.instance}', name: u.displayName, avatarUrl: u.avatarUrl),
          ]);
        }
      } catch (_) {
        // 検索できない SNS / 通信の失敗: 候補を出さないだけ。
      }
    }
    // 同じ人は 1 回。
    final seen = <String>{};
    hits.retainWhere((h) => seen.add(h.insert));
    if (!mounted || seq != _mentionSeq) return;
    setState(() => _mentionHits = hits);
  }

  /// 打っている途中の `@…` を、選んだメンションに置き換える。
  void _applyMention(String mention) {
    final q = _mentionAtCaret;
    final v = _text.value;
    final start = q?.$1 ?? (v.selection.isValid ? v.selection.start : v.text.length);
    final end = v.selection.isValid ? v.selection.start : v.text.length;
    final next = v.text.replaceRange(start, end, '$mention ');
    _text.value = TextEditingValue(text: next, selection: TextSelection.collapsed(offset: start + mention.length + 1));
    setState(() => _mentionHits = const []);
    _focus.requestFocus();
  }

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
      for (final f in files.take(_maxFiles - _files.length)) {
        _files.add(_Attachment(bytes: await f.readAsBytes(), name: f.name, mimeType: f.mimeType));
      }
      setState(() {});
    } catch (e) {
      if (camera) return _pick();
      setState(() => _error = '画像を選択できませんでした: $e');
    }
  }

  /// 動画 (D-174 → D-250): ライブラリから動画 1 本、またはファイルから動画 / **音声** 1 本。
  /// 音声はそのまま添付になる(加工を開くと Visualizer の動画へ変換される)。
  Future<void> _pickVideo(Rect anchor) async {
    final from = await ref.read(overlayManagerProvider).showDropdown<String>(id: 'composer.video.source', ownerId: composerFowId, anchor: anchor, dense: true, items: const [
      RasqDropdownItem('ライブラリの動画', 'library'),
      RasqDropdownItem('ファイルから(動画 / 音声)', 'file'),
    ]);
    if (from == null || !mounted) return;
    try {
      final f = from == 'file' ? await ref.read(mediaFilePickerProvider)() : await ImagePicker().pickVideo(source: ImageSource.gallery);
      if (f == null || _files.length >= _maxFiles) return;
      final name = f.name.isEmpty ? 'video.mp4' : f.name;
      final mime = mediaMimeFor(name, reported: f.mimeType);
      if (mime == null) {
        setState(() => _error = '動画 / 音声のファイルではありません: $name');
        return;
      }
      _files.add(_Attachment(bytes: await f.readAsBytes(), name: name, mimeType: mime));
      setState(() {});
    } catch (e) {
      setState(() => _error = '動画 / 音声を選択できませんでした: $e');
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

  /// RASQ アカウントとして投稿する (D-271 → D-275)。作り方は SNS と共通: 注釈 / 公開範囲 / リアクションの受け入れ(いいねのみ)/
  /// センシティブな画像 / 投票。**違うのは、連合に関わるもの(連合なし、リモート向けの受け入れ)が無いことと、上限**
  /// (添付 6 つ / 投票 6 個 / 本文 1000 文字)。動画 / 音声も付けられる(D-276。32 MiB まで)。引用は RASQ の投稿だけ。投稿先の連動は使えない。
  Future<void> _sendRasq() async {
    final api = ref.read(rasqAccountPageApiProvider);
    final me = ref.read(orgateAccountProvider).value;
    if (api == null || me == null) return setState(() => _error = 'RASQ アカウントにログインしていません');
    if (_files.any((f) => f.bytes.length > rasqPostMaxMediaBytes)) return setState(() => _error = 'RASQ への投稿では、動画 / 音声は 1 つ ${rasqPostMaxMediaBytes ~/ (1024 * 1024)} MB までです');
    if (_rasqReply && (_files.isNotEmpty || _poll != null)) return setState(() => _error = 'RASQ の返信は、文字だけです(添付 / 投票は付けられません)');
    if (_rasqReply && _text.text.trim().length > rasqReplyMaxChars) return setState(() => _error = 'RASQ の返信は $rasqReplyMaxChars 文字までです');
    if (_files.length > rasqPostMaxImages) return setState(() => _error = 'RASQ への投稿は、添付 $rasqPostMaxImages つまでです');
    if (_text.text.trim().length > rasqPostMaxChars) return setState(() => _error = 'RASQ への投稿は $rasqPostMaxChars 文字までです');
    final poll = _poll;
    if (poll != null && poll.texts.length > rasqPostMaxPollChoices) return setState(() => _error = 'RASQ への投稿は、投票の選択肢 $rasqPostMaxPollChoices 個までです');
    final sanctions = ref.read(rasqSanctionsProvider).value ?? RasqSanctions.none;
    final blocked = sanctions.blockedMessage('post') ?? (_files.isNotEmpty ? sanctions.blockedMessage('post.media') : null);
    if (blocked != null) return setState(() => _error = blocked);
    if (!await _childSafeAllows(dm: false)) return;
    // 公開設定は SNS と同じ FOW から。RASQ に無いもの(指名 / リモート向けの受け入れ)は、近いものへ寄せる。
    final opts = ref.read(composeOptionsProvider);
    final visibility = const {'public', 'home', 'followers'}.contains(opts.visibility) ? opts.visibility : 'followers';
    setState(() {
      _busy = true;
      _error = null;
      _progress = '送信中…';
    });
    try {
      final created = _rasqReply
          ? await api.reply(_replyTo!.id, _text.text.trim())
          : await api.createPost(
        _text.text.trim(),
        images: [for (final f in _files) (bytes: f.bytes as List<int>, contentType: f.mimeType ?? 'image/jpeg', sensitive: f.sensitive)],
        cw: _cwOn ? _cw.text.trim() : '',
        visibility: visibility,
        likeOnly: opts.reactionAcceptance == 'likeOnly',
        poll: poll == null ? null : (choices: poll.texts, multiple: poll.multiple, expiresAfter: poll.expiresAfter),
        quoteOf: _rasqQuote ? _quoteOf!.id : null,
      );
      ref.invalidate(rasqAccountPageProvider(me.handle));
      await childComposeSent(ref, _text.text.trim());
      if (_draftId != null) _drafts.clear(_draftId!);
      _skipDraftOnDispose = true;
      ref.read(rootMessengerKeyProvider).currentState?.showSnackBar(const SnackBar(content: Text('RASQ に投稿しました')));
      if (widget.resident) {
        if (mounted) {
          _skipDraftOnDispose = false;
          setState(() {
            _resetDraft();
            // 返信 / 引用は RASQ に固定のまま(常駐の返信コンポーザーは、続けて返信できる)。
            _rasqTarget = _rasqQuote || _rasqReply;
          });
        }
        // スレッド画面が取り直せるように知らせる。
        widget.onSent(created.toPost(central: ref.read(centralBaseUrlProvider)));
      } else if (_rasqReply) {
        widget.onSent(created.toPost(central: ref.read(centralBaseUrlProvider)));
      } else {
        widget.onClose?.call();
      }
    } on OrgateException catch (e) {
      if (mounted) setState(() => _error = e.code.code == '409' && _rasqReply ? 'RASQ の返信は 100 件までです。古い返信を消してください' : e.code.code == '409' ? 'RASQ への投稿は 3 件までです。古い投稿を消してください' : 'RASQ に投稿できませんでした: ${e.message}');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  /// チャイルドセーフ (D-307): 見守りの制限(DM / メディア / 1 日の数 / 本文の強さ)。止めたら理由を出し、当たった語を選んで印を付ける。
  Future<bool> _childSafeAllows({required bool dm}) async {
    final verdict = await childComposeVerdict(ref, text: _text.text, dm: dm, media: _files.isNotEmpty);
    if (verdict == null) return true;
    if (!mounted) return false;
    setState(() => _error = verdict.message);
    if (verdict.hasRange && verdict.end! <= _text.text.length) {
      _text.selection = TextSelection(baseOffset: verdict.start!, extentOffset: verdict.end!);
      _focus.requestFocus();
    }
    return false;
  }

  Future<void> _send() async {
    if (_rasqTarget) return _sendRasq();
    final session = _session;
    if (session == null) return;
    // 連動投稿の計画 (D-129): confirm の届け方があれば**送信前(busy に入る
    // 前)に**チェック済み状態のシートで確認する(閉じたら送信自体を中止)。
    var multiPlan = await _buildMultiPlan();
    var removedByConfirm = <String>[]; // 確認で外した連動先 = 負例 (D-132)
    final regexRules = widget.target is ComposeNormal ? await _regexRules() : const <(String, String, String)>[];
    if (multiPlan.any((e) => e.$3 == 'confirm')) {
      final approved = await _confirmLinked(multiPlan);
      if (approved == null) return; // 送信中止
      multiPlan = approved.$1;
      removedByConfirm = approved.$2;
    }
    if (!mounted) return;
    // アカウントの処置 (D-151): 投稿 / メディア付き投稿 / DM が止まっていれば送らない。
    final sanctions = ref.read(rasqSanctionsProvider).value ?? RasqSanctions.none;
    final blocked = sanctions.blockedMessage(_isDm ? 'dm' : 'post') ?? (_files.isNotEmpty ? sanctions.blockedMessage('post.media') : null);
    if (blocked != null) {
      setState(() => _error = blocked);
      return;
    }
    if (!await _childSafeAllows(dm: _isDm)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // 中レベルの制限 (D-151): 発言ごとに検閲による遅延(投稿系はクライアント側で待つ)。
      if (sanctions.moderated) {
        for (var left = sanctions.reviewDelaySeconds; left > 0; left--) {
          if (!mounted) return;
          setState(() => _progress = '検閲による遅延: あと $left 秒');
          await Future<void>.delayed(const Duration(seconds: 1));
        }
      }
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
      // 代わりのフォーマットで投稿 (D-126): サジェストがフォールバック経由の
      // アカウントで送るとき、指定のフォーマット(注釈/フォロワー限定/
      // 連合なし)を下書きに適用する。
      final fb = (_postAs == null && _suggestedPostAs != null) ? _suggestedFallback : null;
      String? cw = _cwOn && _cw.text.trim().isNotEmpty ? _cw.text.trim() : null;
      String? visibility = _isDm ? null : (direct ? 'specified' : opts.visibility);
      var localOnly = !_isDm && ((parent?.localOnly ?? false) || (!direct && opts.localOnly));
      switch (fb?['format']) {
        case 'cw':
          cw ??= (fb!['cw']?.isNotEmpty ?? false) ? fb['cw'] : '別フォーマット';
        case 'followers':
          if (!_isDm && !direct) visibility = 'followers';
        case 'localOnly':
          if (!_isDm) localOnly = true;
      }
      // 投稿加工(正規表現, D-130): 本体の投稿先アカウントにも適用。
      final primaryLabel = '${(_effectivePostAs ?? ref.read(currentAccountSessionProvider))?.account ?? ''}';
      final draft = NewPost(
        text: applyComposerRegex(_text.text.trim(), primaryLabel, regexRules),
        contentWarning: cw,
        replyToId: replyTo?.id,
        quoteOfId: quoteOf?.id,
        visibility: visibility,
        localOnly: localOnly,
        reactionAcceptance: (_isDm || direct) ? null : opts.reactionAcceptance,
        directToIds: direct ? {replyTo!.author.id, ...replyTo.directToIds}.where((id) => id != myId).toList() : const [],
        mediaIds: ids,
        poll: _poll == null ? null : NewPoll(choices: _poll!.texts, multiple: _poll!.multiple, expiresAfter: _poll!.expiresAfter),
      );
      final post = switch (widget.target) {
        ComposeDm(room: final r) => await session.sendDm(r, draft),
        _ => await session.createPost(draft),
      };
      await childComposeSent(ref, _text.text.trim());
      // 返信 / 引用した相手を、投稿したアカウントの「やりとり」として覚える (D-280: 共有 / リノートに使うアカウントの予測の材料)。
      final talkedTo = replyTo ?? quoteOf;
      if (talkedTo != null) ref.read(accountAffinityProvider.notifier).record(Post(id: talkedTo.id, account: session.account, author: talkedTo.author, createdAt: talkedTo.createdAt, body: '')).ignore();
      // 複数選択モード (D-128/D-129): 計画の実行 — auto/confirm 済みは投稿、
      // draft はそのアカウント宛の下書き。正規表現加工 (D-130) も各送信先に。
      final (linkErrors, linkedPosted) = await _executeMultiPlan(multiPlan, NewPost(
        text: _text.text.trim(),
        contentWarning: cw,
        visibility: visibility,
        localOnly: localOnly,
        reactionAcceptance: (_isDm || direct) ? null : opts.reactionAcceptance,
        poll: _poll == null ? null : NewPoll(choices: _poll!.texts, multiple: _poll!.multiple, expiresAfter: _poll!.expiresAfter),
      ), regexRules);
      // 学習ループ (D-132): 確定ラベル(手動切替は強く学習)+ 連動の正負例。
      if (widget.target is ComposeNormal && _text.text.trim().isNotEmpty) {
        final corrected = _postAs != null && _suggestedPostAs != null && _postAs!.account.key != _suggestedPostAs!.account.key;
        await _recordLearning(primaryLabel: primaryLabel, corrected: corrected, posted: linkedPosted, removed: removedByConfirm);
      }
      if (_draftId != null) _drafts.clear(_draftId!); // 送信済み → 下書き破棄
      _skipDraftOnDispose = true;
      _multiSel.clear();
      if (linkErrors.isNotEmpty && mounted) {
        // 本体は投稿済み — 閉じずに連動側の失敗だけ知らせる。
        setState(() => _error = '連動投稿に失敗しました: ${linkErrors.join(' / ')}(本体は投稿済みです)');
        return;
      }
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
    // 投稿先 (D-089): バンドルタイルで選んだ(またはポスト先ノードが
    // サジェストした, D-116)アカウントの顔で書く。
    final postAs = _effectivePostAs;
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
                              onPressed: _busy ? null : _openDrafts,
                              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32), alignment: Alignment.centerRight),
                              child: Text('下書き', style: RasqTypography.bodySmall.copyWith(color: tokens.link)),
                            ),
                          ),
                        ),
                      ])),
                      if (_directReply) Padding(padding: const EdgeInsets.only(bottom: 2), child: Text('ダイレクト投稿への返信(相手にだけ届きます)', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant))),
                      if (_replyTo != null || _quoteOf != null) Padding(padding: const EdgeInsets.only(bottom: RasqSpacing.sm), child: _TargetPreview(post: (_replyTo ?? _quoteOf)!, emojis: emojis)),
                    ]),
            ),
            // アカウントバンドルタイル (D-089/D-091): **アバターをタップすると
            // 出てくる**(常設だと引用時に場所が取れないため)。行タップで
            // 投稿先切替、設定リンクはノードプログラミングの入口。DM 以外で有効。
            if (_targetsOpen && !_isDm) _bundleTile(scheme, tokens),
            // 投稿先のアカウント選択ピル (D-170): 共有 FOW のヘッダーと同じ 200〜300px の
            // ピル(アバター + SNS 色点 + @handle@instance + ▾)。タップでバンドルタイル開閉。
            Align(
              alignment: Alignment.centerLeft,
              child: AccountSelectPill(
                key: ValueKey(_rasqTarget ? 'composer.pill.rasq' : 'composer.pill.sns'),
                // RASQ 指定 (D-271) のときは、RASQ アカウントの顔を出す。
                account: _rasqTarget ? ref.watch(rasqAccountProvider).account : me.account,
                displayName: _rasqTarget ? ref.watch(rasqAccountProvider).displayName : me.displayName,
                avatarUrl: _rasqTarget ? ref.watch(rasqAccountProvider).avatarUrl : me.avatarUrl,
                open: _targetsOpen,
                tooltip: _isDm ? '' : '投稿先を選ぶ',
                onTap: _isDm ? null : () => setState(() => _targetsOpen = !_targetsOpen),
              ),
            ),
            const SizedBox(height: RasqSpacing.xs),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // テキスト加工プラグインの ON / OFF チップ (契約 v0.14 §2.3)。
                  if (ref.watch(composerTextPluginsProvider).isNotEmpty) _textPluginChips(ref.watch(composerTextPluginsProvider)),
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
                    onChanged: (_) {
                      _scheduleMentionSearch(); // @ 補完 (D-285)
                      _syncStickHeight();
                      _scheduleTargetEval(); // ポスト先の条件を打ち直し毎に再評価 (D-116)
                      _scheduleTextPlugins(); // テキスト加工プラグイン (D-167)
                    },
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
                  itemBuilder: (_, i) => _AttachmentTile(
                    a: _files[i],
                    onRemove: () => setState(() => _files.removeAt(i)),
                    onToggleSensitive: () => setState(() => _files[i].sensitive = !_files[i].sensitive),
                    // プラグインで加工 (D-167): スロット `composer.media` の登録があるときだけ。
                    onEdit: () => _editAttachment(_files[i]),
                  ),
                ),
              ),
            if (_poll != null) PollEditor(draft: _poll!, maxChoices: _rasqTarget ? rasqPostMaxPollChoices : 10, onRemove: () => setState(() => _poll = null)),
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
      // @ 補完の候補 (D-285): 本文で `@…` を打っている間だけ、ツールバーの上に並ぶ。押すと、その場のメンションに置き換わる。
      if (_mentionHits.isNotEmpty)
        SizedBox(
          key: const ValueKey('composer.mentions'),
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.sm), children: [
            for (final h in _mentionHits)
              Padding(
                padding: const EdgeInsets.only(right: 6, top: 4, bottom: 4),
                child: ActionChip(
                  key: ValueKey('composer.mention.${h.insert}'),
                  avatar: RasqAvatar(imageUrl: h.avatarUrl, size: 20, fallbackLabel: h.name),
                  label: Text('${h.name}  ${h.insert}', style: RasqTypography.caption),
                  onPressed: () => _applyMention(h.insert),
                ),
              ),
          ]),
        ),
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
                RasqActionButton.icon(icon: Icons.image_outlined, tooltip: '画像', onTap: _busy || _files.length >= _maxFiles ? null : () => _pick()),
                Builder(builder: (ctx) => RasqActionButton.icon(icon: Icons.videocam_outlined, tooltip: '動画 / 音声', onTap: _busy || _files.length >= _maxFiles ? null : () {
                  final box = ctx.findRenderObject() as RenderBox;
                  _pickVideo(box.localToGlobal(Offset.zero) & box.size);
                })),
                RasqActionButton.icon(icon: Icons.visibility_outlined, doneIcon: Icons.visibility, done: _cwOn, tooltip: '隠す(注釈)', onTap: () => setState(() => _cwOn = !_cwOn)),
                if (!_isDm) RasqActionButton.icon(icon: Icons.poll_outlined, doneIcon: Icons.poll, done: _poll != null, tooltip: '投票', onTap: () => setState(() => _poll = _poll == null ? PollDraft() : null)),
                RasqActionButton.icon(
                  icon: Icons.emoji_emotions_outlined,
                  tooltip: '絵文字',
                  // 絵文字は、**投稿するアカウント**のサーバーのもの (D-278。切り替えに追従する)。
                  onTap: () => openEmojiPicker(ref, ownerId: composerFowId, column: _column, predictionContext: _text.text, accountKey: _effectivePostAs?.account.key, onPick: (e) {
                    _insert(e);
                    _focus.requestFocus();
                  }),
                ),
                // MFM/Markdown ピッカー (D-045/D-046: 起動ボタンはツールバー側)。
                Builder(builder: (context) {
                  // 投稿するアカウントの SNS に合わせる (D-278。切り替えに追従する)。RASQ 指定のときは装飾を送れないので Markdown 側。
                  final mfm = !_rasqTarget && (_effectivePostAs?.account ?? ref.watch(currentAccountProvider))?.kind == SnsKind.misskey;
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
  const _AttachmentTile({required this.a, required this.onRemove, required this.onToggleSensitive, this.onEdit});
  final _Attachment a;
  final VoidCallback onRemove;
  final VoidCallback onToggleSensitive;

  /// プラグインで加工 (D-167)。null なら出さない。
  final VoidCallback? onEdit;
  bool get _isAudio => (a.mimeType ?? '').startsWith('audio/');
  bool get _isVideo => (a.mimeType ?? '').startsWith('video/') || _isAudio;

  @override
  Widget build(BuildContext context) => Stack(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          // 動画 (D-174) / 音声 (D-250): サムネイルは作らず 再生 / 波形 のアイコン + ファイル名。
          child: _isVideo
              ? Container(
                  width: 88,
                  height: 88,
                  color: Colors.black87,
                  padding: const EdgeInsets.all(6),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(_isAudio ? Icons.graphic_eq : Icons.play_circle_outline, color: Colors.white, size: 28),
                    const SizedBox(height: 4),
                    Text(a.name, style: RasqTypography.caption.copyWith(color: Colors.white70, fontSize: 9), maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                  ]),
                )
              : Image.memory(a.bytes, width: 88, height: 88, fit: BoxFit.cover, gaplessPlayback: true),
        ),
        Positioned(right: 0, top: 0, child: RasqIconButton(icon: Icons.cancel, size: 18, color: Colors.white, onPressed: onRemove, tooltip: '削除')),
        if (onEdit != null) Positioned(right: 0, bottom: 0, child: RasqIconButton(icon: Icons.auto_fix_high, size: 18, color: Colors.white, onPressed: onEdit, tooltip: '加工')),
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

/// キャンセル時のポップアップの選択 (D-177)。
enum _CloseChoice { overwrite, saveNew, discard }

/// [caret] の直前で打っている途中のメンション (D-285 → D-289): `(@ の位置, @ のあとの文字)`。
/// - `@` のあとは、**空白と `@` 以外なら何でも**(日本語の表示名で探せるように。以前は英数字だけで、日本語を打つと反応しなかった)。
/// - `@` の前は、行頭 / 空白 / 記号 / **日本語の文字**(日本語は語の間に空白を入れない)。英数字や `.` の直後は拾わない(メールアドレスの途中)。
/// - `@user@host` の host を打っている途中も、まとめて 1 つ(検索には user の部分を使う)。
(int, String)? mentionQueryAt(String text, int caret) {
  if (caret < 0 || caret > text.length) return null;
  final m = RegExp(r'(?:^|[^A-Za-z0-9_.@])@([^\s@]*)(?:@[A-Za-z0-9_.-]*)?$').firstMatch(text.substring(0, caret));
  if (m == null) return null;
  return (text.substring(0, caret).indexOf('@', m.start), m.group(1)!);
}

/// 連動の計画の中で、RASQ アカウントを表す仮のセッションの pluginId (D-286)。
const rasqLinkPluginId = 'rasq.central';
