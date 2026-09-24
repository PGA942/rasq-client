import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../backend/orgate_client.dart';
import '../../backend/rasq_account.dart';
import '../../backend/rasq_account_page_api.dart';
import '../../shell/headers.dart';
import 'rasq_account_page_screen.dart' show RasqSnsTileChip;

/// 持ち主の確認ができる SNS(Central が公開のプロフィールを読める種類。D-313)。
const rasqVerifiableKinds = {'misskey', 'mastodon', 'bluesky'};

/// 確認の文を「どこに貼るか」を、その SNS の呼び名で。
String rasqVerifyWhere(String kind, List<String> where) {
  final fields = where.contains('fields');
  return switch (kind) {
    'misskey' when fields => '自己紹介か、プロフィールの「追加情報」のどれかに貼って、保存してください。',
    'mastodon' when fields => '自己紹介か、プロフィールの「補足情報」のどれかに貼って、保存してください。',
    'bluesky' => '自己紹介(プロフィールの説明)に貼って、保存してください。',
    _ when fields => '自己紹介か、プロフィールの項目のどれかに貼って、保存してください。',
    _ => '自己紹介に貼って、保存してください。',
  };
}

/// 持ち主の確認のエラーを、画面に出す 1 行へ。
String rasqVerifyMessage(OrgateException e) => switch (e.code.code) {
      '404' => 'この SNS アカウントは、RASQ アカウントにつながっていません',
      '400' when e.message.contains('not supported') => 'この SNS は、まだ持ち主の確認に対応していません',
      '429' => '試す回数が多すぎます。しばらく待ってから、もう一度お試しください',
      '409' when e.message.contains('verify/start') => 'まだ確認の文を作っていないか、期限が切れています。「確認の文を作る」からやり直してください',
      '409' when e.message.contains('code was not found') => 'プロフィールに確認の文が見つかりませんでした。保存したか、公開のプロフィールに出ているかを確かめてください(反映まで少しかかることがあります)',
      '409' when e.message.contains('was not found') => 'その SNS アカウントの公開のプロフィールが見つかりませんでした',
      '409' => 'その SNS のプロフィールを読めませんでした。少し待ってから、もう一度お試しください',
      _ => '確認できませんでした: ${e.message}',
    };

/// Keybase のエラーを、画面に出す 1 行へ。
String rasqKeybaseMessage(OrgateException e) => switch (e.code.code) {
      '400' when e.message.contains('username') => 'Keybase のユーザー名(英小文字・数字・_、2〜16 文字)を入れてください',
      '400' when e.message.contains('signature:') => '署名を読めませんでした。BEGIN KEYBASE SALTPACK SIGNED MESSAGE から END KEYBASE SALTPACK SIGNED MESSAGE. までを、そのまま貼ってください',
      '400' when e.message.contains('not the statement') => '署名した文が違います。上のコマンドを、そのまま使ってください',
      '400' when e.message.contains('current key') => 'その Keybase のユーザーの鍵で署名されていません',
      '400' when e.message.contains('no such keybase user') => 'その Keybase のユーザーは見つかりませんでした',
      '409' when e.message.contains('another rasq account') => 'その Keybase は、別の RASQ アカウントにつながっています',
      '409' => '文の期限が切れたか、まだ作っていません。「署名する文を作る」からやり直してください',
      '429' => '試す回数が多すぎます。しばらく待ってから、もう一度お試しください',
      'B03' => 'Keybase に繋がりませんでした。少し待ってから、もう一度お試しください',
      _ => '確かめられませんでした: ${e.message}',
    };

String _date(DateTime? t) {
  if (t == null) return '';
  final l = t.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}/${two(l.month)}/${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
}

void _copy(BuildContext context, String text, String done) {
  unawaited(Clipboard.setData(ClipboardData(text: text))); // 待たない(クリップボードの無い環境で止まらないように)
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(done)));
}

/// 貼る文 / コマンドを見せる枠(選んでコピーもできる)。
class _CodeBox extends StatelessWidget {
  const _CodeBox({required this.valueKey, required this.text, this.mono = false});
  final Key valueKey;
  final String text;
  final bool mono;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(RasqSpacing.sm),
      decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(RasqSizes.radiusMd)),
      child: SelectableText(text, key: valueKey, style: mono ? RasqTypography.bodySmall.copyWith(fontFamily: 'monospace') : RasqTypography.body),
    );
  }
}

/// SNS アカウントの持ち主の確認 (D-313)。
///
/// 1. 「確認の文を作る」→ Central が一度きりのコード入りの文をくれる(24 時間)。
/// 2. その SNS で、自分で自己紹介(かプロフィールの項目)に貼って保存する。**アプリからは書き換えない**
///    (プロフィールを編集できるプラグインでログインしていても、手で貼ってもらう。自動で書くのは今後の課題)。
/// 3. 「確認する」→ Central が公開のプロフィールを読んで、コードがあれば確認済み。確認できたら文は消してよい。
class RasqSnsVerifyScreen extends ConsumerStatefulWidget {
  const RasqSnsVerifyScreen({super.key, required this.accountKey});
  final String accountKey;
  @override
  ConsumerState<RasqSnsVerifyScreen> createState() => _RasqSnsVerifyScreenState();
}

class _RasqSnsVerifyScreenState extends ConsumerState<RasqSnsVerifyScreen> {
  RasqSnsLink? _link;
  bool _loaded = false;
  RasqSnsVerifyStart? _start;
  bool _busy = false;
  String? _error;

  /// 確認できた直後の案内(文を消してよい)。
  bool _justVerified = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final api = ref.read(rasqAccountPageApiProvider);
    try {
      final links = await api?.mySnsLinks() ?? const <RasqSnsLink>[];
      if (mounted) setState(() => _link = links.where((l) => l.accountKey == widget.accountKey).firstOrNull);
    } on OrgateException catch (e) {
      if (mounted) setState(() => _error = rasqVerifyMessage(e));
    } finally {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _run(Future<void> Function(RasqAccountPageApi api) body) async {
    final api = ref.read(rasqAccountPageApiProvider);
    if (api == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await body(api);
    } on OrgateException catch (e) {
      if (mounted) setState(() => _error = rasqVerifyMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _begin() => _run((api) async {
        final s = await api.startSnsVerification(widget.accountKey);
        if (mounted) setState(() => _start = s);
      });

  Future<void> _check() => _run((api) async {
        final l = await api.checkSnsVerification(widget.accountKey);
        if (mounted) {
          setState(() {
            _link = l;
            _start = null;
            _justVerified = l.tile.verified;
          });
        }
      });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = RasqTokens.of(context);
    final caption = RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant);
    final link = _link;
    final kind = link?.tile.kind ?? widget.accountKey.split(':').first;
    return Scaffold(
      appBar: const RasqPageHeader(title: '持ち主を確認'),
      body: !_loaded
          ? const RasqLoading()
          : ListView(padding: const EdgeInsets.all(RasqSpacing.page), children: [
              if (link == null)
                Text('この SNS アカウントは、RASQ アカウントにつながっていません。', style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant))
              else ...[
                Align(alignment: Alignment.centerLeft, child: SizedBox(height: 40, child: RasqSnsTileChip(tile: link.tile))),
                const SizedBox(height: RasqSpacing.md),
                if (link.tile.verified) ...[
                  Row(key: const ValueKey('snsVerify.done'), children: [
                    Icon(Icons.verified, size: 20, color: scheme.primary),
                    const SizedBox(width: 6),
                    Expanded(child: Text('確認済み(${link.tile.verifiedLabel})', style: RasqTypography.body.copyWith(fontWeight: FontWeight.w700))),
                  ]),
                  const SizedBox(height: RasqSpacing.sm),
                  if (_justVerified) Text('確認できました。プロフィールに貼った文は、もう消してかまいません。', key: const ValueKey('snsVerify.removeHint'), style: RasqTypography.bodySmall),
                  const SizedBox(height: RasqSpacing.xs),
                  Text('アカウントページと、SNS のプロフィールに出る RASQ アカウントの欄に、確認済みの印が付きます。この SNS アカウントを外すまで続きます。', style: caption),
                ] else if (!rasqVerifiableKinds.contains(kind))
                  Text('この SNS は、まだ持ち主の確認に対応していません(公開のプロフィールを読める Misskey / Mastodon / Bluesky だけ)。', style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant))
                else ...[
                  Text('この SNS アカウントが、あなたのものかを確かめます。確認の文をその SNS のプロフィールに一時的に貼ってもらい、RASQ がその公開のプロフィールを読んで確かめます。', style: RasqTypography.bodySmall),
                  const SizedBox(height: RasqSpacing.xs),
                  Text('確かめると、アカウントページと SNS のプロフィールの RASQ アカウントの欄に、確認済みの印が付きます。同じ SNS アカウントをほかの人がつないでいても、確認した人が優先されます。', style: caption),
                  const SizedBox(height: RasqSpacing.md),
                  if (_start == null)
                    FilledButton(key: const ValueKey('snsVerify.start'), onPressed: _busy ? null : _begin, child: const Text('確認の文を作る'))
                  else ...[
                    Text('1. この文をコピーする', style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: RasqSpacing.xs),
                    _CodeBox(valueKey: const ValueKey('snsVerify.text'), text: _start!.text),
                    Wrap(spacing: RasqSpacing.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      TextButton.icon(key: const ValueKey('snsVerify.copy'), onPressed: () => _copy(context, _start!.text, '確認の文をコピーしました'), icon: const Icon(Icons.copy, size: 16), label: const Text('コピー')),
                      if (_start!.expiresAt != null) Text('${_date(_start!.expiresAt)} まで有効', style: caption),
                    ]),
                    const SizedBox(height: RasqSpacing.sm),
                    Text('2. その SNS のプロフィールに貼る', style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: RasqSpacing.xs),
                    Text(rasqVerifyWhere(kind, _start!.where), key: const ValueKey('snsVerify.where'), style: RasqTypography.bodySmall),
                    Text('RASQ からプロフィールを書き換えることはしません。その SNS で、ご自分で貼ってください。', style: caption),
                    const SizedBox(height: RasqSpacing.sm),
                    Text('3. 貼ったら「確認する」', style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700)),
                  ],
                  const SizedBox(height: RasqSpacing.sm),
                  Wrap(spacing: RasqSpacing.sm, runSpacing: RasqSpacing.xs, children: [
                    // 前に作った文を貼ってあれば、作り直さずに確かめられる。
                    FilledButton.tonal(key: const ValueKey('snsVerify.check'), onPressed: _busy ? null : _check, child: const Text('確認する')),
                    if (_start != null) TextButton(key: const ValueKey('snsVerify.restart'), onPressed: _busy ? null : _begin, child: const Text('文を作り直す')),
                  ]),
                ],
              ],
              // 失敗は、押したボタンのすぐ下に出す(画面の一番下 = いま見ているところ)。
              if (_error != null) Padding(padding: const EdgeInsets.only(top: RasqSpacing.md), child: Text(_error!, key: const ValueKey('snsVerify.error'), style: RasqTypography.bodySmall.copyWith(color: tokens.danger))),
              if (_busy) const Padding(padding: EdgeInsets.only(top: RasqSpacing.md), child: RasqLoading()),
            ]),
    );
  }
}

/// RASQ アカウントの Keybase (D-313)。
///
/// Keybase のユーザー名を入れる → 署名してもらう文と `keybase sign -m '…'` のコマンド(コピー)→ 出てきた署名を貼る →
/// Central が Keybase の公開の鍵で確かめる。確かめた Keybase は公開ページに「Keybase: @user」で出る。
/// Keybase の証明(Mastodon など)に、つないでいる SNS アカウントがあれば、それも確認済みになる。
class RasqKeybaseScreen extends ConsumerStatefulWidget {
  const RasqKeybaseScreen({super.key});
  @override
  ConsumerState<RasqKeybaseScreen> createState() => _RasqKeybaseScreenState();
}

class _RasqKeybaseScreenState extends ConsumerState<RasqKeybaseScreen> {
  final _username = TextEditingController();
  final _signature = TextEditingController();
  RasqKeybaseStart? _start;
  bool _busy = false;
  String? _error;
  String? _message;

  @override
  void dispose() {
    _username.dispose();
    _signature.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function(RasqAccountPageApi api) body) async {
    final api = ref.read(rasqAccountPageApiProvider);
    if (api == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await body(api);
    } on OrgateException catch (e) {
      if (mounted) setState(() => _error = rasqKeybaseMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _linksMessage(RasqKeybaseStatus st) => st.verifiedLinks.isEmpty
      ? 'Keybase の証明に、つないでいる SNS アカウントはありませんでした。'
      : 'Keybase の証明で、つないでいる SNS アカウント ${st.verifiedLinks.length} 件も確認済みになりました。';

  Future<void> _begin() => _run((api) async {
        final s = await api.startKeybase(_username.text.trim().replaceFirst(RegExp('^@'), '').toLowerCase());
        if (mounted) {
          setState(() {
            _start = s;
            _signature.clear();
          });
        }
      });

  Future<void> _verify() => _run((api) async {
        final st = await api.verifyKeybase(signature: _signature.text.trim());
        await ref.read(orgateAccountProvider.notifier).refresh();
        if (mounted) {
          setState(() {
            _start = null;
            _signature.clear();
            _message = '@${st.keybase?.username ?? ''} をつなぎました。${_linksMessage(st)}';
          });
        }
      });

  Future<void> _refresh() => _run((api) async {
        final st = await api.verifyKeybase();
        if (mounted) setState(() => _message = _linksMessage(st));
      });

  Future<void> _unlink() => _run((api) async {
        await api.unlinkKeybase();
        await ref.read(orgateAccountProvider.notifier).refresh();
        if (mounted) setState(() => _message = 'Keybase を外しました。Keybase の証明で確認していた SNS アカウントは、未確認に戻ります。');
      });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = RasqTokens.of(context);
    final caption = RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant);
    final account = ref.watch(orgateAccountProvider).value;
    final kb = account?.keybase;
    return Scaffold(
      appBar: const RasqPageHeader(title: 'Keybase'),
      body: account == null
          ? Padding(padding: const EdgeInsets.all(RasqSpacing.page), child: Text('RASQ アカウントにログインしていません。', style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant)))
          : ListView(padding: const EdgeInsets.all(RasqSpacing.page), children: [
              if (kb != null) ...[
                Row(children: [
                  Icon(Icons.verified, size: 20, color: scheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: InkWell(
                      key: const ValueKey('keybase.linked'),
                      onTap: () => launchUrl(kb.profileUrl, mode: LaunchMode.externalApplication),
                      child: Text('Keybase: @${kb.username}', style: RasqTypography.body.copyWith(fontWeight: FontWeight.w700, color: scheme.primary)),
                    ),
                  ),
                ]),
                if (kb.verifiedAt != null) Text('${_date(kb.verifiedAt)} に確認', style: caption),
                const SizedBox(height: RasqSpacing.sm),
                Text('アカウントページに「Keybase: @${kb.username}」が出ます。Keybase で Mastodon などの証明を足したら、「証明を読み直す」で、つないでいる SNS アカウントも確認済みになります。', style: caption),
                const SizedBox(height: RasqSpacing.md),
                Wrap(spacing: RasqSpacing.sm, runSpacing: RasqSpacing.xs, children: [
                  FilledButton.tonal(key: const ValueKey('keybase.refresh'), onPressed: _busy ? null : _refresh, child: const Text('証明を読み直す')),
                  TextButton(key: const ValueKey('keybase.unlink'), onPressed: _busy ? null : _unlink, child: Text('Keybase を外す', style: TextStyle(color: tokens.danger))),
                ]),
              ] else ...[
                Text('Keybase のアカウントで署名して、この RASQ アカウントとつなぎます。つないだ Keybase は、アカウントページに出ます(Keybase のプロフィールと同じく公開です)。', style: RasqTypography.bodySmall),
                const SizedBox(height: RasqSpacing.md),
                Text('Keybase のユーザー名', style: caption),
                const SizedBox(height: 4),
                RasqInput(key: const ValueKey('keybase.username'), controller: _username, hintText: 'username'),
                const SizedBox(height: RasqSpacing.sm),
                FilledButton(key: const ValueKey('keybase.start'), onPressed: _busy ? null : _begin, child: Text(_start == null ? '署名する文を作る' : '文を作り直す')),
                if (_start != null) ...[
                  const SizedBox(height: RasqSpacing.md),
                  Text('1. Keybase が入っている端末で、このコマンドを実行する', style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: RasqSpacing.xs),
                  _CodeBox(valueKey: const ValueKey('keybase.command'), text: _start!.command, mono: true),
                  Wrap(spacing: RasqSpacing.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    TextButton.icon(key: const ValueKey('keybase.copy'), onPressed: () => _copy(context, _start!.command, 'コマンドをコピーしました'), icon: const Icon(Icons.copy, size: 16), label: const Text('コピー')),
                    if (_start!.expiresAt != null) Text('${_date(_start!.expiresAt)} まで有効', style: caption),
                  ]),
                  Text('署名する文: ${_start!.statement}', key: const ValueKey('keybase.statement'), style: caption),
                  const SizedBox(height: RasqSpacing.sm),
                  Text('2. 出てきた署名を、BEGIN から END … MESSAGE. まで貼る', style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: RasqSpacing.xs),
                  RasqInput(key: const ValueKey('keybase.signature'), controller: _signature, maxLines: 6, hintText: 'BEGIN KEYBASE SALTPACK SIGNED MESSAGE. …'),
                  const SizedBox(height: RasqSpacing.sm),
                  FilledButton.tonal(key: const ValueKey('keybase.verify'), onPressed: _busy ? null : _verify, child: const Text('確かめる')),
                ],
              ],
              // 結果は、押したボタンのすぐ下に出す。
              if (_error != null) Padding(padding: const EdgeInsets.only(top: RasqSpacing.md), child: Text(_error!, key: const ValueKey('keybase.error'), style: RasqTypography.bodySmall.copyWith(color: tokens.danger))),
              if (_message != null) Padding(padding: const EdgeInsets.only(top: RasqSpacing.md), child: Text(_message!, key: const ValueKey('keybase.message'), style: RasqTypography.bodySmall)),
              if (_busy) const Padding(padding: EdgeInsets.only(top: RasqSpacing.md), child: RasqLoading()),
            ]),
    );
  }
}
