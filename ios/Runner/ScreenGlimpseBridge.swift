import Flutter
import ReplayKit
import UIKit
import UserNotifications

/// 画面の読み取り (D-417) の iOS 側の口(`rasq/screen_glimpse`、Android の `ScreenGlimpseBridge` と同じ形)。
///
/// - `start`: 通知の許可をたずねて(断られても続ける。RASQ に戻れば結果は出る)、端末の「画面の配信」のシートを出す。
///   拡張機能が始まったら `started`、シートを閉じたら / 2 分たっても始まらなければ `denied`。ブラウザは Dart が開く。
/// - 配信を止めると拡張機能が結果をキーチェーンに残す(`GlimpseStore`)。RASQ が前に来たとき / Darwin 通知で取り出して
///   `dir/<id>/frame_n.jpg` + `meta.json`(Android と同じ形)に書き、`done` → `open` を送る。
/// - Dart がまだ聞いていない(起動したばかり)ときは、`takeLaunchOpen` で渡す。
final class ScreenGlimpseBridge: NSObject {
  private let channel: FlutterMethodChannel
  private var running = false
  private var pendingStart: FlutterResult?
  private var startWatch: Timer?
  private var dartReady = false
  private var launchOpen: String?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "rasq/screen_glimpse", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in self?.handle(call, result) }
    let center = CFNotificationCenterGetDarwinNotifyCenter()
    let me = Unmanaged.passUnretained(self).toOpaque()
    CFNotificationCenterAddObserver(center, me, { _, observer, name, _, _ in
      guard let observer, let name else { return }
      let bridge = Unmanaged<ScreenGlimpseBridge>.fromOpaque(observer).takeUnretainedValue()
      let n = name.rawValue as String
      DispatchQueue.main.async { n == GlimpseShared.started as String ? bridge.onStarted() : bridge.collect() }
    }, GlimpseShared.started, nil, .deliverImmediately)
    CFNotificationCenterAddObserver(center, me, { _, observer, _, _, _ in
      guard let observer else { return }
      let bridge = Unmanaged<ScreenGlimpseBridge>.fromOpaque(observer).takeUnretainedValue()
      DispatchQueue.main.async { bridge.collect() }
    }, GlimpseShared.finished, nil, .deliverImmediately)
    // 後ろにいるあいだの Darwin 通知は届かないことがあるので、前に来たときにも見る。
    NotificationCenter.default.addObserver(self, selector: #selector(collect), name: UIApplication.didBecomeActiveNotification, object: nil)
  }

  private static var dir: URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("screen_glimpse", isDirectory: true)
  }

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    switch call.method {
    case "start": start(result)
    case "cancel":
      if running { GlimpseShared.post(GlimpseShared.cancel) }
      running = false
      finishStart("denied")
      result(nil)
    case "state": result(running ? "running" : "idle")
    case "dir": result(Self.dir.path)
    case "takeLaunchOpen":
      collect()
      dartReady = true
      let id = launchOpen
      launchOpen = nil
      result(id)
    case "dismissDone":
      UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [GlimpseShared.doneNotificationId])
      result(nil)
    default: result(FlutterMethodNotImplemented)
    }
  }

  private func start(_ result: @escaping FlutterResult) {
    if running || pendingStart != nil {
      result(["status": "busy"])
      return
    }
    guard #available(iOS 12.0, *), let root = Self.rootViewController() else {
      result(["status": "unavailable"])
      return
    }
    pendingStart = result
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in
      DispatchQueue.main.async { self.presentPicker(on: root) }
    }
  }

  /// 「画面の配信」のシート。RPSystemBroadcastPickerView のボタンを代わりに押す(見えないところに置く)。
  @available(iOS 12.0, *)
  private func presentPicker(on root: UIViewController) {
    let picker = RPSystemBroadcastPickerView(frame: CGRect(x: -100, y: -100, width: 44, height: 44))
    picker.preferredExtension = (Bundle.main.bundleIdentifier ?? "com.example.rasqClient") + ".ScreenGlimpseBroadcast"
    picker.showsMicrophoneButton = false
    root.view.addSubview(picker)
    guard let button = picker.subviews.compactMap({ $0 as? UIButton }).first else {
      picker.removeFromSuperview()
      finishStart("unavailable")
      return
    }
    button.sendActions(for: .touchUpInside)
    var seen = false
    var closedAt: Date?
    let began = Date()
    startWatch = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
      guard let self else { return }
      let showing = root.presentedViewController != nil
      if showing { seen = true; closedAt = nil }
      if seen, !showing, closedAt == nil { closedAt = Date() }
      // シートを閉じてから少し待つ(始まった知らせが遅れて届くことがある)。
      if let c = closedAt, Date().timeIntervalSince(c) > 2 { self.finishStart("denied") }
      if Date().timeIntervalSince(began) > 120 { self.finishStart("denied") }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { picker.removeFromSuperview() }
  }

  private func onStarted() {
    running = true
    finishStart("started")
    channel.invokeMethod("event", arguments: ["type": "armed"])
  }

  private func finishStart(_ status: String) {
    startWatch?.invalidate()
    startWatch = nil
    guard let r = pendingStart else { return }
    pendingStart = nil
    r(["status": status])
  }

  /// 拡張機能が残した結果を取り出す。
  @objc private func collect() {
    guard let (r, frames) = GlimpseStore.take() else { return }
    running = false
    guard r.outcome == "done", !frames.isEmpty, Self.isValidId(r.id) else {
      emit(["type": "stopped", "reason": r.outcome])
      return
    }
    let dir = Self.dir.appendingPathComponent(r.id, isDirectory: true)
    do {
      try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
      var names: [String] = []
      for (i, f) in frames.enumerated() {
        let name = "frame_\(i).jpg"
        try f.write(to: dir.appendingPathComponent(name))
        names.append(name)
      }
      let meta: [String: Any] = ["id": r.id, "capturedAt": Self.iso(r.capturedAtMillis), "width": r.width, "height": r.height, "frames": names]
      try JSONSerialization.data(withJSONObject: meta).write(to: dir.appendingPathComponent("meta.json"))
    } catch {
      NSLog("ScreenGlimpse: write %@", error.localizedDescription)
      try? FileManager.default.removeItem(at: dir)
      emit(["type": "stopped", "reason": "error"])
      return
    }
    if dartReady {
      emit(["type": "done", "id": r.id])
      emit(["type": "open", "id": r.id])
    } else {
      launchOpen = r.id
    }
  }

  private func emit(_ e: [String: Any]) {
    guard dartReady else { return }
    channel.invokeMethod("event", arguments: e)
  }

  private static func isValidId(_ id: String) -> Bool {
    id.range(of: "^[a-z0-9-]{8,64}$", options: .regularExpression) != nil
  }

  private static func iso(_ millis: Int64) -> String {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f.string(from: Date(timeIntervalSince1970: Double(millis) / 1000))
  }

  private static func rootViewController() -> UIViewController? {
    let window = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first { $0.isKeyWindow }
    var vc = window?.rootViewController
    while let p = vc?.presentedViewController { vc = p }
    return vc
  }
}
