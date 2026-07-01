//
//  PresetStore.swift
//  Hot Corner Toggle
//
//  Created by Nguyen Minh Thai on 30/6/26.
//

import Foundation
import Combine

/// Persists presets and app rules to a JSON file in Application Support and
/// exposes them as `@Published` collections for SwiftUI.
@MainActor
final class PresetStore: ObservableObject {
    @Published var presets: [HotCornerPreset] = []
    @Published var rules: [AppPresetRule] = []

    private let fileURL: URL

    init() {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fm.temporaryDirectory
        let appDir = appSupport.appendingPathComponent("HotCornerToggle", isDirectory: true)
        try? fm.createDirectory(at: appDir, withIntermediateDirectories: true)
        self.fileURL = appDir.appendingPathComponent("presets.json")
        load()
        seedDefaultsIfNeeded()
    }

    // MARK: - Presets CRUD

    func preset(with id: UUID) -> HotCornerPreset? {
        presets.first { $0.id == id }
    }

    func addPreset(_ preset: HotCornerPreset) {
        presets.append(preset)
        save()
    }

    func updatePreset(_ preset: HotCornerPreset) {
        guard let i = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[i] = preset
        save()
    }

    func deletePreset(id: UUID) {
        presets.removeAll { $0.id == id }
        // Keep rules consistent: drop any rule pointing at the deleted preset.
        rules.removeAll { $0.presetID == id }
        save()
    }

    // MARK: - Rules CRUD

    func addRule(_ rule: AppPresetRule) {
        rules.append(rule)
        save()
    }

    func updateRule(_ rule: AppPresetRule) {
        guard let i = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        rules[i] = rule
        save()
    }

    func deleteRule(id: UUID) {
        rules.removeAll { $0.id == id }
        save()
    }

    /// Rules whose target app matches the given bundle identifier.
    func rules(forBundleId bundleId: String) -> [AppPresetRule] {
        rules.filter { $0.appBundleIdentifier == bundleId }
    }

    // MARK: - Persistence

    private struct StoreData: Codable {
        var presets: [HotCornerPreset]
        var rules: [AppPresetRule]
    }

    func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        if let store = try? decoder.decode(StoreData.self, from: data) {
            self.presets = store.presets
            self.rules = store.rules
        }
    }

    func save() {
        let store = StoreData(presets: presets, rules: rules)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(store) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    /// Seeds a starter preset the first time the app runs so the UI is not empty.
    private func seedDefaultsIfNeeded() {
        guard presets.isEmpty else { return }
        let starter = HotCornerPreset(
            name: "Screen Saver — Bottom Right",
            snapshot: HotCornerSnapshot(configs: [
                .init(corner: .topLeft,     action: .none),
                .init(corner: .topRight,    action: .none),
                .init(corner: .bottomLeft,  action: .none),
                .init(corner: .bottomRight, action: .startScreenSaver),
            ])
        )
        presets.append(starter)
        save()
    }
}
