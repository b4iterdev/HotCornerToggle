//
//  PresetApplier.swift
//  Hot Corner Toggle
//
//  Created by Nguyen Minh Thai on 30/6/26.
//

import Foundation
import Combine

/// Orchestrates the manual Hot Corner toggle and automatic app-rule presets.
///
/// State model:
/// - `baseline`: the user's manual corner state when no app rule is active.
/// - `focusOverride`: the preset of the currently frontmost app's rule (if any).
///   At most one; focus always wins over running rules.
/// - `runningOverrides`: presets of apps whose `whenRunning` rule is active
///   (launched but not yet terminated). Most recent wins.
///
/// Effective corners =
///   `focusOverride` ?? `runningOverrides.last` ?? (manual enabled ? `baseline` : `.disabled`)
///
/// Auto-revert: when an override clears, the snapshot captured *before* that
/// override was applied is restored — so toggling back returns to exactly the
/// corners that were showing beforehand.
@MainActor
final class PresetApplier: ObservableObject {

    /// Whether the user's manual Hot Corners are enabled (not overridden).
    @Published private(set) var isHotCornersEnabled: Bool = true

    /// The display name of the app whose rule is currently overriding, if any.
    @Published private(set) var activeOverrideApp: String?

    /// The trigger of the currently active override, if any.
    @Published private(set) var activeOverrideTrigger: TriggerType?

    private struct Override {
        let rule: AppPresetRule
        let preset: HotCornerPreset
        let savedPrevious: HotCornerSnapshot
    }

    private var focusOverride: Override?
    private var runningOverrides: [Override] = []
    private var baseline: HotCornerSnapshot = .disabled
    private var cancellables = Set<AnyCancellable>()

    private let service: HotCornerService
    private let store: PresetStore
    private let monitor: AppMonitor

    init(store: PresetStore,
         monitor: AppMonitor,
         service: HotCornerService = .shared) {
        self.store = store
        self.monitor = monitor
        self.service = service

        // Capture the real current system state as the baseline.
        self.baseline = service.readSnapshot()
        self.isHotCornersEnabled = !baseline.configs.allSatisfy { $0.action == .off }

        monitor.start()
        wireEvents()
    }

    // MARK: - Manual actions

    func applyPreset(_ preset: HotCornerPreset) {
        baseline = preset.snapshot
        isHotCornersEnabled = true
        reapplyEffective()
    }

    func toggleHotCorners() {
        if isHotCornersEnabled {
            if focusOverride == nil && runningOverrides.isEmpty {
                baseline = service.readSnapshot()
            }
            isHotCornersEnabled = false
        } else {
            isHotCornersEnabled = true
        }
        reapplyEffective()
    }

    // MARK: - Event wiring

    private func wireEvents() {
        monitor.eventSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self else { return }
                self.handle(event)
            }
            .store(in: &cancellables)
    }

    private func handle(_ event: AppMonitor.AppEvent) {
        switch event {
        case .activated(let bid, _):
            activateFocusRule(forBundleId: bid)
        case .deactivated(let bid):
            deactivateFocusRule(forBundleId: bid)
        case .launched(let bid, _):
            activateRunningRule(forBundleId: bid)
        case .terminated(let bid):
            deactivateRunningRule(forBundleId: bid)
        }
    }

    // MARK: - Effective state

    /// The snapshot that should currently be applied given overrides + manual state.
    private func effectiveSnapshot() -> HotCornerSnapshot {
        if let focus = focusOverride {
            return focus.preset.snapshot
        }
        if let last = runningOverrides.last {
            return last.preset.snapshot
        }
        return isHotCornersEnabled ? baseline : .disabled
    }

    private func reapplyEffective() {
        service.apply(effectiveSnapshot())
        if let focus = focusOverride {
            activeOverrideApp = focus.rule.appName
            activeOverrideTrigger = focus.rule.triggerType
        } else if let last = runningOverrides.last {
            activeOverrideApp = last.rule.appName
            activeOverrideTrigger = last.rule.triggerType
        } else {
            activeOverrideApp = nil
            activeOverrideTrigger = nil
        }
    }

    // MARK: - Focus-triggered overrides

    private func activateFocusRule(forBundleId bid: String) {
        let rules = store.rules(forBundleId: bid).filter { $0.triggerType == .whenFocused }
        guard let rule = rules.first,
              let preset = store.preset(with: rule.presetID) else {
            // No focus rule for this app: if a focus override from another app
            // is still active, clear it (frontmost changed away).
            if focusOverride != nil { clearFocusOverride() }
            return
        }

        // Replacing an existing focus override: restore its saved-previous
        // becomes the new saved-previous for the incoming one.
        let saved = service.readSnapshot()
        focusOverride = Override(rule: rule, preset: preset, savedPrevious: saved)
        reapplyEffective()
    }

    private func deactivateFocusRule(forBundleId bid: String) {
        guard focusOverride?.rule.appBundleIdentifier == bid else { return }
        clearFocusOverride()
    }

    private func clearFocusOverride() {
        guard let override = focusOverride else { return }
        focusOverride = nil
        // Revert to whatever was showing before focus took over. If a running
        // override is active that equals the saved state, re-apply it; otherwise
        // restore the literal saved snapshot.
        if runningOverrides.last != nil {
            reapplyEffective()
        } else {
            service.apply(override.savedPrevious)
            activeOverrideApp = nil
            activeOverrideTrigger = nil
        }
    }

    // MARK: - Running-triggered overrides

    private func activateRunningRule(forBundleId bid: String) {
        let rules = store.rules(forBundleId: bid).filter { $0.triggerType == .whenRunning }
        guard let rule = rules.first,
              let preset = store.preset(with: rule.presetID) else { return }

        let saved = service.readSnapshot()
        runningOverrides.append(Override(rule: rule, preset: preset, savedPrevious: saved))
        // Running rules only visibly apply when no focus override is active.
        if focusOverride == nil {
            reapplyEffective()
        }
    }

    private func deactivateRunningRule(forBundleId bid: String) {
        guard let removed = runningOverrides.last(where: { $0.rule.appBundleIdentifier == bid }) else { return }
        runningOverrides.removeAll { $0.rule.appBundleIdentifier == bid }

        if focusOverride == nil {
            if runningOverrides.last != nil {
                reapplyEffective()
            } else {
                // Restore the snapshot captured before this rule was applied.
                service.apply(removed.savedPrevious)
                activeOverrideApp = nil
                activeOverrideTrigger = nil
            }
        }
    }
}
