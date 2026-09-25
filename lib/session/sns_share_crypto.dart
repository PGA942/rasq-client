import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// SNS のアクセストークンの端末間共有 (D-319) の暗号。**Central は K も平文も見ない**。
///
/// - 端末の鍵: X25519 の鍵ペア(Central のアカウントごと)。秘密鍵は 32 バイトの種として端末の安全な保存先に置く。
/// - 共有鍵 K: ランダム 32 バイト。世代 [SnsShareCrypto.newKeyId] と組で使う。
/// - K を包む: 一時鍵の X25519 → HKDF-SHA256(salt = 一時公開鍵 ‖ 受け手の公開鍵)→ AES-256-GCM。
///   形は `一時公開鍵 (32) ‖ nonce (12) ‖ 暗号文 (32) ‖ タグ (16)` = 92 バイト。AAD にアカウント / 端末 / 世代を入れる
///   (別の端末あて・別のアカウントあての包みを差し替えても開かない)。
/// - 本体: K で AES-256-GCM。`{"v":1,"keyId","nonce","ct"}`(ct = 暗号文 ‖ タグ、base64)の JSON。AAD はアカウントと世代。
class SnsShareCrypto {
  static final _x25519 = X25519();
  static final _aes = AesGcm.with256bits();
  static final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  static const _wrapInfo = 'rasq sns-share v1 wrap';

  static Uint8List _random(int n) {
    final r = Random.secure();
    return Uint8List.fromList(List<int>.generate(n, (_) => r.nextInt(256)));
  }

  /// 新しい端末の鍵(種)。
  static Uint8List newDeviceSeed() => _random(32);

  /// 種から公開鍵。
  static Future<Uint8List> publicKeyOf(List<int> seed) async {
    final kp = await _x25519.newKeyPairFromSeed(seed);
    return Uint8List.fromList((await kp.extractPublicKey()).bytes);
  }

  /// 新しい共有鍵 K。
  static Uint8List newShareKey() => _random(32);

  /// K の世代(Central に置く。K そのものとは無関係な乱数)。
  static String newKeyId() => base64Url.encode(_random(16)).replaceAll('=', '');

  static List<int> _wrapAad(String accountId, String deviceId, String keyId) => utf8.encode('rasq.sns-share.v1:wrap:$accountId:$deviceId:$keyId');
  static List<int> _bodyAad(String accountId, String keyId) => utf8.encode('rasq.sns-share.v1:body:$accountId:$keyId');

  static Future<SecretKey> _wrapKey(SecretKey shared, List<int> ephemeralPublic, List<int> recipientPublic) =>
      _hkdf.deriveKey(secretKey: shared, nonce: [...ephemeralPublic, ...recipientPublic], info: utf8.encode(_wrapInfo));

  /// K を、受け手の公開鍵 [recipientPublicKey] で包む。
  static Future<Uint8List> wrap({
    required List<int> shareKey,
    required List<int> recipientPublicKey,
    required String accountId,
    required String deviceId,
    required String keyId,
  }) async {
    final eph = await _x25519.newKeyPair();
    final ephPub = (await eph.extractPublicKey()).bytes;
    final shared = await _x25519.sharedSecretKey(keyPair: eph, remotePublicKey: SimplePublicKey(recipientPublicKey, type: KeyPairType.x25519));
    final key = await _wrapKey(shared, ephPub, recipientPublicKey);
    final box = await _aes.encrypt(shareKey, secretKey: key, nonce: _aes.newNonce(), aad: _wrapAad(accountId, deviceId, keyId));
    return Uint8List.fromList([...ephPub, ...box.nonce, ...box.cipherText, ...box.mac.bytes]);
  }

  /// 自分あての包み [wrapped] を、端末の種 [seed] で開く。開けなければ null(別の端末あて / 別の世代 / 壊れている)。
  static Future<Uint8List?> unwrap({
    required List<int> wrapped,
    required List<int> seed,
    required String accountId,
    required String deviceId,
    required String keyId,
  }) async {
    if (wrapped.length != 32 + 12 + 32 + 16) return null;
    try {
      final me = await _x25519.newKeyPairFromSeed(seed);
      final myPub = (await me.extractPublicKey()).bytes;
      final ephPub = wrapped.sublist(0, 32);
      final shared = await _x25519.sharedSecretKey(keyPair: me, remotePublicKey: SimplePublicKey(ephPub, type: KeyPairType.x25519));
      final key = await _wrapKey(shared, ephPub, myPub);
      final box = SecretBox(wrapped.sublist(44, 76), nonce: wrapped.sublist(32, 44), mac: Mac(wrapped.sublist(76)));
      return Uint8List.fromList(await _aes.decrypt(box, secretKey: key, aad: _wrapAad(accountId, deviceId, keyId)));
    } catch (_) {
      // タグが合わない(別の端末あて / 別の世代 / 壊れている)・形が違う。
      return null;
    }
  }

  /// 本体を K で閉じる。
  static Future<Uint8List> seal({required List<int> shareKey, required String keyId, required String accountId, required String plaintext}) async {
    final box = await _aes.encrypt(utf8.encode(plaintext), secretKey: SecretKey(shareKey), nonce: _aes.newNonce(), aad: _bodyAad(accountId, keyId));
    return Uint8List.fromList(utf8.encode(jsonEncode({'v': 1, 'keyId': keyId, 'nonce': base64.encode(box.nonce), 'ct': base64.encode([...box.cipherText, ...box.mac.bytes])})));
  }

  /// 本体の世代(開かずに読める)。形が違えば null。
  static String? keyIdOf(List<int> body) {
    try {
      final j = jsonDecode(utf8.decode(body));
      return j is Map && j['v'] == 1 ? j['keyId'] as String? : null;
    } catch (_) {
      return null;
    }
  }

  /// 本体を K で開く。世代が違う / 開けなければ null。
  static Future<String?> open({required List<int> shareKey, required String keyId, required String accountId, required List<int> body}) async {
    try {
      final j = (jsonDecode(utf8.decode(body)) as Map).cast<String, Object?>();
      if (j['v'] != 1 || j['keyId'] != keyId) return null;
      final nonce = base64.decode(j['nonce'] as String);
      final ct = base64.decode(j['ct'] as String);
      if (ct.length < 16) return null;
      final box = SecretBox(ct.sublist(0, ct.length - 16), nonce: nonce, mac: Mac(ct.sublist(ct.length - 16)));
      return utf8.decode(await _aes.decrypt(box, secretKey: SecretKey(shareKey), aad: _bodyAad(accountId, keyId)));
    } catch (_) {
      // タグが合わない / JSON の形が違う。
      return null;
    }
  }
}
