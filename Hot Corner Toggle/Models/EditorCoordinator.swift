//
//  EditorCoordinator.swift
//  Hot Corner Toggle
//
//  Created by Nguyen Minh Thai on 30/6/26.
//

import SwiftUI
import Combine

@MainActor
final class EditorCoordinator: ObservableObject {
    @Published var editingPreset: HotCornerPreset?
    @Published var editingRule: AppPresetRule?

    func newPreset() { editingPreset = nil }
    func editPreset(_ preset: HotCornerPreset) { editingPreset = preset }

    func newRule() { editingRule = nil }
    func editRule(_ rule: AppPresetRule) { editingRule = rule }
}
