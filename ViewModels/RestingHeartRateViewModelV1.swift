//
//  RestingHeartRateViewModelV1.swift
//  GluVibProbe
//
//  V1: Resting Heart Rate ViewModel (kein Fetch im VM)
//  - Spiegelung aus HealthStore (SSoT)
//  - Adapter für Charts + Period-Averages bis 365
//

import Foundation
import Combine

@MainActor
final class RestingHeartRateViewModelV1: ObservableObject {                // !!! UPDATED

    // MARK: - Published Outputs (View)

    @Published var todayRestingHeartRate: Int = 0
    @Published var last90DaysRaw: [RestingHeartRateEntry] = []
    @Published var monthlyRaw: [MonthlyMetricEntry] = []
    @Published var daily365Raw: [RestingHeartRateEntry] = []

    // MARK: - Dependencies

    private let healthStore: HealthStore
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(healthStore: HealthStore = .shared) {
        self.healthStore = healthStore
        bindHealthStore()
        syncFromStores()
    }

    // MARK: - Bindings (SSoT)

    private func bindHealthStore() {

        healthStore.$todayRestingHeartRate
            .sink { [weak self] in self?.todayRestingHeartRate = $0 }       // !!! UPDATED (kein receive(on))
            .store(in: &cancellables)

        healthStore.$last90DaysRestingHeartRate
            .sink { [weak self] in self?.last90DaysRaw = $0 }               // !!! UPDATED
            .store(in: &cancellables)

        healthStore.$monthlyRestingHeartRate
            .sink { [weak self] in self?.monthlyRaw = $0 }                  // !!! UPDATED
            .store(in: &cancellables)

        healthStore.$restingHeartRateDaily365
            .sink { [weak self] in self?.daily365Raw = $0 }                 // !!! UPDATED
            .store(in: &cancellables)
    }

    private func syncFromStores() {
        todayRestingHeartRate = healthStore.todayRestingHeartRate
        last90DaysRaw = healthStore.last90DaysRestingHeartRate
        monthlyRaw = healthStore.monthlyRestingHeartRate
        daily365Raw = healthStore.restingHeartRateDaily365
    }

    // MARK: - KPI Formatting (WITH units)

    var formattedTodayRestingHR: String {
        let v = todayRestingHeartRate
        guard v > 0 else { return "–" }                                     // !!! UPDATED (nur Dash)
        return "\(v) bpm"
    }

    // MARK: - Chart Label Helper (NO units)

    private func numberOnlyLabel(_ value: Double) -> String {               // !!! UPDATED (bleibt)
        "\(Int(value.rounded()))"
    }

    // MARK: - Chart Adapters

    var last90DaysDataForChart: [DailyStepsEntry] {
        let sorted = last90DaysRaw.sorted { $0.date < $1.date }
        let nonZero = sorted.filter { $0.restingHeartRate > 0 }
        let base = nonZero.count <= 90 ? nonZero : Array(nonZero.suffix(90))

        return base.map { e in
            DailyStepsEntry(date: e.date, steps: e.restingHeartRate)
        }
    }

    // MARK: - Period Averages (7/14/30/90 aus 90d, 180/365 aus 365-secondary)

    var periodAverages: [PeriodAverageEntry] {
        [
            .init(label: "7T",   days: 7,   value: averageInt(last: 7)),
            .init(label: "14T",  days: 14,  value: averageInt(last: 14)),
            .init(label: "30T",  days: 30,  value: averageInt(last: 30)),
            .init(label: "90T",  days: 90,  value: averageInt(last: 90)),
            .init(label: "180T", days: 180, value: averageInt(last: 180)),
            .init(label: "365T", days: 365, value: averageInt(last: 365))
        ]
    }

    private func averageInt(last days: Int) -> Int {

        let source: [RestingHeartRateEntry] = {
            if days > 90, !daily365Raw.isEmpty { return daily365Raw }
            return last90DaysRaw
        }()

        guard !source.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard let endDate = calendar.date(byAdding: .day, value: -1, to: today),
              let startDate = calendar.date(byAdding: .day, value: -days, to: today) else {
            return 0
        }

        let filtered = source.filter { entry in
            let d = calendar.startOfDay(for: entry.date)
            return d >= startDate && d <= endDate && entry.restingHeartRate > 0
        }

        guard !filtered.isEmpty else { return 0 }

        let sum = filtered.reduce(0) { $0 + $1.restingHeartRate }
        let avg = Double(sum) / Double(filtered.count)
        return Int(avg.rounded())
    }

    // MARK: - Monthly passthrough

    var monthlyData: [MonthlyMetricEntry] { monthlyRaw }

    // MARK: - Scales (Base: heartRateBpm, Labels: numbers only)

    var dailyScale: MetricScaleResult {
        let values = last90DaysDataForChart.map { Double($0.steps) }
        let base = MetricScaleHelper.scale(values, for: .heartRateBpm)

        return MetricScaleResult(                                            // !!! UPDATED
            yAxisTicks: base.yAxisTicks,
            yMax: base.yMax,
            valueLabel: { [weak self] tick in                               // !!! UPDATED (fix closure)
                self?.numberOnlyLabel(tick) ?? "\(Int(tick.rounded()))"
            }
        )
    }

    var periodScale: MetricScaleResult {
        let values = periodAverages.map { Double($0.value) }
        let base = MetricScaleHelper.scale(values, for: .heartRateBpm)

        return MetricScaleResult(                                            // !!! UPDATED
            yAxisTicks: base.yAxisTicks,
            yMax: base.yMax,
            valueLabel: { [weak self] tick in                               // !!! UPDATED (fix closure)
                self?.numberOnlyLabel(tick) ?? "\(Int(tick.rounded()))"
            }
        )
    }

    var monthlyScale: MetricScaleResult {
        dailyScale
    }
}
