//
//  BMIViewModelV1.swift
//  GluVibProbe
//
//  V1: BMI-ViewModel (kein Fetch im VM)
//  - Spiegelung aus HealthStore (SSoT)
//  - Ableitungen: Chart-Adapter + Period Averages (bis 365 via Secondary)
//  - KPI: 1 Nachkommastelle (nicht runden auf Int)
//

import Foundation
import Combine
import SwiftUI

final class BMIViewModelV1: ObservableObject {

    // MARK: - Published Outputs (Mirror)

    @Published var todayBMI: Double = 0
    @Published var last90DaysBMIRaw: [BMIEntry] = []
    @Published var monthlyBMIData: [MonthlyMetricEntry] = []
    @Published var bmiDaily365Raw: [BMIEntry] = []                         // !!! NEW (Secondary mirror)

    // MARK: - Dependencies

    private let healthStore: HealthStore
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(healthStore: HealthStore = .shared) {
        self.healthStore = healthStore

        bindHealthStore()
        syncFromStores()
    }

    // MARK: - Bindings

    private func bindHealthStore() {
        healthStore.$todayBMI
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.todayBMI = $0 }
            .store(in: &cancellables)

        healthStore.$last90DaysBMI
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.last90DaysBMIRaw = $0 }
            .store(in: &cancellables)

        healthStore.$monthlyBMI
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.monthlyBMIData = $0 }
            .store(in: &cancellables)

        healthStore.$bmiDaily365
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.bmiDaily365Raw = $0 }
            .store(in: &cancellables)
    }

    private func syncFromStores() {
        todayBMI = healthStore.todayBMI
        last90DaysBMIRaw = healthStore.last90DaysBMI
        monthlyBMIData = healthStore.monthlyBMI
        bmiDaily365Raw = healthStore.bmiDaily365                            // !!! NEW
    }

    // MARK: - KPI Formatting (1 Nachkommastelle)

    var formattedTodayBMI: String {
        guard todayBMI > 0 else { return "–" }
        return oneDecimalFormatter.string(from: NSNumber(value: todayBMI)) ?? "–"
    }

    // MARK: - Chart Adapter (Int*10 für 1 Dezimalstelle)

    private var last90DaysForChartBase: [BMIEntry] {
        let sorted = last90DaysBMIRaw.sorted { $0.date < $1.date }
        let nonZero = sorted.filter { $0.bmi > 0 }
        return nonZero.count <= 90 ? nonZero : Array(nonZero.suffix(90))
    }

    /// steps = BMI * 10 (z.B. 24.3 -> 243) für 1-dec-Display im Chart
    var last90DaysDataForChart: [DailyStepsEntry] {
        last90DaysForChartBase.map { e in
            DailyStepsEntry(date: e.date, steps: Int(round(e.bmi * 10.0)))
        }
    }

    // MARK: - Period Averages (7/14/30/90 + 180/365)

    var periodAverages: [PeriodAverageEntry] {
        [
            .init(label: "7T",   days: 7,   value: avgBMIx10(last: 7)),
            .init(label: "14T",  days: 14,  value: avgBMIx10(last: 14)),
            .init(label: "30T",  days: 30,  value: avgBMIx10(last: 30)),
            .init(label: "90T",  days: 90,  value: avgBMIx10(last: 90)),
            .init(label: "180T", days: 180, value: avgBMIx10(last: 180)),     // !!! NEW
            .init(label: "365T", days: 365, value: avgBMIx10(last: 365))      // !!! NEW
        ]
    }

    private func avgBMIx10(last days: Int) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard let endDate = calendar.date(byAdding: .day, value: -1, to: today),
              let startDate = calendar.date(byAdding: .day, value: -days, to: today) else {
            return 0
        }

        // Quelle:
        // - bis 90: last90DaysBMIRaw reicht
        // - 180/365: bmiDaily365Raw (Secondary) nötig
        let source: [BMIEntry] = (days <= 90) ? last90DaysBMIRaw : bmiDaily365Raw

        let filtered = source.filter { entry in
            let d = calendar.startOfDay(for: entry.date)
            return d >= startDate && d <= endDate && entry.bmi > 0
        }

        guard !filtered.isEmpty else { return 0 }

        let sum = filtered.reduce(0.0) { $0 + $1.bmi }
        let avg = sum / Double(filtered.count)

        return Int(round(avg * 10.0))
    }

    // MARK: - Scales (MetricScaleHelper + eigener ValueLabel für 1 dec)

    var dailyScale: MetricScaleResult {
        let values = last90DaysDataForChart.map { Double($0.steps) }
        let base = MetricScaleHelper.scale(values, for: .weightKg)               // reuse ticks-logic
        return MetricScaleResult(
            yAxisTicks: base.yAxisTicks,
            yMax: base.yMax,
            valueLabel: { v in
                let x = v / 10.0
                return self.oneDecimalFormatter.string(from: NSNumber(value: x)) ?? "\(x)"
            }
        )
    }

    var periodScale: MetricScaleResult {
        let values = periodAverages.map { Double($0.value) }
        let base = MetricScaleHelper.scale(values, for: .weightKg)
        return MetricScaleResult(
            yAxisTicks: base.yAxisTicks,
            yMax: base.yMax,
            valueLabel: { v in
                let x = v / 10.0
                return self.oneDecimalFormatter.string(from: NSNumber(value: x)) ?? "\(x)"
            }
        )
    }

    var monthlyScale: MetricScaleResult {
        // MonthlyMetricEntry ist Int -> hier nur Fallback (Monthly Chart ist in BMI V1 aus)
        let values = monthlyBMIData.map { Double($0.value) }
        return MetricScaleHelper.scale(values, for: .weightKg)
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
