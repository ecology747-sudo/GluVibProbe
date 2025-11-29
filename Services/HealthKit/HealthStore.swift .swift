//
//  HealthStore.swift
//  GluVibProbe
//

import Foundation
import HealthKit
import Combine

final class HealthStore: ObservableObject {

    // Singleton-Instanz der App
    static let shared = HealthStore()

    let healthStore = HKHealthStore()
    let isPreview: Bool

    // Standard-Init
    init(isPreview: Bool = false) {
        self.isPreview = isPreview
    }

    // MARK: - Published Values für SwiftUI

    // -------------------------
    // 🔶 STEPS
    // -------------------------

    /// Schritte heute
    @Published var todaySteps: Int = 0

    /// Schritte der letzten 90 Tage
    @Published var last90Days: [DailyStepsEntry] = []

    /// Monatliche Schritte (letzte 5 Monate)
    @Published var monthlySteps: [MonthlyMetricEntry] = []

    // -------------------------
    // 🔶 ACTIVITY ENERGY (kcal)
    // -------------------------

    /// Aktivitätsenergie heute
    @Published var todayActiveEnergy: Int = 0

    /// Aktivitätsenergie der letzten 90 Tage
    @Published var last90DaysActiveEnergy: [ActivityEnergyEntry] = []

    /// Monatliche Aktivitätsenergie (letzte 5 Monate)
    @Published var monthlyActiveEnergy: [MonthlyMetricEntry] = []

    // -------------------------
    // 🔵 SLEEP (Minuten)
    // -------------------------

    /// Schlaf heute in Minuten
    @Published var todaySleepMinutes: Int = 0

    /// Schlaf der letzten 90 Tage
    @Published var last90DaysSleep: [DailySleepEntry] = []

    /// Monatlicher Schlaf (Summen)
    @Published var monthlySleep: [MonthlyMetricEntry] = []

    // -------------------------
    // 🟠 WEIGHT (kg)
    // -------------------------

    /// Letztes bekanntes Gewicht in kg
    @Published var todayWeightKg: Int = 0

    /// Gewicht der letzten 90 Tage (für 90d-Chart),
    /// `steps`-Feld wird hier als "weightKg" verwendet
    @Published var last90DaysWeight: [DailyStepsEntry] = []

    /// Monatliche Gewichtswerte (z. B. Ø Gewicht / Monat)
    @Published var monthlyWeight: [MonthlyMetricEntry] = []

    // MARK: - Preview Caches

    var previewDailySteps: [DailyStepsEntry] = []
    var previewDailyActiveEnergy: [ActivityEnergyEntry] = []
    var previewDailySleep: [DailySleepEntry] = []
    var previewDailyWeight: [DailyStepsEntry] = []

    // MARK: - Authorization

    func requestAuthorization() {
        if isPreview { return }

        guard
            let stepType         = HKQuantityType.quantityType(forIdentifier: .stepCount),
            let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
            let sleepType        = HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
            let weightType       = HKQuantityType.quantityType(forIdentifier: .bodyMass)
        else { return }

        healthStore.requestAuthorization(
            toShare: [],
            read: [stepType, activeEnergyType, sleepType, weightType]
        ) { success, error in
            if success {
                // STEPS (liegt in HealthStore+Steps.swift)
                self.fetchStepsToday()
                self.fetchLast90Days()
                self.fetchMonthlySteps()

                // ACTIVITY ENERGY (liegt in HealthStore+ActivityEnergy.swift)
                self.fetchActiveEnergyToday()
                self.fetchLast90DaysActiveEnergy()
                self.fetchMonthlyActiveEnergy()

                // SLEEP (liegt in HealthStore+Sleep.swift)
                self.fetchSleepToday()
                self.fetchLast90DaysSleep()
                self.fetchMonthlySleep()

                // WEIGHT (liegt in HealthStore+Weight.swift)
                self.fetchWeightToday()
                self.fetchLast90DaysWeight()
                self.fetchMonthlyWeight()
            } else {
                print("HealthKit Auth fehlgeschlagen:", error?.localizedDescription ?? "unbekannt")
            }
        }
    }
}

// ============================================================
// MARK: - PREVIEW STORE
// ============================================================

extension HealthStore {
    static func preview() -> HealthStore {
        let store = HealthStore(isPreview: true)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // STEPS (Demo)
        store.todaySteps = 8_532
        store.previewDailySteps = (0..<365).compactMap { i in
            let d = calendar.date(byAdding: .day, value: -i, to: today)!
            return DailyStepsEntry(date: d, steps: Int.random(in: 3_000...12_000))
        }.sorted { $0.date < $1.date }
        store.last90Days = Array(store.previewDailySteps.suffix(90))
        store.monthlySteps = [
            .init(monthShort: "Jul", value: 140_000),
            .init(monthShort: "Aug", value: 152_000),
            .init(monthShort: "Sep", value: 165_000),
            .init(monthShort: "Okt", value: 158_000),
            .init(monthShort: "Nov", value: 171_000)
        ]

        // ACTIVITY ENERGY (Demo)
        store.todayActiveEnergy = 650
        store.previewDailyActiveEnergy = (0..<365).compactMap { i in
            let d = calendar.date(byAdding: .day, value: -i, to: today)!
            return ActivityEnergyEntry(date: d, activeEnergy: Int.random(in: 200...1_200))
        }.sorted { $0.date < $1.date }
        store.last90DaysActiveEnergy = Array(store.previewDailyActiveEnergy.suffix(90))
        store.monthlyActiveEnergy = [
            .init(monthShort: "Jul", value: 18_200),
            .init(monthShort: "Aug", value: 19_500),
            .init(monthShort: "Sep", value: 20_100),
            .init(monthShort: "Okt", value: 19_800),
            .init(monthShort: "Nov", value: 21_000)
        ]

        // SLEEP (Demo)
        store.todaySleepMinutes = 420   // 7h
        store.previewDailySleep = (0..<365).compactMap { i in
            let d = calendar.date(byAdding: .day, value: -i, to: today)!
            return DailySleepEntry(date: d, minutes: Int.random(in: 300...540))
        }.sorted { $0.date < $1.date }
        store.last90DaysSleep = Array(store.previewDailySleep.suffix(90))
        store.monthlySleep = [
            .init(monthShort: "Jul", value: 13_200),
            .init(monthShort: "Aug", value: 12_600),
            .init(monthShort: "Sep", value: 13_800),
            .init(monthShort: "Okt", value: 12_900),
            .init(monthShort: "Nov", value: 13_500)
        ]

        // WEIGHT (Demo – wie Steps/Sleep über Preview-Array)
        store.previewDailyWeight = (0..<365).compactMap { i in
            let d = calendar.date(byAdding: .day, value: -i, to: today)!
            let w = Int.random(in: 92...100)
            return DailyStepsEntry(date: d, steps: w)
        }.sorted { $0.date < $1.date }

        store.last90DaysWeight = Array(store.previewDailyWeight.suffix(90))

        // Monatsdurchschnitt Gewicht aus previewDailyWeight
        var perMonth: [DateComponents: (sum: Int, count: Int)] = [:]

        for e in store.previewDailyWeight {
            let comps = calendar.dateComponents([.year, .month], from: e.date)
            var bucket = perMonth[comps] ?? (0, 0)
            bucket.sum   += e.steps
            bucket.count += 1
            perMonth[comps] = bucket
        }

        let sortedKeys = perMonth.keys.sorted { lhs, rhs in
            let l = calendar.date(from: lhs) ?? .distantPast
            let r = calendar.date(from: rhs) ?? .distantPast
            return l < r
        }

        store.monthlyWeight = sortedKeys.map { comps in
            let date       = calendar.date(from: comps) ?? Date()
            let monthShort = date.formatted(.dateTime.month(.abbreviated))
            let bucket     = perMonth[comps] ?? (0, 1)
            let avg        = bucket.count > 0 ? bucket.sum / bucket.count : 0
            return MonthlyMetricEntry(monthShort: monthShort, value: avg)
        }

        // KPI im Preview = letzter Weight-Wert
        store.todayWeightKg = store.previewDailyWeight.last?.steps ?? 0

        return store
    }
}
