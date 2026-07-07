//
//  CornerControlView.swift
//  Hot Corner Toggle
//
//  Created by Nguyen Minh Thai on 30/6/26.
//

import SwiftUI

struct CornerControlView: View {
    @EnvironmentObject private var store: PresetStore
    @EnvironmentObject private var applier: PresetApplier
    @EnvironmentObject private var launchOnLogin: LaunchOnLoginController
    @EnvironmentObject private var coordinator: EditorCoordinator
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 12) {
            header
            Divider()
            presetsSection
            Divider()
            rulesSection
            Divider()
            launchOnLoginSection
            Divider()
            quitButton
        }
        .padding(12)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Hot Corners")
                    .font(.headline)
                Text(applier.isHotCornersEnabled ? "Enabled" : "Disabled")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { applier.isHotCornersEnabled },
                set: { _ in applier.toggleHotCorners() }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
    }

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Presets")
                    .font(.subheadline.bold())
                Spacer()
                Button {
                    coordinator.newPreset()
                    openWindow(id: "preset-editor")
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.borderless)
            }
            if store.presets.isEmpty {
                Text("No presets yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.presets) { preset in
                    presetRow(preset)
                }
            }
        }
    }

    private func presetRow(_ preset: HotCornerPreset) -> some View {
        HStack {
            Image(systemName: "square.grid.2x2")
                .foregroundStyle(.secondary)
            Text(preset.name)
            Spacer()
            Menu {
                Button("Apply now") { applier.applyPreset(preset) }
                Divider()
                Button("Edit") {
                    coordinator.editPreset(preset)
                    openWindow(id: "preset-editor")
                }
                Button("Delete", role: .destructive) { store.deletePreset(id: preset.id) }
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.vertical, 2)
    }

    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("App Rules")
                    .font(.subheadline.bold())
                Spacer()
                Button {
                    coordinator.newRule()
                    openWindow(id: "rule-editor")
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.borderless)
            }
            if store.rules.isEmpty {
                Text("No app rules yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.rules) { rule in
                    ruleRow(rule)
                }
            }
        }
    }

    private func ruleRow(_ rule: AppPresetRule) -> some View {
        HStack(spacing: 8) {
            Image(systemName: rule.triggerType.iconName)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(rule.appName)
                Text("\(rule.triggerType.displayName) · \(store.preset(with: rule.presetID)?.name ?? "Missing")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Menu {
                Button("Edit") {
                    coordinator.editRule(rule)
                    openWindow(id: "rule-editor")
                }
                Button("Delete", role: .destructive) { store.deleteRule(id: rule.id) }
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.vertical, 2)
    }

    private var launchOnLoginSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Launch on Login")
                        .font(.subheadline.bold())
                    Text(launchOnLogin.statusDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { launchOnLogin.isEnabled },
                    set: { launchOnLogin.setLaunchOnLoginEnabled($0) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .disabled(!launchOnLogin.canChangeSetting)
            }

            if let validationMessage = launchOnLogin.validationMessage {
                Text(validationMessage)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear { launchOnLogin.refreshStatus() }
    }

    private var quitButton: some View {
        Button("Quit Hot Corner Toggle") {
            NSApplication.shared.terminate(nil)
        }
        .buttonStyle(.bordered)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    CornerControlView()
        .environmentObject(PresetStore())
        .environmentObject(AppMonitor())
        .environmentObject(PresetApplier(
            store: PresetStore(),
            monitor: AppMonitor()
        ))
        .environmentObject(LaunchOnLoginController())
        .environmentObject(EditorCoordinator())
}
