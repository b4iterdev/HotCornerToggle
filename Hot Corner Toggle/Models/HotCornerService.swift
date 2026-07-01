//
//  HotCornerService.swift
//  Hot Corner Toggle
//
//  Created by Nguyen Minh Thai on 30/6/26.
//

import Foundation

// MARK: - Domain Types

/// The four screen corners that macOS maps Hot Corner actions to.
enum Corner: String, CaseIterable, Identifiable, Codable {
    case topLeft = "tl"
    case topRight = "tr"
    case bottomLeft = "bl"
    case bottomRight = "br"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .topLeft:     return "Top Left"
        case .topRight:    return "Top Right"
        case .bottomLeft:  return "Bottom Left"
        case .bottomRight: return "Bottom Right"
        }
    }
}

/// A single Hot Corner action, encoded as the integer value macOS stores in
/// the `com.apple.dock` defaults domain.
enum CornerAction: Int, CaseIterable, Identifiable, Codable {
    case none = 0
    case off = 1
    case missionControl = 2
    case showApplicationWindows = 3
    case desktop = 4
    case startScreenSaver = 5
    case disableScreenSaver = 6
    case dashboard = 7
    case sleepDisplay = 10
    case launchpad = 11
    case notificationCenter = 12
    case lockScreen = 13
    case quickNote = 14

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .none:                return "—"
        case .off:                 return "Off"
        case .missionControl:      return "Mission Control"
        case .showApplicationWindows: return "Application Windows"
        case .desktop:             return "Desktop"
        case .startScreenSaver:    return "Start Screen Saver"
        case .disableScreenSaver:  return "Disable Screen Saver"
        case .dashboard:           return "Dashboard"
        case .sleepDisplay:        return "Put Display to Sleep"
        case .launchpad:           return "Launchpad"
        case .notificationCenter:  return "Notification Center"
        case .lockScreen:          return "Lock Screen"
        case .quickNote:           return "Quick Note"
        }
    }
}

/// Modifier-key bitmask matching macOS' integer encoding for Hot Corners.
struct ModifierKey: OptionSet, Codable, Hashable {
    let rawValue: Int

    static let none    = ModifierKey([])
    static let shift   = ModifierKey(rawValue: 131_072)
    static let control = ModifierKey(rawValue: 262_144)
    static let option  = ModifierKey(rawValue: 524_288)
    static let command = ModifierKey(rawValue: 1_048_576)

    /// All modifier toggles in display order.
    static let allCases: [ModifierKey] = [.shift, .control, .option, .command]

    var displayName: String {
        var parts: [String] = []
        if contains(.shift)   { parts.append("⇧") }
        if contains(.control) { parts.append("⌃") }
        if contains(.option)  { parts.append("⌥") }
        if contains(.command) { parts.append("⌘") }
        return parts.joined()
    }

    var tooltip: String {
        switch self {
        case .shift:   return "Shift"
        case .control: return "Control"
        case .option:  return "Option"
        case .command: return "Command"
        default:       return ""
        }
    }
}

/// Configuration for a single corner: which corner, what action, which modifiers.
struct CornerConfig: Codable, Equatable, Identifiable {
    var id: String { corner.rawValue }
    var corner: Corner
    var action: CornerAction
    var modifier: ModifierKey

    init(corner: Corner, action: CornerAction, modifier: ModifierKey = .none) {
        self.corner = corner
        self.action = action
        self.modifier = modifier
    }
}

/// A complete snapshot of all four corners at a point in time.
struct HotCornerSnapshot: Codable, Equatable {
    var configs: [CornerConfig]

    /// Snapshot with every corner turned off.
    static let disabled: HotCornerSnapshot = .init(
        configs: Corner.allCases.map { CornerConfig(corner: $0, action: .off) }
    )

    /// Access a config by corner.
    subscript(corner: Corner) -> CornerConfig {
        get { configs.first { $0.corner == corner } ?? CornerConfig(corner: corner, action: .none) }
        set {
            if let i = configs.firstIndex(where: { $0.corner == corner }) {
                configs[i] = newValue
            } else {
                configs.append(newValue)
            }
        }
    }
}

// MARK: - HotCornerService

/// Reads and writes macOS Hot Corner preferences (`com.apple.dock`) and
/// restarts the Dock so that changes take effect immediately.
///
/// There is no public Cocoa API for Hot Corners; the values live in the Dock
/// preferences domain and the Dock must be relaunched to pick up changes.
final class HotCornerService {
    static let shared = HotCornerService()

    private let defaultsDomain = "com.apple.dock"
    private let defaultsURL = URL(fileURLWithPath: "/usr/bin/defaults")
    private let killallURL = URL(fileURLWithPath: "/usr/bin/killall")

    private init() {}

    // MARK: Read

    /// Reads the current Hot Corner state from `com.apple.dock`.
    func readSnapshot() -> HotCornerSnapshot {
        let configs = Corner.allCases.map { corner -> CornerConfig in
            let action = readInt(key: "wvous-\(corner.rawValue)-corner") ?? 0
            let mod    = readInt(key: "wvous-\(corner.rawValue)-modifier") ?? 0
            return CornerConfig(
                corner: corner,
                action: CornerAction(rawValue: action) ?? .none,
                modifier: ModifierKey(rawValue: mod)
            )
        }
        return HotCornerSnapshot(configs: configs)
    }

    // MARK: Write

    /// Writes the snapshot to `com.apple.dock` and restarts Dock.
    func apply(_ snapshot: HotCornerSnapshot) {
        for config in snapshot.configs {
            writeInt(key: "wvous-\(config.corner.rawValue)-corner",    value: config.action.rawValue)
            writeInt(key: "wvous-\(config.corner.rawValue)-modifier",  value: config.modifier.rawValue)
        }
        restartDock()
    }

    /// Convenience: turn every corner off.
    func disableAll() { apply(.disabled) }

    // MARK: - Process helpers

    @discardableResult
    private func readInt(key: String) -> Int? {
        let process = Process()
        process.executableURL = defaultsURL
        process.arguments = ["read", defaultsDomain, key]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do { try process.run() } catch { return nil }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let trimmed = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return Int(trimmed)
    }

    private func writeInt(key: String, value: Int) {
        let process = Process()
        process.executableURL = defaultsURL
        process.arguments = ["write", defaultsDomain, key, "-int", "\(value)"]
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            // Writing can fail if the defaults cache is busy; ignore — the next
            // write/restart will typically succeed.
        }
    }

    private func restartDock() {
        let process = Process()
        process.executableURL = killallURL
        process.arguments = ["Dock"]
        try? process.run()
    }
}
