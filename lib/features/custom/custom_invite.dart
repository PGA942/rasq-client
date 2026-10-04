import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart' show overlayManagerProvider;
import '../../backend/orgate_client.dart' show OrgateException;
import '../../backend/rasq_collections_api.dart' show RasqCollection, RasqCollectionKind;
import '../collections/rasq_collections.dart' show myRasqCollectionsProvider;
import '../swing/swing_client.dart';
import '../swing/swing_composer.dart' show swingTtlChoices;
import '../swing/swing_models.dart';
import '../swing/swing_providers.dart';

/// カスタムプラグインの「招待」を **Swing で**送る (D-424、Central S-079、契約 v0.20)。
///
/// 前は招待コード(`link:` のセッション)を作って配るだけだった。いまは、そのページ(shared)を **Swing として**届け、見た人は
/// **作った人のセッションに入る**(ページにセッションがあればそれ = `link:` / `profile:`、無ければ Swing のセッション `swing:<swingId>` を作る)。
///
/// 届け先のボタン(Swing の届け先と同じ: フォロワー / 自分の RASQ リスト)は**複数選べる**:
/// - **1 回押す** = 選ぶ(その人たちに Swing が届く)。もう一度押すと外す。
/// - **2 回続けて押す(ダブルタップ)** = 選んで、**RASQ の通知でも知らせる**(🔔。ORGATE の受信箱 / プッシュ、Central の `notify`)。
///   もう一度ダブルタップすると通知だけ外す(選んだまま)。通知つきを 1 回押すと、選ぶのも外す。
const customInviteFowId = 'custom.invite.swing';

/// 届け先 1 つの印。
enum InviteMark { off, swing, notify }

/// 届け先の選び方(フォロワー = `followers`、リスト = `list:<id>`)。
class SwingInviteSelection extends ChangeNotifier {
  final _marks = <String, InviteMark>{};

  static const followersKey = 'followers';
  static String listKey(String id) => 'list:$id';

  InviteMark markOf(String key) => _marks[key] ?? InviteMark.off;
  bool get isEmpty => _marks.values.every((m) => m == InviteMark.off);

  /// 1 回押した: 選ぶ / 外す。
  void tap(String key) => _set(key, markOf(key) == InviteMark.off ? InviteMark.swing : InviteMark.off);

  /// ダブルタップ: 通知つきにする / 通知だけ外す。
  void doubleTap(String key) => _set(key, markOf(key) == InviteMark.notify ? InviteMark.swing : InviteMark.notify);

  void _set(String key, InviteMark m) {
    if (markOf(key) == m) return;
    _marks[key] = m;
    notifyListeners();
  }

  SwingAudience _of(bool Function(InviteMark m) pick) => SwingAudience(
        followers: pick(markOf(followersKey)),
        lists: [for (final e in _marks.entries) if (e.key.startsWith('list:') && pick(e.value)) e.key.substring(5)],
      );

  /// Swing の届け先(選んだもの全部)。
  SwingAudience toAudience() => _of((m) => m != InviteMark.off);

  /// RASQ の通知でも知らせる先(ダブルタップしたもの)。
  SwingAudience toNotify() => _of((m) => m == InviteMark.notify);
}

/// 招待の FOW を開く。送れたら作った Swing(`plugin.sessionId` = 見た人が入るセッション)、やめたら null。
/// [sessionId] = いま入っている `link:` / `profile:` のセッション(無ければ Swing のセッションを作る)。
Future<Swing?> showCustomSwingInvite(WidgetRef ref, {required String pluginId, required String title, String? version, String? sessionId, int column = 0}) {
  return ref.read(overlayManagerProvider).showFow<Swing>(
        id: customInviteFowId,
        spec: FowSpec(type: FowPanelType.widget, title: 'Swing で招待', columnIndex: column, initialHeightFactor: 0.55, minHeightFactor: 0.3, maxHeightFactor: 0.9),
        semanticsLabel: 'Swing で招待',
        builder: (ctx, handle) => CustomSwingInviteBody(
          pluginId: pluginId,
          title: title,
          version: version,
          sessionId: sessionId,
          onSent: (s) => handle.close(result: s),
        ),
      );
}

/// 招待の FOW の中身。
class CustomSwingInviteBody extends ConsumerStatefulWidget {
  const CustomSwingInviteBody({super.key, required this.pluginId, required this.title, this.version, this.sessionId, required this.onSent});
  final String pluginId;
  final String title;
  final String? version;
  final String? sessionId;
  final ValueChanged<Swing> onSent;

  @override
  ConsumerState<CustomSwingInviteBody> createState() => _CustomSwingInviteBodyState();
}

class _CustomSwingInviteBodyState extends ConsumerState<CustomSwingInviteBody> {
  final _selection = SwingInviteSelection();
  final _text = TextEditingController();
  int _ttl = 24;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _selection.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final api = ref.read(swingApiProvider);
    if (api == null || _selection.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final swing = await api.createServed(NewSwing(
        kind: SwingKind.plugin,
        text: _text.text.trim(),
        plugin: SwingPlugin(id: widget.pluginId, version: widget.version, session: widget.sessionId ?? SwingPlugin.newSession),
        audience: _selection.toAudience(),
        notify: _selection.toNotify(),
        ttlHours: _ttl,
      ));
      ref.invalidate(mySwingsProvider);
      if (mounted) widget.onSent(swing);
    } on OrgateException catch (e) {
      if (mounted) setState(() => _error = customInviteErrorText(e));
    } catch (e) {
      if (mounted) setState(() => _error = '送れませんでした: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lists = ref.watch(myRasqCollectionsProvider(RasqCollectionKind.list)).value ?? const <RasqCollection>[];
    return ListenableBuilder(
      listenable: _selection,
      builder: (context, _) => ListView(key: const ValueKey('custom.invite'), padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, RasqSpacing.page), children: [
        Text('「${widget.title}」に招待', style: RasqTypography.body.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(
          widget.sessionId == null ? 'Swing で届けます。見た人は、あなたのページに一緒に入ります。' : 'Swing で届けます。見た人は、いま開いているページに一緒に入ります。',
          style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: RasqSpacing.sm),
        Text('届け先: 押す = Swing を届ける ・ 2 回続けて押す = RASQ の通知でも知らせる 🔔',
            key: const ValueKey('custom.invite.help'), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: RasqSpacing.xs),
        Wrap(spacing: RasqSpacing.xs, runSpacing: RasqSpacing.xs, children: [
          InviteTargetButton(
            key: const ValueKey('custom.invite.target.followers'),
            icon: Icons.people_outline,
            label: 'フォロワー',
            mark: _selection.markOf(SwingInviteSelection.followersKey),
            onTap: _busy ? null : () => _selection.tap(SwingInviteSelection.followersKey),
            onDoubleTap: _busy ? null : () => _selection.doubleTap(SwingInviteSelection.followersKey),
          ),
          for (final l in lists)
            InviteTargetButton(
              key: ValueKey('custom.invite.target.list.${l.id}'),
              icon: Icons.list_alt_outlined,
              label: l.name,
              mark: _selection.markOf(SwingInviteSelection.listKey(l.id)),
              onTap: _busy ? null : () => _selection.tap(SwingInviteSelection.listKey(l.id)),
              onDoubleTap: _busy ? null : () => _selection.doubleTap(SwingInviteSelection.listKey(l.id)),
            ),
        ]),
        if (lists.isEmpty) const RasqCaption('RASQ リストを作ると、リストに入れた人も招待できます', padding: EdgeInsets.only(top: RasqSpacing.xs)),
        const SizedBox(height: RasqSpacing.md),
        TextField(
          key: const ValueKey('custom.invite.text'),
          controller: _text,
          enabled: !_busy,
          maxLength: 200,
          decoration: const InputDecoration(isDense: true, hintText: 'ひとこと(なくてもよい)'),
        ),
        Wrap(spacing: RasqSpacing.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('消えるまで', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          for (final h in swingTtlChoices)
            ChoiceChip(key: ValueKey('custom.invite.ttl.$h'), label: Text('$h 時間'), selected: _ttl == h, onSelected: _busy ? null : (_) => setState(() => _ttl = h)),
        ]),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: RasqSpacing.xs),
            child: Text(_error!, key: const ValueKey('custom.invite.error'), style: RasqTypography.caption.copyWith(color: scheme.error)),
          ),
        const SizedBox(height: RasqSpacing.sm),
        FilledButton.icon(
          key: const ValueKey('custom.invite.send'),
          onPressed: _selection.isEmpty || _busy || ref.watch(swingApiProvider) == null ? null : _send,
          icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
          label: Text(_selection.toNotify().isEmpty ? 'Swing で招待' : 'Swing で招待(通知も送る)'),
        ),
      ]),
    );
  }
}

/// 招待が送れなかったときの 1 行 (D-424)。
String customInviteErrorText(OrgateException e) => switch (e.serverCode) {
      SwingApi.versionNotAvailable => 'このプラグインは、つないでいる RASQ サーバーのストアで配られていません(審査を通った版がありません)。アプリに入っているサンプルのままでは、みんなで使えません',
      'not_shared_page' => 'みんなで使うプラグインではありません',
      'session_not_shareable' => 'このページのセッションは Swing では招待できません',
      'swing_limit' => '同時に出しておける Swing は 20 個までです',
      _ => '送れませんでした: ${e.message}',
    };

/// 届け先のボタン (D-424): 押す = 選ぶ / 外す、ダブルタップ = 通知つき(🔔)/ 通知だけ外す。
class InviteTargetButton extends StatelessWidget {
  const InviteTargetButton({super.key, required this.icon, required this.label, required this.mark, this.onTap, this.onDoubleTap});
  final IconData icon;
  final String label;
  final InviteMark mark;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final on = mark != InviteMark.off;
    final bell = mark == InviteMark.notify;
    final fg = on ? scheme.onSecondaryContainer : scheme.onSurface;
    return Semantics(
      button: true,
      selected: on,
      label: '$label${bell ? '(通知も送る)' : ''}',
      hint: '押すと選ぶ / 外す。2 回続けて押すと、通知も送る',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.sm, vertical: 8),
          decoration: BoxDecoration(
            color: on ? scheme.secondaryContainer : scheme.surface,
            borderRadius: BorderRadius.circular(RasqSizes.radiusMd),
            border: Border.all(color: on ? scheme.secondary : scheme.outlineVariant, width: on ? 1.5 : 1),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(on ? Icons.check_circle : icon, size: 18, color: on ? scheme.secondary : scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(label, style: RasqTypography.bodySmall.copyWith(color: fg, fontWeight: on ? FontWeight.w700 : null)),
            if (bell) ...[
              const SizedBox(width: 6),
              Icon(Icons.notifications_active, key: const ValueKey('custom.invite.bell'), size: 16, color: scheme.secondary),
            ],
          ]),
        ),
      ),
    );
  }
}
