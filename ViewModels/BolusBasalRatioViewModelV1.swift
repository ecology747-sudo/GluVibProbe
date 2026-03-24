//
//  BolusBasalRatioViewModelV1.swift
//  GluVibProbe
//
//  V1: Bolus/Basal Ratio ViewModel (Metabolic)
//  - KEIN Fetch im ViewModel
//  - SSoT: HealthStore.dailyBolusBasalRatio90 (derived in HealthStore)
//  - Basalflow: Auth-Issue kommt aus HealthStore Read-Probe (Insulin Delivery)
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class BolusBasalRatioViewModelV1: ObservableObject {

    // ============================================================
    // MARK: - Info State
    // ============================================================

    enum BolusBasalRatioInfoState { // 🟨 NEW
        case noHistory
        case noTodayData
    }

    // ============================================================
    // MARK: - Published Outputs
    // ============================================================

    @Published var todayRatioInt10: Int = 0
    @Published var last90DaysRatioInt10: [DailyStepsEntry] = []

    @Published var insulinReadAuthIssueV1: Bool = false

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

        healthStore.$dailyBolusBasalRatio90
            .receive(on: DispatchQueue.main)
            .sink { [weak self] daily in
                guard let self else { return }
                self.recompute(from: daily)
            }
            .store(in: &cancellables)

        Publishers.CombineLatest(healthStore.$bolusReadAuthIssueV1, healthStore.$basalReadAuthIssueV1)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] bolusIssue, basalIssue in
                self?.insulinReadAuthIssueV1 = (bolusIssue || basalIssue)
            }
            .store(in: &cancellables)
    }

    private func syncFromStores() {
        recompute(from: healthStore.dailyBolusBasalRatio90)
        insulinReadAuthIssueV1 = (healthStore.bolusReadAuthIssueV1 || healthStore.basalReadAuthIssueV1)
    }

    // ============================================================
    // MARK: - Recompute (UI-nahe Mapping)
    // ============================================================

    private func recompute(from daily: [DailyBolusBasalRatioEntry]) {

        let calendar = Calendar.current

        let mapped: [DailyStepsEntry] = daily
            .map { entry in
                let day = calendar.startOfDay(for: entry.date)
                let int10 = Int((max(0, entry.ratio) * 10.0).rounded())
                return DailyStepsEntry(date: day, steps: max(0, int10))
            }
            .sorted { $0.date < $1.date }

        last90DaysRatioInt10 = mapped
        todayRatioInt10 = Self.extractTodayInt10(from: mapped)
    }

    // ============================================================
    // MARK: - KPI Formatting
    // ============================================================

    var formattedTodayRatio: String {
        guard todayRatioInt10 > 0 else { return "–" }
        return format1(Double(todayRatioInt10) / 10.0)
    }

    // ============================================================
    // MARK: - Goldstandard Hint State
    // ============================================================

    var todayInfoState: BolusBasalRatioInfoState? { // 🟨 NEW

        if insulinReadAuthIssueV1 {
            return .noHistory
        }

        if todayRatioInt10 > 0 { return nil }

        let hasAnyHistory = last90DaysRatioInt10.contains { $0.steps > 0 }

        if !hasAnyHistory {
            return .noHistory
        }

        return .noTodayData
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
            let day = calendar.startOfDay(for: entry.date)
            return day >= startDate && day <= endDate && entry.steps > 0
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
        MetricScaleHelper.scale(
            last90DaysRatioInt10.map { Double($0.steps) },
            for: .ratioInt10
        )
    }

    var periodScale: MetricScaleResult {
        MetricScaleHelper.scale(
            periodAverages.map { Double($0.value) },
            for: .ratioInt10
        )
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
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 1
        return formatter
    }()
}
