import AppKit
import Combine
import CoreGraphics
import IOKit

/// Detects external-monitor connect/disconnect and toggles the built-in
/// panel on/off via the private CGSConfigureDisplayEnabled call. There is
/// no public API for this — see CGSPrivate.swift.
final class DisplayManager: ObservableObject {

    @Published private(set) var isBlackedOut = false
    @Published private(set) var hasExternalDisplay = false

    @Published var autoBlackoutEnabled: Bool {
        didSet {
            UserDefaults.standard.set(autoBlackoutEnabled, forKey: "autoBlackoutEnabled")
            reevaluate()
        }
    }

    private var actionInProgress = false
    private var isSystemSleeping = false
    private var externalDisconnectedDuringSleep = false
    private var wakeSettleTimer: Timer?

    init() {
        autoBlackoutEnabled = UserDefaults.standard.object(forKey: "autoBlackoutEnabled") as? Bool ?? true

        CGDisplayRegisterReconfigurationCallback({ displayID, flags, userInfo in
            guard let userInfo else { return }
            let manager = Unmanaged<DisplayManager>.fromOpaque(userInfo).takeUnretainedValue()
            DispatchQueue.main.async {
                manager.handleReconfiguration(displayID: displayID, flags: flags)
            }
        }, Unmanaged.passUnretained(self).toOpaque())

        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            self?.isSystemSleeping = true
        }
        center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.handleWake()
        }

        hasActiveExternalDisplay()
    }

    // MARK: - Public controls

    /// Manual "turn it off now" entry point. Refuses if there is no real
    /// external display, since that would leave the Mac with no visible
    /// screen at all.
    @discardableResult
    func disableBuiltin() -> Bool {
        guard hasActiveExternalDisplay() else { return false }
        apply(enabled: false)
        return isBlackedOut
    }

    @discardableResult
    func enableBuiltin() -> Bool {
        apply(enabled: true)
        return !isBlackedOut
    }

    func toggleManually() {
        if isBlackedOut {
            enableBuiltin()
        } else {
            disableBuiltin()
        }
    }

    // MARK: - Detection

    private static func discoverBuiltinID() -> CGDirectDisplayID {
        var displays = [CGDirectDisplayID](repeating: 0, count: 8)
        var count: UInt32 = 0
        CGGetOnlineDisplayList(8, &displays, &count)
        for i in 0..<Int(count) where CGDisplayIsBuiltin(displays[Int(i)]) != 0 {
            return displays[Int(i)]
        }
        return CGMainDisplayID()
    }

    /// Re-resolved on every call rather than cached: CGDirectDisplayID values
    /// can be reassigned across reconfigurations (toggling a panel via the
    /// private disable call is itself a reconfiguration), so caching this
    /// once at launch risks silently operating on the wrong physical display
    /// later on.
    private func currentBuiltinID() -> CGDirectDisplayID {
        Self.discoverBuiltinID()
    }

    private func displayIsHardwareBacked(_ displayID: CGDirectDisplayID) -> Bool {
        if cgDisplayIOServicePort(displayID) != 0 {
            return true
        }
        // macOS assigns pseudo-vendor IDs above the 16-bit PCI vendor range
        // to virtual/placeholder displays (e.g. "unkn", "virt" as FourCC).
        return CGDisplayVendorNumber(displayID) <= 0xFFFF
    }

    /// Also refreshes the published `hasExternalDisplay` so the UI stays in
    /// sync with every call site that checks connectivity.
    @discardableResult
    func hasActiveExternalDisplay() -> Bool {
        var displays = [CGDirectDisplayID](repeating: 0, count: 8)
        var count: UInt32 = 0
        CGGetActiveDisplayList(8, &displays, &count)
        var found = false
        for i in 0..<Int(count) {
            let d = displays[Int(i)]
            if CGDisplayIsBuiltin(d) != 0 { continue }
            if displayIsHardwareBacked(d) {
                found = true
                break
            }
        }
        hasExternalDisplay = found
        return found
    }

    // MARK: - Core apply

    private func apply(enabled: Bool) {
        guard !isSystemSleeping else { return }
        actionInProgress = true
        let targetID = currentBuiltinID()

        var config: CGDisplayConfigRef?
        var err = CGBeginDisplayConfiguration(&config)
        guard err == .success else {
            actionInProgress = false
            return
        }
        err = cgsConfigureDisplayEnabled(config, targetID, enabled)
        if err != .success {
            CGCancelDisplayConfiguration(config)
            actionInProgress = false
            // Don't assume we're already in the requested state — ask the
            // hardware. Trusting `enabled` here is what let the published
            // state drift from reality in the first place.
            isBlackedOut = CGDisplayIsActive(targetID) == 0
            return
        }
        _ = CGCompleteDisplayConfiguration(config, .permanently)
        isBlackedOut = CGDisplayIsActive(targetID) == 0

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.actionInProgress = false
            self?.reevaluate()
        }
    }

    /// Safety invariant: never stay blacked out with no external display,
    /// and never auto-blackout if the user turned auto mode off.
    private func reevaluate() {
        guard !isSystemSleeping, !actionInProgress else { return }
        isBlackedOut = CGDisplayIsActive(currentBuiltinID()) == 0
        let hasExternal = hasActiveExternalDisplay()
        if isBlackedOut && !hasExternal {
            apply(enabled: true)
        } else if !isBlackedOut && hasExternal && autoBlackoutEnabled {
            apply(enabled: false)
        }
    }

    // MARK: - Reconfiguration / sleep-wake

    private func handleReconfiguration(displayID: CGDirectDisplayID, flags: CGDisplayChangeSummaryFlags) {
        if flags.contains(.beginConfigurationFlag) { return }

        if isSystemSleeping {
            let isDisconnect = flags.contains(.removeFlag) || flags.contains(.disabledFlag)
            if isDisconnect && displayID != currentBuiltinID() && isBlackedOut {
                externalDisconnectedDuringSleep = true
            }
            return
        }
        guard !actionInProgress else { return }
        reevaluate()
    }

    private func handleWake() {
        isSystemSleeping = false
        wakeSettleTimer?.invalidate()
        // Give the display pipeline a moment to settle before re-checking;
        // reconfiguration callbacks keep firing for a bit right after wake.
        wakeSettleTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            guard let self else { return }
            if self.externalDisconnectedDuringSleep {
                self.externalDisconnectedDuringSleep = false
                self.apply(enabled: true)
            } else {
                self.reevaluate()
            }
        }
    }
}
