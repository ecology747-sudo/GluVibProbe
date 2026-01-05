//
//  CarbsBolusRatioViewModelV1.swift
//  GluVibProbe
//
//  V1: Carbs/Bolus Ratio ViewModel (Metabolic)
//  - KEIN Fetch im ViewModel
//  - SSoT: HealthStore (last90DaysCarbs + dailyBolus90)
//  - Max 90 Tage
//  - Ratio = grams / IU  -> 1 Dezimalstelle (stored for charts as Int*10)
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
    @Published var last90DaysRatio: [DailyRatioEntry] = []

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
        bindStores()
        syncFromStores()
    }

    // ============================================================
    // MARK: - Bindings
    // ============================================================

    private func bindStores() {

        Publishers.CombineLatest(healthStore.$last90DaysCarbs, healthStore.$dailyBolus90)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] carbs, bolus in
                guard let self else { return }
                self.recompute(carbs: carbs, bolus: bolus)
            }
            .store(in: &cancellables)
    }

    private func syncFromStores() {
        recompute(carbs: healthStore.last90DaysCarbs, bolus: healthStore.dailyBolus90)
    }

    private func recompute(carbs: [DailyCarbsEntry], bolus: [DailyBolusEntry]) {

        let calendar = Calendar.current

        // Map per day
        var carbsByDay: [Date: Double] = [:]
        for c in carbs {
            let d = calendar.startOfDay(for: c.date)
            carbsByDay[d] = Double(max(0, c.grams))
        }

        var bolusByDay: [Date: Double] = [:]
        for b in bolus {
            let d = calendar.startOfDay(for: b.date)
            bolusByDay[d] = max(0, b.bolusUnits)
        }

        // Build ratio series over intersection (≤ 90d)
        let allDays = Set(carbsByDay.keys).union(bolusByDay.keys)
        let sortedDays = allDays.sorted()

        let series: [DailyRatioEntry] = sortedDays.map { day in
            let g = carbsByDay[day] ?? 0
            let iu = bolusByDay[day] ?? 0
            let ratio = (iu > 0) ? (g / iu) : 0
            return DailyRatioEntry(date: day, ratio: ratio)
        }

        self.last90DaysRatio = series

        // Today KPI
        let todayStart = calendar.startOfDay(for: Date())
        self.todayRatio = series.first(where: { calendar.isDate($0.date, inSameDayAs: todayStart) })?.ratio ?? 0
    }

    // ============================================================
    // MARK: - KPI Formatting
    // ============================================================

    var formattedTodayRatio: String {
        format1(todayRatio)
    }

    // ============================================================
    // MARK: - Period Averages (≤ 90d) — wie Steps-Flow (endet gestern)
    // ============================================================

    var periodAverages: [PeriodAverageEntry] {
        [
            .init(label: "7T",  days: 7,  value: averageRatioInt10(last: 7)),
            .init(label: "14T", days: 14, value: averageRatioInt10(last: 14)),
            .init(label: "30T", days: 30, value: averageRatioInt10(last: 30)),
            .init(label: "90T", days: 90, value: averageRatioInt10(last: 90))
        ]
    }

    private func averageRatioInt10(last days: Int) -> Int {
        guard !last90DaysRatio.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard
            let endDate = calendar.date(byAdding: .day, value: -1, to: today),
            let startDate = calendar.date(byAdding: .day, value: -days, to: today)
        else { return 0 }

        let filtered = last90DaysRatio.filter { entry in
            let d = calendar.startOfDay(for: entry.date)
            return d >= startDate && d <= endDate && entry.ratio > 0
        }

        guard !filtered.isEmpty else { return 0 }

        let sum = filtered.reduce(0.0) { $0 + $1.ratio }
        let avg = sum / Double(filtered.count)

        return Int((avg * 10).rounded())
    }

    // ============================================================
    // MARK: - Scales (Int*10 Domain)
    // ============================================================

    var dailyScale: MetricScaleResult {
        MetricScaleHelper.scale(last90DaysRatio.map { $0.ratio * 10.0 }, for: .ratioInt10)   // !!! NEW
    }

    var periodScale: MetricScaleResult {
        MetricScaleHelper.scale(periodAverages.map { Double($0.value) }, for: .ratioInt10)   // !!! NEW
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

// ============================================================
// MARK: - Model
// ============================================================

struct DailyRatioEntry: Identifiable {
    let id = UUID()
    let date: Date
    let ratio: Double
}
