import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:rasq_client/features/child_safe/child_safe_policy.dart';

/// チャイルドセーフ v2 (D-307) の試験の共通: 契約の例の制限と、テスト用のストアの鍵。

/// 契約 (API.md) の例の制限。
const v2Json = '''
{"schema":"rasq.child-safe/2","preset":"strict","timeline":{"enabled":true,"level":"strict","blockedTopics":["ホラー"]},"composer":{"enabled":true,"level":"strict"},"time":{"enabled":true,"start":"21:00","end":"06:00","allowedTopics":["宿題"],"hideNotifications":true,"hidePostDetail":false,"hideDirectMessages":true},"postsPerDay":10,"allow":{"sns":{"kinds":["misskey"],"instances":["misskey.io"],"addAccounts":false},"plugins":{"ids":["jp.rasq.sample"],"slots":{"post.action":false},"install":"none"},"features":{"dm":false,"astell.join":false},"search":{"posts":true,"users":false,"trend":true,"store":false,"web":false},"rai":{"enabled":true,"groups":["rai.guide","rai.read","rai.compose"],"deny":[],"automation":false}},"source":{"catalogVersion":1}}
''';

Map<String, Object?> v2() => (jsonDecode(v2Json) as Map).cast<String, Object?>();

/// テスト用のストアの鍵(本物の鍵ではない)。
class TestSigner {
  TestSigner._(this._kp, this.publicKey);
  final SimpleKeyPair _kp;
  final String publicKey;
  static Future<TestSigner> create([int seed = 7]) async {
    final kp = await Ed25519().newKeyPairFromSeed(List<int>.filled(32, seed));
    return TestSigner._(kp, base64Encode((await kp.extractPublicKey()).bytes));
  }

  Future<String> sign(String accountId, int revision, Object? settings, String issuedAt) async =>
      base64Encode((await Ed25519().sign(childSafeSigningDigest(childAccountId: accountId, revision: revision, settings: settings, issuedAt: issuedAt), keyPair: _kp)).bytes);
}

