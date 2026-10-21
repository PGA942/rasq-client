import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/session/sns_share_crypto.dart';

/// D-547 (Codex Security #17 / ORGATE O-020): 端末の署名鍵で署名する文字列と署名の、ORGATE と揃えるテストベクタ。
/// 値は client が自分で計算したもの(OpenSSL 3.6 の Ed25519 / X25519 / SHA-256 でも同じ値になることを確かめた)。
/// ORGATE 側のテストにも同じ値を置き、突き合わせる(仕様は phase1-17-spec.md の「両方で揃えるテストベクタ」)。
void main() {
  String hex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  final signingSeed = List<int>.filled(32, 0x01);
  final x25519Seed = List<int>.filled(32, 0x02);
  const accountId = '00000000-0000-0000-0000-000000000001';
  const deviceId = 'dev-A';
  const challengeId = '00000000-0000-0000-0000-0000000000aa';
  final nonce = base64.encode(List<int>.filled(32, 0x03));
  const keyId = 'key-test-0001';
  final wrappedKey = List<int>.filled(92, 0x04);

  test('鍵: Ed25519 の署名鍵(種 = 0x01 × 32)と X25519 の公開鍵(種 = 0x02 × 32)', () async {
    expect(hex(await SnsShareCrypto.signingPublicKeyOf(signingSeed)), '8a88e3dd7409f195fd52db2d3cba5d72ca6709bf1d94121bf3748801b40f6f5c');
    expect(hex(await SnsShareCrypto.publicKeyOf(x25519Seed)), 'ce8d3ad1ccb633ec7b70c17814a5c76ecd029685050d344745ba05870e587d59');
  });

  test('ログインの所持の証明: rasq-device-proof/v1', () async {
    final message = SnsShareCrypto.deviceProofMessage(challengeId: challengeId, nonce: nonce, deviceId: deviceId);
    expect(utf8.decode(message), 'rasq-device-proof/v1\n$challengeId\nAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwM=\ndev-A');
    expect(
      hex(message),
      '726173712d6465766963652d70726f6f662f76310a30303030303030302d303030302d303030302d303030302d3030303030303030303061610a'
      '41774d4441774d4441774d4441774d4441774d4441774d4441774d4441774d4441774d4441774d4441774d3d0a6465762d41',
    );
    final signature = await SnsShareCrypto.sign(signingSeed, message);
    expect(hex(signature), '26146ecfd19917cd48a8373ba85e7f8d4a90448f3404eb902010535ecd19bda41571ada768e13703d618047eede8b534df89350826633d032e7936af0c55fd0e');
    final pub = await SnsShareCrypto.signingPublicKeyOf(signingSeed);
    expect(await SnsShareCrypto.verify(publicKey: pub, message: message, signature: signature), isTrue);
    expect(await SnsShareCrypto.verify(publicKey: pub, message: SnsShareCrypto.deviceProofMessage(challengeId: challengeId, nonce: nonce, deviceId: 'dev-B'), signature: signature), isFalse);
  });

  test('K の包みの署名: rasq-sns-share-wrap/v1(宛先 = dev-A、X25519 の公開鍵は種 0x02 のもの)', () async {
    final message = SnsShareCrypto.wrapMessage(accountId: accountId, deviceId: deviceId, recipientPublicKey: await SnsShareCrypto.publicKeyOf(x25519Seed), keyId: keyId, wrappedKey: wrappedKey);
    expect(utf8.decode(message), 'rasq-sns-share-wrap/v1\n$accountId\ndev-A\nzo060cy2M+x7cMF4FKXHbs0CloUFDTRHRboFhw5YfVk=\nkey-test-0001\n+WOIzvp50QoegtCTy8yVodmoIIdeBmWH6kOwtdDDcrE=');
    expect(
      hex(message),
      '726173712d736e732d73686172652d777261702f76310a30303030303030302d303030302d303030302d303030302d3030303030303030303030310a'
      '6465762d410a7a6f3036306379324d2b7837634d4634464b5848627330436c6f55464454524852626f466877355966566b3d0a'
      '6b65792d746573742d303030310a2b574f497a76703530516f6567744354793879566f646d6f49496465426d5748366b4f77746444446372453d',
    );
    final signature = await SnsShareCrypto.sign(signingSeed, message);
    expect(hex(signature), '042e3d10eac831ee4dbc45f07fa6e312ae3f2a96148b97bdab9bae3e755488447c8caa02b35e76c99b634f6b21c7cc5d5587e3922d5cd6ec595425e792746806');
    expect(await SnsShareCrypto.verify(publicKey: await SnsShareCrypto.signingPublicKeyOf(signingSeed), message: message, signature: signature), isTrue);
  });

  test('K の指紋 = SHA-256(K) の base64。形の違う署名鍵・署名は false', () async {
    expect(SnsShareCrypto.keyFingerprint(List<int>.filled(92, 0x04)), '+WOIzvp50QoegtCTy8yVodmoIIdeBmWH6kOwtdDDcrE=');
    expect(await SnsShareCrypto.verify(publicKey: List<int>.filled(31, 0), message: const [1], signature: List<int>.filled(64, 0)), isFalse);
    expect(await SnsShareCrypto.verify(publicKey: await SnsShareCrypto.signingPublicKeyOf(signingSeed), message: const [1], signature: List<int>.filled(63, 0)), isFalse);
  });
}
