//
//  ActivityEnergyViewModelV1.swift
//  GluVibProbe
//

import Foundation
import Combine

@MainActor
final class ActivityEnergyViewModelV1: ObservableObject {

    enum ActivityEnergyInfoState {
        case noHistory // 🟨 UPDATED
        case noTodayData
    }

    // MARK: - Dependencies (SSoT)

    private let healthStore: HealthStore
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Published (Adapter-API für View/Card)

    @Published private(set) var formattedTodayActiveEnergy: String = "–"
    @Published private(set) var last90DaysChartData: [DailyStepsEntry] = []
    @Published private(set) var periodAverages: [PeriodAverageEntry] = []
    @Published private(set) var monthlyData: [MonthlyMetricEntry] = []

    @Published private(set) var dailyScale: MetricScaleHelper.MetricScaleResult
    @Published private(set) var periodScale: MetricScaleHelper.MetricScaleResult
    @Published private(set) var monthlyScale: MetricScaleHelper.MetricScaleResult

    @Published private(set) var activeEnergyReadAuthIssueV1: Bool = false

    // MARK: - Internal 365 Adapter (für Period Averages)

    private var dailyEnergy365Adapter: [DailyStepsEntry] = []

    // MARK: - Internal (for Hint logic)

    private var todayActiveEnergyInt: Int = 0

    // MARK: - Init

    init(healthStore: HealthStore) {
        self.healthStore = healthStore

        let fallback = MetricScaleHelper.scale([0], for: .energyDaily)
        self.dailyScale = fallback
        self.periodScale = fallback
        self.monthlyScale = fallback

        bind()
        syncFromStores()
    }

    // MARK: - Bindings (SSoT → VM)

    private func bind() {

        Publishers.CombineLatest4(
            healthStore.$todayActiveEnergy,
            healthStore.$last90DaysActiveEnergy,
            healthStore.$monthlyActiveEnergy,
            healthStore.$activeEnergyDaily365
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] todayInt, last90Entries, monthlyEntries, daily365Entries in
            guard let self else { return }

            self.todayActiveEnergyInt = max(0, todayInt)

            self.formattedTodayActiveEnergy = self.formatKcal(todayInt)

            self.last90DaysChartData = last90Entries.map {
                DailyStepsEntry(date: $0.date, steps: max(0, $0.activeEnergy))
            }

            self.dailyEnergy365Adapter = daily365Entries.map {
                DailyStepsEntry(date: $0.date, steps: max(0, $0.activeEnergy))
            }

            self.monthlyData = monthlyEntries

            self.periodAverages = self.makePeriodAverages()

            let dailyValues = self.last90DaysChartData.map { Double($0.steps) }
            self.dailyScale = MetricScaleHelper.scale(dailyValues.isEmpty ? [0] : dailyValues, for: .energyDaily)

            let periodValues = self.periodAverages.map { Double($0.value) }
            self.periodScale = MetricScaleHelper.scale(periodValues.isEmpty ? [0] : periodValues, for: .energyDaily)

            let monthlyValues = self.monthlyData.map { Double($0.value) }
            self.monthlyScale = MetricScaleHelper.scale(monthlyValues.isEmpty ? [0] : monthlyValues, for: .energyMonthly)
        }
        .store(in: &cancellables)

        healthStore.$activeEnergyReadAuthIssueV1
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.activeEnergyReadAuthIssueV1 = $0 }
            .store(in: &cancellables)
    }

    private func syncFromStores() {

        todayActiveEnergyInt = max(0, healthStore.todayActiveEnergy)
        formattedTodayActiveEnergy = formatKcal(healthStore.todayActiveEnergy)

        last90DaysChartData = healthStore.last90DaysActiveEnergy.map {
            DailyStepsEntry(date: $0.date, steps: max(0, $0.activeEnergy))
        }

        dailyEnergy365Adapter = healthStore.activeEnergyDaily365.map {
            DailyStepsEntry(date: $0.date, steps: max(0, $0.activeEnergy))
        }

        monthlyData = healthStore.monthlyActiveEnergy
        periodAverages = makePeriodAverages()

        dailyScale = MetricScaleHelper.scale(
            last90DaysChartData.map { Double($0.steps) }.isEmpty ? [0] : last90DaysChartData.map { Double($0.steps) },
            for: .energyDaily
        )

        periodScale = MetricScaleHelper.scale(
            periodAverages.map { Double($0.value) }.isEmpty ? [0] : periodAverages.map { Double($0.value) },
            for: .energyDaily
        )

        monthlyScale = MetricScaleHelper.scale(
            monthlyData.map { Double($0.value) }.isEmpty ? [0] : monthlyData.map { Double($0.value) },
            for: .energyMonthly
        )

        activeEnergyReadAuthIssueV1 = healthStore.activeEnergyReadAuthIssueV1
    }

    // ============================================================
    // MARK: - Info Hint State
    // ============================================================

    var todayInfoState: ActivityEnergyInfoState? { // 🟨 UPDATED

        if todayActiveEnergyInt > 0 { return nil }

        let hasAnyHistory =
            last90DaysChartData.contains { $0.steps > 0 } ||
            dailyEnergy365Adapter.contains { $0.steps > 0 }

        if !hasAnyHistory {
            return .noHistory
        }

        return .noTodayData
    }

    // MARK: - Period Averages (Steps-Pattern 1:1)

    private func makePeriodAverages() -> [PeriodAverageEntry] {
        [
            .init(label: "7T",   days: 7,   value: averageEnergy(last: 7)),
            .init(label: "14T",  days: 14,  value: averageEnergy(last: 14)),
            .init(label: "30T",  days: 30,  value: averageEnergy(last: 30)),
            .init(label: "90T",  days: 90,  value: averageEnergy(last: 90)),
            .init(label: "180T", days: 180, value: averageEnergy(last: 180)),
            .init(label: "365T", days: 365, value: averageEnergy(last: 365))
        ]
    }

    private func averageEnergy(last days: Int) -> Int {
        let source = dailyEnergy365Adapter.isEmpty ? last90DaysChartData : dailyEnergy365Adapter
        guard !source.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard
            let endDate = calendar.date(byAdding: .day, value: -1, to: today),
            let startDate = calendar.date(byAdding: .day, value: -days, to: today)
        else { return 0 }

        let filtered = source.filter {
            let d = calendar.startOfDay(for: $0.date)
            return d >= startDate && d <= endDate && $0.steps > 0
        }

        guard !filtered.isEmpty else { return 0 }
        return filtered.reduce(0) { $0 + $1.steps } / filtered.count
    }

    // MARK: - Formatting (kcal-only)

    private func formatKcal(_ value: Int) -> String {
        guard value > 0 else { return "–" }

        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 0

        let numberString = f.string(from: NSNumber(value: value)) ?? "\(value)"
        return "\(numberString) kcal"
    }
}
