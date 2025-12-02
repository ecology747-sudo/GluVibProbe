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

    // -------------------------
    // 🟢 CARBS (g)
    // -------------------------

    /// Kohlenhydrate heute (Gramm)
    @Published var todayCarbsGrams: Int = 0

    /// Kohlenhydrate der letzten 90 Tage
    @Published var last90DaysCarbs: [DailyCarbsEntry] = []

    /// Monatliche Kohlenhydrate (Summen je Monat)
    @Published var monthlyCarbs: [MonthlyMetricEntry] = []

    // -------------------------
    // 🧬 PROTEIN (g)
    // -------------------------

    /// Protein heute (Gramm)
    @Published var todayProteinGrams: Int = 0

    /// Protein der letzten 90 Tage
    @Published var last90DaysProtein: [DailyProteinEntry] = []

    /// Monatliches Protein (Summen je Monat)
    @Published var monthlyProtein: [MonthlyMetricEntry] = []

    // -------------------------
    // 🧈 FAT (g)
    // -------------------------

    /// Fett heute (Gramm)
    @Published var todayFatGrams: Int = 0

    /// Fett der letzten 90 Tage
    @Published var last90DaysFat: [DailyFatEntry] = []

    /// Monatliches Fett (Summen je Monat)
    @Published var monthlyFat: [MonthlyMetricEntry] = []

    // -------------------------
    // 🍽️ NUTRITION ENERGY (kcal)
    // -------------------------

    /// Nahrungsenergie heute (immer in kcal gespeichert)
    @Published var todayNutritionEnergyKcal: Int = 0

    /// Nahrungsenergie der letzten 90 Tage
    @Published var last90DaysNutritionEnergy: [DailyNutritionEnergyEntry] = []

    /// Monatliche Nahrungsenergie (Summen je Monat)
    @Published var monthlyNutritionEnergy: [MonthlyMetricEntry] = []

    // MARK: - Preview Caches

    var previewDailySteps: [DailyStepsEntry] = []
    var previewDailyActiveEnergy: [ActivityEnergyEntry] = []
    var previewDailySleep: [DailySleepEntry] = []
    var previewDailyWeight: [DailyStepsEntry] = []

    // 🔹 Carbs-Preview
    var previewDailyCarbs: [DailyCarbsEntry] = []

    // 🔹 Fat-Preview
    var previewDailyFat: [DailyFatEntry] = []

    // 🔹 NutritionEnergy-Preview
    var previewDailyNutritionEnergy: [DailyNutritionEnergyEntry] = []

    // MARK: - Authorization

    func requestAuthorization() {
        if isPreview { return }

        guard
            let stepType          = HKQuantityType.quantityType(forIdentifier: .stepCount),
            let activeEnergyType  = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
            let sleepType         = HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
            let weightType        = HKQuantityType.quantityType(forIdentifier: .bodyMass),
            // 🔹 Carbs
            let carbsType         = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates),
            // 🔹 Protein
            let proteinType       = HKQuantityType.quantityType(forIdentifier: .dietaryProtein),
            // 🔹 Fat (Total)
            let fatType           = HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal),
            // 🔹 Nutrition Energy (Food)
            let nutritionEnergyType = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed)
        else {
            return
        }

        healthStore.requestAuthorization(
            toShare: [],
            read: [
                stepType,
                activeEnergyType,
                sleepType,
                weightType,
                carbsType,
                proteinType,
                fatType,
                nutritionEnergyType
            ]
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

                // CARBS (liegt in HealthStore+Carbs.swift)
                self.fetchCarbsToday()
                self.fetchLast90DaysCarbs()
                self.fetchMonthlyCarbs()

                // PROTEIN (liegt in HealthStore+Protein.swift)
                self.fetchProteinToday { grams in
                    self.todayProteinGrams = grams
                }
                self.fetchProteinDaily(last: 90) { entries in
                    self.last90DaysProtein = entries
                }
                self.fetchProteinMonthly { monthly in
                    self.monthlyProtein = monthly
                }

                // FAT (liegt in HealthStore+Fat.swift)
                self.fetchFatToday { grams in
                    self.todayFatGrams = grams
                }
                self.fetchFatDaily(last: 90) { entries in
                    self.last90DaysFat = entries
                }
                self.fetchFatMonthly { monthly in
                    self.monthlyFat = monthly
                }

                // NUTRITION ENERGY (liegt in HealthStore+NutritionEnergy.swift)
                self.fetchNutritionEnergyToday { kcal in
                    self.todayNutritionEnergyKcal = kcal
                }
                self.fetchNutritionEnergyDaily(last: 90) { entries in
                    self.last90DaysNutritionEnergy = entries
                }
                self.fetchNutritionEnergyMonthly { monthly in
                    self.monthlyNutritionEnergy = monthly
                }

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
        let store = HealthStore(isPreview: true)    // wenn Preview dann DEMO Data
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // ------------------------------------
        // STEPS (Demo)
        // ------------------------------------
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

        // ------------------------------------
        // ACTIVITY ENERGY (Demo)
        // ------------------------------------
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

        // ------------------------------------
        // SLEEP (Demo)
        // ------------------------------------
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

        // ------------------------------------
        // WEIGHT (Demo – wie Steps/Sleep über Preview-Array)
        // ------------------------------------
        store.previewDailyWeight = (0..<365).compactMap { i in
            let d = calendar.date(byAdding: .day, value: -i, to: today)!
            let w = Int.random(in: 92...100)
            return DailyStepsEntry(date: d, steps: w)
        }.sorted { $0.date < $1.date }

        store.last90DaysWeight = Array(store.previewDailyWeight.suffix(90))

        // Monatsdurchschnitt Gewicht aus previewDailyWeight
        var perMonthWeight: [DateComponents: (sum: Int, count: Int)] = [:]

        for e in store.previewDailyWeight {
            let comps = calendar.dateComponents([.year, .month], from: e.date)
            var bucket = perMonthWeight[comps] ?? (0, 0)
            bucket.sum   += e.steps
            bucket.count += 1
            perMonthWeight[comps] = bucket
        }

        let sortedWeightKeys = perMonthWeight.keys.sorted { lhs, rhs in
            let l = calendar.date(from: lhs) ?? .distantPast
            let r = calendar.date(from: rhs) ?? .distantPast
            return l < r
        }

        store.monthlyWeight = sortedWeightKeys.map { comps in
            let date       = calendar.date(from: comps) ?? Date()
            let monthShort = date.formatted(.dateTime.month(.abbreviated))
            let bucket     = perMonthWeight[comps] ?? (0, 1)
            let avg        = bucket.count > 0 ? bucket.sum / bucket.count : 0
            return MonthlyMetricEntry(monthShort: monthShort, value: avg)
        }

        // KPI im Preview = letzter Weight-Wert
        store.todayWeightKg = store.previewDailyWeight.last?.steps ?? 0

        // ------------------------------------
        // CARBS (Demo)
        // ------------------------------------
        store.todayCarbsGrams = 180
        store.previewDailyCarbs = (0..<365).compactMap { i in
            let d = calendar.date(byAdding: .day, value: -i, to: today)!
            // z. B. 80–320 g pro Tag
            let g = Int.random(in: 80...320)
            return DailyCarbsEntry(date: d, grams: g)
        }.sorted { $0.date < $1.date }

        store.last90DaysCarbs = Array(store.previewDailyCarbs.suffix(90))

        // Monats-Summen Carbs
        var perMonthCarbs: [DateComponents: Int] = [:]
        for e in store.previewDailyCarbs {
            let comps = calendar.dateComponents([.year, .month], from: e.date)
            let current = perMonthCarbs[comps] ?? 0
            perMonthCarbs[comps] = current + e.grams
        }

        let sortedCarbKeys = perMonthCarbs.keys.sorted { lhs, rhs in
            let l = calendar.date(from: lhs) ?? .distantPast
            let r = calendar.date(from: rhs) ?? .distantPast
            return l < r
        }

        store.monthlyCarbs = sortedCarbKeys.map { comps in
            let date       = calendar.date(from: comps) ?? Date()
            let monthShort = date.formatted(.dateTime.month(.abbreviated))
            let sum        = perMonthCarbs[comps] ?? 0
            return MonthlyMetricEntry(monthShort: monthShort, value: sum)
        }

        // ------------------------------------
        // PROTEIN (Demo – einfache KPI, Charts kommen über HealthStore+Protein)
        // ------------------------------------
        store.todayProteinGrams = 120   // z. B. 120 g heute

        // ------------------------------------
        // FAT (Demo)
        // ------------------------------------
        store.todayFatGrams = 70
        store.previewDailyFat = (0..<365).compactMap { i in
            let d = calendar.date(byAdding: .day, value: -i, to: today)!
            // z. B. 40–120 g Fett
            let g = Int.random(in: 40...120)
            return DailyFatEntry(date: d, grams: g)
        }.sorted { $0.date < $1.date }

        store.last90DaysFat = Array(store.previewDailyFat.suffix(90))

        var perMonthFat: [DateComponents: Int] = [:]
        for e in store.previewDailyFat {
            let comps = calendar.dateComponents([.year, .month], from: e.date)
            let current = perMonthFat[comps] ?? 0
            perMonthFat[comps] = current + e.grams
        }

        let sortedFatKeys = perMonthFat.keys.sorted { lhs, rhs in
            let l = calendar.date(from: lhs) ?? .distantPast
            let r = calendar.date(from: rhs) ?? .distantPast
            return l < r
        }

        store.monthlyFat = sortedFatKeys.map { comps in
            let date       = calendar.date(from: comps) ?? Date()
            let monthShort = date.formatted(.dateTime.month(.abbreviated))
            let sum        = perMonthFat[comps] ?? 0
            return MonthlyMetricEntry(monthShort: monthShort, value: sum)
        }

        // ------------------------------------
        // NUTRITION ENERGY (Demo)
        // ------------------------------------
        store.todayNutritionEnergyKcal = 2_200
        store.previewDailyNutritionEnergy = (0..<365).compactMap { i in
            let d = calendar.date(byAdding: .day, value: -i, to: today)!
            // z. B. 1 400 – 3 000 kcal
            let kcal = Int.random(in: 1_400...3_000)
            return DailyNutritionEnergyEntry(date: d, energyKcal: kcal)
        }.sorted { $0.date < $1.date }

        store.last90DaysNutritionEnergy = Array(store.previewDailyNutritionEnergy.suffix(90))

        var perMonthEnergy: [DateComponents: Int] = [:]
        for e in store.previewDailyNutritionEnergy {
            let comps = calendar.dateComponents([.year, .month], from: e.date)
            let current = perMonthEnergy[comps] ?? 0
            perMonthEnergy[comps] = current + e.energyKcal
        }

        let sortedEnergyKeys = perMonthEnergy.keys.sorted { lhs, rhs in
            let l = calendar.date(from: lhs) ?? .distantPast
            let r = calendar.date(from: rhs) ?? .distantPast
            return l < r
        }

        store.monthlyNutritionEnergy = sortedEnergyKeys.map { comps in
            let date       = calendar.date(from: comps) ?? Date()
            let monthShort = date.formatted(.dateTime.month(.abbreviated))
            let sum        = perMonthEnergy[comps] ?? 0
            return MonthlyMetricEntry(monthShort: monthShort, value: sum)
        }

        return store
    }
}
