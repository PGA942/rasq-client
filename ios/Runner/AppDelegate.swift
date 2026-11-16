import Flutter
import UIKit
import WebKit

#if canImport(webview_flutter_wkwebview)
  import webview_flutter_wkwebview
#endif

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var screenGlimpse: ScreenGlimpseBridge?
  // 他のアプリからのメディアのドロップ (D-571)。desktop_drop を 0.9(iOS 対応)に上げたら消す。
  private var mediaDrop: MediaDropBridge?
  private var webSnapshot: WebSnapshotBridge?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ScreenGlimpseBridge") {
      screenGlimpse = ScreenGlimpseBridge(messenger: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "MediaDropBridge") {
      mediaDrop = MediaDropBridge(messenger: registrar.messenger())
    }
    // アプリの中のブラウザの「この画面を探す」(D-552): 見えている範囲の写し。
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "WebSnapshotBridge") {
      webSnapshot = WebSnapshotBridge(registrar: registrar)
    }
  }
}

/// アプリの中のブラウザの「この画面を探す」(D-552): WKWebView の**いま見えている範囲**を JPEG で返す。
/// ページ全体の写しは、Dart がスクロールしながらこれを何度か呼んでつなぐ(`web_snapshot.dart`)。
/// 撮った画像はどこにも保存しない(Dart に返すだけ)。
final class WebSnapshotBridge {
  private let channel: FlutterMethodChannel

  init(registrar: FlutterPluginRegistrar) {
    channel = FlutterMethodChannel(name: "rasq/web_snapshot", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard call.method == "captureVisible" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let args = call.arguments as? [String: Any]
      guard let id = (args?["id"] as? NSNumber)?.int64Value,
        let web = FWFWebViewFlutterWKWebViewExternalAPI.webView(
          forIdentifier: id, withPluginRegistrar: registrar),
        web.bounds.width > 0, web.bounds.height > 0
      else {
        result(nil)
        return
      }
      // 幅を最大 maxWidth 画素に縮める(長いページを何枚もつなぐので、メモリを抑える)。
      let maxWidth = CGFloat((args?["maxWidth"] as? NSNumber)?.doubleValue ?? 720)
      let scale = web.window?.screen.scale ?? UIScreen.main.scale
      let config = WKSnapshotConfiguration()
      config.snapshotWidth = NSNumber(value: Double(min(web.bounds.width, maxWidth / scale)))
      web.takeSnapshot(with: config) { image, error in
        if let data = image?.jpegData(compressionQuality: 0.88) {
          result(FlutterStandardTypedData(bytes: data))
        } else {
          result(
            FlutterError(code: "capture_failed", message: error?.localizedDescription, details: nil))
        }
      }
    }
  }
}
