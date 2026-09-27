import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import '../../app/router.dart' show routerProvider;
import 'timeline_config_screen.dart';
import 'tl_config_store.dart';

/// タイムライン一時変更 FOW (D-338) の id。
const timelineTempFowId = 'fow.timeline.temp';

/// タイムライン一時変更 FOW (D-338): TL のタブの `↓{タイムライン名}`(選んでいるタブをもう一度押す)で開く。
///
/// **stick FOW**(返信のコンポーザーと同じ: スクリム無しでフッターの上に貼り付き、後ろの TL を見ながら触れる)。中身は
/// 「タイムラインをカスタマイズ」の使い回し([TimelineConfigScreen] の `temporary`)で、いちばん上に**タイムライン本体から
/// 探す**検索欄を足したもの。変更は保存せず、その TL にだけ一時的に効く(「この内容で保存」で保存した構成になる)。
/// [tabs] = FOW のタブ行に並べる TL((スコープ, 名前))、[scope] = 開いたときのタブ。[scopeSync] = ホームのタブと
/// 開いているタブを揃える口(FOW を閉じると null に戻す)。もう開いていれば閉じる。閉じると探す語は消える。
Future<void> showTimelineTempFow(WidgetRef ref, {required List<(String, String)> tabs, required String scope, ValueNotifier<String?>? scopeSync}) async {
  final manager = ref.read(overlayManagerProvider);
  if (manager.contains(timelineTempFowId)) {
    manager.close(timelineTempFowId);
    return;
  }
  final search = ref.read(timelineSearchProvider.notifier);
  final spec = FowSpec(
    type: FowPanelType.widget,
    confirmMode: FowConfirmMode.stick,
    initialHeightFactor: 0.5,
    minHeightFactor: 0.14,
    maxHeightFactor: 0.85,
    dockAboveFooter: true,
    heightStops: const [0.14, 0.5],
    freeAboveStops: true,
  );
  // 別の画面へ移ったら閉じる(返信の stick FOW と同じ作法, D-048)。ホームのタブの切り替えはページ遷移ではないので、閉じずに付いていく。
  final router = ref.read(routerProvider);
  void onNavigate() => manager.close(timelineTempFowId);
  router.routerDelegate.addListener(onNavigate);
  scopeSync?.value = scope;
  try {
    await manager.showFow<void>(
      id: timelineTempFowId,
      semanticsLabel: 'タイムラインを一時的に変える',
      spec: spec,
      builder: (ctx, handle) => TimelineConfigScreen(scope: scope, temporary: true, tabs: tabs, scopeSync: scopeSync, onClose: () => handle.close()),
    );
  } finally {
    router.routerDelegate.removeListener(onNavigate);
    scopeSync?.value = null;
    search.clearAll();
  }
}
