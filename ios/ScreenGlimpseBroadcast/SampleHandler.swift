import CoreImage
import ReplayKit
import UserNotifications

/// 画面の配信の拡張機能 (D-417)。配信のあいだ 1 秒に 1 コマだけ小さな JPEG にしてメモリに持ち(拡張機能のメモリは 50 MB まで)、
/// **配信を止めたとき**、止める直前の約 3 秒(最大 4 コマ)をキーチェーンに残して本体に知らせる。ファイルには書かない。
///
/// 止める操作(赤い表示の「停止」の確認 / コントロールセンター)そのものが写らないよう、止める直前の [tailSkip] は使わない。
class SampleHandler: RPBroadcastSampleHandler {
  /// コマの間隔。
  private let interval: TimeInterval = 1.0
  /// 読み取る長さ。
  private let window: TimeInterval = 3.0
  /// 止める直前の、使わない長さ(止める操作が写っている)。実機で調整する。
  private let tailSkip: TimeInterval = 1.5
  /// 最大のコマ数(Android と同じ)。
  private let maxFrames = 4
  /// 何もしないまま待つ上限。
  private let idleLimit: TimeInterval = 10 * 60
  /// 長辺(Android と同じ)。
  private let longEdge: CGFloat = 1080

  private struct Frame {
    let at: Date
    let jpeg: Data
    let width: Int
    let height: Int
  }

  private let queue = DispatchQueue(label: "rasq.glimpse.frames")
  private let context = CIContext(options: [.cacheIntermediates: false])
  private var frames: [Frame] = []
  private var lastKept = Date.distantPast
  private var id = UUID().uuidString.lowercased()
  private var startedAt = Date()
  private var cancelled = false
  private var finishedOutcome: String?
  private var idleTimer: DispatchSourceTimer?

  override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
    id = UUID().uuidString.lowercased()
    startedAt = Date()
    GlimpseStore.clear()
    let center = CFNotificationCenterGetDarwinNotifyCenter()
    CFNotificationCenterAddObserver(center, Unmanaged.passUnretained(self).toOpaque(), { _, observer, _, _, _ in
      guard let observer else { return }
      Unmanaged<SampleHandler>.fromOpaque(observer).takeUnretainedValue().stop(outcome: "cancel", message: "RASQ で画面の読み取りをやめました")
    }, GlimpseShared.cancel, nil, .deliverImmediately)
    let t = DispatchSource.makeTimerSource(queue: .global())
    t.schedule(deadline: .now() + idleLimit)
    t.setEventHandler { [weak self] in self?.stop(outcome: "timeout", message: "10 分たったので、画面の読み取りを止めました") }
    t.resume()
    idleTimer = t
    GlimpseShared.post(GlimpseShared.started)
    NSLog("ScreenGlimpse: started %@", id)
  }

  /// 拡張機能のほうから止める(やめる / 待ちすぎ)。コマは残さず、わけだけ本体に知らせる。
  private func stop(outcome: String, message: String) {
    let first: Bool = queue.sync {
      guard finishedOutcome == nil else { return false }
      cancelled = true
      finishedOutcome = outcome
      frames.removeAll()
      idleTimer?.cancel()
      GlimpseStore.save(GlimpseResult(id: id, capturedAtMillis: millis(startedAt), width: 0, height: 0, outcome: outcome, frameCount: 0), frames: [])
      return true
    }
    guard first else { return }
    GlimpseShared.post(GlimpseShared.finished)
    // broadcastFinished が呼ばれても、結果はもう書いてある(finishedOutcome)。
    finishBroadcastWithError(NSError(domain: "rasq.glimpse", code: 1, userInfo: [NSLocalizedDescriptionKey: message]))
  }

  override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
    guard sampleBufferType == .video else { return }
    let now = Date()
    // 画面が変わらないと ReplayKit はコマを送ってこない(最後のコマが、そのまま「いまの画面」)。
    guard now.timeIntervalSince(lastKept) >= interval, let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    lastKept = now
    var image = CIImage(cvPixelBuffer: pixels)
    if let raw = CMGetAttachment(sampleBuffer, key: RPVideoSampleOrientationKey as CFString, attachmentModeOut: nil) as? NSNumber,
       let o = CGImagePropertyOrientation(rawValue: raw.uint32Value) {
      image = image.oriented(o)
    }
    let extent = image.extent
    let scale = min(1, longEdge / max(extent.width, extent.height))
    if scale < 1 { image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale)) }
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let opts = [CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String): 0.8]
    guard let jpeg = context.jpegRepresentation(of: image, colorSpace: space, options: opts) else { return }
    let frame = Frame(at: now, jpeg: jpeg, width: Int(image.extent.width.rounded()), height: Int(image.extent.height.rounded()))
    queue.async {
      guard !self.cancelled else { return }
      self.frames.append(frame)
      // 窓 + 使わない長さ + 余裕のぶんだけ持つ。
      let keepFrom = now.addingTimeInterval(-(self.window + self.tailSkip + 3))
      while self.frames.count > 2, let first = self.frames.first, first.at < keepFrom { self.frames.removeFirst() }
    }
  }

  override func broadcastFinished() {
    let stoppedAt = Date()
    CFNotificationCenterRemoveEveryObserver(CFNotificationCenterGetDarwinNotifyCenter(), Unmanaged.passUnretained(self).toOpaque())
    let saved: Bool = queue.sync {
      idleTimer?.cancel()
      if finishedOutcome != nil { return false }
      finishedOutcome = "finished"
      do {
        let picked = pick(stoppedAt: stoppedAt)
        let outcome = picked.isEmpty ? (frames.isEmpty ? "empty" : "short") : "done"
        let first = picked.first
        GlimpseStore.save(
          GlimpseResult(id: id, capturedAtMillis: millis(first?.at ?? startedAt), width: first?.width ?? 0, height: first?.height ?? 0, outcome: outcome, frameCount: picked.count),
          frames: picked.map(\.jpeg))
        if outcome == "done" { notifyDone() }
        NSLog("ScreenGlimpse: finished %@ %@ (%d frames of %d)", id, outcome, picked.count, frames.count)
      }
      frames.removeAll()
      return true
    }
    if saved { GlimpseShared.post(GlimpseShared.finished) }
  }

  /// 止める [tailSkip] 前までの [window] のコマ(最大 [maxFrames])。窓に 1 つも無ければ、その前の最後のコマ(画面が止まっていた)。
  private func pick(stoppedAt: Date) -> [Frame] {
    let end = stoppedAt.addingTimeInterval(-tailSkip)
    let usable = frames.filter { $0.at <= end }
    let inWindow = usable.filter { $0.at >= end.addingTimeInterval(-window) }
    if !inWindow.isEmpty { return Array(inWindow.suffix(maxFrames)) }
    return usable.last.map { [$0] } ?? []
  }

  private func millis(_ d: Date) -> Int64 { Int64(d.timeIntervalSince1970 * 1000) }

  /// 「読み取りました」(タップで RASQ が開いて結果を出す)。通知を許可されていなければ出ない(RASQ に戻れば結果は出る)。
  private func notifyDone() {
    let content = UNMutableNotificationContent()
    content.title = "読み取りました"
    content.body = "タップで結果を見る"
    let request = UNNotificationRequest(identifier: GlimpseShared.doneNotificationId, content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request) { e in if let e { NSLog("ScreenGlimpse: notify %@", e.localizedDescription) } }
  }
}
