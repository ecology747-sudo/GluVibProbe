//
//  GMIViewModelV1.swift
//  GluVibProbe
//
//  V1: GMI (Metabolic)
//  - Scaffold only (noch KEINE Berechnung / keine HealthStore Published Abhängigkeit)
//  - Später: Mean Glucose (z.B. rolling 14d) -> GMI Formel
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class GMIViewModelV1: ObservableObject {

    // ============================================================
    // MARK: - Published Outputs (View-facing) — Scaffold
    // ============================================================

    @Published var placeholderText: String = "GMI (V1) — TODO"

    // ============================================================
    // MARK: - Dependencies
    // ============================================================

    private let healthStore: HealthStore
    private var cancellables = Set<AnyCancellable>()

    // ============================================================
    // MARK: - Init
    // ============================================================

    init(healthStore: HealthStore = .shared) {
        self.healthStore = healthStore
    }
}
