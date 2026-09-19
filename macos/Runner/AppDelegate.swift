import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  // macOS の GUI アプリは、開けるファイル数の既定が 256。画像のキャッシュ / 通信 / 動画の書き出しが重なると尽きて
  // 「Too many open files」になり、AVFoundation が動画を開けなくなる(-11800)。起動時に上げておく。
  override func applicationWillFinishLaunching(_ notification: Notification) {
    var limit = rlimit()
    if getrlimit(RLIMIT_NOFILE, &limit) == 0 {
      let wanted: rlim_t = 8192
      limit.rlim_cur = min(wanted, limit.rlim_max)
      setrlimit(RLIMIT_NOFILE, &limit)
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
