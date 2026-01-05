//
//  BasalViewModelV1.swift
//  GluVibProbe
//
//  V1: Basal ViewModel (Metabolic)
//  - KEIN Fetch im ViewModel
//  - Single Source of Truth: HealthStore (dailyBasal90)
//  - Period-Averages im ViewModel (UI-nah)
//  - Maximal 90 Tage (kein 180/365)
//  - KPI-Strings inkl. Einheit ("IE")
//  - Daily/Period Scale: MetricScaleType.insulinUnitsDaily
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class BasalViewModelV1: ObservableObject {

    // ============================================================
    // MARK: - Published Outputs (View-facing)
    // ============================================================

    // KPI
    @Published var todayBasalUnits: Double = 0

    // Chart Data (SSoT: dailyBasal90)
    @Published var last90DaysData: [DailyBasalEntry] = []

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
        bindHealthStore()
        syncFromStores()
    }

    // ============================================================
    // MARK: - Bindings (SSoT → ViewModel)
    // ============================================================

    private func bindHealthStore() {
        healthStore.$dailyBasal90
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.last90DaysData = $0
                self?.todayBasalUnits = Self.extractTodayValue(from: $0)
            }
            .store(in: &cancellables)
    }

    private func syncFromStores() {
        last90DaysData = healthStore.dailyBasal90
        todayBasalUnits = Self.extractTodayValue(from: healthStore.dailyBasal90)
    }

    // ============================================================
    // MARK: - KPI Formatting (inkl. Einheit)
    // ============================================================

    var formattedTodayBasal: String {
        "\(format1(todayBasalUnits)) IE"
    }

    // ============================================================
    // MARK: - Period Averages (max 90 Tage)
    // ============================================================

    var periodAverages: [PeriodAverageEntry] {
        [
            .init(label: "7T",  days: 7,  value: averageBasalInt(last: 7)),
            .init(label: "14T", days: 14, value: averageBasalInt(last: 14)),
            .init(label: "30T", days: 30, value: averageBasalInt(last: 30)),
            .init(label: "90T", days: 90, value: averageBasalInt(last: 90))
        ]
    }

    private func averageBasalInt(last days: Int) -> Int {
        guard !last90DaysData.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Durchschnitt über „letzte volle Tage“ (endet gestern) wie im Steps/Bolus-Flow
        guard
            let endDate = calendar.date(byAdding: .day, value: -1, to: today),
            let startDate = calendar.date(byAdding: .day, value: -days, to: today)
        else { return 0 }

        let filtered = last90DaysData.filter { entry in
            let d = calendar.startOfDay(for: entry.date)
            return d >= startDate && d <= endDate && entry.basalUnits > 0
        }

        guard !filtered.isEmpty else { return 0 }

        let sum = filtered.reduce(0.0) { $0 + $1.basalUnits }
        let avg = sum / Double(filtered.count)

        return Int(avg.rounded())
    }

    // ============================================================
    // MARK: - Chart Scales (Helper)
    // ============================================================

    var dailyScale: MetricScaleResult {
        MetricScaleHelper.scale(last90DaysData.map { $0.basalUnits }, for: .insulinUnitsDaily)
    }

    var periodScale: MetricScaleResult {
        MetricScaleHelper.scale(periodAverages.map { Double($0.value) }, for: .insulinUnitsDaily)
    }

    // ============================================================
    // MARK: - Helpers
    // ============================================================

    private static func extractTodayValue(from daily: [DailyBasalEntry]) -> Double {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        return daily.first(where: { calendar.isDate($0.date, inSameDayAs: todayStart) })?.basalUnits ?? 0
    }

    private func format1(_ value: Double) -> String {
        numberFormatter1.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private let numberFormatter1: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 1
        f.minimumFractionDigits = 0
        return f
    }()
}
