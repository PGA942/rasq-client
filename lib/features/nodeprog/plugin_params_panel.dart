import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rrl_core/rrl_core.dart';
import 'package:rrl_renderer/rrl_renderer.dart';

import '../../l10n/l10n.dart';
import '../plugins/slot_plugins.dart';

/// ノードエディター(自由キャンバス)の「ノードを設定」FOW (D-171): スロットの
/// TL プラグイン(`plugin:slot:<pluginId>:<tlId>`)のソートノードに、プラグインの
/// `tl.params` の RRL 設定ページを差し込む。簡略 UI (D-169) と同じ作法 —
/// キャンセル(左)/ タイトル / 決定(右)、決定で値がノードの「パラメーター」ポートに入る。
const nodeParamsFowId = 'fow.nodeprog.params';

/// `plugin:slot:<pluginId>:<tlId>` → (pluginId, tlId)。違う形なら null。
(String pluginId, String tlId)? slotSortNodeOf(String type) {
  if (!type.startsWith('plugin:slot:')) return null;
  final parts = type.substring('plugin:slot:'.length).split(':');
  if (parts.length < 2) return null;
  return (parts.first, parts.sublist(1).join(':'));
}

class PluginParamsPanel extends ConsumerStatefulWidget {
  const PluginParamsPanel({super.key, required this.nodeType, required this.title, required this.initial, required this.onConfirm, required this.onCancel});
  final String nodeType;
  final String title;
  final Map<String, Object?> initial;
  final ValueChanged<Map<String, Object?>> onConfirm;
  final VoidCallback onCancel;
  @override
  ConsumerState<PluginParamsPanel> createState() => _PluginParamsPanelState();
}

class _PluginParamsPanelState extends ConsumerState<PluginParamsPanel> {
  late Map<String, Object?> _values = {...widget.initial};
  ({RrlNode root, Map<String, Object?> defaults})? _params;
  bool _missing = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final ref_ = slotSortNodeOf(widget.nodeType);
    final plugin = ref_ == null ? null : ref.read(activeSlotPluginsProvider).where((p) => p.id == ref_.$1).firstOrNull;
    if (ref_ == null || plugin == null) {
      _missing = true;
      _loading = false;
      return;
    }
    ref.read(slotPluginsProvider.notifier).tlParams(plugin, ref_.$2).then((v) {
      if (!mounted) return;
      setState(() {
        _params = v;
        _loading = false;
        if (v != null) _values = {...v.defaults, ..._values};
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = RasqTokens.of(context);
    final l = context.l10n;
    final p = _params;
    final root = p?.root ??
        RrlNode(t: 'Column', c: [
          RrlNode(t: 'Text', p: {
            'text': _missing
                ? l.nodeprogEditorParamsMissing
                : _loading
                    ? l.nodeprogEditorParamsLoading
                    : l.nodeprogEditorParamsNone
          }),
        ]);
    final host = RrlHost(
      instanceScope: 'rasq.host.nodeprog:-:0:${widget.nodeType}',
      scope: RrlScope({'settings': _values}),
      onEvent: (nodeId, kind, {String? fn, Map<String, Object?> payload = const {}}) {
        if (fn == 'settings.set') setState(() => _values = {..._values, nodeId.split(':').last: payload['value']});
      },
    );
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 2, RasqSpacing.page, 0),
        child: Row(children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: widget.onCancel,
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32), alignment: Alignment.centerLeft),
                child: Text(l.nodeprogEditorCancelButton, style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant)),
              ),
            ),
          ),
          Text(l.nodeprogEditorParamsTitle, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => widget.onConfirm(_values),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32), alignment: Alignment.centerRight),
                child: Text(l.nodeprogEditorConfirmButton, style: RasqTypography.bodySmall.copyWith(color: tokens.link)),
              ),
            ),
          ),
        ]),
      ),
      RasqPluginTile(icon: Icons.extension_outlined, title: widget.title, subtitle: l.nodeprogEditorPluginSortAuthor, description: rasqDetail(context, l.nodeprogEditorPluginSortDescription, l.nodeprogEditorParamsPluginDetail), chevron: false),

      const Divider(height: 1),
      Expanded(child: ListView(padding: const EdgeInsets.only(bottom: RasqSpacing.sm), children: [RrlRenderer(node: root, host: host)])),
    ]);
  }
}
