import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var displayManager: DisplayManager!
    private var statusBar: StatusBarController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        displayManager = DisplayManager()
        statusBar = StatusBarController(displayManager: displayManager)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // no Dock icon, menu bar only
let delegate = AppDelegate()
app.delegate = delegate
app.run()
