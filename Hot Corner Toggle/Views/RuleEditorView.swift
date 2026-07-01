//
//  RuleEditorView.swift
//  Hot Corner Toggle
//
//  Created by Nguyen Minh Thai on 30/6/26.
//

import SwiftUI
import AppKit

struct RuleEditorView: View {
    @EnvironmentObject private var store: PresetStore
    @EnvironmentObject private var coordinator: EditorCoordinator
    @Environment(\.dismissWindow) private var dismissWindow

    @State private var appName: String = ""
    @State private var appBundleIdentifier: String = ""
    @State private var presetID: UUID = UUID()
    @State private var triggerType: TriggerType = .whenFocused

    private var rule: AppPresetRule? { coordinator.editingRule }

    var body: some View {
        VStack(spacing: 16) {
            Text(rule == nil ? "New App Rule" : "Edit App Rule")
                .font(.headline)

            GroupBox("Target App") {
                HStack {
                    if appBundleIdentifier.isEmpty {
                        Image(systemName: "app.dashed")
                            .foregroundStyle(.secondary)
                        Text("No app selected")
                            .foregroundStyle(.secondary)
                    } else {
                        Image(systemName: "app.fill")
                        Text(appName)
                    }
                    Spacer()
                    Menu {
                        Menu("Running Apps") {
                            ForEach(runningApps(), id: \.bundleIdentifier) { app in
                                Button(app.localizedName ?? "Unknown") {
                                    appName = app.localizedName ?? "Unknown"
                                    appBundleIdentifier = app.bundleIdentifier ?? ""
                                }
                            }
                        }
                        Divider()
                        Button("Browse in Finder…") { chooseApp() }
                    } label: {
                        Text("Choose…")
                    }
                }
                .padding(6)
            }

            GroupBox("Trigger") {
                Picker("Trigger", selection: $triggerType) {
                    ForEach(TriggerType.allCases) { t in
                        Label(t.displayName, systemImage: t.iconName).tag(t)
                    }
                }
                .pickerStyle(.radioGroup)
                .padding(6)
            }

            GroupBox("Preset") {
                Picker("Apply preset", selection: $presetID) {
                    ForEach(store.presets) { p in
                        Text(p.name).tag(p.id)
                    }
                }
                .labelsHidden()
                .padding(6)
            }

            HStack {
                Button("Cancel", role: .cancel) { dismissWindow(id: "rule-editor") }
                Spacer()
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(appBundleIdentifier.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 420)
        .onAppear {
            load()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func load() {
        if let rule {
            appName = rule.appName
            appBundleIdentifier = rule.appBundleIdentifier
            presetID = rule.presetID
            triggerType = rule.triggerType
        } else if let first = store.presets.first {
            presetID = first.id
        }
    }

    private func save() {
        let saved = AppPresetRule(
            id: rule?.id ?? UUID(),
            appName: appName,
            appBundleIdentifier: appBundleIdentifier,
            presetID: presetID,
            triggerType: triggerType
        )
        if rule == nil {
            store.addRule(saved)
        } else {
            store.updateRule(saved)
        }
        dismissWindow(id: "rule-editor")
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = []
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Select"
        if panel.runModal() == .OK, let url = panel.url {
            extractAppInfo(from: url)
        }
    }

    private func extractAppInfo(from url: URL) {
        let bundle = Bundle(url: url)
        appName = bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        appBundleIdentifier = bundle?.bundleIdentifier ?? ""
    }

    private func runningApps() -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }
}

#Preview {
    RuleEditorView()
        .environmentObject(PresetStore())
        .environmentObject(EditorCoordinator())
}
