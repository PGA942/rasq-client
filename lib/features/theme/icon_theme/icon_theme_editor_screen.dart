import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../../l10n/l10n.dart';
import '../../../mock/mock_data.dart';
import '../../../shell/headers.dart';
import 'icon_theme_backdrop.dart';
import 'icon_theme_codec.dart';
import 'icon_theme_library.dart';
import 'icon_theme_pipeline.dart';
import 'rasq_theme_spec.dart';

/// 画像を選ぶ口(テストで差し替える)。null = やめた。
final iconThemeImagePickerProvider = Provider<Future<Uint8List?> Function()>((ref) => () async {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery);
      return x?.readAsBytes();
    });

/// テーマ編集 (D-581) を開く。[initial] = 選んである画像(無ければ見本から)。「このアイコンを使う」で、テーマを書き込んだ PNG を返す。
Future<Uint8List?> openIconThemeEditor(BuildContext context, {Uint8List? initial}) =>
    Navigator.of(context).push<Uint8List>(MaterialPageRoute(builder: (_) => IconThemeEditorScreen(initial: initial)));

/// アイコンにテーマを埋め込む画面 (D-581)。ユーザーの仮組み(theme_mock_icon_embed.html)の 01〜04 をそのまま 1 画面に:
/// 01 アイコンを選ぶ → 02 変換する(基本テーマ・拡張領域・予約 3 ビット)→ 03 アップロード(見本の再圧縮 / リサイズ、または
/// 実際の SNS から保存した画像)→ 04 閲覧する(投稿のアイコンと添付の並び、拡大したプロフィール)。どの段も実際の画素を通す。
class IconThemeEditorScreen extends ConsumerStatefulWidget {
  const IconThemeEditorScreen({super.key, this.initial});
  final Uint8List? initial;

  @override
  ConsumerState<IconThemeEditorScreen> createState() => _IconThemeEditorScreenState();
}

enum _Mask { accent, bg, mono }

class _IconThemeEditorScreenState extends ConsumerState<IconThemeEditorScreen> {
  Uint8List? _source;
  Uint8List? _sourcePng;
  String? _sourceError;

  // 02 基本テーマ
  bool _gradient = true;
  int _gradKind = 2;
  List<int> _bg = const [17, 34, 68];
  List<int> _text = const [255, 255, 255];
  List<int> _accent = const [0, 204, 255];
  int _particle = 3;
  int _amount = 10;
  int _speed = 5;

  // 拡張領域
  bool _useExt = true;
  bool _urlMode = false;
  final _url = TextEditingController(text: 'plugins.example.social/t/starfall');
  _Mask _mask = _Mask.accent;
  int _angle = 6;
  int _anim = 1;
  int _animSpeed = 3;
  final _slots = <IconThemeSlotDraft>[
    IconThemeSlotDraft(trigger: IconThemeTrigger.always, shape: 3, orbit: 'fall', rand: 15, angleRand: 1, easeA: 0, easeB: 1, mix: 2),
    IconThemeSlotDraft(trigger: IconThemeTrigger.tap, shape: 4, orbit: 'rise', rand: 6, angleRand: 8, easeA: 2, easeB: 1, mix: 3),
    IconThemeSlotDraft(trigger: IconThemeTrigger.slide, shape: 3, orbit: 'drift', rand: 3, angleRand: 15, easeA: 3, easeB: 0, mix: 4),
  ];
  static const _maxSlots = 4;

  // 予約 3 ビット
  bool _useHint = true;
  bool _hintRounded = true;
  bool _hintVertical = false;
  bool _hintPack = true;

  // 表示
  int _shape = 0; // 0 = そのまま / 1 = 角丸 / 2 = 円形
  bool _zones = false;

  // サーバーの再圧縮の見本 (D-587 で段を外した。既定のまま読み戻しを確かめる)。
  static const _quality = 75;
  static const _size = 400;
  static const Uint8List? _external = null;

  IconThemeRun? _run;
  IconThemeEncodeInfo? _lastInfo;
  Timer? _debounce;
  int _runId = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_setSource(widget.initial));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _url.dispose();
    super.dispose();
  }


  Future<void> _setSource(Uint8List? bytes) async {
    Uint8List? rgba;
    if (bytes != null) {
      rgba = kIsWeb ? iconThemePrepareSource(bytes) : await compute(iconThemePrepareSource, bytes);
      if (rgba == null) {
        if (mounted) setState(() => _sourceError = context.l10n.iconThemeLoadFailed);
        return;
      }
    }
    final Uint8List src = rgba ?? (kIsWeb ? iconThemeSampleSource() : await compute(_sampleJob, null));
    final png = kIsWeb ? iconThemePngEncode(src) : await compute(iconThemePngEncode, src);
    if (!mounted) return;
    setState(() {
      _source = src;
      _sourcePng = png;
      _sourceError = null;
    });
    _schedule();
  }

  IconThemeBasic get _theme => IconThemeBasic(
        bgMode: _gradient ? IconThemeBg.gradient : IconThemeBg.solid,
        gradient: _gradKind,
        bg: _bg,
        text: _text,
        accent: _accent,
        particle: _particle,
        amount: _amount,
        speed: _speed,
        hint: _useHint ? IconThemeHint.of(roundedFrame: _hintRounded, verticalMedia: _hintVertical, packMedia: _hintPack) : null,
      );

  IconThemeExt? get _ext {
    if (!_useExt) return null;
    if (_urlMode) return IconThemeExt.url(_url.text.trim().replaceFirst(RegExp(r'^https?://', caseSensitive: false), ''));
    return iconThemeExtFromDrafts(_slots, angle: _angle, anim: _anim, animSpeed: _animSpeed);
  }

  void _changed(VoidCallback f) {
    setState(f);
    _schedule();
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), _runPipeline);
  }

  Future<void> _runPipeline() async {
    final source = _source;
    if (source == null) return;
    final id = ++_runId;
    final theme = _theme;
    final job = IconThemeJob(
      source: source,
      theme: theme,
      ext: _ext,
      ramp: iconThemeRamp(_mask == _Mask.bg ? theme.bg : theme.accent, mono: _mask == _Mask.mono),
      quality: _quality,
      size: _size,
      external: _external,
    );
    final run = kIsWeb ? iconThemeRunPipeline(job) : await compute(iconThemeRunPipeline, job);
    if (!mounted || id != _runId) return;
    setState(() {
      // 容量を超えたときは、アイコンは直前のまま(仮組みと同じ)。
      if (run.capacity != null) {
        _run = IconThemeRun(png: _run?.png, info: _run?.info, capacity: run.capacity, served: _run?.served, servedSize: _run?.servedSize ?? 0, servedBytes: _run?.servedBytes ?? 0, decoded: _run?.decoded ?? IconThemeDecoded.none);
      } else {
        _run = run;
        _lastInfo = run.info ?? _lastInfo;
      }
    });
  }

  RasqThemeSpec? get _decodedSpec {
    final d = _run?.decoded;
    if (d == null || !d.ok) return null;
    return RasqThemeSpec.fromIcon(d, frames: iconThemeFramesFor(d.theme!));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final run = _run;
    return Scaffold(
      key: const ValueKey('iconTheme.editor'),
      appBar: RasqPageHeader(title: l.iconThemeEditorTitle),
      // D-587: 変換先のアイコンと「画像を変更」はいつも見える所に(狭い = 上 / 2 カラムの幅 = 左に固定)。
      // 「アイコンを選ぶ」(見本の画像)と「アップロード(見本)」の段は出さない(再圧縮の見本は既定の 400px・品質 75 のまま)。
      body: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= _wideMinWidth;
        final stations = SingleChildScrollView(
          key: const ValueKey('iconTheme.stations'),
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.xl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(l.iconThemeEditorIntro, style: RasqTypography.bodySmall.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: RasqSpacing.md),
            _station('01', l.iconThemeStepEncode, _encodeSection(context, run)),
            _station('02', l.iconThemeStepView, _viewSection(context, run)),
          ]),
        );
        final pinned = _pinned(context, run, wide: wide);
        if (wide) {
          return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(width: _pinnedWidth, child: pinned),
            const VerticalDivider(width: 1),
            Expanded(child: stations),
          ]);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [pinned, const Divider(height: 1), Expanded(child: stations)]);
      }),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, RasqSpacing.sm),
          child: FilledButton(
            key: const ValueKey('iconTheme.use'),
            onPressed: run?.png == null || run?.capacity != null ? null : () => Navigator.of(context).pop(run!.png),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
            child: Text(l.iconThemeUseIcon),
          ),
        ),
      ),
    );
  }

  /// 2 カラムにする幅(この画面の幅)と、左の欄の幅。
  static const _wideMinWidth = 720.0;
  static const _pinnedWidth = 260.0;

  /// 固定の欄 (D-587): 変換先のアイコン(書き込んだもの。まだ無ければ元の画像)と「画像を変更」。
  Widget _pinned(BuildContext context, IconThemeRun? run, {required bool wide}) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final png = run?.png ?? _sourcePng;
    final change = FilledButton.icon(
      key: const ValueKey('iconTheme.pick'),
      icon: const Icon(Icons.image_outlined, size: 18),
      label: Text(l.iconThemeChangeImage),
      onPressed: () async {
        final b = await ref.read(iconThemeImagePickerProvider)();
        if (b != null) await _setSource(b);
      },
    );
    final label = Text(l.iconThemeTargetIcon, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant));
    final error = _sourceError == null ? null : Text(_sourceError!, key: const ValueKey('iconTheme.sourceError'), style: RasqTypography.caption.copyWith(color: scheme.error));
    return Material(
      key: const ValueKey('iconTheme.pinned'),
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(RasqSpacing.md),
        child: wide
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                label,
                const SizedBox(height: RasqSpacing.sm),
                AspectRatio(aspectRatio: 1, child: _thumb(png, size: _pinnedWidth, key: const ValueKey('iconTheme.target'))),
                const SizedBox(height: RasqSpacing.md),
                change,
                ?error,
                const SizedBox(height: RasqSpacing.xs),
                Text(l.iconThemeStepPickHint, style: _hint(context)),
              ])
            : Row(children: [
                _thumb(png, key: const ValueKey('iconTheme.target')),
                const SizedBox(width: RasqSpacing.md),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    label,
                    const SizedBox(height: RasqSpacing.xs),
                    change,
                    ?error,
                  ]),
                ),
              ]),
      ),
    );
  }

  TextStyle _hint(BuildContext context) => RasqTypography.caption.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);

  Widget _station(String no, String title, List<Widget> children) => Builder(
        builder: (context) {
          final scheme = Theme.of(context).colorScheme;
          // 中の CheckboxListTile が地の色の上に描けるように Material で(Container の色だと ListTile の地が隠れる)。
          return Padding(
            key: ValueKey('iconTheme.station.$no'),
            padding: const EdgeInsets.only(bottom: RasqSpacing.md),
            child: Material(
            color: scheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(side: BorderSide(color: scheme.outlineVariant), borderRadius: BorderRadius.circular(10)),
            child: Padding(
            padding: const EdgeInsets.all(RasqSpacing.md),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text(no, style: RasqTypography.title.copyWith(color: scheme.primary)),
                const SizedBox(width: 10),
                Expanded(child: Text(title, style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700))),
              ]),
              const SizedBox(height: RasqSpacing.sm),
              for (final c in children) Padding(padding: const EdgeInsets.only(bottom: RasqSpacing.sm), child: c),
            ]),
            ),
            ),
          );
        },
      );

  Widget _thumb(Uint8List? png, {double size = 72, Key? key}) => ClipRRect(
        key: key,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(width: size, height: size, child: png == null ? const ColoredBox(color: Colors.black12) : Image.memory(png, fit: BoxFit.cover, gaplessPlayback: true)),
      );

  Widget _seg<T>(List<(T, String)> items, T value, ValueChanged<T> onChanged, {Key? key}) => SegmentedButton<T>(
        key: key,
        showSelectedIcon: false,
        style: const ButtonStyle(visualDensity: VisualDensity.compact),
        segments: [for (final (v, label) in items) ButtonSegment(value: v, label: Text(label, style: RasqTypography.caption))],
        selected: {value},
        onSelectionChanged: (s) => onChanged(s.first),
      );

  Widget _field(String label, Widget control) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: RasqTypography.caption),
        const SizedBox(height: 2),
        control,
      ]);

  Widget _slider(String label, int value, int max, ValueChanged<int> onChanged, {String Function(int)? show, Key? key}) => _field(
        label,
        Row(children: [
          Expanded(child: Slider(key: key, value: value.toDouble(), min: 0, max: max.toDouble(), divisions: max, onChanged: (v) => onChanged(v.round()))),
          SizedBox(width: 44, child: Text(show?.call(value) ?? '$value', style: RasqTypography.caption, textAlign: TextAlign.end)),
        ]),
      );

  Widget _dropdown<T>(String label, T value, List<(T, String)> items, ValueChanged<T> onChanged, {Key? key}) => _field(
        label,
        DropdownButton<T>(key: key, isDense: true, value: value, items: [for (final (v, t) in items) DropdownMenuItem(value: v, child: Text(t, style: RasqTypography.bodySmall))], onChanged: (v) => v == null ? null : onChanged(v)),
      );

  List<Widget> _encodeSection(BuildContext context, IconThemeRun? run) {
    final l = context.l10n;
    final info = _lastInfo;
    final scheme = Theme.of(context).colorScheme;
    final radius = switch (_shape) { 1 => 0.2, 2 => 0.5, _ => 0.0 };
    return [
      Center(
        child: SizedBox(
          width: 220,
          height: 220,
          child: Stack(fit: StackFit.expand, children: [
            ClipRRect(borderRadius: BorderRadius.circular(220 * radius), child: run?.png == null ? const ColoredBox(color: Colors.black12) : Image.memory(run!.png!, key: const ValueKey('iconTheme.encoded'), fit: BoxFit.cover, gaplessPlayback: true)),
            if (_zones) const IgnorePointer(child: CustomPaint(painter: _ZonesPainter())),
          ]),
        ),
      ),
      Center(child: _seg<int>([(0, l.iconThemeShapeRaw), (1, l.iconThemeShapeRound), (2, l.iconThemeShapeCircle)], _shape, (v) => setState(() => _shape = v))),
      CheckboxListTile(contentPadding: EdgeInsets.zero, dense: true, value: _zones, onChanged: (v) => setState(() => _zones = v ?? false), title: Text(l.iconThemeShowZones, style: RasqTypography.caption)),
      Wrap(spacing: 16, runSpacing: 8, children: [
        _field(l.iconThemeBackground, _seg<bool>([(false, l.iconThemeBgSolid), (true, l.iconThemeBgGradient)], _gradient, (v) => _changed(() => _gradient = v), key: const ValueKey('iconTheme.bgMode'))),
        if (_gradient)
          _dropdown<int>(l.iconThemeGradientKind, _gradKind, [(0, l.iconThemeGradient0), (1, l.iconThemeGradient1), (2, l.iconThemeGradient2), (3, l.iconThemeGradient3)], (v) => _changed(() => _gradKind = v)),
      ]),
      _ColorField(key: const ValueKey('iconTheme.color.bg'), label: l.iconThemeBgColor, value: _bg, onChanged: (v) => _changed(() => _bg = v)),
      _ColorField(key: const ValueKey('iconTheme.color.text'), label: l.iconThemeTextColor, value: _text, onChanged: (v) => _changed(() => _text = v)),
      _ColorField(key: const ValueKey('iconTheme.color.accent'), label: l.iconThemeAccentColor, value: _accent, onChanged: (v) => _changed(() => _accent = v)),
      _dropdown<int>(l.iconThemeParticle, _particle, [for (var i = 0; i <= 5; i++) (i, _particleName(l, i))], (v) => _changed(() {
            _particle = v;
            // 基本パーティクルを替えたら、最初のスロットの形と軌道もそれに合わせる(仮組みと同じ)。
            final def = iconThemeShapes[v];
            if (def != null && _slots.isNotEmpty) {
              _slots[0].shape = v;
              _slots[0].orbit = def.orbit;
            }
          }), key: const ValueKey('iconTheme.particle')),
      _slider(l.iconThemeAmount, _amount, 15, (v) => _changed(() => _amount = v)),
      _slider(l.iconThemeSpeed, _speed, 15, (v) => _changed(() => _speed = v)),
      CheckboxListTile(key: const ValueKey('iconTheme.useExt'), contentPadding: EdgeInsets.zero, value: _useExt, onChanged: (v) => _changed(() => _useExt = v ?? false), title: Text(l.iconThemeUseExt, style: RasqTypography.bodySmall)),
      if (_useExt) ..._extFields(context),
      CheckboxListTile(key: const ValueKey('iconTheme.useHint'), contentPadding: EdgeInsets.zero, value: _useHint, onChanged: (v) => _changed(() => _useHint = v ?? false), title: Text(l.iconThemeUseHint, style: RasqTypography.bodySmall)),
      if (_useHint)
        Wrap(spacing: 16, runSpacing: 8, children: [
          _field(l.iconThemeHintFrame, _seg<bool>([(true, l.iconThemeHintFrameRound), (false, l.iconThemeHintFrameCircle)], _hintRounded, (v) => _changed(() => _hintRounded = v), key: const ValueKey('iconTheme.hint.frame'))),
          _field(l.iconThemeHintDir, _seg<bool>([(false, l.iconThemeHintDirHorizontal), (true, l.iconThemeHintDirVertical)], _hintVertical, (v) => _changed(() => _hintVertical = v), key: const ValueKey('iconTheme.hint.dir'))),
          _field(l.iconThemeHintFill, _seg<bool>([(false, l.iconThemeHintFillAsIs), (true, l.iconThemeHintFillPack)], _hintPack, (v) => _changed(() => _hintPack = v), key: const ValueKey('iconTheme.hint.fill'))),
        ]),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: scheme.surface, border: Border.all(color: scheme.outlineVariant), borderRadius: BorderRadius.circular(8)),
        child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: SelectableText(info?.text ?? '', key: const ValueKey('iconTheme.dsl'), style: const TextStyle(fontFamily: 'monospace', fontSize: 13))),
      ),
      if (info != null) Text(l.iconThemePalStat(info.palBlocks), style: _hint(context)),
      if (run?.capacity case final c?)
        Text(_urlMode ? l.iconThemeOverCapacityUrl(c.used, c.capacity) : l.iconThemeOverCapacity(c.used, c.capacity), key: const ValueKey('iconTheme.over'), style: RasqTypography.caption.copyWith(color: scheme.error, fontWeight: FontWeight.w700))
      else if (info != null)
        Text(_useExt ? l.iconThemeExtStat(info.extBlocks, info.extUsed, info.extCapacity) : l.iconThemeExtUnused, key: const ValueKey('iconTheme.extStat'), style: _hint(context)),
    ];
  }

  List<Widget> _extFields(BuildContext context) {
    final l = context.l10n;
    final ext = _ext;
    return [
      _field(l.iconThemeExtMode, _seg<bool>([(false, l.iconThemeExtModeSlots), (true, l.iconThemeExtModeUrl)], _urlMode, (v) => _changed(() => _urlMode = v), key: const ValueKey('iconTheme.extMode'))),
      if (_urlMode)
        TextField(
          key: const ValueKey('iconTheme.url'),
          controller: _url,
          autocorrect: false,
          keyboardType: TextInputType.url,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          decoration: InputDecoration(labelText: l.iconThemePluginUrl, isDense: true, prefixText: 'https://'),
          onChanged: (_) => _schedule(),
        )
      else ...[
        Wrap(spacing: 16, runSpacing: 8, children: [
          _dropdown<_Mask>(l.iconThemeMask, _mask, [(_Mask.accent, l.iconThemeMaskAccent), (_Mask.bg, l.iconThemeMaskBg), (_Mask.mono, l.iconThemeMaskMono)], (v) => _changed(() => _mask = v)),
          _dropdown<int>(l.iconThemeAnim, _anim, [(0, l.iconThemeAnim0), (1, l.iconThemeAnim1), (2, l.iconThemeAnim2), (3, l.iconThemeAnim3)], (v) => _changed(() => _anim = v)),
        ]),
        _slider(l.iconThemeAngle, _angle, 15, (v) => _changed(() => _angle = v), show: (v) => '${(v * 22.5).toStringAsFixed(v.isOdd ? 1 : 0)}°'),
        _slider(l.iconThemeAnimSpeed, _animSpeed, 7, (v) => _changed(() => _animSpeed = v)),
        for (final (i, s) in _slots.indexed) _slotEditor(context, i, s),
        Row(children: [
          OutlinedButton(key: const ValueKey('iconTheme.slot.add'), onPressed: _slots.length >= _maxSlots ? null : () => _changed(() => _slots.add(IconThemeSlotDraft(trigger: IconThemeTrigger.tap, shape: _slots.first.shape, orbit: _slots.first.orbit))), child: Text(l.iconThemeSlotAdd)),
          const SizedBox(width: 12),
          if (ext != null && !ext.isUrl) Expanded(child: Text(l.iconThemeSlotShare(ext.shapes.length, ext.paths.length, ext.slots.length), style: _hint(context))),
        ]),
      ],
    ];
  }

  Widget _slotEditor(BuildContext context, int i, IconThemeSlotDraft s) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final eases = [(0, l.iconThemeEase0), (1, l.iconThemeEase1), (2, l.iconThemeEase2), (3, l.iconThemeEase3)];
    return Container(
      key: ValueKey('iconTheme.slot.$i'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: scheme.surface, border: Border.all(color: scheme.outlineVariant), borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(l.iconThemeSlotTitle(i + 1), style: RasqTypography.caption.copyWith(fontWeight: FontWeight.w700))),
          TextButton(onPressed: _slots.length < 2 ? null : () => _changed(() => _slots.removeAt(i)), child: Text(l.iconThemeSlotRemove)),
        ]),
        Wrap(spacing: 16, runSpacing: 8, children: [
          _dropdown<IconThemeTrigger>(l.iconThemeTriggerLabel, s.trigger, [(IconThemeTrigger.always, l.iconThemeTriggerAlways), (IconThemeTrigger.tap, l.iconThemeTriggerTap), (IconThemeTrigger.slide, l.iconThemeTriggerSlide)], (v) => _changed(() => s.trigger = v), key: ValueKey('iconTheme.slot.$i.trigger')),
          _dropdown<int>(l.iconThemeShapeLabel, s.shape, [for (final k in iconThemeShapes.keys) (k, _particleName(l, k))], (v) => _changed(() => s.shape = v)),
          _dropdown<String>(l.iconThemeOrbitLabel, s.orbit, [('fall', l.iconThemeOrbitFall), ('drift', l.iconThemeOrbitDrift), ('rise', l.iconThemeOrbitRise), ('flow', l.iconThemeOrbitFlow)], (v) => _changed(() => s.orbit = v)),
          _dropdown<int>(l.iconThemeEaseA, s.easeA, eases, (v) => _changed(() => s.easeA = v)),
          _dropdown<int>(l.iconThemeEaseB, s.easeB, eases, (v) => _changed(() => s.easeB = v)),
        ]),
        _slider(l.iconThemeRand, s.rand, 15, (v) => _changed(() => s.rand = v)),
        _slider(l.iconThemeAngleRand, s.angleRand, 15, (v) => _changed(() => s.angleRand = v), show: (v) => '±${v * 6}°'),
        _slider(l.iconThemeMix, s.mix, 7, (v) => _changed(() => s.mix = v), show: (v) => '$v/7'),
      ]),
    );
  }

  List<Widget> _viewSection(BuildContext context, IconThemeRun? run) {
    final l = context.l10n;
    final d = run?.decoded ?? IconThemeDecoded.none;
    final hints = d.ok ? d.theme!.hints : null;
    final scheme = Theme.of(context).colorScheme;
    Widget pill(String key, bool? ok, String text) => Container(
          key: ValueKey('iconTheme.result.$key'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: ok == null ? scheme.surface : (ok ? Colors.green.withValues(alpha: 0.15) : scheme.errorContainer),
            border: ok == null ? Border.all(color: scheme.outlineVariant) : null,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(text, style: RasqTypography.caption.copyWith(fontWeight: FontWeight.w700, color: ok == null ? scheme.onSurfaceVariant : (ok ? Colors.green.shade800 : scheme.onErrorContainer))),
        );
    Widget row(String label, Widget pillW, [String note = '']) => Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 10, runSpacing: 4, children: [
          SizedBox(width: 120, child: Text(label, style: RasqTypography.caption.copyWith(fontWeight: FontWeight.w700))),
          pillW,
          if (note.isNotEmpty) Text(note, style: RasqTypography.caption),
        ]);
    final ext = d.ext;
    final extNote = ext == null ? '' : (ext.isUrl ? l.iconThemeExtUrlNote(ext.url!) : l.iconThemeExtSlotsNote([for (final s in ext.slots) _triggerName(l, s.trigger)].join(l.iconThemeListSeparator)));
    return [
      // 投稿の見本: アイコンの枠と添付の並びは、読み戻した予約 3 ビットで。
      Container(
        key: const ValueKey('iconTheme.samplePost'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: scheme.surface, border: Border.all(color: scheme.outlineVariant), borderRadius: BorderRadius.circular(10)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(
            onTap: _decodedSpec == null ? null : () => _openPreview(context),
            child: ClipRRect(
              key: ValueKey('iconTheme.sampleAvatar.${hints?.roundedFrame ?? false ? 'rounded' : 'circle'}'),
              borderRadius: BorderRadius.circular(hints?.roundedFrame ?? false ? 11 : 28),
              child: SizedBox(width: 56, height: 56, child: run?.served == null ? const ColoredBox(color: Colors.black12) : Image.memory(run!.served!, fit: BoxFit.cover, gaplessPlayback: true)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.iconThemeSamplePostName, style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700)),
              Text(l.iconThemeSamplePostBody, style: RasqTypography.bodySmall),
              const SizedBox(height: 8),
              RasqMediaGrid(
                key: ValueKey('iconTheme.sampleMedia.${hints?.bits}'),
                items: _sampleMedia,
                maxVisible: _sampleMedia.length,
                arrangement: hints == null ? RasqMediaArrangement.auto : RasqMediaArrangement.of(vertical: hints.verticalMedia, packed: hints.packMedia),
              ),
            ]),
          ),
        ]),
      ),
      FilledButton.icon(key: const ValueKey('iconTheme.preview'), onPressed: _decodedSpec == null ? null : () => _openPreview(context), icon: const Icon(Icons.zoom_in, size: 18), label: Text(l.iconThemeOpenPreview)),
      row(l.iconThemeResultBasic, pill('basic', run == null ? null : d.ok, run == null ? '—' : (d.ok ? l.iconThemeRestored : l.iconThemeNotRestored)), d.ok ? l.iconThemeCorrected(d.palTotal, d.palCorrected) : ''),
      row(
        l.iconThemeResultExt,
        pill('ext', ext != null ? true : (!_useExt && _external == null ? null : (d.ok && _external == null ? false : null)), ext != null ? l.iconThemeRestored : (!_useExt && _external == null ? l.iconThemeNotUsed : (d.ok && _external == null ? l.iconThemeNotRestored : l.iconThemeNotFound))),
        ext != null ? '${l.iconThemeCorrected(iconThemeLayoutBytes, d.extCorrected)} $extNote' : '',
      ),
      row(l.iconThemeResultHint, pill('hint', hints == null ? null : true, hints == null ? (d.ok ? l.iconThemeHintNone : '—') : l.iconThemeHintRead), hints == null ? '' : _hintText(l, hints)),
      row(
        l.iconThemeResultMatch,
        pill('match', _external != null || run == null ? null : (d.ok && d.text == run.info?.text), _external != null ? l.iconThemeExternalNoCompare : (run != null && d.ok && d.text == run.info?.text ? l.iconThemeDslMatch : l.iconThemeDslMismatch)),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: scheme.surface, border: Border.all(color: scheme.outlineVariant), borderRadius: BorderRadius.circular(8)),
        child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Text(d.ok ? d.text! : l.iconThemeDslUnreadable, key: const ValueKey('iconTheme.dslBack'), style: const TextStyle(fontFamily: 'monospace', fontSize: 13))),
      ),
    ];
  }

  void _openPreview(BuildContext context) {
    final spec = _decodedSpec, served = _run?.served;
    if (spec == null || served == null) return;
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => IconThemeProfilePreview(spec: spec, avatar: served)));
  }

  static final _sampleMedia = [for (var i = 0; i < 5; i++) ...MockData.media(5).skip(i).take(1)];

  String _hintText(AppLocalizations l, IconThemeHint h) => l.iconThemeHintSummary(
        h.bits.toRadixString(2).padLeft(3, '0'),
        h.roundedFrame ? l.iconThemeHintFrameRound : l.iconThemeHintFrameCircle,
        h.verticalMedia ? l.iconThemeHintDirVertical : l.iconThemeHintDirHorizontal,
        h.packMedia ? l.iconThemeHintFillPack : l.iconThemeHintFillAsIs,
      );
}

/// 拡張領域の全体のバイト数(訂正の数の分母)。
int get iconThemeLayoutBytes => IconThemeLayout.instance.extBytes;

String _particleName(AppLocalizations l, int i) => switch (i) {
      1 => l.iconThemeParticle1,
      2 => l.iconThemeParticle2,
      3 => l.iconThemeParticle3,
      4 => l.iconThemeParticle4,
      5 => l.iconThemeParticle5,
      _ => l.iconThemeParticle0,
    };

String _triggerName(AppLocalizations l, IconThemeTrigger t) => switch (t) {
      IconThemeTrigger.always => l.iconThemeTriggerAlways,
      IconThemeTrigger.tap => l.iconThemeTriggerTap,
      IconThemeTrigger.slide => l.iconThemeTriggerSlide,
    };

/// 4 ビット × 3 の色(`#rgb`)を選ぶ: 見本の色と、16 進 3 桁の入力。
class _ColorField extends StatefulWidget {
  const _ColorField({super.key, required this.label, required this.value, required this.onChanged});
  final String label;
  final List<int> value;
  final ValueChanged<List<int>> onChanged;

  static const presets = ['#000', '#123', '#124', '#fff', '#eee', '#f9a', '#e24', '#f80', '#fd4', '#4c6', '#0cf', '#36f', '#a6f', '#8a9'];

  @override
  State<_ColorField> createState() => _ColorFieldState();
}

String _short(List<int> c) => '#${c.map((v) => (v / 17).round().toRadixString(16)).join()}';
List<int>? _parseShort(String s) {
  final m = RegExp(r'^#?([0-9a-fA-F]{3})$').firstMatch(s.trim());
  if (m == null) return null;
  return [for (final ch in m.group(1)!.split('')) int.parse(ch, radix: 16) * 17];
}

class _ColorFieldState extends State<_ColorField> {
  late final _ctl = TextEditingController(text: _short(widget.value));

  @override
  void didUpdateWidget(_ColorField old) {
    super.didUpdateWidget(old);
    final s = _short(widget.value);
    if (_parseShort(_ctl.text) == null || _short(_parseShort(_ctl.text)!) != s) _ctl.text = s;
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.label, style: RasqTypography.caption),
      const SizedBox(height: 4),
      Row(children: [
        Container(width: 32, height: 32, decoration: BoxDecoration(color: themeColor(widget.value), borderRadius: BorderRadius.circular(6), border: Border.all(color: scheme.outlineVariant))),
        const SizedBox(width: 8),
        SizedBox(
          width: 76,
          child: TextField(
            controller: _ctl,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            inputFormatters: [LengthLimitingTextInputFormatter(4)],
            decoration: const InputDecoration(isDense: true),
            onChanged: (s) {
              final c = _parseShort(s);
              if (c != null) widget.onChanged(c);
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final p in _ColorField.presets)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: InkWell(
                    onTap: () => widget.onChanged(_parseShort(p)!),
                    customBorder: const CircleBorder(),
                    child: Container(width: 22, height: 22, decoration: BoxDecoration(color: themeColor(_parseShort(p)!), shape: BoxShape.circle, border: Border.all(color: scheme.outlineVariant))),
                  ),
                ),
            ]),
          ),
        ),
      ]),
    ]);
  }
}

/// 境界線: 桃 = 円形で表示したときの縁、青 = 角丸で表示したときの縁(仮組みと同じ)。
class _ZonesPainter extends CustomPainter {
  const _ZonesPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / iconThemeSize;
    final white = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.white;
    final pink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFFE0218A);
    final blue = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFF0A7CFF);
    canvas.drawCircle(size.center(Offset.zero), 199 * s, white);
    canvas.drawCircle(size.center(Offset.zero), 199 * s, pink);
    final r = RRect.fromRectAndRadius(Rect.fromLTWH(1 * s, 1 * s, 398 * s, 398 * s), Radius.circular(80 * s));
    canvas.drawRRect(r, white);
    canvas.drawRRect(r, blue);
  }

  @override
  bool shouldRepaint(_ZonesPainter old) => false;
}

/// 拡大したプロフィールの見本(読み戻した値だけで描く)。
class IconThemeProfilePreview extends StatelessWidget {
  const IconThemeProfilePreview({super.key, required this.spec, required this.avatar});
  final RasqThemeSpec spec;
  final Uint8List avatar;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fg = themeColor(spec.basic.text), accent = themeColor(spec.basic.accent);
    final rounded = spec.basic.hints?.roundedFrame ?? true;
    final onAccent = accent.computeLuminance() > 0.5 ? Colors.black : Colors.white;
    return Scaffold(
      key: const ValueKey('iconTheme.profilePreview'),
      body: IconThemeBackdrop(
        spec: spec,
        child: SafeArea(
          child: Stack(children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 48, 20, 32),
                child: DefaultTextStyle(
                  style: RasqTypography.bodySmall.copyWith(color: fg),
                  textAlign: TextAlign.center,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    LayoutBuilder(builder: (context, c) {
                      final side = (c.maxWidth * 0.62).clamp(80.0, 240.0);
                      return ClipRRect(borderRadius: BorderRadius.circular(rounded ? side * 0.2 : side / 2), child: Image.memory(avatar, width: side, height: side, fit: BoxFit.cover));
                    }),
                    const SizedBox(height: 14),
                    Text(l.iconThemeSamplePostName, style: RasqTypography.title.copyWith(color: fg)),
                    Opacity(opacity: 0.75, child: Text('@sample@example.social', style: RasqTypography.caption.copyWith(color: fg))),
                    const SizedBox(height: 10),
                    ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Text(l.iconThemePreviewBio)),
                    const SizedBox(height: 14),
                    FilledButton(style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: onAccent, shape: const StadiumBorder()), onPressed: () {}, child: Text(l.iconThemePreviewFollow)),
                    if (spec.ext?.url case final url?) ...[
                      const SizedBox(height: 12),
                      Text(l.iconThemePluginUrlNote(url), style: RasqTypography.caption.copyWith(color: fg)),
                    ],
                  ]),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 12,
              child: FilledButton.tonal(key: const ValueKey('iconTheme.preview.close'), onPressed: () => Navigator.of(context).maybePop(), child: Text(MaterialLocalizations.of(context).closeButtonLabel)),
            ),
          ]),
        ),
      ),
    );
  }
}

Uint8List _sampleJob(Object? _) => iconThemeSampleSource();
