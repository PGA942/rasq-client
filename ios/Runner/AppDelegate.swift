import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var screenGlimpse: ScreenGlimpseBridge?
  // 他のアプリからのメディアのドロップ (D-571)。desktop_drop を 0.9(iOS 対応)に上げたら消す。
  private var mediaDrop: MediaDropBridge?

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
  }
}
