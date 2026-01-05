//
//  BodyFatViewModelV1.swift
//  GluVibProbe
//
//  V1: Body Fat ViewModel (kein Fetch im VM)
//  - Spiegelung aus HealthStore (SSoT)
//  - BodyFat als Prozent (0...100) bleibt Double (KPI)
//  - Charts: kompatibel zu BodySectionCardScaledV2 über Int*10 (18.7 -> 187)
//  - Period-Averages: 7/14/30/90 aus 90d, 180/365 aus 365-secondary
//

import Foundation
import Combine

@MainActor
final class BodyFatViewModelV1: ObservableObject {

    // MARK: - Published Outputs (View)

    @Published var todayBodyFatPercent: Double = 0
    @Published var last90DaysBodyFatRaw: [BodyFatEntry] = []
    @Published var monthlyBodyFatData: [MonthlyMetricEntry] = []

    /// Secondary (365d) – wird vom Store geladen (refreshBodySecondary)
    @Published var bodyFatDaily365Raw: [BodyFatEntry] = []                   // !!! NEW

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

        healthStore.$todayBodyFatPercent
            .sink { [weak self] in self?.todayBodyFatPercent = $0 }
            .store(in: &cancellables)

        healthStore.$last90DaysBodyFat
            .sink { [weak self] in self?.last90DaysBodyFatRaw = $0 }
            .store(in: &cancellables)

        healthStore.$monthlyBodyFat
            .sink { [weak self] in self?.monthlyBodyFatData = $0 }
            .store(in: &cancellables)

        healthStore.$bodyFatDaily365
            .sink { [weak self] in self?.bodyFatDaily365Raw = $0 }          // !!! NEW
            .store(in: &cancellables)
    }

    private func syncFromStores() {
        todayBodyFatPercent = healthStore.todayBodyFatPercent
        last90DaysBodyFatRaw = healthStore.last90DaysBodyFat
        monthlyBodyFatData = healthStore.monthlyBodyFat
        bodyFatDaily365Raw = healthStore.bodyFatDaily365                    // !!! NEW
    }

    // MARK: - KPI Formatting (1 decimal)

    var formattedTodayBodyFat: String {
        let v = todayBodyFatPercent
        guard v > 0 else { return "–" }                                     // !!! UPDATED
        let value = oneDecimalFormatter.string(from: NSNumber(value: v)) ?? "\(v)"
        return "\(value) %"
    }

    // MARK: - Chart Adapters (compat: Int*10)

    /// !!! UPDATED: BodySectionCardScaledV2 erwartet [DailyStepsEntry]
    /// steps = bodyFat% * 10  (18.7 -> 187)
    var last90DaysDataForChart: [DailyStepsEntry] {
        let sorted = last90DaysBodyFatRaw.sorted { $0.date < $1.date }
        let nonZero = sorted.filter { $0.bodyFatPercent > 0 }

        let base = nonZero.count <= 90 ? nonZero : Array(nonZero.suffix(90))

        return base.map { e in
            DailyStepsEntry(
                date: e.date,
                steps: Int((e.bodyFatPercent * 10.0).rounded())
            )
        }
    }

    // MARK: - Period Averages (compat: Int value)

    var periodAverages: [PeriodAverageEntry] {
        [
            .init(label: "7T",   days: 7,   value: averageBodyFatInt10(last: 7)),
            .init(label: "14T",  days: 14,  value: averageBodyFatInt10(last: 14)),
            .init(label: "30T",  days: 30,  value: averageBodyFatInt10(last: 30)),
            .init(label: "90T",  days: 90,  value: averageBodyFatInt10(last: 90)),
            .init(label: "180T", days: 180, value: averageBodyFatInt10(last: 180)),  // !!! NEW
            .init(label: "365T", days: 365, value: averageBodyFatInt10(last: 365))   // !!! NEW
        ]
    }

    /// Durchschnitt über echte Werte im Zeitraum (vor heute), Ergebnis als Int*10
    private func averageBodyFatInt10(last days: Int) -> Int {

        let source: [BodyFatEntry] = {
            if days > 90, !bodyFatDaily365Raw.isEmpty {
                return bodyFatDaily365Raw
            }
            return last90DaysBodyFatRaw
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
            return d >= startDate && d <= endDate && entry.bodyFatPercent > 0
        }

        guard !filtered.isEmpty else { return 0 }

        let sum = filtered.reduce(0.0) { $0 + $1.bodyFatPercent }
        let avg = sum / Double(filtered.count)

        return Int((avg * 10.0).rounded())
    }

    // MARK: - Monthly (SSoT passthrough)

    var monthlyBodyFatDataForChart: [MonthlyMetricEntry] {                   // !!! NEW
        monthlyBodyFatData
    }

    // MARK: - Scales (Int*10, Labels als 1 decimal)

    var dailyScale: MetricScaleResult {
        let values = last90DaysDataForChart.map { Double($0.steps) }         // !!! UPDATED (Double array)
        return scalePercentInt10(values)
    }

    var periodScale: MetricScaleResult {
        let values = periodAverages.map { Double($0.value) }                 // !!! UPDATED (Double array)
        return scalePercentInt10(values)
    }

    var monthlyScale: MetricScaleResult {
        dailyScale
    }

    private func scalePercentInt10(_ values: [Double]) -> MetricScaleResult {
        // Tick-Engine reuse (Fallback): wir überschreiben nur Label (Int10 -> 1 decimal).
        let base = MetricScaleHelper.scale(values, for: .percentInt10)

        return MetricScaleResult(
            yAxisTicks: base.yAxisTicks,
            yMax: base.yMax,
            valueLabel: { tick in
                let v = tick / 10.0
                let text = self.oneDecimalFormatter.string(from: NSNumber(value: v)) ?? "\(v)"
                return "\(text)"
            }
        )
    }

    // MARK: - Formatter

    private let oneDecimalFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 1
        f.maximumFractionDigits = 1
        return f
    }()
}
