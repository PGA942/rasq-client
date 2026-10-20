import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart' show AccountSession;

import '../app/providers.dart' show overlayManagerProvider;
import '../l10n/l10n.dart';

/// 既存の RASQ アカウントへのログインで、**この端末で開いていた SNS アカウントを持ち込むか**を聞く (D-461)。
///
/// 前は、ログインしたアカウントのバンドル(Central の `sns_links`)にあって、この端末にもログインがある SNS アカウントを
/// 黙ってそのアカウントに入れていた (D-316 の `adoptKeys`)。バンドルには、この端末でログアウトしても消えずに残った行
/// (D-461 の同期の不具合)もあり、「ログインの直前に開いていたアカウントが、ログインした RASQ アカウントに入ってしまう」
/// ことになっていた。Web 版では、ログイン前にメモリにだけ持っていた SNS のセッションを、ログインした先の保管庫へ
/// そのまま預けていた。
///
/// いまは、持ち込むものを本人が 1 件ずつ選ぶ(**既定は持ち込まない**)。選ばなかったものは「この端末のみ」に残り、
/// ログインした RASQ アカウントのバンドルへは送らない(Web 版では保管庫へ預けない — タブを閉じると消える)。
@immutable
class RasqLoginCarryCandidate {
  const RasqLoginCarryCandidate({required this.session, this.inBundle = false});

  /// この端末の SNS のセッション。
  final AccountSession session;

  /// ログインした RASQ アカウントのバンドル(Central)にも載っている(前にこのアカウントでつないだ)。
  final bool inBundle;

  String get key => session.account.key;
}

/// 問いの中身。
@immutable
class RasqLoginCarryQuestion {
  const RasqLoginCarryQuestion({required this.accountHandle, required this.candidates});

  /// ログインした RASQ アカウントのハンドル。
  final String accountHandle;
  final List<RasqLoginCarryCandidate> candidates;
}

/// 問いを出す口。戻り = 持ち込む SNS アカウントのキー(`AccountId.key`)。null / 空 = 持ち込まない。テストで差し替える。
typedef RasqLoginCarryAsk = Future<Set<String>?> Function(RasqLoginCarryQuestion question);

final rasqLoginCarryAskProvider = Provider<RasqLoginCarryAsk>((ref) => (q) => showRasqLoginCarry(ref.read(overlayManagerProvider), q));

/// 既定の問い: 1 件ずつのチェック(どれも外れた状態から)と、「選んだアカウントを加える」/「加えない」。
Future<Set<String>?> showRasqLoginCarry(OverlayManager overlays, RasqLoginCarryQuestion q) async {
  const id = 'rasqLogin.carry';
  final picked = ValueNotifier<Set<String>>(const {});
  final handle = q.accountHandle.isEmpty ? appL10n.sessionCarryThisAccount : '@${q.accountHandle}';
  final result = await overlays.show(RasqOverlayEntry(
    id: id,
    layer: OverlayLayer.modal,
    alignment: Alignment.center,
    semanticsLabel: appL10n.sessionCarrySemantics,
    builder: (context, h) {
      final scheme = Theme.of(context).colorScheme;
      final text = Theme.of(context).textTheme;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Material(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: ValueListenableBuilder<Set<String>>(
              valueListenable: picked,
              builder: (context, value, _) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(context.l10n.sessionCarryTitle(q.candidates.length, handle),
                    style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(context.l10n.sessionCarryMessage(handle),
                    style: text.bodyMedium),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: ListView(shrinkWrap: true, children: [
                    for (final c in q.candidates)
                      CheckboxListTile(
                        key: ValueKey('$id.${c.key}'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: value.contains(c.key),
                        onChanged: (on) => picked.value = on == true ? {...value, c.key} : {for (final k in value) if (k != c.key) k},
                        title: Text(c.session.displayName?.isNotEmpty == true ? c.session.displayName! : '@${c.session.account.handle}', overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          '@${c.session.account.handle}@${c.session.account.instance}${c.inBundle ? context.l10n.sessionCarryInBundle : ''}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ]),
                ),
                const SizedBox(height: 4),
                OverflowBar(alignment: MainAxisAlignment.end, overflowAlignment: OverflowBarAlignment.end, children: [
                  TextButton(key: const ValueKey('$id.none'), onPressed: () => h.close(result: const <String>{}), child: Text(context.l10n.sessionCarryNone)),
                  TextButton(
                    key: const ValueKey('$id.add'),
                    onPressed: value.isEmpty ? null : () => h.close(result: value),
                    child: Text(context.l10n.sessionCarryAdd(value.length), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      );
    },
  ));
  picked.dispose();
  return result is Set<String> ? result : null;
}
