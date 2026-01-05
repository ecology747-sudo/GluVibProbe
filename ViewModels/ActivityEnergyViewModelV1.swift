//
//  ActivityEnergyViewModelV1.swift
//  GluVibProbe
//
//  V1: Activity Energy ViewModel
//  - SSoT: HealthStore (Energie = kcal)
//  - kJ / EnergyUnit vollständig entfernt
//  - Adapter-API kompatibel zu ActivityEnergyViewV1 + ActivitySectionCardScaledV2
//  - Period Averages analog zu StepsViewModelV1 (inkl. 180T / 365T)
//

import Foundation
import Combine

@MainActor
final class ActivityEnergyViewModelV1: ObservableObject {

    // MARK: - Dependencies (SSoT)

    private let healthStore: HealthStore
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Published (Adapter-API für View/Card)

    @Published private(set) var formattedTodayActiveEnergy: String = "–"
    @Published private(set) var last90DaysChartData: [DailyStepsEntry] = []
    @Published private(set) var periodAverages: [PeriodAverageEntry] = []                 // !!! UPDATED (7/14/30/90/180/365)
    @Published private(set) var monthlyData: [MonthlyMetricEntry] = []

    @Published private(set) var dailyScale: MetricScaleHelper.MetricScaleResult
    @Published private(set) var periodScale: MetricScaleHelper.MetricScaleResult
    @Published private(set) var monthlyScale: MetricScaleHelper.MetricScaleResult

    // MARK: - Internal 365 Adapter (für Period Averages)

    private var dailyEnergy365Adapter: [DailyStepsEntry] = []                              // !!! NEW

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

        // !!! UPDATED: zusätzlich activeEnergyDaily365 binden (für 180/365)
        Publishers.CombineLatest4(
            healthStore.$todayActiveEnergy,
            healthStore.$last90DaysActiveEnergy,
            healthStore.$monthlyActiveEnergy,
            healthStore.$activeEnergyDaily365
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] todayInt, last90Entries, monthlyEntries, daily365Entries in
            guard let self else { return }

            // KPI
            self.formattedTodayActiveEnergy = self.formatKcal(todayInt)

            // Daily (Last 90) – Adapter (kcal -> steps)
            self.last90DaysChartData = last90Entries.map {
                DailyStepsEntry(date: $0.date, steps: max(0, $0.activeEnergy))
            }

            // 365 – Adapter (kcal -> steps) für Period Averages
            self.dailyEnergy365Adapter = daily365Entries.map {                              // !!! NEW
                DailyStepsEntry(date: $0.date, steps: max(0, $0.activeEnergy))
            }

            // Monthly (passt vom Typ)
            self.monthlyData = monthlyEntries

            // Period Averages (analog Steps, inkl. 180/365)
            self.periodAverages = self.makePeriodAverages()                                 // !!! UPDATED

            // Scales
            let dailyValues = self.last90DaysChartData.map { Double($0.steps) }
            self.dailyScale = MetricScaleHelper.scale(dailyValues.isEmpty ? [0] : dailyValues, for: .energyDaily)

            let periodValues = self.periodAverages.map { Double($0.value) }
            self.periodScale = MetricScaleHelper.scale(periodValues.isEmpty ? [0] : periodValues, for: .energyDaily)

            let monthlyValues = self.monthlyData.map { Double($0.value) }
            self.monthlyScale = MetricScaleHelper.scale(monthlyValues.isEmpty ? [0] : monthlyValues, for: .energyDaily)
        }
        .store(in: &cancellables)
    }

    private func syncFromStores() {
        formattedTodayActiveEnergy = formatKcal(healthStore.todayActiveEnergy)

        last90DaysChartData = healthStore.last90DaysActiveEnergy.map {
            DailyStepsEntry(date: $0.date, steps: max(0, $0.activeEnergy))
        }

        dailyEnergy365Adapter = healthStore.activeEnergyDaily365.map {                      // !!! NEW
            DailyStepsEntry(date: $0.date, steps: max(0, $0.activeEnergy))
        }

        monthlyData = healthStore.monthlyActiveEnergy

        periodAverages = makePeriodAverages()                                               // !!! UPDATED

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
            for: .energyDaily
        )
    }

    // MARK: - Period Averages (Steps-Pattern 1:1)

    private func makePeriodAverages() -> [PeriodAverageEntry] {                             // !!! NEW
        [
            .init(label: "7T",   days: 7,   value: averageEnergy(last: 7)),
            .init(label: "14T",  days: 14,  value: averageEnergy(last: 14)),
            .init(label: "30T",  days: 30,  value: averageEnergy(last: 30)),
            .init(label: "90T",  days: 90,  value: averageEnergy(last: 90)),
            .init(label: "180T", days: 180, value: averageEnergy(last: 180)),
            .init(label: "365T", days: 365, value: averageEnergy(last: 365))
        ]
    }

    private func averageEnergy(last days: Int) -> Int {                                     // !!! NEW
        // exakt wie Steps: nimm 365 wenn vorhanden, sonst fallback auf last90
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
        guard value > 0 else { return "0 kcal" }

        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 0

        let numberString = f.string(from: NSNumber(value: value)) ?? "\(value)"
        return "\(numberString) kcal"
    }
}
