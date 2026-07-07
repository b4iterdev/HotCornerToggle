//
//  Hot_Corner_ToggleApp.swift
//  Hot Corner Toggle
//
//  Created by Nguyen Minh Thai on 30/6/26.
//

import SwiftUI
import AppKit
import CoreServices

@main
struct Hot_Corner_ToggleApp: App {
    @StateObject private var store: PresetStore
    @StateObject private var monitor: AppMonitor
    @StateObject private var applier: PresetApplier
    @StateObject private var launchOnLogin = LaunchOnLoginController()
    @StateObject private var coordinator = EditorCoordinator()

    init() {
        Self.registerAppWithLaunchServices()

        let store = PresetStore()
        let monitor = AppMonitor()
        _store = StateObject(wrappedValue: store)
        _monitor = StateObject(wrappedValue: monitor)
        _applier = StateObject(wrappedValue: PresetApplier(store: store, monitor: monitor))
    }

    // Re-register the bundle with Launch Services so SMAppService.mainApp resolves to the
    // running copy after the app is moved (e.g. into /Applications); otherwise macOS reports
    // .notFound / "cannot validate" for Login Items. LSRegisterURL is deprecated but the only
    // public API that does this.
    private static func registerAppWithLaunchServices() {
        LSRegisterURL(Bundle.main.bundleURL as CFURL, true)
    }

    var body: some Scene {
        MenuBarExtra {
            CornerControlView()
                .environmentObject(store)
                .environmentObject(monitor)
                .environmentObject(applier)
                .environmentObject(launchOnLogin)
                .environmentObject(coordinator)
                .frame(width: 360)
        } label: {
            Image(systemName: "rectangle.dashed.badge.record")
        }
        .menuBarExtraStyle(.window)

        Window("Preset Editor", id: "preset-editor") {
            PresetEditorView()
                .environmentObject(store)
                .environmentObject(coordinator)
        }
        .defaultSize(width: 460, height: 480)

        Window("Rule Editor", id: "rule-editor") {
            RuleEditorView()
                .environmentObject(store)
                .environmentObject(coordinator)
        }
        .defaultSize(width: 420, height: 400)
    }
}
