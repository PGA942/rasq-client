import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import '../../shell/third_column.dart';
import '../../text/inline_spans.dart';
import 'compose_providers.dart';

/// MFM/Markdown ピッカー FOW (D-045: コンポーザーヘッダーから)。
///
/// - ホーム画面: 縦方向リスト(タイル = 関数名 + 説明文)
/// - サブページ: 上側にプレビュー(文字列 + ランダムなサーバー絵文字)、
///   下側にプロパティータイル(左 = プロパティー名、右 = 入力欄)の縦リスト。
///   右上の「決定」でコンポーザーに適用され、カーソルはプロパティーにない
///   中身部分へ移動する(挿入は [composerInsertBridgeProvider] 経由)。
const mfmPickerFowId = 'fow.mfm';

/// 1 プロパティー。[flag] は値なしのオン/オフ(`$[flip.h,v …]` の h/v)。
class MfmProp {
  const MfmProp(this.key, {this.hint = '', this.flag = false});
  final String key;
  final String hint;
  final bool flag;
}

/// 1 関数(または Markdown スニペット)。[prefix]/[suffix] があれば固定
/// スニペット(Markdown 系)、なければ MFM `$[name.props 中身]` を組み立てる。
class MfmFn {
  const MfmFn(this.name, this.description, {this.props = const [], this.prefix, this.suffix});
  final String name;
  final String description;
  final List<MfmProp> props;
  final String? prefix;
  final String? suffix;
}

/// MFM カタログ = ホストが描画できるコアセット(PROTOCOL §2.3。プレビューが
/// 必ず動く範囲に限定)。
const mfmFunctions = <MfmFn>[
  MfmFn('x2', '2倍に拡大'),
  MfmFn('x3', '3倍に拡大'),
  MfmFn('x4', '4倍に拡大'),
  MfmFn('small', '小さく表示'),
  MfmFn('center', '中央寄せ'),
  MfmFn('blur', 'ぼかし(ホバー/タップで解除)'),
  MfmFn('rotate', '回転', props: [MfmProp('deg', hint: '角度(既定 90)')]),
  MfmFn('flip', '反転', props: [MfmProp('h', hint: '左右', flag: true), MfmProp('v', hint: '上下', flag: true)]),
  MfmFn('fg', '文字色', props: [MfmProp('color', hint: '16進(例: ff0000)')]),
  MfmFn('bg', '背景色', props: [MfmProp('color', hint: '16進(例: ffff00)')]),
  MfmFn('shake', '振動', props: [MfmProp('speed', hint: '例: 0.5s')]),
  MfmFn('spin', '回転アニメ', props: [MfmProp('speed', hint: '例: 1.5s'), MfmProp('left', hint: '逆回転', flag: true), MfmProp('alternate', hint: '往復', flag: true), MfmProp('x', hint: '横軸', flag: true), MfmProp('y', hint: '縦軸', flag: true)]),
  MfmFn('jump', 'ジャンプ', props: [MfmProp('speed', hint: '例: 0.75s')]),
  MfmFn('bounce', 'バウンド', props: [MfmProp('speed', hint: '例: 0.75s')]),
  MfmFn('rainbow', '虹色', props: [MfmProp('speed', hint: '例: 1s')]),
  MfmFn('twitch', 'ぴくぴく', props: [MfmProp('speed', hint: '例: 0.5s')]),
  MfmFn('jelly', 'ぷるぷる', props: [MfmProp('speed', hint: '例: 1s')]),
  MfmFn('tada', 'じゃーん', props: [MfmProp('speed', hint: '例: 1s')]),
  MfmFn('plain', '装飾を無効化'),
];

/// Markdown カタログ(MFM 非対応 SNS 向け。固定スニペット)。
const markdownFunctions = <MfmFn>[
  MfmFn('太字', '**強調** で表示', prefix: '**', suffix: '**'),
  MfmFn('斜体', '*斜体* で表示', prefix: '*', suffix: '*'),
  MfmFn('取り消し線', '~~取り消し~~ で表示', prefix: '~~', suffix: '~~'),
  MfmFn('インラインコード', '`コード` で表示', prefix: '`', suffix: '`'),
  MfmFn('コードブロック', '複数行のコードを枠で表示', prefix: '```\n', suffix: '\n```'),
  MfmFn('見出し', '行頭に # を付ける', prefix: '# ', suffix: ''),
  MfmFn('リンク', '[表示名](URL) の形', prefix: '[', suffix: '](url)'),
];

/// [values] = プロパティーキー → 入力値(flag は 'true' でオン)から
/// 挿入スニペット (prefix, suffix) を組み立てる。
(String, String) mfmSnippet(MfmFn fn, Map<String, String> values) {
  if (fn.prefix != null) return (fn.prefix!, fn.suffix ?? '');
  final parts = <String>[];
  for (final p in fn.props) {
    final v = (values[p.key] ?? '').trim();
    if (p.flag) {
      if (v == 'true') parts.add(p.key);
    } else if (v.isNotEmpty) {
      parts.add('${p.key}=$v');
    }
  }
  final head = parts.isEmpty ? fn.name : '${fn.name}.${parts.join(',')}';
  return ('\$[$head ', ']');
}

Future<void> openMfmPicker(WidgetRef ref, {String? ownerId, required void Function(String prefix, String suffix) onApply, required bool mfm}) async {
  final manager = ref.read(overlayManagerProvider);
  final title = mfm ? 'MFM' : 'Markdown';
  final spec = FowSpec(type: FowPanelType.widget, initialHeightFactor: 0.5, minHeightFactor: 0.3, maxHeightFactor: 0.85, title: title, cancelText: '閉じる', dockAboveFooter: true);
  // 掴んで第3カラムへ移動 (D-060)。
  spec.onMoveAside = () {
    manager.close(mfmPickerFowId);
    ref.read(thirdColumnProvider.notifier).open(ThirdColumnEntry(
          id: mfmPickerFowId,
          title: title,
          builder: (_) => MfmPickerPanel(
            mfm: mfm,
            onApply: (p, s) {
              onApply(p, s);
              ref.read(thirdColumnProvider.notifier).close(mfmPickerFowId);
            },
          ),
        ));
  };
  await manager.showFow<void>(
    id: mfmPickerFowId,
    ownerId: ownerId,
    // 同手法化 (D-051): 角丸枠 + フッター上にドック + 余白クリックで消失。
    barrierBehavior: OverlayBarrierBehavior.dismissDiscard,
    spec: spec,
    builder: (ctx, handle) => MfmPickerPanel(
      mfm: mfm,
      onApply: (p, s) {
        onApply(p, s);
        handle.close();
      },
    ),
  );
}

class MfmPickerPanel extends ConsumerStatefulWidget {
  const MfmPickerPanel({super.key, required this.onApply, this.mfm = true});
  final bool mfm;
  final void Function(String prefix, String suffix) onApply;

  @override
  ConsumerState<MfmPickerPanel> createState() => _MfmPickerPanelState();
}

class _MfmPickerPanelState extends ConsumerState<MfmPickerPanel> {
  MfmFn? _fn;
  final _ctrls = <String, TextEditingController>{};
  final _flags = <String, bool>{};
  String? _sampleEmoji; // ランダムなサーバー絵文字(サブページ毎に引き直す)

  List<MfmFn> get _catalog => widget.mfm ? mfmFunctions : markdownFunctions;

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _open(MfmFn fn) {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    _ctrls.clear();
    _flags.clear();
    for (final p in fn.props) {
      if (p.flag) {
        _flags[p.key] = false;
      } else {
        _ctrls[p.key] = TextEditingController();
      }
    }
    final emojis = ref.read(customEmojisProvider).value ?? const [];
    _sampleEmoji = emojis.isEmpty ? null : emojis[math.Random().nextInt(emojis.length)].name;
    setState(() => _fn = fn);
  }

  Map<String, String> get _values => {
        for (final e in _ctrls.entries) e.key: e.value.text,
        for (final e in _flags.entries) e.key: '${e.value}',
      };

  @override
  Widget build(BuildContext context) {
    final fn = _fn;
    return fn == null ? _home() : _detail(fn);
  }

  /// ホーム画面: 関数名 + 説明文の縦方向リスト。
  Widget _home() => ListView(
        padding: const EdgeInsets.symmetric(vertical: 4),
        children: [for (final fn in _catalog) RasqListTile(title: fn.name, subtitle: fn.description, onTap: () => _open(fn))],
      );

  /// サブページ: プレビュー + プロパティータイル + 右上の決定。
  Widget _detail(MfmFn fn) {
    final scheme = Theme.of(context).colorScheme;
    final emojiUrls = <String, Uri?>{};
    var sample = 'サンプル';
    if (_sampleEmoji != null) {
      sample = 'サンプル :$_sampleEmoji:';
      final info = (ref.watch(customEmojisProvider).value ?? const []).where((e) => e.name == _sampleEmoji).firstOrNull;
      emojiUrls[_sampleEmoji!] = info?.url;
    }
    final (prefix, suffix) = mfmSnippet(fn, _values);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.sm, 0, RasqSpacing.sm, 0),
        child: Row(children: [
          RasqIconButton(icon: Icons.arrow_back, size: 20, tooltip: '一覧へ戻る', onPressed: () => setState(() => _fn = null)),
          const SizedBox(width: 4),
          Expanded(child: Text(fn.name, style: RasqTypography.body.copyWith(fontWeight: FontWeight.w700))),
          FilledButton(
            onPressed: () => widget.onApply(prefix, suffix),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 16)),
            child: const Text('決定'),
          ),
        ]),
      ),
      // プレビュー: 実際に挿入される MFM をそのままホストレンダラーで描画。
      Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
        padding: const EdgeInsets.all(RasqSpacing.md),
        decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(RasqSizes.radiusSm)),
        child: RasqRichText(InlineSpans.parse('$prefix$sample$suffix', emojis: emojiUrls), style: RasqTypography.body),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 4, RasqSpacing.page, 0),
        child: Text('$prefix…$suffix', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
      ),
      Expanded(
        child: fn.props.isEmpty
            ? Padding(padding: const EdgeInsets.all(RasqSpacing.page), child: Text('この関数にプロパティーはありません。', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)))
            : ListView(
                padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.md),
                children: [
                  for (final p in fn.props)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(children: [
                        SizedBox(
                          width: 120,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(p.key, style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700)),
                            if (p.hint.isNotEmpty) Text(p.hint, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
                          ]),
                        ),
                        const SizedBox(width: RasqSpacing.md),
                        Expanded(
                          child: p.flag
                              ? Align(
                                  alignment: Alignment.centerLeft,
                                  child: Switch(value: _flags[p.key] ?? false, onChanged: (v) => setState(() => _flags[p.key] = v)),
                                )
                              : TextField(
                                  controller: _ctrls[p.key],
                                  decoration: const InputDecoration(isDense: true),
                                  style: RasqTypography.bodySmall,
                                  onChanged: (_) => setState(() {}),
                                ),
                        ),
                      ]),
                    ),
                ],
              ),
      ),
    ]);
  }
}
