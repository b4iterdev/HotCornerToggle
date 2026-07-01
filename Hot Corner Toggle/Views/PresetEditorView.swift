//
//  PresetEditorView.swift
//  Hot Corner Toggle
//
//  Created by Nguyen Minh Thai on 30/6/26.
//

import SwiftUI

struct PresetEditorView: View {
    @EnvironmentObject private var store: PresetStore
    @EnvironmentObject private var coordinator: EditorCoordinator
    @Environment(\.dismissWindow) private var dismissWindow

    @State private var name: String = ""
    @State private var snapshot: HotCornerSnapshot = .disabled

    private var preset: HotCornerPreset? { coordinator.editingPreset }

    var body: some View {
        VStack(spacing: 16) {
            Text(preset == nil ? "New Preset" : "Edit Preset")
                .font(.headline)

            TextField("Preset name", text: $name)
                .textFieldStyle(.roundedBorder)

            GroupBox {
                VStack(spacing: 8) {
                    ForEach(Corner.allCases) { corner in
                        cornerRow(corner)
                    }
                }
                .padding(6)
            } label: {
                HStack {
                    Text("Corners")
                    Spacer()
                    Button {
                        snapshot = HotCornerService.shared.readSnapshot()
                    } label: {
                        Label("Capture Current", systemImage: "camera.viewfinder")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
            }

            HStack {
                Button("Cancel", role: .cancel) { dismissWindow(id: "preset-editor") }
                Spacer()
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
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
        if let preset {
            name = preset.name
            snapshot = preset.snapshot
        } else {
            name = ""
            snapshot = HotCornerService.shared.readSnapshot()
        }
    }

    private func save() {
        let saved = HotCornerPreset(
            id: preset?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            snapshot: snapshot
        )
        if preset == nil {
            store.addPreset(saved)
        } else {
            store.updatePreset(saved)
        }
        dismissWindow(id: "preset-editor")
    }

    private func cornerRow(_ corner: Corner) -> some View {
        let config = binding(for: corner)
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(corner.displayName)
                    .font(.subheadline.bold())
                    .frame(width: 110, alignment: .leading)
                Picker("Action", selection: config.action) {
                    ForEach(CornerAction.allCases) { action in
                        Text(action.displayName).tag(action)
                    }
                }
                .labelsHidden()
            }

            HStack(spacing: 6) {
                Text("Hold keys:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(ModifierKey.allCases, id: \.self) { mod in
                    let isSelected = config.wrappedValue.modifier.contains(mod)
                    Button {
                        if isSelected {
                            config.wrappedValue.modifier.remove(mod)
                        } else {
                            config.wrappedValue.modifier.insert(mod)
                        }
                    } label: {
                        Text(mod.shortLabel)
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 28, height: 24)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(isSelected ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                            )
                            .foregroundColor(isSelected ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                    .help(mod.tooltip)
                }
            }
            .padding(.leading, 110)
        }
        .padding(.vertical, 2)
    }

    private func binding(for corner: Corner) -> Binding<CornerConfig> {
        Binding(
            get: { snapshot[corner] },
            set: { snapshot[corner] = $0 }
        )
    }

}

private extension ModifierKey {
    var shortLabel: String {
        switch self {
        case .shift:   return "⇧"
        case .control: return "⌃"
        case .option:  return "⌥"
        case .command: return "⌘"
        default:       return ""
        }
    }
}

#Preview {
    PresetEditorView()
        .environmentObject(PresetStore())
        .environmentObject(EditorCoordinator())
}
