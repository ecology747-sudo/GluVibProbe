//
//  BolusBasalRatioViewModelV1.swift
//  GluVibProbe
//
//  V1: Bolus/Basal Ratio ViewModel (Metabolic)
//  - KEIN Fetch im ViewModel
//  - SSoT: HealthStore.dailyBolusBasalRatio90 (derived in HealthStore)
//  - UI-nah: Chart-Adapter (Int*10 via DailyStepsEntry), Period Averages, Formatting
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class BolusBasalRatioViewModelV1: ObservableObject {

    // ============================================================
    // MARK: - Published Outputs
    // ============================================================

    @Published var todayRatioInt10: Int = 0
    @Published var last90DaysRatioInt10: [DailyStepsEntry] = []          // Int*10 im steps-Feld

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

        // !!! NEW: Single SSoT stream (derived daily array)
        healthStore.$dailyBolusBasalRatio90
            .receive(on: DispatchQueue.main)
            .sink { [weak self] daily in
                guard let self else { return }
                self.recompute(from: daily)
            }
            .store(in: &cancellables)
    }

    private func syncFromStores() {
        recompute(from: healthStore.dailyBolusBasalRatio90) // !!! NEW
    }

    // ============================================================
    // MARK: - Recompute (UI-nahe Mapping)
    // ============================================================

    private func recompute(from daily: [DailyBolusBasalRatioEntry]) {

        let calendar = Calendar.current

        let mapped: [DailyStepsEntry] = daily
            .map { e in
                let day = calendar.startOfDay(for: e.date)
                let int10 = Int((max(0, e.ratio) * 10.0).rounded())
                return DailyStepsEntry(date: day, steps: max(0, int10))
            }
            .sorted { $0.date < $1.date }

        self.last90DaysRatioInt10 = mapped
        self.todayRatioInt10 = Self.extractTodayInt10(from: mapped)
    }

    // ============================================================
    // MARK: - KPI Formatting
    // ============================================================

    var formattedTodayRatio: String {
        format1(Double(todayRatioInt10) / 10.0)
    }

    // ============================================================
    // MARK: - Period Averages (≤90) — endet gestern
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
    // MARK: - Scales
    // ============================================================

    var dailyScale: MetricScaleResult {
        MetricScaleHelper.scale(last90DaysRatioInt10.map { Double($0.steps) }, for: .ratioInt10)   // !!! NEW
    }

    var periodScale: MetricScaleResult {
        MetricScaleHelper.scale(periodAverages.map { Double($0.value) }, for: .ratioInt10)         // !!! NEW
    }

    // ============================================================
    // MARK: - Helpers
    // ============================================================

    private static func extractTodayInt10(from daily: [DailyStepsEntry]) -> Int {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        return daily.first(where: { calendar.isDate($0.date, inSameDayAs: todayStart) })?.steps ?? 0
    }

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
