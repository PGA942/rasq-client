import 'dart:convert';

/// `storage.set` の上限 (D-546、セキュリティ確認 2026-10-21 の #2、csf_2e9abe156286029a2ec69d3b)。
///
/// `storage.*` の値はゲストの線形メモリの外(ホストの Dart / Worker の JS のマップ)に残り、さらに `storage.set` のたびに
/// 写し (D-422 の `onStorageWrite` / `storageWrites`) がアプリへ渡る。前は名前空間の権限しか見なかったので、制限モード
/// (`storage.safe` だけ)のプラグインでも、小さなバッファを使い回して別のキーへ書き続ければ、線形メモリの上限
/// (256 MiB)と関係なくアプリのメモリを増やせた。そこで**インスタンスごと**に(`safe` / `unsafe` を合わせて)次を数え、
/// 超える書き込みは**保存も写しも出す前に** `E02`(予算切れ)で断る。断った書き込みは何も変えない(前の値はそのまま)。
///
/// - キーの数: [maxKeys](1,024)。上書きは数を増やさない。
/// - キーの長さ: [maxKeyBytes](ゲストが渡す `key` の UTF-8 で 512 バイト)。
/// - 値 1 つの大きさ: [maxValueBytes](JSON にして 1 MiB)。
/// - 合計: [maxTotalBytes](全キーの「`ns:key` の UTF-8 + 値の JSON」の合計で 4 MiB)。上書きは差分、削除は丸ごと返す。
///
/// いまのプラグインが持つのは設定・カウンタ・セッションのトークン(数 KiB)くらいなので、十分に余裕がある。
/// ホストが最初に渡す値 (`seedStorage`) も数に入れるが、それ自体は断らない(上限を超えていれば、減らす書き込みだけが通る)。
/// Web 版の Worker の JS (`wasm_plugin_worker_web.dart`) も同じ規則・同じ答えで数える(値はここから渡す)。片方を変えたらもう片方も。
class PluginStorageQuota {
  PluginStorageQuota({this.maxKeys = defaultMaxKeys, this.maxKeyBytes = defaultMaxKeyBytes, this.maxValueBytes = defaultMaxValueBytes, this.maxTotalBytes = defaultMaxTotalBytes});

  static const defaultMaxKeys = 1024;
  static const defaultMaxKeyBytes = 512;
  static const defaultMaxValueBytes = 1024 * 1024;
  static const defaultMaxTotalBytes = 4 * 1024 * 1024;

  final int maxKeys;
  final int maxKeyBytes;
  final int maxValueBytes;
  final int maxTotalBytes;

  final Map<String, int> _bytes = {};
  int _total = 0;

  /// いま数えているキーの数。
  int get keyCount => _bytes.length;

  /// いま数えている合計のバイト数。
  int get totalBytes => _total;

  /// ホストが最初に渡す値を数える(断らない)。
  void seed(Map<String, Object?> storage) {
    for (final e in storage.entries) {
      final bytes = entryBytes(e.key, e.value);
      _total += bytes - (_bytes[e.key] ?? 0);
      _bytes[e.key] = bytes;
    }
  }

  /// `storage.set` を確かめ、通るなら数える。断るときは理由を返し、何も変えない(通れば null)。
  /// [fullKey] はホストのマップのキー(`ns:key`)、[guestKey] はゲストが渡した `key`。
  String? trySet(String fullKey, String guestKey, Object? value) {
    if (utf8.encode(guestKey).length > maxKeyBytes) return 'storage key exceeds $maxKeyBytes bytes';
    final valueBytes = utf8.encode(jsonEncode(value)).length;
    if (valueBytes > maxValueBytes) return 'storage value exceeds $maxValueBytes bytes';
    final old = _bytes[fullKey];
    if (old == null && _bytes.length >= maxKeys) return 'storage key count exceeds $maxKeys';
    final next = utf8.encode(fullKey).length + valueBytes;
    final total = _total - (old ?? 0) + next;
    // 減らす上書きは、合計が(最初に渡された値で)上限を超えていても通す。
    if (total > maxTotalBytes && total > _total) return 'storage exceeds $maxTotalBytes bytes in total';
    _bytes[fullKey] = next;
    _total = total;
    return null;
  }

  /// `storage.delete`: そのキーのぶんを返す。
  void remove(String fullKey) {
    _total -= _bytes.remove(fullKey) ?? 0;
  }

  /// 1 つのキーのぶん: `ns:key` の UTF-8 + 値の JSON の UTF-8。
  static int entryBytes(String fullKey, Object? value) => utf8.encode(fullKey).length + utf8.encode(jsonEncode(value)).length;
}
