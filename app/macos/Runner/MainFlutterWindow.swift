/*
 * [INPUT]: Depends on Cocoa system background semantics, FlutterMacOS, window_manager launch visibility support, generated plugin registration, and the shared 1120x760 desktop launch geometry.
 * [OUTPUT]: Provides the initially hidden, background-matched macOS Flutter host window with launch size and centered placement matching the Dart window configuration.
 * [POS]: Serves as the native macOS window bootstrap and hidden-until-content-ready presentation gate before Flutter desktop initialization completes.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import Cocoa
import FlutterMacOS
import window_manager

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    var windowFrame = self.frame
    windowFrame.size = NSSize(width: 1120, height: 760)
    self.backgroundColor = NSColor.windowBackgroundColor
    flutterViewController.backgroundColor = NSColor.windowBackgroundColor
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: false)
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  override public func order(
    _ place: NSWindow.OrderingMode,
    relativeTo otherWin: Int
  ) {
    super.order(place, relativeTo: otherWin)
    hiddenWindowAtLaunch()
  }
}
