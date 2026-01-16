//
//  CarbsBolusRatioViewModelV1.swift
//  GluVibProbe
//
//  V1: Carbs/Bolus Ratio ViewModel (Metabolic)
//  - KEIN Fetch im ViewModel
//  - SSoT: HealthStore.dailyCarbBolusRatio90 (derived in HealthStore)
//  - UI-nah: Period Averages + Formatting + Chart-Adapter (Int*10 via DailyStepsEntry)
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class CarbsBolusRatioViewModelV1: ObservableObject {

    // ============================================================
    // MARK: - Published Outputs (View-facing)
    // ============================================================

    @Published var todayRatio: Double = 0

    /// Chart Adapter: ratio (Double) -> Int*10 im `steps` Feld
    @Published var last90DaysRatioInt10: [DailyStepsEntry] = []

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

        // !!! NEW: single SSoT stream (derived in HealthStore)
        healthStore.$dailyCarbBolusRatio90
            .receive(on: DispatchQueue.main)
            .sink { [weak self] daily in
                guard let self else { return }
                self.recompute(from: daily)
            }
            .store(in: &cancellables)
    }

    private func syncFromStores() {
        recompute(from: healthStore.dailyCarbBolusRatio90) // !!! NEW
    }

    // ============================================================
    // MARK: - Recompute (UI-nahe Mapping)
    // ============================================================

    private func recompute(from daily: [DailyCarbBolusRatioEntry]) {

        let calendar = Calendar.current

        // Map to chart-friendly series (Int*10)
        let mapped: [DailyStepsEntry] = daily
            .map { e in
                let day = calendar.startOfDay(for: e.date)
                let int10 = Int((max(0, e.gramsPerUnit) * 10.0).rounded())
                return DailyStepsEntry(date: day, steps: max(0, int10))
            }
            .sorted { $0.date < $1.date }

        self.last90DaysRatioInt10 = mapped

        // Today KPI (Double)
        let todayStart = calendar.startOfDay(for: Date())
        let todayInt10 = mapped.first(where: { calendar.isDate($0.date, inSameDayAs: todayStart) })?.steps ?? 0
        self.todayRatio = Double(todayInt10) / 10.0
    }

    // ============================================================
    // MARK: - KPI Formatting
    // ============================================================

    var formattedTodayRatio: String {
        "\(format1(todayRatio)) g/U"
    }

    // ============================================================
    // MARK: - Period Averages (≤ 90d) — endet gestern
    // ============================================================

    var periodAverages: [PeriodAverageEntry] {
        [
            .init(label: "7T",  days: 7,  value: averageInt10(last: 7)),
            .init(label: "14T", days: 14, value: averageInt10(last: 14)),
            .init(label: "30T", days: 30, value: averageInt10(last: 30)),
            .init(label: "90T", days: 90, value: averageInt10(last: 90))
        ]
    }

    private func averageInt10(last days: Int) -> Int {
        guard !last90DaysRatioInt10.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard
            let endDate = calendar.date(byAdding: .day, value: -1, to: today),
            let startDate = calendar.date(byAdding: .day, value: -days, to: today)
        else { return 0 }

        let filtered = last90DaysRatioInt10.filter { entry in
            let d = calendar.startOfDay(for: entry.date)
            return d >= startDate && d <= endDate && entry.steps > 0
        }

        guard !filtered.isEmpty else { return 0 }

        let sum = filtered.reduce(0) { $0 + $1.steps }
        let avg = Double(sum) / Double(filtered.count)

        return Int(avg.rounded())
    }

    // ============================================================
    // MARK: - Scales (Int*10 Domain)
    // ============================================================

    var dailyScale: MetricScaleResult {
        MetricScaleHelper.scale(last90DaysRatioInt10.map { Double($0.steps) }, for: .ratioInt10)   // !!! NEW
    }

    var periodScale: MetricScaleResult {
        MetricScaleHelper.scale(periodAverages.map { Double($0.value) }, for: .ratioInt10)         // !!! NEW
    }

    // ============================================================
    // MARK: - Formatting Helpers
    // ============================================================

    private func format1(_ value: Double) -> String {
        numberFormatter1.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private let numberFormatter1: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 1
        f.minimumFractionDigits = 1
        return f
    }()
}
