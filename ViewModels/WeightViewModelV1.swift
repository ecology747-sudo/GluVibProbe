//
//  WeightViewModelV1.swift
//  GluVibProbe
//
//  V1: Weight ViewModel
//  - SSoT: HealthStore
//  - Weight is Double (kg)
//  - Targets aus SettingsModel (Display/Goal only)
//  - KEIN Fetch im ViewModel (Views trigger refresh via HealthStore/Bootstrap)
//
//

import Foundation
import Combine
import SwiftUI

// ============================================================
// MARK: - Local Double Chart Entry (V1)
// ============================================================

struct DailyDoubleEntry: Identifiable, Equatable {
    var id: Date { date }                       // !!! UPDATED (stable id; no UUID churn)
    let date: Date
    let value: Double
}

@MainActor
final class WeightViewModelV1: ObservableObject {

    // ============================================================
    // MARK: - Published Outputs
    // ============================================================

    @Published var todayWeightKg: Double = 0
    @Published var targetWeightKg: Double = 0                        // !!! UPDATED (Settings -> Double)
    @Published var weightDaily365Raw: [DailyWeightEntry] = []

    // Chart-ready series (Double) — DISPLAY UNIT values (kg/lbs)      // !!! UPDATED
    @Published var last90DaysForChart: [DailyDoubleEntry] = []        // !!! UPDATED
    @Published var monthlyForChart: [MonthlyMetricEntry] = []         // (unchanged; depends on your existing pipeline)

    // Period averages — DISPLAY UNIT values (rounded Int)             // !!! UPDATED
    @Published var periodAverages: [PeriodAverageEntry] = []          // !!! UPDATED

    // Scaling — based on DISPLAY UNIT values                           // !!! UPDATED
    @Published var dailyScale: MetricScaleResult = MetricScaleHelper.scale([0], for: .weightKg)
    @Published var periodScale: MetricScaleResult = MetricScaleHelper.scale([0], for: .weightKg)
    @Published var monthlyScale: MetricScaleResult = MetricScaleHelper.scale([0], for: .weightKg)

    // KPI strings (unit in KPI)
    @Published var currentText: String = "–"
    @Published var targetText: String = "–"
    @Published var deltaText: String = "–"
    @Published var deltaColor: Color = Color.Glu.primaryBlue

    // ============================================================
    // MARK: - Dependencies
    // ============================================================

    private let healthStore: HealthStore
    private let settings: SettingsModel
    private var cancellables = Set<AnyCancellable>()

    // ============================================================
    // MARK: - Init
    // ============================================================

    init(
        healthStore: HealthStore = .shared,
        settings: SettingsModel = .shared
    ) {
        self.healthStore = healthStore
        self.settings = settings

        bind()
        syncInitial()
    }

    // ============================================================
    // MARK: - Bindings (trigger remap only)
    // ============================================================

    private func bind() {

        // ✅ Weight today (Double)
        healthStore.$todayWeightKgRaw
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.remap()
            }
            .store(in: &cancellables)

        // ✅ 365 raw series (measured days only)
        healthStore.$weightDaily365Raw
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.remap()
            }
            .store(in: &cancellables)

        // ✅ Target from SettingsModel (Steps-Pattern: Settings -> VM mirror)
        settings.$targetWeightKg
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.remap()
            }
            .store(in: &cancellables)

        // ✅ Display Unit preference — must remap chart values + scales
        settings.$weightUnit                                           // !!! UPDATED
            .receive(on: DispatchQueue.main)                           // !!! UPDATED
            .sink { [weak self] _ in                                   // !!! UPDATED
                self?.remap()                                          // !!! UPDATED
            }                                                          // !!! UPDATED
            .store(in: &cancellables)                                  // !!! UPDATED
    }

    private func syncInitial() {
        remap()
    }

    // ============================================================
    // MARK: - Core Mapping
    // ============================================================

    private func remap() {

        let unit = settings.weightUnit                                 // !!! UPDATED

        // 1) Pull from SSoT (BASE = kg)
        todayWeightKg = max(0, healthStore.todayWeightKgRaw)
        weightDaily365Raw = healthStore.weightDaily365Raw

        // !!! UPDATED: Fallback -> latest measured weight if todayWeightKgRaw not ready yet
        if todayWeightKg <= 0, let latest = weightDaily365Raw.last(where: { $0.kg > 0 })?.kg {
            todayWeightKg = max(0, latest)
        }

        // ✅ Steps-Pattern: Target from Settings (Int -> Double, BASE = kg)
        targetWeightKg = max(0, Double(settings.targetWeightKg))

        // 2) Build last 90 days chart series (DISPLAY UNIT values)
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let start90 = calendar.date(byAdding: .day, value: -89, to: todayStart) ?? todayStart

        let last90Raw = weightDaily365Raw
            .filter { $0.date >= start90 && $0.date <= todayStart }
            .sorted { $0.date < $1.date }

        last90DaysForChart = last90Raw.map { entry in                   // !!! UPDATED
            DailyDoubleEntry(
                date: entry.date,
                value: max(0, unit.convertedValue(fromKg: entry.kg))    // !!! UPDATED (DISPLAY)
            )
        }

        // 3) Period averages (compute in kg, store DISPLAY UNIT Int)    // !!! UPDATED
        periodAverages = makePeriodAverages(from: weightDaily365Raw, unit: unit) // !!! UPDATED

        // 4) Scaling (use helper output, but feed DISPLAY values)       // !!! UPDATED
        dailyScale = MetricScaleHelper.scale(last90DaysForChart.map { $0.value }, for: .weightKg) // !!! UPDATED
        periodScale = MetricScaleHelper.scale(periodAverages.map { Double($0.value) }, for: .weightKg) // !!! UPDATED
        monthlyScale = MetricScaleHelper.scale(monthlyForChart.map { Double($0.value) }, for: .weightKg)

        // 5) KPI strings (DISPLAY via Settings.weightUnit)
        currentText = formatWeightDisplay(fromKg: todayWeightKg)
        targetText = formatWeightDisplay(fromKg: targetWeightKg)

        let deltaKg = todayWeightKg - targetWeightKg
        deltaText = formatDeltaDisplay(fromKgDelta: deltaKg)
        deltaColor = deltaKg == 0 ? Color.Glu.primaryBlue : (deltaKg < 0 ? .green : .red)
    }

    // ============================================================
    // MARK: - Helpers
    // ============================================================

    private func makePeriodAverages(                                     // !!! UPDATED
        from entries: [DailyWeightEntry],
        unit: WeightUnit
    ) -> [PeriodAverageEntry] {

        // NOTE: PeriodAverageEntry.value is Int in your project.
        // We compute avg in kg (Double) and convert for DISPLAY at the end.

        func avgKg(lastDays days: Int) -> Double {                        // !!! UPDATED
            let calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: Date())
            guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) else { return 0 }

            let slice = entries
                .filter { $0.date >= start && $0.date <= todayStart && $0.kg > 0 }

            guard !slice.isEmpty else { return 0 }

            let sum = slice.reduce(0.0) { $0 + $1.kg }
            return sum / Double(slice.count)
        }

        func displayRoundedInt(fromKg kg: Double) -> Int {                // !!! UPDATED
            let display = unit.convertedValue(fromKg: kg)                 // !!! UPDATED
            return Int(round(display))                                    // !!! UPDATED
        }

        return [
            .init(label: "7T",   days: 7,   value: displayRoundedInt(fromKg: avgKg(lastDays: 7))),   // !!! UPDATED
            .init(label: "14T",  days: 14,  value: displayRoundedInt(fromKg: avgKg(lastDays: 14))),  // !!! UPDATED
            .init(label: "30T",  days: 30,  value: displayRoundedInt(fromKg: avgKg(lastDays: 30))),  // !!! UPDATED
            .init(label: "90T",  days: 90,  value: displayRoundedInt(fromKg: avgKg(lastDays: 90))),  // !!! UPDATED
            .init(label: "180T", days: 180, value: displayRoundedInt(fromKg: avgKg(lastDays: 180))), // !!! UPDATED
            .init(label: "365T", days: 365, value: displayRoundedInt(fromKg: avgKg(lastDays: 365)))  // !!! UPDATED
        ]
    }

    private func formatWeightDisplay(fromKg kg: Double) -> String {
        guard kg > 0 else { return "–" }
        return settings.weightUnit.formatted(fromKg: kg, fractionDigits: 1)
    }

    private func formatDeltaDisplay(fromKgDelta deltaKg: Double) -> String {
        let unit = settings.weightUnit

        if deltaKg == 0 {
            return "±\(unit.formattedNumber(fromKg: 0, fractionDigits: 1)) \(unit.label)"
        }

        let sign = deltaKg > 0 ? "+" : "−"
        let absString = unit.formattedNumber(fromKg: abs(deltaKg), fractionDigits: 1)
        return "\(sign)\(absString) \(unit.label)"
    }
}
