import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import 'compose_providers.dart';

/// 下書き FOW (D-176): コンポーザーの「下書き」から。複数の下書きを一覧し、選んで開く / 消す。
///
/// - ヘッダー: 「キャンセル　**下書き**」。フッターの「選択」で複数選択モード(チェックボックス)になり、
///   ヘッダー右に「削除」が出る。
/// - 先頭行: 今の内容を保存して閉じる(開いている下書きがあれば「上書き」/「新しい下書きにして」の 2 行)。
/// - 行(通常)= 右に > 、タップでそのまま編集画面へ(その下書きを開く)。
const composerDraftsFowId = 'fow.composer.drafts';
const draftsSelectKey = Key('drafts.select');
const draftsConfirmKey = Key('drafts.confirm');

sealed class DraftsResult {
  const DraftsResult();
}

/// 今の内容を保存して閉じる([asNew] = 開いている下書きとは別に新しく)。
class DraftsSaveAndClose extends DraftsResult {
  const DraftsSaveAndClose({this.asNew = false});
  final bool asNew;
}

class DraftsLoad extends DraftsResult {
  const DraftsLoad(this.draft);
  final ComposeDraft draft;
}

Future<DraftsResult?> showDraftsFow(WidgetRef ref, {required String? currentDraftId, required bool hasContent, int column = 0, String? ownerId}) async {
  final manager = ref.read(overlayManagerProvider);
  final selectMode = ValueNotifier(false);
  final selected = ValueNotifier<Set<String>>(const {});
  final store = ref.read(composeDraftsProvider.notifier);
  final spec = FowSpec(
    type: FowPanelType.widget,
    title: '下書き',
    cancelText: 'キャンセル',
    initialHeightFactor: 0.6,
    minHeightFactor: 0.3,
    maxHeightFactor: 0.92,
    dockAboveFooter: true,
    columnIndex: column,
    headerTrailing: ValueListenableBuilder<bool>(
      valueListenable: selectMode,
      builder: (context, select, _) => ValueListenableBuilder<Set<String>>(
        valueListenable: selected,
        builder: (context, sel, _) {
          final scheme = Theme.of(context).colorScheme;
          // 通常モードは行タップで直接開くので右側は空、選択モードで「削除」。
          if (!select) return const SizedBox(width: 80);
          return TextButton(
            key: draftsConfirmKey,
            onPressed: sel.isEmpty
                ? null
                : () {
                    store.clearAll(sel);
                    selected.value = const {};
                    selectMode.value = false;
                  },
            child: Text('削除', style: TextStyle(color: sel.isEmpty ? scheme.onSurfaceVariant.withValues(alpha: 0.5) : scheme.error)),
          );
        },
      ),
    ),
  );
  try {
    return await manager.showFow<DraftsResult>(
      id: composerDraftsFowId,
      ownerId: ownerId,
      spec: spec,
      builder: (ctx, handle) => _DraftsBody(currentDraftId: currentDraftId, hasContent: hasContent, selectMode: selectMode, selected: selected, onSave: (asNew) => handle.close(result: DraftsSaveAndClose(asNew: asNew)), onOpen: (d) => handle.close(result: DraftsLoad(d))),
    );
  } finally {
    selectMode.dispose();
    selected.dispose();
  }
}

class _DraftsBody extends ConsumerWidget {
  const _DraftsBody({required this.currentDraftId, required this.hasContent, required this.selectMode, required this.selected, required this.onSave, required this.onOpen});
  final String? currentDraftId;
  final bool hasContent;
  final ValueNotifier<bool> selectMode;
  final ValueNotifier<Set<String>> selected;
  final ValueChanged<bool> onSave;
  final ValueChanged<ComposeDraft> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = RasqTokens.of(context);
    final drafts = ref.watch(composeDraftsProvider.notifier).list;
    ref.watch(composeDraftsProvider);
    return ValueListenableBuilder<bool>(
      valueListenable: selectMode,
      builder: (context, select, _) => ValueListenableBuilder<Set<String>>(
        valueListenable: selected,
        builder: (context, sel, _) => Column(children: [
          Expanded(
            child: ListView(padding: EdgeInsets.zero, children: [
              if (!select && hasContent) ...[
                if (currentDraftId == null)
                  RasqListTile(key: const ValueKey('drafts.save'), leading: Icon(Icons.save_outlined, size: 20, color: tokens.link), title: '今の内容を保存して閉じる', titleColor: tokens.link, onTap: () => onSave(false))
                else ...[
                  RasqListTile(key: const ValueKey('drafts.save'), leading: Icon(Icons.save_outlined, size: 20, color: tokens.link), title: '今の内容を上書き保存して閉じる', titleColor: tokens.link, onTap: () => onSave(false)),
                  RasqListTile(key: const ValueKey('drafts.saveNew'), leading: Icon(Icons.note_add_outlined, size: 20, color: tokens.link), title: '今の内容を新しい下書きにして閉じる', titleColor: tokens.link, onTap: () => onSave(true)),
                ],
              ],
              if (drafts.isEmpty)
                Padding(padding: const EdgeInsets.all(RasqSpacing.page), child: Text('下書きはありません', style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant)))
              else
                for (final d in drafts)
                  RasqListTile(
                    key: ValueKey('drafts.item.${d.id}'),
                    leading: select ? Icon(sel.contains(d.id) ? Icons.check_box : Icons.check_box_outline_blank, size: 22, color: sel.contains(d.id) ? RasqColors.accent : scheme.onSurfaceVariant) : null,
                    title: d.title,
                    subtitle: [d.targetLabel, if (d.createdAt != null) _fmt(d.createdAt!), if (d.files.isNotEmpty) '添付 ${d.files.length}', if (d.id == currentDraftId) '開いている'].join(' · '),
                    chevron: !select,
                    onTap: () {
                      if (select) {
                        selected.value = sel.contains(d.id) ? ({...sel}..remove(d.id)) : {...sel, d.id};
                      } else {
                        onOpen(d); // そのまま編集画面へ
                      }
                    },
                  ),
            ]),
          ),
          // フッター: 選択(複数選択モードの切り替え。ヘッダーの決定が削除に変わる)。
          Padding(
            padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 4, RasqSpacing.page, RasqSpacing.sm),
            child: Row(children: [
              TextButton.icon(
                key: draftsSelectKey,
                onPressed: drafts.isEmpty
                    ? null
                    : () {
                        selected.value = const {};
                        selectMode.value = !select;
                      },
                icon: Icon(select ? Icons.close : Icons.checklist, size: 18),
                label: Text(select ? '選択解除' : '選択'),
              ),
              const Spacer(),
              if (select) Text('${sel.length} 件', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
            ]),
          ),
        ]),
      ),
    );
  }

  static String _fmt(DateTime t) => '${t.month}/${t.day} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
