import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import '../../l10n/l10n.dart';
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
List<MfmFn> get mfmFunctions => <MfmFn>[
  MfmFn('x2', appL10n.composeMfmFnX2),
  MfmFn('x3', appL10n.composeMfmFnX3),
  MfmFn('x4', appL10n.composeMfmFnX4),
  MfmFn('small', appL10n.composeMfmFnSmall),
  MfmFn('center', appL10n.composeMfmFnCenter),
  MfmFn('blur', appL10n.composeMfmFnBlur),
  MfmFn('rotate', appL10n.composeMfmFnRotate, props: [MfmProp('deg', hint: appL10n.composeMfmPropRotateDeg)]),
  MfmFn('flip', appL10n.composeMfmFnFlip, props: [MfmProp('h', hint: appL10n.composeMfmPropFlipH, flag: true), MfmProp('v', hint: appL10n.composeMfmPropFlipV, flag: true)]),
  MfmFn('fg', appL10n.composeMfmFnFg, props: [MfmProp('color', hint: appL10n.composeMfmPropFgColor)]),
  MfmFn('bg', appL10n.composeMfmFnBg, props: [MfmProp('color', hint: appL10n.composeMfmPropBgColor)]),
  MfmFn('shake', appL10n.composeMfmFnShake, props: [MfmProp('speed', hint: appL10n.composeMfmPropShakeSpeed)]),
  MfmFn('spin', appL10n.composeMfmFnSpin, props: [MfmProp('speed', hint: appL10n.composeMfmPropSpinSpeed), MfmProp('left', hint: appL10n.composeMfmPropSpinLeft, flag: true), MfmProp('alternate', hint: appL10n.composeMfmPropSpinAlternate, flag: true), MfmProp('x', hint: appL10n.composeMfmPropSpinX, flag: true), MfmProp('y', hint: appL10n.composeMfmPropSpinY, flag: true)]),
  MfmFn('jump', appL10n.composeMfmFnJump, props: [MfmProp('speed', hint: appL10n.composeMfmPropJumpSpeed)]),
  MfmFn('bounce', appL10n.composeMfmFnBounce, props: [MfmProp('speed', hint: appL10n.composeMfmPropBounceSpeed)]),
  MfmFn('rainbow', appL10n.composeMfmFnRainbow, props: [MfmProp('speed', hint: appL10n.composeMfmPropRainbowSpeed)]),
  MfmFn('twitch', appL10n.composeMfmFnTwitch, props: [MfmProp('speed', hint: appL10n.composeMfmPropTwitchSpeed)]),
  MfmFn('jelly', appL10n.composeMfmFnJelly, props: [MfmProp('speed', hint: appL10n.composeMfmPropJellySpeed)]),
  MfmFn('tada', appL10n.composeMfmFnTada, props: [MfmProp('speed', hint: appL10n.composeMfmPropTadaSpeed)]),
  MfmFn('plain', appL10n.composeMfmFnPlain),
];

/// Markdown カタログ(MFM 非対応 SNS 向け。固定スニペット)。
List<MfmFn> get markdownFunctions => <MfmFn>[
  MfmFn(appL10n.composeMfmMarkdownBoldName, appL10n.composeMfmMarkdownBoldDescription, prefix: '**', suffix: '**'),
  MfmFn(appL10n.composeMfmMarkdownItalicName, appL10n.composeMfmMarkdownItalicDescription, prefix: '*', suffix: '*'),
  MfmFn(appL10n.composeMfmMarkdownStrikeName, appL10n.composeMfmMarkdownStrikeDescription, prefix: '~~', suffix: '~~'),
  MfmFn(appL10n.composeMfmMarkdownInlineCodeName, appL10n.composeMfmMarkdownInlineCodeDescription, prefix: '`', suffix: '`'),
  MfmFn(appL10n.composeMfmMarkdownCodeBlockName, appL10n.composeMfmMarkdownCodeBlockDescription, prefix: '```\n', suffix: '\n```'),
  MfmFn(appL10n.composeMfmMarkdownHeadingName, appL10n.composeMfmMarkdownHeadingDescription, prefix: '# ', suffix: ''),
  MfmFn(appL10n.composeMfmMarkdownLinkName, appL10n.composeMfmMarkdownLinkDescription, prefix: '[', suffix: '](url)'),
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

Future<void> openMfmPicker(WidgetRef ref, {String? ownerId, required void Function(String prefix, String suffix) onApply, required bool mfm, int column = 0}) async {
  final manager = ref.read(overlayManagerProvider);
  final title = mfm ? 'MFM' : 'Markdown';
  // 横ドッキング (D-062): ヘッダー(FowMoveGrip)を掴んで左右カラムへ移動。
  final spec = FowSpec(type: FowPanelType.widget, initialHeightFactor: 0.5, minHeightFactor: 0.3, maxHeightFactor: 0.85, title: title, cancelText: appL10n.composeMfmClose, dockAboveFooter: true, columnIndex: column);
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
    var sample = context.l10n.composeMfmSample;
    if (_sampleEmoji != null) {
      sample = context.l10n.composeMfmSampleWithEmoji(':$_sampleEmoji:');
      final info = (ref.watch(customEmojisProvider).value ?? const []).where((e) => e.name == _sampleEmoji).firstOrNull;
      emojiUrls[_sampleEmoji!] = info?.url;
    }
    final (prefix, suffix) = mfmSnippet(fn, _values);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.sm, 0, RasqSpacing.sm, 0),
        child: Row(children: [
          RasqIconButton(icon: Icons.arrow_back, size: 20, tooltip: context.l10n.composeMfmBackTooltip, onPressed: () => setState(() => _fn = null)),
          const SizedBox(width: 4),
          Expanded(child: Text(fn.name, style: RasqTypography.body.copyWith(fontWeight: FontWeight.w700))),
          FilledButton(
            onPressed: () => widget.onApply(prefix, suffix),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 16)),
            child: Text(context.l10n.composeMfmApply),
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
            ? Padding(padding: const EdgeInsets.all(RasqSpacing.page), child: Text(context.l10n.composeMfmNoProps, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)))
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
