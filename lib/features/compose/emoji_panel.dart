import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import '../home/reaction_history.dart';
import '../emoji/emoji_index.dart';
import '../emoji/emoji_index_providers.dart';
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
  const EmojiPanel({super.key, required this.onPick, this.accountKey, this.height, this.predictionContext, this.existingReactions = const {}, this.actionBar, this.spec, this.stickers});
  final ValueChanged<String> onPick;

  /// どのアカウントのカスタム絵文字を出すか (D-278)。null = いま表示しているアカウント。
  final String? accountKey;

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

  /// **ステッカーのピッカー**として使う (D-273: RASQ の投稿のキュー)。渡すと、絵文字(デフォルト / サーバー)の代わりに
  /// これを並べる: 履歴 → 予測 → パックごと。作りは絵文字のときと同じ(検索 / 省略表示 / 予測)。[onPick] には [EmojiPanelSticker.key] が来る。
  final List<EmojiPanelSticker>? stickers;

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

  /// バー(= この系統の FOW 内ヘッダー)を掴んでドラッグ:
  /// 上下 → 離した位置で上付き/下付きが決まる。
  /// 左右 → カラム間移動(moveDx で追従し、離すとホストが精算 — D-062)。
  /// 枠線は内側にだけ引く(枠の外周線と二重にならないように)。
  Widget _grabbableBar(BuildContext context, Widget bar, {required bool onTop}) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => setState(() {
          _draggingBar = true;
          _barDragDelta = 0;
          widget.spec?.dragging.value = true;
          widget.spec?.moveDx.value = 0;
        }),
        onPanUpdate: (d) {
          _barDragDelta += d.delta.dy;
          widget.spec?.moveDx.value += d.delta.dx;
        },
        onPanEnd: (_) => setState(() {
          _draggingBar = false;
          final spec = widget.spec;
          if (spec != null) {
            spec.dragging.value = false;
            final dx = spec.moveDx.value;
            spec.moveDx.value = 0;
            if (dx.abs() > 40) {
              spec.settleMove?.call(dx, 0); // 横が主 → カラム間移動の精算
              return;
            }
          }
          // 24px 以上動かしたら方向で確定(上へ = バーが上辺 = 下方向へつく)。
          if (_barDragDelta.abs() > 24) _barOnTopOverride = _barDragDelta < 0;
        }),
        onPanCancel: () => setState(() {
          _draggingBar = false;
          widget.spec?.dragging.value = false;
          widget.spec?.moveDx.value = 0;
        }),
        child: Container(
          decoration: BoxDecoration(
            border: onTop
                ? Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant))
                : Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
          ),
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
        // ハンドルをその場で長押し = FOW スイッチャー (D-065/D-066: プレビュー付き。D-340 でタップから長押しへ)。
        onLongPress: () => OverlayScope.read(context).openFowSwitcher(),
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
    final custom = ref.watch(customEmojisForProvider(widget.accountKey));
    final recent = ref.watch(recentEmojiProvider);
    final q = _q.text.trim().toLowerCase();

    // フラットな行リストを組み立てる(重い Widget 生成は各行の build まで遅延)。
    final rows = <Widget Function()>[];
    final stickers = widget.stickers;
    void label(String t) => rows.add(() => _label(t));
    void grid(List<_CellSpec> cells) => rows.add(() => _grid([for (final c in cells) _EmojiCell(text: c.text, url: c.url, file: c.file, tooltip: c.tooltip, onTap: () => _pick(c.text))]));
    void chunked(List<_CellSpec> cells) {
      for (var i = 0; i < cells.length; i += EmojiPanel.chunkSize) {
        final chunk = cells.sublist(i, (i + EmojiPanel.chunkSize).clamp(0, cells.length));
        grid(chunk);
      }
    }

    _CellSpec spec(EmojiInfo e) => _CellSpec(':${e.name}:', e.url);

    if (stickers != null) {
      _stickerRows(stickers, q, scheme, label: label, grid: grid, chunked: chunked, rows: rows);
    }
    if (stickers == null) {
    if (q.isEmpty && recent.isNotEmpty) {
      // 履歴は全アカウント共通なので、**このアカウントのサーバーに無いカスタム絵文字は出さない** (D-282。
      // 以前は別のアカウントの絵文字が並び、「ピッカーの中身が切り替わらない」ように見えていた)。
      final usable = [for (final e in recent) if (_usable(e, custom.value)) e];
      if (usable.isNotEmpty) {
        label('履歴');
        grid([for (final e in usable) _CellSpec(e, _urlFor(e, custom.value))]);
      }
    }
    if (q.isEmpty) {
      // 予測も同じ: 履歴 / 付いているリアクション(他サーバーのものは名前だけ借りている)由来の、このサーバーに無い絵文字は出さない。
      final predicted = [for (final e in _prediction(custom.value)) if (_usable(e, custom.value)) e];
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
        // 検索 (D-290): これまでの部分一致は必ず入り、端末の埋め込みモデルがあれば、意味の近い絵文字を後ろに足す。
        // 意味検索の点数は非同期に来る(来るまでは部分一致だけを出す。来たら並びが伸びる)。
        final semantic = q.isEmpty ? null : ref.watch(emojiSearchProvider((accountKey: widget.accountKey, query: q))).value;
        final filtered = filterAndRankEmojis(list, q, semantic);
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

    }

    return Container(
      height: widget.height,
      // リアクションピッカー(ヘッダーレス)ではバーが枠の上辺そのものなので
      // 上枠線を引かない(枠の外周線と二重になるため)。
      decoration: widget.spec != null ? null : BoxDecoration(border: Border(top: BorderSide(color: scheme.outlineVariant))),
      child: LayoutBuilder(builder: (context, constraints) {
        final bar = widget.actionBar;
        // 既定は「下方向へつく」= バーが上辺(ワイヤーフレーム 1p 左下)。
        // 表示余白が最小配列より小さければ逆付きに。バーを掴んで離した
        // 手動指定があればそれを優先する (D-053)。
        final onTop = _barOnTopOverride ?? !(constraints.maxHeight.isFinite && constraints.maxHeight < EmojiPanel.actionBarFlipHeight);
        final hasEdgeHandle = bar != null && widget.spec != null;
        // ⚠ 子にはキーを付ける: キーボードで高さが縮むとバー / ハンドルの上下が入れ替わる。キーが無いと検索欄が作り直されて
        // フォーカスが外れ、キーボードが閉じて元に戻る(大きいキーボードで検索欄が一瞬で閉じていた、D-351)。
        return Column(mainAxisSize: MainAxisSize.max, children: [
          if (bar != null && onTop) KeyedSubtree(key: const ValueKey('emoji.bar.top'), child: _grabbableBar(context, bar, onTop: true)),
          if (hasEdgeHandle && !onTop) KeyedSubtree(key: const ValueKey('emoji.handle.top'), child: _edgeHandle(context)), // バーが下 → ハンドルは上
          Padding(
            key: const ValueKey('emoji.search'),
            padding: const EdgeInsets.fromLTRB(RasqSpacing.md, RasqSpacing.sm, RasqSpacing.md, 4),
            child: RasqSearchBar(controller: _q, hintText: '検索', onChanged: (_) => setState(() {})),
          ),
          // 意味検索の索引づくり (D-290): ピッカーを開いたら裏で始める(モデルを入れてあるときだけ)。進み具合を 1 行で出す。
          if (stickers == null) _EmojiIndexProgressLine(key: const ValueKey('emoji.index'), accountKey: widget.accountKey),
          Expanded(
            key: const ValueKey('emoji.list'),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(RasqSpacing.md, 0, RasqSpacing.md, 12),
              itemCount: rows.length,
              itemBuilder: (_, i) => rows[i](),
            ),
          ),
          if (hasEdgeHandle && onTop) KeyedSubtree(key: const ValueKey('emoji.handle.bottom'), child: _edgeHandle(context)), // バーが上 → ハンドルは下
          if (bar != null && !onTop) KeyedSubtree(key: const ValueKey('emoji.bar.bottom'), child: _grabbableBar(context, bar, onTop: false)),
        ]);
      }),
    );
  }

  // ── ステッカーのピッカー (D-273) ──
  List<String>? _stickerPredicted;

  void _stickerRows(
    List<EmojiPanelSticker> stickers,
    String q,
    ColorScheme scheme, {
    required void Function(String) label,
    required void Function(List<_CellSpec>) grid,
    required void Function(List<_CellSpec>) chunked,
    required List<Widget Function()> rows,
  }) {
    _CellSpec cell(EmojiPanelSticker s) => _CellSpec(s.key, s.url, file: s.file, tooltip: s.label ?? s.key);
    final byKey = {for (final s in stickers) s.key: s};
    if (stickers.isEmpty) {
      rows.add(() => Padding(padding: const EdgeInsets.all(8), child: Text('使えるアセットパックがありません(ストアからインストールできます)', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant))));
      return;
    }
    if (q.isNotEmpty) {
      final hit = [for (final s in stickers) if (s.matches(q)) s];
      label('検索結果');
      if (hit.isEmpty) {
        rows.add(() => Padding(padding: const EdgeInsets.all(8), child: Text('見つかりません', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant))));
      } else {
        chunked([for (final s in hit) cell(s)]);
      }
      return;
    }
    // 履歴: 絵文字と同じ置き場(最近使ったもの)から、ステッカーのものだけ。
    final recent = [for (final k in ref.watch(recentEmojiProvider)) if (byKey[k] != null) byKey[k]!];
    if (recent.isNotEmpty) {
      label('履歴');
      grid([for (final s in recent) cell(s)]);
    }
    // 予測: 絵文字の予測と同じ式(本文との語句一致 / 既に付いているもの / 最近使った)を、ラベルとタグに当てる。
    _stickerPredicted ??= predictEmojis(
      context: widget.predictionContext ?? '',
      existingReactions: {for (final e in widget.existingReactions.entries) ':${e.key}:': e.value},
      recent: [for (final k in ref.read(recentEmojiProvider)) if (byKey[k] != null) ':$k:'],
      custom: [for (final s in stickers) EmojiInfo(name: s.key, url: s.url ?? Uri(), aliases: [if (s.label != null) s.label!, ...s.tags])],
    );
    final predicted = [for (final p in _stickerPredicted!) if (byKey[p.substring(1, p.length - 1)] != null) byKey[p.substring(1, p.length - 1)]!];
    if (predicted.isNotEmpty) {
      label('予測');
      grid([for (final s in predicted) cell(s)]);
    }
    // パックごと(絵文字のジャンルと同じ省略表示)。
    final byPack = <String, List<EmojiPanelSticker>>{};
    for (final s in stickers) {
      byPack.putIfAbsent(s.group, () => []).add(s);
    }
    for (final entry in byPack.entries) {
      final open = _expanded.contains(entry.key) || byPack.length == 1;
      rows.add(() => InkWell(
            onTap: () => setState(() => open ? _expanded.remove(entry.key) : _expanded.add(entry.key)),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(children: [
                Expanded(child: Text('・${entry.key}', style: RasqTypography.caption.copyWith(fontWeight: FontWeight.w700))),
                Text('${entry.value.length}', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
                if (byPack.length > 1) Icon(open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 16, color: scheme.onSurfaceVariant),
              ]),
            ),
          ));
      if (open) {
        chunked([for (final s in entry.value) cell(s)]);
      } else {
        grid([for (final s in entry.value.take(EmojiPanel.collapsedCount)) cell(s)]);
      }
    }
  }

  // このアカウントのサーバーにあるカスタム絵文字の名前(一覧が変わったときだけ作り直す)。
  Set<String>? _names;
  List<EmojiInfo>? _namesFrom;

  /// このアカウントで使える絵文字か: Unicode はいつでも、カスタム(`:name:`)はサーバーの一覧にあるものだけ(読み込み中は出さない)。
  bool _usable(String e, List<EmojiInfo>? custom) {
    if (!e.startsWith(':')) return true;
    if (custom == null) return false;
    if (_names == null || !identical(_namesFrom, custom)) {
      _names = {for (final c in custom) c.name};
      _namesFrom = custom;
    }
    return _names!.contains(e.substring(1, e.length - 1).split('@').first);
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
  const _CellSpec(this.text, this.url, {this.file, this.tooltip});
  final String text;
  final Uri? url;

  /// 端末上の画像(インストール済みのアセットパックのステッカー)。
  final String? file;
  final String? tooltip;
}

/// ステッカー 1 枚(ピッカーに並べる)。[key] = 選んだときに返す文字列、[group] = パックの名前。
@immutable
class EmojiPanelSticker {
  const EmojiPanelSticker({required this.key, required this.group, this.label, this.tags = const [], this.file, this.url});
  final String key;
  final String group;
  final String? label;
  final List<String> tags;
  final String? file;
  final Uri? url;

  bool matches(String q) => (label ?? '').toLowerCase().contains(q) || key.toLowerCase().contains(q) || group.toLowerCase().contains(q) || tags.any((t) => t.toLowerCase().contains(q));
}

class _EmojiCell extends StatelessWidget {
  const _EmojiCell({required this.text, required this.onTap, this.url, this.file, this.tooltip});
  final String text;
  final Uri? url;
  final String? file;
  final String? tooltip;
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
          child: Center(
            widthFactor: 1,
            child: file != null
                ? Tooltip(message: tooltip ?? text, child: Image.file(File(file!), key: ValueKey('emoji.sticker.$text'), height: 30, fit: BoxFit.contain, errorBuilder: (_, _, _) => const Icon(Icons.image_not_supported_outlined, size: 20)))
                : RasqCustomEmoji(url: url, fallbackText: text, height: 26, name: text.startsWith(':') ? text.replaceAll(':', '') : text),
          ),
        ),
      );
}

/// 「意味検索を準備中 n / m」(D-290)。索引づくりを始める役も兼ねる(この行が、索引の provider を見ている)。
class _EmojiIndexProgressLine extends ConsumerWidget {
  const _EmojiIndexProgressLine({super.key, required this.accountKey});
  final String? accountKey;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(emojiIndexProvider(accountKey));
    ref.watch(emojiImageIndexProvider(accountKey)); // 絵そのものの索引 (D-293。画像側のモデルがあるときだけ)
    final all = ref.watch(emojiIndexProgressProvider);
    final p = all[accountKey ?? '_current'] ?? all['${accountKey ?? '_current'}#image'];
    if (p == null || p.$2 == 0 || p.$1 >= p.$2) return const SizedBox.shrink();
    return Padding(
      key: const ValueKey('emoji.index.progress'),
      padding: const EdgeInsets.fromLTRB(RasqSpacing.md, 0, RasqSpacing.md, 4),
      child: Text('意味検索を準備中 ${p.$1} / ${p.$2}', style: RasqTypography.caption.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );
  }
}
