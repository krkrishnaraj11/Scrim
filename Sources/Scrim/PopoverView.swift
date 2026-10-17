import SwiftUI
import ServiceManagement

struct PopoverView: View {
    @ObservedObject var displayManager: DisplayManager
    var onQuit: () -> Void

    // Command Line Tools' Swift toolchain can't load the SwiftUIMacros
    // plugin (it only ships inside full Xcode), so @State isn't available
    // here. A manual Binding backed directly by SMAppService avoids it.
    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { SMAppService.mainApp.status == .enabled },
            set: { setLaunchAtLogin($0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Scrim")
                    .font(.headline)
                Text(statusLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Button(action: toggleManual) {
                HStack {
                    Image(systemName: displayManager.isBlackedOut ? "sun.max" : "moon.fill")
                    Text(displayManager.isBlackedOut ? "Turn Internal Display Back On" : "Turn Internal Display Off Now")
                    Spacer()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!displayManager.isBlackedOut && !displayManager.hasExternalDisplay)

            if !displayManager.isBlackedOut && !displayManager.hasExternalDisplay {
                Text("Connect an external monitor to disable the internal display.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Toggle("Auto-disable when external monitor connects", isOn: $displayManager.autoBlackoutEnabled)

            Toggle("Launch at Login", isOn: launchAtLoginBinding)

            Divider()

            Button("Quit Scrim", action: onQuit)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 300)
    }

    private var statusLine: String {
        let external = displayManager.hasExternalDisplay ? "Connected" : "Not connected"
        let internalState = displayManager.isBlackedOut ? "Off" : "On"
        return "External: \(external) · Internal: \(internalState)"
    }

    private func toggleManual() {
        displayManager.toggleManually()
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("[login-item] failed to toggle: \(error.localizedDescription)")
        }
    }
}
