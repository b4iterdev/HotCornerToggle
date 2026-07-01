//
//  AppMonitor.swift
//  Hot Corner Toggle
//
//  Created by Nguyen Minh Thai on 30/6/26.
//

import AppKit
import Combine

/// Monitors running-application state changes via `NSWorkspace` and emits
/// high-level events that the rest of the app can react to.
final class AppMonitor: ObservableObject {

    enum AppEvent {
        case launched(bundleId: String, name: String)
        case terminated(bundleId: String)
        case activated(bundleId: String, name: String)
        case deactivated(bundleId: String)
    }

    /// Broadcasts app lifecycle / focus events.
    let eventSubject = PassthroughSubject<AppEvent, Never>()

    /// The bundle id of the currently frontmost regular app.
    @Published private(set) var frontmostBundleId: String = ""

    private var observers: [NSObjectProtocol] = []
    private let workspace = NSWorkspace.shared

    init() {}

    /// Begin observing workspace notifications. Safe to call once.
    func start() {
        guard observers.isEmpty else { return }
        let nc = workspace.notificationCenter

        observers.append(nc.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.app, let bid = app.bundleIdentifier else { return }
            self?.eventSubject.send(.launched(bundleId: bid, name: app.localizedName ?? ""))
        })

        observers.append(nc.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.app, let bid = app.bundleIdentifier else { return }
            self?.eventSubject.send(.terminated(bundleId: bid))
        })

        observers.append(nc.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            // Only track regular (windowed) apps so background helpers don't
            // trigger overrides.
            guard let app = note.app,
                  app.activationPolicy == .regular,
                  let bid = app.bundleIdentifier else { return }
            self?.frontmostBundleId = bid
            self?.eventSubject.send(.activated(bundleId: bid, name: app.localizedName ?? ""))
        })

        observers.append(nc.addObserver(
            forName: NSWorkspace.didDeactivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.app, let bid = app.bundleIdentifier else { return }
            self?.eventSubject.send(.deactivated(bundleId: bid))
        })

        // Seed the current frontmost app so the applier can apply on launch.
        if let front = workspace.frontmostApplication, let bid = front.bundleIdentifier {
            self.frontmostBundleId = bid
            self.eventSubject.send(.activated(bundleId: bid, name: front.localizedName ?? ""))
        }
    }

    func stop() {
        let nc = workspace.notificationCenter
        observers.forEach { nc.removeObserver($0) }
        observers.removeAll()
    }

    deinit { stop() }
}

private extension Notification {
    /// Extracts the `NSRunningApplication` from a workspace notification.
    var app: NSRunningApplication? {
        userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
    }
}
