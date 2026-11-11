import Cocoa
import FlutterMacOS
import WebKit

#if canImport(webview_flutter_wkwebview)
  import webview_flutter_wkwebview
#endif

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // アプリの中のブラウザの「この画面を探す」(D-552): WKWebView のいま見えている範囲を JPEG で返す。
    // ページ全体の写しは、Dart がスクロールしながらこれを何度か呼んでつなぐ(`web_snapshot.dart`)。保存はしない。
    let webSnapshot = FlutterMethodChannel(
      name: "rasq/web_snapshot", binaryMessenger: flutterViewController.engine.binaryMessenger)
    webSnapshot.setMethodCallHandler { [weak flutterViewController] call, result in
      guard call.method == "captureVisible" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let args = call.arguments as? [String: Any]
      guard let registry = flutterViewController,
        let id = (args?["id"] as? NSNumber)?.int64Value,
        let web = FWFWebViewFlutterWKWebViewExternalAPI.webView(
          forIdentifier: id, withPluginRegistry: registry),
        web.bounds.width > 0, web.bounds.height > 0
      else {
        result(nil)
        return
      }
      let maxWidth = CGFloat((args?["maxWidth"] as? NSNumber)?.doubleValue ?? 720)
      let scale = web.window?.backingScaleFactor ?? 1
      let config = WKSnapshotConfiguration()
      config.snapshotWidth = NSNumber(value: Double(min(web.bounds.width, maxWidth / scale)))
      web.takeSnapshot(with: config) { image, error in
        if let tiff = image?.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
          let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.88])
        {
          result(FlutterStandardTypedData(bytes: data))
        } else {
          result(
            FlutterError(code: "capture_failed", message: error?.localizedDescription, details: nil))
        }
      }
    }

    super.awakeFromNib()
  }
}
