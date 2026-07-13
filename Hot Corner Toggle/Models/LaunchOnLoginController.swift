import AppKit
import Combine
import Foundation
import ServiceManagement

@MainActor
final class LaunchOnLoginController: ObservableObject {
    enum Status: Equatable {
        case checking
        case enabled
        case disabled
        case requiresApproval
        case unavailable
    }

    @Published private(set) var status: Status = .checking
    @Published private(set) var isEnabled = false
    @Published private(set) var statusDescription = "Checking…"
    @Published private(set) var validationMessage: String?
    @Published private(set) var canChangeSetting = true

    private let notificationCenter: NotificationCenter
    private var activationObserver: NSObjectProtocol?

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
        refreshStatus()
        activationObserver = notificationCenter.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let controller = self else { return }
            Task { @MainActor in
                controller.refreshStatus()
            }
        }
    }

    deinit {
        if let activationObserver {
            notificationCenter.removeObserver(activationObserver)
        }
    }

    func toggleLaunchOnLogin() {
        setLaunchOnLoginEnabled(!isEnabled)
    }

    func setLaunchOnLoginEnabled(_ enabled: Bool) {
        refreshStatus()

        guard #available(macOS 13.0, *) else {
            status = .unavailable
            isEnabled = false
            statusDescription = "Not supported"
            validationMessage = "Launch on Login requires macOS 13 or later."
            canChangeSetting = false
            return
        }

        validationMessage = nil

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            refreshStatus()
            validationMessage = "Could not \(enabled ? "enable" : "disable") Launch on Login: \(error.localizedDescription)"
            return
        }

        refreshStatus(expectedEnabled: enabled)
    }

    func refreshStatus() {
        refreshStatus(expectedEnabled: nil)
    }

    private func refreshStatus(expectedEnabled: Bool?) {
        guard #available(macOS 13.0, *) else {
            status = .unavailable
            isEnabled = false
            statusDescription = "Not supported"
            validationMessage = "Launch on Login requires macOS 13 or later."
            canChangeSetting = false
            return
        }

        let status = SMAppService.mainApp.status
        self.status = uiStatus(for: status)
        isEnabled = self.status == .enabled
        canChangeSetting = self.status != .unavailable
        statusDescription = description(for: self.status)

        if let expectedEnabled {
            validationMessage = validationMessage(for: status, expectedEnabled: expectedEnabled)
        } else {
            validationMessage = passiveValidationMessage(for: status)
        }
    }

    @available(macOS 13.0, *)
    private func uiStatus(for status: SMAppService.Status) -> Status {
        switch status {
        case .enabled:
            return .enabled
        case .notRegistered:
            return .disabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .disabled
        @unknown default:
            return .unavailable
        }
    }

    private func description(for status: Status) -> String {
        switch status {
        case .checking:
            return "Checking…"
        case .enabled:
            return "Enabled"
        case .disabled:
            return "Disabled"
        case .requiresApproval:
            return "Needs approval"
        case .unavailable:
            return "Unavailable"
        }
    }

    @available(macOS 13.0, *)
    private func validationMessage(for status: SMAppService.Status, expectedEnabled: Bool) -> String? {
        switch (expectedEnabled, status) {
        case (true, .enabled), (false, .notRegistered):
            return nil
        case (true, .requiresApproval):
            return "Launch on Login was registered but still needs approval in System Settings → General → Login Items."
        case (_, .notFound):
            return nil
        case (true, .notRegistered):
            return "Launch on Login did not stay enabled after registration. Please try again or check Login Items in System Settings."
        case (false, .enabled):
            return "Launch on Login is still enabled after unregistering. Please check Login Items in System Settings."
        case (false, .requiresApproval):
            return "Launch on Login is pending approval. Remove or deny it in System Settings → General → Login Items if it still appears."
        @unknown default:
            return "macOS returned an unknown Launch on Login status. Please verify it in System Settings → General → Login Items."
        }
    }

    @available(macOS 13.0, *)
    private func passiveValidationMessage(for status: SMAppService.Status) -> String? {
        switch status {
        case .requiresApproval:
            return "Approval required in System Settings → General → Login Items."
        case .notFound:
            return nil
        case .enabled, .notRegistered:
            return nil
        @unknown default:
            return "Unknown Launch on Login status. Verify in System Settings."
        }
    }
}
