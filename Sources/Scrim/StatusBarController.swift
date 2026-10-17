import AppKit
import SwiftUI

final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let displayManager: DisplayManager
    private var stateObservation: AnyObject?

    init(displayManager: DisplayManager) {
        self.displayManager = displayManager
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.popover = NSPopover()
        super.init()

        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(displayManager: displayManager, onQuit: { NSApp.terminate(nil) })
        )

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover)
        }

        stateObservation = displayManager.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.refreshIcon() }
        } as AnyObject

        refreshIcon()
    }

    private func refreshIcon() {
        guard let button = statusItem.button else { return }
        let symbolName = displayManager.isBlackedOut ? "rectangle.slash.fill" : "rectangle.on.rectangle.slash"
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Scrim")
        image?.isTemplate = true
        button.image = image
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
