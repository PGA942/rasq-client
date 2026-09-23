import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../store/rasqpkg.dart';

/// サイドロードの信頼の段 (D-306、ユーザー決定 2026-09-24):
/// サイドロードは**自分の署名がある場合だけフル機能**、それ以外は**制限モード**で動かす。
///
/// - [full]: `.rasqpkg` に開発者鍵の署名(`rasq build` が隣に出す `<pkg>.sig.json`)があり、それが配布物と合い、
///   しかも鍵の指紋が**このアカウントが登録した開発者鍵**([ownDevKeyFingerprintsProvider])のどれかと同じ。
/// - [restricted]: それ以外のサイドロード全部 — 署名なし / 署名が合わない / 他人の鍵 / 素の `.wasm`(入れ物も署名も無い)/
///   同梱アセット(`asset:`、隣に同じ形の `.sig.json` があって自分の鍵なら full)。
///
/// 制限モードで閉じるもの(判定はどれも [SideloadTrust] の 1 か所から引く):
/// - `gpu.compute` (D-081) — `slotGpuComputeAllowed`。
/// - TODO(制限モード): 残りの制限(`network` の接続先、`storage.unsafe`、fuel の予算、FOW の種類など)は今後決める。
///   足すときは [SideloadTrust.isFull] を見る関数をここに並べ、呼び出し側は変えない。
///
/// ストア (`store:`) の登録は審査で決まるので、この段は使わない(`isReviewedSlotSource`)。
enum SideloadTrust {
  full,
  restricted;

  bool get isFull => this == SideloadTrust.full;
}

/// このアカウントが Central に登録した開発者の署名鍵の指紋(失効していないもの。SHA-512 の先頭 8 バイトの hex、
/// `rasq key show` / Central `developer_keys.fingerprint` と同じ形)。
///
/// TODO(制限モード): **今のクライアントはこれを知る口が無い**ので空 = 全てのサイドロードが制限モード。
/// Central は鍵を `GET / POST /console/keys`(Web コンソールの HTML ページ、Cookie のセッション)でしか扱わず、
/// `GET /me` にも鍵は載らない。アプリのトークンで読める JSON の口(例: `GET /me` に `devKeyFingerprints`、
/// または `GET /api/v1/dev/keys`)が Central に入ったら、ここで `orgateAccountProvider` から引く。
/// テストは上書きして自分の鍵を与える。
final ownDevKeyFingerprintsProvider = Provider<Set<String>>((ref) => const {});

/// サイドロードの配布物の信頼の段を決める(判定の 1 か所)。
///
/// [packageBytes] = 読み込んだ**そのままの**バイト列(`.rasqpkg` なら展開前)。[signature] = 隣の `.sig.json` の中身
/// (無ければ null)。[ownFingerprints] = [ownDevKeyFingerprintsProvider]。署名の確かめは [verifyDevSignature]
/// (digest = 配布物の SHA-512、ed25519、指紋 = 公開鍵の SHA-512 の先頭 8 バイト)。
Future<SideloadTrust> sideloadTrustOf(Uint8List packageBytes, {required Map<String, Object?>? signature, required Set<String> ownFingerprints}) async {
  // 署名の対象は `rasq build` の `.rasqpkg` だけ。素の `.wasm` は入れ物が無い = 制限モード。
  if (signature == null || ownFingerprints.isEmpty || !isRasqPackage(packageBytes)) return SideloadTrust.restricted;
  try {
    final fingerprint = await verifyDevSignature(packageBytes, signature);
    return ownFingerprints.contains(fingerprint) ? SideloadTrust.full : SideloadTrust.restricted;
  } on RasqPackageException catch (e) {
    debugPrint('sideload signature: $e');
    return SideloadTrust.restricted;
  }
}

/// サイドロードの `container`(ファイルのパス / `asset:<name>`)の隣の `.sig.json` を読む。無い・読めなければ null。
Future<Map<String, Object?>?> readSideloadSignature(String container) async {
  try {
    final String text;
    if (container.startsWith('asset:')) {
      text = await rootBundle.loadString('${container.substring(6)}.sig.json');
    } else {
      final f = File('$container.sig.json');
      if (!f.existsSync()) return null;
      text = f.readAsStringSync();
    }
    final j = jsonDecode(text);
    return j is Map ? j.cast<String, Object?>() : null;
  } catch (_) {
    return null; // 無い(アセットに無いと例外)/ JSON でない = 署名なし
  }
}
