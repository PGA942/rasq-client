import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import '../home/reaction_history.dart';
import 'compose_providers.dart';
import 'emoji_prediction.dart';

/// 絵文字ピッカー (D-040/D-043: 検索 / 履歴 / 予測 / デフォルト / サーバー).
/// Emits the text to insert (`😀` or `:shortcode:`).
///
/// - 「予測」= 文脈([predictionContext])× 利用履歴 × 既存リアクションの
///   ルールベース予測(SigLIP/GLiNER 配線後に前段を強化 — 絵文字予測.md)
/// - 「デフォルト」(旧: 全てのemoji)は見出し長押しでバンドル編集(FOW)へ
///   移行する予定(M4 のプレースホルダー)
/// - 「サーバー」= 独自の絵文字を**サーバー設定のジャンル(category)毎に
///   省略表示**(ワイヤーフレーム準拠): 折りたたみ時は先頭 1 行分だけ、
///   ∨ で全件展開する
///
/// パフォーマンス (D-043): 全体を `ListView.builder` のフラットな行リストに
/// し、展開中のジャンルも [chunkSize] 個ずつの Wrap 行アイテムに分割して
/// **画面に入った行だけビルド**する。従来のセル毎 VisibilityDetector は
/// 数千個のコールバック登録が FPS を殺していたため廃止(ListView の遅延
/// ビルドが同じ役割をゼロコストで果たす)。
class EmojiPanel extends ConsumerStatefulWidget {
  const EmojiPanel({super.key, required this.onPick, this.height, this.predictionContext, this.existingReactions = const {}, this.actionBar, this.spec});
  final ValueChanged<String> onPick;

  /// Fixed height; null = fill the parent (FOW panel).
  final double? height;

  /// 投稿への絵文字コンポーザー (D-052/D-053): 対象投稿のアクションボタン。
  /// 既定は**下方向へつく**(= バーがパネル上辺、ワイヤーフレーム 1p 左下)。
  /// バー(ヘッダー枠)を掴んで上下にドラッグすると、**掴んでいる間は
  /// ドラッグハンドルが消失**し、離した位置でボタンに対して上付き/下付き
  /// (+ハンドルを上下どちらに出すか)が決定する。表示余白が最小配列
  /// ([actionBarFlipHeight])より小さいときは自動で逆付きになる。
  /// (未実装の第3カラムへの移動も将来同じ手法。)
  final Widget? actionBar;

  /// これより低いパネルではバーを逆側に付ける。
  static const actionBarFlipHeight = 240.0;

  /// リアクションピッカー時の FOW spec (D-053)。バーの反対側に出す
  /// **外縁ハンドル**のリサイズ/スナップに使う(ホスト側ハンドルは消す)。
  final FowSpec? spec;

  /// 予測の文脈(CW + 本文 + 親/引用。コンポーザーでは下書きテキスト)。
  final String? predictionContext;

  /// 対象投稿に既に付いているリアクション(リアクション用途のとき)。
  final Map<String, int> existingReactions;

  static const unicode = ['😀', '😂', '🥹', '😍', '🤔', '😭', '😡', '🥳', '😴', '🙏', '👍', '👎', '👏', '🙌', '💪', '❤️', '💔', '🔥', '✨', '🎉', '🚀', '🌙', '☀️', '🌸', '🍣', '🍜', '☕', '🍺', '🐱', '🐶', '🐟', '🦀', '💡', '📌', '✅', '❌', '⚠️', '💯', '🆗', '🔁'];

  /// 折りたたみ時に見せる件数(≒ 1 行分)。
  static const collapsedCount = 12;

  /// 展開時の 1 リストアイテムあたりのセル数。
  static const chunkSize = 40;

  @override
  ConsumerState<EmojiPanel> createState() => _EmojiPanelState();
}

class _EmojiPanelState extends ConsumerState<EmojiPanel> {
  final _q = TextEditingController();
  final _expanded = <String>{};

  /// アクションバー(= 掴めるヘッダー枠)の位置 (D-052/D-053)。
  /// null = 自動(パネル高さで判定)、true/false = ドラッグによる手動指定。
  bool? _barOnTopOverride;
  bool _draggingBar = false; // 掴んでいる間はドラッグハンドルが消失する
  double _barDragDelta = 0;

  /// バーを掴んで上下へドラッグ → 離した位置で上付き/下付きが決まる。
  Widget _grabbableBar(BuildContext context, Widget bar) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: (_) => setState(() {
          _draggingBar = true;
          _barDragDelta = 0;
        }),
        onVerticalDragUpdate: (d) => _barDragDelta += d.delta.dy,
        onVerticalDragEnd: (_) => setState(() {
          _draggingBar = false;
          // 24px 以上動かしたら方向で確定(上へ = バーが上辺 = 下方向へつく)。
          if (_barDragDelta.abs() > 24) _barOnTopOverride = _barDragDelta < 0;
        }),
        onVerticalDragCancel: () => setState(() => _draggingBar = false),
        child: Container(
          decoration: BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: Theme.of(context).colorScheme.outlineVariant))),
          child: bar,
        ),
      );

  /// バーの反対側(外縁)に出すドラッグハンドル。バーを掴んでいる間は消える。
  Widget _edgeHandle(BuildContext context) {
    final spec = widget.spec;
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: _draggingBar ? 0 : 1,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: spec == null ? null : (_) => spec.dragging.value = true,
        onVerticalDragUpdate: spec == null ? null : (d) => spec.resizeBy(d.delta.dy / MediaQuery.sizeOf(context).height),
        onVerticalDragEnd: spec == null
            ? null
            : (_) {
                spec.dragging.value = false;
                spec.snapToStops();
              },
        onVerticalDragCancel: spec == null ? null : () => spec.dragging.value = false,
        child: Semantics(
          label: 'サイズ変更ハンドル',
          child: SizedBox(
            height: 18,
            width: double.infinity,
            child: Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: scheme.onSurface, borderRadius: BorderRadius.circular(2)))),
          ),
        ),
      ),
    );
  }

  // 予測は毎ビルド再計算しない(カスタム絵文字数千件の走査になるため)。
  List<String>? _predicted;
  List<EmojiInfo>? _predictedFrom;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  void _pick(String e) {
    ref.read(recentEmojiProvider.notifier).push(e);
    widget.onPick(e);
  }

  List<String> _prediction(List<EmojiInfo>? custom) {
    if (_predicted == null || !identical(_predictedFrom, custom)) {
      _predicted = predictEmojis(
        context: widget.predictionContext ?? '',
        existingReactions: widget.existingReactions,
        history: ref.read(reactionHistoryProvider).value ?? const {},
        recent: ref.read(recentEmojiProvider),
        custom: custom ?? const [],
      );
      _predictedFrom = custom;
    }
    return _predicted!;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final custom = ref.watch(customEmojisProvider);
    final recent = ref.watch(recentEmojiProvider);
    final q = _q.text.trim().toLowerCase();

    // フラットな行リストを組み立てる(重い Widget 生成は各行の build まで遅延)。
    final rows = <Widget Function()>[];
    void label(String t) => rows.add(() => _label(t));
    void grid(List<_CellSpec> cells) => rows.add(() => _grid([for (final c in cells) _EmojiCell(text: c.text, url: c.url, onTap: () => _pick(c.text))]));
    void chunked(List<_CellSpec> cells) {
      for (var i = 0; i < cells.length; i += EmojiPanel.chunkSize) {
        final chunk = cells.sublist(i, (i + EmojiPanel.chunkSize).clamp(0, cells.length));
        grid(chunk);
      }
    }

    _CellSpec spec(EmojiInfo e) => _CellSpec(':${e.name}:', e.url);

    if (q.isEmpty && recent.isNotEmpty) {
      label('履歴');
      grid([for (final e in recent) _CellSpec(e, _urlFor(e, custom.value))]);
    }
    if (q.isEmpty) {
      final predicted = _prediction(custom.value);
      if (predicted.isNotEmpty) {
        label('予測');
        grid([for (final e in predicted) _CellSpec(e, _urlFor(e, custom.value))]);
      }
    }
    rows.add(() => InkWell(
          onLongPress: () => ref.read(overlayManagerProvider).showAlert(id: 'emoji.bundle', title: 'バンドル編集', message: 'デフォルト欄のバンドル編集(FOW)は M4 で実装します。', confirmText: 'OK'),
          child: _label('デフォルト'),
        ));
    chunked([for (final e in EmojiPanel.unicode) _CellSpec(e, null)]);

    // サーバー(独自の絵文字): ジャンル毎に省略表示 (D-043)。
    switch (custom) {
      case AsyncData(value: final list):
        final filtered = q.isEmpty ? list : [for (final e in list) if (e.name.toLowerCase().contains(q) || e.aliases.any((a) => a.toLowerCase().contains(q))) e];
        if (filtered.isEmpty) {
          rows.add(() => Padding(padding: const EdgeInsets.all(8), child: Text('独自の絵文字はありません', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant))));
        } else if (q.isNotEmpty) {
          // 検索中はジャンルを跨いだフラット表示。
          label('サーバー');
          chunked([for (final e in filtered) spec(e)]);
        } else {
          label('サーバー');
          // サーバーが設定したジャンル(category)毎。挿入順を維持。
          final byGenre = <String, List<EmojiInfo>>{};
          for (final e in filtered) {
            byGenre.putIfAbsent(e.category ?? 'その他', () => []).add(e);
          }
          for (final entry in byGenre.entries) {
            final genre = entry.key;
            final open = _expanded.contains(genre);
            rows.add(() => InkWell(
                  onTap: () => setState(() => open ? _expanded.remove(genre) : _expanded.add(genre)),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(children: [
                      Expanded(child: Text('・$genre', style: RasqTypography.caption.copyWith(fontWeight: FontWeight.w700))),
                      Text('${entry.value.length}', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
                      Icon(open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 16, color: scheme.onSurfaceVariant),
                    ]),
                  ),
                ));
            if (open) {
              chunked([for (final e in entry.value) spec(e)]);
            } else {
              grid([for (final e in entry.value.take(EmojiPanel.collapsedCount)) spec(e)]);
            }
          }
        }
      case AsyncLoading():
        rows.add(() => const RasqLoading());
      default:
        break;
    }

    return Container(
      height: widget.height,
      decoration: BoxDecoration(border: Border(top: BorderSide(color: scheme.outlineVariant))),
      child: LayoutBuilder(builder: (context, constraints) {
        final bar = widget.actionBar;
        // 既定は「下方向へつく」= バーが上辺(ワイヤーフレーム 1p 左下)。
        // 表示余白が最小配列より小さければ逆付きに。バーを掴んで離した
        // 手動指定があればそれを優先する (D-053)。
        final onTop = _barOnTopOverride ?? !(constraints.maxHeight.isFinite && constraints.maxHeight < EmojiPanel.actionBarFlipHeight);
        final hasEdgeHandle = bar != null && widget.spec != null;
        return Column(mainAxisSize: MainAxisSize.max, children: [
          if (bar != null && onTop) _grabbableBar(context, bar),
          if (hasEdgeHandle && !onTop) _edgeHandle(context), // バーが下 → ハンドルは上
          Padding(
            padding: const EdgeInsets.fromLTRB(RasqSpacing.md, RasqSpacing.sm, RasqSpacing.md, 4),
            child: RasqSearchBar(controller: _q, hintText: '検索', onChanged: (_) => setState(() {})),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(RasqSpacing.md, 0, RasqSpacing.md, 12),
              itemCount: rows.length,
              itemBuilder: (_, i) => rows[i](),
            ),
          ),
          if (hasEdgeHandle && onTop) _edgeHandle(context), // バーが上 → ハンドルは下
          if (bar != null && !onTop) _grabbableBar(context, bar),
        ]);
      }),
    );
  }

  static Uri? _urlFor(String e, List<EmojiInfo>? custom) {
    if (!e.startsWith(':') || custom == null) return null;
    final name = e.substring(1, e.length - 1);
    return custom.where((c) => c.name == name).firstOrNull?.url;
  }

  Widget _label(String t) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(t, style: RasqTypography.caption.copyWith(fontWeight: FontWeight.w700)));
  Widget _grid(List<Widget> cells) => Padding(padding: const EdgeInsets.only(top: 4), child: Wrap(spacing: 4, runSpacing: 4, children: cells));
}

class _CellSpec {
  const _CellSpec(this.text, this.url);
  final String text;
  final Uri? url;
}

class _EmojiCell extends StatelessWidget {
  const _EmojiCell({required this.text, required this.onTap, this.url});
  final String text;
  final Uri? url;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          constraints: const BoxConstraints(minWidth: 36),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          // 可変幅表示 + ホバー/長押しチップ (D-040: Miria 方式参考)。
          // widthFactor: 1 で shrink-wrap — 素の Center は有界制約で全幅に
          // 広がり、Wrap で 1 行 1 絵文字になってしまう (D-042 修正)。
          child: Center(widthFactor: 1, child: RasqCustomEmoji(url: url, fallbackText: text, height: 26, name: text.startsWith(':') ? text.replaceAll(':', '') : text)),
        ),
      );
}
