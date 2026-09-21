import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../backend/orgate_client.dart';
import '../backend/rasq_account.dart';
import 'session_providers.dart';
import 'session_storage.dart';

/// Web 版の保存先 (D-300 / S-033): **SNS のログイン情報(アクセストークン入り)はブラウザに置かず、RASQ アカウントの保管庫 (Central) に預ける**。
///
/// - 預けるのは [vaulted] のキーだけ(SNS のセッション一覧)。RASQ 自身のトークンなど、ほかのキーは [local](ブラウザ)に置く —
///   保管庫を開くのに RASQ のトークンが要るので。
/// - RASQ アカウントにログインしていない間は、メモリにだけ持つ(タブを閉じると消える。Web 版は RASQ アカウントでのログインが前提)。
///   ログインしたら、メモリのぶんを預ける。RASQ アカウントが変わったら、SNS のセッションを読み直す。
/// - 前の版(ブラウザに置いていた)のぶんが残っていれば、保管庫へ移してブラウザからは消す。
class CentralVaultSessionStorage implements SessionStorage {
  CentralVaultSessionStorage(this._ref, this.local) {
    // RASQ アカウントの読み込みは、この保存先を読む。作っている最中に読ませないよう、見張りはひと呼吸おいてから始める。
    Future.microtask(_watchAccount);
  }

  void _watchAccount() {
    if (!_ref.mounted) return;
    _ref.listen(orgateAccountProvider.select((a) => a.value?.id), (prev, next) async {
      if (prev == next) return;
      if (next != null) {
        // ログインした: メモリにだけ持っていたぶんを預ける。
        for (final e in Map.of(_memory).entries) {
          if (await _put(e.key, e.value)) _memory.remove(e.key);
        }
      } else {
        _memory.clear();
      }
      _ref.invalidate(sessionsProvider);
    });
  }

  final Ref _ref;
  final SessionStorage local;
  final Map<String, String> _memory = {};

  static const vaulted = {SessionsNotifier.storageKey};

  Future<OrgateClient?> _client() async {
    try {
      if (await _ref.read(orgateAccountProvider.future) == null) return null;
    } catch (_) {
      return null;
    }
    return _ref.read(centralClientProvider);
  }

  Future<bool> _put(String key, String value) async {
    final client = await _client();
    if (client == null) return false;
    try {
      await client.putJson('/me/vault/$key', {'value': value});
      return true;
    } on OrgateException catch (e) {
      debugPrint('RASQ: ログイン情報を保管庫へ預けられませんでした: ${e.message}');
      return false;
    }
  }

  @override
  Future<String?> read(String key) async {
    if (!vaulted.contains(key)) return local.read(key);
    final client = await _client();
    if (client == null) return _memory[key];
    try {
      final value = (await client.getJson('/me/vault/$key'))['value'];
      if (value is String) return value;
    } on OrgateException catch (e) {
      if (e.code.code != '404') {
        debugPrint('RASQ: 保管庫を読めませんでした: ${e.message}');
        return _memory[key];
      }
    }
    // 保管庫は空。前の版がブラウザに置いていたぶんがあれば、預けてからブラウザのぶんを消す。
    final old = _memory[key] ?? await local.read(key);
    if (old != null && await _put(key, old)) {
      _memory.remove(key);
      await local.delete(key);
    }
    return old;
  }

  @override
  Future<void> write(String key, String value) async {
    if (!vaulted.contains(key)) return local.write(key, value);
    if (await _put(key, value)) {
      _memory.remove(key);
    } else {
      _memory[key] = value;
    }
  }

  @override
  Future<void> delete(String key) async {
    if (!vaulted.contains(key)) return local.delete(key);
    _memory.remove(key);
    final client = await _client();
    try {
      await client?.delete('/me/vault/$key');
    } on OrgateException catch (e) {
      debugPrint('RASQ: 保管庫から消せませんでした: ${e.message}');
    }
  }
}
