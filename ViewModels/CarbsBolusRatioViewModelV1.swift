//
//  CarbsBolusRatioViewModelV1.swift
//  GluVibProbe
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class CarbsBolusRatioViewModelV1: ObservableObject {

    enum CarbsBolusRatioInfoState { // 🟨 NEW
        case noHistory
        case noTodayData
    }

    @Published var todayRatio: Double = 0
    @Published var last90DaysRatioInt10: [DailyStepsEntry] = []

    @Published var bolusReadAuthIssueV1: Bool = false
    @Published var carbsReadAuthIssueV1: Bool = false

    private let healthStore: HealthStore
    private var cancellables = Set<AnyCancellable>()

    init(healthStore: HealthStore = .shared) {
        self.healthStore = healthStore
        bindHealthStore()
        syncFromStores()
    }

    private func bindHealthStore() {

        healthStore.$dailyCarbBolusRatio90
            .receive(on: DispatchQueue.main)
            .sink { [weak self] daily in
                guard let self else { return }
                self.recompute(from: daily)
            }
            .store(in: &cancellables)

        healthStore.$bolusReadAuthIssueV1
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.bolusReadAuthIssueV1 = value
            }
            .store(in: &cancellables)

        healthStore.$carbsReadAuthIssueV1
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.carbsReadAuthIssueV1 = value
            }
            .store(in: &cancellables)
    }

    private func syncFromStores() {
        recompute(from: healthStore.dailyCarbBolusRatio90)
        bolusReadAuthIssueV1 = healthStore.bolusReadAuthIssueV1
        carbsReadAuthIssueV1 = healthStore.carbsReadAuthIssueV1
    }

    private func recompute(from daily: [DailyCarbBolusRatioEntry]) {

        let calendar = Calendar.current

        let mapped: [DailyStepsEntry] = daily
            .map { entry in
                let day = calendar.startOfDay(for: entry.date)
                let int10 = Int((max(0, entry.gramsPerUnit) * 10.0).rounded())
                return DailyStepsEntry(date: day, steps: max(0, int10))
            }
            .sorted { $0.date < $1.date }

        last90DaysRatioInt10 = mapped

        let todayStart = calendar.startOfDay(for: Date())
        let todayInt10 = mapped.first(where: { calendar.isDate($0.date, inSameDayAs: todayStart) })?.steps ?? 0
        todayRatio = Double(todayInt10) / 10.0
    }

    var formattedTodayRatio: String {
        guard todayRatio > 0 else { return "–" }
        return "\(format1(todayRatio)) \(L10n.CarbsBolusRatio.gramsPerUnit)"
    }

    var todayInfoState: CarbsBolusRatioInfoState? { // 🟨 NEW

        if bolusReadAuthIssueV1 || carbsReadAuthIssueV1 {
            return .noHistory
        }

        if todayRatio > 0 { return nil }

        let hasAnyHistory = last90DaysRatioInt10.contains { $0.steps > 0 }
        if !hasAnyHistory {
            return .noHistory
        }

        return .noTodayData
    }

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
        return Int((Double(sum) / Double(filtered.count)).rounded())
    }

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
