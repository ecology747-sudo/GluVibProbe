//
//  MetabolicReportCoordinatorV1.swift
//  GluVibProbe
//
//  GluVib Report (V1) — On-Demand Coordinator (Premium)
//
//  Zweck:
//  - On-demand Pipeline für Report-Daten (teure CGM Aggregation) außerhalb von Bootstrap
//  - Keine dauerhaften Published Checklist-Properties im HealthStore
//  - Wird nur gestartet, wenn die Report-Vorschau geöffnet wird
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class MetabolicReportCoordinatorV1: ObservableObject {

    @Published private(set) var isLoading: Bool = false
    @Published private(set) var loadErrorMessage: String? = nil

    @Published private(set) var glucoseProfile: ReportGlucoseProfileV1? = nil

    private let healthStore: HealthStore

    private var lastWindowDays: Int? = nil
    private var lastBuiltAt: Date? = nil

    init(healthStore: HealthStore = .shared) {
        self.healthStore = healthStore
    }

    func loadGlucosePercentileProfile(
        windowDays: Int,
        forceReload: Bool = false
    ) async {

        loadErrorMessage = nil

        if !forceReload,
           let cached = glucoseProfile,
           lastWindowDays == windowDays,
           cached.days == windowDays {
            return
        }

        isLoading = true
        defer { isLoading = false }

        let profile = await healthStore.buildReportGlucoseProfileV1(days: windowDays)

        let hasAnyData = profile.points.contains(where: { $0.sampleCount > 0 })

        if hasAnyData {
            self.glucoseProfile = profile
            self.lastWindowDays = windowDays
            self.lastBuiltAt = Date()
        } else {
            self.glucoseProfile = nil
            self.loadErrorMessage = "No glucose data available for the selected period."
        }
    }

    var debugStatusLine: String {
        if let p = glucoseProfile {
            let valid = p.points.filter { $0.sampleCount > 0 }.count
            let total = p.points.count
            let pct = Double(valid) / Double(max(1, total)) * 100.0
            return "Loaded \(p.days)d: \(valid)/\(total) slots (\(Int(pct))%)."
        }
        if isLoading { return "Loading…" }
        if let msg = loadErrorMessage { return msg }
        return "Idle."
    }
}
