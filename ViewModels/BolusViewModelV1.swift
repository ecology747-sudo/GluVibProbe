//
//  BolusViewModelV1.swift
//  GluVibProbe
//
//  V1: Bolus ViewModel (Metabolic)
//  - KEIN Fetch im ViewModel
//  - Single Source of Truth: HealthStore (dailyBolus90)
//  - Period-Averages im ViewModel (UI-nah)
//  - Maximal 90 Tage (kein 180/365)
//  - KPI-Strings inkl. Einheit
//  - Daily/Period Scale: MetricScaleType.insulinUnitsDaily
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class BolusViewModelV1: ObservableObject {

    // ============================================================
    // MARK: - Info State
    // ============================================================

    enum BolusInfoState { // 🟨 NEW
        case noHistory
        case noTodayData
    }

    // ============================================================
    // MARK: - Published Outputs (View-facing)
    // ============================================================

    @Published var todayBolusUnits: Double = 0
    @Published var last90DaysData: [DailyBolusEntry] = []
    @Published var bolusReadAuthIssueV1: Bool = false

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

        healthStore.$bolusReadAuthIssueV1
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.bolusReadAuthIssueV1 = $0
            }
            .store(in: &cancellables)
    }

    private func syncFromStores() {
        last90DaysData = healthStore.dailyBolus90
        todayBolusUnits = Self.extractTodayValue(from: healthStore.dailyBolus90)
        bolusReadAuthIssueV1 = healthStore.bolusReadAuthIssueV1
    }

    // ============================================================
    // MARK: - KPI Formatting (inkl. Einheit)
    // ============================================================

    var formattedTodayBolus: String {
        "\(format1(todayBolusUnits)) \(localizedInsulinUnit(for: todayBolusUnits))"
    }

    // ============================================================
    // MARK: - Goldstandard Hint State
    // ============================================================

    var todayInfoState: BolusInfoState? { // 🟨 NEW
        if todayBolusUnits > 0 { return nil }

        let hasAnyHistory = last90DaysData.contains { $0.bolusUnits > 0 }

        if !hasAnyHistory {
            return .noHistory
        }

        return .noTodayData
    }

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
        MetricScaleHelper.scale(last90DaysData.map { $0.bolusUnits }, for: .insulinUnitsDaily)
    }

    var periodScale: MetricScaleResult {
        MetricScaleHelper.scale(periodAverages.map { Double($0.value) }, for: .insulinUnitsDaily)
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

    private func localizedInsulinUnit(for value: Double) -> String {
        abs(value - 1.0) < 0.0001
            ? L10n.Common.insulinUnitSingular
            : L10n.Common.insulinUnitPlural
    }

    private let numberFormatter1: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 1
        f.minimumFractionDigits = 0
        return f
    }()
}
