//
//  BMIViewModelV1.swift
//  GluVibProbe
//
//  V1: BMI-ViewModel (kein Fetch im VM)
//  - SSoT: HealthStore
//  - BMI bleibt durchgehend Double (kein Int*10, keine Quantisierung)
//  - Period Averages bleiben Int (weil PeriodAverageEntry im Projekt Int ist)
//    -> wir runden hier konsistent auf 1 Nachkommastelle (als Double),
//       und liefern für PeriodAverageEntry ein Int "×10", ABER NUR für die Anzeige-Engine,
//       NICHT als BMI-Datenhaltung. (Card/Charts bekommen Double direkt.)
//  - Daily Chart / Scales laufen Double-only über BodySectionCardScaledV2 (Double-Init)
//

import Foundation
import Combine
import SwiftUI

// ============================================================
// MARK: - Local Double Period Average Entry (BMI)
// ============================================================

struct PeriodAverageEntryDouble: Identifiable, Equatable {
    let id = UUID()
    let label: String
    let days: Int
    let value: Double
}

@MainActor
final class BMIViewModelV1: ObservableObject {

    // ============================================================
    // MARK: - Published Outputs (View)
    // ============================================================

    @Published var todayBMI: Double = 0
    @Published var last90DaysBMIRaw: [BMIEntry] = []
    @Published var monthlyBMIData: [MonthlyMetricEntry] = []

    /// Secondary (365d) – wird vom Store geladen (refreshBodySecondary)
    @Published var bmiDaily365Raw: [BMIEntry] = []

    // ✅ Double-first Outputs (für Double-Charts)
    @Published var last90DaysForChart: [DailyDoubleEntry] = []                 // ✅ Double
    @Published var periodAveragesDouble: [PeriodAverageEntryDouble] = []       // ✅ Double
    @Published var monthlyForChart: [MonthlyMetricEntry] = []                  // passthrough

    // ✅ Scales (Double)
    @Published var dailyScale: MetricScaleResult = MetricScaleHelper.scale([0], for: .weightKg)
    @Published var periodScale: MetricScaleResult = MetricScaleHelper.scale([0], for: .weightKg)
    @Published var monthlyScale: MetricScaleResult = MetricScaleHelper.scale([0], for: .weightKg)

    // ✅ KPI Text
    @Published var currentText: String = "–"

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

        bind()
        syncInitial()
    }

    // ============================================================
    // MARK: - Bindings (trigger remap only)
    // ============================================================

    private func bind() {

        healthStore.$todayBMI
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.remap()
            }
            .store(in: &cancellables)

        healthStore.$last90DaysBMI
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.remap()
            }
            .store(in: &cancellables)

        healthStore.$monthlyBMI
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.remap()
            }
            .store(in: &cancellables)

        healthStore.$bmiDaily365
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.remap()
            }
            .store(in: &cancellables)
    }

    private func syncInitial() {
        remap()
    }

    // ============================================================
    // MARK: - Core Mapping
    // ============================================================

    private func remap() {

        // 1) Pull from SSoT
        todayBMI = max(0, healthStore.todayBMI)
        last90DaysBMIRaw = healthStore.last90DaysBMI
        monthlyBMIData = healthStore.monthlyBMI
        bmiDaily365Raw = healthStore.bmiDaily365

        // 2) KPI text (1 decimal)
        currentText = formatOneDecimal(todayBMI)

        // 3) Daily (Last 90) chart series (Double)
        let sorted90 = last90DaysBMIRaw
            .filter { $0.bmi > 0 }
            .sorted { $0.date < $1.date }

        last90DaysForChart = sorted90.map {
            DailyDoubleEntry(date: $0.date, value: max(0, $0.bmi))
        }

        // 4) Period averages (Double)
        periodAveragesDouble = makePeriodAveragesDouble()

        // 5) Monthly passthrough
        monthlyForChart = monthlyBMIData

        // 6) Scales (Double)
        dailyScale = MetricScaleResult(
            yAxisTicks: MetricScaleHelper.scale(last90DaysForChart.map { $0.value }, for: .weightKg).yAxisTicks,
            yMax: MetricScaleHelper.scale(last90DaysForChart.map { $0.value }, for: .weightKg).yMax,
            valueLabel: { tick in
                self.formatOneDecimal(Double(tick))
            }
        )

        periodScale = MetricScaleResult(
            yAxisTicks: MetricScaleHelper.scale(periodAveragesDouble.map { $0.value }, for: .weightKg).yAxisTicks,
            yMax: MetricScaleHelper.scale(periodAveragesDouble.map { $0.value }, for: .weightKg).yMax,
            valueLabel: { tick in
                self.formatOneDecimal(Double(tick))
            }
        )

        monthlyScale = MetricScaleResult(
            yAxisTicks: MetricScaleHelper.scale(monthlyForChart.map { Double($0.value) }, for: .weightKg).yAxisTicks,
            yMax: MetricScaleHelper.scale(monthlyForChart.map { Double($0.value) }, for: .weightKg).yMax,
            valueLabel: { tick in
                // MonthlyMetricEntry ist Int -> wir zeigen 1 Nachkommastelle trotzdem sauber
                self.formatOneDecimal(Double(tick))
            }
        )
    }

    // ============================================================
    // MARK: - Public Outputs for Views (Bridge)
    // ============================================================

    /// ✅ Für BodySectionCardScaledV2 (Period Chart) brauchst du aktuell PeriodAverageEntry (Int).
    /// Wir bridgen Double → Int nur an dieser Stelle (0.1 Auflösung), ohne interne Int-Datenhaltung.
    var periodAverages: [PeriodAverageEntry] {
        periodAveragesDouble.map { e in
            .init(label: e.label, days: e.days, value: Int((e.value * 10.0).rounded()))
        }
    }

    /// ✅ Falls deine AveragePeriodsScaledBarChart NUR Int kann:
    /// Dann musst du im Chart die valueLabel aus periodScale nutzen (liefert wieder "xx.x").
    /// (Das passt zu deinem bestehenden Scale-Pattern.)
    
    // ============================================================
    // MARK: - Helpers
    // ============================================================

    private func makePeriodAveragesDouble() -> [PeriodAverageEntryDouble] {
        [
            .init(label: "7T",   days: 7,   value: averageBMI(last: 7)),
            .init(label: "14T",  days: 14,  value: averageBMI(last: 14)),
            .init(label: "30T",  days: 30,  value: averageBMI(last: 30)),
            .init(label: "90T",  days: 90,  value: averageBMI(last: 90)),
            .init(label: "180T", days: 180, value: averageBMI(last: 180)),
            .init(label: "365T", days: 365, value: averageBMI(last: 365))
        ]
    }

    private func averageBMI(last days: Int) -> Double {

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard
            let endDate = calendar.date(byAdding: .day, value: -1, to: today),
            let startDate = calendar.date(byAdding: .day, value: -days, to: today)
        else { return 0 }

        let source: [BMIEntry] = {
            if days > 90, !bmiDaily365Raw.isEmpty { return bmiDaily365Raw }
            return last90DaysBMIRaw
        }()

        let values = source
            .filter {
                let d = calendar.startOfDay(for: $0.date)
                return d >= startDate && d <= endDate && $0.bmi > 0
            }
            .map(\.bmi)

        guard !values.isEmpty else { return 0 }

        let avg = values.reduce(0, +) / Double(values.count)

        // ✅ konsistent auf 1 Nachkommastelle
        return (avg * 10.0).rounded() / 10.0
    }

    private func formatOneDecimal(_ v: Double) -> String {
        guard v > 0 else { return "–" }
        return oneDecimalFormatter.string(from: NSNumber(value: v)) ?? "\(v)"
    }

    private let oneDecimalFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 1
        f.maximumFractionDigits = 1
        return f
    }()
}
