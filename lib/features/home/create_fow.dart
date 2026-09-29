import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../backend/rasq_account.dart' show orgateAccountProvider;
import '../child_safe/child_safe_providers.dart' show childGateProvider;
import '../compose/compose_target.dart';
import '../compose/composer_sheet.dart';
import '../swing/swing_providers.dart';
import '../vc/astell_fows.dart' show openAstellCreateFow;

/// ホームの ＋ (D-378): 作るものを選ぶ FOW。投稿 / RASQ に投稿 / AsTell / Swing。
/// 使えるものが「投稿」だけなら、FOW を出さずにそのままコンポーザーを開く。

enum CreateChoice { post, rasq, astell, swing }

const createFowId = 'fow.create';

/// 今この端末で選べるもの(並び順どおり)。
List<CreateChoice> availableCreateChoices(WidgetRef ref) {
  final gate = ref.read(childGateProvider);
  final rasq = ref.read(orgateAccountProvider).value != null;
  return [
    CreateChoice.post,
    if (rasq) CreateChoice.rasq,
    if (gate.featureAllowed('astell.join')) CreateChoice.astell,
    if (ref.read(swingApiProvider) != null) CreateChoice.swing,
  ];
}

({IconData icon, String title, String subtitle}) createChoiceLabel(CreateChoice c) => switch (c) {
      CreateChoice.post => (icon: Icons.edit_outlined, title: '投稿', subtitle: 'いまのアカウントの SNS に投稿します'),
      CreateChoice.rasq => (icon: Icons.person_pin_outlined, title: 'RASQ に投稿', subtitle: 'RASQ アカウントのページに投稿します'),
      CreateChoice.astell => (icon: Icons.graphic_eq, title: 'AsTell を作る', subtitle: '声で話せる部屋を開きます'),
      CreateChoice.swing => (icon: Icons.bolt_outlined, title: 'Swing を作る', subtitle: 'フォロワーや RASQ リストの人に届き、時間がたつと消えます'),
    };

/// ＋ を押したとき。投稿したら [onPosted]。
Future<void> openCreateFow(BuildContext context, WidgetRef ref, {VoidCallback? onPosted}) async {
  final choices = availableCreateChoices(ref);
  CreateChoice? pick;
  if (choices.length == 1) {
    pick = choices.single;
  } else {
    pick = await ref.read(overlayManagerProvider).showFow<CreateChoice>(
          id: createFowId,
          spec: FowSpec(type: FowPanelType.widget, initialHeightFactor: 0.45, minHeightFactor: 0.3, maxHeightFactor: 0.7, title: '作成', cancelText: '閉じる'),
          semanticsLabel: '作成',
          barrierBehavior: OverlayBarrierBehavior.dismissDiscard,
          builder: (ctx, handle) => ListView(padding: EdgeInsets.zero, children: [
            for (final c in choices)
              RasqListTile(
                key: ValueKey('create.${c.name}'),
                leading: Icon(createChoiceLabel(c).icon),
                title: createChoiceLabel(c).title,
                subtitle: createChoiceLabel(c).subtitle,
                onTap: () => handle.close(result: c),
              ),
          ]),
        );
  }
  if (pick == null || !context.mounted) return;
  switch (pick) {
    case CreateChoice.post:
      final created = await showComposer(ref, const ComposeNormal());
      if (created != null) onPosted?.call();
    case CreateChoice.rasq:
      await showComposer(ref, const ComposeNormal(), rasqTarget: true);
    case CreateChoice.astell:
      await openAstellCreateFow(context, ref);
    case CreateChoice.swing:
      await context.push(Routes.swingNew);
  }
}
