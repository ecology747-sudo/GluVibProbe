//
//  TimeInRangeViewModelV1.swift
//  GluVibProbe
//
//  V1: Time In Range (Metabolic)
//  - Scaffold only (noch KEINE Berechnung / keine HealthStore Published Abhängigkeit)
//  - Später: CGM Raw Samples (Minutenwerte) -> DailyStats 90d
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class TimeInRangeViewModelV1: ObservableObject {

    // ============================================================
    // MARK: - Published Outputs (View-facing) — Scaffold
    // ============================================================

    @Published var placeholderText: String = "TIR (V1) — TODO"

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
