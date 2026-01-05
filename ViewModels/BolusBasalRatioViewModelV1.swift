//
//  BolusBasalRatioViewModelV1.swift
//  GluVibProbe
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
    // MARK: - Bindings
    // ============================================================

    private func bindHealthStore() {

        Publishers.CombineLatest(healthStore.$dailyBolus90, healthStore.$dailyBasal90)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] bolus, basal in
                guard let self else { return }
                let mapped = Self.buildDailyRatioInt10(bolus: bolus, basal: basal)
                self.last90DaysRatioInt10 = mapped
                self.todayRatioInt10 = Self.extractTodayInt10(from: mapped)
            }
            .store(in: &cancellables)
    }

    private func syncFromStores() {
        let mapped = Self.buildDailyRatioInt10(bolus: healthStore.dailyBolus90, basal: healthStore.dailyBasal90)
        last90DaysRatioInt10 = mapped
        todayRatioInt10 = Self.extractTodayInt10(from: mapped)
    }

    // ============================================================
    // MARK: - KPI Formatting
    // ============================================================

    var formattedTodayRatio: String {
        format1(Double(todayRatioInt10) / 10.0)
    }

    // ============================================================
    // MARK: - Period Averages (≤90)
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
        MetricScaleHelper.scale(last90DaysRatioInt10.map { Double($0.steps) }, for: .ratioInt10)   // !!! IMPORTANT
    }

    var periodScale: MetricScaleResult {
        MetricScaleHelper.scale(periodAverages.map { Double($0.value) }, for: .ratioInt10)         // !!! IMPORTANT
    }

    // ============================================================
    // MARK: - Builders
    // ============================================================

    private static func buildDailyRatioInt10(
        bolus: [DailyBolusEntry],
        basal: [DailyBasalEntry]
    ) -> [DailyStepsEntry] {

        let calendar = Calendar.current

        // Basal lookup by day
        let basalByDay: [Date: Double] = Dictionary(
            uniqueKeysWithValues: basal.map { (calendar.startOfDay(for: $0.date), $0.basalUnits) }
        )

        // Map over bolus days (90d) and compute ratio per day
        let mapped: [DailyStepsEntry] = bolus.map { b in
            let day = calendar.startOfDay(for: b.date)
            let basalUnits = basalByDay[day] ?? 0

            let ratio: Double = (basalUnits > 0) ? (b.bolusUnits / basalUnits) : 0
            let int10 = Int((ratio * 10.0).rounded())

            return DailyStepsEntry(date: day, steps: max(0, int10))
        }
        .sorted { $0.date < $1.date }

        return mapped
    }

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
