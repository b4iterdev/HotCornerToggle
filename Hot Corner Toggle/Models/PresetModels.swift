//
//  PresetModels.swift
//  Hot Corner Toggle
//
//  Created by Nguyen Minh Thai on 30/6/26.
//

import Foundation

/// A named set of corner configurations that can be applied as a group.
struct HotCornerPreset: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var snapshot: HotCornerSnapshot

    init(id: UUID = UUID(), name: String, snapshot: HotCornerSnapshot) {
        self.id = id
        self.name = name
        self.snapshot = snapshot
    }
}

/// When an app rule should activate its assigned preset.
enum TriggerType: String, Codable, CaseIterable, Identifiable {
    /// Activate while the app is the frontmost (focused) window.
    case whenFocused
    /// Activate while the app is running (regardless of focus).
    case whenRunning

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .whenFocused: return "When Focused"
        case .whenRunning: return "When Running"
        }
    }

    var iconName: String {
        switch self {
        case .whenFocused: return "rectangle.dashed"
        case .whenRunning: return "play.circle"
        }
    }
}

/// A rule that ties a specific application to a preset with a trigger type.
struct AppPresetRule: Codable, Identifiable, Equatable {
    var id: UUID
    var appName: String
    var appBundleIdentifier: String
    var presetID: UUID
    var triggerType: TriggerType

    init(id: UUID = UUID(),
         appName: String,
         appBundleIdentifier: String,
         presetID: UUID,
         triggerType: TriggerType) {
        self.id = id
        self.appName = appName
        self.appBundleIdentifier = appBundleIdentifier
        self.presetID = presetID
        self.triggerType = triggerType
    }
}
