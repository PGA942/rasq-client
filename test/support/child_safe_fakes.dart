import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:rasq_client/features/child_safe/child_safe_policy.dart';

/// チャイルドセーフ v2 (D-307) の試験の共通: 契約の例の制限と、テスト用のストアの鍵。

/// 契約 (API.md) の例の制限。
const v2Json = '''
{"schema":"rasq.child-safe/2","preset":"strict","timeline":{"enabled":true,"level":"strict","blockedTopics":["ホラー"]},"composer":{"enabled":true,"level":"strict"},"time":{"enabled":true,"start":"21:00","end":"06:00","allowedTopics":["宿題"],"hideNotifications":true,"hidePostDetail":false,"hideDirectMessages":true},"postsPerDay":10,"allow":{"sns":{"kinds":["misskey"],"instances":["misskey.io"],"addAccounts":false},"plugins":{"ids":["jp.rasq.sample"],"slots":{"post.action":false},"install":"none"},"features":{"dm":false,"astell.join":false},"search":{"posts":true,"users":false,"trend":true,"store":false,"web":false},"rai":{"enabled":true,"groups":["rai.guide","rai.read","rai.compose"],"deny":[],"automation":false}},"source":{"catalogVersion":1}}
''';

Map<String, Object?> v2() => (jsonDecode(v2Json) as Map).cast<String, Object?>();

/// Central `docs/API.md`「署名」の参照のベクトル(入力の settings。JSON のエスケープで書いてある)。
const referenceSettingsJson = r'''
{"schema":"rasq.child-safe/2","preset":"custom","timeline":{"enabled":true,"level":"strict","blockedTopics":["賭けごと","a/b"]},"postsPerDay":10,"numbers":[0,-1,1000,9007199254740991],"text":"引用\"と\\と改行\nとタブ\tと\u001fと/と\u007fと\u2028","controls":"\u0000\b\f\r\u000b","nested":{"z":{"y":[{"b":null,"a":false}]},"A":[]},"日本語キー":"値","ｚ":"全角","😀":"絵文字","é":1}
''';

/// 決まった形(U+007F と U+2028 は生のまま)。
const referenceCanonical =
    '{"childAccountId":"00000000-0000-4000-8000-000000000001","issuedAt":"2026-09-24T12:34:56Z","revision":7,"settings":{"controls":"\\u0000\\b\\f\\r\\u000b","nested":{"A":[],"z":{"y":[{"a":false,"b":null}]}},"numbers":[0,-1,1000,9007199254740991],"postsPerDay":10,"preset":"custom","schema":"rasq.child-safe/2","text":"引用\\"と\\\\と改行\\nとタブ\\tと\\u001fと/と\u007fと\u2028","timeline":{"blockedTopics":["賭けごと","a/b"],"enabled":true,"level":"strict"},"é":1,"日本語キー":"値","ｚ":"全角","😀":"絵文字"}}';
const referenceSha512 = '224c6679a21b9c78981386b0bfed4507ae3015e32a61db39b4aa7773ecbe65763cde7f45100a7a542d36e648f1da630c002f594bb1a75d9f707c1483862cd9fb';
const referencePublicKey = '6kpsY+KcUgq+9VB7Ey7F+ZVHdq6+vnuSQh7qaRRG0iw=';
const referenceSignature = 'QyCmhxJ1dsLRvCE/c2reIHMyaCPJoxgm5pYGhahymAgWbyiHGN84eOghA1qu6EdSjtUQteL+v2e+vVKLvjG1BQ==';

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

