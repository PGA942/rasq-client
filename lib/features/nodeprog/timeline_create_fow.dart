import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import '../settings/settings_dsl.dart';
import 'node_tabs.dart';
import 'timeline_config_screen.dart';
import 'timeline_temp_fow.dart' show timelineTempExpandedFactor;
import 'tl_components.dart';
import 'tl_config_store.dart';

/// タイムラインを作る FOW (D-384) の id。
const timelineCreateFowId = 'fow.timeline.create';

const timelineCreateHeaderKey = Key('tl.create.header');

/// タイムライン(タブ)を作る FOW (D-384)。**「タイムラインを一時変更」と同じ作り**(ヘッダーのキャンセル / 決定 + 部品の積み)で、
/// 探す欄の代わりに名前の欄。
///
/// - 中身は [TimelineConfigScreen] の作るモード(構成は保存せず [tlTemporaryConfigsProvider] に書く)。
/// - **決定**: ほかにアカウントがあれば「他のアカウントにも適用しますか」を聞き、
///   - すべてのアカウントに適用 = **共有のタブ**(一覧も構成も 1 つ、[NodeTab.shared])
///   - このアカウントだけ = このアカウントのタブ
///   として保存する。キャンセル / 外側を押すと何も作らずに閉じる。
/// - 作ったタブのスコープ(`tl.node:<id>`)を返す。作らなければ null。
Future<String?> showTimelineCreateFow(WidgetRef ref) async {
  // 呼んだ画面(一時変更 FOW の中など)は先に消えることがあるので、ref ではなく container を持つ。
  final container = ProviderScope.containerOf(ref.context, listen: false);
  final manager = container.read(overlayManagerProvider);
  if (manager.contains(timelineCreateFowId)) return null;
  final id = 'node:${DateTime.now().millisecondsSinceEpoch}';
  final scope = 'tl.$id';
  final name = TextEditingController();
  String? created;
  try {
    await manager.showFow<void>(
      id: timelineCreateFowId,
      semanticsLabel: 'タイムラインを作成',
      spec: FowSpec(
        type: FowPanelType.widget,
        initialHeightFactor: timelineTempExpandedFactor,
        minHeightFactor: 0.3,
        maxHeightFactor: 0.9,
        dockAboveFooter: true,
      ),
      barrierBehavior: OverlayBarrierBehavior.dismissDiscard,
      builder: (ctx, handle) => Consumer(
        builder: (_, bodyRef, _) => _CreateBody(
          scope: scope,
          name: name,
          onCancel: handle.close,
          onConfirm: () async {
            if (await _create(bodyRef, id: id, label: name.text)) {
              created = scope;
              handle.close();
            }
          },
        ),
      ),
    );
  } finally {
    container.read(tlTemporaryConfigsProvider.notifier).clear(scope);
    name.dispose();
  }
  return created;
}

/// 保存する。ほかにアカウントがあれば共有するかを聞く。
Future<bool> _create(WidgetRef ref, {required String id, required String label}) async {
  final scope = 'tl.$id';
  final sessions = ref.read(sessionsProvider).value?.sessions ?? const [];
  final name = label.trim().isEmpty ? 'タイムライン ${ref.read(nodeTabsProvider).length + 1}' : label.trim();
  var shared = false;
  if (sessions.length > 1) {
    shared = await ref.read(overlayManagerProvider).showAlert(
          id: 'tl.create.share',
          title: '他のアカウントにも適用しますか',
          message: '「すべてのアカウントに適用」にすると、どのアカウントでもこのタイムラインが並び、中身の変更も全部に効きます(あとで … メニューから変えられます)。',
          confirmText: 'すべてのアカウントに適用',
          cancelText: 'このアカウントだけ',
        );
  }
  final accounts = [for (final s in sessions) '${s.account}'];
  final cfg = ref.read(tlTemporaryConfigsProvider)[scope] ?? defaultTlConfig(scope, bundleAccounts: accounts);
  final area = nodeprogAreaFor(shared ? null : ref.read(currentAccountProvider)?.key, scope);
  final store = ref.read(settingsAreaProvider(area).notifier);
  await store.set('tlcfg', jsonEncode(cfg.toJson()));
  await store.set('graph', jsonEncode(compileTlConfig(cfg, scope: scope).toJson()));
  await saveNodeTabs(ref, [...ref.read(nodeTabsProvider), NodeTab(id: id, label: name, shared: shared)]);
  return true;
}

class _CreateBody extends StatelessWidget {
  const _CreateBody({required this.scope, required this.name, required this.onCancel, required this.onConfirm});
  final String scope;
  final TextEditingController name;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(children: [
      SizedBox(
        key: timelineCreateHeaderKey,
        height: 40,
        child: Row(children: [
          TextButton(key: const ValueKey('tl.create.cancel'), onPressed: onCancel, child: Text('キャンセル', style: TextStyle(color: scheme.onSurfaceVariant))),
          Expanded(child: Center(child: Text('タイムラインを作成', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis))),
          TextButton(key: const ValueKey('tl.create.confirm'), onPressed: onConfirm, child: Text('決定', style: TextStyle(color: scheme.primary))),
        ]),
      ),
      Expanded(child: TimelineConfigScreen(scope: scope, temporary: true, nameController: name)),
    ]);
  }
}
