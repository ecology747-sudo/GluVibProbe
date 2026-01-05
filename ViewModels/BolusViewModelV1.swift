//
//  BolusViewModelV1.swift
//  GluVibProbe
//
//  V1: Bolus ViewModel (Metabolic)
//  - KEIN Fetch im ViewModel
//  - Single Source of Truth: HealthStore (dailyBolus90)
//  - Rolling / Period-Averages im ViewModel (UI-nah)
//  - Maximal 90 Tage (kein 180/365)
//  - KPI-Strings inkl. Einheit ("IE")
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class BolusViewModelV1: ObservableObject {

    // ============================================================
    // MARK: - Published Outputs (View-facing)
    // ============================================================

    // KPI
    @Published var todayBolusUnits: Double = 0

    // Chart Data (SSoT: dailyBolus90)
    @Published var last90DaysData: [DailyBolusEntry] = []

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

        healthStore.$dailyBolus90
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.last90DaysData = $0
                self?.todayBolusUnits = Self.extractTodayValue(from: $0)
            }
            .store(in: &cancellables)
    }

    private func syncFromStores() {
        last90DaysData = healthStore.dailyBolus90
        todayBolusUnits = Self.extractTodayValue(from: healthStore.dailyBolus90)
    }

    // ============================================================
    // MARK: - KPI Formatting (inkl. Einheit)
    // ============================================================

    var formattedTodayBolus: String {
        "\(format1(todayBolusUnits)) IE"
    }

    var formattedAvg7dBolus: String {                                        // !!! NEW
        let avg7 = Double(periodAverages.first(where: { $0.days == 7 })?.value ?? 0)
        return "\(format1(avg7)) IE"
    }                                                                         // !!! NEW

    var kpiDeltaText: String {                                                // !!! NEW
        let avg7 = Double(periodAverages.first(where: { $0.days == 7 })?.value ?? 0)
        let diff = todayBolusUnits - avg7

        let sign: String = diff > 0 ? "+" : diff < 0 ? "−" : "±"
        let absValue = abs(diff)

        return "\(sign) \(format1(absValue))"
    }                                                                         // !!! NEW

    var kpiDeltaColor: Color {                                                // !!! NEW
        let avg7 = Double(periodAverages.first(where: { $0.days == 7 })?.value ?? 0)
        let diff = todayBolusUnits - avg7

        if diff > 0 { return .orange }
        if diff < 0 { return .green }
        return Color.Glu.primaryBlue
    }                                                                         // !!! NEW

    // ============================================================
    // MARK: - Period Averages (max 90 Tage)
    // ============================================================

    var periodAverages: [PeriodAverageEntry] {
        [
            .init(label: "7T",  days: 7,  value: averageBolusInt(last: 7)),
            .init(label: "14T", days: 14, value: averageBolusInt(last: 14)),
            .init(label: "30T", days: 30, value: averageBolusInt(last: 30)),
            .init(label: "90T", days: 90, value: averageBolusInt(last: 90))
        ]
    }

    private func averageBolusInt(last days: Int) -> Int {
        guard !last90DaysData.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Durchschnitt über „letzte volle Tage“ (endet gestern) wie im Steps-Flow
        guard
            let endDate = calendar.date(byAdding: .day, value: -1, to: today),
            let startDate = calendar.date(byAdding: .day, value: -days, to: today)
        else { return 0 }

        let filtered = last90DaysData.filter { entry in
            let d = calendar.startOfDay(for: entry.date)
            return d >= startDate && d <= endDate && entry.bolusUnits > 0
        }

        guard !filtered.isEmpty else { return 0 }

        let sum = filtered.reduce(0.0) { $0 + $1.bolusUnits }
        let avg = sum / Double(filtered.count)

        return Int(avg.rounded())
    }

    // ============================================================
    // MARK: - Chart Scales (Helper)
    // ============================================================

    var dailyScale: MetricScaleResult {
        // !!! UPDATED: eigener insulinUnitsDaily-Scale existiert noch nicht → vorerst generisch wie gramsDaily
        MetricScaleHelper.scale(last90DaysData.map { $0.bolusUnits }, for: .gramsDaily)          // !!! UPDATED
    }

    var periodScale: MetricScaleResult {
        MetricScaleHelper.scale(periodAverages.map { Double($0.value) }, for: .gramsDaily)      // !!! UPDATED
    }

    // ============================================================
    // MARK: - Helpers
    // ============================================================

    private static func extractTodayValue(from daily: [DailyBolusEntry]) -> Double {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())

        return daily.first(where: { calendar.isDate($0.date, inSameDayAs: todayStart) })?.bolusUnits ?? 0
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
