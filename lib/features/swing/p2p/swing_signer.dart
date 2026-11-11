import 'dart:convert';
import 'dart:typed_data';

import '../../../session/session_storage.dart';
import '../../../session/sns_share_crypto.dart';
import 'swing_manifest.dart';

/// Swing の署名鍵 (D-549 / Central S-128)。RASQ アカウントごとに、この端末だけの Ed25519 の種(32 バイト)を持つ。
/// ORGATE の端末の所持の証明(D-547)の鍵とは**別**(用途を混ぜない。Central が ORGATE を呼ばずに確かめられるように)。
///
/// 種は [SessionStorage](端末の安全な保管庫)に置き、外へは出さない。公開鍵だけを `PUT /me/swing-keys/{deviceId}` で登録する。
class SwingSigner {
  SwingSigner(this._storage);
  final SessionStorage _storage;

  static String _seedKey(String accountId) => 'rasq.swing.seed.$accountId';
  static String _registeredKey(String accountId, String deviceId) =>
      'rasq.swing.registered.$accountId.$deviceId';

  Future<Uint8List> _seed(String accountId) async {
    final raw = await _storage.read(_seedKey(accountId));
    if (raw != null) {
      try {
        final b = base64.decode(raw);
        if (b.length == 32) return Uint8List.fromList(b);
      } catch (_) {}
    }
    final seed = SnsShareCrypto.newDeviceSeed();
    await _storage.write(_seedKey(accountId), base64.encode(seed));
    return seed;
  }

  /// 公開鍵(32 バイトの base64)。
  Future<String> publicKey(String accountId) async => base64.encode(
    await SnsShareCrypto.signingPublicKeyOf(await _seed(accountId)),
  );

  /// まだ登録していなければ [register] を呼ぶ(登録した公開鍵を覚えておき、同じなら呼ばない)。
  Future<void> ensureRegistered(
    String accountId,
    String deviceId,
    Future<void> Function(String publicKey) register,
  ) async {
    final pk = await publicKey(accountId);
    if (await _storage.read(_registeredKey(accountId, deviceId)) == pk) return;
    await register(pk);
    await _storage.write(_registeredKey(accountId, deviceId), pk);
  }

  /// 登録を忘れる(Central が `swing_key_unknown` を返した: 外された / 別の端末で替えた)。次の [ensureRegistered] で登録し直す。
  Future<void> forgetRegistration(String accountId, String deviceId) =>
      _storage.delete(_registeredKey(accountId, deviceId));

  /// 目録に署名する(64 バイトの base64)。
  Future<String> sign(String accountId, Map<String, Object?> manifest) async =>
      base64.encode(
        await SnsShareCrypto.sign(
          await _seed(accountId),
          signingInput(manifestDigest(manifest)),
        ),
      );

  /// 目録の署名を確かめる(見る側)。鍵・署名の形が違う / 目録が正規化できない(整数でない数)も false。
  static Future<bool> verify({
    required Map<String, Object?> manifest,
    required String signature,
    required String publicKey,
  }) async {
    try {
      return await SnsShareCrypto.verify(
        publicKey: base64.decode(publicKey),
        message: signingInput(manifestDigest(manifest)),
        signature: base64.decode(signature),
      );
    } catch (_) {
      return false;
    }
  }
}
