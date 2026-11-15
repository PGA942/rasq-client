import Flutter
import UIKit
import UniformTypeIdentifiers

/// 他のアプリから落としたメディアを受ける (D-555) の iPadOS 側。
///
/// Dart は desktop_drop(0.8)の `DropTarget` で受けるが、desktop_drop の iOS 版は 0.9 から(Flutter 3.47.7 以上が要る)なので、
/// それまではこのクラスが**同じ口**(チャンネル `desktop_drop`、`entered` / `updated` / `exited` / `performOperation`)で話す。
/// desktop_drop を 0.9 に上げたら、このファイルと AppDelegate の 1 行を消す(同じ名前のチャンネルを二重に持たない)。
///
/// - Flutter の画面(FlutterViewController の view)に `UIDropInteraction` を付ける。画像 / 動画 / 音声を持つドラッグだけ受ける。
/// - 位置は view の point(= Flutter の論理ピクセル、左上が原点)。どの部品の上かは Dart の `DropTarget` が決める。
/// - 離したら、項目ごとにファイルの形で受け取り、`tmp/media_drop/<uuid>/` に写して、そのパスを `performOperation` で渡す。
///   受け取りが終わるまで `exited` は送らない(先に送ると Dart の DropTarget が離したことを捨てる)。
final class MediaDropBridge: NSObject, UIDropInteractionDelegate {
  private let channel: FlutterMethodChannel
  private weak var attachedView: UIView?
  private var loading = false

  /// 受けるもの(画像 / 動画 / 音声)。同じ項目が複数の形を持つときは、前のものを選ぶ(JPEG / PNG / GIF を HEIC より先に)。
  private static let types: [UTType] = [.jpeg, .png, .gif, .image, .movie, .audio]

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "desktop_drop", binaryMessenger: messenger)
    super.init()
    // Dart が DesktopDrop.init で受け手を付ける。Dart から呼ばれるもの(macOS のブックマーク)は iOS では無いので、何もしない。
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "startAccessingSecurityScopedResource": result(false)
      case "stopAccessingSecurityScopedResource": result(true)
      default: result(FlutterMethodNotImplemented)
      }
    }
    // 窓(シーン)ができるのはエンジンより後なので、前に来るたびに付いているかを見る。
    NotificationCenter.default.addObserver(self, selector: #selector(attachIfNeeded), name: UIApplication.didBecomeActiveNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(attachIfNeeded), name: UIScene.didActivateNotification, object: nil)
    DispatchQueue.main.async { [weak self] in self?.attachIfNeeded() }
    // 前の起動で写したまま残ったもの(コンポーザーの外に落とした分)を消す。
    try? FileManager.default.removeItem(at: Self.dir)
  }

  private static var dir: URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("media_drop", isDirectory: true)
  }

  @objc private func attachIfNeeded() {
    for scene in UIApplication.shared.connectedScenes {
      guard let ws = scene as? UIWindowScene else { continue }
      for window in ws.windows {
        guard let vc = window.rootViewController as? FlutterViewController, let view = vc.view else { continue }
        if view === attachedView { return }
        view.addInteraction(UIDropInteraction(delegate: self))
        attachedView = view
        return
      }
    }
  }

  private func point(_ session: UIDropSession, _ interaction: UIDropInteraction) -> [Double] {
    let p = session.location(in: interaction.view ?? UIView())
    return [Double(p.x), Double(p.y)]
  }

  // MARK: UIDropInteractionDelegate

  func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
    !loading && session.hasItemsConforming(toTypeIdentifiers: [UTType.image, .movie, .audio].map(\.identifier))
  }

  func dropInteraction(_ interaction: UIDropInteraction, sessionDidEnter session: UIDropSession) {
    channel.invokeMethod("entered", arguments: point(session, interaction))
  }

  func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
    channel.invokeMethod("updated", arguments: point(session, interaction))
    return UIDropProposal(operation: .copy)
  }

  func dropInteraction(_ interaction: UIDropInteraction, sessionDidExit session: UIDropSession) {
    if !loading { channel.invokeMethod("exited", arguments: nil) }
  }

  func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
    loading = true
    let batch = Self.dir.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try? FileManager.default.createDirectory(at: batch, withIntermediateDirectories: true)
    let group = DispatchGroup()
    let lock = NSLock()
    // 落とした順を保つ(写し終わる順はばらばら)。
    var paths = [String?](repeating: nil, count: session.items.count)
    for (i, item) in session.items.enumerated() {
      let provider = item.itemProvider
      guard let type = Self.types.lazy.compactMap({ t in provider.registeredTypeIdentifiers.first { UTType($0)?.conforms(to: t) == true } }).first else { continue }
      group.enter()
      // HEIC / HEIF(写真 App の既定)は Flutter の画像の読み込みで読めないことがあるので、JPEG にして渡す
      // (image_picker が選んだ写真を JPEG にするのと同じ)。
      if let t = UTType(type), t.conforms(to: .heic) || t.conforms(to: .heif) {
        _ = provider.loadDataRepresentation(forTypeIdentifier: type) { data, _ in
          defer { group.leave() }
          guard let data, let jpeg = UIImage(data: data)?.jpegData(compressionQuality: 0.9) else { return }
          let base = ((provider.suggestedName?.isEmpty == false ? provider.suggestedName! : "photo\(i + 1)") as NSString).deletingPathExtension
          let sub = batch.appendingPathComponent("\(i)", isDirectory: true)
          let dest = sub.appendingPathComponent("\(base.replacingOccurrences(of: "/", with: "_")).jpg")
          do {
            try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
            try jpeg.write(to: dest)
            lock.lock()
            paths[i] = dest.path
            lock.unlock()
          } catch {
            NSLog("media drop: write failed: \(error)")
          }
        }
        continue
      }
      _ = provider.loadFileRepresentation(forTypeIdentifier: type) { url, _ in
        defer { group.leave() }
        guard let url else { return }
        // 渡された URL はこの中でしか読めないので、写してから返す。名前は元の名前(無ければ型の拡張子)。
        let ext = url.pathExtension.isEmpty ? (UTType(type)?.preferredFilenameExtension ?? "dat") : url.pathExtension
        let base = (provider.suggestedName?.isEmpty == false ? provider.suggestedName! : "media\(i + 1)") as NSString
        let name = base.pathExtension.isEmpty ? "\(base).\(ext)" : base as String
        let sub = batch.appendingPathComponent("\(i)", isDirectory: true)
        let dest = sub.appendingPathComponent(name.replacingOccurrences(of: "/", with: "_"))
        do {
          try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
          try FileManager.default.copyItem(at: url, to: dest)
          lock.lock()
          paths[i] = dest.path
          lock.unlock()
        } catch {
          NSLog("media drop: copy failed: \(error)")
        }
      }
    }
    group.notify(queue: .main) { [weak self] in
      guard let self else { return }
      self.loading = false
      self.channel.invokeMethod("performOperation", arguments: paths.compactMap { $0 })
    }
  }

  func dropInteraction(_ interaction: UIDropInteraction, sessionDidEnd session: UIDropSession) {
    // 離さずに終わった(取り消し)ときの片付け。受け取り中は performOperation のあとに Dart 側が idle に戻る。
    if !loading { channel.invokeMethod("exited", arguments: nil) }
  }
}
