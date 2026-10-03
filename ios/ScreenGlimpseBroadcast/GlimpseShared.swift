import Foundation
import Security

/// 画面の読み取り (D-417) で、拡張機能 `ScreenGlimpseBroadcast` と RASQ 本体が共有するもの。両方のターゲットに入っている。
///
/// 無料の Apple ID(Personal Team)では App Groups が使えないので、コマは**共有のキーチェーン**で渡す
/// (`keychain-access-groups` の `<チーム>.com.example.rasqClient.shared`)。4 コマで 1 MB ほど。有料の登録にしたら
/// App Groups の共有フォルダに置き換える(このファイルの `GlimpseStore` だけを差し替えればよい)。
/// 知らせは Darwin 通知(プロセスをまたぐ、中身は持てない)。中身はキーチェーンの `result` に書く。
enum GlimpseShared {
  static let started = "com.example.rasqClient.glimpse.started" as CFString
  static let finished = "com.example.rasqClient.glimpse.finished" as CFString
  static let cancel = "com.example.rasqClient.glimpse.cancel" as CFString
  static let doneNotificationId = "rasq.glimpse.done"

  static func post(_ name: CFString) {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName(name), nil, nil, true)
  }
}

/// 読み取りの結果。`outcome` は done / cancel / timeout / empty / short / error。
struct GlimpseResult: Codable {
  var id: String
  var capturedAtMillis: Int64
  var width: Int
  var height: Int
  var outcome: String
  var frameCount: Int
}

/// キーチェーンの置き場。結果は 1 件だけ(新しい配信で上書き)。
enum GlimpseStore {
  private static let service = "rasq.screen_glimpse"

  private static var accessGroup: String? {
    Bundle.main.object(forInfoDictionaryKey: "RASQKeychainGroup") as? String
  }

  private static func query(_ account: String? = nil) -> [String: Any] {
    var q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service]
    if let g = accessGroup { q[kSecAttrAccessGroup as String] = g }
    if let a = account { q[kSecAttrAccount as String] = a }
    return q
  }

  @discardableResult
  static func put(_ account: String, _ data: Data) -> Bool {
    SecItemDelete(query(account) as CFDictionary)
    var q = query(account)
    q[kSecValueData as String] = data
    q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    let status = SecItemAdd(q as CFDictionary, nil)
    if status != errSecSuccess { NSLog("ScreenGlimpse: keychain put %@ failed %d", account, status) }
    return status == errSecSuccess
  }

  static func get(_ account: String) -> Data? {
    var q = query(account)
    q[kSecReturnData as String] = true
    q[kSecMatchLimit as String] = kSecMatchLimitOne
    var out: CFTypeRef?
    return SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess ? out as? Data : nil
  }

  static func clear() {
    SecItemDelete(query() as CFDictionary)
  }

  /// コマを先に、`result` を最後に書く(本体は `result` があれば読みに行く)。
  static func save(_ result: GlimpseResult, frames: [Data]) {
    clear()
    for (i, f) in frames.enumerated() { put("frame_\(i)", f) }
    if let d = try? JSONEncoder().encode(result) { put("result", d) }
  }

  /// 結果とコマを取り出して消す。無ければ nil。
  static func take() -> (GlimpseResult, [Data])? {
    guard let d = get("result"), let r = try? JSONDecoder().decode(GlimpseResult.self, from: d) else { return nil }
    let frames = (0..<r.frameCount).compactMap { get("frame_\($0)") }
    clear()
    return (r, frames)
  }
}
