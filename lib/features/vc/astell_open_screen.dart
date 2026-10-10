import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../app/router.dart';
import '../../shell/headers.dart';
import 'astell_actions.dart';
import 'astell_links.dart';
import 'astell_models.dart';

/// リンクから開く AsTell ルーム (D-456): `/astell/<UUID か Base58 コード>`。
///
/// Central の Web のページの「Web クライアントで開く」(`/app/astell/<code>`、rasq-central S-092)と、
/// 「アプリで開く」(`rasq://astell/<id>` → `rasqDeepLinkLocation`)の着地点。ルームを引いて、タイルを押したときと
/// 同じ([openAstellRoomTile]: 参加中ならルームの FOW、ほかはプレビュー)ものをこの画面の上に開く。
/// FOW を閉じたあとも、ここから開き直す / AsTell のホームへ行ける。カスタムプラグインもルームの中で動く(Web では Worker、D-297)。
class AstellOpenScreen extends ConsumerStatefulWidget {
  const AstellOpenScreen({super.key, required this.roomRef});
  final String roomRef;
  @override
  ConsumerState<AstellOpenScreen> createState() => _AstellOpenScreenState();
}

class _AstellOpenScreenState extends ConsumerState<AstellOpenScreen> {
  AstellRoom? _room;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final room = await ref.read(astellRoomProvider(widget.roomRef).future);
      if (!mounted) return;
      if (room == null) return setState(() => _error = 'このルームは見つかりません(終了したか、リンクが違うかもしれません)');
      setState(() => _room = room);
      await _open();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _open() async {
    final room = _room;
    if (room != null && mounted) await openAstellRoomTile(context, ref, room);
  }

  @override
  Widget build(BuildContext context) {
    final room = _room;
    return Scaffold(
      appBar: const RasqPageHeader(title: 'ASTell', showMore: false),
      body: _error != null
          ? RasqEmptyView(
              key: const ValueKey('astell.open.error'),
              title: 'ルームを開けませんでした',
              hint: _error,
              action: TextButton(onPressed: () => context.go(Routes.vc), child: const Text('ASTell のホームへ')),
            )
          : room == null
              ? const Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5)))
              : RasqEmptyView(
                  key: const ValueKey('astell.open.room'),
                  title: room.title,
                  hint: 'ホスト: ${room.ownerDisplayName}(@${room.ownerHandle})',
                  action: Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                    FilledButton(key: const ValueKey('astell.open.again'), onPressed: _open, child: const Text('ルームを開く')),
                    TextButton(onPressed: () => context.go(Routes.vc), child: const Text('ASTell のホームへ')),
                  ]),
                ),
    );
  }
}
