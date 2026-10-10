import 'package:flutter/foundation.dart';
import 'package:plugin_runtime/plugin_runtime.dart' show fetchHostPermitted;

/// プラグインに許す内容 (セキュリティ確認 2026-10-09 の [8] / [14]): 選んだ版の**マニフェストそのもの**から読む
/// 権限・接続先・アクセスできるデータ(差し込む面 = 受け取る入力)・目的(権限ごとの用途理由とデータの扱い)。
/// `.rasqpkg` は root と子を全部合わせる(子にだけ足した権限も見落とさない)。
///
/// 利用規約 第4条 2項「利用者が最後に許可した内容よりも … 広がる更新は、自動では有効にしません」の比べる元は、
/// 端末に記録した**最後の承認**(`InstalledPlugin.approvedScope`)。サーバーの `permissionsAdded`(直前の公開版との差分)は
/// 版を飛ばすと空になるので、表示の参考にしか使わない。
@immutable
class PluginScope {
  const PluginScope({this.permissions = const {}, this.hosts = const {}, this.instance = false, this.slots = const {}, this.reasons = const {}, this.dataHandling = ''});

  /// マニフェストの `permissions`。
  final Set<String> permissions;

  /// `network.hosts`(`*` / `*.example.com` を含む)。
  final Set<String> hosts;

  /// `network.instance`(ログイン先のインスタンスへ繋ぐ)。
  final bool instance;

  /// 差し込む面(`slots`)= プラグインに渡る入力(投稿 / 画像 / 本文 …)。
  final Set<String> slots;

  /// 権限 → 用途理由(配布物の目次 `root.safety.permissions`)。
  final Map<String, String> reasons;

  /// データの扱い(`root.safety.dataHandling`)。
  final String dataHandling;

  bool get isEmpty => permissions.isEmpty && hosts.isEmpty && !instance && slots.isEmpty && reasons.isEmpty && dataHandling.isEmpty;

  /// マニフェスト(1 つ以上)と、目次の安全性ブロックから。
  factory PluginScope.of(Iterable<Map<String, Object?>> manifests, {Object? safety}) {
    final permissions = <String>{}, hosts = <String>{}, slots = <String>{};
    var instance = false;
    for (final m in manifests) {
      permissions.addAll(_strings(m['permissions']));
      slots.addAll(_strings(m['slots']));
      if (m['network'] case final Map n) {
        hosts.addAll(_strings(n['hosts']));
        if (n['instance'] == true) instance = true;
      }
    }
    final s = safety is Map ? safety : const {};
    return PluginScope(
      permissions: permissions,
      hosts: hosts,
      instance: instance,
      slots: slots,
      reasons: {
        for (final p in s['permissions'] as List? ?? const [])
          if (p is Map && p['permission'] is String && p['reason'] is String && (p['reason'] as String).trim().isNotEmpty) p['permission'] as String: (p['reason'] as String).trim(),
      },
      dataHandling: s['dataHandling'] is String ? (s['dataHandling'] as String).trim() : '',
    );
  }

  /// [approved](最後に許可した内容)より広がるところ。空 = 広がらない。[approved] が null(記録が無い)は何も許していない扱い。
  List<String> wideningOver(PluginScope? approved) {
    final a = approved ?? const PluginScope();
    return [
      for (final p in permissions.difference(a.permissions)) '権限 $p',
      for (final h in hosts) if (!_hostCovered(h, a.hosts)) '接続先 $h',
      if (instance && !a.instance) '接続先 ログイン先のインスタンス',
      for (final s in slots.difference(a.slots)) '使う場所 $s',
      // 目的: 許していた権限の用途理由が変わったら(広がったかは文からは決められないので、変わったら確かめ直す)。
      for (final e in reasons.entries)
        if (a.permissions.contains(e.key) && a.reasons[e.key] != e.value) '用途 ${e.key} — ${e.value}',
      if (dataHandling.isNotEmpty && dataHandling != a.dataHandling) 'データの扱い — ${dataHandling.length > 80 ? '${dataHandling.substring(0, 80)}…' : dataHandling}',
    ];
  }

  Map<String, Object?> toJson() => {
        'permissions': [...permissions]..sort(),
        'hosts': [...hosts]..sort(),
        if (instance) 'instance': true,
        'slots': [...slots]..sort(),
        if (reasons.isNotEmpty) 'reasons': reasons,
        if (dataHandling.isNotEmpty) 'dataHandling': dataHandling,
      };

  factory PluginScope.fromJson(Map<String, Object?> j) => PluginScope(
        permissions: _strings(j['permissions']).toSet(),
        hosts: _strings(j['hosts']).toSet(),
        instance: j['instance'] == true,
        slots: _strings(j['slots']).toSet(),
        reasons: {for (final e in ((j['reasons'] as Map?) ?? const {}).entries) if (e.value is String) '${e.key}': e.value as String},
        dataHandling: j['dataHandling'] as String? ?? '',
      );
}

/// [host] が許していた接続先 [approved] に収まるか(`*` = どこでも、`*.example.com` = そのサブドメイン)。
/// 判定は net.fetch と同じ fetchHostPermitted に寄せる。`*.a.example.com` は先頭のラベルが `*` のサブドメインとして
/// 渡せば、`*.example.com` / `*` にだけ収まり、`a.example.com` のような 1 つのホストには収まらない。
bool _hostCovered(String host, Set<String> approved) => fetchHostPermitted(host, approved);

List<String> _strings(Object? v) => [for (final s in v is List ? v : const []) if (s is String) s];

/// 利用者がこの場で内容を確かめて許した(インストールの確認シート / 版を切り替える前の確認)。
/// これを渡したインストール / 版の切り替えは、その版の内容を最後の承認(`InstalledPlugin.approvedScope`)として記録する。
/// 渡さない(自動のアップデート)ときは、最後の承認に収まる版だけを有効にする。
///
/// [version] / [sha512] = 確認シートで見た版(`manifest.version`)と配布物のダイジェスト(セキュリティ確認 2026-10-09 の [14])。
/// あれば、インストールはその版を取り直し、構成の版と配布物の SHA-512 が同じときだけ入れる
/// (シートを開いている間にストアの最新版が変わっても、確かめていない版は入れない)。
@immutable
class PluginConsent {
  const PluginConsent({this.version, this.sha512});
  final String? version;
  final String? sha512;
}
